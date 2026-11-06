import '../../home/models/monthly_summary.dart';

int _int(Object? v) => (v as num? ?? 0).toInt();
int? _intOrNull(Object? v) => (v as num?)?.toInt();

/// Result of the `ai-advisor` Edge Function. Totals and % changes are computed
/// by the server; Gemini only writes [summary] and the advice texts.
class AdvisorReport {
  final int range;
  final int income;
  final int expense;
  final int previousExpense;
  final int? expenseChange;
  final String summary;
  final List<AdvisorInsight> insights;
  final int forecastNextMonth;
  final int forecastBaseline;
  final List<String> riskCategories;
  final int? quotaUsed;
  final int? quotaLimit;
  final bool cached;
  final bool stale;

  const AdvisorReport({
    required this.range,
    required this.summary,
    this.income = 0,
    this.expense = 0,
    this.previousExpense = 0,
    this.expenseChange,
    this.insights = const [],
    this.forecastNextMonth = 0,
    this.forecastBaseline = 0,
    this.riskCategories = const [],
    this.quotaUsed,
    this.quotaLimit,
    this.cached = false,
    this.stale = false,
  });

  factory AdvisorReport.fromJson(Map<String, dynamic> json) {
    final period = (json['period'] as Map?)?.cast<String, dynamic>() ?? const {};
    final totals = (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final forecast = (json['forecast'] as Map?)?.cast<String, dynamic>() ?? const {};
    final quota = (json['quota'] as Map?)?.cast<String, dynamic>();
    return AdvisorReport(
      range: _int(period['range']),
      income: _int(totals['income']),
      expense: _int(totals['expense']),
      previousExpense: _int(totals['previousExpense']),
      expenseChange: _intOrNull(totals['expenseChange']),
      summary: (json['summary'] as String?) ?? '',
      insights: ((json['insights'] as List?) ?? const [])
          .map((i) => AdvisorInsight.fromJson((i as Map).cast<String, dynamic>()))
          .toList(),
      forecastNextMonth: _int(forecast['nextMonth']),
      forecastBaseline: _int(forecast['baseline']),
      riskCategories: ((forecast['riskCategories'] as List?) ?? const []).cast<String>(),
      quotaUsed: _intOrNull(quota?['used']),
      quotaLimit: _intOrNull(quota?['limit']),
      cached: json['cached'] == true,
      stale: json['stale'] == true,
    );
  }
}

class AdvisorInsight {
  final String category;
  final int total;

  /// % change vs the previous period; null when there is nothing to compare.
  final int? change;
  final String advice;

  const AdvisorInsight({required this.category, required this.advice, this.total = 0, this.change});

  factory AdvisorInsight.fromJson(Map<String, dynamic> json) => AdvisorInsight(
        category: json['category'] as String,
        total: _int(json['total']),
        change: _intOrNull(json['change']),
        advice: (json['advice'] as String?) ?? '',
      );
}

/// One category line of `get_period_summary`.
class CategoryTotal {
  final String? categoryId;
  final String name;
  final bool isIncome;
  final String? icon;
  final String? color;
  final int total;
  final int count;

  const CategoryTotal({
    required this.name,
    required this.total,
    this.categoryId,
    this.isIncome = false,
    this.icon,
    this.color,
    this.count = 0,
  });

  factory CategoryTotal.fromJson(Map<String, dynamic> json) => CategoryTotal(
        categoryId: json['category_id'] as String?,
        name: (json['name'] as String?) ?? 'Chưa phân loại',
        isIncome: json['type'] == 'income',
        icon: json['icon'] as String?,
        color: json['color'] as String?,
        total: _int(json['total']),
        count: _int(json['count']),
      );
}

/// Result of the `get_period_summary(p_from, p_to)` RPC.
class PeriodSummary {
  final int income;
  final int expense;
  final List<CategoryTotal> byCategory;
  final List<DailyTotal> byDay;

  const PeriodSummary({
    this.income = 0,
    this.expense = 0,
    this.byCategory = const [],
    this.byDay = const [],
  });

  factory PeriodSummary.fromJson(Map<String, dynamic> json) => PeriodSummary(
        income: _int(json['income']),
        expense: _int(json['expense']),
        byCategory: ((json['by_category'] as List?) ?? const [])
            .map((c) => CategoryTotal.fromJson((c as Map).cast<String, dynamic>()))
            .toList(),
        byDay: ((json['by_day'] as List?) ?? const [])
            .map((d) => DailyTotal.fromJson((d as Map).cast<String, dynamic>()))
            .toList(),
      );

  /// Expense categories, largest first.
  List<CategoryTotal> get expenseCategories =>
      byCategory.where((c) => !c.isIncome).toList()..sort((a, b) => b.total.compareTo(a.total));

  /// Total spending between [from] and [to] (inclusive, by calendar day).
  int expenseBetween(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return byDay.where((d) => !d.day.isBefore(start) && !d.day.isAfter(end)).fold(0, (sum, d) => sum + d.expense);
  }
}
