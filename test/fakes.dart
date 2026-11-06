import 'package:tui_khon_mobile/core/services/vietnamese_nlp_service.dart';
import 'package:tui_khon_mobile/core/services/voice_input_service.dart';
import 'package:tui_khon_mobile/features/advisor/data/advisor_repository.dart';
import 'package:tui_khon_mobile/features/advisor/models/advisor_models.dart';
import 'package:tui_khon_mobile/features/home/models/category_model.dart';
import 'package:tui_khon_mobile/features/home/models/monthly_summary.dart';
import 'package:tui_khon_mobile/features/home/models/transaction_model.dart';
import 'package:tui_khon_mobile/features/home/models/wallet_model.dart';
import 'package:tui_khon_mobile/features/quick_record/data/quick_record_repository.dart';
import 'package:tui_khon_mobile/features/receipt/data/receipt_repository.dart';
import 'package:tui_khon_mobile/core/services/app_lock_service.dart';
import 'package:tui_khon_mobile/core/services/debt_reminder_service.dart';
import 'package:tui_khon_mobile/features/planning/data/planning_repository.dart';
import 'package:tui_khon_mobile/features/planning/models/planning_models.dart';

/// Quick record without a backend: text goes through the on-device parser,
/// receipts come back as a fixed "Circle K" draft.
class FakeQuickRecordRepository implements QuickRecordRepository {
  @override
  Future<QuickRecordResult> parse(
    String text, {
    required List<CategoryModel> categories,
    required List<WalletModel> wallets,
    bool voice = false,
    List<ChatTurn> history = const [],
  }) async {
    final draft = resolveDraftNames(
      VietnameseNlpService.parseInput(text, source: voice ? TransactionSource.voice : TransactionSource.ai),
      categories,
      wallets,
    );
    return QuickRecordResult(draft: draft, quotaUsed: 1, quotaLimit: 50);
  }

  @override
  Future<QuickRecordResult> scanReceipt(PickedReceipt receipt) async => const QuickRecordResult(
        draft: TransactionDraft(
          type: TransactionType.expense,
          amount: 120000,
          walletId: 'wallet-cash',
          walletName: 'Tiền mặt',
          categoryId: 'cat-food',
          categoryName: 'Ăn uống',
          note: 'Mua đồ ăn sáng',
          merchant: 'Circle K',
          source: TransactionSource.receipt,
          receiptPath: 'user-1/receipt.jpg',
        ),
      );

  @override
  Future<int?> fetchTodayChatUsage() async => 0;
}

/// Speech recognizer that immediately "hears" [transcript].
class FakeVoiceInput implements VoiceInput {
  FakeVoiceInput(this.transcript);

  final String transcript;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> start({
    required void Function(String text, bool isFinal) onResult,
    void Function()? onDone,
    void Function(String error)? onError,
  }) async {
    _listening = true;
    Future.microtask(() {
      onResult(transcript, true);
      _listening = false;
    });
    return true;
  }

  @override
  Future<void> stop() async => _listening = false;
}

/// In-memory budgets, debt book and goals mirroring the database rules
/// (settle_debt, goal completion).
class FakePlanningRepository implements PlanningRepository {
  FakePlanningRepository({DateTime? today}) : today = today ?? DateTime.now();

  final DateTime today;
  final List<BudgetProgress> budgets = [];
  late final List<DebtModel> debts = [
    DebtModel(id: 'd1', type: DebtType.lend, personName: 'Lan', amount: 500000, dueDate: today),
    DebtModel(
        id: 'd2', type: DebtType.borrow, personName: 'Minh', amount: 2000000, dueDate: today.add(const Duration(days: 10))),
  ];
  final List<GoalModel> goals = [
    const GoalModel(id: 'g1', name: 'Mua MacBook', targetAmount: 1000000, savedAmount: 800000),
  ];
  final List<(String, int?, bool)> settleCalls = [];
  int _ids = 0;

  @override
  Future<List<BudgetProgress>> fetchBudgets(DateTime month) async => List.of(budgets);

  @override
  Future<void> saveBudget({required DateTime month, String? categoryId, required int limitAmount}) async {
    budgets.removeWhere((b) => b.categoryId == categoryId);
    budgets.add(BudgetProgress(
      id: 'b${_ids++}',
      categoryId: categoryId,
      categoryName: categoryId == null ? null : 'Ăn uống',
      limitAmount: limitAmount,
      spent: 120000,
    ));
  }

