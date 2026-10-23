import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/currency_formatter.dart';
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
            ? Text(friendlyError(goalsAsync.error!))
            : const CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        if (goals.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.savings, color: AppColors.outline, size: 32),
                SizedBox(height: 8),
                Text('Chưa có mục tiêu nào.\nĐặt mục tiêu (vd: mua laptop 20 triệu) và ghi lại mỗi lần để dành.',
                    style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
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

  Future<void> _adjust(BuildContext context, WidgetRef ref, {required bool deposit}) async {
    final amount = await showAmountDialog(
      context,
      title: deposit ? 'Nạp thêm vào "${goal.name}"' : 'Rút bớt từ "${goal.name}"',
    );
    if (amount == null || amount <= 0) return;

    final next = deposit ? goal.savedAmount + amount : (goal.savedAmount - amount).clamp(0, goal.savedAmount);
    try {
      await ref.read(planningRepositoryProvider).setGoalSaved(goal.id!, next);
      ref.invalidate(goalsProvider);
      ref.invalidate(notificationsProvider);
      if (context.mounted && deposit && next >= goal.targetAmount && !goal.isCompleted) {
        showToast(context, '🎉 Chúc mừng! Bạn đã hoàn thành mục tiêu "${goal.name}"');
      }
    } catch (e) {
      if (context.mounted) showToast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorFromHex(goal.color) ?? AppColors.primary;
    return Card(
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
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
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(CategoryIcons.resolve(goal.icon), color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(goal.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text(
                          goal.isCompleted
                              ? 'Đã hoàn thành 🎉'
                              : [
                                  'Còn ${CurrencyFormatter.formatVND(goal.remaining)}',
                                  if (goal.deadline != null) 'hạn ${formatDate(goal.deadline!)}',
                                ].join(' • '),
                          style: TextStyle(
                            fontSize: 11,
                            color: goal.isCompleted ? AppColors.primary : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text('${(goal.progress * 100).round()}%',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${CurrencyFormatter.formatVND(goal.savedAmount)} / ${CurrencyFormatter.formatVND(goal.targetAmount)}',
                style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _adjust(context, ref, deposit: true),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Nạp thêm'),
                  ),
                  TextButton.icon(
                    onPressed: goal.savedAmount == 0 ? null : () => _adjust(context, ref, deposit: false),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('Rút bớt'),
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
  late final _target = TextEditingController(text: widget.initial == null ? '' : '${widget.initial!.targetAmount}');
  late String _icon = widget.initial?.icon ?? 'savings';
  late String _color = widget.initial?.color ?? kPaletteColors[8];
  late DateTime? _deadline = widget.initial?.deadline;
  bool _busy = false;

  Future<void> _save() async {
    final target = MoneyField.valueOf(_target);
    if (_name.text.trim().isEmpty) return showToast(context, 'Nhập tên mục tiêu');
    if (target <= 0) return showToast(context, 'Nhập số tiền mục tiêu lớn hơn 0');
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
      if (mounted) showToast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, title: 'Xoá mục tiêu?', message: 'Xoá mục tiêu "${widget.initial!.name}"?')) return;
    try {
      await ref.read(planningRepositoryProvider).deleteGoal(widget.initial!.id!);
      ref.invalidate(goalsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
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
      title: widget.initial == null ? 'Mục tiêu mới' : 'Sửa mục tiêu',
      submitLabel: 'Lưu',
      busy: _busy,
      onSubmit: _save,
      trailing: widget.initial == null
          ? null
          : IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: _delete),
      children: [
        TextField(controller: _name, decoration: sheetInputDecoration('Tên mục tiêu (vd: Mua laptop)')),
        const SizedBox(height: 12),
        MoneyField(controller: _target, label: 'Số tiền mục tiêu (VND)'),
        DatePickerTile(
          label: 'Hạn hoàn thành',
          value: _deadline,
          firstDate: DateTime.now(),
          onChanged: (d) => setState(() => _deadline = d),
        ),
        const Text('Biểu tượng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        IconPickerGrid(selected: _icon, color: colorFromHex(_color)!, onChanged: (v) => setState(() => _icon = v)),
        const SizedBox(height: 12),
        const Text('Màu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ColorPickerRow(selected: _color, onChanged: (v) => setState(() => _color = v)),
      ],
    );
  }
}
