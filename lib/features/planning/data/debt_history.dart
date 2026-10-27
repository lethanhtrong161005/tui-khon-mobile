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
  rows.sort((a, b) => '${b['paid_at']}'.compareTo('${a['paid_at']}'));
  return rows;
});
