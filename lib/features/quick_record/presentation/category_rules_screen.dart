import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/local_store.dart';
import '../../../core/utils/error_messages.dart';
import '../../home/providers/home_providers.dart';

final categoryRulesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(localRevisionProvider);
  final store = ref.watch(localStoreProvider);
  if (store == null) return [];
  final rows = await store.rows('category_rules');
  rows.sort(
      (a, b) => (a['keyword'] as String).compareTo(b['keyword'] as String));
  return rows;
});

class CategoryRulesScreen extends ConsumerStatefulWidget {
  const CategoryRulesScreen({super.key});
  @override
  ConsumerState<CategoryRulesScreen> createState() =>
      _CategoryRulesScreenState();
}

class _CategoryRulesScreenState extends ConsumerState<CategoryRulesScreen> {
  final _busy = <String>{};

  Future<void> _change(Map<String, dynamic> row,
      {bool? enabled, bool delete = false}) async {
    final id = row['id'] as String;
    final store = ref.read(localStoreProvider);
    if (store == null || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      if (delete) {
        await store.remove('category_rules', id);
      } else {
        await store.put('category_rules', {...row, 'enabled': enabled});
      }
      if (mounted) ref.invalidate(categoryRulesProvider);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(categoryRulesProvider);
    final categories = ref.watch(categoriesProvider);
    final names = {for (final c in categories.valueOrNull ?? []) c.id: c.name};
    return Scaffold(
      appBar: AppBar(title: const Text('Quy tắc phân loại')),
      body: Column(children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'Chỉ học khi bạn đổi danh mục rồi lưu giao dịch. Quy tắc khớp chính xác mô tả bản nháp ban đầu sau khi bỏ dấu, chuyển chữ thường và gộp khoảng trắng; ưu tiên quy tắc riêng của cửa hàng; không học ví hay số tiền.')),
        Expanded(
            child: rules.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(friendlyError(error)),
            TextButton(
                onPressed: () => ref.invalidate(categoryRulesProvider),
                child: const Text('Thử lại')),
          ])),
          data: (rows) => rows.isEmpty
              ? const Center(child: Text('Chưa có quy tắc phân loại'))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final busy = _busy.contains(row['id']);
                    return ListTile(
                      title: Text(row['keyword'] as String),
                      subtitle: Text(names[row['category_id']] ??
                          (categories.isLoading
                              ? 'Đang tải danh mục…'
                              : 'Danh mục không còn tồn tại')),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Switch(
                            value: row['enabled'] != false,
                            onChanged: busy
                                ? null
                                : (value) => _change(row, enabled: value)),
                        IconButton(
                            tooltip: 'Xóa quy tắc',
                            icon: const Icon(Icons.delete_outline),
                            onPressed:
                                busy ? null : () => _change(row, delete: true)),
                      ]),
                    );
                  }),
        )),
      ]),
    );
  }
}
