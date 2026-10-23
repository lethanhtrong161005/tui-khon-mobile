import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/core/services/app_lock_service.dart';
import 'package:tui_khon_mobile/core/services/debt_reminder_service.dart';
import 'package:tui_khon_mobile/core/services/voice_input_service.dart';
import 'package:tui_khon_mobile/core/supabase/supabase_providers.dart';
import 'package:tui_khon_mobile/features/advisor/data/advisor_repository.dart';
import 'package:tui_khon_mobile/features/advisor/presentation/advisor_screen.dart';
import 'package:tui_khon_mobile/features/auth/models/user_profile.dart';
import 'package:tui_khon_mobile/features/auth/presentation/auth_gate.dart';
import 'package:tui_khon_mobile/features/auth/providers/auth_providers.dart';
import 'package:tui_khon_mobile/features/home/models/transaction_model.dart';
import 'package:tui_khon_mobile/features/home/providers/home_providers.dart';
import 'package:tui_khon_mobile/features/planning/data/planning_repository.dart';
import 'package:tui_khon_mobile/features/planning/presentation/planning_screen.dart';
import 'package:tui_khon_mobile/features/quick_record/data/quick_record_repository.dart';
import 'package:tui_khon_mobile/features/quick_record/presentation/quick_record_screen.dart';
import 'package:tui_khon_mobile/features/settings/presentation/categories_screen.dart';
import 'package:tui_khon_mobile/features/transactions/presentation/transaction_history_screen.dart';

import 'fakes.dart';
import 'support/local_wallet_repository.dart';

