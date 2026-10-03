import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/widgets/app_bottom_nav.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../advisor/presentation/advisor_screen.dart';
import '../../pro/presentation/pro_upgrade_screen.dart';
import '../../profile/presentation/profile_settings_screen.dart';
import '../../quick_record/presentation/quick_record_screen.dart';
import '../../split_bill/presentation/split_bill_screen.dart';
import '../controllers/home_controller.dart';
import '../models/dashboard_summary_model.dart';
import 'transactions_screen.dart';
import 'widgets/balance_card_widget.dart';
import 'widgets/category_summary_card.dart';
import 'widgets/recent_transactions_section.dart';

/// HomeScreen renders the primary PRM-3 Dashboard conforming to the Google Stitch UI spec.
/// Reactive via Riverpod [homeControllerProvider]:
/// - Total Balance = Total Income - Total Expense
/// - Current Period Income / Expense & Net Summary
/// - Monthly Budget Progress Bar
/// - Category Summary (Expense / Income breakdown)
/// - Recent Transactions (with detail sheet & See All screen)
class HomeScreen extends ConsumerWidget {
  final bool showEmbeddedBottomNav;

  const HomeScreen({
    super.key,
    this.showEmbeddedBottomNav = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.refreshDashboard,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(context, ref),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _buildProBanner(context),
                          const SizedBox(height: 12),

                          // 1 & 2 & 3. Total Balance (Income - Expense) + Period Income/Expense
                          BalanceCardWidget(
                            summary: homeState.summary,
                            isBalanceVisible: homeState.isBalanceVisible,
                            onToggleVisibility:
                                controller.toggleBalanceVisibility,
                            onSelectPeriod: controller.setPeriod,
                          ),
                          const SizedBox(height: 16),

                          // AI Proactive Advisory Card (Stitch section 2)
                          _buildGeminiInsightCard(context, ref),
                          const SizedBox(height: 16),

                          // Quick Action Shortcuts Grid (Stitch section 3)
                          _buildQuickActionGrid(context, ref),
                          const SizedBox(height: 16),

                          // Monthly Budget Progress Bar (Stitch section 4)
                          _buildBudgetProgressBar(
                            monthlyExpense: homeState.periodExpense,
                            monthlyLimit: homeState.monthlyBudgetLimit,
                            progressRatio: homeState.budgetProgressPercentage,
                            progressPercent: homeState.budgetProgressPercentInt,
                            periodSubtitle: homeState.selectedPeriod.subtitle,
                          ),
                          const SizedBox(height: 16),

                          // PRM-3 Section 1: Category Summary
                          CategorySummaryCard(
                            items: homeState.categorySummaries,
                            selectedType: homeState.selectedCategoryType,
                            period: homeState.selectedPeriod,
                            onSelectType: controller.setCategorySummaryType,
                            onTapViewAnalytics: () {
                              if (!showEmbeddedBottomNav) {
                                controller.setTabIndex(2);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdvisorScreen(),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 20),

                          // PRM-3 Section 4: Recent Transactions
                          RecentTransactionsSection(
                            transactions: homeState.recentTransactions,
                            totalCount: homeState.periodTransactions.length,
                            onTapSeeAll: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TransactionsScreen(),
                                ),
                              );
                            },
                            onTapTransaction: (tx) =>
                                showTransactionDetailBottomSheet(
                              context,
                              ref,
                              tx,
                            ),
                          ),
                          const SizedBox(height: 104),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (showEmbeddedBottomNav)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: AppBottomNav(
                  currentIndex: homeState.currentTabIndex,
                  onSelectTab: (idx) {
                    if (idx == 0) return;
                    if (idx == 1) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SplitBillScreen(),
                        ),
                      );
                    } else if (idx == 2) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdvisorScreen(),
                        ),
                      );
                    } else if (idx == 3) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileSettingsScreen(),
                        ),
                      );
                    }
                  },
                  onTapCenterAction: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const QuickRecordScreen(),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the top app bar with avatar, PRO upgrade pill, and notification icon.
  Widget _buildSliverAppBar(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.surface.withValues(alpha: 0.88),
      elevation: 0,
      expandedHeight: 64,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () {
              if (!showEmbeddedBottomNav) {
                ref.read(homeControllerProvider.notifier).setTabIndex(3);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileSettingsScreen(),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryFixed,
                        backgroundImage: const NetworkImage(
                          'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150',
                        ),
                        onBackgroundImageError: (_, __) {},
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Minh Quân',
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Tài khoản & Cài đặt ›',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProUpgradeScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        size: 16,
                        color: AppColors.tertiary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Nâng cấp ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none,
                      color: AppColors.onSurface,
                    ),
                    onPressed: () => _showNotificationBottomSheet(context, ref),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Small promotional strip leading to PRO features (Stitch top strip)
  Widget _buildProBanner(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProUpgradeScreen()),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stars,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Trải nghiệm toàn diện với Túi Khôn PRO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            const Row(
              children: [
                Text(
                  'Nâng cấp',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// AI Proactive Advisory Card
  Widget _buildGeminiInsightCard(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Gemini khuyên bạn',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryFixed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Thời gian thực',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurface,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(text: 'Hôm nay bạn đã chi tiêu '),
                      TextSpan(
                        text: '120.000 ₫',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            ' cho Cà phê & Ăn uống, vẫn nằm trong hạn mức tuần! Bạn có ',
                      ),
                      TextSpan(
                        text: '1 hóa đơn định kỳ (Tiền điện)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                      TextSpan(text: ' đến hạn sau 2 ngày.'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    if (!showEmbeddedBottomNav) {
                      ref.read(homeControllerProvider.notifier).setTabIndex(2);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdvisorScreen(),
                        ),
                      );
                    }
                  },
                  child: const Row(
                    children: [
                      Text(
                        'Hỏi Gemini ngay',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4 Quick Action Shortcuts Grid
  Widget _buildQuickActionGrid(BuildContext context, WidgetRef ref) {
    final actions = [
      {
        'title': 'Quét OCR',
        'icon': Icons.document_scanner,
        'color': AppColors.primary,
        'bg': AppColors.surfaceContainerHigh,
      },
      {
        'title': 'Voice AI',
        'icon': Icons.mic,
        'color': AppColors.secondary,
        'bg': AppColors.secondaryFixed,
      },
      {
        'title': 'Chia tiền',
        'icon': Icons.group_add,
        'color': AppColors.tertiary,
        'bg': AppColors.surfaceContainerHigh,
      },
      {
        'title': 'Ngân sách',
        'icon': Icons.pie_chart,
        'color': AppColors.primaryContainer,
        'bg': AppColors.surfaceContainerHigh,
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((item) {
        return Expanded(
          child: GestureDetector(
            onTap: () {
              final title = item['title'] as String;
              if (title == 'Voice AI' || title == 'Quét OCR') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QuickRecordScreen(),
                  ),
                );
              } else if (title == 'Chia tiền') {
                if (!showEmbeddedBottomNav) {
                  ref.read(homeControllerProvider.notifier).setTabIndex(1);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SplitBillScreen(),
                    ),
                  );
                }
              } else {
                if (!showEmbeddedBottomNav) {
                  ref.read(homeControllerProvider.notifier).setTabIndex(2);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdvisorScreen(),
                    ),
                  );
                }
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item['bg'] as Color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Dynamic Monthly budget progress bar matching Stitch section 4
  Widget _buildBudgetProgressBar({
    required double monthlyExpense,
    required double monthlyLimit,
    required double progressRatio,
    required int progressPercent,
    required String periodSubtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.donut_large,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ngân sách ($periodSubtitle)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressRatio,
              minHeight: 10,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                progressRatio >= 0.9 ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đã dùng',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatVND(monthlyExpense),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Hạn mức tháng',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatVND(monthlyLimit),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNotificationBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_active,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trung tâm thông báo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              '3 thông báo mới chưa đọc',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    _buildNotifItem(
                      icon: Icons.receipt_long,
                      iconColor: AppColors.error,
                      title: 'Nhắc nợ • Tiệc BBQ Sinh nhật Lan',
                      subtitle:
                          'Anh Tuấn còn khoản nợ 600.000 ₫ chưa thanh toán. Chạm để gửi link VietQR.',
                      time: '5 phút trước',
                      isUnread: true,
                      tag: '600.000 ₫',
                      onAction: () {
                        Navigator.pop(ctx);
                        if (!showEmbeddedBottomNav) {
                          ref
                              .read(homeControllerProvider.notifier)
                              .setTabIndex(1);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SplitBillScreen(),
                            ),
                          );
                        }
                      },
                      actionText: 'Nhắc Zalo ngay',
                    ),
                    _buildNotifItem(
                      icon: Icons.account_balance_wallet,
                      iconColor: AppColors.primary,
                      title: 'Ghi nhận chi tiêu MoMo',
                      subtitle:
                          'Phở bò tái gầu (-65.000 ₫) đã lưu vào danh mục Ăn uống • Tiêu dùng.',
                      time: '42 phút trước',
                      isUnread: true,
                      tag: '-65.000 ₫',
                    ),
                    _buildNotifItem(
                      icon: Icons.auto_awesome,
                      iconColor: AppColors.tertiary,
                      title: 'Cố vấn Túi Khôn AI',
                      subtitle:
                          'Tiết kiệm được 24% ngân sách tuần này. Dự kiến đạt mục tiêu mua căn hộ trước hạn!',
                      time: '2 giờ trước',
                      isUnread: true,
                      onAction: () {
                        Navigator.pop(ctx);
                        if (!showEmbeddedBottomNav) {
                          ref
                              .read(homeControllerProvider.notifier)
                              .setTabIndex(2);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdvisorScreen(),
                            ),
                          );
                        }
                      },
                      actionText: 'Xem phân tích',
                    ),
                    _buildNotifItem(
                      icon: Icons.security,
                      iconColor: Colors.blue,
                      title: 'Bảo mật dữ liệu Local SQLite',
                      subtitle:
                          'Đã hoàn tất mã hóa chuẩn ngân hàng AES-256 trên thiết bị cục bộ.',
                      time: 'Hôm qua',
                      isUnread: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotifItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
    required bool isUnread,
    String? tag,
    VoidCallback? onAction,
    String? actionText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnread
            ? AppColors.primary.withValues(alpha: 0.04)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tag != null || onAction != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  const SizedBox(),
                if (onAction != null && actionText != null)
                  ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      actionText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
