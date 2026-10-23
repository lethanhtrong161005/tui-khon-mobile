import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/id_generator.dart';
import '../models/category_model.dart';
import '../models/monthly_summary.dart';
import '../models/notification_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import 'wallet_repository.dart';

/// WalletRepository backed by Supabase. Row Level Security scopes every query
/// to the signed-in user, so no `user_id` filter is needed here.
class SupabaseWalletRepository implements WalletRepository {
  SupabaseWalletRepository(this._client);

  final SupabaseClient _client;

  static const _transactionColumns =
      'id, type, amount, note, occurred_at, source, receipt_path, wallet_id, category_id';

  @override
  Future<List<CategoryModel>> fetchCategories() async {
    final rows = await _client
        .from('categories')
        .select('id, name, type, icon, color, is_default')
        .order('name');
    return rows.map(CategoryModel.fromJson).toList();
  }

  @override
  Future<List<WalletModel>> fetchWallets() async {
    final rows = await _client.from('wallet_balances').select().order('created_at');
    return rows.map(WalletModel.fromJson).toList();
  }

  @override
  Future<MonthlySummary> fetchMonthlySummary({DateTime? month}) async {
    final data = await _client.rpc(
      'get_monthly_summary',
      params: {'p_month': month == null ? null : _isoDate(month)},
    );
    return MonthlySummary.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<List<TransactionModel>> fetchRecentTransactions({int limit = 10}) async {
    final (rows, categories, wallets) = await (
      _client.from('transactions').select(_transactionColumns).order('occurred_at', ascending: false).limit(limit),
      fetchCategories(),
      fetchWallets(),
    ).wait;

    final categoryById = {for (final c in categories) c.id: c};
    final walletById = {for (final w in wallets) w.id: w};
    return rows
        .map((row) => TransactionModel.fromJson(row, categories: categoryById, wallets: walletById))
        .toList();
  }

  @override
  Future<List<TransactionModel>> fetchTransactions(TransactionFilter filter, {int offset = 0, int limit = 50}) async {
    var query = _client
        .from('transactions')
        .select(_transactionColumns)
        .gte('occurred_at', filter.start.toUtc().toIso8601String())
        .lt('occurred_at', filter.end.toUtc().toIso8601String());
    if (filter.type != null) query = query.eq('type', filter.type!.name);
    if (filter.categoryId != null) query = query.eq('category_id', filter.categoryId!);
    if (filter.walletId != null) query = query.eq('wallet_id', filter.walletId!);
    final search = filter.search.trim().replaceAll(RegExp(r'[%_,()]'), ' ');
    if (search.isNotEmpty) query = query.ilike('note', '%$search%');

    final (rows, categories, wallets) = await (
      query.order('occurred_at', ascending: false).range(offset, offset + limit - 1),
      fetchCategories(),
      fetchWallets(),
    ).wait;
    final categoryById = {for (final c in categories) c.id: c};
    final walletById = {for (final w in wallets) w.id: w};
    return rows
        .map((row) => TransactionModel.fromJson(row, categories: categoryById, wallets: walletById))
        .toList();
  }

  @override
  Future<void> updateTransaction(String id, TransactionDraft draft) async {
    await _client.from('transactions').update(draft.toInsertJson()).eq('id', id);
  }

  @override
  Future<void> addTransaction(TransactionDraft draft) async {
    await _client.from('transactions').insert(draft.toInsertJson(clientId: newUuidV4()));
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }

  @override
  Future<List<NotificationModel>> fetchNotifications({int limit = 30}) async {
    final rows = await _client
        .from('notifications')
        .select('id, type, title, message, is_read, created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(NotificationModel.fromJson).toList();
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _client.from('notifications').update({'is_read': true}).eq('is_read', false);
  }

  @override
  Future<void> saveCategory(CategoryModel category) async {
    if (category.id.isEmpty) {
      await _client.from('categories').insert(category.toJson());
    } else {
      await _client.from('categories').update(category.toJson()).eq('id', category.id);
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }

  @override
  Future<void> saveWallet(WalletModel wallet) async {
    if (wallet.id.isEmpty) {
      await _client.from('wallets').insert(wallet.toJson());
    } else {
      await _client.from('wallets').update(wallet.toJson()).eq('id', wallet.id);
    }
  }

  @override
  Future<bool> removeWallet(String id) async {
    final used = await _client.from('transactions').select('id').eq('wallet_id', id).limit(1);
    if (used.isEmpty) {
      await _client.from('wallets').delete().eq('id', id);
      return false;
    }
    await _client.from('wallets').update({'is_archived': true}).eq('id', id);
    return true;
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
