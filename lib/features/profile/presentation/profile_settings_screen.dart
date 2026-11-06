import '../../../core/theme/semantic_colors.dart';
import '../../../core/theme/appearance.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/offline/sync_screen.dart';
import '../../data_exchange/data_exchange_screen.dart';
import '../../reports/monthly_report_screen.dart';
import '../../reminders/reminders.dart';
import '../../quick_record/presentation/category_rules_screen.dart';
import '../../../core/services/app_lock_service.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../settings/presentation/categories_screen.dart';
import '../../settings/presentation/wallets_screen.dart';
import 'edit_profile_screen.dart';

/// Tài khoản & cài đặt: hồ sơ, nguồn tiền, danh mục, khoá ứng dụng, đăng xuất.
class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key, this.embedded = false});
  final bool embedded;

  /// Confirmation sheet to prevent accidental logouts.
  Future<void> _showLogoutConfirmation(
      BuildContext context, WidgetRef ref) async {
    final pending = await ref.read(localStoreProvider)?.pendingCount() ?? 0;
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius:
                const BorderRadius.vertical(top: const Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: appPalette(context).outlineVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: appPalette(context).errorContainer.withOpacity(0.5),
                    shape: BoxShape.circle),
                child: Icon(Icons.logout_rounded,
                    color: appPalette(context).error, size: 26),
              ),
              const SizedBox(height: 14),
              Text(appL10n(context).signOutTitle,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: appPalette(context).onSurface)),
              const SizedBox(height: 6),
              Text(
                pending > 0
                    ? appL10n(context).msgThereAreUnsyncedChangesSigningOut344(
                        (pending).toString())
                    : appL10n(context).signOutLocalNote,
                style: TextStyle(
                    fontSize: 13,
                    color: appPalette(context).onSurfaceVariant,
                    height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: appPalette(context)
                                .outlineVariant
                                .withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(appL10n(context).stay,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: appPalette(context).onSurface)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        try {
                          // AuthGate clears the route stack and shows LoginScreen.
                          await ref.read(authRepositoryProvider).signOut();
                          if (!context.mounted) return;
                          messenger.showSnackBar(SnackBar(
                              content: Text(appL10n(context).signedOut)));
                        } catch (e) {
                          if (!context.mounted) return;
                          messenger.showSnackBar(SnackBar(
                              content:
                                  Text(friendlyError(e, context: context))));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appPalette(context).error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(appL10n(context).signOut,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleLock(
      BuildContext context, WidgetRef ref, bool enable) async {
    final lock = ref.read(appLockProvider);
    if (enable) {
      if (!await lock.isAvailable()) {
        if (context.mounted) {
          showToast(context, appL10n(context).msgBiometricsAreNotSetUpOn345);
        }
        return;
      }
      if (!context.mounted) return;
      if (!await lock.authenticate(appL10n(context).msgConfirmToEnableTIKh346))
        return;
    }
    await lock.setEnabled(enable);
    ref.invalidate(appLockEnabledProvider);
    if (context.mounted)
      showToast(
          context,
          enable
              ? appL10n(context).lockEnabled
              : appL10n(context).lockDisabled);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = appL10n(context);
    final appearance = ref.watch(appearanceProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final lockEnabled = ref.watch(appLockEnabledProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            Theme.of(context).colorScheme.surface.withValues(alpha: .9),
        elevation: 0,
        automaticallyImplyLeading: !embedded,
        title: Text(appL10n(context).profile,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, embedded ? 130 : 24),
        children: [
          _ProfileCard(profile: profile),
          const SizedBox(height: 20),
          _sectionTitle(context, l10n.preferences),
          _menuGroup(context, [
            _menuItem(context,
                icon: Icons.brightness_6_outlined,
                title: l10n.appearance,
                subtitle: appearance.theme == ThemeMode.system
                    ? l10n.system
                    : appearance.theme == ThemeMode.dark
                        ? l10n.dark
                        : l10n.light,
                onTap: () => showAppearanceChoice(context, ref)),
            _menuItem(context,
                icon: Icons.translate,
                title: l10n.language,
                subtitle: appearance.language == 'system'
                    ? l10n.system
                    : appearance.language == 'en'
                        ? 'English'
                        : 'Tiếng Việt',
                onTap: () =>
                    showAppearanceChoice(context, ref, language: true)),
          ]),
          const SizedBox(height: 20),
          _sectionTitle(context, l10n.manageNotebook),
          _menuGroup(context, [
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
              _menuItem(context,
                  icon: Icons.widgets_outlined,
                  title: l10n.homeWidgetTitle,
                  subtitle: l10n.homeWidgetHelpSubtitle,
                  onTap: () => showDialog<void>(context: context,
                      builder: (ctx) => AlertDialog(
                          scrollable: true,
                          title: Text(l10n.homeWidgetTitle),
                          content: Text(l10n.homeWidgetHelp),
                          actions: [TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(l10n.homeWidgetHelpClose))]))),
            _menuItem(context,
                icon: Icons.cloud_sync,
                title: appL10n(context).dataSync,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SyncScreen()))),
            _menuItem(context,
                icon: Icons.import_export,
                title: appL10n(context).csvExchange,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DataExchangeScreen()))),
            _menuItem(context,
                icon: Icons.summarize,
                title: appL10n(context).monthlyReport,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MonthlyReportScreen()))),
            _menuItem(context,
                icon: Icons.notifications_active,
                title: appL10n(context).reminderSettings,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ReminderSettingsScreen()))),
            _menuItem(context,
                icon: Icons.event_note,
                title: appL10n(context).payables,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PayablesScreen()))),
            _menuItem(context,
                icon: Icons.auto_awesome,
                title: appL10n(context).learnedRules,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CategoryRulesScreen()))),
            _menuItem(
              context,
              icon: Icons.account_balance_wallet,
              title: appL10n(context).wallets,
              subtitle: appL10n(context).walletsSubtitle,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WalletsScreen())),
            ),
            _menuItem(
              context,
              icon: Icons.category,
              title: appL10n(context).categories,
              subtitle: appL10n(context).categoriesSubtitle,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CategoriesScreen())),
            ),
          ]),
          const SizedBox(height: 20),
          _sectionTitle(context, appL10n(context).security),
          _menuGroup(context, [
            SwitchListTile.adaptive(
              secondary:
                  Icon(Icons.fingerprint, color: appPalette(context).primary),
              title: Text(appL10n(context).biometricLock,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(appL10n(context).biometricSubtitle,
                  style: const TextStyle(fontSize: 12)),
              value: lockEnabled,
              activeThumbColor: appPalette(context).primary,
              onChanged: (v) => _toggleLock(context, ref, v),
            ),
            _menuItem(
              context,
              icon: Icons.logout_rounded,
              title: appL10n(context).signOut,
              color: appPalette(context).error,
              onTap: () => _showLogoutConfirmation(context, ref),
            ),
          ]),
          const SizedBox(height: 24),
          Center(
            child: Text(appL10n(context).appDescription,
                style: TextStyle(
                    fontSize: 11, color: appPalette(context).outline)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: appPalette(context).outline,
                letterSpacing: 0.5)),
      );

  Widget _menuGroup(BuildContext context, List<Widget> children) => Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainer,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: color),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color == appPalette(context).error ? color : null)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EditProfileScreen.fromProfile(profile)),
        ),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.primaryFixed,
          backgroundImage: profile?.avatarUrl == null
              ? null
              : NetworkImage(profile!.avatarUrl!),
          child: profile?.avatarUrl == null
              ? Text(profile?.initials ?? '',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: appPalette(context).primary))
              : null,
        ),
        title: Text(profile?.name ?? '',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        subtitle: Text(
          [profile?.email, profile?.phone].whereType<String>().join(' • '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Icon(Icons.edit_outlined, color: appPalette(context).primary),
      ),
    );
  }
}
