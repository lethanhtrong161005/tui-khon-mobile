import 'package:intl/intl.dart';
import '../../../core/utils/localized_format.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/glass.dart';
import '../../home/models/monthly_summary.dart';
import '../../home/models/transaction_model.dart';
import '../../home/providers/home_providers.dart';
import '../../reports/monthly_report_screen.dart';

class SpendingCategory {
  SpendingCategory(this.id, this.name, this.amount);
  final String? id;
  final String name;
  int amount;
}

class StatisticsData {
  const StatisticsData(this.summary, this.categories);
  final MonthlySummary summary;
  final List<SpendingCategory> categories;
}

/// Uses the same offline repository as the dashboard, including unsynced rows.
/// Pagination prevents a month with more than one history page losing totals.
final statisticsProvider = FutureProvider.autoDispose
    .family<StatisticsData, DateTime>((ref, month) async {
  ref.watch(localRevisionProvider);
  final repository = ref.watch(walletRepositoryProvider);
  final summary = await repository.fetchMonthlySummary(month: month);
  final grouped = <String?, SpendingCategory>{};
  var offset = 0;
  while (true) {
    final page = await repository.fetchTransactions(
        TransactionFilter(month: month, type: TransactionType.expense),
        offset: offset,
        limit: 500);
    for (final tx in page) {
      final category = grouped.putIfAbsent(tx.categoryId,
          () => SpendingCategory(tx.categoryId, tx.categoryName ?? '', 0));
      category.amount += tx.amount;
    }
    if (page.length < 500) break;
    offset += page.length;
  }
  return StatisticsData(summary,
      grouped.values.toList()..sort((a, b) => b.amount.compareTo(a.amount)));
});