  @override
  Future<void> deleteBudget(String id) async => budgets.removeWhere((b) => b.id == id);

  @override
  Future<int> copyBudgetsFromPreviousMonth(DateTime month) async => 0;

  @override
  Future<List<DebtModel>> fetchDebts() async => List.of(debts);

  @override
  Future<void> saveDebt(DebtModel debt) async {
    final saved = DebtModel(
      id: debt.id ?? 'd${_ids++}',
      type: debt.type,
      personName: debt.personName,
      phone: debt.phone,
      amount: debt.amount,
      dueDate: debt.dueDate,
      note: debt.note,
    );
    final i = debts.indexWhere((d) => d.id == saved.id);
    if (i < 0) {
      debts.add(saved);
    } else {
      debts[i] = saved;
    }
  }

  @override
  Future<void> deleteDebt(String id) async => debts.removeWhere((d) => d.id == id);

  @override
  Future<void> settleDebt(String id, {int? amount, bool recordTransaction = false, DateTime? paidAt, String? note, String? walletId}) async {
    settleCalls.add((id, amount, recordTransaction));
    final i = debts.indexWhere((d) => d.id == id);
    final d = debts[i];
    final paid = d.paidAmount + (amount ?? d.remaining);
    debts[i] = DebtModel(
      id: d.id,
      type: d.type,
      personName: d.personName,
      amount: d.amount,
      paidAmount: paid,
      dueDate: d.dueDate,
      isSettled: paid >= d.amount,
    );
  }

  @override
  Future<void> updateDebtPayment(String id, {required int amount, required DateTime paidAt,
    String? note, required bool recordTransaction, String? walletId}) async => throw UnimplementedError();
  @override
  Future<void> undoDebtPayment(String id) async => throw UnimplementedError();

  @override
  Future<List<GoalModel>> fetchGoals() async => List.of(goals);

  @override
  Future<void> saveGoal(GoalModel goal) async =>
      goals.add(GoalModel(id: 'g${_ids++}', name: goal.name, targetAmount: goal.targetAmount, icon: goal.icon));

  @override
  Future<void> setGoalSaved(String id, int savedAmount) async {
    final i = goals.indexWhere((g) => g.id == id);
    final g = goals[i];
    goals[i] = GoalModel(
      id: g.id,
      name: g.name,
      targetAmount: g.targetAmount,
      savedAmount: savedAmount,
      isCompleted: savedAmount >= g.targetAmount,
    );
  }

  @override
  Future<void> deleteGoal(String id) async => goals.removeWhere((g) => g.id == id);
}

class FakeDebtReminders implements DebtReminders {
  List<DebtModel> lastSynced = const [];

  @override
  Future<void> sync(List<DebtModel> debts) async => lastSynced = debts;
}

class FakeAppLock implements AppLock {
  FakeAppLock({this.enabled = false, this.passes = true});

  bool enabled;
  bool passes;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return passes;
  }
}

class FakeAdvisorRepository implements AdvisorRepository {
  int analyzeCalls = 0;

  @override
  Future<AdvisorReport> analyze({required int range}) async {
    analyzeCalls++;
    return AdvisorReport.fromJson({
      'period': {'from': '2026-09-25', 'to': '2026-10-24', 'range': range},
      'totals': {'income': 15000000, 'expense': 4000000, 'previousIncome': 0, 'previousExpense': 3200000, 'expenseChange': 25},
      'summary': 'Tháng này bạn chi nhiều hơn cho ăn uống.',
      'insights': [
        {'category': 'Ăn uống', 'total': 3000000, 'change': 40, 'advice': 'Nên giảm khoảng 500k'},
      ],
      'forecast': {'nextMonth': 4200000, 'baseline': 4000000, 'riskCategories': ['Ăn uống']},
      'quota': {'used': 1, 'limit': 10},
    });
  }

  @override
  Future<PeriodSummary> fetchPeriod({required DateTime from, required DateTime to}) async {
    final today = DateTime(to.year, to.month, to.day);
    return PeriodSummary(
      income: 15000000,
      expense: 4000000,
      byCategory: const [
        CategoryTotal(name: 'Ăn uống', total: 3000000, icon: 'restaurant', color: '#FF7043', count: 40),
        CategoryTotal(name: 'Di chuyển', total: 1000000, icon: 'local_gas_station', color: '#42A5F5', count: 8),
      ],
      byDay: [DailyTotal(day: today, expense: 150000)],
    );
  }
}
