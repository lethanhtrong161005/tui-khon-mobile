import 'dart:io';
import 'dart:async';
import 'package:tui_khon_mobile/core/supabase/supabase_providers.dart';
import 'package:tui_khon_mobile/features/planning/data/planning_repository.dart';
import 'package:tui_khon_mobile/features/planning/models/planning_models.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/core/offline/offline_planning_repository.dart';
import 'package:tui_khon_mobile/core/theme/app_theme.dart';
import 'package:tui_khon_mobile/core/services/debt_reminder_service.dart';
import 'package:tui_khon_mobile/features/planning/presentation/debt_history_screen.dart';
import 'package:tui_khon_mobile/features/planning/presentation/debt_payment_sheet.dart';
import 'package:tui_khon_mobile/features/reports/monthly_report.dart';
import 'package:tui_khon_mobile/features/reports/monthly_report_screen.dart';
import 'package:tui_khon_mobile/features/reports/report_widgets.dart';
import 'support/report_debt_fixture.dart';
import 'fakes.dart';

void main() {
  late LocalStore store;
  final boundary = GlobalKey();
  setUpAll(() async {
    await (FontLoader('PlusJakartaSans')
          ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(() async {
    store = LocalStore.memory('ui-report');
    await seedReportDebtFixture(store);
  });
  tearDown(() => store.close());
  Future<void> pump(WidgetTester tester, Widget home,
      {Size size = const Size(390, 844),
      double scale = 1,
      double keyboard = 0,
      List<Override> extra = const []}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 28, bottom: 16);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: ProviderScope(
            overrides: [
              localStoreProvider.overrideWithValue(store),
              currentUserIdProvider.overrideWithValue(store.userId),
              ...extra,
              debtRemindersProvider.overrideWithValue(FakeDebtReminders()),
            ],
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                home: home,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!)))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final dir = Platform.environment['TUIKHON_UI_PREVIEW_DIR'];
    if (dir == null) return;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(dir).create(recursive: true);
      await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in [
    const Size(390, 844),
    const Size(411, 914),
    const Size(320, 568)
  ]) {
    for (final scale in [1.0, 1.4, 2.0]) {
      testWidgets('debt ${size.width} / $scale and payment form',
          (tester) async {
        final debt =
            (await OfflinePlanningRepository(store).fetchDebts()).single;
        await pump(tester, DebtHistoryScreen(debt: debt),
            size: size, scale: scale);
        expect(find.text('Chi tiết khoản nợ'), findsOneWidget);
        if (scale == 1 && size.width > 320)
          await capture(tester, 'debt-${size.width.toInt()}');
        await tester.tap(find.text('Ghi trả nợ'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('payment-amount')), findsOneWidget);
        await tester.enterText(
            find.byKey(const Key('payment-amount')), '2500000');
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Ghi trả nợ').last);
        await tester.tap(find.widgetWithText(FilledButton, 'Ghi trả nợ').last);
        await tester.pumpAndSettle();
        expect(find.textContaining('Số tiền vượt quá'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (scale == 1 && size.width == 390)
          await capture(tester, 'payment-validation');
        await tester.pumpWidget(const SizedBox());
      });
      testWidgets('report ${size.width} / $scale scrolls through all sections',
          (tester) async {
        await pump(
            tester, MonthlyReportScreen(initialMonth: DateTime(2026, 10)),
            size: size, scale: scale);
        if (scale == 1 && size.width > 320)
          await capture(tester, 'report-${size.width.toInt()}');
        await tester.scrollUntilVisible(find.text('Góc nhìn từ AI'), 180,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('keyboard keeps form scrollable at 200% text', (tester) async {
    final debt = (await OfflinePlanningRepository(store).fetchDebts()).single;
    await pump(tester, Scaffold(body: DebtPaymentSheet(debt: debt)),
        size: const Size(320, 568), scale: 2, keyboard: 260);
    await tester.enterText(find.byKey(const Key('payment-amount')), '123');
    await tester.scrollUntilVisible(find.text('Ghi trả nợ').last, 180,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'report handles negative balance, 15+ categories, donut sum and budget boundaries',
      () async {
    final report = MonthlyReport.compute(
        DateTime(2026, 10),
        await store.rows('transactions'),
        await store.rows('categories'),
        await store.rows('budgets'));
    final slices = reportSlices(report);
    expect(slices.length, 6);
    expect(slices.last['name'], 'Khác');
    expect(slices.fold<int>(0, (n, r) => n + (r['amount'] as int)),
        report.expense);
    expect(reportSlices(report, all: true).length,
        16); // Includes linked debt expense without a category.
    expect(budgetState(79, 100), 'Trong hạn mức');
    expect(budgetState(80, 100), 'Gần chạm hạn mức');
    expect(budgetState(100, 100), 'Đã chạm hạn mức');
    expect(budgetState(101, 100), contains('Vượt'));
    expect(reportMoney(-100), startsWith('-'));
    expect(reportMoney(100, signed: true), startsWith('+'));
  });
  testWidgets('lend empty history, missing due date and settled CTA',
      (tester) async {
    final repo = OfflinePlanningRepository(store);
    await repo.saveDebt(const DebtModel(
        id: 'empty-lend',
        type: DebtType.lend,
        personName: 'Minh',
        amount: 100));
    var debt =
        (await repo.fetchDebts()).firstWhere((d) => d.id == 'empty-lend');
    await pump(tester, DebtHistoryScreen(debt: debt));
    expect(find.text('Ghi thu nợ'), findsOneWidget);
    expect(find.text('Chưa đặt hạn'), findsOneWidget);
    expect(find.text('Chưa có lịch sử thanh toán'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await repo.settleDebt('empty-lend');
    debt = (await repo.fetchDebts()).firstWhere((d) => d.id == 'empty-lend');
    await pump(tester, DebtHistoryScreen(debt: debt));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Đã tất toán'))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('full budget list opens selected month rather than current month',
      (tester) async {
    await pump(tester, MonthlyReportScreen(initialMonth: DateTime(2026, 9)));
    await tester.scrollUntilVisible(find.text('Xem tất cả'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Xem tất cả'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('Ngân sách · 9/2026'), findsOneWidget);
    expect(find.text('Ngân sách tổng'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'AI loading blocks duplicate requests; configuration error allows retry',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    await pump(tester, MonthlyReportScreen(initialMonth: DateTime(2026, 10)),
        extra: [
          monthlyAiRequestProvider.overrideWithValue((body) {
            calls++;
            return pending.future;
          })
        ]);
    await tester.scrollUntilVisible(find.text('Tạo nhận xét AI'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Tạo nhận xét AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo nhận xét AI'));
    await tester.pump();
    expect(find.text('Đang tạo nhận xét…'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Đang tạo nhận xét…'))
            .onPressed,
        isNull);
    expect(calls, 1);
    pending.completeError(StateError('AI chưa được cấu hình trên server'));
    await tester.pumpAndSettle();
    expect(find.text('AI chưa được cấu hình trên server'), findsOneWidget);
    expect(find.text('Tạo nhận xét AI'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('payment busy, inline validation, server error and legacy switch',
      (tester) async {
    final debt = (await OfflinePlanningRepository(store).fetchDebts()).single;
    final repository = DelayedPaymentRepository(store);
    await pump(tester, Scaffold(body: DebtPaymentSheet(debt: debt)),
        extra: [planningRepositoryProvider.overrideWithValue(repository)]);
    await tester.enterText(find.byKey(const Key('payment-amount')), '200');
    await tester.tap(find.widgetWithText(FilledButton, 'Ghi trả nợ'));
    await tester.pump();
    expect(find.text('Đang lưu…'), findsOneWidget);
    expect(repository.calls, 1);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Đang lưu…'))
            .onPressed,
        isNull);
    repository.result.completeError(StateError('Không thể lưu lúc này'));
    await tester.pumpAndSettle();
    expect(find.text('Không thể lưu lúc này'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('payment-amount')))
            .controller!
            .text,
        '200');
    await tester.pumpWidget(const SizedBox());
    await pump(
        tester,
        Scaffold(
            body: DebtPaymentSheet(debt: debt, payment: {
          'id': 'legacy',
          'amount': 50,
          'is_legacy': true,
          'paid_at': '2026-01-01T00:00:00Z'
        })));
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

class DelayedPaymentRepository extends OfflinePlanningRepository {
  DelayedPaymentRepository(super.store);
  final result = Completer<void>();
  int calls = 0;
  @override
  Future<void> settleDebt(String id,
      {int? amount,
      bool recordTransaction = false,
      DateTime? paidAt,
      String? note,
      String? walletId}) {
    calls++;
    return result.future;
  }
}
