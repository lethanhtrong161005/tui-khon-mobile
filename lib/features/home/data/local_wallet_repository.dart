import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/dashboard_summary_model.dart';
import '../models/transaction_model.dart';

/// LocalWalletRepository acts as the single source of truth for wallet data.
/// Computes Total Balance = Total Income - Total Expense dynamically from transactions,
/// and provides period filtering and category aggregation for PRM-3 Dashboard.
class LocalWalletRepository {
  final double _monthlyBudgetLimit = 22000000;
  late List<TransactionModel> _transactions;

  LocalWalletRepository({List<TransactionModel>? initialTransactions}) {
    _transactions = List<TransactionModel>.from(
      initialTransactions ?? _buildDefaultSeedTransactions(),
    );
    _sortTransactions();
  }

  /// Builds default seed transactions matching the Stitch UI figures and PRM-3 formula:
  /// - Top 5 recent transactions match Stitch "Trang Chủ - Túi Khôn"
  /// - Current Month Income = 28,500,000 ₫
  /// - Current Month Expense = 14,320,000 ₫ (Ăn uống 5,012,000 + Nhà ở 4,500,000 + Mua sắm 2,577,000 + Di chuyển 1,432,000 + Khác 799,000)
  /// - Total Income = 57,170,000 ₫, Total Expense = 14,320,000 ₫
  /// - Total Balance = Total Income - Total Expense = 42,850,000 ₫
  static List<TransactionModel> _buildDefaultSeedTransactions() {
    final now = DateTime.now();
    final today1230 = DateTime(now.year, now.month, now.day, 12, 30);
    final today0915 = DateTime(now.year, now.month, now.day, 9, 15);

    return [
      TransactionModel(
        id: 'tx-1',
        title: 'Ăn phở Thìn Lò Đúc',
        category: 'Ăn uống',
        amount: 65000,
        type: TransactionType.expense,
        walletSource: 'Tiền mặt',
        timestamp: today1230,
        badgeText: 'AI Note',
        icon: Icons.restaurant,
        note: 'Ghi tự động qua trợ lý Gemini AI',
      ),
      TransactionModel(
        id: 'tx-2',
        title: 'Highlands Coffee',
        category: 'Ăn uống',
        amount: 55000,
        type: TransactionType.expense,
        walletSource: 'Ví MoMo',
        timestamp: today0915,
        badgeText: 'Hóa đơn',
        icon: Icons.local_cafe,
        hasReceipt: true,
        note: 'Cà phê sáng cùng nhóm dự án (đã quét hóa đơn)',
      ),
      TransactionModel(
        id: 'tx-3',
        title: 'Đổ xăng Petrolimex',
        category: 'Di chuyển',
        amount: 80000,
        type: TransactionType.expense,
        walletSource: 'Vietcombank',
        timestamp: now.subtract(const Duration(days: 1)),
        badgeText: 'Voice',
        icon: Icons.local_gas_station,
        note: 'Ghi bằng giọng nói tiếng Việt',
      ),
      TransactionModel(
        id: 'tx-4',
        title: 'Tạm ứng lương tháng 6',
        category: 'Lương',
        amount: 15000000,
        type: TransactionType.income,
        walletSource: 'Techcombank',
        timestamp: now.subtract(const Duration(days: 2)),
        icon: Icons.payments,
        note: 'Lương đợt 1 chuyển khoản qua Techcombank',
      ),
      TransactionModel(
        id: 'tx-5',
        title: 'Tiền thuê căn hộ',
        category: 'Nhà ở',
        amount: 4500000,
        type: TransactionType.expense,
        walletSource: 'Chuyển khoản',
        timestamp: now.subtract(const Duration(days: 4)),
        badgeText: 'Định kỳ',
        icon: Icons.home_work,
        note: 'Thanh toán tiền thuê nhà định kỳ hàng tháng',
      ),
      TransactionModel(
        id: 'tx-6',
        title: 'Siêu thị WinMart & Thực phẩm tuần',
        category: 'Ăn uống',
        amount: 4892000,
        type: TransactionType.expense,
        walletSource: 'Techcombank',
        timestamp: now.subtract(const Duration(days: 5)),
        badgeText: 'Hóa đơn',
        icon: Icons.restaurant,
        hasReceipt: true,
        note: 'Chi phí thực phẩm, liên hoan và ăn uống trong tháng',
      ),
      TransactionModel(
        id: 'tx-7',
        title: 'Mua sắm Shopee & Đồ gia dụng',
        category: 'Mua sắm',
        amount: 2577000,
        type: TransactionType.expense,
        walletSource: 'Ví MoMo',
        timestamp: now.subtract(const Duration(days: 6)),
        badgeText: 'AI Note',
        icon: Icons.shopping_bag,
        note: 'Mua quần áo và phụ kiện làm việc',
      ),
      TransactionModel(
        id: 'tx-8',
        title: 'Vé tháng xe buýt điện & Grab',
        category: 'Di chuyển',
        amount: 1352000,
        type: TransactionType.expense,
        walletSource: 'Ví MoMo',
        timestamp: now.subtract(const Duration(days: 8)),
        icon: Icons.directions_bus,
        note: 'Chi phí đi lại công tác và di chuyển nội thành',
      ),
      TransactionModel(
        id: 'tx-9',
        title: 'Thưởng dự án & Freelance Q2',
        category: 'Thưởng',
        amount: 13500000,
        type: TransactionType.income,
        walletSource: 'Vietcombank',
        timestamp: now.subtract(const Duration(days: 9)),
        badgeText: 'AI Note',
        icon: Icons.celebration,
        note: 'Tiền thưởng hoàn thành sớm milestone dự án',
      ),
      TransactionModel(
        id: 'tx-10',
        title: 'Cắt tóc, Sách & Giải trí cuối tuần',
        category: 'Khác',
        amount: 799000,
        type: TransactionType.expense,
        walletSource: 'Tiền mặt',
        timestamp: now.subtract(const Duration(days: 11)),
        icon: Icons.category,
        note: 'Chi tiêu cá nhân phát sinh',
      ),
      TransactionModel(
        id: 'tx-11',
        title: 'Lương & Tích lũy kỳ trước',
        category: 'Lương',
        amount: 28670000,
        type: TransactionType.income,
        walletSource: 'Techcombank',
        timestamp: DateTime(now.year, now.month - 1, 25, 10, 0),
        icon: Icons.account_balance_wallet,
        note: 'Số dư tích lũy từ lương các kỳ trước',
      ),
    ];
  }

