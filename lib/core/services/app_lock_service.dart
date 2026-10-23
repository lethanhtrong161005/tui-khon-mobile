import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric app lock (Face ID / fingerprint). The Supabase session already
/// stays signed in, so "quick login" means: when enabled, the dashboard is
/// hidden behind a biometric check every time the app is opened.
abstract class AppLock {
  /// Device has Face ID / fingerprint (or a passcode fallback) set up.
  Future<bool> isAvailable();

  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);

  /// Shows the system biometric prompt; true when the user passed it.
  Future<bool> authenticate(String reason);
}

class BiometricAppLock implements AppLock {
  final LocalAuthentication _auth = LocalAuthentication();
  static const _key = 'app_lock_enabled';

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isEnabled() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    await (await SharedPreferences.getInstance()).setBool(_key, enabled);
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}

final appLockProvider = Provider<AppLock>((ref) => BiometricAppLock());

/// Whether the lock is turned on (read once, updated by the settings switch).
final appLockEnabledProvider = FutureProvider<bool>((ref) => ref.watch(appLockProvider).isEnabled());
