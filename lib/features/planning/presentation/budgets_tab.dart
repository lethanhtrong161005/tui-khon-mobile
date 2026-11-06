import '../../../core/utils/localized_format.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/glass.dart';
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
      final copied = await ref
          .read(planningRepositoryProvider)
          .copyBudgetsFromPreviousMonth(_month);
      _refresh();
      if (mounted) {
        showToast(
            context,
            copied == 0
                ? appL10n(context).msgNoBudgetsWereSetLastMonth215
                : appL10n(context).msgCopiedBudgets216((copied).toString()));
      }
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e, context: context));
    }
  }

  Future<void> _openForm({BudgetProgress? initial}) async {
    final budgets =
        ref.read(budgetsProvider(_month)).valueOrNull ?? <BudgetProgress>[];
    final saved = await showFormSheet<bool>(
      context,
      _BudgetForm(
          month: _month,
          initial: initial,
          taken: {for (final b in budgets) b.categoryId}),
    );
    if (saved == true) _refresh();
  }

  Future<void> _delete(BudgetProgress budget) async {
    if (!await confirmDialog(context,
        title: appL10n(context).msgDeleteBudget217,
        message: appL10n(context).msgDeleteTheLimitForThisMonth218(
            (budget.categoryName ?? appL10n(context).msgTotalSpending449)
                .toString()))) {
      return;
    }
    try {
      await ref.read(planningRepositoryProvider).deleteBudget(budget.id);
      _refresh();
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e, context: context));
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
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1)),
            ),
            Expanded(
                child: Text(
              appL10n(context).msgMonth219(
                  (_month.month.toString().padLeft(2, '0')).toString(),
                  (_month.year).toString()),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            )),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1)),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(appL10n(context).msgAddBudget220),
                style: ElevatedButton.styleFrom(
                    backgroundColor: appPalette(context).primary,
                    foregroundColor: appPalette(context).onPrimary),
              ),
            ),
            if (isCurrentOrFuture) ...[
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton.icon(
                onPressed: _copyPrevious,
                icon: const Icon(Icons.copy_all, size: 18),
                label: Text(appL10n(context).msgCopy221),
              )),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (budgets == null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: budgetsAsync.hasError
                  ? Text(friendlyError(budgetsAsync.error!, context: context))
                  : CircularProgressIndicator(
                      color: appPalette(context).primary),
            ),
          )
        else if (budgets.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: appPalette(context).surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              appL10n(context).msgNoBudgetForThisMonthYet222,
              style: TextStyle(
                  fontSize: 13, color: appPalette(context).onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(appL10n(context).msgYourBudgets223,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800))),
          for (final b in budgets)
            _BudgetCard(
                budget: b,
                category: (ref.watch(categoriesProvider).valueOrNull ??
                        <CategoryModel>[])
                    .where((c) => c.id == b.categoryId)
                    .firstOrNull,
                onTap: () => _openForm(initial: b),
                onDelete: () => _delete(b)),
        ],
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard(
      {required this.budget,
      required this.onTap,
      required this.onDelete,
      this.category});
  final BudgetProgress budget;
  final CategoryModel? category;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ratio = budget.ratio;
    final color =
        ratio >= 0.8 ? appPalette(context).error : AppColors.primaryContainer;
    final left = budget.limitAmount - budget.spent;
    final iconColor = category?.colorValue ?? const Color(0xFFFFA51C);
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
            radius: 23,
            child: InkWell(
                borderRadius: BorderRadius.circular(23),
                onTap: onTap,
                onLongPress: onDelete,
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TintedIcon(
                              category?.iconData ?? Icons.donut_large_rounded,
                              color: iconColor,
                              size: 45),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(
                                          budget.categoryName ??
                                              appL10n(context)
                                                  .msgTotalMonthlySpending224,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700))),
                                  SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: IconButton(
                                          padding: EdgeInsets.zero,
                                          tooltip: appL10n(context)
                                              .msgDeleteBudget225,
                                          onPressed: onDelete,
                                          icon: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 16,
                                              color:
                                                  appPalette(context).outline)))
                                ]),
                                const SizedBox(height: 4),
                                Wrap(spacing: 4, children: [
                                  Text(formatMoney(context, budget.spent),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                      '/ ${formatMoney(context, budget.limitAmount)}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: appPalette(context)
                                              .onSurfaceVariant))
                                ]),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Expanded(
                                      child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                              value: ratio.clamp(0, 1),
                                              minHeight: 8,
                                              backgroundColor:
                                                  appPalette(context)
                                                      .surfaceContainerLow,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                      color)))),
                                  const SizedBox(width: 12),
                                  Text('${(ratio * 100).round()}%',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700))
                                ]),
                                if (left < 0)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                          appL10n(context).msgOverBy226(
                                              (formatMoney(context, -left))
                                                  .toString()),
                                          style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  appPalette(context).error))),
                              ])),
                        ])))));
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
  late final _limit = TextEditingController(
      text: widget.initial == null ? '' : '${widget.initial!.limitAmount}');
  bool _busy = false;

  Future<void> _save() async {
    final limit = MoneyField.valueOf(_limit);
    if (limit <= 0)
      return showToast(context, appL10n(context).msgEnterALimitGreaterThan227);
    setState(() => _busy = true);
    try {
      await ref.read(planningRepositoryProvider).saveBudget(
            month: widget.month,
            categoryId: _selected == _total ? null : _selected,
            limitAmount: limit,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e, context: context));
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
    final categories =
        (ref.watch(categoriesProvider).valueOrNull ?? <CategoryModel>[])
            .where((c) => c.type == TransactionType.expense)
            .where((c) => editing || !widget.taken.contains(c.id))
            .toList();
    final totalAvailable = editing || !widget.taken.contains(null);
    final options = [
      if (totalAvailable) _total,
      for (final c in categories) c.id
    ];
    if (!options.contains(_selected) && options.isNotEmpty)
      _selected = options.first;

    return FormSheet(
      title: editing
          ? appL10n(context).msgEditBudget228
          : appL10n(context).msgAddBudget220,
      submitLabel: appL10n(context).msgSave43,
      busy: _busy,
      onSubmit: _save,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('budget-${categories.length}'),
          initialValue: _selected,
          isExpanded: true,
          decoration: sheetInputDecoration(appL10n(context).msgAppliesTo229),
          items: [
            if (totalAvailable)
              DropdownMenuItem(
                  value: _total,
                  child: Text(appL10n(context).msgTotalMonthlySpending224)),
            for (final c in categories)
              DropdownMenuItem(
                value: c.id,
                child: Row(children: [
                  Icon(c.iconData, size: 18, color: c.colorValue),
                  const SizedBox(width: 8),
                  Flexible(
                      child: Text(c.name, overflow: TextOverflow.ellipsis)),
                ]),
              ),
          ],
          onChanged:
              editing ? null : (v) => setState(() => _selected = v ?? _total),
        ),
        const SizedBox(height: 12),
        MoneyField(
            controller: _limit,
            label: appL10n(context).msgMonthlyLimitVnd230,
            autofocus: !editing),
      ],
    );
  }
}
