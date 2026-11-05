import '../../../core/utils/localized_format.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/error_messages.dart';
import '../../quick_record/presentation/quick_record_screen.dart';
import '../data/advisor_repository.dart';
import '../models/advisor_models.dart';

/// AdvisorScreen renders financial insights, spending structure (Donut chart),
/// and a 4-week cash flow forecast. Numbers come from `get_period_summary`;
/// the summary, advice and forecast come from the `ai-advisor` Edge Function.
class AdvisorScreen extends ConsumerStatefulWidget {
  const AdvisorScreen({super.key});

  @override
  ConsumerState<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends ConsumerState<AdvisorScreen> {
  static final _ranges = [30, 90];
  int _range = 30;

  void _reanalyze() {
    ref.invalidate(advisorReportProvider(_range));
    ref.invalidate(periodSummaryProvider(_range));
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(advisorReportProvider(_range));
    final periodAsync = ref.watch(periodSummaryProvider(_range));

    return Scaffold(
      backgroundColor: appPalette(context).surface,
      appBar: AppBar(
        backgroundColor: appPalette(context).surface.withOpacity(0.9),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: appPalette(context).onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          appL10n(context).msgReportsAiAdvisor44,
          style: TextStyle(
              color: appPalette(context).onSurface,
              fontSize: 17,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: appL10n(context).msgAnalyzeAgain45,
            icon: Icon(Icons.refresh, color: appPalette(context).onSurface),
            onPressed: reportAsync.isLoading ? null : _reanalyze,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Selector
            _buildPeriodSelector(),
            const SizedBox(height: 16),

            // AI Advisor Hero Banner
            _buildAdvisorHeroBanner(reportAsync),
            if (reportAsync.valueOrNull?.cached == true)
              Text(appL10n(context).msgViewingAdviceSavedOnThisDevice46),
            if (ref.watch(advisorStaleProvider(_range)).valueOrNull == true ||
                reportAsync.valueOrNull?.stale == true)
              Text(appL10n(context).msgYourDataHasChangedSyncAnd47),
            const SizedBox(height: 16),

            // Category Breakdown (Donut Chart representation)
            _buildCategoryBreakdownCard(periodAsync, reportAsync.valueOrNull),
            const SizedBox(height: 16),

            // Cashflow & AI Forecast Bar Chart
            _buildForecastChartCard(
                periodAsync.valueOrNull, reportAsync.valueOrNull),
            const SizedBox(height: 16),

            // Chat with AI CTA
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const QuickRecordScreen()));
                },
                icon: const Icon(Icons.forum, size: 20),
                label: Text(appL10n(context).msgRecordWithTheAiAssistant48,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: appPalette(context).secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: appPalette(context).surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: _ranges.map((range) {
          final isSelected = _range == range;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _range = range),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? appPalette(context).surfaceContainerLowest
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4)
                        ]
                      : null,
                ),
                child: Text(
                  appL10n(context).msgPastDays49((range).toString()),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? appPalette(context).primary
                        : appPalette(context).onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdvisorHeroBanner(AsyncValue<AdvisorReport> reportAsync) {
    final report = reportAsync.valueOrNull;
    final children = <Widget>[];

    if (report == null && reportAsync.hasError) {
      children.addAll([
        Text(
          friendlyError(reportAsync.error!, context: context),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.3),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _reanalyze,
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54)),
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(appL10n(context).msgRetry50),
        ),
      ]);
    } else if (report == null) {
      children.add(Row(
        children: [
          const SizedBox(
              width: 18,
              height: 18,
              child: const CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(appL10n(context).msgGeminiIsAnalyzingYourSpending51,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ],
      ));
    } else {
      final change = report.expenseChange;
      children.addAll([
        Text(appL10n(context).msgOverallTrend52,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(
          report.summary,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.3),
        ),
        if (change != null) ...[
          const SizedBox(height: 6),
          Text(
            appL10n(context).msgSpendingComparedWithThePreviousDays53(
                (change >= 0
                        ? appL10n(context).increase
                        : appL10n(context).decrease)
                    .toString(),
                (change.abs()).toString(),
                (_range).toString()),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
        const SizedBox(height: 14),
        for (final insight in report.insights) ...[
          _adviceCard(insight),
          const SizedBox(height: 8),
        ],
        if (report.forecastNextMonth > 0) _forecastAdvice(report),
        if (report.quotaUsed != null && report.quotaLimit != null) ...[
          const SizedBox(height: 8),
          Text(
            appL10n(context).msgAnalysesUsedToday54(
                (report.quotaUsed).toString(), (report.quotaLimit).toString()),
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ]);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            appPalette(context).secondary,
            AppColors.secondaryContainer,
            AppColors.primaryContainer
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: appPalette(context).secondary.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: appPalette(context).surfaceContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy,
                        size: 14, color: AppColors.tertiaryFixed),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(
                            appL10n(context).msgDetailedAnalysisByGeminiAi55,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold))),
                  ],
                ),
              )),
              const Icon(Icons.auto_awesome, color: Colors.white70, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _adviceCard(AdvisorInsight insight) {
    final change = insight.change;
    final (icon, badge, badgeColor) = change == null
        ? ('💡', appL10n(context).msgSuggestion56, AppColors.tertiaryFixed)
        : change > 0
            ? ('⚠️', appL10n(context).msgWarning57, appPalette(context).error)
            : ('✅', appL10n(context).msgPositive58, AppColors.primaryFixed);
    final title = change == null
        ? '$icon ${insight.category}'
        : '$icon ${insight.category} (${change > 0 ? '+' : ''}$change%)';
    return _adviceTile(
        title,
        badge,
        '${formatMoney(context, insight.total)} • ${insight.advice}',
        badgeColor);
  }

  Widget _forecastAdvice(AdvisorReport report) {
    final risks = report.riskCategories.isEmpty
        ? ''
        : appL10n(context).msgCategoriesAtRiskOfOverspending59(
            (report.riskCategories.join(', ')).toString());
    return _adviceTile(
      appL10n(context).msgForecastForTheNextDays60,
      appL10n(context).msgAiEstimate61,
      appL10n(context).msgEstimatedSpending62(
          (formatMoney(context, report.forecastNextMonth)).toString(),
          (risks).toString()),
      AppColors.tertiaryFixed,
    );
  }

  Widget _adviceTile(
      String title, String badge, String body, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appPalette(context).surfaceContainer.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: badgeColor == appPalette(context).error
                        ? Colors.white
                        : appPalette(context).onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  String _millions(int amount) => appL10n(context).compactMillion(NumberFormat('0.00', appL10n(context).localeName).format(amount / 1000000));

  Widget _buildCategoryBreakdownCard(
      AsyncValue<PeriodSummary> periodAsync, AdvisorReport? report) {
    final period = periodAsync.valueOrNull;
    final categories = period?.expenseCategories ?? <CategoryTotal>[];
    final total = period?.expense ?? 0;
    final top = categories.isEmpty ? null : categories.first;
    final changeByName = {
      for (final i in report?.insights ?? <AdvisorInsight>[])
        i.category: i.change
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appPalette(context).surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(appL10n(context).msgSpendingBreakdown63,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                appL10n(context).msgTotalSpendingOverDays64(
                    (_range).toString(),
                    (period == null ? '...' : formatMoney(context, total))
                        .toString()),
                style: TextStyle(
                    fontSize: 12, color: appPalette(context).onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (period == null)
            Center(
              child: periodAsync.hasError
                  ? Text(friendlyError(periodAsync.error!, context: context),
                      style: TextStyle(
                          color: appPalette(context).onSurfaceVariant))
                  : CircularProgressIndicator(
                      color: appPalette(context).primary),
            )
          else if (categories.isEmpty)
            Center(
              child: Text(appL10n(context).msgNoExpensesInThisPeriodYet65,
                  style:
                      TextStyle(color: appPalette(context).onSurfaceVariant)),
            )
          else ...[
            // Donut: share of the largest category
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: total == 0 ? 0 : top!.total / total,
                      strokeWidth: 16,
                      backgroundColor: appPalette(context).surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          colorFromHex(top!.color) ??
                              appPalette(context).tertiary),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(appL10n(context).msgDays66((_range).toString()),
                          style: TextStyle(
                              fontSize: 10,
                              color: appPalette(context).outline,
                              fontWeight: FontWeight.bold)),
                      Text(_millions(total),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: appPalette(context).onSurface)),
                      Text(appL10n(context).msgCategories67(categories.length),
                          style: TextStyle(
                              fontSize: 10,
                              color: appPalette(context).primary,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Detail rows
            for (final cat in categories.take(6))
              _categoryRow(cat, total, changeByName[cat.name]),
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(CategoryTotal cat, int total, int? change) {
    final color = colorFromHex(cat.color) ?? appPalette(context).outline;
    final share = total == 0 ? 0 : (cat.total * 100 / total).round();
    final (badge, badgeColor) = change == null
        ? (
            appL10n(context).msgTransactions68(cat.count),
            appPalette(context).outline
          )
        : change > 0
            ? (
                appL10n(context)
                    .msgFromThePreviousPeriod69((change).toString()),
                appPalette(context).error
              )
            : (
                appL10n(context)
                    .msgFromThePreviousPeriod70((change).toString()),
                appPalette(context).primary
              );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: appPalette(context).surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(CategoryIcons.resolve(cat.icon), color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                Text(appL10n(context).msgOfSpending71((share).toString()),
                    style: TextStyle(
                        fontSize: 11,
                        color: appPalette(context).onSurfaceVariant)),
              ],
            ),
          ),
          Flexible(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatMoney(context, cat.total),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              Text(badge,
                  style: TextStyle(
                      fontSize: 10,
                      color: badgeColor,
                      fontWeight: FontWeight.bold)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildForecastChartCard(PeriodSummary? period, AdvisorReport? report) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 4 weeks ending today, oldest first
    final actual = [
      for (var w = 3; w >= 0; w--)
        period?.expenseBetween(today.subtract(Duration(days: w * 7 + 6)),
                today.subtract(Duration(days: w * 7))) ??
            0,
    ];
    final weeklyForecast =
        report == null ? 0 : (report.forecastNextMonth * 7 / 30).round();
    final maxValue =
        [...actual, weeklyForecast].fold<int>(1, (m, v) => v > m ? v : m);
    // Tallest bar 90px: leaves room for the week label inside the 120px chart.
    double h(int v) => 90 * v / maxValue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appPalette(context).surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appL10n(context).msgCashFlowAiForecast72,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(appL10n(context).msgSpendingOverTheLastWeeksVersus73,
                      style: TextStyle(
                          fontSize: 11,
                          color: appPalette(context).onSurfaceVariant)),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _legendDot(appPalette(context).primary,
                      appL10n(context).msgActual74),
                  const SizedBox(width: 8),
                  _legendDot(AppColors.secondaryContainer,
                      appL10n(context).msgForecast75),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4-Week Comparison Bars
          SizedBox(
            height: 100 + 32 * MediaQuery.textScalerOf(context).scale(1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                      child: _barPair(
                          i == 3
                              ? appL10n(context).msgThisWeek76
                              : appL10n(context).msgWeek77((i + 1).toString()),
                          h(actual[i]),
                          h(weeklyForecast),
                          isCurrent: i == 3)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: appPalette(context).surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up,
                        color: appPalette(context).secondary, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(appL10n(context).msgNextDaysForecast78,
                            style: TextStyle(
                                fontSize: 12,
                                color: appPalette(context).onSurfaceVariant))),
                  ],
                ),
                Text(
                  report == null
                      ? '...'
                      : '~ ${formatMoney(context, report.forecastNextMonth)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 10, color: appPalette(context).onSurfaceVariant)),
      ],
    );
  }

  Widget _barPair(String label, double actualH, double forecastH,
      {bool isCurrent = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 14,
              height: actualH,
              decoration: BoxDecoration(
                color: appPalette(context).primary,
                borderRadius:
                    const BorderRadius.vertical(top: const Radius.circular(4)),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 14,
              height: forecastH,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withOpacity(0.8),
                borderRadius:
                    const BorderRadius.vertical(top: const Radius.circular(4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isCurrent
                ? appPalette(context).primary
                : appPalette(context).onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
