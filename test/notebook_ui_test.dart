import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/core/services/app_lock_service.dart';
import 'package:tui_khon_mobile/core/services/debt_reminder_service.dart';
import 'package:tui_khon_mobile/core/services/voice_input_service.dart';
import 'package:tui_khon_mobile/core/supabase/supabase_providers.dart';
import 'package:tui_khon_mobile/core/theme/app_theme.dart';
import 'package:tui_khon_mobile/features/advisor/data/advisor_repository.dart';
import 'package:tui_khon_mobile/features/auth/models/user_profile.dart';
import 'package:tui_khon_mobile/features/auth/providers/auth_providers.dart';
import 'package:tui_khon_mobile/features/home/models/transaction_model.dart';
import 'package:tui_khon_mobile/features/home/models/monthly_summary.dart';
import 'package:tui_khon_mobile/features/home/presentation/home_screen.dart';
import 'package:tui_khon_mobile/features/home/providers/home_providers.dart';
import 'package:tui_khon_mobile/features/planning/data/planning_repository.dart';
import 'package:tui_khon_mobile/features/quick_record/data/quick_record_repository.dart';
import 'package:tui_khon_mobile/features/quick_record/presentation/quick_record_screen.dart';
import 'package:tui_khon_mobile/features/statistics/presentation/statistics_screen.dart';
import 'fakes.dart';
import 'support/local_wallet_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final boundary = GlobalKey();
  late LocalWalletRepository wallet;
  late FakePlanningRepository planning;
  setUpAll(() async {
    final font = FontLoader('PlusJakartaSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() {
    wallet = LocalWalletRepository();
    planning = FakePlanningRepository()..debts.clear();
    planning.budgets.addAll(const [
      BudgetProgress(id: 'total', limitAmount: 10000000, spent: 5350000),
      BudgetProgress(
          id: 'food',
          categoryId: 'cat-food',
          categoryName: 'Ăn uống',
          limitAmount: 3000000,
          spent: 2030000),
    ]);
  });

  List<Override> overrides() => [
        localStoreProvider.overrideWithValue(null),
        sessionProvider.overrideWithValue(null),
        currentUserIdProvider.overrideWithValue('ui-user'),
        walletRepositoryProvider.overrideWithValue(wallet),
        planningRepositoryProvider.overrideWithValue(planning),
        quickRecordRepositoryProvider
            .overrideWithValue(FakeQuickRecordRepository()),
        advisorRepositoryProvider.overrideWithValue(FakeAdvisorRepository()),
        debtRemindersProvider.overrideWithValue(FakeDebtReminders()),
        appLockProvider.overrideWithValue(FakeAppLock()),
        voiceInputProvider.overrideWithValue(FakeVoiceInput('Cà phê 35k')),
        profileProvider.overrideWith((ref) async => const UserProfile(
            id: 'ui-user',
            email: 'test@example.com',
            displayName: 'Hoàng Phúc')),
      ];

  Future<void> pump(WidgetTester tester,
      {Widget home = const HomeScreen(),
      double width = 390,
      double scale = 1}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 28, bottom: 16);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: ProviderScope(
            overrides: overrides(),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              home: home,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
            ))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  // Optional local render artifacts, kept outside the repository. These are
  // fixture screenshots, not evidence of a real Supabase/AI integration run.
  Future<void> capture(WidgetTester tester, String name) async {
    final directory = Platform.environment['TUIKHON_UI_PREVIEW_DIR'];
    if (directory == null) return;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
      'phone navigation, plus menu and manual entry save through repository',
      (tester) async {
    await pump(tester);
    await capture(tester, 'home');
    expect(find.text('Tổng chi tiêu tháng ${DateTime.now().month}'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Mở menu thêm'));
    await tester.pumpAndSettle();
    expect(find.text('Ghi nhanh AI'), findsOneWidget);
    expect(find.text('Quét hóa đơn'), findsOneWidget);
    await capture(tester, 'plus-menu');
    await tester.tap(find.text('Thêm chi tiêu'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Số tiền (VND)'), '65000');
    await tester.tap(find.text('Ăn uống').last);
    await tester.pumpAndSettle();
    await capture(tester, 'manual-entry');
    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();
    expect(
        (await wallet.fetchRecentTransactions(limit: 1)).single.amount, 65000);
    await tester.tap(find.text('Thống kê').last);
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.byType(StatisticsScreen)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.text('Chi tiêu theo thời gian'), findsOneWidget);
    await capture(tester, 'statistics');
    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiêu theo thời gian'), findsNothing);
    await tester.tap(find.byTooltip('Tháng trước'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có chi tiêu trong tháng này.'), findsOneWidget);
    await tester.tap(find.text('Kế hoạch').last);
    await tester.pumpAndSettle();
    await capture(tester, 'budgets');
    expect(find.text('Thêm ngân sách'), findsOneWidget);
    await tester.tap(find.byTooltip('Mở menu thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giao dịch'));
    await tester.pumpAndSettle();
    await capture(tester, 'history');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cá nhân').last);
    await tester.pumpAndSettle();
    expect(find.text('Dữ liệu & Đồng bộ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'AI composer has an explicit send button and preserves draft confirmation',
      (tester) async {
    await pump(tester, home: const QuickRecordScreen());
    await capture(tester, 'quick-ai');
    await tester.enterText(find.byType(TextField), 'Ăn bún chả 45k');
    await tester.pump();
    await tester.tap(find.byTooltip('Gửi ghi chép'));
    await tester.pumpAndSettle();
    expect(find.text('Lưu giao dịch'), findsOneWidget);
    expect((await wallet.fetchRecentTransactions()).length, 5);
    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();
    expect(
        (await wallet.fetchRecentTransactions(limit: 1)).single.amount, 45000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small phone with larger text can open the full action menu',
      (tester) async {
    await pump(tester, width: 320, scale: 1.4);
    await tester.tap(find.byTooltip('Mở menu thêm'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nhắc ghi chép'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Đóng menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thống kê').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('statistics includes more than 500 rows and groups by category ID',
      () async {
    final now = DateTime.now();
    for (var i = 0; i < 501; i++) {
      await wallet.addTransaction(TransactionDraft(
          type: TransactionType.expense,
          amount: 1000,
          walletId: 'wallet-cash',
          categoryId: 'cat-food',
          occurredAt: now));
    }
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    final result = await container
        .read(statisticsProvider(DateTime(now.year, now.month)).future);
    expect(
        result.categories.firstWhere((c) => c.id == 'cat-food').amount, 621000);
    expect(result.categories.fold<int>(0, (s, c) => s + c.amount),
        result.summary.expense);
  });
}
