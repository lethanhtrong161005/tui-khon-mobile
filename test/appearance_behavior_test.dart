import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise the real preference cache when platform persistence fails.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:tui_khon_mobile/core/theme/appearance.dart';
import 'package:tui_khon_mobile/core/theme/app_theme.dart';
import 'package:tui_khon_mobile/core/utils/currency_formatter.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/core/services/debt_reminder_service.dart';
import 'package:tui_khon_mobile/features/auth/presentation/login_screen.dart';
import 'package:tui_khon_mobile/features/data_exchange/csv_exchange.dart';
import 'package:tui_khon_mobile/features/planning/models/planning_models.dart';
import 'package:tui_khon_mobile/features/reminders/data/reminder_scheduler.dart';
import 'package:tui_khon_mobile/features/reminders/models/payable.dart';
import 'package:tui_khon_mobile/l10n/app_l10n.dart';
import 'package:tui_khon_mobile/l10n/locale_aware_forms.dart';
import 'support/report_debt_fixture.dart';

class FailingPreferences extends InMemorySharedPreferencesStore {
  FailingPreferences() : super.empty();
  bool fail = true;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (fail) {
      fail = false;
      return false;
    }
    return super.setValue(type, key, value);
  }
}

class RecordingScheduler extends ReminderScheduler {
  RecordingScheduler(AppLocalizations Function() localizations)
      : super(onRoute: (_) {}, localizations: localizations);
  final groups = <String, List<ReminderNotice>>{};
  int permissionRequests = 0;
  @override
  Future<void> replace(String group, List<ReminderNotice> notices) async {
    groups[group] = List.of(notices);
  }

  @override
  Future<void> requestPermission() async {
    permissionRequests++;
  }
}

