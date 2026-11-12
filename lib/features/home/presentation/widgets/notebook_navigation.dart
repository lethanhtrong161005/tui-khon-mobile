import '../../../../core/theme/semantic_colors.dart';
import '../../../../l10n/app_l10n.dart';

import 'package:flutter/material.dart';

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
  reminders,
}

class NotebookNavigation extends StatelessWidget {
  const NotebookNavigation({
    super.key,
    required this.index,
    required this.onSelect,
    required this.onAdd,
    this.menuOpen = false,
  });
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final bool menuOpen;

  @override
  Widget build(BuildContext context) => GlassCard(
    blur: true,
    radius: 30,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: Row(
      children: [
        _item(
          context,
          0,
          Icons.home_outlined,
          Icons.home_rounded,
          appL10n(context).home,
        ),
        _item(
          context,
          1,
          Icons.bar_chart_outlined,
          Icons.bar_chart_rounded,
          appL10n(context).statistics,
        ),
        SizedBox(
          width: 62,
          height: 62,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1AC991),
                    appPalette(context).primary,
                    const Color(0xFF005A43),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .7)),
                boxShadow: [
                  BoxShadow(
                    color: appPalette(context).primary.withValues(alpha: .25),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: FloatingActionButton(
                heroTag: 'notebook-add',
                tooltip: appL10n(context).addMenu,
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
                  child: const Icon(Icons.add_rounded, size: 31),
                ),
              ),
            ),
          ),
        ),
        _item(
          context,
          2,
          Icons.edit_calendar_outlined,
          Icons.edit_calendar_rounded,
          appL10n(context).planning,
        ),
        _item(
          context,
          3,
          Icons.person_outline_rounded,
          Icons.person_rounded,
          appL10n(context).profile,
        ),
      ],
    ),
  );

  Widget _item(
    BuildContext context,
    int value,
    IconData icon,
    IconData selected,
    String label,
  ) => Expanded(
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
                ? appPalette(context).primary.withValues(alpha: .06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                index == value ? selected : icon,
                size: 23,
                color: index == value
                    ? appPalette(context).primary
                    : appPalette(context).outline,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: index == value
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: index == value
                      ? appPalette(context).primary
                      : appPalette(context).outline,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<NotebookAction?> showNotebookActions(BuildContext context) =>
    showModalBottomSheet<NotebookAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotebookActionSheet(),
    );

class _NotebookActionSheet extends StatelessWidget {
  const _NotebookActionSheet();
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GlassCard(
        blur: true,
        radius: 32,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: appPalette(context).outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: appL10n(context).closeMenu,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appL10n(context).msgWhatWouldYouLikeToRecord186,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        appL10n(context).msgRecordTodayPlanForTomorrow188,
                        style: TextStyle(
                          color: appPalette(context).onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, bounds) {
                          final columns =
                              bounds.maxWidth < 320 ||
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.3
                              ? 2
                              : 3;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final action in _actions(context))
                                SizedBox(
                                  width:
                                      (bounds.maxWidth - (columns - 1) * 10) /
                                      columns,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () =>
                                        Navigator.pop(context, action.$1),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: appPalette(context)
                                            .surfaceContainer
                                            .withValues(alpha: .62),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: appPalette(context)
                                              .outlineVariant,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          TintedIcon(
                                            action.$3,
                                            color: action.$4,
                                          ),
                                          const SizedBox(height: 9),
                                          Text(
                                            action.$2,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

List<(NotebookAction, String, IconData, Color)> _actions(
  BuildContext context,
) => [
  (
    NotebookAction.expense,
    appL10n(context).msgAddExpense189,
    Icons.remove_rounded,
    appPalette(context).primary,
  ),
  (
    NotebookAction.income,
    appL10n(context).msgAddIncome190,
    Icons.arrow_upward_rounded,
    appPalette(context).primary,
  ),
  (
    NotebookAction.ai,
    appL10n(context).quickAi,
    Icons.auto_awesome_rounded,
    appPalette(context).secondary,
  ),
  (
    NotebookAction.voice,
    appL10n(context).msgRecordByVoice191,
    Icons.mic_none_rounded,
    appPalette(context).secondary,
  ),
  (
    NotebookAction.receipt,
    appL10n(context).msgScanReceipt192,
    Icons.document_scanner_outlined,
    const Color(0xFF238BCC),
  ),
  (
    NotebookAction.advisor,
    appL10n(context).msgAiAdvisor193,
    Icons.insights_rounded,
    appPalette(context).secondary,
  ),
  (
    NotebookAction.history,
    appL10n(context).msgTransactions5,
    Icons.receipt_long_outlined,
    const Color(0xFFCE8418),
  ),
  (
    NotebookAction.csv,
    appL10n(context).csvExchange,
    Icons.import_export_rounded,
    const Color(0xFF238BCC),
  ),
  (
    NotebookAction.payables,
    appL10n(context).payables,
    Icons.event_note_outlined,
    const Color(0xFFCE8418),
  ),
  (
    NotebookAction.report,
    appL10n(context).monthlyReport,
    Icons.summarize_outlined,
    appPalette(context).primary,
  ),
  (
    NotebookAction.reminders,
    appL10n(context).msgRecordingReminder196,
    Icons.notifications_none_rounded,
    const Color(0xFFCE8418),
  ),
];
