import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

/// LocalWalletRepository acts as the single source of truth for wallet data.
/// Works 100% offline without needing any external backend (BE).
class LocalWalletRepository {
  // In-memory balance initialized from design specifications
  double _currentBalance = 42850000;
  double _monthlyIncome = 28500000;
  double _monthlyExpense = 14320000;
  final double _monthlyBudgetLimit = 22000000;

  // Mock initial transactions matching the user's provided UI screens
  final List<TransactionModel> _transactions = [
    TransactionModel(
      id: 'tx-1',
      title: 'Ăn phở Thìn Lò Đúc',
      category: 'Ăn uống',
      amount: 65000,
      type: TransactionType.expense,
      walletSource: 'Tiền mặt',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      badgeText: 'AI Note',
      icon: Icons.restaurant,
    ),
    TransactionModel(
      id: 'tx-2',
      title: 'Highlands Coffee',
      category: 'Ăn uống',
      amount: 55000,
      type: TransactionType.expense,
      walletSource: 'Ví MoMo',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      badgeText: 'Hóa đơn',
      icon: Icons.local_cafe,
    ),
    TransactionModel(
      id: 'tx-3',
      title: 'Đổ xăng Petrolimex',
      category: 'Di chuyển',
      amount: 80000,
      type: TransactionType.expense,
      walletSource: 'Vietcombank',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      badgeText: 'Voice',
      icon: Icons.local_gas_station,
    ),
    TransactionModel(
      id: 'tx-4',
      title: 'Tạm ứng lương tháng 6',
      category: 'Lương',
      amount: 15000000,
      type: TransactionType.income,
      walletSource: 'Techcombank',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      icon: Icons.payments,
    ),
    TransactionModel(
      id: 'tx-5',
      title: 'Tiền thuê căn hộ',
      category: 'Nhà ở',
      amount: 4500000,
      type: TransactionType.expense,
      walletSource: 'Chuyển khoản',
      timestamp: DateTime.now().subtract(const Duration(days: 4)),
      badgeText: 'Định kỳ',
      icon: Icons.home_work,
    ),
  ];

  // Getters
  double get currentBalance => _currentBalance;
  double get monthlyIncome => _monthlyIncome;
  double get monthlyExpense => _monthlyExpense;
  double get monthlyBudgetLimit => _monthlyBudgetLimit;
  double get budgetProgressPercentage => (_monthlyExpense / _monthlyBudgetLimit).clamp(0.0, 1.0);
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);

  /// Inserts a new transaction locally and automatically recalculates balances.
  void addTransaction(TransactionModel transaction) {
    _transactions.insert(0, transaction);
    if (transaction.type == TransactionType.income) {
      _currentBalance += transaction.amount;
      _monthlyIncome += transaction.amount;
    } else {
      _currentBalance -= transaction.amount;
      _monthlyExpense += transaction.amount;
    }
  }
}
