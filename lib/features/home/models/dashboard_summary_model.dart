import 'package:flutter/material.dart';
import 'transaction_model.dart';

/// Supported time periods for filtering Dashboard Income/Expense and Category Summary.
enum DashboardPeriod {
  thisWeek,
  thisMonth,
  thisYear,
  all,
}

extension DashboardPeriodExtension on DashboardPeriod {
  /// Compact Vietnamese label for period selector chips.
  String get label {
    switch (this) {
      case DashboardPeriod.thisWeek:
        return 'Tuần này';
      case DashboardPeriod.thisMonth:
        return 'Tháng này';
      case DashboardPeriod.thisYear:
        return 'Năm nay';
      case DashboardPeriod.all:
        return 'Tất cả';
    }
  }

  /// Detailed Vietnamese subtitle for the current period summary.
  String get subtitle {
    switch (this) {
      case DashboardPeriod.thisWeek:
        return 'Tuần hiện tại';
      case DashboardPeriod.thisMonth:
        return 'Tháng 06/2026';
      case DashboardPeriod.thisYear:
        return 'Năm 2026';
      case DashboardPeriod.all:
        return 'Toàn thời gian';
    }
  }
}

/// Aggregated category breakdown item for PRM-3 Dashboard Category Summary.
class CategorySummaryItem {
  final String category;
  final double amount;
  final double percentage; // 0.0 -> 1.0
  final int transactionCount;
  final IconData icon;
  final Color color;
  final Color containerColor;
  final TransactionType type;

  const CategorySummaryItem({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
    required this.icon,
    required this.color,
    required this.containerColor,
    required this.type,
  });

  /// Rounded integer percentage (0..100).
  int get percentInt => (percentage * 100).round();
}

/// Complete financial summary model for PRM-3 Dashboard.
/// Guarantees the core invariant: totalBalance = totalIncome - totalExpense.
class DashboardSummary {
  final double totalIncome;
  final double totalExpense;
  final double periodIncome;
  final double periodExpense;
  final double monthlyBudgetLimit;
  final DashboardPeriod period;

  const DashboardSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.periodIncome,
    required this.periodExpense,
    required this.monthlyBudgetLimit,
    required this.period,
  });

  /// Total available balance computed strictly as Total Income - Total Expense (PRM-3).
  double get totalBalance => totalIncome - totalExpense;

  /// Net cashflow for the selected period (Period Income - Period Expense).
  double get periodNetFlow => periodIncome - periodExpense;

  /// Monthly budget usage ratio clamped between 0.0 and 1.0.
  double get budgetProgressPercentage {
    if (monthlyBudgetLimit <= 0) return 0.0;
    return (periodExpense / monthlyBudgetLimit).clamp(0.0, 1.0);
  }

  /// Monthly budget usage percentage as an integer (e.g., 65 for 65%).
  int get budgetProgressPercentInt => (budgetProgressPercentage * 100).round();
}
