import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/offline/local_store.dart';

final debtHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  ref.watch(localRevisionProvider);
  final store = ref.watch(localStoreProvider);
  if (store == null) return [];
  final rows = (await store.rows('debt_payments'))
      .where((r) => r['debt_id'] == id)
      .toList();
  rows.sort((a, b) {
    final order = DateTime.parse('${b['paid_at']}')
        .compareTo(DateTime.parse('${a['paid_at']}'));
    return order == 0 ? '${a['id']}'.compareTo('${b['id']}') : order;
  });
  return rows;
});
