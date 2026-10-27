import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/models/transaction_model.dart';
import '../utils/currency_formatter.dart';
import 'local_store.dart';

class DuplicateService {
  DuplicateService(this.store);
  final LocalStore store;
  Future<List<Map<String, dynamic>>> find(TransactionDraft draft, {String? excludingId}) async {
    final at = draft.occurredAt ?? DateTime.now();
    return (await store.rows('transactions')).where((t) {
      if (t['id'] == excludingId) return false;
      final sameImage = draft.receiptPath != null && draft.receiptPath == t['receipt_path'];
      final time = DateTime.tryParse(t['occurred_at'] as String? ?? '');
      return sameImage ||
          (t['type'] == draft.type.name &&
              t['amount'] == draft.amount &&
              t['wallet_id'] == draft.walletId &&
              time != null &&
              time.difference(at).abs() <= const Duration(minutes: 10));
    }).toList();
  }
}

final duplicateServiceProvider = Provider<DuplicateService?>((ref) {
  final store = ref.watch(localStoreProvider);
  return store == null ? null : DuplicateService(store);
});

Future<bool> confirmPossibleDuplicate(BuildContext context, List<Map<String, dynamic>> matches) async {
  if (matches.isEmpty) return true;
  return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Có thể đã ghi giao dịch này'),
                  content: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Đối chiếu trước khi lưu:'),
                        for (final row in matches.take(5))
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                  '${row['note'] ?? 'Giao dịch'} · ${CurrencyFormatter.formatVND((row['amount'] as num).toInt())}\n${row['occurred_at']}'))
                      ])),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bỏ qua')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vẫn lưu'))
                  ])) ??
      false;
}
