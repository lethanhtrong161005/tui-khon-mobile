import '../../../core/utils/debt_labels.dart';
import '../../../core/utils/localized_format.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../data/planning_repository.dart';
import '../models/planning_models.dart';
import 'debt_actions.dart';
import 'debt_history_screen.dart';

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
            ? Text(friendlyError(debtsAsync.error!, context: context),
                style: TextStyle(color: appPalette(context).onSurfaceVariant))
            : CircularProgressIndicator(color: appPalette(context).primary),
      );
    }

    final active = debts.where((d) => !d.isSettled).toList();
    final borrow = active.where((d) => d.type == DebtType.borrow).toList();
    final lend = active.where((d) => d.type == DebtType.lend).toList();
    final settled = debts.where((d) => d.isSettled).toList();
    int total(List<DebtModel> list) => list.fold(0, (s, d) => s + d.remaining);

    return RefreshIndicator(
      color: appPalette(context).primary,
      onRefresh: ref.refreshDebts,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            children: [
              Expanded(
                  child: _totalCard(context, appL10n(context).msgIOweMoney231,
                      total(borrow), appPalette(context).error)),
              const SizedBox(width: 10),
              Expanded(
                  child: _totalCard(context, appL10n(context).msgOthersOweMe232,
                      total(lend), appPalette(context).primary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            appL10n(context).msgTheDebtBookIsARecord233,
            style: TextStyle(
                fontSize: 11, color: appPalette(context).onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (active.isEmpty) _empty(context),
          if (borrow.isNotEmpty) ...[
            _sectionTitle(
                appL10n(context).msgIOwe234((borrow.length).toString())),
            for (final d in borrow) DebtTile(debt: d, today: today),
          ],
          if (lend.isNotEmpty) ...[
            _sectionTitle(
                appL10n(context).msgOwedToMe235((lend.length).toString())),
            for (final d in lend) DebtTile(debt: d, today: today),
          ],
          if (settled.isNotEmpty)
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                    appL10n(context).msgSettled236((settled.length).toString()),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                children: [
                  for (final d in settled) DebtTile(debt: d, today: today)
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _totalCard(
      BuildContext context, String label, int amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: appPalette(context).onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(formatMoney(context, amount),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      );

  Widget _empty(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: appPalette(context).surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.handshake, color: appPalette(context).outline, size: 32),
            const SizedBox(height: 8),
            Text(appL10n(context).msgNoOpenDebtsYetTapAdd237,
                style: TextStyle(
                    fontSize: 13, color: appPalette(context).onSurfaceVariant),
                textAlign: TextAlign.center),
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
        ? appPalette(context).onSurfaceVariant
        : days < 0
            ? appPalette(context).error
            : days <= 1
                ? appPalette(context).tertiary
                : appPalette(context).onSurfaceVariant;
    final isBorrow = debt.type == DebtType.borrow;
    final color =
        isBorrow ? appPalette(context).error : appPalette(context).primary;

    return Card(
      elevation: 0,
      color: appPalette(context).surfaceContainerLowest,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => DebtHistoryScreen(debt: debt))),
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
                      debt.personName.isEmpty
                          ? '?'
                          : String.fromCharCode(debt.personName.runes.first)
                              .toUpperCase(),
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBorrow
                              ? appL10n(context)
                                  .msgIOwe182((debt.personName).toString())
                              : appL10n(context)
                                  .msgOwesMe183((debt.personName).toString()),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          [
                            if (debt.isSettled)
                              appL10n(context).msgSettled238
                            else if (debtDueLabel(context, debt, today) != null)
                              debtDueLabel(context, debt, today)!,
                            if (debt.note != null) debt.note!,
                          ].join(' • '),
                          style: TextStyle(
                              fontSize: 11,
                              color: debt.isSettled
                                  ? appPalette(context).primary
                                  : dueColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          formatMoney(context,
                              debt.isSettled ? debt.amount : debt.remaining),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: color)),
                      if (debt.paidAmount > 0 && !debt.isSettled)
                        Text('/ ${formatMoney(context, debt.amount)}',
                            style: TextStyle(
                                fontSize: 10,
                                color: appPalette(context).onSurfaceVariant)),
                    ],
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 18, color: appPalette(context).onSurfaceVariant),
                    onSelected: (value) async {
                      switch (value) {
                        case 'partial':
                          await showSettleDebtDialog(context, ref, debt,
                              partial: true);
                        case 'settle':
                          await showSettleDebtDialog(context, ref, debt);
                        case 'edit':
                          await showDebtForm(context, initial: debt);
                        case 'delete':
                          if (await confirmDialog(context,
                              title: appL10n(context).msgDeleteDebt239,
                              message: appL10n(context)
                                  .msgDeleteTheDebtRecordWith240(
                                      (debt.personName).toString()))) {
                            try {
                              await ref
                                  .read(planningRepositoryProvider)
                                  .deleteDebt(debt.id!);
                              await ref.refreshDebts();
                            } catch (e) {
                              if (context.mounted)
                                showToast(context,
                                    friendlyError(e, context: context));
                            }
                          }
                      }
                    },
                    itemBuilder: (_) => [
                      if (!debt.isSettled) ...[
                        PopupMenuItem(
                            value: 'settle',
                            child: Text(isBorrow
                                ? appL10n(context).msgFullyPaid241
                                : appL10n(context).msgFullyCollected242)),
                        PopupMenuItem(
                            value: 'partial',
                            child: Text(
                                appL10n(context).msgRecordPartialPayment243)),
                        PopupMenuItem(
                            value: 'edit',
                            child: Text(appL10n(context).msgEdit244)),
                      ],
                      PopupMenuItem(
                          value: 'delete',
                          child: Text(appL10n(context).msgDelete41)),
                    ],
                  ),
                ],
              ),
              if (debt.paidAmount > 0 && !debt.isSettled) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: debt.paidAmount / debt.amount,
                  minHeight: 5,
                  backgroundColor: appPalette(context).surfaceContainerHigh,
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
Future<void> showDebtForm(BuildContext context,
    {DebtModel? initial, DebtType type = DebtType.borrow}) {
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
  late final _name =
      TextEditingController(text: widget.initial?.personName ?? '');
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final _amount = TextEditingController(
      text: widget.initial == null ? '' : '${widget.initial!.amount}');
  late final _note = TextEditingController(text: widget.initial?.note ?? '');
  late DateTime? _dueDate = widget.initial?.dueDate;
  bool _busy = false;

  Future<void> _save() async {
    final amount = MoneyField.valueOf(_amount);
    if (_name.text.trim().isEmpty)
      return showToast(
          context, appL10n(context).msgEnterTheLenderOrBorrowerName245);
    if (amount <= 0)
      return showToast(
          context, appL10n(context).msgEnterAnAmountGreaterThan246);
    if (widget.initial != null && amount < widget.initial!.paidAmount) {
      return showToast(
          context, appL10n(context).msgAmountCannotBeLessThanWhat247);
    }

    setState(() => _busy = true);
    try {
      await ref.read(planningRepositoryProvider).saveDebt(DebtModel(
            id: widget.initial?.id,
            type: _type,
            personName: _name.text,
            phone: _phone.text,
            paidAmount: widget.initial?.paidAmount ?? 0,
            isSettled: widget.initial?.isSettled ?? false,
            amount: amount,
            dueDate: _dueDate,
            note: _note.text,
          ));
      await ref.refreshDebts();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e, context: context));
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
      title: widget.initial == null
          ? appL10n(context).msgAddDebt248
          : appL10n(context).msgEditDebt249,
      submitLabel: appL10n(context).msgSave43,
      busy: _busy,
      onSubmit: _save,
      children: [
        SegmentedButton<DebtType>(
          segments: [
            ButtonSegment(
                value: DebtType.borrow,
                label: Text(appL10n(context).msgIOwe250),
                icon: const Icon(Icons.call_made)),
            ButtonSegment(
                value: DebtType.lend,
                label: Text(appL10n(context).msgOwedToMe251),
                icon: const Icon(Icons.call_received)),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: sheetInputDecoration(_type == DebtType.borrow
              ? appL10n(context).msgWhoDoIOwe252
              : appL10n(context).msgWhoOwesMe253),
        ),
        const SizedBox(height: 12),
        MoneyField(
            controller: _amount, label: appL10n(context).msgAmountVnd200),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration:
              sheetInputDecoration(appL10n(context).msgPhoneNumberOptional254),
        ),
        const SizedBox(height: 12),
        TextField(
            controller: _note,
            maxLength: 255,
            decoration:
                sheetInputDecoration(appL10n(context).msgNoteOptional255)),
        DatePickerTile(
          label: appL10n(context).msgDueDate256,
          value: _dueDate,
          onChanged: (d) => setState(() => _dueDate = d),
        ),
      ],
    );
  }
}
