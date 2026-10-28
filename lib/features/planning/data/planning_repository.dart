import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/local_store.dart';
import '../../../core/offline/offline_planning_repository.dart';
import '../../home/models/monthly_summary.dart';
import '../models/planning_models.dart';

/// Budgets, debt book and savings goals. All rows are scoped by RLS.
abstract class PlanningRepository {
  /// Budgets of [month] with what has been spent so far.
  Future<List<BudgetProgress>> fetchBudgets(DateTime month);

  /// Creates or updates (same category + month) a monthly limit.
  /// [categoryId] null = the month-wide budget.
  Future<void> saveBudget(
      {required DateTime month, String? categoryId, required int limitAmount});

  Future<void> deleteBudget(String id);

  /// Copies last month's limits into [month]; returns how many were copied.
  Future<int> copyBudgetsFromPreviousMonth(DateTime month);

  /// Active debts first (nearest due date first), then settled ones.
  Future<List<DebtModel>> fetchDebts();

  Future<void> saveDebt(DebtModel debt);

  Future<void> deleteDebt(String id);

  /// Atomic local payment and outbox write: [amount] null = pay everything left. When
  /// [recordTransaction], a matching income / expense is written too.
  Future<void> settleDebt(String id,
      {int? amount,
      bool recordTransaction = false,
      DateTime? paidAt,
      String? note,
      String? walletId});

  Future<void> updateDebtPayment(String id,
      {required int amount,
      required DateTime paidAt,
      String? note,
      required bool recordTransaction,
      String? walletId});

  Future<void> undoDebtPayment(String id);

  Future<List<GoalModel>> fetchGoals();

  Future<void> saveGoal(GoalModel goal);

  /// Sets the saved amount; the database marks the goal completed when reached.
  Future<void> setGoalSaved(String id, int savedAmount);

  Future<void> deleteGoal(String id);
}

String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-01';

final planningRepositoryProvider = Provider<PlanningRepository>((ref) {
  final store = ref.watch(localStoreProvider);
  if (store == null) throw StateError('Bạn cần đăng nhập');
  return OfflinePlanningRepository(store);
});

final budgetsProvider =
    FutureProvider.autoDispose.family<List<BudgetProgress>, DateTime>(
  (ref, month) {
    ref.watch(localRevisionProvider);
    return ref.watch(planningRepositoryProvider).fetchBudgets(month);
  },
);

final debtsProvider = FutureProvider.autoDispose<List<DebtModel>>(
  (ref) {
    ref.watch(localRevisionProvider);
    return ref.watch(planningRepositoryProvider).fetchDebts();
  },
);

final goalsProvider = FutureProvider.autoDispose<List<GoalModel>>(
  (ref) {
    ref.watch(localRevisionProvider);
    return ref.watch(planningRepositoryProvider).fetchGoals();
  },
);
