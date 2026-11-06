import 'package:tui_khon_mobile/features/home/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/features/reminders/models/payable.dart';
import 'package:tui_khon_mobile/features/reminders/data/payable_repository.dart';
import 'package:tui_khon_mobile/features/reminders/data/reminder_scheduler.dart';

void main() {
  test('payable notes round trip, trim and clear', () {
    final payable = Payable(
        id: 'note',
        title: 'Rent',
        amount: 100,
        start: DateTime(2026),
        note: '  Transfer reference 123  ');
    expect(Payable.fromJson(payable.toJson()).note, 'Transfer reference 123');
    expect(
        Payable(
                id: 'note',
                title: 'Rent',
                amount: 100,
                start: DateTime(2026),
                note: ' ')
            .toJson()['note'],
        isNull);
    expect(Payable.fromJson({...payable.toJson(), 'note': null}).note, isNull);
  });
  test('monthly recurrence clamps then returns to original day', () {
    final p = Payable(
        id: 'rent',
        title: 'Rent',
        amount: 10,
        start: DateTime(2028, 1, 31),
        frequency: PayableFrequency.monthly);
    expect(p.occurrence(1), DateTime(2028, 2, 29));
    expect(p.occurrence(2), DateTime(2028, 3, 31));
    expect(p.occurrence(13), DateTime(2029, 2, 28));
    expect(
        p.occurrenceId(p.occurrence(1)), p.occurrenceId(DateTime(2028, 2, 29)));
  });
  test('weekly and one-time schedules', () {
    final weekly = Payable(
        id: 'w',
        title: 'W',
        amount: 1,
        start: DateTime(2026, 12, 29),
        frequency: PayableFrequency.weekly);
    expect(weekly.occurrence(1), DateTime(2027, 1, 5));
    final once = Payable(id: 'o', title: 'O', amount: 1, start: DateTime(2026));
    expect(once.through(DateTime(2027)).length, 1);
  });
  test('notification groups have disjoint stable ID ranges', () {
    final ids = [
      for (final g in ['debts', 'payables', 'diary', 'report'])
        reminderNotificationId(g, 'same')
    ];
    expect(ids.toSet().length, 4);
    expect(reminderNotificationId('debts', 'same'), ids.first);
  });
  test('payable confirmation is idempotent and transaction is optional',
      () async {
    final store = LocalStore.memory('test');
    addTearDown(store.close);
    final service = PayablePayments(store);
    final p = Payable(
        id: 'p',
        title: 'Rent',
        amount: 50,
        start: DateTime(2026, 1, 1),
        frequency: PayableFrequency.monthly);
    await Future.wait([
      service.markPaid(p, p.start),
      PayablePayments(store).markPaid(p, p.start)
    ]);
    await service.markPaid(p, p.start, walletId: 'wallet');
    expect((await store.rows('payable_occurrences')).length, 1);
    expect(await store.rows('transactions'), isEmpty);
    await service.markPaid(p, p.occurrence(1), walletId: 'wallet');
    final occurrence = (await store.rows('payable_occurrences'))
        .lastWhere((r) => r['due_date'] == '2026-02-01');
    expect(occurrence['record_transaction'], true);
    expect(occurrence['amount'], 50);
    final operations = await store.pending();
    expect(operations.where((r) => r['entity'] == 'transactions'), isEmpty);
  });
  test(
      'debt payment edits and undo update debt and linked transaction atomically',
      () async {
    final store = LocalStore.memory('test');
    addTearDown(store.close);
    await store.setMeta('bootstrapped', 'true');
    await store.put('debts',
        {'id': 'd', 'type': 'borrow', 'person_name': 'Lan', 'amount': 100});
    final row = {
      'id': 'payment',
      'debt_id': 'd',
      'amount': 40,
      'paid_at': '2026-10-28',
      'record_transaction': true,
      'wallet_id': 'w',
      'transaction_id': 'tx'
    };
    await store.put('debt_payments', row);
    expect((await store.rows('debts')).single['paid_amount'], 40);
    expect((await store.rows('transactions')).single['amount'], 40);
    await store.put('debt_payments', {...row, 'amount': 60});
    expect((await store.rows('transactions')).single['amount'], 60);
    await expectLater(
        store.put('debt_payments', {...row, 'amount': 101}), throwsStateError);
    expect((await store.rows('debts')).single['paid_amount'], 60);
    await store.remove('debt_payments', 'payment');
    expect((await store.rows('debts')).single['paid_amount'], 0);
    expect(await store.rows('transactions'), isEmpty);
  });
  test('legacy history can edit amount/date and undo without a transaction',
      () async {
    final store = LocalStore.memory('test');
    addTearDown(store.close);
    await store.setMeta('bootstrapped', 'true');
    await store.put('debts',
        {'id': 'old', 'type': 'borrow', 'person_name': 'Lan', 'amount': 100});
    final row = {
      'id': 'legacy',
      'debt_id': 'old',
      'amount': 40,
      'paid_at': '2026-01-01',
      'is_legacy': true,
      'record_transaction': false
    };
    await store.put('debt_payments', row);
    await store
        .put('debt_payments', {...row, 'amount': 30, 'paid_at': '2026-02-02'});
    final saved = (await store.rows('debt_payments')).single;
    expect(saved['is_legacy'], true);
    expect(saved['paid_at'], '2026-02-02');
    expect((await store.rows('debts')).single['paid_amount'], 30);
    expect(await store.rows('transactions'), isEmpty);
    await store.remove('debt_payments', 'legacy');
    expect((await store.rows('debts')).single['paid_amount'], 0);
    expect(await store.rows('transactions'), isEmpty);
  });
  test(
      'edited payable draft queues only occurrence with stable cross-device transaction ID',
      () async {
    final a = LocalStore.memory('same-user');
    final b = LocalStore.memory('same-user');
    addTearDown(a.close);
    addTearDown(b.close);
    final payable = Payable(
        id: 'rent', title: 'Rent', amount: 100, start: DateTime(2026, 10, 1));
    final draft = TransactionDraft(
        type: TransactionType.expense,
        amount: 75,
        walletId: 'wallet',
        categoryId: 'category',
        note: 'Edited rent',
        occurredAt: DateTime.utc(2026, 10, 2, 9));
    await PayablePayments(a).markPaid(payable, payable.start, draft: draft);
    await PayablePayments(b)
        .markPaid(payable, payable.start, draft: draft.copyWith(amount: 80));
    final left = (await a.rows('payable_occurrences')).single;
    final right = (await b.rows('payable_occurrences')).single;
    expect(left['id'], right['id']);
    expect(left['transaction_id'], right['transaction_id']);
    expect(left['transaction_id'], isNot(left['id']));
    expect(left['amount'], 75);
    expect(left['wallet_id'], 'wallet');
    expect(left['category_id'], 'category');
    expect(left['note'], 'Edited rent');
    expect(left['paid_at'], draft.occurredAt!.toIso8601String());
    final tx = (await a.rows('transactions')).single;
    expect(tx['id'], left['transaction_id']);
    expect(tx['amount'], 75);
    expect(tx['note'], 'Edited rent');
    expect(tx['wallet_id'], 'wallet');
    expect(tx['category_id'], 'category');
    final queued = await a.pending();
    expect(queued.length, 1);
    expect(queued.single['entity'], 'payable_occurrences');
    await expectLater(
        PayablePayments(a).markPaid(
            Payable(
                id: 'other', title: 'Other', amount: 1, start: payable.start),
            payable.start,
            draft: draft.copyWith(type: TransactionType.income)),
        throwsArgumentError);
    expect((await a.rows('payable_occurrences')).length, 1);
  });
}
