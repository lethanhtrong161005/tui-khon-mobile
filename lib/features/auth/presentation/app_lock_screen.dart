import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_lock_service.dart';
import '../../../core/offline/local_store.dart';
import '../providers/auth_providers.dart';
import 'widgets/auth_widgets.dart';

/// True once the user passed the biometric check in this app session
/// (or just signed in with a password).
final appUnlockedProvider = StateProvider<bool>((ref) => false);

/// Shown instead of the dashboard when the biometric lock is enabled.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key, this.automaticallyAuthenticate = true});
  final bool automaticallyAuthenticate;

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    if (widget.automaticallyAuthenticate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _unlock();
      });
    }
  }

  Future<void> _unlock() async {
    if (_checking) return;
    setState(() => _checking = true);
    final ok = await ref
        .read(appLockProvider)
        .authenticate(appL10n(context).msgUnlockTIKhN79);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) ref.read(appUnlockedProvider.notifier).state = true;
  }

  Future<void> _passwordLogin() async {
    final pending = await ref.read(localStoreProvider)?.pendingCount() ?? 0;
    if (!mounted) return;
    if (pending > 0) {
      final yes = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text(appL10n(context).msgUnsyncedChanges80),
                  content: Text(appL10n(context)
                      .msgChangesWillStayOnThisDevice81((pending).toString())),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(appL10n(context).stay)),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child:
                            Text(appL10n(context).msgKeepOnDeviceAndSignOut83))
                  ]));
      if (yes != true || !mounted) return;
    }
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appPalette(context).surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthBrandHeader(
                title: appL10n(context).msgTIKhNIsLocked84,
                subtitle: appL10n(context).msgUseFaceIdOrYourFingerprint85,
                icon: Icons.lock_outline,
              ),
              const SizedBox(height: 32),
              AuthPrimaryButton(
                label: appL10n(context).msgUnlock86,
                icon: Icons.fingerprint,
                isLoading: _checking,
                onPressed: _unlock,
              ),
              const SizedBox(height: 12),
              TextButton(
                // Signing out returns to LoginScreen; the password login unlocks again.
                onPressed: _passwordLogin,
                child: Text(appL10n(context).msgSignInWithPassword87),
              ),
            ],
          )),
        ),
      ),
    );
  }
}
