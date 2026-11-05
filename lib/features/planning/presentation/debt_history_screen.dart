import '../../../core/utils/debt_labels.dart';
import '../../../core/utils/localized_format.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/glass.dart';
import '../../home/providers/home_providers.dart';
import '../data/debt_history.dart';
import '../data/planning_repository.dart';
import '../models/planning_models.dart';
import 'debt_actions.dart';
import 'debt_payment_sheet.dart';
import 'debts_tab.dart';

String debtStatus(DebtModel debt, DateTime vietnamToday,
    {BuildContext? context}) {
  if (debt.isSettled || debt.remaining <= 0)
    return appL10n(context).msgSettled238;
  final days = debt.daysUntilDue(vietnamToday);
  if (days != null && days < 0) return appL10n(context).msgOverdue269;
  if (days == 0) return appL10n(context).msgDueToday270;
  if (days != null && days <= 3) return appL10n(context).msgDueSoon271;
  return appL10n(context).msgOutstanding272;
}

String _money(num value, {BuildContext? context}) =>
    formatMoney(context, value);

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
                title: Text(appL10n(context).msgUndoDebtPayment273),
                content: Text(appL10n(context)
                    .msgUndoTheOutstandingDebtWillIncrease274(
                        (_money(row['amount'] as num, context: context))
                            .toString(),
                        (paymentDate(row['paid_at'])).toString(),
                        (linked
                            ? appL10n(context).undoLinkedEffect
                            : appL10n(context).undoNoCashEffect))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(appL10n(context).msgCancel275)),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: appPalette(context).error),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(appL10n(context).msgUndo276))
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyError(e, context: context))));
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
      appBar: AppBar(title: Text(appL10n(context).msgDebtDetails277), actions: [
        IconButton(
            tooltip: appL10n(context).msgEditDebtInformation278,
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
                          ? appL10n(context).msgUndoing279
                          : settled
                              ? appL10n(context).msgSettled238
                              : borrow
                                  ? appL10n(context).msgRecordRepayment280
                                  : appL10n(context).msgRecordCollection281,
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
                      (borrow
                          ? appL10n(context).repaymentHistory(
                              history.valueOrNull?.length ?? 0)
                          : appL10n(context).collectionHistory(
                              history.valueOrNull?.length ?? 0)),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  DropdownButton<bool>(
                      value: _newest,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(
                            value: true,
                            child: Text(appL10n(context).msgNewest283)),
                        DropdownMenuItem(
                            value: false,
                            child: Text(appL10n(context).msgOldest284))
                      ],
                      onChanged: (v) => setState(() => _newest = v ?? true)),
                ]),
            if (_undoBusy) const LinearProgressIndicator(),
            history.when(
                loading: () =>
                    const Center(child: const CircularProgressIndicator()),
                error: (e, _) => GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Text(friendlyError(e, context: context)),
                      TextButton(
                          onPressed: () =>
                              ref.invalidate(debtHistoryProvider(debt.id!)),
                          child: Text(appL10n(context).msgRetry50))
                    ])),
                data: (rows) => rows.isEmpty
                    ? GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(children: [
                          const TintedIcon(Icons.receipt_long_outlined),
                          const SizedBox(height: 12),
                          Text(appL10n(context).msgNoPaymentHistoryYet285),
                          Text(
                              appL10n(context)
                                  .msgEachPaymentYouRecordWillAppear286,
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
                                          decoration: BoxDecoration(
                                              color:
                                                  appPalette(context).primary,
                                              shape: BoxShape.circle)),
                                      Container(
                                          width: 2,
                                          height: 96,
                                          margin:
                                              const EdgeInsets.only(right: 10),
                                          color: appPalette(context)
                                              .primary
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
                                                                  _money(
                                                                      row['amount']
                                                                          as num,
                                                                      context:
                                                                          context),
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
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: appPalette(
                                                                              context)
                                                                          .onSurfaceVariant))
                                                            ])),
                                                        PopupMenuButton<String>(
                                                            enabled: !_undoBusy,
                                                            tooltip: appL10n(
                                                                    context)
                                                                .msgPaymentActions287,
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
                                                                (_) => [
                                                                      PopupMenuItem(
                                                                          value:
                                                                              'edit',
                                                                          child:
                                                                              Text(appL10n(context).msgEdit288)),
                                                                      PopupMenuItem(
                                                                          value:
                                                                              'undo',
                                                                          child:
                                                                              Text(appL10n(context).msgUndo276))
                                                                    ]),
                                                      ]),
                                                  const SizedBox(height: 10),
                                                  _Badge(
                                                      row['is_legacy'] == true
                                                          ? appL10n(context)
                                                              .msgPaidBeforeTheUpgrade289
                                                          : row['record_transaction'] ==
                                                                  true
                                                              ? (borrow
                                                                  ? appL10n(context)
                                                                      .recordExpense
                                                                  : appL10n(
                                                                          context)
                                                                      .recordIncome)
                                                              : appL10n(context)
                                                                  .msgRecordOnly291,
                                                      color:
                                                          row['record_transaction'] ==
                                                                  true
                                                              ? appPalette(
                                                                      context)
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
                                                                        '${w['name']}${w['is_archived'] == true ? appL10n(context).archivedSuffix : ''}')
                                                                    .firstOrNull ??
                                                                appL10n(context)
                                                                    .msgMoneySourceNoLongerAvailable292,
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: appPalette(
                                                                        context)
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
                                                    Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 6),
                                                        child: Text(
                                                            appL10n(context)
                                                                .msgTotalPaidBeforeTheUpgradeIndividual293,
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: appPalette(
                                                                        context)
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
    final status = debtStatus(debt, now, context: context);
    final days = debt.daysUntilDue(now);
    final ratio = debt.amount <= 0
        ? 0.0
        : (debt.paidAmount / debt.amount).clamp(0.0, 1.0);
    final borrow = debt.type == DebtType.borrow;
    final urgent = debt.remaining > 0 && days != null && days <= 0;
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
                    style: TextStyle(
                        color: appPalette(context).primary,
                        fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(debt.personName,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                  Text(
                      borrow
                          ? appL10n(context).msgIOweMoney231
                          : appL10n(context).msgThisPersonOwesMe294,
                      style: TextStyle(
                          color: appPalette(context).onSurfaceVariant,
                          fontSize: 12)),
                ])),
          ]),
          const SizedBox(height: 12),
          _Badge(status,
              color: urgent
                  ? appPalette(context).error
                  : debt.remaining > 0 && days != null && days > 0 && days <= 3
                      ? Colors.orange.shade800
                      : appPalette(context).primary),
          const SizedBox(height: 18),
          Text(appL10n(context).msgRemaining295,
              style: const TextStyle(fontSize: 12)),
          Text(_money(debt.remaining, context: context),
              style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  color: appPalette(context).primary)),
          const SizedBox(height: 14),
          Wrap(spacing: 32, runSpacing: 12, children: [
            _Amount(appL10n(context).msgTotalDebt296, debt.amount),
            _Amount(
                borrow
                    ? appL10n(context).msgPaid184
                    : appL10n(context).msgCollected297,
                debt.paidAmount)
          ]),
          const SizedBox(height: 14),
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor:
                      adaptiveSurface(context, const Color(0xFFE7ECEF)))),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
            Text(
                '${borrow ? appL10n(context).msgPaid184 : appL10n(context).msgCollected297} ${NumberFormat('0.0', appL10n(context).localeName).format(ratio * 100)}%',
                style: TextStyle(
                    fontSize: 11,
                    color: appPalette(context).primary,
                    fontWeight: FontWeight.w700)),
            Text(
                appL10n(context).msgRemaining298(
                    (NumberFormat('0.0', appL10n(context).localeName)
                            .format((1 - ratio) * 100))
                        .toString()),
                style: TextStyle(
                    fontSize: 11, color: appPalette(context).onSurfaceVariant))
          ]),
          const SizedBox(height: 16),
          Wrap(
              spacing: 14,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.calendar_month_outlined, size: 20),
                Text(debt.dueDate == null
                    ? appL10n(context).msgNoDueDate299
                    : appL10n(context).msgDue300(
                        (DateFormat('dd/MM/yyyy').format(debt.dueDate!))
                            .toString())),
                if (debt.dueDate != null && debt.remaining > 0)
                  Text(debtDueLabel(context, debt, now)!,
                      style: TextStyle(
                          color: urgent
                              ? appPalette(context).error
                              : appPalette(context).onSurfaceVariant,
                          fontSize: 12)),
              ]),
          if (debt.note?.trim().isNotEmpty == true)
            Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: adaptiveSurface(context, const Color(0xFFF0F4F5)),
                    borderRadius: BorderRadius.circular(14)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appL10n(context).msgNote24,
                          style: TextStyle(
                              fontSize: 11,
                              color: appPalette(context).onSurfaceVariant)),
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
            style: TextStyle(
                color: appPalette(context).onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 4),
        Text(_money(value, context: context),
            style: const TextStyle(fontWeight: FontWeight.w700))
      ]);
}
