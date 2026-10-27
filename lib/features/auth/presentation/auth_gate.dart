import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_lock_service.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/offline/sync_controller.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../home/presentation/home_screen.dart';
import '../providers/auth_providers.dart';
import 'app_lock_screen.dart';
import 'login_screen.dart';

/// AuthGate is the app's root route: LoginScreen without a session,
/// AppLockScreen when the biometric lock is on and not yet passed,
/// HomeScreen otherwise. Whenever the signed-in user changes (sign in,
/// sign out, session expired) every pushed route is cleared.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> with WidgetsBindingObserver {
  /// Lock again when the app comes back after this long in the background.
  static const _relockAfter = Duration(seconds: 60);
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _backgroundedAt != null) {
      if (DateTime.now().difference(_backgroundedAt!) > _relockAfter) {
        ref.read(appUnlockedProvider.notifier).state = false;
      }
      _backgroundedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (next == null) return;
      Future.microtask(() async {
        if (!mounted) return;
        ref.read(offlineAccountIdProvider.notifier).state = next.user.id;
        await (await SharedPreferences.getInstance()).setString('offline_account_id', next.user.id);
      });
    });
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (previous == next) return;
      // A fresh password / Google / OTP sign-in already proved who the user is.
      ref.read(appUnlockedProvider.notifier).state = next != null;
      // The reset-password flow closes its own screens once the new password is saved.
      if (ref.read(passwordRecoveryPendingProvider)) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });

    final userId = ref.watch(currentUserIdProvider);
    final recovering = ref.watch(passwordRecoveryPendingProvider);
    if (userId == null || recovering) return const LoginScreen();

    if (ref.watch(localStoreProvider) != null) {
      final sync = ref.watch(syncControllerProvider);
      if (!sync.initialized) {
        return Scaffold(
            body: Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (sync.running) const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(sync.error ?? 'Đang tải dữ liệu lần đầu để dùng offline…', textAlign: TextAlign.center),
                      if (!sync.running)
                        FilledButton(
                            onPressed: () => ref.read(syncControllerProvider.notifier).sync(),
                            child: const Text('Thử lại')),
                    ]))));
      }
    }

    final lockEnabled = ref.watch(appLockEnabledProvider);
    final unlocked = ref.watch(appUnlockedProvider);
    if (lockEnabled.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if ((lockEnabled.valueOrNull ?? false) && !unlocked) return const AppLockScreen();
    return const HomeScreen();
  }
}

/// Shown when the app was built without `--dart-define-from-file=.env`.
class MissingConfigScreen extends StatelessWidget {
  const MissingConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings_suggest, size: 56, color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Thiếu cấu hình Supabase',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
              SizedBox(height: 8),
              Text(
                'Copy .env.example thành .env, điền SUPABASE_URL và SUPABASE_ANON_KEY rồi chạy:\n\n'
                'flutter run --dart-define-from-file=.env',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
