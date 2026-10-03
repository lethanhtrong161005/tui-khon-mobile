import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tui_khon_mobile/core/services/local_storage_service.dart';
import 'package:tui_khon_mobile/features/home/controllers/home_controller.dart';
import 'package:tui_khon_mobile/features/home/data/local_wallet_repository.dart';
import 'package:tui_khon_mobile/features/home/models/dashboard_summary_model.dart';
import 'package:tui_khon_mobile/features/home/models/transaction_model.dart';
import 'package:tui_khon_mobile/features/home/presentation/home_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PRM-3 Dashboard Unit Tests (HomeController & LocalWalletRepository)', () {
    test('Calculates Total Balance = Total Income - Total Expense accurately', () {
      final repo = LocalWalletRepository();
      final controller = HomeController(
        repository: repo,
        storageService: LocalStorageService(),
      );

      final state = controller.state;

      // Verify PRM-3 core formula: Balance = Income - Expense
      expect(state.totalIncome, 57170000);
      expect(state.totalExpense, 14320000);
      expect(state.totalBalance, state.totalIncome - state.totalExpense);
      expect(state.totalBalance, 42850000);

      // Verify current month period summary matches Stitch design
      expect(state.periodIncome, 28500000);
      expect(state.periodExpense, 14320000);
      expect(state.periodNetFlow, 14180000);
    });

    test('Aggregates Category Summary for Expense and Income accurately', () {
      final repo = LocalWalletRepository();
      final controller = HomeController(
        repository: repo,
        storageService: LocalStorageService(),
      );

      final expenseCategories = controller.state.categorySummaries;
      expect(expenseCategories.isNotEmpty, isTrue);

      // Top expense category in seed data is Ăn uống (5,012,000 VND)
      expect(expenseCategories.first.category, 'Ăn uống');
      expect(expenseCategories.first.amount, 5012000);

      final sumCategoryExpenses = expenseCategories.fold<double>(
        0.0,
        (sum, item) => sum + item.amount,
      );
      expect(sumCategoryExpenses, controller.state.periodExpense);

      // Switch to Income category summary
      controller.setCategorySummaryType(TransactionType.income);
      final incomeCategories = controller.state.categorySummaries;
      expect(incomeCategories.isNotEmpty, isTrue);
      final sumCategoryIncomes = incomeCategories.fold<double>(
        0.0,
        (sum, item) => sum + item.amount,
      );
      expect(sumCategoryIncomes, controller.state.periodIncome);
    });

    test('Adding and deleting a transaction updates Balance, Period Summary, and Recent Transactions', () {
      final repo = LocalWalletRepository();
      final controller = HomeController(
        repository: repo,
        storageService: LocalStorageService(),
      );

      final initialBalance = controller.state.totalBalance;
      final initialExpense = controller.state.periodExpense;

      final newTx = TransactionModel(
        id: 'tx-test-999',
        title: 'Mua bàn phím cơ',
        category: 'Mua sắm',
        amount: 1500000,
        type: TransactionType.expense,
        walletSource: 'Ví MoMo',
        timestamp: DateTime.now(),
        icon: Icons.shopping_bag,
      );

      controller.addTransaction(newTx);

      expect(controller.state.totalBalance, initialBalance - 1500000);
      expect(controller.state.periodExpense, initialExpense + 1500000);
      expect(
        controller.state.totalBalance,
        controller.state.totalIncome - controller.state.totalExpense,
      );
      expect(controller.state.recentTransactions.first.id, 'tx-test-999');

      // Delete the transaction and verify balance is restored
      controller.deleteTransaction('tx-test-999');
      expect(controller.state.totalBalance, initialBalance);
      expect(controller.state.periodExpense, initialExpense);
    });

    test('Switching DashboardPeriod updates filtered income and expense', () {
      final repo = LocalWalletRepository();
      final controller = HomeController(
        repository: repo,
        storageService: LocalStorageService(),
      );

      controller.setPeriod(DashboardPeriod.all);
      expect(controller.state.selectedPeriod, DashboardPeriod.all);
      expect(controller.state.periodIncome, controller.state.totalIncome);
      expect(controller.state.periodExpense, controller.state.totalExpense);
    });
  });

  group('PRM-3 Dashboard Widget Tests', () {
    testWidgets('HomeScreen renders Balance, Category Summary, Recent Transactions and toggles visibility', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify key PRM-3 Dashboard sections exist
      expect(find.text('Số dư khả dụng'), findsOneWidget);
      expect(find.textContaining('42.850.000'), findsOneWidget);
      expect(find.text('Tóm tắt danh mục'), findsOneWidget);
      expect(find.text('Giao dịch gần đây'), findsOneWidget);
      expect(find.text('Ăn phở Thìn Lò Đúc'), findsOneWidget);

      // Toggle balance visibility
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      expect(find.text('••••••••'), findsOneWidget);
    });
  });
}
