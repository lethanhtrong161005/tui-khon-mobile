import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/core/offline/offline_wallet_repository.dart';
import 'package:tui_khon_mobile/core/offline/offline_planning_repository.dart';
import 'package:tui_khon_mobile/core/offline/duplicate_service.dart';
import 'package:tui_khon_mobile/features/home/models/transaction_model.dart';

void main() {
  late LocalStore store;
  setUp(() async {
    store = LocalStore.memory('user-a');
    await store.put('wallets', {'id': 'wallet', 'name': 'Tiền mặt', 'type': 'cash', 'initial_balance': 1000000});
    await store.put('categories', {'id': 'food', 'name': 'Ăn uống', 'type': 'expense'});
    await store.put('debts',
        {'id': 'debt', 'person_name': 'Lan', 'type': 'lend', 'amount': 500000, 'paid_amount': 0, 'status': 'active'});
    await store.setMeta('bootstrapped', 'true');
  });
  tearDown(() async => store.close());
  test('local financial write and outbox persist atomically', () async {
    final repo = OfflineWalletRepository(store);
    await repo.addTransaction(
        const TransactionDraft(type: TransactionType.expense, amount: 65000, walletId: 'wallet', categoryId: 'food'));
    final tx = (await store.rows('transactions')).single;
    final op = (await store.pending()).last;
    expect(tx['client_id'], tx['id']);
    expect(op['record_id'], tx['id']);
    expect(jsonDecode(op['payload'] as String)['amount'], 65000);
    expect((await repo.fetchWallets()).single.balance, 935000);
  });
  test('database and immutable outbox survive close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp('tuikhon-offline-test-');
    final file = File('${directory.path}/account.sqlite');
    final first = LocalStore.file('persistent-user', file);
    await first.put('wallets', {'id': 'persisted', 'name': 'Saved offline'});
    final opId = (await first.pending()).single['op_id'];
    await first.close();
    final reopened = LocalStore.file('persistent-user', file);
    expect((await reopened.rows('wallets')).single['name'], 'Saved offline');
    expect((await reopened.pending()).single['op_id'], opId);
    await reopened.close();
    for (final f in directory.listSync().whereType<File>()) {
      await f.delete();
    }
    await directory.delete();
  });
  test('failed batch rolls back records and outbox', () async {
    final before = await store.pendingCount();
    await expectLater(
        store.writeBatch([
          LocalMutation('transactions', {'id': 'one', 'wallet_id': 'wallet', 'amount': 100, 'type': 'expense'}),
          LocalMutation('transactions', {'id': 'two', 'wallet_id': 'wallet', 'amount': 0, 'type': 'expense'}),
        ]),
        throwsStateError);
    expect(await store.rows('transactions'), isEmpty);
    expect(await store.pendingCount(), before);
  });
  test('independent user databases never share records', () async {
    final other = LocalStore.memory('user-b');
    expect(await other.rows('wallets'), isEmpty);
    await other.close();
  });
  test('ACK rebases later edits and preserves optimistic state', () async {
    final first = (await store.pending()).first;
    await store.put('wallets', {'id': 'wallet', 'name': 'Tiền mặt mới'});
    await store.acknowledge(
        first['op_id'] as String, 'wallets', 'wallet', {'id': 'wallet', 'name': 'Tiền mặt'}, 1, false);
    expect((await store.record('wallets', 'wallet'))!['name'], 'Tiền mặt mới');
    final later = (await store.pending()).where((o) => o['record_id'] == 'wallet').single;
    expect(later['base_version'], 1);
    expect(later['op_id'], isNot(first['op_id']));
  });
  test('pull page does not overwrite dirty edits and advances cursor atomically', () async {
    await store.applyPage([
      {
        'entity': 'wallets',
        'id': 'wallet',
        'row': {'id': 'wallet', 'name': 'Server'},
        'version': 4,
        'deleted': false
      }
    ], '42');
    expect((await store.record('wallets', 'wallet'))!['name'], 'Tiền mặt');
    expect(await store.meta('cursor'), '42');
  });
  test('conflict keeps both versions and explicit local choice queues new operation', () async {
    await store.conflict('wallets', 'wallet', {'id': 'wallet', 'name': 'Server', 'initial_balance': 200}, 2, false);
    final conflict = (await store.conflicts()).single;
    expect(jsonDecode(conflict['local_data'] as String)['name'], 'Tiền mặt');
    expect(jsonDecode(conflict['server_data'] as String)['name'], 'Server');
    await store.resolveConflict('wallets', 'wallet', keepLocal: true);
    expect(await store.conflicts(), isEmpty);
    expect((await store.pending()).where((o) => o['record_id'] == 'wallet').single['base_version'], 2);
    expect((await store.record('wallets', 'wallet'))!['name'], 'Tiền mặt');
  });
  test('server delete conflict can be accepted without erasing other pending edits', () async {
    await store.conflict('wallets', 'wallet', {'id': 'wallet', 'name': 'Server'}, 3, true);
    await store.resolveConflict('wallets', 'wallet', keepLocal: false);
    expect(await store.record('wallets', 'wallet'), isNull);
    expect((await store.pending()).where((o) => o['entity'] == 'categories'), isNotEmpty);
  });
  test('debt payment edit and undo change one linked transaction and reopen debt', () async {
    final repo = OfflinePlanningRepository(store);
    await repo.settleDebt('debt', amount: 200000, recordTransaction: true);
    final payment = (await store.rows('debt_payments')).single;
    expect((await store.record('debts', 'debt'))!['paid_amount'], 200000);
    expect((await store.rows('transactions')).single['amount'], 200000);
    await store.put('debt_payments', {...payment, 'amount': 500000});
    expect((await store.record('debts', 'debt'))!['status'], 'settled');
    expect((await store.rows('transactions')).single['amount'], 500000);
    await store.remove('debt_payments', payment['id'] as String);
    expect((await store.record('debts', 'debt'))!['paid_amount'], 0);
    expect((await store.record('debts', 'debt'))!['status'], 'active');
    expect(await store.rows('transactions'), isEmpty);
  });
  test('overpayment rolls back payment and linked income', () async {
    final before = await store.pendingCount();
    await expectLater(
        store.put('debt_payments',
            {'id': 'overpay', 'debt_id': 'debt', 'amount': 600000, 'record_transaction': true, 'wallet_id': 'wallet'}),
        throwsStateError);
    expect(await store.rows('debt_payments'), isEmpty);
    expect(await store.rows('transactions'), isEmpty);
    expect(await store.pendingCount(), before);
  });
  test('category deletion unclassifies old transactions and removes its budget', () async {
    await store.put(
        'transactions', {'id': 'tx', 'wallet_id': 'wallet', 'category_id': 'food', 'amount': 100, 'type': 'expense'});
    await store.put('budgets', {'id': 'budget', 'category_id': 'food', 'month': '2026-10-01', 'limit_amount': 500});
    await store.remove('categories', 'food');
    expect((await store.record('transactions', 'tx'))!['category_id'], isNull);
    expect(await store.rows('budgets'), isEmpty);
  });
  test('duplicate warning uses same amount/source/time or receipt hash', () async {
    final time = DateTime(2026, 10, 28, 12);
    await store.put('transactions', {
      'id': 'tx',
      'wallet_id': 'wallet',
      'amount': 65000,
      'type': 'expense',
      'occurred_at': time.toIso8601String(),
      'receipt_path': 'user-a/hash.jpg'
    });
    final checker = DuplicateService(store);
    expect(
        await checker.find(TransactionDraft(
            type: TransactionType.expense,
            amount: 65000,
            walletId: 'wallet',
            occurredAt: time.add(const Duration(minutes: 5)))),
        hasLength(1));
    expect(
        await checker.find(TransactionDraft(
            type: TransactionType.expense,
            amount: 65000,
            walletId: 'wallet',
            occurredAt: time.add(const Duration(days: 2)))),
        isEmpty);
    expect(
        await checker.find(const TransactionDraft(
            type: TransactionType.expense, amount: 1, walletId: 'different', receiptPath: 'user-a/hash.jpg')),
        hasLength(1));
  });
}
