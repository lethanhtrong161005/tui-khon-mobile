import '../../features/home/data/wallet_repository.dart';
import '../../features/home/models/category_model.dart';
import '../../features/home/models/monthly_summary.dart';
import '../../features/home/models/notification_model.dart';
import '../../features/home/models/transaction_model.dart';
import '../../features/home/models/wallet_model.dart';
import '../utils/id_generator.dart';
import 'local_store.dart';

/// UI reads only SQLite, including totals and balances. Cloud latency never
/// blocks a financial edit. The outbox is managed by LocalStore.
class OfflineWalletRepository implements WalletRepository {
  OfflineWalletRepository(this.store);
  final LocalStore store;
  static DateTime _vn(DateTime instant) => instant.toUtc().add(const Duration(hours: 7));

  @override
  Future<List<CategoryModel>> fetchCategories() async =>
      (await store.rows('categories')).map(CategoryModel.fromJson).toList()..sort((a, b) => a.name.compareTo(b.name));
  @override
  Future<List<WalletModel>> fetchWallets() async {
    final transactions = await store.rows('transactions');
    return (await store.rows('wallets')).map((w) {
      final balance = transactions.where((t) => t['wallet_id'] == w['id']).fold<int>(
          (w['initial_balance'] as num? ?? 0).toInt(),
          (sum, t) => sum + (t['type'] == 'income' ? 1 : -1) * (t['amount'] as num).toInt());
      return WalletModel.fromJson({...w, 'wallet_id': w['id'], 'balance': balance});
    }).toList();
  }

