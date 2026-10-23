import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_lock_service.dart';
import '../providers/auth_providers.dart';
import 'widgets/auth_widgets.dart';

/// True once the user passed the biometric check in this app session
/// (or just signed in with a password).
final appUnlockedProvider = StateProvider<bool>((ref) => false);

/// Shown instead of the dashboard when the biometric lock is enabled.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_checking) return;
    setState(() => _checking = true);
    final ok = await ref.read(appLockProvider).authenticate('Mở khoá Túi Khôn');
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) ref.read(appUnlockedProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHeader(
                title: 'Túi Khôn đang khoá',
                subtitle: 'Xác thực bằng Face ID / vân tay để mở sổ của bạn',
                icon: Icons.lock_outline,
              ),
              const SizedBox(height: 32),
              AuthPrimaryButton(
                label: 'Mở khoá',
                icon: Icons.fingerprint,
                isLoading: _checking,
                onPressed: _unlock,
              ),
              const SizedBox(height: 12),
              TextButton(
                // Signing out returns to LoginScreen; the password login unlocks again.
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Đăng nhập bằng mật khẩu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
