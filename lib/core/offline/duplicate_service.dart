import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/models/transaction_model.dart';
import '../utils/localized_format.dart';
import '../../l10n/app_l10n.dart';
import 'local_store.dart';

class DuplicateService {
  DuplicateService(this.store);
  final LocalStore store;
  Future<List<Map<String, dynamic>>> find(TransactionDraft draft,
      {String? excludingId}) async {
    final at = draft.occurredAt ?? DateTime.now();
    return (await store.rows('transactions')).where((t) {
      if (t['id'] == excludingId) return false;
      final sameImage =
          draft.receiptPath != null && draft.receiptPath == t['receipt_path'];
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

Future<bool> confirmPossibleDuplicate(
    BuildContext context, List<Map<String, dynamic>> matches) async {
  if (matches.isEmpty) return true;
  return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text(appL10n(context).duplicateTitle),
                  content: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(appL10n(context).compareBeforeSaving),
                        for (final row in matches.take(5))
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                  '${row['note'] ?? appL10n(context).transaction} · ${formatMoney(context, (row['amount'] as num).toInt())}\n${financialDateTime(DateTime.parse(row['occurred_at'] as String))}'))
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(appL10n(context).skip)),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(appL10n(context).saveAnyway))
                  ])) ??
      false;
}
