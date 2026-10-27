import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/features/data_exchange/csv_exchange.dart';
import 'package:tui_khon_mobile/features/reports/monthly_report.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/features/data_exchange/csv_import_plan.dart';

void main() {
  List<String> row(
          {String id = '',
          String amount = '123',
          String note = 'Ăn uống, "ngon"\nHôm nay'}) =>
      [
        id,
        'expense',
        amount,
        '2026-10-15T12:00:00+07:00',
        'Tiền mặt',
        'Ăn uống',
        note,
        'manual'
      ];
  List<int> file(List<List<String>> rows) =>
      utf8.encode(CsvExchange.encode([CsvExchange.columns, ...rows]));

  test('UTF8 BOM, quoted multiline Vietnamese and formula-safe round trip', () {
    final csv =
        CsvExchange.encode([CsvExchange.columns, row(note: '=SUM(A1)')]);
    expect(utf8.encode(csv).take(3), [239, 187, 191]);
    expect(csv, contains("'=SUM(A1)"));
    expect(CsvExchange.decode(file([row()]))[1], row());
    expect(CsvExchange.decode(utf8.encode(csv))[1][6], '=SUM(A1)');
  });
  test('malformed CSV and invalid UTF8 rejected', () {
    expect(() => CsvExchange.decode(utf8.encode('"unclosed')),
        throwsFormatException);
    expect(() => CsvExchange.decode([255]), throwsFormatException);
    expect(() => CsvExchange.decode(utf8.encode('"x"junk')),
        throwsFormatException);
  });
  test('row limit counts logical multiline records', () {
    expect(
        CsvExchange.preview(file(List.generate(10000, (_) => row())), [])
            .length,
        10000);
    expect(
        () => CsvExchange.preview(file(List.generate(10001, (_) => row())), []),
        throwsFormatException);
  });
  test('validates amount, schema, timezone and provenance', () {
    expect(
        CsvExchange.preview(file([row(amount: '-1'), row(amount: '1.5')]), [])
            .every((r) => r.error != null),
        isTrue);
    final noZone = row()..[3] = '2026-10-01';
    final badSource = row()..[7] = 'unknown';
    expect(
        CsvExchange.preview(file([noZone, badSource]), [])
            .every((r) => r.error != null),
        isTrue);
    expect(() => CsvExchange.preview(utf8.encode('foo,bar'), []),
        throwsFormatException);
  });
  test(
      'debt CSV round trips as a standalone transaction without payment linkage',
      () {
    final debt = {
      'id': '12345678-1234-4234-8234-123456789abc',
      'type': 'expense',
      'amount': 100,
      'occurred_at': '2026-10-01T00:00:00Z',
      'wallet_id': 'cash',
      'source': 'debt',
      'debt_id': 'private-debt',
      'debt_payment_id': 'private-payment'
    };
    final csv = CsvExchange.export([
      debt
    ], [
      {'id': 'cash', 'name': 'Tiền mặt'}
    ], []);
    final parsed = CsvExchange.preview(utf8.encode(csv), []).single;
    expect(parsed.error, isNull);
    expect(parsed.values['source'], 'debt');
    expect(parsed.values.containsKey('debt_id'), isFalse);
    expect(parsed.values.containsKey('debt_payment_id'), isFalse);
    for (final source in ['recurring', 'split']) {
      final invalid = row()..[7] = source;
      expect(CsvExchange.preview(file([invalid]), []).single.error, isNotNull);
    }
  });

  test('export filters combine inclusive Vietnam dates, type and source', () {
    final rows = <JsonRow>[
      {
        'id': 'start',
        'type': 'expense',
        'source': 'debt',
        'occurred_at': '2026-09-30T17:00:00Z'
      },
      {
        'id': 'end',
        'type': 'expense',
        'source': 'debt',
        'occurred_at': '2026-10-31T16:59:59Z'
      },
      {
        'id': 'outside',
        'type': 'expense',
        'source': 'debt',
        'occurred_at': '2026-10-31T17:00:00Z'
      },
      {
        'id': 'income',
        'type': 'income',
        'source': 'debt',
        'occurred_at': '2026-10-02T00:00:00Z'
      },
      {
        'id': 'manual',
        'type': 'expense',
        'source': 'manual',
        'occurred_at': '2026-10-02T00:00:00Z'
      },
    ];
    final filter = CsvExportFilter(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
        type: 'expense',
        source: 'debt');
    expect(filter.apply(rows).map((r) => r['id']), ['start', 'end']);
    expect(const CsvExportFilter().apply(rows), rows);
  });

  test(
      'mapped 10-minute duplicates match existing and selected batch; selection controls writes',
      () async {
    final store = LocalStore.memory('csv-user');
    addTearDown(store.close);
    const oldId = '12345678-1234-4234-8234-123456789abc';
    await store.put('transactions', {
      'id': oldId,
      'type': 'expense',
      'amount': 123,
      'wallet_id': 'cash',
      'occurred_at': '2026-10-15T05:00:00Z',
      'note': 'different note',
      'source': 'manual'
    });
    final records = [
      row(note: 'existing within 10m')..[3] = '2026-10-15T12:09:00+07:00',
      row(amount: '456', note: 'batch first'),
      row(amount: '456', note: 'batch duplicate')
        ..[3] = '2026-10-15T12:10:00+07:00',
      row(amount: '789', note: 'unselected'),
      row(amount: '123', note: 'outside window')
        ..[3] = '2026-10-15T12:10:01+07:00',
    ];
    final preview = CsvExchange.preview(file(records), []);
    final planner = CsvImportPlanner(store);
    Future<CsvImportPlan> build(Set<int> selected, bool skip) =>
        planner.build(preview, selected,
            resolve: (entity, _) => entity == 'wallets' ? 'cash' : 'food',
            allowCreation: false,
            skipDuplicates: skip);
    final plan = await build({2, 3, 4, 6}, true);
    expect(plan.duplicates, {2, 4});
    expect(plan.transactionCount, 2);
    expect(
        plan.mutations
            .where((m) => m.entity == 'transactions')
            .map((m) => m.row['note']),
        ['batch first', 'outside window']);
    expect((await build({2, 3, 4}, false)).transactionCount, 3);
    // Deselecting the first candidate makes the second batch row importable.
    expect((await build({4}, true)).transactionCount, 1);
    final existingPreview = CsvExchange.preview(file([row(id: oldId)]), []);
    final existing = await planner.build(existingPreview, {2},
        resolve: (entity, _) => 'cash',
        allowCreation: true,
        skipDuplicates: false);
    expect(existing.transactionCount, 0);
    expect(existing.existingIds, {2});
  });
  test('duplicates and differing existing IDs never become normal inserts', () {
    const id = '12345678-1234-4234-8234-123456789abc';
    final base = CsvExchange.preview(file([row(id: id)]), []).single.values;
    final result = CsvExchange.preview(
        file([row(id: id), row(id: id, amount: '456'), row(), row()]), [base]);
    expect(result[0].duplicate, isTrue);
    expect(result[1].conflict, isTrue);
    expect(result[3].duplicate, isTrue);
  });
  test('monthly local totals, previous, category budgets, stable fingerprints',
      () {
    final tx = <JsonRow>[
      {
        'id': 'a',
        'type': 'expense',
        'amount': 100,
        'occurred_at': DateTime(2026, 10, 1).toUtc().toIso8601String(),
        'category_id': 'food'
      },
      {
        'id': 'b',
        'type': 'income',
        'amount': 300,
        'occurred_at': DateTime(2026, 10, 31, 23, 59).toUtc().toIso8601String()
      },
      {
        'id': 'c',
        'type': 'expense',
        'amount': 70,
        'occurred_at': DateTime(2026, 9, 30).toUtc().toIso8601String()
      },
      {
        'id': 'd',
        'type': 'expense',
        'amount': 999,
        'occurred_at': DateTime(2026, 11, 1).toUtc().toIso8601String()
      },
    ];
    final categories = <JsonRow>[
      {'id': 'food', 'name': 'Ăn uống'}
    ];
    final budgets = <JsonRow>[
      {
        'id': 'budget',
        'month': '2026-10-01',
        'category_id': 'food',
        'limit_amount': 80
      }
    ];
    MonthlyReport compute(List<JsonRow> rows) =>
        MonthlyReport.compute(DateTime(2026, 10), rows, categories, budgets);
    final report = compute(tx);
    expect(report.income, 300);
    expect(report.expense, 100);
    expect(report.balance, 200);
    expect(report.previousExpense, 70);
    expect(report.byCategory['Ăn uống'], 100);
    expect(report.budgets.single['spent'], 100);
    expect(compute(tx.reversed.toList()).fingerprint, report.fingerprint);
    expect(
        compute([
          ...tx,
          {...tx.first, 'id': 'new'}
        ]).fingerprint,
        isNot(report.fingerprint));
  });
}
