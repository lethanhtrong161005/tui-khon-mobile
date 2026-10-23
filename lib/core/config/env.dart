/// Compile-time configuration injected with `--dart-define-from-file=.env`.
///
/// Example:
///   flutter run --dart-define-from-file=.env
class Env {
  Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Web OAuth client ID — passed to Google Sign-In as `serverClientId`
  /// so the returned ID token is accepted by Supabase Auth.
  static const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// iOS OAuth client ID (also needs its reversed form as a URL scheme in Info.plist).
  static const String googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool get isSupabaseConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get isGoogleConfigured => googleWebClientId.isNotEmpty;
}