void main() {
  late LocalWalletRepository wallet;
  late FakePlanningRepository planning;
  late FakeAdvisorRepository advisor;
  late FakeDebtReminders reminders;
  late FakeAppLock lock;

  setUp(() {
    wallet = LocalWalletRepository();
    planning = FakePlanningRepository();
    advisor = FakeAdvisorRepository();
    reminders = FakeDebtReminders();
    lock = FakeAppLock();
  });

  List<Override> overrides({String? userId = 'user-1'}) => [
        currentUserIdProvider.overrideWithValue(userId),
        walletRepositoryProvider.overrideWithValue(wallet),
        quickRecordRepositoryProvider.overrideWithValue(FakeQuickRecordRepository()),
        planningRepositoryProvider.overrideWithValue(planning),
        advisorRepositoryProvider.overrideWithValue(advisor),
        debtRemindersProvider.overrideWithValue(reminders),
        appLockProvider.overrideWithValue(lock),
        voiceInputProvider.overrideWithValue(FakeVoiceInput('Đổ xăng 80k')),
        profileProvider.overrideWith(
          (ref) async => const UserProfile(id: 'user-1', email: 'quan@test.vn', displayName: 'Minh Quân'),
        ),
      ];

  Future<void> pumpApp(WidgetTester tester, Widget home, {String? userId = 'user-1'}) async {
    // Tall viewport so bottom sheets fit. Kept 800 wide: the test font draws every
    // glyph as a full square, so phone widths report overflows real fonts don't have.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: overrides(userId: userId), child: MaterialApp(home: home)));
    await tester.pumpAndSettle();
  }

  testWidgets('AuthGate shows the login screen without a session', (tester) async {
    await pumpApp(tester, const AuthGate(), userId: null);

    expect(find.text('Đăng Nhập'), findsOneWidget);
    expect(find.text('Tiếp tục với Google'), findsOneWidget);
  });

  testWidgets('App lock hides the dashboard until biometrics pass', (tester) async {
    lock
      ..enabled = true
      ..passes = false;
    await pumpApp(tester, const AuthGate());
    expect(find.text('Túi Khôn đang khoá'), findsOneWidget);
    expect(lock.prompts, 1); // asked automatically

    lock.passes = true;
    await tester.tap(find.text('Mở khoá'));
    await tester.pumpAndSettle();
    expect(find.text('Túi Khôn đang khoá'), findsNothing);
    expect(find.text('Minh Quân'), findsWidgets);
  });

  testWidgets('Dashboard renders data and asks about due debts', (tester) async {
    await pumpApp(tester, const AuthGate());

    // Opening the app re-schedules device reminders and asks about Lan's debt due today.
    expect(reminders.lastSynced, hasLength(2));
    expect(find.text('Khoản nợ đã đến hạn'), findsOneWidget);
    await tester.tap(find.text('Đã nhận'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(planning.settleCalls, [('d1', null, false)]);

    expect(find.text('Minh Quân'), findsOneWidget);
    // 37.000.000 opening balances + 15.000.000 income − 4.780.000 expenses
    expect(find.textContaining('47.300.000'), findsOneWidget);
    expect(find.text('Ăn phở Thìn Lò Đúc'), findsOneWidget);
    expect(find.textContaining('PRO'), findsNothing);
  });

  testWidgets('Quick record turns text into a card and saves it', (tester) async {
    await pumpApp(tester, const QuickRecordScreen());

    await tester.enterText(find.byType(TextField), 'Ăn bún chả 45k');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.textContaining('45.000'), findsOneWidget);

    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu vào sổ'), findsOneWidget);
    final saved = await wallet.fetchRecentTransactions(limit: 1);
    expect((saved.single.amount, saved.single.categoryName), (45000, 'Ăn uống'));
  });

  testWidgets('Voice quick action sends the transcript as a voice record', (tester) async {
    await pumpApp(tester, const QuickRecordScreen(initialAction: QuickRecordStart.voice));

    expect(find.text('"Đổ xăng 80k"'), findsOneWidget);
    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();
    final saved = await wallet.fetchRecentTransactions(limit: 1);
    expect((saved.single.source, saved.single.amount), (TransactionSource.voice, 80000));
  });

  testWidgets('Budgets: add a month-wide budget and see progress', (tester) async {
    await pumpApp(tester, const PlanningScreen());

    await tester.tap(find.text('Thêm ngân sách'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Hạn mức trong tháng (VND)'), '1000000');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Tổng chi tiêu tháng'), findsOneWidget);
    expect(find.text('12%'), findsOneWidget); // 120.000 / 1.000.000
  });

  testWidgets('Debt book: partial payment and new debt', (tester) async {
    await pumpApp(tester, const PlanningScreen(initialTab: PlanningTab.debts));

    expect(find.text('Lan nợ tôi'), findsOneWidget);
    expect(find.text('Tôi nợ Minh'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert).first); // Minh (Tôi nợ) is listed first
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ghi trả một phần'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền đã trả'), '500000');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(planning.settleCalls, [('d2', 500000, false)]);
    expect(find.textContaining('1.500.000'), findsWidgets);

    await tester.tap(find.text('Thêm khoản nợ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tôi nợ ai?'), 'Hương');
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền (VND)'), '300000');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Tôi nợ Hương'), findsOneWidget);
  });

  testWidgets('Goals: saving up to the target completes the goal', (tester) async {
    await pumpApp(tester, const PlanningScreen(initialTab: PlanningTab.goals));

    expect(find.text('80%'), findsOneWidget);
    await tester.tap(find.text('Nạp thêm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '200000');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Đã hoàn thành 🎉'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('History: search and swipe to delete', (tester) async {
    await pumpApp(tester, const TransactionHistoryScreen());

    expect(find.text('Ăn phở Thìn Lò Đúc'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Tìm theo ghi chú...'), 'phở');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Highlands Coffee'), findsNothing);

    await tester.drag(find.text('Ăn phở Thìn Lò Đúc'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();
    expect(find.text('Ăn phở Thìn Lò Đúc'), findsNothing);
    expect((await wallet.fetchRecentTransactions(limit: 20)).any((t) => t.title == 'Ăn phở Thìn Lò Đúc'), isFalse);
  });

  testWidgets('Categories: add a new expense category', (tester) async {
    await pumpApp(tester, const CategoriesScreen());

    await tester.tap(find.text('Thêm danh mục'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tên danh mục'), 'Thú cưng');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Thú cưng'), findsOneWidget);
    expect((await wallet.fetchCategories()).any((c) => c.name == 'Thú cưng' && c.type == TransactionType.expense),
        isTrue);
  });

  testWidgets('Advisor shows the AI report and spending breakdown', (tester) async {
    await pumpApp(tester, const AdvisorScreen());

    expect(find.text('Tháng này bạn chi nhiều hơn cho ăn uống.'), findsOneWidget);
    expect(find.text('75% tổng chi'), findsOneWidget);
    await tester.tap(find.text('90 ngày qua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 ngày qua'));
    await tester.pumpAndSettle();
    expect(advisor.analyzeCalls, 2); // 30-day report reused from cache
  });
}
