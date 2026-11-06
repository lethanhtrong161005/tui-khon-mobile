import '../../../core/utils/localized_format.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/debt_reminder_service.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../home/providers/home_providers.dart';
import '../data/planning_repository.dart';
import '../data/debt_history.dart';
import '../models/planning_models.dart';

extension PlanningRefresh on WidgetRef {
  /// Reloads the debt book and re-schedules the device reminders.
  Future<void> refreshDebts() async {
    invalidate(debtsProvider);
    invalidate(debtHistoryProvider);
    invalidate(notificationsProvider);
    try {
      final debts = await read(debtsProvider.future);
      await read(debtRemindersProvider).sync(debts);
    } catch (_) {
      // The list shows its own error state.
    }
  }
}

/// Confirms "đã trả" / "đã nhận" (whole remaining amount) or a partial payment,
/// optionally recording the matching income / expense transaction.
Future<bool> showSettleDebtDialog(
    BuildContext context, WidgetRef ref, DebtModel debt,
    {bool partial = false}) async {
  final result = await showDialog<(int?, bool)>(
    context: context,
    builder: (_) => _SettleDialog(debt: debt, partial: partial),
  );
  if (result == null || debt.id == null) return false;

  try {
    await ref.read(planningRepositoryProvider).settleDebt(
          debt.id!,
          amount: result.$1,
          recordTransaction: result.$2,
        );
    if (result.$2) ref.refreshWalletData();
    await ref.refreshDebts();
    if (context.mounted) {
      showToast(
          context,
          result.$1 == null
              ? appL10n(context)
                  .msgSettledTheDebtWith257((debt.personName).toString())
              : appL10n(context).msgPaymentRecorded258);
    }
    return true;
  } catch (e) {
    if (context.mounted) showToast(context, friendlyError(e, context: context));
    return false;
  }
}

/// Returns (amount or null for "everything left", record a transaction?).
/// Owns its controller so the closing animation never touches a disposed one.
class _SettleDialog extends StatefulWidget {
  const _SettleDialog({required this.debt, required this.partial});

  final DebtModel debt;
  final bool partial;

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  final _amount = TextEditingController();
  bool _recordTransaction = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debt = widget.debt;
    final isBorrow = debt.type == DebtType.borrow;
    final title = widget.partial
        ? appL10n(context).msgRecordPartialPayment243
        : (isBorrow
            ? appL10n(context).msgConfirmDebtRepayment259
            : appL10n(context).msgConfirmMoneyCollected260);
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBorrow
                  ? appL10n(context).msgYouOweRemaining261(
                      (debt.personName).toString(),
                      (formatMoney(context, debt.remaining)).toString())
                  : appL10n(context).msgOwesYouRemaining262(
                      (debt.personName).toString(),
                      (formatMoney(context, debt.remaining)).toString()),
            ),
            if (widget.partial) ...[
              const SizedBox(height: 12),
              MoneyField(
                  controller: _amount,
                  label: appL10n(context).msgAmountPaid263,
                  autofocus: true),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _recordTransaction,
              activeColor: appPalette(context).primary,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(appL10n(context).msgRecordAMatchingTransaction264,
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                isBorrow
                    ? appL10n(context).msgAddADebtRepaymentExpense265
                    : appL10n(context).msgAddADebtCollectionIncome266,
                style: const TextStyle(fontSize: 11),
              ),
              onChanged: (v) => setState(() => _recordTransaction = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(appL10n(context).msgCancel42)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: appPalette(context).primary,
              foregroundColor: appPalette(context).onPrimary),
          onPressed: () {
            if (!widget.partial)
              return Navigator.pop(context, (null, _recordTransaction));
            final value = MoneyField.valueOf(_amount);
            if (value <= 0 || value > debt.remaining) {
              showToast(
                  context,
                  appL10n(context).msgAmountMustBeBetweenAnd267(
                      (formatMoney(context, debt.remaining)).toString()));
              return;
            }
            Navigator.pop(context, (value, _recordTransaction));
          },
          child: Text(appL10n(context).msgConfirm268),
        ),
      ],
    );
  }
}
