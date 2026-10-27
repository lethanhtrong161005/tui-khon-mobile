import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/features/reports/monthly_report.dart';
import 'package:tui_khon_mobile/features/reports/monthly_ai_report.dart';
import 'package:tui_khon_mobile/features/reports/monthly_report_screen.dart';

void main() {
  final october = DateTime(2026, 10);
  MonthlyReport report(List<ReportRow> rows, {DateTime? month}) =>
      MonthlyReport.compute(month ?? october, rows, [], []);
  ReportRow tx(String id, String date, String type, int amount) => {
        'id': id,
        'wallet_id': 'cash',
        'occurred_at': date,
        'type': type,
        'amount': amount
      };
  Map<String, dynamic> response(MonthlyReport r) => {
        'period': {
          'month': reportMonthKey(r.month),
          'timezone': 'Asia/Ho_Chi_Minh'
        },
        'summary': 'Nhận xét đúng tháng',
        'insights': [],
        'grounding': r.grounding,
      };

  test(
      'empty month and previous month produce zeros, empty categories and budgets',
      () {
    final r = report([]);
    expect(
        [r.income, r.expense, r.balance, r.previousIncome, r.previousExpense],
        [0, 0, 0, 0, 0]);
    expect(r.byCategory, isEmpty);
    expect(r.budgets, isEmpty);
    expect((r.grounding['current'] as Map)['transaction_count'], 0);
  });

  test('Vietnam boundaries and previous calendar month across year/leap year',
      () {
    final r = report([
      tx('previousStart', '2025-11-30T17:00:00Z', 'income', 100),
      tx('previousEnd', '2025-12-31T16:59:59Z', 'expense', 40),
      tx('start', '2025-12-31T17:00:00Z', 'income', 200),
      tx('end', '2026-01-31T16:59:59Z', 'expense', 50),
      tx('outside', '2026-01-31T17:00:00Z', 'expense', 999),
    ], month: DateTime(2026, 1));
    expect([r.income, r.expense, r.previousIncome, r.previousExpense],
        [200, 50, 100, 40]);
    final leap = report([
      tx('leap', '2024-02-29T16:59:59Z', 'expense', 80),
      tx('march', '2024-02-29T17:00:00Z', 'income', 90),
    ], month: DateTime(2024, 3));
    expect(leap.previousExpense, 80);
    expect(leap.income, 90);
    expect(leap.expense, 0);
  });

  group('monthly AI cache and sync gate', () {
    late LocalStore store;
    setUp(() => store = LocalStore.memory('report-test-user'));
    tearDown(() => store.close());

    testWidgets(
        'saved commentary stays readable and generation disables while pending',
        (tester) async {
      final now = DateTime.now();
      final month = DateTime(now.year, now.month - 1);
      final service = MonthlyAiReports(
          store, (_) async => response(report([], month: month)));
      await service.generate(month, isCurrentAccount: () => true);
      await tester.pumpWidget(ProviderScope(
          overrides: [localStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(home: MonthlyReportScreen())));
      await tester.pumpAndSettle();
      expect(find.text('${month.month}/${month.year}'), findsOneWidget);
      expect(find.text('Nhận xét đúng tháng'), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'Tạo lại nhận xét AI');
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await store.put('transactions',
          tx('unsynced', '${reportMonthKey(month)}T00:00:00Z', 'expense', 10));
      await tester.pumpAndSettle();
      expect(find.text('Nhận xét đúng tháng'), findsOneWidget);
      expect(find.textContaining('Nhận xét đã cũ'), findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'notification initialMonth selects that calendar month and its cache',
        (tester) async {
      final selected = DateTime(2025, 12, 31, 23, 59);
      final service = MonthlyAiReports(
          store, (_) async => response(report([], month: selected)));
      await service.generate(selected, isCurrentAccount: () => true);
      await tester.pumpWidget(ProviderScope(
        overrides: [localStoreProvider.overrideWithValue(store)],
        child: MaterialApp(home: MonthlyReportScreen(initialMonth: selected)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('12/2025'), findsOneWidget);
      expect(find.text('Nhận xét đúng tháng'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('1/2026'), findsOneWidget);
      expect(find.text('Nhận xét đúng tháng'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    test('cache is scoped to account database', () async {
      final service =
          MonthlyAiReports(store, (_) async => response(report([])));
      await service.generate(october, isCurrentAccount: () => true);
      final otherStore = LocalStore.memory('other-account');
      addTearDown(otherStore.close);
      expect(
          await MonthlyAiReports(
                  otherStore, (_) async => throw StateError('offline'))
              .cached(october),
          isNull);
    });

    test(
        'sends exact month, persists successful cache and reads without network',
        () async {
      var requests = 0;
      final r = report([]);
      final service = MonthlyAiReports(store, (body) async {
        requests++;
        expect(body, {'month': '2026-10-01'});
        return response(r);
      });
      final cache =
          await service.generate(october, isCurrentAccount: () => true);
      expect(cache.isStale(r, pending: false), isFalse);
      final offline =
          MonthlyAiReports(store, (_) async => throw StateError('offline'));
      final saved = (await offline.cached(october))!;
      expect(saved.data['summary'], cache.data['summary']);
      expect(saved.fingerprint, r.fingerprint);
      expect(requests, 1);
      expect(await offline.cached(DateTime(2026, 9)), isNull);
      expect(saved.isStale(r, pending: true), isTrue);
      final changed = report([tx('new', '2026-10-02T00:00:00Z', 'expense', 1)]);
      expect(saved.isStale(changed, pending: false), isTrue);
    });

    test('pending, errored and conflicting operations block before network',
        () async {
      await store.put(
          'transactions', tx('new', '2026-10-02T00:00:00Z', 'expense', 100));
      var requests = 0;
      final service = MonthlyAiReports(store, (_) async {
        requests++;
        return response(report([]));
      });
      await expectLater(service.generate(october, isCurrentAccount: () => true),
          throwsStateError);
      final op = (await store.pending()).single;
      await store.operationError(op['op_id'] as String, 'offline');
      await expectLater(service.generate(october, isCurrentAccount: () => true),
          throwsStateError);
      await store.conflict('transactions', 'new', null, 1, false);
      await expectLater(service.generate(october, isCurrentAccount: () => true),
          throwsStateError);
      expect(requests, 0);
    });

    test(
        'rejects rolling range, cloud differences, and keeps previous success on failure',
        () async {
      final r = report([]);
      final good = MonthlyAiReports(store, (_) async => response(r));
      await good.generate(october, isCurrentAccount: () => true);
      final badMonth = MonthlyAiReports(
          store,
          (_) async => {
                ...response(r),
                'period': {'range': 30}
              });
      await expectLater(
          badMonth.generate(october, isCurrentAccount: () => true),
          throwsStateError);
      final differing = MonthlyAiReports(
          store,
          (_) async => response(
              report([tx('cloud', '2026-10-02T00:00:00Z', 'expense', 10)])));
      await expectLater(
          differing.generate(october, isCurrentAccount: () => true),
          throwsStateError);
      final failed = MonthlyAiReports(
          store, (_) async => throw StateError('network failed'));
      await expectLater(failed.generate(october, isCurrentAccount: () => true),
          throwsStateError);
      expect((await good.cached(october))!.fingerprint, r.fingerprint);
    });

    test('changes during request or account switch prevent caching', () async {
      final r = report([]);
      final changing = MonthlyAiReports(store, (_) async {
        await store.put(
            'transactions', tx('new', '2026-10-02T00:00:00Z', 'expense', 10));
        return response(r);
      });
      await expectLater(
          changing.generate(october, isCurrentAccount: () => true),
          throwsStateError);
      expect(await changing.cached(october), isNull);
      var calls = 0;
      final switched = MonthlyAiReports(store, (_) async {
        calls++;
        return response(r);
      });
      await expectLater(
          switched.generate(october, isCurrentAccount: () => false),
          throwsStateError);
      expect(calls, 0);
    });
  });
}
