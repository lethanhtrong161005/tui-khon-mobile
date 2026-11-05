import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/core/home_widget/home_widget_controller.dart';
import 'package:tui_khon_mobile/core/home_widget/home_widget_host.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/core/offline/sync_controller.dart';
import 'package:tui_khon_mobile/core/offline/sync_screen.dart';
import 'package:tui_khon_mobile/core/services/app_lock_service.dart';
import 'package:tui_khon_mobile/core/services/debt_reminder_service.dart';
import 'package:tui_khon_mobile/core/supabase/supabase_providers.dart';
import 'package:tui_khon_mobile/core/theme/app_theme.dart';
import 'package:tui_khon_mobile/core/theme/appearance.dart';
import 'package:tui_khon_mobile/features/auth/models/user_profile.dart';
import 'package:tui_khon_mobile/features/auth/presentation/app_lock_screen.dart';
import 'package:tui_khon_mobile/features/auth/presentation/auth_gate.dart';
import 'package:tui_khon_mobile/features/auth/providers/auth_providers.dart';
import 'package:tui_khon_mobile/features/home/presentation/widgets/transaction_form_sheet.dart';
import 'package:tui_khon_mobile/features/home/models/transaction_model.dart';
import 'package:tui_khon_mobile/features/planning/data/planning_repository.dart';
import 'package:tui_khon_mobile/features/quick_record/data/quick_record_repository.dart';
import 'package:tui_khon_mobile/features/quick_record/presentation/quick_record_screen.dart';
import 'package:tui_khon_mobile/features/reminders/data/reminder_sync.dart';
import 'package:tui_khon_mobile/l10n/app_l10n.dart';
import 'fakes.dart';

class TestWidgetBridge implements HomeWidgetBridge {
  Object? pending;
  VoidCallback? onAvailable;
  int clears = 0;
  final appearances = <Map<String, String>>[];
  @override
  void listen(VoidCallback onAvailable) => this.onAvailable = onAvailable;
  @override
  Future<Object?> takePendingAction() async {
    final result = pending;
    pending = null;
    return result;
  }

  void emit(String action, String id) {
    pending = {'id': id, 'action': action};
    onAvailable?.call();
  }

  @override
  Future<void> clearPendingAction() async {
    clears++;
    pending = null;
  }

  @override
  Future<void> updateAppearance(Map<String, String> values) async =>
      appearances.add(Map.of(values));
  @override
  void dispose() => onAvailable = null;
}

class _NoRemote implements SyncRemote {
  @override
  String? get userId => 'qa';
  @override
  Future<Map<String, dynamic>> pull(int cursor) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> push(Map<String, dynamic> parameters) =>
      throw UnimplementedError();
  @override
  Future<void> upload(String path, Uint8List bytes, String mime) =>
      throw UnimplementedError();
}

class _Bootstrap extends SyncController {
  _Bootstrap(LocalStore store, bool ready)
      : super.withRemote(store, _NoRemote(), autoStart: false) {
    setReady(ready);
  }
  void setReady(bool value) => state =
      SyncStatus(initialized: value, error: value ? null : 'offline bootstrap');
}

final _account = StateProvider<String?>((ref) => 'qa');

class _Harness extends ConsumerWidget {
  const _Harness();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ref.watch(appearanceProvider).theme,
        locale: ref.watch(effectiveLocaleProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [ref.read(appNavigationObserverProvider)],
        builder: (context, child) => HomeWidgetHost(child: child!),
        home: const AuthGate(),
      );
}

