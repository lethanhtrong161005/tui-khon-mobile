import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/glass.dart';
import '../../home/providers/home_providers.dart';
import '../data/debt_history.dart';
import '../data/planning_repository.dart';
import '../models/planning_models.dart';
import 'debt_actions.dart';
import 'debt_payment_sheet.dart';
import 'debts_tab.dart';

String debtStatus(DebtModel debt, DateTime vietnamToday) {
  if (debt.isSettled || debt.remaining <= 0) return 'Đã tất toán';
  final days = debt.daysUntilDue(vietnamToday);
  if (days != null && days < 0) return 'Quá hạn';
  if (days == 0) return 'Đến hạn hôm nay';
  if (days != null && days <= 3) return 'Sắp đến hạn';
  return 'Đang còn nợ';
}

String _money(num value) => CurrencyFormatter.formatVND(value);

class DebtHistoryScreen extends ConsumerStatefulWidget {
  const DebtHistoryScreen({super.key, required this.debt});
  final DebtModel debt;
  @override
  ConsumerState<DebtHistoryScreen> createState() => _DebtHistoryScreenState();
}

class _DebtHistoryScreenState extends ConsumerState<DebtHistoryScreen> {
  bool _newest = true;
  bool _undoBusy = false;
  Future<void> _undo(Map<String, dynamic> row) async {
    if (_undoBusy) return;
    final linked = row['record_transaction'] == true;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                icon: const TintedIcon(Icons.history, color: Colors.orange),
                title: const Text('Hoàn tác lần trả nợ'),
                content: Text(
                    'Hoàn tác ${_money(row['amount'] as num)} (${paymentDate(row['paid_at'])})? '
                    'Khoản nợ còn lại sẽ tăng tương ứng.${linked ? ' Khoản thu/chi liên kết sẽ được xóa và số dư nguồn tiền được cập nhật.' : ' Không thay đổi thu/chi.'}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Hủy')),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Hoàn tác'))
                ]));
    if (accepted != true || !mounted) return;
    setState(() => _undoBusy = true);
    try {
      await ref
          .read(planningRepositoryProvider)
          .undoDebtPayment(row['id'] as String);
      ref.refreshWalletData();
      await ref.refreshDebts();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _undoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final debt = ref
            .watch(debtsProvider)
            .valueOrNull
            ?.where((d) => d.id == widget.debt.id)
            .firstOrNull ??
        widget.debt;
    final history = ref.watch(debtHistoryProvider(debt.id!));
    final wallets = ref.watch(paymentWalletsProvider).valueOrNull ?? [];
    final settled = debt.isSettled || debt.remaining <= 0;
    final borrow = debt.type == DebtType.borrow;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Chi tiết khoản nợ'), actions: [
        IconButton(
            tooltip: 'Chỉnh sửa khoản nợ',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showDebtForm(context, initial: debt))
      ]),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: GlassCard(
                  blur: true,
                  radius: 22,
                  child: EmeraldButton(
                      label: _undoBusy
                          ? 'Đang hoàn tác…'
                          : settled
                              ? 'Đã tất toán'
                              : borrow
                                  ? 'Ghi trả nợ'
                                  : 'Ghi thu nợ',
                      icon: settled
                          ? Icons.check_circle_outline
                          : Icons.add_circle_outline,
                      onPressed: settled || _undoBusy
                          ? null
                          : () => showDebtPaymentSheet(context, ref, debt))))),
      body: NotebookBackground(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
              children: [
            _DebtSummary(debt: debt),
            const SizedBox(height: 22),
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                      'Lịch sử ${borrow ? 'trả' : 'thu'} nợ • ${history.valueOrNull?.length ?? 0} lần',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  DropdownButton<bool>(
                      value: _newest,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Mới nhất')),
                        DropdownMenuItem(value: false, child: Text('Cũ nhất'))
                      ],
                      onChanged: (v) => setState(() => _newest = v ?? true)),
                ]),
            if (_undoBusy) const LinearProgressIndicator(),
            history.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Text(friendlyError(e)),
                      TextButton(
                          onPressed: () =>
                              ref.invalidate(debtHistoryProvider(debt.id!)),
                          child: const Text('Thử lại'))
                    ])),
                data: (rows) => rows.isEmpty
                    ? const GlassCard(
                        padding: EdgeInsets.all(24),
                        child: Column(children: [
                          TintedIcon(Icons.receipt_long_outlined),
                          SizedBox(height: 12),
                          Text('Chưa có lịch sử thanh toán'),
                          Text('Mỗi lần ghi nhận sẽ xuất hiện tại đây.',
                              textAlign: TextAlign.center)
                        ]))
                    : Column(children: [
                        for (final row in _newest ? rows : rows.reversed)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(children: [
                                      Container(
                                          width: 10,
                                          height: 10,
                                          margin: const EdgeInsets.fromLTRB(
                                              0, 24, 10, 0),
                                          decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle)),
                                      Container(
                                          width: 2,
                                          height: 96,
                                          margin:
                                              const EdgeInsets.only(right: 10),
                                          color: AppColors.primary
                                              .withValues(alpha: .12))
                                    ]),
                                    Expanded(
                                        child: GlassCard(
                                            padding: const EdgeInsets.all(14),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        TintedIcon(
                                                            row['record_transaction'] ==
                                                                    true
                                                                ? Icons
                                                                    .payments_outlined
                                                                : Icons
                                                                    .receipt_outlined,
                                                            size: 36),
                                                        const SizedBox(
                                                            width: 10),
                                                        Expanded(
                                                            child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                              Text(
                                                                  _money(row[
                                                                          'amount']
                                                                      as num),
                                                                  style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w800,
                                                                      fontSize:
                                                                          17)),
                                                              const SizedBox(
                                                                  height: 4),
                                                              Text(
                                                                  paymentDate(row[
                                                                      'paid_at']),
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: AppColors
                                                                          .onSurfaceVariant))
                                                            ])),
                                                        PopupMenuButton<String>(
                                                            enabled: !_undoBusy,
                                                            tooltip:
                                                                'Thao tác lần thanh toán',
                                                            onSelected: (v) => v ==
                                                                    'undo'
                                                                ? _undo(row)
                                                                : showDebtPaymentSheet(
                                                                    context,
                                                                    ref,
                                                                    debt,
                                                                    payment:
                                                                        row),
                                                            itemBuilder:
                                                                (_) => const [
                                                                      PopupMenuItem(
                                                                          value:
                                                                              'edit',
                                                                          child:
                                                                              Text('Chỉnh sửa')),
                                                                      PopupMenuItem(
                                                                          value:
                                                                              'undo',
                                                                          child:
                                                                              Text('Hoàn tác'))
                                                                    ]),
                                                      ]),
                                                  const SizedBox(height: 10),
                                                  _Badge(
                                                      row['is_legacy'] == true
                                                          ? 'Số tiền trước nâng cấp'
                                                          : row['record_transaction'] ==
                                                                  true
                                                              ? 'Đã ghi khoản ${borrow ? 'chi' : 'thu'}'
                                                              : 'Chỉ ghi nhận',
                                                      color:
                                                          row['record_transaction'] ==
                                                                  true
                                                              ? AppColors
                                                                  .primary
                                                              : const Color(
                                                                  0xFF6366D9)),
                                                  if (row['record_transaction'] ==
                                                      true)
                                                    Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 6),
                                                        child: Text(
                                                            wallets
                                                                    .where((w) =>
                                                                        w['id'] ==
                                                                        row[
                                                                            'wallet_id'])
                                                                    .map((w) =>
                                                                        '${w['name']}${w['is_archived'] == true ? ' · Đã lưu trữ' : ''}')
                                                                    .firstOrNull ??
                                                                'Nguồn tiền không còn hoạt động',
                                                            style: const TextStyle(
                                                                fontSize: 12,
                                                                color: AppColors
                                                                    .onSurfaceVariant))),
                                                  if ('${row['note'] ?? ''}'
                                                      .isNotEmpty)
                                                    Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 8),
                                                        child: Text(
                                                            '${row['note']}')),
                                                  if (row['is_legacy'] == true)
                                                    const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                top: 6),
                                                        child: Text(
                                                            'Tổng đã trả trước nâng cấp, không có chi tiết từng lần.',
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: AppColors
                                                                    .onSurfaceVariant))),
                                                ]))),
                                  ])),
                      ])),
          ])),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {this.color = AppColors.primary});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)));
}

