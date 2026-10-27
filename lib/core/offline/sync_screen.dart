import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/planning/models/planning_models.dart';
import '../../features/planning/presentation/debt_history_screen.dart';

import 'local_store.dart';
import 'sync_controller.dart';

class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(localStoreProvider) == null) return const SizedBox.shrink();
    final state = ref.watch(syncControllerProvider);
    final label = state.running
        ? 'Đang đồng bộ…'
        : state.conflicts > 0
            ? '${state.conflicts} mục cần đối chiếu'
            : state.pending > 0
                ? '${state.pending} thay đổi trên máy'
                : 'Đã đồng bộ';
    return ListTile(
        dense: true,
        leading: Icon(state.error != null ? Icons.cloud_off : Icons.cloud_sync),
        title: Text(label),
        subtitle: state.error == null ? null : const Text('Ghi chép vẫn lưu trên máy'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncScreen())));
  }
}

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});
  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  String _entity(Object? key) =>
      const {
        'transactions': 'Giao dịch',
        'wallets': 'Nguồn tiền',
        'categories': 'Danh mục',
        'budgets': 'Ngân sách',
        'debts': 'Sổ nợ',
        'debt_payments': 'Lịch sử trả nợ',
        'goals': 'Mục tiêu',
        'payables': 'Khoản phải trả',
        'payable_occurrences': 'Lần thanh toán',
        'category_rules': 'Quy tắc phân loại',
        'notifications': 'Thông báo'
      }[key] ??
      'Ghi chép';
  String _error(Map<String, dynamic> row) => row['entity'] == 'debt_payments'
      ? 'Kiểm tra số tiền trả và khoản nợ còn lại. Bấm để sửa lịch sử.'
      : 'Kiểm tra nội dung trong mục ${_entity(row['entity'])}, rồi thử đồng bộ lại.';
  Future<void> _openError(Map<String, dynamic> e) async {
    final row = (jsonDecode(e['payload'] as String) as Map).cast<String, dynamic>();
    if (e['entity'] == 'debt_payments') {
      final debt = await ref.read(localStoreProvider)!.record('debts', row['debt_id'] as String);
      if (debt != null && mounted) {
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => DebtHistoryScreen(debt: DebtModel.fromJson(debt))));
        if (mounted) setState(() {});
        return;
      }
    }
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
            title: Text(_entity(e['entity'])),
            content: SingleChildScrollView(child: Text('${_display(e['payload'] as String?, 0)}\n\n${_error(e)}')),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))]));
  }

  Future<void> _resolve(Map<String, dynamic> c, bool keep) async {
    await ref
        .read(localStoreProvider)!
        .resolveConflict(c['entity'] as String, c['record_id'] as String, keepLocal: keep);
    if (!mounted) return;
    await ref.read(syncControllerProvider.notifier).sync();
    if (mounted) setState(() {});
  }

  String _display(String? raw, int deleted) {
    if (deleted == 1) return 'Đã xoá';
    if (raw == null) return 'Chưa tồn tại';
    final row = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final fields = [
      'name',
      'person_name',
      'note',
      'type',
      'amount',
      'paid_at',
      'occurred_at',
      'saved_amount',
      'target_amount',
      'limit_amount'
    ];
    const names = {
      'name': 'Tên',
      'person_name': 'Người liên quan',
      'note': 'Ghi chú',
      'type': 'Loại',
      'amount': 'Số tiền',
      'paid_at': 'Ngày trả',
      'occurred_at': 'Thời điểm',
      'saved_amount': 'Đã để dành',
      'target_amount': 'Mục tiêu',
      'limit_amount': 'Hạn mức'
    };
    return fields.where((k) => row[k] != null).map((k) => '${names[k]}: ${row[k]}').join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(localStoreProvider)!;
    final status = ref.watch(syncControllerProvider);
    ref.watch(localRevisionProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Dữ liệu & Đồng bộ')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('${status.pending} thay đổi đang chờ · ${status.conflicts} xung đột'),
          if (status.lastSuccess != null) Text('Lần cuối: ${status.lastSuccess!.toLocal()}'),
          if (status.error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(status.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          FilledButton.icon(
              onPressed:
                  status.running ? null : () => ref.read(syncControllerProvider.notifier).sync(retryErrors: true),
              icon: const Icon(Icons.sync),
              label: Text(status.running ? 'Đang đồng bộ' : 'Đồng bộ ngay')),
          const Text(
              'Dữ liệu trên máy được giữ khi chưa có mạng. Nếu hai thiết bị sửa cùng một mục, chọn bản muốn giữ bên dưới.'),
          FutureBuilder(
              future: store.conflicts(),
              builder: (context, snapshot) => Column(children: [
                    for (final c in snapshot.data ?? <Map<String, dynamic>>[])
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(_entity(c['entity'])),
                                const SizedBox(height: 8),
                                const Text('Trên máy', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(_display(c['local_data'] as String?, c['local_deleted'] as int)),
                                const Text('Trên server', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(_display(c['server_data'] as String?, c['server_deleted'] as int)),
                                Wrap(spacing: 8, children: [
                                  TextButton(onPressed: () => _resolve(c, true), child: const Text('Giữ bản trên máy')),
                                  TextButton(onPressed: () => _resolve(c, false), child: const Text('Giữ bản server'))
                                ]),
                              ])))
                  ])),
          FutureBuilder(
              future: store.errors(),
              builder: (context, snapshot) => Column(children: [
                    for (final e in snapshot.data ?? <Map<String, dynamic>>[])
                      ListTile(
                          leading: const Icon(Icons.error_outline),
                          title: Text(_entity(e['entity'])),
                          subtitle: Text(_error(e)),
                          onTap: () => _openError(e))
                  ])),
        ]));
  }
}
