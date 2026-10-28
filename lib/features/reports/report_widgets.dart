import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../../core/constants/app_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/spending_donut.dart';
import 'monthly_report.dart';

String reportMoney(num value, {bool signed = false}) =>
    CurrencyFormatter.formatVND(value, showSign: signed || value < 0);
String percent(num value) => '${NumberFormat('0.0', 'vi').format(value)}%';

class ReportSectionTitle extends StatelessWidget {
  const ReportSectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            if (action != null) action!
          ]));
}

class AdaptiveReportGrid extends StatelessWidget {
  const AdaptiveReportGrid(
      {super.key, required this.children, this.columns = 3});
  final List<Widget> children;
  final int columns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        var minimum = 140.0;
        if (children.every((w) => w is ReportMetric)) {
          minimum = 0;
          for (final metric in children.cast<ReportMetric>()) {
            final painter = TextPainter(
                textDirection: TextDirection.ltr,
                textScaler: MediaQuery.textScalerOf(context),
                text: TextSpan(
                    text: reportMoney(metric.value, signed: metric.signed),
                    style: DefaultTextStyle.of(context)
                        .style
                        .copyWith(fontSize: 11, fontWeight: FontWeight.w800)))
              ..layout();
            if (painter.width + 18 > minimum) minimum = painter.width + 18;
          }
        } else {
          minimum *= scale;
        }
        final count =
            ((c.maxWidth + 10) / (minimum + 10)).floor().clamp(1, columns);
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final child in children)
            SizedBox(
                width: (c.maxWidth - (count - 1) * 10) / count, child: child)
        ]);
      });
}

class ReportMetric extends StatelessWidget {
  const ReportMetric(this.label, this.value, this.icon, this.color,
      {super.key, this.signed = false});
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool signed;
  @override
  Widget build(BuildContext context) => GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TintedIcon(icon, color: color, size: 32),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 5),
        Text(reportMoney(value, signed: signed),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: signed ? color : AppColors.onSurface))
      ]));
}

class ReportComparison extends StatelessWidget {
  const ReportComparison(
      {super.key,
      required this.income,
      required this.current,
      required this.previous});
  final bool income;
  final int current, previous;
  @override
  Widget build(BuildContext context) {
    final delta = current - previous;
    final good = income ? delta >= 0 : delta <= 0;
    final color = good ? AppColors.primary : AppColors.error;
    return GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(income ? 'Thu nhập tháng trước' : 'Chi tiêu tháng trước',
              style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 6),
          Text(reportMoney(previous),
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 12),
          if (previous == 0)
            const Text('Chưa có dữ liệu so sánh',
                style:
                    TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant))
          else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                  delta >= 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: color,
                  size: 16),
              const SizedBox(width: 6),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(reportMoney(delta, signed: true),
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    Text(
                        '${delta > 0 ? '+' : ''}${percent(delta / previous * 100)}',
                        style: TextStyle(color: color, fontSize: 11)),
                  ])),
            ]),
        ]));
  }
}

List<ReportRow> reportSlices(MonthlyReport report, {bool all = false}) {
  final sorted = report.categoryDetails.toList()
    ..sort((a, b) {
      final order = (b['amount'] as int).compareTo(a['amount'] as int);
      return order == 0 ? '${a['id']}'.compareTo('${b['id']}') : order;
    });
  const fallback = ['#00A878', '#7257D9', '#FFBD44', '#FF852C', '#3999E8'];
  final result = <ReportRow>[];
  for (var i = 0; i < sorted.length; i++) {
    result.add({
      ...sorted[i],
      'color': sorted[i]['color'] ?? fallback[i % fallback.length]
    });
  }
  if (all || result.length <= 5) return result;
  return [
    ...result.take(5),
    {
      'id': 'other',
      'name': 'Khác',
      'color': '#A9B4C4',
      'amount': result.skip(5).fold<int>(0, (n, r) => n + (r['amount'] as int))
    }
  ];
}

class ReportCategories extends StatelessWidget {
  const ReportCategories({super.key, required this.report, this.all = false});
  final MonthlyReport report;
  final bool all;
  @override
  Widget build(BuildContext context) {
    final rows = reportSlices(report, all: all);
    final colors = [
      for (final r in rows)
        colorFromHex(r['color'] as String?) ?? AppColors.primary
    ];
    return GlassCard(
        padding: const EdgeInsets.all(14),
        radius: 20,
        child: LayoutBuilder(builder: (context, c) {
          if (rows.isEmpty)
            return const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: Text('Chưa có chi tiêu trong tháng.')));
          final compact = c.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(14) <= 16;
          final chart = SizedBox(
              width: compact ? 150 : 190,
              child: SpendingDonut(
                  amounts: [for (final r in rows) r['amount'] as int],
                  colors: colors,
                  center: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(reportMoney(report.expense),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                    const Text('Tổng chi',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.onSurfaceVariant))
                  ])));
          final legend = Column(children: [
            for (var i = 0; i < rows.length; i++)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4, right: 7),
                            decoration: BoxDecoration(
                                color: colors[i], shape: BoxShape.circle)),
                        Expanded(
                            child: Text('${rows[i]['name']}',
                                style: const TextStyle(fontSize: 11))),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                              Text(reportMoney(rows[i]['amount'] as num),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  percent((rows[i]['amount'] as num) /
                                      report.expense *
                                      100),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.onSurfaceVariant))
                            ])),
                      ]))
          ]);
          return compact
              ? Row(children: [
                  chart,
                  const SizedBox(width: 12),
                  Expanded(child: legend)
                ])
              : Column(children: [chart, const SizedBox(height: 16), legend]);
        }));
  }
}

String budgetState(int spent, int limit) => spent > limit
    ? 'Vượt ${reportMoney(spent - limit)}'
    : spent == limit
        ? 'Đã chạm hạn mức'
        : spent >= limit * .8
            ? 'Gần chạm hạn mức'
            : 'Trong hạn mức';

class ReportBudget extends StatelessWidget {
  const ReportBudget({super.key, required this.budget});
  final ReportRow budget;
  @override
  Widget build(BuildContext context) {
    final spent = (budget['spent'] as num).toInt(),
        limit = (budget['limit_amount'] as num).toInt();
    final ratio = limit <= 0 ? 0.0 : spent / limit;
    final color = ratio >= 1
        ? AppColors.error
        : ratio >= .8
            ? Colors.orange.shade700
            : AppColors.primary;
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
            radius: 18,
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TintedIcon(
                  budget['category_id'] == null
                      ? Icons.account_balance_wallet_outlined
                      : CategoryIcons.resolve(budget['icon'] as String?),
                  color: colorFromHex(budget['color'] as String?) ?? color,
                  size: 36),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        budget['category_id'] == null
                            ? 'Ngân sách tổng'
                            : '${budget['name']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 5),
                    Text('${reportMoney(spent)} / ${reportMoney(limit)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            color: color,
                            minHeight: 6,
                            backgroundColor: color.withValues(alpha: .10))),
                    const SizedBox(height: 7),
                    Text(
                        '${percent(ratio * 100)} · ${budgetState(spent, limit)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600)),
                  ])),
            ])));
  }
}
