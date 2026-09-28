import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/presentation/login_screen.dart';
import '../../pro/presentation/pro_upgrade_screen.dart';
import 'edit_profile_screen.dart';

/// ProfileSettingsScreen provides user account management, security preferences,
/// and an ergonomically safe, high-UX Logout flow with confirmation bottom sheet.
class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  /// Displays an iOS / Material 3 compliant confirmation bottom sheet
  /// to prevent accidental logouts and maintain smooth UX.
  void _showLogoutConfirmation(BuildContext context) {
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
              // Subtle Drag Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Warning Icon Container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),

              // Title & Clarification
              const Text(
                'Đăng xuất khỏi Túi Khôn?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Dữ liệu tài chính của bạn đã được mã hóa an toàn trên thiết bị này. Bạn có thể đăng nhập lại bất kỳ lúc nào.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Action Buttons: Safe Cancel vs Confirm Logout
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Ở lại',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx); // Close sheet
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false, // Clear all route stack
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã đăng xuất an toàn khỏi tài khoản'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Đăng xuất',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withOpacity(0.9),
        elevation: 0,
        title: const Text(
          'Tài khoản & Cài đặt',
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            // User Profile Card (Tap to edit)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundImage: NetworkImage(
                                'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150',
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.check, size: 10, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'Minh Quân',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.verified, color: AppColors.primary, size: 16),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '0988 ••• •56 • Google Sync',
                                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFDBA74)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.military_tech, size: 12, color: Color(0xFFEA580C)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Hội viên PRO (7 ngày dùng thử)',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Sửa',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Text('🎯', style: TextStyle(fontSize: 12)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Tiết kiệm mua nhà 2027',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Text('💳', style: TextStyle(fontSize: 12)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Techcombank',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Settings Group 1: Features & Plan
            _buildSectionHeader('TÀI CHÍNH & NÂNG CẤP'),
            _buildSettingsContainer([
              _settingsTile(
                icon: Icons.workspace_premium,
                iconColor: AppColors.tertiary,
                title: 'Gói thành viên Túi Khôn PRO',
                subtitle: 'Hạn dùng: 08/06/2026',
                trailingBadge: 'Đang dùng',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProUpgradeScreen()));
                },
              ),
              _settingsTile(
                icon: Icons.qr_code_scanner,
                iconColor: AppColors.primary,
                title: 'Tài khoản ngân hàng & VietQR',
                subtitle: 'Techcombank • VPBank • MoMo',
                onTap: () {},
              ),
              _settingsTile(
                icon: Icons.pie_chart_outline,
                iconColor: AppColors.secondary,
                title: 'Hạn mức & Cảnh báo ngân sách',
                subtitle: '22.000.000 ₫/tháng',
                onTap: () {},
              ),
            ]),

            const SizedBox(height: 18),

            // Settings Group 2: Privacy & Security
            _buildSectionHeader('BẢO MẬT & DỮ LIỆU'),
            _buildSettingsContainer([
              _settingsTile(
                icon: Icons.fingerprint,
                iconColor: AppColors.primary,
                title: 'Khóa ứng dụng (Face ID / Vân tay)',
                subtitle: 'Đang bật',
                isSwitch: true,
                switchValue: true,
                onToggle: (val) {},
              ),
              _settingsTile(
                icon: Icons.cloud_done,
                iconColor: AppColors.primary,
                title: 'Sao lưu & Đồng bộ cục bộ',
                subtitle: 'Vừa đồng bộ lúc 12:45',
                onTap: () {},
              ),
              _settingsTile(
                icon: Icons.notifications_none,
                iconColor: AppColors.secondary,
                title: 'Thông báo & Nhắc nợ thông minh',
                subtitle: 'Bật nhắc bill trước 3 ngày',
                onTap: () {},
              ),
            ]),

            const SizedBox(height: 24),

            // UX-Safe LOGOUT TILE / BUTTON
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.errorContainer.withOpacity(0.6)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Đăng xuất',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                subtitle: const Text(
                  'Bảo mật thông tin phiên làm việc',
                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.error,
                  size: 20,
                ),
                onTap: () => _showLogoutConfirmation(context),
              ),
            ),

            const SizedBox(height: 20),

            // App Version footnote
            const Text(
              'Túi Khôn v1.0.0 (Build 2026.09) • Local-First Security',
              style: TextStyle(fontSize: 11, color: AppColors.outline),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.outline,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    String? trailingBadge,
    bool isSwitch = false,
    bool switchValue = false,
    Function(bool)? onToggle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant))
          : null,
      trailing: isSwitch
          ? Switch.adaptive(
              value: switchValue,
              activeColor: AppColors.primary,
              onChanged: onToggle,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailingBadge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trailingBadge,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(Icons.chevron_right, size: 18, color: AppColors.outline),
              ],
            ),
    );
  }
}
