import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../home/models/monthly_summary.dart';
import '../models/planning_models.dart';

/// Budgets, debt book and savings goals. All rows are scoped by RLS.
abstract class PlanningRepository {
  /// Budgets of [month] with what has been spent so far.
  Future<List<BudgetProgress>> fetchBudgets(DateTime month);

  /// Creates or updates (same category + month) a monthly limit.
  /// [categoryId] null = the month-wide budget.
  Future<void> saveBudget({required DateTime month, String? categoryId, required int limitAmount});

  Future<void> deleteBudget(String id);

  /// Copies last month's limits into [month]; returns how many were copied.
  Future<int> copyBudgetsFromPreviousMonth(DateTime month);

  /// Active debts first (nearest due date first), then settled ones.
  Future<List<DebtModel>> fetchDebts();

  Future<void> saveDebt(DebtModel debt);

  Future<void> deleteDebt(String id);

  /// `settle_debt` RPC: [amount] null = pay everything left. When
  /// [recordTransaction], a matching income / expense is written too.
  Future<void> settleDebt(String id, {int? amount, bool recordTransaction = false});

  Future<List<GoalModel>> fetchGoals();

  Future<void> saveGoal(GoalModel goal);

  /// Sets the saved amount; the database marks the goal completed when reached.
  Future<void> setGoalSaved(String id, int savedAmount);

  Future<void> deleteGoal(String id);
}

String monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-01';

class SupabasePlanningRepository implements PlanningRepository {
  SupabasePlanningRepository(this._client);

  final SupabaseClient _client;

  static const _debtColumns = 'id, type, person_name, phone, amount, paid_amount, due_date, note, status';
  static const _goalColumns = 'id, name, icon, color, target_amount, saved_amount, deadline, status';

  @override
  Future<List<BudgetProgress>> fetchBudgets(DateTime month) async {
    final data = await _client.rpc('get_monthly_summary', params: {'p_month': monthKey(month)});
    return MonthlySummary.fromJson((data as Map).cast<String, dynamic>()).budgets;
  }

  @override
  Future<void> saveBudget({required DateTime month, String? categoryId, required int limitAmount}) async {
    var query = _client.from('budgets').select('id').eq('month', monthKey(month));
    query = categoryId == null ? query.isFilter('category_id', null) : query.eq('category_id', categoryId);
    final existing = await query.maybeSingle();
    if (existing == null) {
      await _client.from('budgets').insert({
        'month': monthKey(month),
        'category_id': categoryId,
        'limit_amount': limitAmount,
      });
    } else {
      await _client.from('budgets').update({'limit_amount': limitAmount}).eq('id', existing['id'] as String);
    }
  }

  @override
  Future<void> deleteBudget(String id) async {
    await _client.from('budgets').delete().eq('id', id);
  }

  @override
  Future<int> copyBudgetsFromPreviousMonth(DateTime month) async {
    final previous = DateTime(month.year, month.month - 1);
    final rows = await _client
        .from('budgets')
        .select('category_id, limit_amount')
        .eq('month', monthKey(previous));
    if (rows.isEmpty) return 0;
    await _client.from('budgets').upsert(
      [
        for (final r in rows)
          {'month': monthKey(month), 'category_id': r['category_id'], 'limit_amount': r['limit_amount']},
      ],
      onConflict: 'user_id,category_id,month',
      ignoreDuplicates: true,
    );
    return rows.length;
  }

  @override
  Future<List<DebtModel>> fetchDebts() async {
    final rows = await _client
        .from('debts')
        .select(_debtColumns)
        .order('status')
        .order('due_date', nullsFirst: false)
        .order('created_at');
    return rows.map(DebtModel.fromJson).toList();
  }

  @override
  Future<void> saveDebt(DebtModel debt) async {
    if (debt.id == null) {
      await _client.from('debts').insert(debt.toJson());
    } else {
      await _client.from('debts').update(debt.toJson()).eq('id', debt.id!);
    }
  }

  @override
  Future<void> deleteDebt(String id) async {
    await _client.from('debts').delete().eq('id', id);
  }

  @override
  Future<void> settleDebt(String id, {int? amount, bool recordTransaction = false}) async {
    await _client.rpc('settle_debt', params: {
      'p_debt_id': id,
      'p_amount': amount,
      'p_record_transaction': recordTransaction,
    });
  }

  @override
  Future<List<GoalModel>> fetchGoals() async {
    final rows = await _client.from('goals').select(_goalColumns).neq('status', 'cancelled').order('created_at');
    return rows.map(GoalModel.fromJson).toList();
  }

  @override
  Future<void> saveGoal(GoalModel goal) async {
    if (goal.id == null) {
      await _client.from('goals').insert(goal.toJson());
    } else {
      await _client.from('goals').update(goal.toJson()).eq('id', goal.id!);
    }
  }

  @override
  Future<void> setGoalSaved(String id, int savedAmount) async {
    await _client.from('goals').update({'saved_amount': savedAmount}).eq('id', id);
  }

  @override
  Future<void> deleteGoal(String id) async {
    await _client.from('goals').delete().eq('id', id);
  }
}

final planningRepositoryProvider = Provider<PlanningRepository>((ref) {
  ref.watch(currentUserIdProvider);
  return SupabasePlanningRepository(ref.watch(supabaseClientProvider));
});

final budgetsProvider = FutureProvider.autoDispose.family<List<BudgetProgress>, DateTime>(
  (ref, month) => ref.watch(planningRepositoryProvider).fetchBudgets(month),
);

final debtsProvider = FutureProvider.autoDispose<List<DebtModel>>(
  (ref) => ref.watch(planningRepositoryProvider).fetchDebts(),
);

final goalsProvider = FutureProvider.autoDispose<List<GoalModel>>(
  (ref) => ref.watch(planningRepositoryProvider).fetchGoals(),
);