  Future<List<TransactionModel>> allTransactions() async {
    final categories = {for (final c in await fetchCategories()) c.id: c};
    final wallets = {for (final w in await fetchWallets()) w.id: w};
    return (await store.rows('transactions'))
        .map((r) => TransactionModel.fromJson(r, categories: categories, wallets: wallets))
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  @override
  Future<List<TransactionModel>> fetchRecentTransactions({int limit = 10}) async =>
      (await allTransactions()).take(limit).toList();
  @override
  Future<List<TransactionModel>> fetchTransactions(TransactionFilter filter, {int offset = 0, int limit = 50}) async =>
      (await allTransactions())
          .where((t) =>
              !_vn(t.occurredAt).isBefore(DateTime.utc(filter.month.year, filter.month.month)) &&
              _vn(t.occurredAt).isBefore(DateTime.utc(filter.month.year, filter.month.month + 1)) &&
              (filter.type == null || filter.type == t.type) &&
              (filter.categoryId == null || filter.categoryId == t.categoryId) &&
              (filter.walletId == null || filter.walletId == t.walletId) &&
              (filter.search.isEmpty || (t.note ?? '').toLowerCase().contains(filter.search.toLowerCase())))
          .skip(offset)
          .take(limit)
          .toList();

  @override
  Future<MonthlySummary> fetchMonthlySummary({DateTime? month}) async {
    final d = month ?? DateTime.now().toUtc().add(const Duration(hours: 7));
    final start = DateTime.utc(d.year, d.month),
        end = DateTime.utc(d.year, d.month + 1),
        previous = DateTime.utc(d.year, d.month - 1);
    final tx = await allTransactions();
    final current = tx.where((t) => !_vn(t.occurredAt).isBefore(start) && _vn(t.occurredAt).isBefore(end)).toList();
    final prior = tx.where((t) => !_vn(t.occurredAt).isBefore(previous) && _vn(t.occurredAt).isBefore(start));
    int sum(Iterable<TransactionModel> rows, TransactionType type) =>
        rows.where((t) => t.type == type).fold(0, (n, t) => n + t.amount);
    final categories = {for (final c in await fetchCategories()) c.id: c};
    final budgets = (await store.rows('budgets'))
        .where((b) => (b['month'] as String).startsWith('${d.year}-${d.month.toString().padLeft(2, '0')}'))
        .map((b) => BudgetProgress(
            id: b['id'] as String,
            categoryId: b['category_id'] as String?,
            categoryName: categories[b['category_id']]?.name,
            limitAmount: (b['limit_amount'] as num).toInt(),
            spent: sum(current.where((t) => b['category_id'] == null || t.categoryId == b['category_id']),
                TransactionType.expense)))
        .toList();
    final days = <String, List<TransactionModel>>{};
    for (final t in current) {
      final key = _vn(t.occurredAt).toIso8601String().substring(0, 10);
      (days[key] ??= []).add(t);
    }
    return MonthlySummary(
        month: start,
        income: sum(current, TransactionType.income),
        expense: sum(current, TransactionType.expense),
        previousIncome: sum(prior, TransactionType.income),
        previousExpense: sum(prior, TransactionType.expense),
        totalBalance: (await fetchWallets()).fold(0, (n, w) => n + w.balance),
        budgets: budgets,
        byDay: [
          for (final e in days.entries)
            DailyTotal(
                day: DateTime.parse(e.key),
                income: sum(e.value, TransactionType.income),
                expense: sum(e.value, TransactionType.expense))
        ]);
  }

  @override
  Future<void> addTransaction(TransactionDraft draft) =>
      store.put('transactions', {'id': newUuidV4(), ...draft.toInsertJson()});
  Future<void> addTransactions(List<TransactionDraft> drafts) => store.writeBatch([
        for (final d in drafts) LocalMutation('transactions', {'id': newUuidV4(), ...d.toInsertJson()})
      ]);
  @override
  Future<void> updateTransaction(String id, TransactionDraft draft) async {
    final linked = (await store.rows('debt_payments')).any((p) => p['transaction_id'] == id);
    if (linked) throw StateError('Hãy sửa lần trả nợ trong Sổ nợ để cập nhật giao dịch liên kết');
    final occurrence = (await store.rows('payable_occurrences')).where((p) => p['transaction_id'] == id).firstOrNull;
    if (occurrence != null) {
      if (draft.type != TransactionType.expense) throw StateError('Khoản phải trả phải là một khoản chi');
      await store.put('payable_occurrences', {
        ...occurrence,
        'amount': draft.amount,
        'wallet_id': draft.walletId,
        'category_id': draft.categoryId,
        'note': draft.note,
        'paid_at': (draft.occurredAt ?? DateTime.now()).toUtc().toIso8601String()
      });
      return;
    }
    await store.put('transactions', {'id': id, ...draft.toInsertJson()});
  }

  @override
  Future<void> deleteTransaction(String id) async {
    if ((await store.rows('debt_payments')).any((p) => p['transaction_id'] == id))
      throw StateError('Hãy hoàn tác lần trả nợ trong Sổ nợ');
    final occurrence = (await store.rows('payable_occurrences')).where((p) => p['transaction_id'] == id).firstOrNull;
    if (occurrence != null) {
      await store.put('payable_occurrences', {...occurrence, 'status': 'pending'});
      return;
    }
    await store.remove('transactions', id);
  }

  @override
  Future<void> saveCategory(CategoryModel category) =>
      store.put('categories', {'id': category.id.isEmpty ? newUuidV4() : category.id, ...category.toJson()});
  @override
  Future<void> deleteCategory(String id) => store.remove('categories', id);
  @override
  Future<void> saveWallet(WalletModel wallet) => store.put('wallets',
      {'id': wallet.id.isEmpty ? newUuidV4() : wallet.id, 'is_archived': wallet.isArchived, ...wallet.toJson()});
  @override
  Future<bool> removeWallet(String id) async {
    final used = (await store.rows('transactions')).any((t) => t['wallet_id'] == id);
    if (used) {
      await store.put('wallets', {'id': id, 'is_archived': true});
    } else {
      await store.remove('wallets', id);
    }
    return used;
  }

  @override
  Future<List<NotificationModel>> fetchNotifications({int limit = 30}) async =>
      (await store.rows('notifications')).map(NotificationModel.fromJson).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  @override
  Future<void> markAllNotificationsRead() async => store.writeBatch([
        for (final n in await store.rows('notifications'))
          if (n['is_read'] != true) LocalMutation('notifications', {...n, 'is_read': true})
      ]);
}