void main() {
  test('unrecognized actions and malformed requests are ignored', () {
    final c = HomeWidgetController();
    addTearDown(c.dispose);
    for (final raw in [
      null,
      'expense',
      {'id': '', 'action': 'expense'},
      {'id': 1, 'action': 'expense'},
      {'id': 'x', 'action': 'transfer'}
    ]) {
      c.receive(raw);
      expect(c.state, isNull);
    }
  });

  test('latest wins, repeated delivery and active-action taps do not replay',
      () {
    final c = HomeWidgetController();
    addTearDown(c.dispose);
    c.receive({'id': '1', 'action': 'expense'});
    expect(c.begin()!.action, HomeWidgetAction.expense);
    c.receive({'id': '1', 'action': 'expense'});
    c.receive({'id': '2', 'action': 'income'});
    c.receive({'id': '3', 'action': 'expense'});
    expect(c.state!.action, HomeWidgetAction.income);
    c.receive({'id': '4', 'action': 'quickRecord'});
    expect(c.begin(), isNull);
    c.finish('1');
    expect(c.begin()!.action, HomeWidgetAction.quickRecord);
    c.finish('4');
    c.receive({'id': '4', 'action': 'quickRecord'});
    expect(c.hasWork, isFalse);
  });

  test('logout invalidates an in-flight native response', () async {
    final c = HomeWidgetController();
    addTearDown(c.dispose);
    final response = Completer<Object?>();
    final bridge = _DelayedBridge(response.future);
    final poll = c.poll(bridge);
    c.clear();
    response.complete({'id': 'old', 'action': 'expense'});
    await poll;
    expect(c.hasWork, isFalse);
  });

  test('completion from a departed account cannot finish a new action', () {
    final c = HomeWidgetController();
    addTearDown(c.dispose);
    c.receive({'id': 'old', 'action': 'expense'});
    c.begin();
    c.clear();
    c.receive({'id': 'new', 'action': 'income'});
    c.begin();
    c.finish('old');
    c.receive({'id': 'repeat-new', 'action': 'income'});
    expect(c.state, isNull);
    expect(c.hasWork, isTrue);
    c.finish('new');
    expect(c.hasWork, isFalse);
  });

  late LocalStore store;
  late TestWidgetBridge bridge;
  late FakeAppLock lock;
  late FakePlanningRepository planning;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester,
      {String? account = 'qa',
      bool ready = true,
      bool locked = false,
      String? coldAction,
      bool dueDebt = false}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    store = LocalStore.memory('qa');
    await store.writeBatch([
      const LocalMutation('wallets', {'id': 'cash', 'name': 'Tiền mặt'}),
      const LocalMutation(
          'categories', {'id': 'food', 'name': 'Ăn uống', 'type': 'expense'}),
      const LocalMutation(
          'categories', {'id': 'salary', 'name': 'Lương', 'type': 'income'}),
    ]);
    bridge = TestWidgetBridge();
    if (coldAction != null) {
      bridge.pending = {'id': 'cold', 'action': coldAction};
    }
    lock = FakeAppLock(enabled: locked, passes: false);
    planning = FakePlanningRepository();
    if (!dueDebt) planning.debts.clear();
    container = ProviderContainer(overrides: [
      _account.overrideWith((ref) => account),
      currentUserIdProvider.overrideWith((ref) => ref.watch(_account)),
      sessionProvider.overrideWithValue(null),
      localStoreProvider
          .overrideWith((ref) => ref.watch(_account) == null ? null : store),
      homeWidgetBridgeProvider.overrideWithValue(bridge),
      appLockProvider.overrideWithValue(lock),
      syncControllerProvider.overrideWith((ref) => _Bootstrap(store, ready)),
      planningRepositoryProvider.overrideWithValue(planning),
      debtRemindersProvider.overrideWithValue(FakeDebtReminders()),
      reminderSyncProvider.overrideWith((ref) async {}),
      quickRecordRepositoryProvider
          .overrideWithValue(FakeQuickRecordRepository()),
      profileProvider.overrideWith((ref) async => const UserProfile(
          id: 'qa', email: 'qa@test.invalid', displayName: 'Widget QA')),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const _Harness()));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await store.close();
      tester.view.reset();
    });
  }

  testWidgets(
      'cold expense waits for biometrics; cancel creates no transaction',
      (t) async {
    await pump(t, locked: true, coldAction: 'expense');
    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    lock.passes = true;
    await t.tap(find.text('Mở khoá'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
    final count = await store.pendingCount();
    await t.tap(find.byTooltip('Đóng'));
    await t.pumpAndSettle();
    expect(await store.rows('transactions'), isEmpty);
    expect(await store.pendingCount(), count);
  });

  testWidgets('cold launch survives initial login and failed bootstrap',
      (t) async {
    await pump(t, account: null, ready: false, coldAction: 'income');
    expect(find.text('Đăng nhập'), findsOneWidget);
    container.read(_account.notifier).state = 'qa';
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(container.read(homeWidgetControllerProvider)!.action,
        HomeWidgetAction.income);
    (container.read(syncControllerProvider.notifier) as _Bootstrap)
        .setReady(true);
    await t.pumpAndSettle();
    expect(find.text('Lưu khoản thu'), findsOneWidget);
  });

  testWidgets(
      'offline Save writes one integer-VND transaction and one outbox op',
      (t) async {
    await pump(t, coldAction: 'expense');
    final before = await store.pendingCount();
    bridge.emit('expense', 'repeat');
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '65000');
    await t.tap(find.text('Ăn uống'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Lưu giao dịch'));
    await t.tap(find.text('Lưu giao dịch'));
    await t.tap(find.text('Lưu giao dịch'), warnIfMissed: false);
    await t.pumpAndSettle();
    final rows = await store.rows('transactions');
    expect(rows, hasLength(1));
    expect(rows.single['amount'], 65000);
    expect(rows.single['amount'], isA<int>());
    expect(rows.single['type'], 'expense');
    expect(await store.pendingCount(), before + 1);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('latest different action waits without losing the open draft',
      (t) async {
    await pump(t, coldAction: 'expense');
    await t.enterText(find.byType(TextField).first, '75000');
    bridge.emit('income', 'next-income');
    await t.pumpAndSettle();
    bridge.emit('quickRecord', 'latest');
    await t.pumpAndSettle();
    expect(find.text('75.000'), findsOneWidget);
    expect(find.byType(QuickRecordScreen), findsNothing);
    await t.tap(find.byTooltip('Đóng'));
    await t.pumpAndSettle();
    expect(find.byType(QuickRecordScreen), findsOneWidget);
    expect(await store.rows('transactions'), isEmpty);
  });

  testWidgets('widget waits for an unrelated editor to close', (t) async {
    await pump(t);
    final context = t.element(find.text('Widget QA').first);
    unawaited(showTransactionFormSheet(context,
        initial:
            const TransactionDraft(type: TransactionType.income, amount: 0)));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '99000');
    bridge.emit('quickRecord', 'warm');
    await t.pumpAndSettle();
    expect(find.text('99.000'), findsOneWidget);
    expect(find.byType(QuickRecordScreen), findsNothing);
    await t.tap(find.byTooltip('Đóng'));
    await t.pumpAndSettle();
    expect(find.byType(QuickRecordScreen), findsOneWidget);
  });

  testWidgets('relocking shields a pushed draft and preserves its input',
      (t) async {
    await pump(t, coldAction: 'expense', locked: true);
    lock.passes = true;
    await t.tap(find.text('Mở khoá'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '123000');
    lock.passes = false;
    container.read(appUnlockedProvider.notifier).state = false;
    await t.pumpAndSettle();
    expect(find.text('Túi Khôn đang khoá'), findsWidgets);
    expect(lock.prompts, 3); // initial, explicit unlock, one overlay prompt
    lock.passes = true;
    await t.tap(find.text('Mở khoá').last);
    await t.pumpAndSettle();
    expect(find.text('123.000'), findsOneWidget);
    expect(await store.rows('transactions'), isEmpty);
  });

  testWidgets('account departure clears queued actions and removes old forms',
      (t) async {
    await pump(t, coldAction: 'expense');
    bridge.emit('income', 'other');
    await t.pumpAndSettle();
    container.read(_account.notifier).state = null;
    await t.pumpAndSettle();
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(container.read(homeWidgetControllerProvider), isNull);
    expect(bridge.clears, greaterThan(0));
    container.read(_account.notifier).state = 'second-account';
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(await store.rows('transactions'), isEmpty);
  });

  testWidgets('background requests wait for resumed lifecycle', (t) async {
    await pump(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    bridge.emit('income', 'paused');
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(find.text('Lưu khoản thu'), findsOneWidget);
  });

  testWidgets('due debt prompt follows the widget action, never covers it',
      (t) async {
    await pump(t, coldAction: 'expense', dueDebt: true);
    expect(find.text('Khoản nợ đã đến hạn'), findsNothing);
    await t.tap(find.byTooltip('Đóng'));
    await t.pumpAndSettle();
    expect(find.text('Khoản nợ đã đến hạn'), findsOneWidget);
  });

  testWidgets(
      'appearance sync uses ARB strings and does not contain account data',
      (t) async {
    await pump(t);
    await container
        .read(appearanceProvider.notifier)
        .change(theme: ThemeMode.dark, language: 'en');
    await t.pumpAndSettle();
    final presentation = bridge.appearances.last;
    expect(presentation['theme'], 'dark');
    expect(presentation['language'], 'en');
    expect(presentation['expense'], 'Expense');
    expect(presentation.keys, isNot(contains('userId')));
    expect(presentation.keys, isNot(contains('balance')));
  });
  testWidgets(
      'scan action opens source picker without taking a photo or saving',
      (t) async {
    await pump(t, coldAction: 'scanReceipt');
    expect(find.byType(QuickRecordScreen), findsOneWidget);
    expect(
        t
            .widget<QuickRecordScreen>(find.byType(QuickRecordScreen))
            .initialAction,
        QuickRecordStart.scan);
    expect(find.byIcon(Icons.photo_camera), findsOneWidget);
    expect(find.byIcon(Icons.photo_library), findsOneWidget);
    expect(await store.rows('transactions'), isEmpty);
  });
  testWidgets(
      'conflict amounts group in both locales, preserve sign and leave notes/data unchanged',
      (t) async {
    await pump(t);
    await store.put('wallets',
        {'id': 'cash', 'name': 'Tiền mặt', 'initial_balance': -1234567});
    await store.conflict(
        'wallets',
        'cash',
        {'id': 'cash', 'name': 'Tiền mặt', 'initial_balance': 2000000},
        1,
        false);
    await store.put('transactions', {
      'id': 'conflict-tx',
      'amount': 65000,
      'type': 'expense',
      'wallet_id': 'cash',
      'note': 'mã 1234567'
    });
    await store.conflict(
        'transactions',
        'conflict-tx',
        {
          'id': 'conflict-tx',
          'amount': 1500000,
          'type': 'expense',
          'wallet_id': 'cash',
          'note': 'mã 1234567'
        },
        1,
        false);
    unawaited(Navigator.of(t.element(find.text('Widget QA').first))
        .push(MaterialPageRoute<void>(builder: (_) => const SyncScreen())));
    await t.pumpAndSettle();
    expect(find.textContaining('-1.234.567'), findsWidgets);
    expect(find.textContaining('2.000.000'), findsWidgets);
    expect(find.textContaining('65.000'), findsWidgets);
    expect(find.textContaining('1.500.000'), findsWidgets);
    expect(find.textContaining('mã 1234567'), findsWidgets);
    await container.read(appearanceProvider.notifier).change(language: 'en');
    await t.pumpAndSettle();
    expect(find.textContaining('-₫1,234,567'), findsWidgets);
    expect(find.textContaining('₫1,500,000'), findsWidgets);
    expect(
        (await store.record('transactions', 'conflict-tx'))!['amount'], 65000);
    expect(
        (await store.record('wallets', 'cash'))!['initial_balance'], -1234567);
  });
}

class _DelayedBridge extends TestWidgetBridge {
  _DelayedBridge(this.response);
  final Future<Object?> response;
  @override
  Future<Object?> takePendingAction() => response;
}
