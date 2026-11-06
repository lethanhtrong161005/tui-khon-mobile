/// Result of the `get_monthly_summary` RPC: totals for one month,
/// the previous month for comparison, budgets and the overall balance.
class MonthlySummary {
  final DateTime month;
  final int income;
  final int expense;
  final int previousIncome;
  final int previousExpense;
  final int totalBalance;
  final List<BudgetProgress> budgets;
  final List<DailyTotal> byDay;

  const MonthlySummary({
    required this.month,
    this.income = 0,
    this.expense = 0,
    this.previousIncome = 0,
    this.previousExpense = 0,
    this.totalBalance = 0,
    this.budgets = const [],
    this.byDay = const [],
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    final previous = (json['previous'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MonthlySummary(
      month: DateTime.parse(json['month'] as String),
      income: _int(json['income']),
      expense: _int(json['expense']),
      previousIncome: _int(previous['income']),
      previousExpense: _int(previous['expense']),
      totalBalance: _int(json['total_balance']),
      budgets: ((json['budgets'] as List?) ?? const [])
          .map((b) => BudgetProgress.fromJson((b as Map).cast<String, dynamic>()))
          .toList(),
      byDay: ((json['by_day'] as List?) ?? const [])
          .map((d) => DailyTotal.fromJson((d as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  /// The month-wide budget (category_id null), if the user set one.
  BudgetProgress? get totalBudget {
    for (final b in budgets) {
      if (b.categoryId == null) return b;
    }
    return null;
  }

  int expenseOn(DateTime day) {
    for (final d in byDay) {
      if (d.day.year == day.year && d.day.month == day.month && d.day.day == day.day) return d.expense;
    }
    return 0;
  }

  /// Percent change of spending vs last month; null when last month had no spending.
  int? get expenseChangePercent =>
      previousExpense > 0 ? ((expense - previousExpense) * 100 / previousExpense).round() : null;
}

class BudgetProgress {
  final String id;
  final String? categoryId;
  final String? categoryName;
  final int limitAmount;
  final int spent;

  const BudgetProgress({
    required this.id,
    required this.limitAmount,
    required this.spent,
    this.categoryId,
    this.categoryName,
  });

  factory BudgetProgress.fromJson(Map<String, dynamic> json) => BudgetProgress(
        id: json['id'] as String,
        categoryId: json['category_id'] as String?,
        categoryName: json['category_name'] as String?,
        limitAmount: _int(json['limit_amount']),
        spent: _int(json['spent']),
      );

  double get ratio => limitAmount > 0 ? spent / limitAmount : 0;
}

class DailyTotal {
  final DateTime day;
  final int income;
  final int expense;

  const DailyTotal({required this.day, this.income = 0, this.expense = 0});

  factory DailyTotal.fromJson(Map<String, dynamic> json) => DailyTotal(
        day: DateTime.parse(json['day'] as String),
        income: _int(json['income']),
        expense: _int(json['expense']),
      );
}

int _int(Object? value) => (value as num? ?? 0).toInt();
