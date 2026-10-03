import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/local_storage_service.dart';
import '../data/local_wallet_repository.dart';
import '../models/dashboard_summary_model.dart';
import '../models/transaction_model.dart';

/// Immutable state representing the entire PRM-3 Dashboard view model.
class HomeState {
  final DashboardSummary summary;
  final List<TransactionModel> allTransactions;
  final List<TransactionModel> periodTransactions;
  final List<CategorySummaryItem> categorySummaries;
  final DashboardPeriod selectedPeriod;
  final TransactionType selectedCategoryType;
  final bool isBalanceVisible;
  final int currentTabIndex;

  const HomeState({
    required this.summary,
    required this.allTransactions,
    required this.periodTransactions,
    required this.categorySummaries,
    required this.selectedPeriod,
    required this.selectedCategoryType,
    required this.isBalanceVisible,
    this.currentTabIndex = 0,
  });

  /// Total Balance = Total Income - Total Expense (PRM-3 requirement 2).
  double get totalBalance => summary.totalBalance;

  /// Total cumulative income across all transactions.
  double get totalIncome => summary.totalIncome;

  /// Total cumulative expense across all transactions.
  double get totalExpense => summary.totalExpense;

  /// Total income for the currently selected period (PRM-3 requirement 3).
  double get periodIncome => summary.periodIncome;

  /// Total expense for the currently selected period (PRM-3 requirement 3).
  double get periodExpense => summary.periodExpense;

  /// Net summary for the currently selected period (Income - Expense).
  double get periodNetFlow => summary.periodNetFlow;

  /// Monthly budget limit.
  double get monthlyBudgetLimit => summary.monthlyBudgetLimit;

  /// Monthly budget progress ratio (0.0 to 1.0).
  double get budgetProgressPercentage => summary.budgetProgressPercentage;

  /// Monthly budget progress integer percentage (0..100).
  int get budgetProgressPercentInt => summary.budgetProgressPercentInt;

  /// Top 5 newest transactions for the Recent Transactions section (PRM-3 requirement 4).
  List<TransactionModel> get recentTransactions =>
      periodTransactions.take(5).toList();

  HomeState copyWith({
    DashboardSummary? summary,
    List<TransactionModel>? allTransactions,
    List<TransactionModel>? periodTransactions,
    List<CategorySummaryItem>? categorySummaries,
    DashboardPeriod? selectedPeriod,
    TransactionType? selectedCategoryType,
    bool? isBalanceVisible,
    int? currentTabIndex,
  }) {
    return HomeState(
      summary: summary ?? this.summary,
      allTransactions: allTransactions ?? this.allTransactions,
      periodTransactions: periodTransactions ?? this.periodTransactions,
      categorySummaries: categorySummaries ?? this.categorySummaries,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      selectedCategoryType: selectedCategoryType ?? this.selectedCategoryType,
      isBalanceVisible: isBalanceVisible ?? this.isBalanceVisible,
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
    );
  }
}

/// Riverpod StateNotifier managing Dashboard state, transactions, period filter,
/// category summaries, and bottom navigation tab state.
class HomeController extends StateNotifier<HomeState> {
  final LocalWalletRepository _repository;
  final LocalStorageService _storageService;

  HomeController({
    required LocalWalletRepository repository,
    required LocalStorageService storageService,
  })  : _repository = repository,
        _storageService = storageService,
        super(
          _computeState(
            repository: repository,
            period: DashboardPeriod.thisMonth,
            categoryType: TransactionType.expense,
            isBalanceVisible: true,
            currentTabIndex: 0,
          ),
        ) {
    _hydrateFromStorage();
  }

  static HomeState _computeState({
    required LocalWalletRepository repository,
    required DashboardPeriod period,
    required TransactionType categoryType,
    required bool isBalanceVisible,
    required int currentTabIndex,
  }) {
    return HomeState(
      summary: repository.getSummary(period),
      allTransactions: repository.transactions,
      periodTransactions: repository.filterByPeriod(period),
      categorySummaries: repository.getCategorySummaries(
        period: period,
        type: categoryType,
      ),
      selectedPeriod: period,
      selectedCategoryType: categoryType,
      isBalanceVisible: isBalanceVisible,
      currentTabIndex: currentTabIndex,
    );
  }

  Future<void> _hydrateFromStorage() async {
    final storedTxs = await _storageService.loadTransactions();
    final isVisible = await _storageService.loadBalanceVisibility();
    if (!mounted) return;

    if (storedTxs != null && storedTxs.isNotEmpty) {
      _repository.setTransactions(storedTxs);
    }
    _recompute(isBalanceVisible: isVisible);
  }

  void _recompute({
    DashboardPeriod? period,
    TransactionType? categoryType,
    bool? isBalanceVisible,
    int? currentTabIndex,
  }) {
    final nextPeriod = period ?? state.selectedPeriod;
    final nextCategoryType = categoryType ?? state.selectedCategoryType;
    final nextVisible = isBalanceVisible ?? state.isBalanceVisible;
    final nextTab = currentTabIndex ?? state.currentTabIndex;

    state = _computeState(
      repository: _repository,
      period: nextPeriod,
      categoryType: nextCategoryType,
      isBalanceVisible: nextVisible,
      currentTabIndex: nextTab,
    );
  }

  /// Toggles whether the total balance is visible or masked (`••••••••`).
  void toggleBalanceVisibility() {
    final nextVisible = !state.isBalanceVisible;
    _recompute(isBalanceVisible: nextVisible);
    _storageService.saveBalanceVisibility(nextVisible);
  }

  /// Updates the active period filter (`Tuần này`, `Tháng này`, `Năm nay`, `Tất cả`).
  void setPeriod(DashboardPeriod period) {
    if (state.selectedPeriod == period) return;
    _recompute(period: period);
  }

  /// Switches the Category Summary view between Expense and Income categories.
  void setCategorySummaryType(TransactionType type) {
    if (state.selectedCategoryType == type) return;
    _recompute(categoryType: type);
  }

  /// Changes the active tab index in MainShellScreen.
  void setTabIndex(int index) {
    if (state.currentTabIndex == index) return;
    _recompute(currentTabIndex: index);
  }

  /// Adds a new transaction, immediately updating Balance, Income/Expense,
  /// Category Summary, and Recent Transactions on the Dashboard.
  void addTransaction(TransactionModel transaction) {
    _repository.addTransaction(transaction);
    _recompute();
    _storageService.saveTransactions(_repository.transactions);
  }

  /// Removes a transaction by ID and recalculates all Dashboard metrics.
  void deleteTransaction(String id) {
    _repository.deleteTransaction(id);
    _recompute();
    _storageService.saveTransactions(_repository.transactions);
  }

  /// Updates an existing transaction and recalculates all Dashboard metrics.
  void updateTransaction(TransactionModel updated) {
    _repository.updateTransaction(updated);
    _recompute();
    _storageService.saveTransactions(_repository.transactions);
  }

  /// Re-computes state from repository (used for pull-to-refresh).
  Future<void> refreshDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    _recompute();
  }
}

/// Provider for LocalStorageService.
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

/// Provider for LocalWalletRepository.
final localWalletRepositoryProvider = Provider<LocalWalletRepository>((ref) {
  return LocalWalletRepository();
});

/// Primary Riverpod StateNotifierProvider for the PRM-3 Dashboard.
final homeControllerProvider =
    StateNotifierProvider<HomeController, HomeState>((ref) {
  final repository = ref.watch(localWalletRepositoryProvider);
  final storage = ref.watch(localStorageServiceProvider);
  return HomeController(
    repository: repository,
    storageService: storage,
  );
});
