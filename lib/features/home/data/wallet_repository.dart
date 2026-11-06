import '../models/category_model.dart';
import '../models/monthly_summary.dart';
import '../models/notification_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

/// Reads and writes the user's notebook. The production implementation uses
/// durable SQLite and an outbox; test implementations can stay in memory.
abstract class WalletRepository {
  Future<List<CategoryModel>> fetchCategories();

  /// All wallets with live balances (archived ones included, so old
  /// transactions can still show their wallet name).
  Future<List<WalletModel>> fetchWallets();

  /// Totals of [month] (defaults to the current month in Vietnam time).
  Future<MonthlySummary> fetchMonthlySummary({DateTime? month});

  Future<List<TransactionModel>> fetchRecentTransactions({int limit = 10});

  /// One page of the history screen, newest first.
  Future<List<TransactionModel>> fetchTransactions(TransactionFilter filter, {int offset = 0, int limit = 50});

  Future<void> addTransaction(TransactionDraft draft);

  Future<void> updateTransaction(String id, TransactionDraft draft);

  Future<void> deleteTransaction(String id);

  Future<List<NotificationModel>> fetchNotifications({int limit = 30});

  Future<void> markAllNotificationsRead();

  /// Insert when [category.id] is empty, otherwise update.
  Future<void> saveCategory(CategoryModel category);

  /// Old transactions keep existing as "Chưa phân loại"; budgets of the category are removed.
  Future<void> deleteCategory(String id);

  /// Insert when [wallet.id] is empty, otherwise update.
  Future<void> saveWallet(WalletModel wallet);

  /// Deletes a wallet without transactions; otherwise archives it (hidden from pickers).
  /// Returns true when it was archived instead of deleted.
  Future<bool> removeWallet(String id);
}