class _DebtSummary extends StatelessWidget {
  const _DebtSummary({required this.debt});
  final DebtModel debt;
  @override
  Widget build(BuildContext context) {
    final now = vietnamTime(DateTime.now());
    final status = debtStatus(debt, now);
    final ratio = debt.amount <= 0
        ? 0.0
        : (debt.paidAmount / debt.amount).clamp(0.0, 1.0);
    final borrow = debt.type == DebtType.borrow;
    final urgent = status == 'Quá hạn' || status == 'Đến hạn hôm nay';
    return GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFBFF2DD),
                child: Text(
                    debt.personName.characters.firstOrNull?.toUpperCase() ??
                        '?',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(debt.personName,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                  Text(borrow ? 'Tôi đang nợ' : 'Người này nợ tôi',
                      style: const TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 12)),
                ])),
          ]),
          const SizedBox(height: 12),
          _Badge(status,
              color: urgent
                  ? AppColors.error
                  : status == 'Sắp đến hạn'
                      ? Colors.orange.shade800
                      : AppColors.primary),
          const SizedBox(height: 18),
          const Text('Còn lại', style: TextStyle(fontSize: 12)),
          Text(_money(debt.remaining),
              style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF006657))),
          const SizedBox(height: 14),
          Wrap(spacing: 32, runSpacing: 12, children: [
            _Amount('Tổng nợ', debt.amount),
            _Amount(borrow ? 'Đã trả' : 'Đã thu', debt.paidAmount)
          ]),
          const SizedBox(height: 14),
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE7ECEF))),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
            Text(
                '${borrow ? 'Đã trả' : 'Đã thu'} ${NumberFormat('0.0', 'vi').format(ratio * 100)}%',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700)),
            Text(
                'Còn lại ${NumberFormat('0.0', 'vi').format((1 - ratio) * 100)}%',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.onSurfaceVariant))
          ]),
          const SizedBox(height: 16),
          Wrap(
              spacing: 14,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.calendar_month_outlined, size: 20),
                Text(debt.dueDate == null
                    ? 'Chưa đặt hạn'
                    : 'Hạn ${DateFormat('dd/MM/yyyy').format(debt.dueDate!)}'),
                if (debt.dueDate != null && debt.remaining > 0)
                  Text(debt.dueLabel(now)!,
                      style: TextStyle(
                          color: urgent
                              ? AppColors.error
                              : AppColors.onSurfaceVariant,
                          fontSize: 12)),
              ]),
          if (debt.note?.trim().isNotEmpty == true)
            Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F5),
                    borderRadius: BorderRadius.circular(14)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ghi chú',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(debt.note!)
                    ])),
        ]));
  }
}

class _Amount extends StatelessWidget {
  const _Amount(this.label, this.value);
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 4),
        Text(_money(value), style: const TextStyle(fontWeight: FontWeight.w700))
      ]);
}
