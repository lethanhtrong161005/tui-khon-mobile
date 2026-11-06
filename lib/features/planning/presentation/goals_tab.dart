import '../../../core/utils/localized_format.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/category_icons.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/icon_color_picker.dart';
import '../../home/providers/home_providers.dart';
import '../data/planning_repository.dart';
import '../models/planning_models.dart';

/// Savings goals. "Nạp thêm" only updates the noted amount — money is not
/// moved out of any wallet. The database marks a goal completed when reached.
class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final goals = goalsAsync.valueOrNull;
    if (goals == null) {
      return Center(
        child: goalsAsync.hasError
            ? Text(friendlyError(goalsAsync.error!, context: context))
            : CircularProgressIndicator(color: appPalette(context).primary),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        if (goals.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: appPalette(context).surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.savings,
                    color: appPalette(context).outline, size: 32),
                const SizedBox(height: 8),
                Text(appL10n(context).msgNoGoalsYetSetAGoal314,
                    style: TextStyle(
                        fontSize: 13,
                        color: appPalette(context).onSurfaceVariant),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        for (final g in goals) _GoalCard(goal: g),
      ],
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal});

  final GoalModel goal;

  Future<void> _adjust(BuildContext context, WidgetRef ref,
      {required bool deposit}) async {
    final amount = await showAmountDialog(
      context,
      title: deposit
          ? appL10n(context).msgAddTo315((goal.name).toString())
          : appL10n(context).msgWithdrawFrom316((goal.name).toString()),
    );
    if (amount == null || amount <= 0) return;

    final next = deposit
        ? goal.savedAmount + amount
        : (goal.savedAmount - amount).clamp(0, goal.savedAmount);
    try {
      await ref.read(planningRepositoryProvider).setGoalSaved(goal.id!, next);
      ref.invalidate(goalsProvider);
      ref.invalidate(notificationsProvider);
      if (context.mounted &&
          deposit &&
          next >= goal.targetAmount &&
          !goal.isCompleted) {
        showToast(
            context,
            appL10n(context).msgCongratulationsYouCompletedTheGoal317(
                (goal.name).toString()));
      }
    } catch (e) {
      if (context.mounted)
        showToast(context, friendlyError(e, context: context));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorFromHex(goal.color) ?? appPalette(context).primary;
    return Card(
      elevation: 0,
      color: appPalette(context).surfaceContainerLowest,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showGoalForm(context, initial: goal),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(CategoryIcons.resolve(goal.icon),
                        color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(goal.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        Text(
                          goal.isCompleted
                              ? appL10n(context).msgCompleted318
                              : [
                                  appL10n(context).msgRemaining319(
                                      (formatMoney(context, goal.remaining))
                                          .toString()),
                                  if (goal.deadline != null)
                                    appL10n(context).msgDue320(
                                        (formatDate(goal.deadline!))
                                            .toString()),
                                ].join(' • '),
                          style: TextStyle(
                            fontSize: 11,
                            color: goal.isCompleted
                                ? appPalette(context).primary
                                : appPalette(context).onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text('${(goal.progress * 100).round()}%',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8,
                  backgroundColor: appPalette(context).surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${formatMoney(context, goal.savedAmount)} / ${formatMoney(context, goal.targetAmount)}',
                style: TextStyle(
                    fontSize: 12, color: appPalette(context).onSurfaceVariant),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () => _adjust(context, ref, deposit: true),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: Text(appL10n(context).msgAddSavings321),
                  ),
                  TextButton.icon(
                    onPressed: goal.savedAmount == 0
                        ? null
                        : () => _adjust(context, ref, deposit: false),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: Text(appL10n(context).msgWithdrawSavings322),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showGoalForm(BuildContext context, {GoalModel? initial}) {
  return showFormSheet<void>(context, _GoalForm(initial: initial));
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({this.initial});

  final GoalModel? initial;

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _target = TextEditingController(
      text: widget.initial == null ? '' : '${widget.initial!.targetAmount}');
  late String _icon = widget.initial?.icon ?? 'savings';
  late String _color = widget.initial?.color ?? kPaletteColors[8];
  late DateTime? _deadline = widget.initial?.deadline;
  bool _busy = false;

  Future<void> _save() async {
    final target = MoneyField.valueOf(_target);
    if (_name.text.trim().isEmpty)
      return showToast(context, appL10n(context).msgEnterAGoalName323);
    if (target <= 0)
      return showToast(
          context, appL10n(context).msgEnterATargetAmountGreaterThan324);
    setState(() => _busy = true);
    try {
      await ref.read(planningRepositoryProvider).saveGoal(GoalModel(
            id: widget.initial?.id,
            name: _name.text,
            icon: _icon,
            color: _color,
            targetAmount: target,
            deadline: _deadline,
          ));
      ref.invalidate(goalsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e, context: context));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context,
        title: appL10n(context).msgDeleteGoal325,
        message: appL10n(context)
            .msgDeleteTheGoal326((widget.initial!.name).toString()))) return;
    try {
      await ref
          .read(planningRepositoryProvider)
          .deleteGoal(widget.initial!.id!);
      ref.invalidate(goalsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e, context: context));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: widget.initial == null
          ? appL10n(context).msgNewGoal327
          : appL10n(context).msgEditGoal328,
      submitLabel: appL10n(context).msgSave43,
      busy: _busy,
      onSubmit: _save,
      trailing: widget.initial == null
          ? null
          : IconButton(
              icon:
                  Icon(Icons.delete_outline, color: appPalette(context).error),
              onPressed: _delete),
      children: [
        TextField(
            controller: _name,
            decoration: sheetInputDecoration(
                appL10n(context).msgGoalNameEGNewLaptop329)),
        const SizedBox(height: 12),
        MoneyField(
            controller: _target, label: appL10n(context).msgTargetAmountVnd330),
        DatePickerTile(
          label: appL10n(context).msgTargetDate331,
          value: _deadline,
          firstDate: DateTime.now(),
          onChanged: (d) => setState(() => _deadline = d),
        ),
        Text(appL10n(context).msgIcon332,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        IconPickerGrid(
            selected: _icon,
            color: colorFromHex(_color)!,
            onChanged: (v) => setState(() => _icon = v)),
        const SizedBox(height: 12),
        Text(appL10n(context).msgColor333,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ColorPickerRow(
            selected: _color, onChanged: (v) => setState(() => _color = v)),
      ],
    );
  }
}
