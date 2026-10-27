import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/currency_formatter.dart';
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
  static const _ranges = [30, 90];
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withOpacity(0.9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Báo cáo & Cố vấn AI',
          style: TextStyle(color: AppColors.onSurface, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Phân tích lại',
            icon: const Icon(Icons.refresh, color: AppColors.onSurface),
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
            if (reportAsync.valueOrNull?.cached == true) const Text('Đang xem nhận xét đã lưu trên máy'),
            if (ref.watch(advisorStaleProvider(_range)).valueOrNull == true || reportAsync.valueOrNull?.stale == true)
              const Text('Dữ liệu đã thay đổi. Đồng bộ rồi phân tích lại để cập nhật nhận xét.'),
            const SizedBox(height: 16),

            // Category Breakdown (Donut Chart representation)
            _buildCategoryBreakdownCard(periodAsync, reportAsync.valueOrNull),
            const SizedBox(height: 16),

            // Cashflow & AI Forecast Bar Chart
            _buildForecastChartCard(periodAsync.valueOrNull, reportAsync.valueOrNull),
            const SizedBox(height: 16),

            // Chat with AI CTA
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickRecordScreen()));
                },
                icon: const Icon(Icons.forum, size: 20),
                label: const Text('Trò chuyện chi tiết với Cố vấn AI',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        color: AppColors.surfaceContainerHigh,
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
                  color: isSelected ? AppColors.surfaceContainerLowest : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)] : null,
                ),
                child: Text(
                  '$range ngày qua',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
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
          friendlyError(reportAsync.error!),
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.3),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _reanalyze,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Thử lại'),
        ),
      ]);
    } else if (report == null) {
      children.add(const Row(
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Expanded(
            child:
                Text('Gemini đang phân tích chi tiêu của bạn...', style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ],
      ));
    } else {
      final change = report.expenseChange;
      children.addAll([
        const Text('XU HƯỚNG TỔNG THỂ', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(
          report.summary,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, height: 1.3),
        ),
        if (change != null) ...[
          const SizedBox(height: 6),
          Text(
            'Chi tiêu ${change >= 0 ? 'tăng' : 'giảm'} ${change.abs()}% so với $_range ngày trước đó',
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
            'Đã dùng ${report.quotaUsed}/${report.quotaLimit} lượt phân tích hôm nay',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ]);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, AppColors.secondaryContainer, AppColors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.secondary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.smart_toy, size: 14, color: AppColors.tertiaryFixed),
                    SizedBox(width: 4),
                    Text('Phân tích chuyên sâu bởi Gemini AI',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
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
        ? ('💡', 'Gợi ý', AppColors.tertiaryFixed)
        : change > 0
            ? ('⚠️', 'Cảnh báo', AppColors.error)
            : ('✅', 'Tích cực', AppColors.primaryFixed);
    final title =
        change == null ? '$icon ${insight.category}' : '$icon ${insight.category} (${change > 0 ? '+' : ''}$change%)';
    return _adviceTile(title, badge, '${CurrencyFormatter.formatVND(insight.total)} • ${insight.advice}', badgeColor);
  }

  Widget _forecastAdvice(AdvisorReport report) {
    final risks = report.riskCategories.isEmpty ? '' : ', danh mục dễ vượt chi: ${report.riskCategories.join(', ')}';
    return _adviceTile(
      '🔮 Dự báo 30 ngày tới',
      'Ước tính AI',
      'Dự kiến chi khoảng ${CurrencyFormatter.formatVND(report.forecastNextMonth)}$risks.',
      AppColors.tertiaryFixed,
    );
  }

  Widget _adviceTile(String title, String badge, String body, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child:
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
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
                    color: badgeColor == AppColors.error ? Colors.white : AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  static String _millions(int amount) => '${(amount / 1000000).toStringAsFixed(2).replaceAll('.', ',')}M';

  Widget _buildCategoryBreakdownCard(AsyncValue<PeriodSummary> periodAsync, AdvisorReport? report) {
    final period = periodAsync.valueOrNull;
    final categories = period?.expenseCategories ?? const <CategoryTotal>[];
    final total = period?.expense ?? 0;
    final top = categories.isEmpty ? null : categories.first;
    final changeByName = {for (final i in report?.insights ?? const <AdvisorInsight>[]) i.category: i.change};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cơ cấu chi tiêu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                'Tổng chi $_range ngày: ${period == null ? '...' : CurrencyFormatter.formatVND(total)}',
                style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (period == null)
            Center(
              child: periodAsync.hasError
                  ? Text(friendlyError(periodAsync.error!), style: const TextStyle(color: AppColors.onSurfaceVariant))
                  : const CircularProgressIndicator(color: AppColors.primary),
            )
          else if (categories.isEmpty)
            const Center(
              child: Text('Chưa có khoản chi nào trong giai đoạn này',
                  style: TextStyle(color: AppColors.onSurfaceVariant)),
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
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(colorFromHex(top!.color) ?? AppColors.tertiary),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_range NGÀY',
                          style: const TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold)),
                      Text(_millions(total),
                          style:
                              const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                      Text('${categories.length} danh mục',
                          style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Detail rows
            for (final cat in categories.take(6)) _categoryRow(cat, total, changeByName[cat.name]),
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(CategoryTotal cat, int total, int? change) {
    final color = colorFromHex(cat.color) ?? AppColors.outline;
    final share = total == 0 ? 0 : (cat.total * 100 / total).round();
    final (badge, badgeColor) = change == null
        ? ('${cat.count} giao dịch', AppColors.outline)
        : change > 0
            ? ('+$change% kỳ trước', AppColors.error)
            : ('$change% kỳ trước', AppColors.primary);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
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
            child: Icon(CategoryIcons.resolve(cat.icon), color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text('$share% tổng chi', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyFormatter.formatVND(cat.total),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text(badge, style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold)),
            ],
          ),
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
        period?.expenseBetween(today.subtract(Duration(days: w * 7 + 6)), today.subtract(Duration(days: w * 7))) ?? 0,
    ];
    final weeklyForecast = report == null ? 0 : (report.forecastNextMonth * 7 / 30).round();
    final maxValue = [...actual, weeklyForecast].fold<int>(1, (m, v) => v > m ? v : m);
    // Tallest bar 90px: leaves room for the week label inside the 120px chart.
    double h(int v) => 90 * v / maxValue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dòng tiền & Dự báo AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('Chi tiêu 4 tuần qua đối chiếu dự báo',
                      style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
              Row(
                children: [
                  _legendDot(AppColors.primary, 'Thực tế'),
                  const SizedBox(width: 8),
                  _legendDot(AppColors.secondaryContainer, 'Dự báo'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4-Week Comparison Bars
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 4; i++)
                  _barPair(i == 3 ? 'Tuần này' : 'Tuần ${i + 1}', h(actual[i]), h(weeklyForecast), isCurrent: i == 3),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.trending_up, color: AppColors.secondary, size: 16),
                    SizedBox(width: 6),
                    Text('Dự báo 30 ngày tới:', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  ],
                ),
                Text(
                  report == null ? '...' : '~ ${CurrencyFormatter.formatVND(report.forecastNextMonth)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
      ],
    );
  }

  Widget _barPair(String label, double actualH, double forecastH, {bool isCurrent = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 14,
              height: actualH,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 14,
              height: forecastH,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withOpacity(0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isCurrent ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
