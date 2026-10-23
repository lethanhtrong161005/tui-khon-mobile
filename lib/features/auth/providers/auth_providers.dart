import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_repository.dart';
import '../models/user_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

/// Profile of the signed-in user (display name, avatar, plan).
final profileProvider = FutureProvider.autoDispose<UserProfile?>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(authRepositoryProvider).fetchProfile();
});

/// True between verifying a password-reset code (which signs the user in)
/// and saving the new password. While set, [AuthGate] keeps the auth flow
/// on screen instead of jumping to the dashboard.
final passwordRecoveryPendingProvider = StateProvider<bool>((ref) => false);
