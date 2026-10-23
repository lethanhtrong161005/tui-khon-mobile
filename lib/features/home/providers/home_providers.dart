import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/supabase_wallet_repository.dart';
import '../data/wallet_repository.dart';
import '../models/category_model.dart';
import '../models/monthly_summary.dart';
import '../models/notification_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

/// Recreated whenever the signed-in user changes, which also resets every
/// provider below so one account never sees another account's cached data.
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  ref.watch(currentUserIdProvider);
  return SupabaseWalletRepository(ref.watch(supabaseClientProvider));
});

final categoriesProvider = FutureProvider.autoDispose<List<CategoryModel>>(
  (ref) => ref.watch(walletRepositoryProvider).fetchCategories(),
);

final walletsProvider = FutureProvider.autoDispose<List<WalletModel>>(
  (ref) => ref.watch(walletRepositoryProvider).fetchWallets(),
);

final monthlySummaryProvider = FutureProvider.autoDispose<MonthlySummary>(
  (ref) => ref.watch(walletRepositoryProvider).fetchMonthlySummary(),
);

final recentTransactionsProvider = FutureProvider.autoDispose<List<TransactionModel>>(
  (ref) => ref.watch(walletRepositoryProvider).fetchRecentTransactions(limit: 10),
);

final notificationsProvider = FutureProvider.autoDispose<List<NotificationModel>>(
  (ref) => ref.watch(walletRepositoryProvider).fetchNotifications(),
);

final unreadNotificationCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(notificationsProvider).valueOrNull?.where((n) => !n.isRead).length ?? 0,
);

/// The "khoản nợ đến hạn" prompt is shown once per app session.
final dueDebtsPromptShownProvider = StateProvider<bool>((ref) => false);

extension WalletDataRefresh on WidgetRef {
  /// Reloads everything a new / deleted transaction can change
  /// (balances, monthly totals, budget alerts created by the database trigger).
  void refreshWalletData() {
    invalidate(monthlySummaryProvider);
    invalidate(recentTransactionsProvider);
    invalidate(walletsProvider);
    invalidate(notificationsProvider);
  }

  /// Saves [draft] and refreshes the dashboard.
  Future<void> saveTransaction(TransactionDraft draft) async {
    await read(walletRepositoryProvider).addTransaction(draft);
    refreshWalletData();
  }
}