final _chartColors = [
  AppColors.primary,
  const Color(0xFF4998F3),
  const Color(0xFFFFBA46),
  const Color(0xFFFF8A4C),
  const Color(0xFF8B80D9),
  const Color(0xFF9CB0A6)
];

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});
  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  late DateTime _month = () {
    final n = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(n.year, n.month);
  }();
  int _tab = 0;

  void _move(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));
  Future<void> _pickMonth() async {
    final date = await showDatePicker(
        context: context,
        initialDate: _month,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: appL10n(context).msgSelectStatisticsMonth442);
    if (date != null && mounted) {
      setState(() => _month = DateTime(date.year, date.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(statisticsProvider(_month));
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(appL10n(context).statistics),
            actions: [
              IconButton(
                  tooltip: appL10n(context).monthlyReport,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              MonthlyReportScreen(initialMonth: _month))),
                  icon: const Icon(Icons.summarize_outlined)),
            ]),
        body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(statisticsProvider(_month));
              await ref.read(statisticsProvider(_month).future);
            },
            child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                            tooltip: appL10n(context).msgPreviousMonth444,
                            onPressed: () => _move(-1),
                            icon: const Icon(Icons.chevron_left_rounded)),
                        Expanded(
                            child: GlassCard(
                                radius: 24,
                                child: InkWell(
                                    onTap: _pickMonth,
                                    borderRadius: BorderRadius.circular(24),
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 9),
                                        child: Row(children: [
                                          Expanded(
                                              child: Text(
                                                  appL10n(context).msgMonth219(
                                                      (_month.month
                                                              .toString()
                                                              .padLeft(2, '0'))
                                                          .toString(),
                                                      (_month.year).toString()),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          const SizedBox(width: 6),
                                          const Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              size: 16),
                                        ]))))),
                        IconButton(
                            tooltip: appL10n(context).msgNextMonth445,
                            onPressed: () => _move(1),
                            icon: const Icon(Icons.chevron_right_rounded)),
                      ]),
                  const SizedBox(height: 12),
                  GlassCard(
                      radius: 24,
                      padding: const EdgeInsets.all(4),
                      child: Row(children: [
                        for (final (i, label) in [
                          appL10n(context).msgOverview446,
                          appL10n(context).categories,
                          appL10n(context).msgTrends447
                        ].indexed)
                          Expanded(
                              child: InkWell(
                                  onTap: () => setState(() => _tab = i),
                                  borderRadius: BorderRadius.circular(22),
                                  child: AnimatedContainer(
                                      duration: MediaQuery.of(context)
                                              .disableAnimations
                                          ? Duration.zero
                                          : const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      decoration: BoxDecoration(
                                          color: _tab == i
                                              ? appPalette(context).primary
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(22)),
                                      child: Text(label,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: _tab == i
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: _tab == i
                                                  ? appPalette(context)
                                                      .onPrimary
                                                  : appPalette(context)
                                                      .onSurface))))),
                      ])),
                  const SizedBox(height: 16),
                  data.when(
                      loading: () => const Padding(
                          padding: const EdgeInsets.all(48),
                          child: const Center(
                              child: const CircularProgressIndicator())),
                      error: (e, _) => GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(children: [
                            Text(friendlyError(e, context: context),
                                textAlign: TextAlign.center),
                            TextButton(
                                onPressed: () =>
                                    ref.invalidate(statisticsProvider(_month)),
                                child: Text(appL10n(context).msgRetry50))
                          ])),
                      data: (d) => Column(children: [
                            if (_tab != 2) _categoryCard(d),
                            if (_tab != 1) ...[
                              const SizedBox(height: 14),
                              _dailyCard(d.summary)
                            ],
                            if (_tab == 0) ...[
                              const SizedBox(height: 14),
                              _totals(d.summary)
                            ],
                            const SizedBox(height: 16),
                            Text(
                                appL10n(context)
                                    .msgCalculatedFromRecordsOnThisDevice448,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: appPalette(context).onSurfaceVariant,
                                    height: 1.5)),
                          ])),
                ])));
  }

  Widget _categoryCard(StatisticsData data) {
    final summary = data.summary;
    final change = summary.expenseChangePercent;
    final categories = data.categories;
    return GlassCard(
        radius: 24,
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            TintedIcon(Icons.south_rounded,
                color: appPalette(context).error, size: 43),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(appL10n(context).msgTotalSpending449,
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(formatMoney(context, summary.expense),
                      style: const TextStyle(
                          fontSize: 23, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      change == null
                          ? appL10n(context)
                              .msgNoSpendingLastMonthForComparison450
                          : appL10n(context).msgComparedWithLastMonth451(
                              (change > 0 ? '↑' : '↓').toString(),
                              (change.abs()).toString()),
                      style: TextStyle(
                          fontSize: 10,
                          color: change != null && change > 0
                              ? appPalette(context).error
                              : appPalette(context).primary)),
                ])),
          ]),
          const SizedBox(height: 22),
          if (categories.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                    child: Text(appL10n(context).msgNoExpensesThisMonthYet452,
                        style: TextStyle(
                            fontSize: 12,
                            color: appPalette(context).onSurfaceVariant))))
          else
            LayoutBuilder(builder: (context, bounds) {
              final chart = Semantics(
                  label: appL10n(context).msgSpendingByCategoryTotal453(
                      (formatMoney(context, summary.expense)).toString()),
                  child: SizedBox(
                      width: 148,
                      height: 148,
                      child: CustomPaint(
                          painter: _DonutPainter(categories),
                          child: Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                Text(appL10n(context).msgTotalSpending454,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: appPalette(context)
                                            .onSurfaceVariant)),
                                const SizedBox(height: 3),
                                Text(
                                    _compact(summary.expense, context: context),
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800)),
                                Text(appL10n(context).msgVnd455,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: appPalette(context)
                                            .onSurfaceVariant)),
                              ])))));
              final legend = Column(children: [
                for (final (i, c) in categories.indexed)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                                color: _chartColors[i % _chartColors.length],
                                shape: BoxShape.circle)),
                        const SizedBox(width: 7),
                        Expanded(
                            child: Text(
                                c.id == null
                                    ? appL10n(context).msgUncategorized441
                                    : c.name,
                                style: const TextStyle(fontSize: 10))),
                        const SizedBox(width: 8),
                        Text(formatMoney(context, c.amount),
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600)),
                      ])),
              ]);
              if (bounds.maxWidth < 310 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.2) {
                return Column(
                    children: [chart, const SizedBox(height: 18), legend]);
              }
              return Row(children: [
                chart,
                const SizedBox(width: 14),
                Expanded(child: legend)
              ]);
            }),
        ]));
  }

  Widget _dailyCard(MonthlySummary summary) {
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    final days = List.generate(count,
        (i) => summary.expenseOn(DateTime(_month.year, _month.month, i + 1)));
    final highest = days.fold<int>(0, math.max);
    return GlassCard(
        radius: 24,
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(appL10n(context).msgSpendingOverTime456,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              highest == 0
                  ? appL10n(context).msgNoExpenseRecordsYet457
                  : appL10n(context).msgHighestDay458(
                      (formatMoney(context, highest)).toString()),
              style: TextStyle(
                  fontSize: 10, color: appPalette(context).onSurfaceVariant)),
          const SizedBox(height: 20),
          SizedBox(
              height: 126,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                      child: Tooltip(
                          message:
                              '${i + 1}/${_month.month}: ${formatMoney(context, days[i])}',
                          child: Semantics(
                              label: appL10n(context).msgDate306(
                                  (i + 1).toString(),
                                  (formatMoney(context, days[i])).toString()),
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 1.8),
                                  child: Container(
                                      height: highest == 0 || days[i] == 0
                                          ? 2
                                          : (126 * days[i] / highest)
                                              .clamp(2, 126)
                                              .toDouble(),
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          gradient: const LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: const [
                                                Color(0xFF89DCC0),
                                                Color(0xFF36B68A)
                                              ]))))))),
              ])),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (final day in [1, 8, 15, 22, count])
              Text('$day/${_month.month}',
                  style: TextStyle(
                      fontSize: 9,
                      color: appPalette(context).onSurfaceVariant)),
          ]),
        ]));
  }

  Widget _totals(MonthlySummary s) => GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _total(appL10n(context).msgIncome163, s.income,
            appPalette(context).primary),
        const Divider(height: 22),
        _total(
            appL10n(context).msgNetIncomeExpenses504,
            s.income - s.expense,
            s.income >= s.expense
                ? appPalette(context).primary
                : appPalette(context).error),
        if (s.totalBudget != null) ...[
          const Divider(height: 22),
          _total(appL10n(context).msgMonthlyBudgets459,
              s.totalBudget!.limitAmount, appPalette(context).onSurface)
        ],
      ]));
  Widget _total(String title, int amount, Color color) => Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
        Text(formatMoney(context, amount, showSign: amount < 0),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color))
      ]);
}

String _compact(int amount, {BuildContext? context}) => amount >= 1000000
    ? appL10n(context).compactMillion(
        NumberFormat('0.00', appL10n(context).localeName)
            .format(amount / 1000000))
    : amount >= 1000
        ? appL10n(context)
            .msgThousand460(((amount / 1000).toStringAsFixed(0)).toString())
        : '$amount';

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.categories);
  final List<SpendingCategory> categories;
  @override
  void paint(Canvas canvas, Size size) {
    final total = categories.fold<int>(0, (s, c) => s + c.amount);
    if (total <= 0) return;
    final rect = Rect.fromCircle(
        center: size.center(Offset.zero), radius: size.shortestSide / 2 - 16);
    var angle = -math.pi / 2;
    for (var i = 0; i < categories.length; i++) {
      final sweep = categories[i].amount / total * math.pi * 2;
      canvas.drawArc(
          rect,
          angle + .015,
          math.max(0, sweep - .03),
          false,
          Paint()
            ..color = _chartColors[i % _chartColors.length]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 29);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.categories != categories;
}