class AppearanceHarness extends ConsumerWidget {
  const AppearanceHarness({super.key, required this.home});
  final Widget home;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ref.watch(appearanceProvider).theme,
        locale: ref.watch(effectiveLocaleProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => LocaleAwareForms(child: child!),
        home: home,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'failed persistence restores the state AND the preference cache; next write works',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final original = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = FailingPreferences();
    addTearDown(() => SharedPreferencesStorePlatform.instance = original);
    final controller = AppearanceController(prefs);
    addTearDown(controller.dispose);
    await expectLater(
        controller.change(theme: ThemeMode.dark), throwsStateError);
    expect(controller.state.theme, ThemeMode.system);
    expect(prefs.getString('appearance_theme'), isNull);
    await controller.change(theme: ThemeMode.dark, language: 'en');
    expect(AppearanceController(prefs).state.language, 'en');
    expect(controller.state.theme, ThemeMode.dark);
  });
  testWidgets(
      'actual auth controls keep field contents and translate existing validation errors',
      (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const ProviderScope(child: AppearanceHarness(home: LoginScreen())));
    await tester.enterText(find.byType(TextFormField).at(0), 'invalid');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('Đăng nhập').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.brightness_6_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tối').last);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(LoginScreen))).brightness,
        Brightness.dark);
    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('invalid'), findsOneWidget);
    expect(find.text('secret'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.first.controller!.text, 'invalid');
    expect(find.textContaining('Email không'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Register now'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('invalid'), findsOneWidget);
  });
  testWidgets(
      'system appearance follows device changes, explicit language stays fixed',
      (tester) async {
    final controller = AppearanceController(null);
    await controller.change(language: 'system');
    await tester.pumpWidget(ProviderScope(
        overrides: [appearanceProvider.overrideWith((ref) => controller)],
        child: const AppearanceHarness(home: LoginScreen())));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    tester.platformDispatcher.localesTestValue = [const Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(Theme.of(tester.element(find.byType(LoginScreen))).brightness,
        Brightness.dark);
    tester.platformDispatcher.localesTestValue = [const Locale('fr')];
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập'), findsWidgets);
    await controller.change(language: 'en', theme: ThemeMode.light);
    await tester.pumpAndSettle();
    tester.platformDispatcher.localesTestValue = [const Locale('vi')];
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(Theme.of(tester.element(find.byType(LoginScreen))).brightness,
        Brightness.light);
  });
  testWidgets('non-auth form errors refresh with locale without clearing edits', (tester) async {
    final appearance=AppearanceController(null);
    final field=TextEditingController();addTearDown(field.dispose);
    final key=GlobalKey<FormState>();
    await tester.pumpWidget(ProviderScope(overrides:[appearanceProvider.overrideWith((ref)=>appearance)],
      child:AppearanceHarness(home:Builder(builder:(context)=>Scaffold(body:Form(key:key,child:TextFormField(controller:field,validator:(_)=>appL10n(context).errorEmail)))))));
    await tester.enterText(find.byType(TextFormField),'draft@example');
    key.currentState!.validate();await tester.pump();
    expect(find.text(lookupAppLocalizations(const Locale('vi')).errorEmail),findsOneWidget);
    await appearance.change(language:'en',theme:ThemeMode.dark);await tester.pumpAndSettle();
    expect(find.text('Invalid email address'),findsOneWidget);
    expect(field.text,'draft@example');expect(tester.takeException(),isNull);
  });
  test('catalogs have the same keys, placeholders and plural counts', () {
    Map<String, dynamic> arb(String lang) =>
        jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
            as Map<String, dynamic>;
    final vi = arb('vi'), en = arb('en');
    expect(vi.keys.where((k) => !k.startsWith('@')).toSet(),
        en.keys.where((k) => !k.startsWith('@')).toSet());
    for (final k in vi.keys.where((k) => !k.startsWith('@'))) {
      expect((vi['@$k']?['placeholders'] as Map?)?.keys.toSet(),
          (en['@$k']?['placeholders'] as Map?)?.keys.toSet(),
          reason: k);
    }
    final l = lookupAppLocalizations(const Locale('en'));
    expect(l.repaymentHistory(1), 'Repayment history • 1 payment');
    expect(l.repaymentHistory(3), 'Repayment history • 3 payments');
    expect(l.daysRemaining(1), '1 day remaining');
    expect(l.daysRemaining(2), '2 days remaining');
    expect(l.msgTransactions68(0), '0 transactions');
    expect(CurrencyFormatter.formatVND(-1234567890, locale: 'en'),
        contains('1,234,567,890'));
    expect(CurrencyFormatter.formatVND(1234567890, locale: 'vi'),
        contains('1.234.567.890'));
  });
  test(
      'switching display preferences never changes records, outbox or CSV bytes',
      () async {
    final store = LocalStore.memory('appearance-data');
    addTearDown(store.close);
    await seedReportDebtFixture(store);
    final before = await store.pending(),
        transactions = await store.rows('transactions'),
        wallets = await store.rows('wallets'),
        categories = await store.rows('categories');
    final csv = CsvExchange.export(transactions, wallets, categories);
    final controller =
        AppearanceController(await SharedPreferences.getInstance());
    addTearDown(controller.dispose);
    for (final language in ['en', 'system', 'vi']) {
      await controller.change(language: language, theme: ThemeMode.dark);
    }
    expect(await store.pending(), before);
    expect(await store.rows('transactions'), transactions);
    expect(
        CsvExchange.export(await store.rows('transactions'),
            await store.rows('wallets'), await store.rows('categories')),
        csv);
  });
  test(
      'translated reminders retain group IDs, dates and routes; disabled groups stay disabled',
      () async {
    var language = 'vi';
    final scheduler =
        RecordingScheduler(() => lookupAppLocalizations(Locale(language)));
    final due = DateTime.now().add(const Duration(days: 10));
    final debt = DebtModel(
        id: 'debt-qa',
        type: DebtType.borrow,
        personName: 'Lan',
        amount: 100000,
        dueDate: due);
    final payable =
        Payable(id: 'bill-qa', title: 'Điện', amount: 50000, start: due);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_diary', true);
    Future<void> sync() async {
      await scheduler.syncGeneral();
      await scheduler.syncPayables([payable], {});
      await LocalDebtReminders(scheduler).sync([debt]);
    }

    await sync();
    final before = {...scheduler.groups};
    language = 'en';
    await sync();
    for (final group in before.keys) {
      final old = before[group]!, next = scheduler.groups[group]!;
      expect(
          next.map(
              (n) => (reminderNotificationId(group, n.key), n.date, n.route)),
          old.map(
              (n) => (reminderNotificationId(group, n.key), n.date, n.route)));
      expect(next.first.title, isNot(old.first.title));
    }
    expect(scheduler.groups['debts']!.first.body, contains('Lan'));
    for (final group in ['diary', 'report', 'payables', 'debts']) {
      await prefs.setBool('reminder_$group', false);
    }
    language = 'vi';
    await sync();
    expect(scheduler.groups.values.every((v) => v.isEmpty), isTrue);
    expect(scheduler.permissionRequests, 0);
  });
}
