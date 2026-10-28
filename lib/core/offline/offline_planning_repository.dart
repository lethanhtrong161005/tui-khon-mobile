import '../../features/planning/data/planning_repository.dart';
import '../../features/planning/models/planning_models.dart';
import '../../features/home/models/monthly_summary.dart';
import '../utils/id_generator.dart';
import 'local_store.dart';
import 'offline_wallet_repository.dart';

class OfflinePlanningRepository implements PlanningRepository {
  OfflinePlanningRepository(this.store);
  final LocalStore store;
  @override
  Future<List<BudgetProgress>> fetchBudgets(DateTime month) async =>
      (await OfflineWalletRepository(store).fetchMonthlySummary(month: month))
          .budgets;
  @override
  Future<void> saveBudget(
      {required DateTime month,
      String? categoryId,
      required int limitAmount}) async {
    if (limitAmount <= 0) throw StateError('Hạn mức phải lớn hơn 0');
    final key = monthKey(month);
    final old = (await store.rows('budgets'))
        .where((r) => r['month'] == key && r['category_id'] == categoryId)
        .firstOrNull;
    await store.put('budgets', {
      'id': old?['id'] ?? newUuidV4(),
      'month': key,
      'category_id': categoryId,
      'limit_amount': limitAmount
    });
  }

  @override
  Future<void> deleteBudget(String id) => store.remove('budgets', id);
  @override
  Future<int> copyBudgetsFromPreviousMonth(DateTime month) async {
    final all = await store.rows('budgets');
    final previous = all.where(
        (b) => b['month'] == monthKey(DateTime(month.year, month.month - 1)));
    final existing = all
        .where((b) => b['month'] == monthKey(month))
        .map((b) => b['category_id'])
        .toSet();
    final writes = [
      for (final b in previous)
        if (!existing.contains(b['category_id']))
          LocalMutation('budgets', {
            'id': newUuidV4(),
            'month': monthKey(month),
            'category_id': b['category_id'],
            'limit_amount': b['limit_amount']
          })
    ];
    await store.writeBatch(writes);
    return writes.length;
  }

  @override
  Future<List<DebtModel>> fetchDebts() async =>
      (await store.rows('debts')).map(DebtModel.fromJson).toList()
        ..sort((a, b) {
          if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
          return (a.dueDate ?? DateTime(9999))
              .compareTo(b.dueDate ?? DateTime(9999));
        });
  @override
  Future<void> saveDebt(DebtModel debt) async {
    if (debt.amount <= 0 || debt.personName.trim().isEmpty)
      throw StateError('Khoản nợ không hợp lệ');
    await store.put('debts', {
      'id': debt.id ?? newUuidV4(),
      'paid_amount': debt.paidAmount,
      'status': debt.isSettled ? 'settled' : 'active',
      ...debt.toJson()
    });
  }

  @override
  Future<void> deleteDebt(String id) => store.remove('debts', id);
  @override
  Future<void> settleDebt(String id,
      {int? amount,
      bool recordTransaction = false,
      DateTime? paidAt,
      String? note,
      String? walletId}) async {
    final debt = await store.record('debts', id);
    if (debt == null) throw StateError('Không tìm thấy khoản nợ');
    final remaining = (debt['amount'] as num).toInt() -
        (debt['paid_amount'] as num? ?? 0).toInt();
    final pay = amount ?? remaining;
    if (pay <= 0 || pay > remaining)
      throw StateError('Số tiền trả vượt khoản nợ còn lại');
    final selectedWallet = recordTransaction ? await _wallet(walletId) : null;
    final paymentId = newUuidV4();
    await store.put('debt_payments', {
      'id': paymentId,
      'debt_id': id,
      'amount': pay,
      'paid_at': (paidAt ?? DateTime.now()).toUtc().toIso8601String(),
      'note': _note(note),
      'record_transaction': recordTransaction,
      'wallet_id': selectedWallet,
      'transaction_id':
          recordTransaction ? debtPaymentTransactionId(paymentId) : null,
      'is_legacy': false
    });
  }

  String? _note(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  Future<String> _wallet(String? id, {String? retained}) async {
    final wallets = await store.rows('wallets');
    final selected = id == null
        ? wallets.where((w) => w['is_archived'] != true).firstOrNull
        : wallets.where((w) => w['id'] == id).firstOrNull;
    if (selected == null ||
        (selected['is_archived'] == true && selected['id'] != retained)) {
      throw StateError('Chọn nguồn tiền đang hoạt động để ghi kèm giao dịch');
    }
    return selected['id'] as String;
  }

  @override
  Future<void> updateDebtPayment(String id,
      {required int amount,
      required DateTime paidAt,
      String? note,
      required bool recordTransaction,
      String? walletId}) async {
    final previous = await store.record('debt_payments', id);
    if (previous == null) throw StateError('Lần trả nợ không còn tồn tại');
    if (previous['is_legacy'] == true && recordTransaction) {
      throw StateError('Số tiền trước nâng cấp không được tạo thu/chi');
    }
    final wallet = recordTransaction
        ? await _wallet(walletId ?? previous['wallet_id'] as String?,
            retained: previous['record_transaction'] == true
                ? previous['wallet_id'] as String?
                : null)
        : previous['wallet_id'];
    await store.put('debt_payments', {
      ...previous,
      'amount': amount,
      'paid_at': paidAt.toUtc().toIso8601String(),
      'note': _note(note),
      'record_transaction': recordTransaction,
      'wallet_id': wallet,
      'transaction_id': previous['transaction_id'] ??
          (recordTransaction ? debtPaymentTransactionId(id) : null),
    });
  }

  @override
  Future<void> undoDebtPayment(String id) async {
    if (await store.record('debt_payments', id) == null)
      throw StateError('Lần trả nợ không còn tồn tại');
    await store.remove('debt_payments', id);
  }

  @override
  Future<List<GoalModel>> fetchGoals() async => (await store.rows('goals'))
      .where((g) => g['status'] != 'cancelled')
      .map(GoalModel.fromJson)
      .toList();
  @override
  Future<void> saveGoal(GoalModel goal) => store.put('goals', {
        'id': goal.id ?? newUuidV4(),
        'saved_amount': goal.savedAmount,
        'status': goal.isCompleted ? 'completed' : 'active',
        ...goal.toJson()
      });
  @override
  Future<void> setGoalSaved(String id, int savedAmount) async {
    if (savedAmount < 0) throw StateError('Số đã để dành không được âm');
    await store.put('goals', {'id': id, 'saved_amount': savedAmount});
  }

  @override
  Future<void> deleteGoal(String id) => store.remove('goals', id);
}
