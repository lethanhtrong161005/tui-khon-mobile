import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/core/offline/offline_planning_repository.dart';
import 'package:tui_khon_mobile/core/utils/id_generator.dart';
import 'package:tui_khon_mobile/features/planning/data/debt_history.dart';
import 'package:tui_khon_mobile/features/planning/models/planning_models.dart';
import 'package:tui_khon_mobile/features/planning/presentation/debt_history_screen.dart';
import 'package:tui_khon_mobile/features/planning/presentation/debt_payment_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  late LocalStore store;
  late OfflinePlanningRepository repo;
  final day = DateTime.utc(2026, 10, 24, 2, 30);
  setUp(() async {
    store = LocalStore.memory('editing-user');
    repo = OfflinePlanningRepository(store);
    await store.setMeta('bootstrapped', 'true');
    await store.writeBatch([
      const LocalMutation('wallets', {'id': 'w', 'name': 'Tiền mặt'}),
      const LocalMutation('wallets', {'id': 'w2', 'name': 'Ngân hàng'}),
      const LocalMutation(
          'wallets', {'id': 'old', 'name': 'Cũ', 'is_archived': true}),
      const LocalMutation('debts',
          {'id': 'd', 'person_name': 'Lan', 'amount': 100, 'type': 'borrow'}),
    ]);
  });
  tearDown(() => store.close());
  Future<Map<String, dynamic>> payment() async =>
      (await store.rows('debt_payments')).single;

  test('first-attachment UUID matches PostgreSQL golden value', () {
    expect(debtPaymentTransactionId('11112222-3333-4444-5555-666677778888'),
        '7da29022-ac54-628b-d143-61cfd54937e3');
  });
  test(
      'create, first attachment, edit, off/on and undo retain one transaction and queue only payment',
      () async {
    await repo.settleDebt('d', amount: 40, paidAt: day, note: '  Lần đầu  ');
    final p = await payment();
    final id = p['id'] as String;
    expect(p['note'], 'Lần đầu');
    expect(p['paid_at'], day.toIso8601String());
    final transactionId = debtPaymentTransactionId(id);
    await repo.updateDebtPayment(id,
        amount: 50,
        paidAt: day,
        note: 'Đã sửa',
        recordTransaction: true,
        walletId: 'w');
    var tx = (await store.rows('transactions')).single;
    expect(tx['id'], transactionId);
    expect(tx['note'], 'Đã sửa');
    expect(tx['type'], 'expense');
    await repo.updateDebtPayment(id,
        amount: 60,
        paidAt: day.add(const Duration(days: 1)),
        note: '',
        recordTransaction: true,
        walletId: 'w2');
    tx = (await store.rows('transactions')).single;
    expect(tx['amount'], 60);
    expect(tx['wallet_id'], 'w2');
    expect(tx['note'], 'Trả nợ Lan');
    await repo.updateDebtPayment(id,
        amount: 60, paidAt: day, recordTransaction: false);
    expect(await store.rows('transactions'), isEmpty);
    expect((await payment())['transaction_id'], transactionId);
    await repo.updateDebtPayment(id,
        amount: 60, paidAt: day, recordTransaction: true, walletId: 'w');
    expect((await store.rows('transactions')).single['id'], transactionId);
    expect(
        (await store.pending()).where((op) => op['entity'] == 'transactions'),
        isEmpty);
    await repo.undoDebtPayment(id);
    expect(await store.rows('transactions'), isEmpty);
    expect((await store.record('debts', 'd'))!['paid_amount'], 0);
  });

  test('existing arbitrary transaction IDs remain unchanged', () async {
    await store.put('debt_payments', {
      'id': 'p',
      'debt_id': 'd',
      'amount': 30,
      'record_transaction': true,
      'wallet_id': 'w',
      'transaction_id': 'old-transaction'
    });
    await repo.updateDebtPayment('p',
        amount: 35,
        paidAt: day,
        note: 'Edit',
        recordTransaction: true,
        walletId: 'w2');
    expect((await store.rows('transactions')).single['id'], 'old-transaction');
  });

  test(
      'archived wallet retained for old recording; cannot newly select or re-enable after saved off',
      () async {
    await repo.settleDebt('d',
        amount: 20, recordTransaction: true, walletId: 'w');
    final id = (await payment())['id'] as String;
    await store.put('wallets', {'id': 'w', 'is_archived': true});
    await repo.updateDebtPayment(id,
        amount: 21, paidAt: day, recordTransaction: true, walletId: 'w');
    await expectLater(
        repo.updateDebtPayment(id,
            amount: 22, paidAt: day, recordTransaction: true, walletId: 'old'),
        throwsStateError);
    await repo.updateDebtPayment(id,
        amount: 21, paidAt: day, recordTransaction: false);
    await expectLater(
        repo.updateDebtPayment(id,
            amount: 22, paidAt: day, recordTransaction: true, walletId: 'w'),
        throwsStateError);
    await expectLater(
        repo.settleDebt('d',
            amount: 1, recordTransaction: true, walletId: 'old'),
        throwsStateError);
  });

  test(
      'legacy editing never creates cash; overpayment rolls back records and outbox',
      () async {
    await store.put('debt_payments',
        {'id': 'legacy', 'debt_id': 'd', 'amount': 40, 'is_legacy': true});
    await repo.updateDebtPayment('legacy',
        amount: 30,
        paidAt: day,
        note: 'Trước nâng cấp',
        recordTransaction: false);
    await expectLater(
        repo.updateDebtPayment('legacy',
            amount: 30, paidAt: day, recordTransaction: true, walletId: 'w'),
        throwsStateError);
    await repo.settleDebt('d', amount: 60);
    final count = await store.pendingCount();
    await expectLater(
        repo.updateDebtPayment('legacy',
            amount: 41, paidAt: day, recordTransaction: false),
        throwsStateError);
    expect((await store.record('debts', 'd'))!['paid_amount'], 90);
    expect(await store.pendingCount(), count);
    expect(await store.rows('transactions'), isEmpty);
  });

  test(
      'lend derives income, uses chosen wallet and instant; full payment settles',
      () async {
    await store.put('debts', {'id': 'd', 'type': 'lend'});
    await repo.settleDebt('d',
        paidAt: day,
        note: 'Thu lần cuối',
        walletId: 'w2',
        recordTransaction: true);
    expect((await store.record('debts', 'd'))!['status'], 'settled');
    final tx = (await store.rows('transactions')).single;
    expect(tx['type'], 'income');
    expect(tx['wallet_id'], 'w2');
    expect(tx['note'], 'Thu lần cuối');
    expect(paymentDate(tx['occurred_at']), '24/10/2026 · 09:30');
  });

  test('history sorts instants rather than ISO strings with different offsets',
      () async {
    await repo.settleDebt('d',
        amount: 10, paidAt: DateTime.parse('2026-10-24T08:00:00+07:00'));
    await store.put('debt_payments', {
      'id': 'later',
      'debt_id': 'd',
      'amount': 10,
      'paid_at': '2026-10-24T02:00:00Z'
    });
    final container = ProviderContainer(
        overrides: [localStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    expect((await container.read(debtHistoryProvider('d').future)).first['id'],
        'later');
  });

  test('status precedence, no due date and Vietnam calendar', () {
    DebtModel d({int paid = 0, DateTime? due, bool settled = false}) =>
        DebtModel(
            type: DebtType.borrow,
            personName: 'Lan',
            amount: 100,
            paidAmount: paid,
            dueDate: due,
            isSettled: settled);
    final today = DateTime(2026, 10, 28);
    expect(debtStatus(d(settled: true, due: DateTime(2026)), today),
        'Đã tất toán');
    expect(debtStatus(d(due: DateTime(2026, 10, 27)), today), 'Quá hạn');
    expect(debtStatus(d(due: today), today), 'Đến hạn hôm nay');
    expect(debtStatus(d(due: DateTime(2026, 10, 31)), today), 'Sắp đến hạn');
    expect(debtStatus(d(), today), 'Đang còn nợ');
    expect(debtStatus(d(due: DateTime(2026, 11, 1)), today), 'Đang còn nợ');
  });
}
