import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass.dart';

enum NotebookAction {
  expense,
  income,
  ai,
  voice,
  receipt,
  advisor,
  history,
  csv,
  payables,
  report,
  reminders
}

class NotebookNavigation extends StatelessWidget {
  const NotebookNavigation(
      {super.key,
      required this.index,
      required this.onSelect,
      required this.onAdd,
      this.menuOpen = false});
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final bool menuOpen;

  @override
  Widget build(BuildContext context) => GlassCard(
      blur: true,
      radius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(children: [
        _item(context, 0, Icons.home_outlined, Icons.home_rounded, 'Trang chủ'),
        _item(context, 1, Icons.bar_chart_outlined, Icons.bar_chart_rounded,
            'Thống kê'),
        SizedBox(
            width: 62,
            height: 62,
            child: Center(
                child: DecoratedBox(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1AC991),
                        AppColors.primary,
                        Color(0xFF005A43)
                      ]),
                  border: Border.all(color: Colors.white.withValues(alpha: .7)),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: .25),
                        blurRadius: 14,
                        offset: const Offset(0, 5))
                  ]),
              child: FloatingActionButton(
                  heroTag: 'notebook-add',
                  tooltip: 'Mở menu thêm',
                  elevation: 0,
                  highlightElevation: 0,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  onPressed: onAdd,
                  child: AnimatedRotation(
                      turns: menuOpen ? .125 : 0,
                      duration: MediaQuery.of(context).disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      child: const Icon(Icons.add_rounded, size: 31))),
            ))),
        _item(context, 2, Icons.edit_calendar_outlined,
            Icons.edit_calendar_rounded, 'Kế hoạch'),
        _item(context, 3, Icons.person_outline_rounded, Icons.person_rounded,
            'Cá nhân'),
      ]));

  Widget _item(BuildContext context, int value, IconData icon,
          IconData selected, String label) =>
      Expanded(
          child: Semantics(
              selected: index == value,
              button: true,
              child: InkWell(
                  onTap: () => onSelect(value),
                  borderRadius: BorderRadius.circular(22),
                  child: AnimatedContainer(
                      duration: MediaQuery.of(context).disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                          color: index == value
                              ? AppColors.primary.withValues(alpha: .06)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(22)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(index == value ? selected : icon,
                            size: 23,
                            color: index == value
                                ? AppColors.primary
                                : AppColors.outline),
                        const SizedBox(height: 4),
                        Text(label,
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: index == value
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: index == value
                                    ? AppColors.primary
                                    : AppColors.outline)),
                      ])))));
}

Future<NotebookAction?> showNotebookActions(BuildContext context) =>
    showModalBottomSheet<NotebookAction>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _NotebookActionSheet());

class _NotebookActionSheet extends StatelessWidget {
  const _NotebookActionSheet();
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GlassCard(
          blur: true,
          radius: 32,
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .82),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                                color: AppColors.outlineVariant,
                                borderRadius: BorderRadius.circular(4)))),
                    Row(children: [
                      const Expanded(
                          child: Text('Bạn muốn ghi gì?',
                              style: TextStyle(
                                  fontSize: 23, fontWeight: FontWeight.w800))),
                      IconButton(
                          tooltip: 'Đóng menu',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded))
                    ]),
                    const Text('Ghi lại hôm nay, chủ động ngày mai.',
                        style: TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 18),
                    Flexible(child: SingleChildScrollView(
                        child: LayoutBuilder(builder: (context, bounds) {
                      final columns = bounds.maxWidth < 320 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.3
                          ? 2
                          : 3;
                      return Wrap(spacing: 10, runSpacing: 10, children: [
                        for (final action in _actions)
                          SizedBox(
                              width: (bounds.maxWidth - (columns - 1) * 10) /
                                  columns,
                              child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () =>
                                      Navigator.pop(context, action.$1),
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 14),
                                      decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: .62),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border:
                                              Border.all(color: Colors.white)),
                                      child: Column(children: [
                                        TintedIcon(action.$3, color: action.$4),
                                        const SizedBox(height: 9),
                                        Text(action.$2,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600))
                                      ])))),
                      ]);
                    }))),
                  ]))));
}

const _actions = [
  (
    NotebookAction.expense,
    'Thêm chi tiêu',
    Icons.remove_rounded,
    AppColors.primary
  ),
  (
    NotebookAction.income,
    'Thêm thu nhập',
    Icons.arrow_upward_rounded,
    AppColors.primary
  ),
  (
    NotebookAction.ai,
    'Ghi nhanh AI',
    Icons.auto_awesome_rounded,
    AppColors.secondary
  ),
  (
    NotebookAction.voice,
    'Ghi bằng giọng nói',
    Icons.mic_none_rounded,
    AppColors.secondary
  ),
  (
    NotebookAction.receipt,
    'Quét hóa đơn',
    Icons.document_scanner_outlined,
    Color(0xFF238BCC)
  ),
  (
    NotebookAction.advisor,
    'Cố vấn AI',
    Icons.insights_rounded,
    AppColors.secondary
  ),
  (
    NotebookAction.history,
    'Giao dịch',
    Icons.receipt_long_outlined,
    Color(0xFFCE8418)
  ),
  (
    NotebookAction.csv,
    'Nhập / xuất CSV',
    Icons.import_export_rounded,
    Color(0xFF238BCC)
  ),
  (
    NotebookAction.payables,
    'Khoản phải trả',
    Icons.event_note_outlined,
    Color(0xFFCE8418)
  ),
  (
    NotebookAction.report,
    'Báo cáo tháng',
    Icons.summarize_outlined,
    AppColors.primary
  ),
  (
    NotebookAction.reminders,
    'Nhắc ghi chép',
    Icons.notifications_none_rounded,
    Color(0xFFCE8418)
  ),
];
