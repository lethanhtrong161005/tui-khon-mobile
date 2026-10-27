import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../home/providers/home_providers.dart';
import '../data/debt_history.dart';
import '../data/planning_repository.dart';
import '../models/planning_models.dart';
import 'debt_actions.dart';
import 'debts_tab.dart';

class DebtHistoryScreen extends ConsumerWidget {
  const DebtHistoryScreen({super.key, required this.debt});
  final DebtModel debt;

  Future<void> _change(
      BuildContext context, WidgetRef ref, Map<String, dynamic> row,
      {bool undo = false}) async {
    final store = ref.read(localStoreProvider);
    if (store == null) return;
    Map<String, dynamic>? updated;
    if (undo) {
      if (!await confirmDialog(context,
          title: 'Hoàn tác khoản trả?',
          message: 'Số dư nợ và giao dịch liên kết sẽ được cập nhật.')) return;
    } else {
      updated = await showDialog<Map<String, dynamic>>(
          context: context, builder: (_) => _EditPayment(row: row));
      if (updated == null) return;
    }
    if (updated != null && row['is_legacy'] == true) {
      updated = {
        ...updated,
        'is_legacy': true,
        'record_transaction': false,
        'transaction_id': null,
        'wallet_id': null
      };
    }
    try {
      if (undo) {
        await store.remove('debt_payments', row['id'] as String);
      } else {
        await store.put('debt_payments', updated!);
      }
      ref.invalidate(debtHistoryProvider(debt.id!));
      ref.refreshWalletData();
      await ref.refreshDebts();
    } catch (e) {
      if (context.mounted) showToast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(debtHistoryProvider(debt.id!));
    final current = ref
            .watch(debtsProvider)
            .valueOrNull
            ?.where((d) => d.id == debt.id)
            .firstOrNull ??
        debt;
    return Scaffold(
      appBar: AppBar(title: Text('Lịch sử · ${debt.personName}'), actions: [
        IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => showDebtForm(context, initial: current))
      ]),
      floatingActionButton: current.isSettled
          ? null
          : FloatingActionButton.extended(
              label: const Text('Ghi trả'),
              icon: const Icon(Icons.payments),
              onPressed: () =>
                  showSettleDebtDialog(context, ref, current, partial: true),
            ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (rows) => rows.isEmpty
            ? const Center(child: Text('Chưa có lịch sử thanh toán'))
            : ListView(children: [
                for (final row in rows)
                  ListTile(
                    title: Text(CurrencyFormatter.formatVND(
                        (row['amount'] as num).toInt())),
                    subtitle: Text(
                        '${row['paid_at']}\n${row['note'] ?? ''}${row['is_legacy'] == true ? ' · Số dư cũ' : ''}'),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) =>
                          _change(context, ref, row, undo: v == 'undo'),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'edit', child: Text('Sửa khoản trả')),
                        PopupMenuItem(value: 'undo', child: Text('Hoàn tác'))
                      ],
                    ),
                  ),
              ]),
      ),
    );
  }
}

class _EditPayment extends StatefulWidget {
  const _EditPayment({required this.row});
  final Map<String, dynamic> row;
  @override
  State<_EditPayment> createState() => _EditPaymentState();
}

class _EditPaymentState extends State<_EditPayment> {
  late final amount = TextEditingController(text: '${widget.row['amount']}');
  late final note =
      TextEditingController(text: widget.row['note'] as String? ?? '');
  late DateTime date = DateTime.parse(widget.row['paid_at'] as String);
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Sửa khoản trả'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          MoneyField(controller: amount, label: 'Số tiền'),
          TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Ghi chú')),
          DatePickerTile(
              label: 'Ngày trả',
              value: date,
              onChanged: (v) {
                if (v != null) setState(() => date = v);
              }),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () {
                final value = MoneyField.valueOf(amount);
                if (value <= 0) return;
                Navigator.pop(context, {
                  ...widget.row,
                  'amount': value,
                  'note': note.text.trim(),
                  'paid_at': date.toIso8601String()
                });
              },
              child: const Text('Lưu'))
        ],
      );
}