  void _sortTransactions() {
    _transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Replaces current transactions list (e.g. when loaded from local storage).
  void setTransactions(List<TransactionModel> items) {
    _transactions = List<TransactionModel>.from(items);
    _sortTransactions();
  }

  /// Immutable list of all transactions sorted newest-first.
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);

  /// Total cumulative income across all transactions.
  double get totalIncome => _transactions
      .where((tx) => tx.type == TransactionType.income)
      .fold(0.0, (sum, tx) => sum + tx.amount);

  /// Total cumulative expense across all transactions.
  double get totalExpense => _transactions
      .where((tx) => tx.type == TransactionType.expense)
      .fold(0.0, (sum, tx) => sum + tx.amount);

  /// Core PRM-3 formula: Balance = Total Income - Total Expense.
  double get currentBalance => totalIncome - totalExpense;

  /// Current month total income.
  double get monthlyIncome => getIncomeForPeriod(DashboardPeriod.thisMonth);

  /// Current month total expense.
  double get monthlyExpense => getExpenseForPeriod(DashboardPeriod.thisMonth);

  /// Monthly budget limit.
  double get monthlyBudgetLimit => _monthlyBudgetLimit;

  /// Budget progress ratio (0.0 to 1.0).
  double get budgetProgressPercentage =>
      (monthlyExpense / _monthlyBudgetLimit).clamp(0.0, 1.0);

  /// Filters transactions belonging to the given [DashboardPeriod].
  List<TransactionModel> filterByPeriod(
    DashboardPeriod period, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    switch (period) {
      case DashboardPeriod.thisWeek:
        final cutoff = now.subtract(const Duration(days: 7));
        return _transactions
            .where((tx) => !tx.timestamp.isBefore(cutoff))
            .toList();
      case DashboardPeriod.thisMonth:
        return _transactions
            .where(
              (tx) =>
                  tx.timestamp.year == now.year &&
                  tx.timestamp.month == now.month,
            )
            .toList();
      case DashboardPeriod.thisYear:
        return _transactions
            .where((tx) => tx.timestamp.year == now.year)
            .toList();
      case DashboardPeriod.all:
        return List.unmodifiable(_transactions);
    }
  }

