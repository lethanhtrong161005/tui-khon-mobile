import 'package:flutter/material.dart';
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
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: AppColors.errorContainer.withOpacity(0.5),
                    shape: BoxShape.circle),
                child: const Icon(Icons.logout_rounded,
                    color: AppColors.error, size: 26),
              ),
              const SizedBox(height: 14),
              const Text('Đăng xuất khỏi Túi Khôn?',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface)),
              const SizedBox(height: 6),
              Text(
                pending > 0
                    ? 'Có $pending thay đổi chưa đồng bộ. Đăng xuất sẽ giữ dữ liệu trên máy cho lần đăng nhập sau.'
                    : 'Dữ liệu trên máy được giữ riêng cho tài khoản này. Bạn có thể đăng nhập lại bất kỳ lúc nào.',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
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
                            color: AppColors.outlineVariant.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Ở lại',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface)),
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
                          messenger.showSnackBar(
                              const SnackBar(content: Text('Đã đăng xuất')));
                        } catch (e) {
                          messenger.showSnackBar(
                              SnackBar(content: Text(friendlyError(e))));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Đăng xuất',
                          style: TextStyle(
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
          showToast(context,
              'Thiết bị chưa cài Face ID / vân tay. Hãy thiết lập trong Cài đặt của máy trước.');
        }
        return;
      }
      if (!await lock.authenticate('Xác nhận để bật khoá Túi Khôn')) return;
    }
    await lock.setEnabled(enable);
    ref.invalidate(appLockEnabledProvider);
    if (context.mounted)
      showToast(
          context, enable ? 'Đã bật khoá ứng dụng' : 'Đã tắt khoá ứng dụng');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final lockEnabled = ref.watch(appLockEnabledProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withOpacity(0.9),
        elevation: 0,
        automaticallyImplyLeading: !embedded,
        title: const Text('Cá nhân',
            style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, embedded ? 130 : 24),
        children: [
          _ProfileCard(profile: profile),
          const SizedBox(height: 20),
          _sectionTitle('QUẢN LÝ SỔ'),
          _menuGroup([
            _menuItem(
                icon: Icons.cloud_sync,
                title: 'Dữ liệu & Đồng bộ',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SyncScreen()))),
            _menuItem(
                icon: Icons.import_export,
                title: 'Nhập / xuất CSV',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DataExchangeScreen()))),
            _menuItem(
                icon: Icons.summarize,
                title: 'Báo cáo tháng',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MonthlyReportScreen()))),
            _menuItem(
                icon: Icons.notifications_active,
                title: 'Cài đặt nhắc nhở',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ReminderSettingsScreen()))),
            _menuItem(
                icon: Icons.event_note,
                title: 'Khoản phải trả',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PayablesScreen()))),
            _menuItem(
                icon: Icons.auto_awesome,
                title: 'Quy tắc phân loại đã học',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CategoryRulesScreen()))),
            _menuItem(
              icon: Icons.account_balance_wallet,
              title: 'Nguồn tiền',
              subtitle: 'Tiền mặt, tài khoản, ví điện tử bạn tự khai',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WalletsScreen())),
            ),
            _menuItem(
              icon: Icons.category,
              title: 'Danh mục',
              subtitle: 'Thêm, sửa, xoá danh mục thu chi',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CategoriesScreen())),
            ),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('BẢO MẬT'),
          _menuGroup([
            SwitchListTile.adaptive(
              secondary:
                  const Icon(Icons.fingerprint, color: AppColors.primary),
              title: const Text('Khoá bằng Face ID / vân tay',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Mở app cần xác thực sinh trắc học',
                  style: TextStyle(fontSize: 12)),
              value: lockEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => _toggleLock(context, ref, v),
            ),
            _menuItem(
              icon: Icons.logout_rounded,
              title: 'Đăng xuất',
              color: AppColors.error,
              onTap: () => _showLogoutConfirmation(context, ref),
            ),
          ]),
          const SizedBox(height: 24),
          const Center(
            child: Text('Túi Khôn v1.0.0 • Sổ ghi chép tài chính cá nhân',
                style: TextStyle(fontSize: 11, color: AppColors.outline)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.outline,
                letterSpacing: 0.5)),
      );

  Widget _menuGroup(List<Widget> children) => Card(
        elevation: 0,
        color: AppColors.surfaceContainerLowest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _menuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color color = AppColors.primary,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: color),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color == AppColors.error ? color : null)),
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
      color: AppColors.surfaceContainerLowest,
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
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary))
              : null,
        ),
        title: Text(profile?.name ?? '',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        subtitle: Text(
          [profile?.email, profile?.phone].whereType<String>().join(' • '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.edit_outlined, color: AppColors.primary),
      ),
    );
  }
}
