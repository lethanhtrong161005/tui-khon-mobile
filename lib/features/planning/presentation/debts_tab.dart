import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../data/planning_repository.dart';
import '../models/planning_models.dart';
import 'debt_actions.dart';

/// Sổ nợ: notes of "tôi nợ ai" / "ai nợ tôi" with due dates and reminders.
class DebtsTab extends ConsumerWidget {
  const DebtsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsProvider);
    final debts = debtsAsync.valueOrNull;
    final today = DateTime.now();

    if (debts == null) {
      return Center(
        child: debtsAsync.hasError
            ? Text(friendlyError(debtsAsync.error!), style: const TextStyle(color: AppColors.onSurfaceVariant))
            : const CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final active = debts.where((d) => !d.isSettled).toList();
    final borrow = active.where((d) => d.type == DebtType.borrow).toList();
    final lend = active.where((d) => d.type == DebtType.lend).toList();
    final settled = debts.where((d) => d.isSettled).toList();
    int total(List<DebtModel> list) => list.fold(0, (s, d) => s + d.remaining);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: ref.refreshDebts,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            children: [
              Expanded(child: _totalCard('Tôi đang nợ', total(borrow), AppColors.error)),
              const SizedBox(width: 10),
              Expanded(child: _totalCard('Người khác nợ tôi', total(lend), AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Sổ nợ chỉ là ghi chú, không tự trừ tiền. Túi Khôn nhắc bạn trước hạn 1 ngày và đúng ngày hạn.',
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (active.isEmpty) _empty(),
          if (borrow.isNotEmpty) ...[
            _sectionTitle('Tôi nợ (${borrow.length})'),
            for (final d in borrow) DebtTile(debt: d, today: today),
          ],
          if (lend.isNotEmpty) ...[
            _sectionTitle('Nợ tôi (${lend.length})'),
            for (final d in lend) DebtTile(debt: d, today: today),
          ],
          if (settled.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Đã tất toán (${settled.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                children: [for (final d in settled) DebtTile(debt: d, today: today)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _totalCard(String label, int amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(CurrencyFormatter.formatVND(amount),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      );

  Widget _empty() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.handshake, color: AppColors.outline, size: 32),
            SizedBox(height: 8),
            Text('Chưa có khoản nợ nào đang mở.\nBấm "Thêm khoản nợ" để ghi lại.',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ),
      );
}

class DebtTile extends ConsumerWidget {
  const DebtTile({super.key, required this.debt, required this.today});

  final DebtModel debt;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = debt.daysUntilDue(today);
    final dueColor = days == null
        ? AppColors.onSurfaceVariant
        : days < 0
            ? AppColors.error
            : days <= 1
                ? AppColors.tertiary
                : AppColors.onSurfaceVariant;
    final isBorrow = debt.type == DebtType.borrow;
    final color = isBorrow ? AppColors.error : AppColors.primary;

    return Card(
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showDebtForm(context, initial: debt),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withOpacity(0.12),
                    child: Text(
                      debt.personName.isEmpty ? '?' : String.fromCharCode(debt.personName.runes.first).toUpperCase(),
                      style: TextStyle(color: color, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBorrow ? 'Tôi nợ ${debt.personName}' : '${debt.personName} nợ tôi',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          [
                            if (debt.isSettled) 'Đã tất toán' else if (debt.dueLabel(today) != null) debt.dueLabel(today)!,
                            if (debt.note != null) debt.note!,
                          ].join(' • '),
                          style: TextStyle(fontSize: 11, color: debt.isSettled ? AppColors.primary : dueColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(CurrencyFormatter.formatVND(debt.isSettled ? debt.amount : debt.remaining),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                      if (debt.paidAmount > 0 && !debt.isSettled)
                        Text('/ ${CurrencyFormatter.formatVND(debt.amount)}',
                            style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: AppColors.onSurfaceVariant),
                    onSelected: (value) async {
                      switch (value) {
                        case 'partial':
                          await showSettleDebtDialog(context, ref, debt, partial: true);
                        case 'settle':
                          await showSettleDebtDialog(context, ref, debt);
                        case 'edit':
                          await showDebtForm(context, initial: debt);
                        case 'delete':
                          if (await confirmDialog(context,
                              title: 'Xoá khoản nợ?', message: 'Xoá ghi chú nợ với ${debt.personName}?')) {
                            try {
                              await ref.read(planningRepositoryProvider).deleteDebt(debt.id!);
                              await ref.refreshDebts();
                            } catch (e) {
                              if (context.mounted) showToast(context, friendlyError(e));
                            }
                          }
                      }
                    },
                    itemBuilder: (_) => [
                      if (!debt.isSettled) ...[
                        PopupMenuItem(value: 'settle', child: Text(isBorrow ? 'Đã trả hết' : 'Đã nhận đủ')),
                        const PopupMenuItem(value: 'partial', child: Text('Ghi trả một phần')),
                        const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                      ],
                      const PopupMenuItem(value: 'delete', child: Text('Xoá')),
                    ],
                  ),
                ],
              ),
              if (debt.paidAmount > 0 && !debt.isSettled) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: debt.paidAmount / debt.amount,
                  minHeight: 5,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Add / edit a debt note.
Future<void> showDebtForm(BuildContext context, {DebtModel? initial, DebtType type = DebtType.borrow}) {
  return showFormSheet<void>(context, _DebtForm(initial: initial, type: type));
}

class _DebtForm extends ConsumerStatefulWidget {
  const _DebtForm({this.initial, required this.type});

  final DebtModel? initial;
  final DebtType type;

  @override
  ConsumerState<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends ConsumerState<_DebtForm> {
  late DebtType _type = widget.initial?.type ?? widget.type;
  late final _name = TextEditingController(text: widget.initial?.personName ?? '');
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final _amount = TextEditingController(text: widget.initial == null ? '' : '${widget.initial!.amount}');
  late final _note = TextEditingController(text: widget.initial?.note ?? '');
  late DateTime? _dueDate = widget.initial?.dueDate;
  bool _busy = false;

  Future<void> _save() async {
    final amount = MoneyField.valueOf(_amount);
    if (_name.text.trim().isEmpty) return showToast(context, 'Nhập tên người cho vay / đi vay');
    if (amount <= 0) return showToast(context, 'Nhập số tiền lớn hơn 0');
    if (widget.initial != null && amount < widget.initial!.paidAmount) {
      return showToast(context, 'Số tiền không được nhỏ hơn phần đã trả');
    }

    setState(() => _busy = true);
    try {
      await ref.read(planningRepositoryProvider).saveDebt(DebtModel(
            id: widget.initial?.id,
            type: _type,
            personName: _name.text,
            phone: _phone.text,
            amount: amount,
            dueDate: _dueDate,
            note: _note.text,
          ));
      await ref.refreshDebts();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: widget.initial == null ? 'Thêm khoản nợ' : 'Sửa khoản nợ',
      submitLabel: 'Lưu',
      busy: _busy,
      onSubmit: _save,
      children: [
        SegmentedButton<DebtType>(
          segments: const [
            ButtonSegment(value: DebtType.borrow, label: Text('Tôi nợ'), icon: Icon(Icons.call_made)),
            ButtonSegment(value: DebtType.lend, label: Text('Nợ tôi'), icon: Icon(Icons.call_received)),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: sheetInputDecoration(_type == DebtType.borrow ? 'Tôi nợ ai?' : 'Ai nợ tôi?'),
        ),
        const SizedBox(height: 12),
        MoneyField(controller: _amount, label: 'Số tiền (VND)'),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: sheetInputDecoration('Số điện thoại (tuỳ chọn)'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _note, maxLength: 255, decoration: sheetInputDecoration('Ghi chú (tuỳ chọn)')),
        DatePickerTile(
          label: 'Hạn trả',
          value: _dueDate,
          onChanged: (d) => setState(() => _dueDate = d),
        ),
      ],
    );
  }
}
