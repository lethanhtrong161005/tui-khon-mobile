import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/offline/local_store.dart';
import '../../home/models/transaction_model.dart';
import '../models/payable.dart';

final payablesProvider = FutureProvider.autoDispose<List<Payable>>((ref) async {
  ref.watch(localRevisionProvider);
  final store = ref.watch(localStoreProvider);
  return store == null
      ? []
      : (await store.rows('payables')).map(Payable.fromJson).toList();
});
final payablePaymentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(localRevisionProvider);
  return await ref.watch(localStoreProvider)?.rows('payable_occurrences') ?? [];
});

/// All recurrence is manual. Only a confirmed payment can create a transaction.
class PayablePayments {
  PayablePayments(this.store);
  final LocalStore store;
  static final _queues = Expando<Future<void>>();
  Future<void> markPaid(Payable payable, DateTime date,
      {String? walletId, TransactionDraft? draft}) {
    final result = (_queues[store] ?? Future<void>.value()).then(
        (_) => _markPaid(payable, date, walletId: walletId, draft: draft));
    _queues[store] = result.catchError((Object _) {});
    return result;
  }

  Future<void> _markPaid(Payable payable, DateTime date,
      {String? walletId, TransactionDraft? draft}) async {
    final valid = payable
        .through(date)
        .any((d) => payableDateKey(d) == payableDateKey(date));
    if (!valid || payable.amount <= 0)
      throw ArgumentError('Invalid payable occurrence');
    final id = payable.occurrenceId(date);
    if ((await store.rows('payable_occurrences')).any((r) =>
        (r['id'] == id ||
            (r['payable_id'] == payable.id &&
                r['due_date'] == payableDateKey(date))) &&
        r['status'] == 'paid')) return;
    final confirmed = draft ??
        (walletId == null
            ? null
            : TransactionDraft(
                type: TransactionType.expense,
                amount: payable.amount,
                walletId: walletId,
                note: payable.note ?? payable.title));
    if (confirmed != null &&
        (!confirmed.isValid || confirmed.type != TransactionType.expense)) {
      throw ArgumentError('Khoản phải trả cần một khoản chi hợp lệ');
    }
    // One journal operation: LocalStore and the server derive its transaction
    // in the same commit. Never enqueue an independent transaction here.
    await store.put('payable_occurrences', {
      'id': id,
      'payable_id': payable.id,
      'status': 'paid',
      'due_date': payableDateKey(date),
      'amount': confirmed?.amount ?? payable.amount,
      'paid_at':
          (confirmed?.occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
      'record_transaction': confirmed != null,
      'wallet_id': confirmed?.walletId,
      'category_id': confirmed?.categoryId,
      'note': confirmed?.note?.trim() ?? payable.note?.trim() ?? payable.title,
      'transaction_id': confirmed == null
          ? null
          : stablePayableUuid('payable-transaction:$id'),
    });
  }
}
