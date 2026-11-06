import 'package:tui_khon_mobile/core/utils/id_generator.dart';
import 'package:tui_khon_mobile/features/home/models/category_model.dart';
import 'package:tui_khon_mobile/features/home/models/monthly_summary.dart';
import 'package:tui_khon_mobile/features/home/models/notification_model.dart';
import 'package:tui_khon_mobile/features/home/models/transaction_model.dart';
import 'package:tui_khon_mobile/features/home/models/wallet_model.dart';
import 'package:tui_khon_mobile/features/home/data/wallet_repository.dart';

/// In-memory WalletRepository with seed data that mirrors the design mockups.
/// Works without any backend — used by widget tests and for UI work offline
/// (override `walletRepositoryProvider` with it).
class LocalWalletRepository implements WalletRepository {
  LocalWalletRepository({DateTime? now}) : _now = now ?? DateTime.now() {
    _seed();
  }

  final DateTime _now;
  final List<CategoryModel> _categories = [];
  final List<WalletModel> _wallets = [];
  final List<TransactionModel> _transactions = [];
  final List<NotificationModel> _notifications = [];
  int _monthlyBudgetLimit = 22000000;

  void _seed() {
    _categories.addAll(const [
      CategoryModel(id: 'cat-food', name: 'Ăn uống', type: TransactionType.expense, icon: 'restaurant', color: '#FF7043'),
      CategoryModel(id: 'cat-move', name: 'Di chuyển', type: TransactionType.expense, icon: 'local_gas_station', color: '#42A5F5'),
      CategoryModel(id: 'cat-home', name: 'Nhà ở & Tiện ích', type: TransactionType.expense, icon: 'home_work', color: '#8D6E63'),
      CategoryModel(id: 'cat-other', name: 'Chi tiêu khác', type: TransactionType.expense, icon: 'payments', color: '#BDBDBD'),
      CategoryModel(id: 'cat-salary', name: 'Lương', type: TransactionType.income, icon: 'payments', color: '#4CAF50'),
      CategoryModel(id: 'cat-income-other', name: 'Thu nhập khác', type: TransactionType.income, icon: 'celebration', color: '#607D8B'),
    ]);
    _wallets.addAll(const [
      WalletModel(id: 'wallet-cash', name: 'Tiền mặt', type: 'cash', icon: 'payments', initialBalance: 5000000),
      WalletModel(id: 'wallet-momo', name: 'Ví MoMo', type: 'ewallet', initialBalance: 2000000),
      WalletModel(id: 'wallet-vcb', name: 'Vietcombank', type: 'bank', icon: 'account_balance', initialBalance: 30000000),
    ]);
    final seed = [
      ('Ăn phở Thìn Lò Đúc', 'cat-food', 'wallet-cash', 65000, TransactionType.expense, TransactionSource.ai, const Duration(minutes: 30)),
      ('Highlands Coffee', 'cat-food', 'wallet-momo', 55000, TransactionType.expense, TransactionSource.receipt, const Duration(hours: 3)),
      ('Đổ xăng Petrolimex', 'cat-move', 'wallet-vcb', 80000, TransactionType.expense, TransactionSource.voice, const Duration(days: 1)),
      ('Tạm ứng lương', 'cat-salary', 'wallet-vcb', 15000000, TransactionType.income, TransactionSource.manual, const Duration(days: 2)),
      ('Tiền thuê căn hộ', 'cat-home', 'wallet-vcb', 4500000, TransactionType.expense, TransactionSource.manual, const Duration(days: 4)),
    ];
    for (final (note, categoryId, walletId, amount, type, source, ago) in seed) {
      _transactions.add(_build(
        TransactionDraft(
          type: type,
          amount: amount,
          walletId: walletId,
          categoryId: categoryId,
          note: note,
          occurredAt: _now.subtract(ago),
          source: source,
        ),
      ));
    }
    _notifications.add(NotificationModel(
      id: 'notif-1',
      type: 'budget',
      title: 'Sắp chạm ngân sách',
      message: 'Bạn đã dùng 82% ngân sách "Ăn uống" tháng này.',
      createdAt: _now.subtract(const Duration(minutes: 5)),
    ));
  }

  TransactionModel _build(TransactionDraft draft) {
    final category = _categories.where((c) => c.id == draft.categoryId).firstOrNull;
    final wallet = _wallets.where((w) => w.id == draft.walletId).firstOrNull;
    return TransactionModel(
      id: newUuidV4(),
      type: draft.type,
      amount: draft.amount,
      walletId: draft.walletId!,
      walletName: wallet?.name,
      categoryId: draft.categoryId,
      categoryName: category?.name,
      categoryIcon: category?.icon,
      categoryColor: category?.color,
      note: draft.note,
      occurredAt: draft.occurredAt ?? DateTime.now(),
      source: draft.source,
      receiptPath: draft.receiptPath,
    );
  }

  set monthlyBudgetLimit(int value) => _monthlyBudgetLimit = value;

  @override
  Future<List<CategoryModel>> fetchCategories() async => List.unmodifiable(_categories);

