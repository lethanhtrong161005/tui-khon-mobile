import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../../core/offline/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../reminders/data/reminder_scheduler.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_repository.dart';
import '../models/user_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider), beforeSignOut: () async {
    ref.read(offlineAccountIdProvider.notifier).state = null;
    await (await SharedPreferences.getInstance()).remove('offline_account_id');
    for (final group in ['debts', 'payables', 'diary', 'report']) {
      try {
        await ref.read(reminderSchedulerProvider).replace(group, []);
      } catch (_) {/* No notifications on unsupported devices. */}
    }
  }),
);

/// Profile of the signed-in user (display name, avatar, plan).
final profileProvider = FutureProvider.autoDispose<UserProfile?>((ref) async {
  ref.watch(currentUserIdProvider);
  final store = ref.watch(localStoreProvider);
  final repository = ref.watch(authRepositoryProvider);
  try {
    final profile = await repository.fetchProfile();
    if (profile != null) {
      await store?.setMeta(
          'profile',
          jsonEncode({
            'id': profile.id,
            'email': profile.email,
            'display_name': profile.displayName,
            'avatar_url': profile.avatarUrl,
            'phone': profile.phone
          }));
      return profile;
    }
  } catch (_) {
    // A transient network error must not remove the cached profile.
  }
  final cached = await store?.meta('profile');
  return cached == null ? null : UserProfile.fromJson((jsonDecode(cached) as Map).cast<String, dynamic>());
});

/// True between verifying a password-reset code (which signs the user in)
/// and saving the new password. While set, [AuthGate] keeps the auth flow
/// on screen instead of jumping to the dashboard.
final passwordRecoveryPendingProvider = StateProvider<bool>((ref) => false);
