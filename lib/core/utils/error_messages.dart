import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_l10n.dart';
import 'app_failure.dart';
import 'failure_localization.dart';

/// Non-UI callers keep Vietnamese diagnostics. UI always passes its context.
String friendlyError(Object error, {BuildContext? context}) {
  final l = appL10n(context);
  if (error is CodedFailure) return codedFailureMessage(context, error);
  if (error is SocketException ||
      error is TimeoutException ||
      error is AuthRetryableFetchException) return l.errorNetwork;
  if (error is AuthException) {
    return switch (error.code) {
      'invalid_credentials' => l.errorInvalidCredentials,
      'email_not_confirmed' => l.errorUnverified,
      'user_already_exists' || 'email_exists' => l.errorRegistered,
      'otp_expired' => l.errorOtp,
      'weak_password' => l.errorPasswordShort,
      'same_password' => l.errorPasswordSame,
      'over_email_send_rate_limit' ||
      'over_request_rate_limit' =>
        l.errorRateLimit,
      'user_banned' => l.errorBlocked,
      'email_address_invalid' || 'validation_failed' => l.errorEmail,
      _ => error.statusCode == '429' ? l.errorRateLimit : l.errorAuth,
    };
  }
  if (error is FunctionException) {
    final details = error.details;
    final code = details is Map && details['error'] is Map
        ? details['error']['code']
        : null;
    if (code == 'AI_NOT_CONFIGURED') return l.errorAiConfig;
    if (error.status == 404) return l.errorAiUnavailable;
    if (error.status == 429) return l.errorRateLimit;
    return l.errorAi;
  }
  if (error is PostgrestException)
    return error.code == '23505'
        ? l.errorExists
        : error.code == '42501'
            ? l.errorPermission
            : l.errorSave;
  if (error is GoogleSignInException)
    return error.code == GoogleSignInExceptionCode.canceled
        ? l.errorGoogleCanceled
        : error.code == GoogleSignInExceptionCode.clientConfigurationError
            ? l.errorGoogleConfig
            : l.errorGoogle;
  if (context == null && error is StateError) return error.message;
  return l.errorUnknown;
}