  @override
  Future<List<WalletModel>> fetchWallets() async {
    return _wallets.map((w) {
      final delta = _transactions.where((t) => t.walletId == w.id).fold<int>(0, (sum, t) => sum + t.signedAmount);
      return WalletModel(
        id: w.id,
        name: w.name,
        type: w.type,
        icon: w.icon,
        color: w.color,
        initialBalance: w.initialBalance,
        isArchived: w.isArchived,
        balance: w.initialBalance + delta,
      );
    }).toList();
  }

  @override
  Future<MonthlySummary> fetchMonthlySummary({DateTime? month}) async {
    final m = month ?? _now;
    final start = DateTime(m.year, m.month);
    final inMonth = _transactions.where((t) => t.occurredAt.year == start.year && t.occurredAt.month == start.month);
    final income = inMonth.where((t) => t.isIncome).fold<int>(0, (s, t) => s + t.amount);
    final expense = inMonth.where((t) => !t.isIncome).fold<int>(0, (s, t) => s + t.amount);
    final wallets = await fetchWallets();
    final byDay = <DateTime, DailyTotal>{};
    for (final t in inMonth) {
      final day = DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
      final current = byDay[day] ?? DailyTotal(day: day);
      byDay[day] = DailyTotal(
        day: day,
        income: current.income + (t.isIncome ? t.amount : 0),
        expense: current.expense + (t.isIncome ? 0 : t.amount),
      );
    }
    return MonthlySummary(
      month: start,
      income: income,
      expense: expense,
      totalBalance: wallets.fold<int>(0, (s, w) => s + w.balance),
      budgets: [BudgetProgress(id: 'budget-total', limitAmount: _monthlyBudgetLimit, spent: expense)],
      byDay: byDay.values.toList(),
    );
  }

  @override
  Future<List<TransactionModel>> fetchRecentTransactions({int limit = 10}) async {
    final sorted = [..._transactions]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<TransactionModel>> fetchTransactions(TransactionFilter filter, {int offset = 0, int limit = 50}) async {
    final search = filter.search.trim().toLowerCase();
    final matches = _transactions.where((t) =>
        !t.occurredAt.isBefore(filter.start) &&
        t.occurredAt.isBefore(filter.end) &&
        (filter.type == null || t.type == filter.type) &&
        (filter.categoryId == null || t.categoryId == filter.categoryId) &&
        (filter.walletId == null || t.walletId == filter.walletId) &&
        (search.isEmpty || (t.note ?? '').toLowerCase().contains(search)));
    final sorted = matches.toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return sorted.skip(offset).take(limit).toList();
  }

  @override
  Future<void> updateTransaction(String id, TransactionDraft draft) async {
    final i = _transactions.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final updated = _build(draft);
    _transactions[i] = TransactionModel(
      id: id,
      type: updated.type,
      amount: updated.amount,
      walletId: updated.walletId,
      walletName: updated.walletName,
      categoryId: updated.categoryId,
      categoryName: updated.categoryName,
      categoryIcon: updated.categoryIcon,
      categoryColor: updated.categoryColor,
      note: updated.note,
      occurredAt: updated.occurredAt,
      source: updated.source,
      receiptPath: updated.receiptPath,
    );
  }

  @override
  Future<void> addTransaction(TransactionDraft draft) async {
    if (!draft.isValid) throw StateError('Giao dịch chưa hợp lệ');
    _transactions.add(_build(draft));
  }

  @override
  Future<void> deleteTransaction(String id) async => _transactions.removeWhere((t) => t.id == id);

  @override
  Future<List<NotificationModel>> fetchNotifications({int limit = 30}) async =>
      _notifications.take(limit).toList();

  @override
  Future<void> saveCategory(CategoryModel category) async {
    final i = _categories.indexWhere((c) => c.id == category.id);
    final saved = CategoryModel(
      id: category.id.isEmpty ? newUuidV4() : category.id,
      name: category.name,
      type: category.type,
      icon: category.icon,
      color: category.color,
    );
    if (i < 0) {
      _categories.add(saved);
    } else {
      _categories[i] = saved;
    }
  }

  @override
  Future<void> deleteCategory(String id) async => _categories.removeWhere((c) => c.id == id);

  @override
  Future<void> saveWallet(WalletModel wallet) async {
    final i = _wallets.indexWhere((w) => w.id == wallet.id);
    final saved = WalletModel(
      id: wallet.id.isEmpty ? newUuidV4() : wallet.id,
      name: wallet.name,
      type: wallet.type,
      icon: wallet.icon,
      color: wallet.color,
      initialBalance: wallet.initialBalance,
    );
    if (i < 0) {
      _wallets.add(saved);
    } else {
      _wallets[i] = saved;
    }
  }

  @override
  Future<bool> removeWallet(String id) async {
    if (_transactions.any((t) => t.walletId == id)) {
      final i = _wallets.indexWhere((w) => w.id == id);
      final w = _wallets[i];
      _wallets[i] = WalletModel(
        id: w.id,
        name: w.name,
        type: w.type,
        icon: w.icon,
        color: w.color,
        initialBalance: w.initialBalance,
        isArchived: true,
      );
      return true;
    }
    _wallets.removeWhere((w) => w.id == id);
    return false;
  }

  @override
  Future<void> markAllNotificationsRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      _notifications[i] = NotificationModel(
        id: n.id,
        type: n.type,
        title: n.title,
        message: n.message,
        createdAt: n.createdAt,
        isRead: true,
      );
    }
  }
}
