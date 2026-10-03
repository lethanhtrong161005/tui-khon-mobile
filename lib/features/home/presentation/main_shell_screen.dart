import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/widgets/app_bottom_nav.dart';
import '../../../core/constants/app_colors.dart';
import '../../advisor/presentation/advisor_screen.dart';
import '../../profile/presentation/profile_settings_screen.dart';
import '../../quick_record/presentation/quick_record_screen.dart';
import '../../split_bill/presentation/split_bill_screen.dart';
import '../controllers/home_controller.dart';
import 'home_screen.dart';
import 'transactions_screen.dart';

/// MainShellScreen provides the persistent bottom navigation shell (PRM-3 Section 5)
/// integrating Dashboard, Planning, Statistics (AI Advisor), Profile, and Transactions.
class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(
      homeControllerProvider.select((s) => s.currentTabIndex),
    );

    const tabs = <Widget>[
      HomeScreen(showEmbeddedBottomNav: false),
      SplitBillScreen(),
      AdvisorScreen(),
      ProfileSettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: currentTab,
            children: tabs,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: AppBottomNav(
                currentIndex: currentTab,
                onSelectTab: (idx) {
                  ref.read(homeControllerProvider.notifier).setTabIndex(idx);
                },
                onTapCenterAction: () => _showCenterActionModal(context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCenterActionModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ghi chép & Quản lý giao dịch',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chọn phương thức thêm giao dịch để cập nhật số dư tức thì',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _actionOptionTile(
                icon: Icons.auto_awesome,
                iconBg: AppColors.secondaryFixed,
                iconColor: AppColors.secondary,
                title: 'Ghi nhanh bằng AI (Chat / Giọng nói)',
                subtitle: 'Nhập "Ăn phở 65k", "Lương 15 củ" để Gemini tự phân loại',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QuickRecordScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _actionOptionTile(
                icon: Icons.add_card_rounded,
                iconBg: AppColors.primaryFixed.withValues(alpha: 0.45),
                iconColor: AppColors.primary,
                title: 'Thêm giao dịch thủ công',
                subtitle: 'Nhập số tiền, chọn Thu/Chi, Danh mục và Nguồn ví',
                onTap: () {
                  Navigator.pop(ctx);
                  showAddTransactionBottomSheet(context, ref);
                },
              ),
              const SizedBox(height: 10),
              _actionOptionTile(
                icon: Icons.receipt_long_rounded,
                iconBg: AppColors.tertiaryFixed.withValues(alpha: 0.6),
                iconColor: AppColors.tertiary,
                title: 'Xem toàn bộ Sổ giao dịch',
                subtitle: 'Lọc theo Thu/Chi, Danh mục và tìm kiếm chi tiết',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionOptionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
