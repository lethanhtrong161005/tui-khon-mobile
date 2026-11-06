import '../../home/models/transaction_model.dart';

/// Optional capability for repositories that can atomically queue a batch.
/// Implementations must commit all drafts or throw without committing any.
abstract interface class QuickRecordBatchWriter {
  Future<void> addTransactions(List<TransactionDraft> drafts);
}

/// Match the shared duplicate service for drafts not yet in local storage.
bool isPossibleDuplicate(TransactionDraft a, TransactionDraft b) {
  if (a.receiptPath != null && a.receiptPath == b.receiptPath) return true;
  if (a.amount != b.amount || a.type != b.type || a.walletId != b.walletId)
    return false;
  if (a.occurredAt == null || b.occurredAt == null) return false;
  return a.occurredAt!.difference(b.occurredAt!).abs() <=
      const Duration(minutes: 10);
}
