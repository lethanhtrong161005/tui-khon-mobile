import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../models/user_profile.dart';

/// Wraps Supabase Auth (email + 6-digit OTP, Google) for the auth screens.
/// Session persistence and token refresh are handled by supabase_flutter.
class AuthRepository {
  AuthRepository(this._client, {Future<void> Function()? beforeSignOut}) : _beforeSignOut = beforeSignOut;

  final SupabaseClient _client;
  final Future<void> Function()? _beforeSignOut;
  bool _googleInitialized = false;

  GoTrueClient get _auth => _client.auth;

  Future<void> signInWithPassword({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  /// Creates the account; Supabase emails a 6-digit code.
  /// Returns true when the code must be verified before signing in.
  Future<bool> signUp({required String email, required String password, required String displayName}) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
    // With email confirmation on, Supabase hides "already registered" by
    // returning a user without identities instead of an error.
    final identities = response.user?.identities;
    if (identities != null && identities.isEmpty) {
      throw const AuthException('Email đã được đăng ký', code: 'user_already_exists');
    }
    return response.session == null;
  }

  Future<void> verifySignupOtp({required String email, required String token}) async {
    await _auth.verifyOTP(email: email, token: token, type: OtpType.signup);
  }

  Future<void> resendSignupOtp(String email) async {
    await _auth.resend(email: email, type: OtpType.signup);
  }

  /// Emails a 6-digit password reset code (no error for unknown emails).
  Future<void> sendPasswordResetOtp(String email) async {
    await _auth.resetPasswordForEmail(email);
  }

  /// Verifying the recovery code signs the user in; follow with [updatePassword].
  Future<void> verifyRecoveryOtp({required String email, required String token}) async {
    await _auth.verifyOTP(email: email, token: token, type: OtpType.recovery);
  }

  Future<void> updatePassword(String password) async {
    await _auth.updateUser(UserAttributes(password: password));
  }

  /// Native Google Sign-In → ID token → Supabase session.
  Future<void> signInWithGoogle() async {
    if (!Env.isGoogleConfigured) {
      throw StateError('Đăng nhập Google chưa được cấu hình (thiếu GOOGLE_WEB_CLIENT_ID)');
    }
    final google = GoogleSignIn.instance;
    if (!_googleInitialized) {
      final isIos = defaultTargetPlatform == TargetPlatform.iOS;
      await google.initialize(
        clientId: isIos && Env.googleIosClientId.isNotEmpty ? Env.googleIosClientId : null,
        serverClientId: Env.googleWebClientId,
      );
      _googleInitialized = true;
    }

    final account = await google.authenticate(scopeHint: const ['email', 'profile']);
    final idToken = account.authentication.idToken;
    if (idToken == null) throw StateError('Không lấy được thông tin đăng nhập Google');

    await _auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
  }

  Future<void> signOut() async {
    await _beforeSignOut?.call();
    await _auth.signOut();
    if (_googleInitialized) await GoogleSignIn.instance.signOut();
  }

  Future<UserProfile?> fetchProfile() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select('id, email, display_name, avatar_url, phone')
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : UserProfile.fromJson(row);
  }

  /// Updates the editable profile columns (RLS + column grants allow nothing else).
  Future<void> updateProfile({required String displayName, String? phone}) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) throw StateError('Bạn cần đăng nhập');
    final trimmedPhone = phone?.trim();
    await _client.from('profiles').update({
      'display_name': displayName.trim(),
      'phone': (trimmedPhone == null || trimmedPhone.isEmpty) ? null : trimmedPhone,
    }).eq('id', userId);
  }

  /// Uploads a new avatar to the public `avatars` bucket (`{uid}/avatar.<ext>`,
  /// overwritten each time) and stores its URL on the profile.
  Future<String> uploadAvatar(Uint8List bytes, {String extension = 'jpg', String mimeType = 'image/jpeg'}) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) throw StateError('Bạn cần đăng nhập');
    final path = '$userId/avatar.$extension';
    final bucket = _client.storage.from('avatars');
    await bucket.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mimeType, upsert: true));
    // Same path every time: the version query makes image caches fetch the new file.
    final url = '${bucket.getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('profiles').update({'avatar_url': url}).eq('id', userId);
    return url;
  }
}
