import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/debt_reminder_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../home/providers/home_providers.dart';
import '../data/planning_repository.dart';
import '../models/planning_models.dart';

extension PlanningRefresh on WidgetRef {
  /// Reloads the debt book and re-schedules the device reminders.
  Future<void> refreshDebts() async {
    invalidate(debtsProvider);
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
Future<bool> showSettleDebtDialog(BuildContext context, WidgetRef ref, DebtModel debt, {bool partial = false}) async {
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
      showToast(context, result.$1 == null ? 'Đã tất toán khoản nợ với ${debt.personName}' : 'Đã ghi nhận khoản trả');
    }
    return true;
  } catch (e) {
    if (context.mounted) showToast(context, friendlyError(e));
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
    final title = widget.partial ? 'Ghi trả một phần' : (isBorrow ? 'Xác nhận đã trả nợ' : 'Xác nhận đã nhận tiền');
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBorrow
                  ? 'Bạn nợ ${debt.personName}: còn ${CurrencyFormatter.formatVND(debt.remaining)}'
                  : '${debt.personName} nợ bạn: còn ${CurrencyFormatter.formatVND(debt.remaining)}',
            ),
            if (widget.partial) ...[
              const SizedBox(height: 12),
              MoneyField(controller: _amount, label: 'Số tiền đã trả', autofocus: true),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _recordTransaction,
              activeColor: AppColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Ghi kèm vào giao dịch', style: TextStyle(fontSize: 13)),
              subtitle: Text(
                isBorrow ? 'Thêm một khoản chi "Trả nợ"' : 'Thêm một khoản thu "Thu nợ"',
                style: const TextStyle(fontSize: 11),
              ),
              onChanged: (v) => setState(() => _recordTransaction = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          onPressed: () {
            if (!widget.partial) return Navigator.pop(context, (null, _recordTransaction));
            final value = MoneyField.valueOf(_amount);
            if (value <= 0 || value > debt.remaining) {
              showToast(context, 'Số tiền phải từ 1đ đến ${CurrencyFormatter.formatVND(debt.remaining)}');
              return;
            }
            Navigator.pop(context, (value, _recordTransaction));
          },
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
