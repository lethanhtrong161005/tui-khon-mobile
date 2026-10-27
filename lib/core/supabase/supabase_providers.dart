import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Supabase client created in `main()` by `Supabase.initialize`.
/// Overridden in tests.
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// Emits on sign in, sign out, token refresh, password recovery...
final authStateChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);

/// The current session (null when signed out). Re-evaluated on every auth event.
final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentSession;
});

/// Restored only after a prior authenticated use. Explicit logout clears it;
/// refresh failures leave the account's offline notebook available.
final offlineAccountIdProvider = StateProvider<String?>((ref) => null);

/// Id of the signed-in user. Data providers watch this so that they reload
/// when the account changes, but not on every token refresh.
final currentUserIdProvider = Provider<String?>((ref) => ref.watch(sessionProvider)?.user.id ?? ref.watch(offlineAccountIdProvider));