  /// Computes total income within the specified [period].
  double getIncomeForPeriod(DashboardPeriod period) {
    return filterByPeriod(period)
        .where((tx) => tx.type == TransactionType.income)
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  /// Computes total expense within the specified [period].
  double getExpenseForPeriod(DashboardPeriod period) {
    return filterByPeriod(period)
        .where((tx) => tx.type == TransactionType.expense)
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  /// Builds the full [DashboardSummary] for the selected [period].
  DashboardSummary getSummary(DashboardPeriod period) {
    return DashboardSummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      periodIncome: getIncomeForPeriod(period),
      periodExpense: getExpenseForPeriod(period),
      monthlyBudgetLimit: _monthlyBudgetLimit,
      period: period,
    );
  }

  /// Computes aggregated [CategorySummaryItem] list for the given [period] and [type].
  List<CategorySummaryItem> getCategorySummaries({
    required DashboardPeriod period,
    TransactionType type = TransactionType.expense,
  }) {
    final periodTxs = filterByPeriod(period)
        .where((tx) => tx.type == type)
        .toList();

    final totalForType = periodTxs.fold(0.0, (sum, tx) => sum + tx.amount);
    if (periodTxs.isEmpty || totalForType <= 0) {
      return const [];
    }

    final Map<String, double> amountByCat = {};
    final Map<String, int> countByCat = {};

    for (final tx in periodTxs) {
      final normalizedCat = _normalizeCategoryName(tx.category);
      amountByCat[normalizedCat] = (amountByCat[normalizedCat] ?? 0) + tx.amount;
      countByCat[normalizedCat] = (countByCat[normalizedCat] ?? 0) + 1;
    }

    final items = amountByCat.entries.map((entry) {
      final cat = entry.key;
      final amt = entry.value;
      final pct = (amt / totalForType).clamp(0.0, 1.0);
      return CategorySummaryItem(
        category: cat,
        amount: amt,
        percentage: pct,
        transactionCount: countByCat[cat] ?? 1,
        icon: _categoryIcon(cat, type),
        color: _categoryColor(cat, type),
        containerColor: _categoryContainerColor(cat, type),
        type: type,
      );
    }).toList();

    items.sort((a, b) => b.amount.compareTo(a.amount));
    return items;
  }

  /// Inserts a new transaction locally and automatically recalculates balances.
  void addTransaction(TransactionModel transaction) {
    _transactions.insert(0, transaction);
    _sortTransactions();
  }

  /// Deletes a transaction by [id] and recalculates balances.
  void deleteTransaction(String id) {
    _transactions.removeWhere((tx) => tx.id == id);
  }

  /// Updates an existing transaction and recalculates balances.
  void updateTransaction(TransactionModel updated) {
    final idx = _transactions.indexWhere((tx) => tx.id == updated.id);
    if (idx != -1) {
      _transactions[idx] = updated;
      _sortTransactions();
    }
  }

  static String _normalizeCategoryName(String raw) {
    if (raw.startsWith('Nhà ở')) return 'Nhà ở';
    if (raw.startsWith('Mua sắm')) return 'Mua sắm';
    return raw;
  }

  static IconData _categoryIcon(String category, TransactionType type) {
    if (type == TransactionType.income) {
      if (category.contains('Lương')) return Icons.payments;
      return Icons.celebration;
    }
    switch (category) {
      case 'Ăn uống':
        return Icons.restaurant;
      case 'Nhà ở':
        return Icons.apartment;
      case 'Mua sắm':
        return Icons.shopping_bag;
      case 'Di chuyển':
        return Icons.directions_bus;
      default:
        return Icons.category;
    }
  }

  static Color _categoryColor(String category, TransactionType type) {
    if (type == TransactionType.income) {
      if (category.contains('Lương')) return AppColors.primary;
      return AppColors.secondary;
    }
    switch (category) {
      case 'Ăn uống':
        return AppColors.tertiary;
      case 'Nhà ở':
        return AppColors.secondary;
      case 'Mua sắm':
        return AppColors.error;
      case 'Di chuyển':
        return AppColors.primary;
      default:
        return AppColors.outline;
    }
  }

  static Color _categoryContainerColor(String category, TransactionType type) {
    return _categoryColor(category, type).withOpacity(0.12);
  }
}
