import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../home/models/category_model.dart';
import '../../home/models/monthly_summary.dart';
import '../../home/models/transaction_model.dart';
import '../../home/providers/home_providers.dart';
import '../data/planning_repository.dart';

/// Monthly spending limits: a month-wide budget and/or per-category budgets.
/// The database raises 80% / 100% alerts on its own (check_budget_alert).
class BudgetsTab extends ConsumerStatefulWidget {
  const BudgetsTab({super.key});

  @override
  ConsumerState<BudgetsTab> createState() => _BudgetsTabState();
}

class _BudgetsTabState extends ConsumerState<BudgetsTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _refresh() {
    ref.invalidate(budgetsProvider(_month));
    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(notificationsProvider);
  }

  Future<void> _copyPrevious() async {
    try {
      final copied = await ref.read(planningRepositoryProvider).copyBudgetsFromPreviousMonth(_month);
      _refresh();
      if (mounted) {
        showToast(context, copied == 0 ? 'Tháng trước chưa có ngân sách nào' : 'Đã sao chép $copied ngân sách');
      }
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
    }
  }

  Future<void> _openForm({BudgetProgress? initial}) async {
    final budgets = ref.read(budgetsProvider(_month)).valueOrNull ?? const <BudgetProgress>[];
    final saved = await showFormSheet<bool>(
      context,
      _BudgetForm(month: _month, initial: initial, taken: {for (final b in budgets) b.categoryId}),
    );
    if (saved == true) _refresh();
  }

  Future<void> _delete(BudgetProgress budget) async {
    if (!await confirmDialog(context,
        title: 'Xoá ngân sách?', message: 'Xoá hạn mức "${budget.categoryName ?? 'Tổng chi tiêu'}" của tháng này?')) {
      return;
    }
    try {
      await ref.read(planningRepositoryProvider).deleteBudget(budget.id);
      _refresh();
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsProvider(_month));
    final budgets = budgetsAsync.valueOrNull;
    final now = DateTime.now();
    final isCurrentOrFuture = !_month.isBefore(DateTime(now.year, now.month));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            ),
            Text(
              'Tháng ${_month.month.toString().padLeft(2, '0')}/${_month.year}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm ngân sách'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ),
            if (isCurrentOrFuture) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _copyPrevious,
                icon: const Icon(Icons.copy_all, size: 18),
                label: const Text('Từ tháng trước'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (budgets == null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: budgetsAsync.hasError
                  ? Text(friendlyError(budgetsAsync.error!))
                  : const CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (budgets.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Chưa đặt ngân sách cho tháng này.\nĐặt hạn mức tổng hoặc cho từng danh mục, Túi Khôn sẽ nhắc khi bạn chi tới 80% và 100%.',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final b in budgets) _BudgetCard(budget: b, onTap: () => _openForm(initial: b), onDelete: () => _delete(b)),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, required this.onTap, required this.onDelete});

  final BudgetProgress budget;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ratio = budget.ratio;
    final color = ratio >= 1 ? AppColors.error : (ratio >= 0.8 ? AppColors.tertiary : AppColors.primary);
    final left = budget.limitAmount - budget.spent;
    return Card(
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(budget.categoryId == null ? Icons.donut_large : Icons.category, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(budget.categoryName ?? 'Tổng chi tiêu tháng',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  Text('${(ratio * 100).round()}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.outline),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${CurrencyFormatter.formatVND(budget.spent)} / ${CurrencyFormatter.formatVND(budget.limitAmount)} • '
                '${left >= 0 ? 'còn ${CurrencyFormatter.formatVND(left)}' : 'vượt ${CurrencyFormatter.formatVND(-left)}'}',
                style: TextStyle(fontSize: 12, color: left >= 0 ? AppColors.onSurfaceVariant : AppColors.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetForm extends ConsumerStatefulWidget {
  const _BudgetForm({required this.month, required this.taken, this.initial});

  final DateTime month;
  final BudgetProgress? initial;

  /// Category ids (null = month-wide) that already have a budget this month.
  final Set<String?> taken;

  @override
  ConsumerState<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends ConsumerState<_BudgetForm> {
  static const _total = '__total__';
  late String _selected = widget.initial?.categoryId ?? _total;
  late final _limit = TextEditingController(text: widget.initial == null ? '' : '${widget.initial!.limitAmount}');
  bool _busy = false;

  Future<void> _save() async {
    final limit = MoneyField.valueOf(_limit);
    if (limit <= 0) return showToast(context, 'Nhập hạn mức lớn hơn 0');
    setState(() => _busy = true);
    try {
      await ref.read(planningRepositoryProvider).saveBudget(
            month: widget.month,
            categoryId: _selected == _total ? null : _selected,
            limitAmount: limit,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    final categories = (ref.watch(categoriesProvider).valueOrNull ?? const <CategoryModel>[])
        .where((c) => c.type == TransactionType.expense)
        .where((c) => editing || !widget.taken.contains(c.id))
        .toList();
    final totalAvailable = editing || !widget.taken.contains(null);
    final options = [if (totalAvailable) _total, for (final c in categories) c.id];
    if (!options.contains(_selected) && options.isNotEmpty) _selected = options.first;

    return FormSheet(
      title: editing ? 'Sửa ngân sách' : 'Thêm ngân sách',
      submitLabel: 'Lưu',
      busy: _busy,
      onSubmit: _save,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('budget-${categories.length}'),
          initialValue: _selected,
          isExpanded: true,
          decoration: sheetInputDecoration('Áp dụng cho'),
          items: [
            if (totalAvailable) const DropdownMenuItem(value: _total, child: Text('Tổng chi tiêu tháng')),
            for (final c in categories)
              DropdownMenuItem(
                value: c.id,
                child: Row(children: [
                  Icon(c.iconData, size: 18, color: c.colorValue),
                  const SizedBox(width: 8),
                  Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                ]),
              ),
          ],
          onChanged: editing ? null : (v) => setState(() => _selected = v ?? _total),
        ),
        const SizedBox(height: 12),
        MoneyField(controller: _limit, label: 'Hạn mức trong tháng (VND)', autofocus: !editing),
      ],
    );
  }
}
