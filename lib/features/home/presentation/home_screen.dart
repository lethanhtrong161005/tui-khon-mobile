import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/offline/sync_controller.dart';
import '../../../core/offline/sync_screen.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_messages.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../core/services/debt_reminder_service.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../planning/data/planning_repository.dart';
import '../../planning/models/planning_models.dart';
import '../../planning/presentation/debt_actions.dart';
import '../../planning/presentation/debt_history_screen.dart';
import '../../reminders/reminders.dart';
import '../../reports/monthly_report_screen.dart';
import '../../planning/presentation/planning_screen.dart';
import '../../quick_record/presentation/quick_record_screen.dart';
import '../../advisor/presentation/advisor_screen.dart';
import '../../profile/presentation/profile_settings_screen.dart';
import '../../transactions/presentation/transaction_history_screen.dart';
import 'widgets/transaction_form_sheet.dart';
import '../models/monthly_summary.dart';
import '../models/notification_model.dart';
import '../models/transaction_model.dart';
import '../providers/home_providers.dart';

/// HomeScreen renders the primary dashboard conforming to the Túi Khôn UI spec.
/// Designed adaptively for both iOS (Cupertino/Dynamic Island) and Android (Material 3).
/// Figures come from Supabase via [monthlySummaryProvider] / [recentTransactionsProvider].
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Local state toggles
  bool _isBalanceVisible = true;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    if (ref.read(localStoreProvider) != null) {
      ref.listenManual<String?>(pendingNotificationRouteProvider, (_, route) => _openNotification(route),
          fireImmediately: true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDebts());
  }

  void _openNotification(String? route) {
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(pendingNotificationRouteProvider.notifier).state = null;
      if (route.contains('/debts/')) {
        final id = route.split('/').last;
        final debt = (await ref.read(debtsProvider.future)).where((d) => d.id == id).firstOrNull;
        if (!mounted) return;
        if (debt != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => DebtHistoryScreen(debt: debt)));
          return;
        }
      }
      final now = DateTime.now().toUtc().add(const Duration(hours: 7));
      final screen = route == '/reports'
          ? MonthlyReportScreen(initialMonth: DateTime(now.year, now.month - 1))
          : route == '/payables'
              ? const PayablesScreen()
              : route.contains('/debts')
                  ? const PlanningScreen(initialTab: PlanningTab.debts)
                  : const QuickRecordScreen();
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    });
  }

  /// On opening the app: re-schedule device reminders and ask about debts
  /// that are due today or overdue.
  Future<void> _checkDebts() async {
    List<DebtModel> debts;
    try {
      debts = await ref.read(debtsProvider.future);
    } catch (_) {
      return;
    }
    ref.read(debtRemindersProvider).sync(debts);
    final today = DateTime.now();
    final due = debts.where((d) => d.isDue(today)).toList();
    if (due.isEmpty || !mounted || ref.read(dueDebtsPromptShownProvider)) return;
    ref.read(dueDebtsPromptShownProvider.notifier).state = true;
    await showFormSheet<void>(context, _DueDebtsSheet(debts: due));
  }

  Future<void> _editTransaction(TransactionModel tx) async {
    final store = ref.read(localStoreProvider);
    if (store != null) {
      final linked = (await store.rows('debt_payments')).where((p) => p['transaction_id'] == tx.id).firstOrNull;
      if (linked != null) {
        final debt = (await ref.read(debtsProvider.future)).where((d) => d.id == linked['debt_id']).firstOrNull;
        if (debt != null && mounted)
          await Navigator.push(context, MaterialPageRoute(builder: (_) => DebtHistoryScreen(debt: debt)));
        return;
      }
    }
    final draft = await showTransactionFormSheet(context, initial: tx.toDraft(), excludingId: tx.id);
    if (draft == null || !mounted) return;
    try {
      await ref.read(walletRepositoryProvider).updateTransaction(tx.id, draft);
      ref.refreshWalletData();
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
    }
  }

  Future<void> _refresh() async {
    if (ref.read(localStoreProvider) != null) await ref.read(syncControllerProvider.notifier).sync();
    ref.refreshWalletData();
    ref.invalidate(profileProvider);
    await ref.read(monthlySummaryProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(localStoreProvider) != null) {
      ref.watch(reminderSyncProvider);
    }
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final summary = summaryAsync.valueOrNull;
    final profile = ref.watch(profileProvider).valueOrNull;
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false, // Allows the header blur to flow behind status bar
        child: Stack(
          children: [
            // Scrollable Content
            RefreshIndicator(
              color: AppColors.primary,
              edgeOffset: 64,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(context, profile, unreadCount),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          const SyncIndicator(),
                          if (summaryAsync.hasError) ...[
                            _buildErrorBanner(summaryAsync.error!),
                            const SizedBox(height: 12),
                          ],
                          _buildBalanceCard(summary),
                          const SizedBox(height: 16),
                          _buildGeminiInsightCard(context, summary),
                          const SizedBox(height: 16),
                          _buildQuickActionGrid(context),
                          const SizedBox(height: 16),
                          _buildBudgetProgressBar(summary),
                          const SizedBox(height: 20),
                          _buildRecentTransactionsHeader(),
                          const SizedBox(height: 8),
                          _buildRecentTransactionsList(ref.watch(recentTransactionsProvider)),
                          const SizedBox(height: 100), // Space for floating bottom nav
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Floating Bottom Navigation Bar
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildFloatingBottomNav(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown when the dashboard could not be loaded (offline, expired session...).
  Widget _buildErrorBanner(Object error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              friendlyError(error),
              style: const TextStyle(fontSize: 12, color: AppColors.onSurface),
            ),
          ),
          TextButton(onPressed: _refresh, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  /// Builds the top app bar with avatar, PRO upgrade pill, and notification icon.
  Widget _buildSliverAppBar(BuildContext context, UserProfile? profile, int unreadCount) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.surface.withOpacity(0.85),
      elevation: 0,
      expandedHeight: 64,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()));
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
                        backgroundImage: profile?.avatarUrl == null ? null : NetworkImage(profile!.avatarUrl!),
                        child: profile?.avatarUrl == null
                            ? Text(
                                profile?.initials ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                              )
                            : null,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile?.name ?? '',
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
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
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: AppColors.onSurface),
                    onPressed: () => _showNotificationBottomSheet(context),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
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

  /// Main emerald card holding balance, sync state, and monthly summary.
  /// [summary] is null while the first load is in progress.
  Widget _buildBalanceCard(MonthlySummary? summary) {
    String money(int? value, {bool showSign = false}) =>
        value == null ? '...' : CurrencyFormatter.formatVND(value, showSign: showSign);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security and Sync Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryFixed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'SỔ GHI CHÉP TRÊN THIẾT BỊ',
                      style: TextStyle(
                        color: AppColors.primaryFixed,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Sổ ghi chép',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Balance Display with Mask Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Số dư khả dụng',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isBalanceVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isBalanceVisible = !_isBalanceVisible;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _isBalanceVisible ? money(summary?.totalBalance) : '••••••••',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Monthly Dual Pills
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward, color: AppColors.primaryFixed, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Thu nhập tháng', style: TextStyle(color: Colors.white60, fontSize: 10)),
                          Text(
                            money(summary?.income, showSign: true),
                            style: const TextStyle(
                              color: AppColors.primaryFixed,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_downward, color: AppColors.errorContainer, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Đã chi tiêu', style: TextStyle(color: Colors.white60, fontSize: 10)),
                          Text(
                            money(summary == null ? null : -summary.expense, showSign: true),
                            style: const TextStyle(
                              color: AppColors.errorContainer,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Today's spending and the month-over-month trend, with a link to the AI advisor.
  Widget _buildGeminiInsightCard(BuildContext context, MonthlySummary? summary) {
    const bold = TextStyle(fontWeight: FontWeight.bold);
    final change = summary?.expenseChangePercent;
    final spans = <TextSpan>[
      if (summary == null)
        const TextSpan(text: 'Đang tổng hợp chi tiêu của bạn...')
      else ...[
        const TextSpan(text: 'Hôm nay bạn đã chi '),
        TextSpan(text: CurrencyFormatter.formatVND(summary.expenseOn(DateTime.now())), style: bold),
        const TextSpan(text: '. '),
        if (change == null)
          const TextSpan(text: 'Ghi chép đều đặn để Gemini so sánh chi tiêu giữa các tháng nhé!')
        else ...[
          const TextSpan(text: 'Chi tiêu tháng này '),
          TextSpan(
            text: change >= 0 ? 'tăng $change%' : 'giảm ${-change}%',
            style: bold.copyWith(color: change > 0 ? AppColors.error : AppColors.primary),
          ),
          const TextSpan(text: ' so với cùng kỳ tháng trước.'),
        ],
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withOpacity(0.7),
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
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
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
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryFixed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Thời gian thực',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: AppColors.onSurface, height: 1.4),
                    children: spans,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvisorScreen()));
                  },
                  child: const Row(
                    children: [
                      Text(
                        'Hỏi Gemini ngay',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16, color: AppColors.secondary),
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
  Widget _buildQuickActionGrid(BuildContext context) {
    final actions = [
      {
        'title': 'Quét OCR',
        'icon': Icons.document_scanner,
        'color': AppColors.primary,
        'bg': AppColors.surfaceContainerHigh
      },
      {'title': 'Voice AI', 'icon': Icons.mic, 'color': AppColors.secondary, 'bg': AppColors.secondaryFixed},
      {'title': 'Sổ nợ', 'icon': Icons.handshake, 'color': AppColors.tertiary, 'bg': AppColors.surfaceContainerHigh},
      {
        'title': 'Ngân sách',
        'icon': Icons.pie_chart,
        'color': AppColors.primaryContainer,
        'bg': AppColors.surfaceContainerHigh
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((item) {
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (item['title'] == 'Voice AI') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuickRecordScreen(initialAction: QuickRecordStart.voice)),
                );
              } else if (item['title'] == 'Quét OCR') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuickRecordScreen(initialAction: QuickRecordStart.scan)),
                );
              } else if (item['title'] == 'Sổ nợ') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlanningScreen(initialTab: PlanningTab.debts)),
                );
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanningScreen()));
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
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
                    child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['title'] as String,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Monthly budget progress bar (the month-wide budget, category_id = null).
  Widget _buildBudgetProgressBar(MonthlySummary? summary) {
    final budget = summary?.totalBudget;
    final month = summary?.month ?? DateTime.now();
    final monthLabel = '${month.month.toString().padLeft(2, '0')}/${month.year}';
    final spent = budget?.spent ?? summary?.expense ?? 0;
    final ratio = budget?.ratio ?? 0;
    final barColor = ratio >= 1 ? AppColors.error : (ratio >= 0.8 ? AppColors.tertiary : AppColors.primary);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.donut_large, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Ngân sách tháng $monthLabel',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
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
                  budget == null ? 'Chưa đặt' : '${(ratio * 100).round()}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Đã dùng', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                  Text(
                    CurrencyFormatter.formatVND(spent),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Hạn mức tháng', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                  Text(
                    budget == null ? '—' : CurrencyFormatter.formatVND(budget.limitAmount),
                    style:
                        const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Recent transactions header
  Widget _buildRecentTransactionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Giao dịch gần đây',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
          ),
          child: const Text(
            'Xem tất cả',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  /// Recent transaction list
  Widget _buildRecentTransactionsList(AsyncValue<List<TransactionModel>> transactionsAsync) {
    final list = transactionsAsync.valueOrNull;
    if (list == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: transactionsAsync.hasError
              ? Text(friendlyError(transactionsAsync.error!), style: const TextStyle(color: AppColors.onSurfaceVariant))
              : const CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long, color: AppColors.outline, size: 32),
            SizedBox(height: 8),
            Text(
              'Chưa có giao dịch nào.\nBấm nút ✨ để ghi chi tiêu bằng giọng nói hoặc chữ.',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: list.map((tx) {
        final isIncome = tx.isIncome;
        final color = colorFromHex(tx.categoryColor) ?? (isIncome ? AppColors.primary : AppColors.tertiary);
        final subtitle = '${tx.categoryName ?? 'Chưa phân loại'} • ${_formatWhen(tx.occurredAt)}';
        return GestureDetector(
          onTap: () => _editTransaction(tx),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 1)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(tx.icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              subtitle,
                              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (tx.badgeText != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryFixed,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tx.badgeText!,
                                style: const TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.secondary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatVND(tx.signedAmount, showSign: true),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isIncome ? AppColors.primary : AppColors.onSurface,
                      ),
                    ),
                    Text(
                      tx.walletName ?? '',
                      style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Floating pill bottom navigation bar matching the design
  Widget _buildFloatingBottomNav(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withOpacity(0.92),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF131B2E).withOpacity(0.12),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, 'Trang chủ', 0, () {}),
          _navItem(Icons.track_changes, 'Kế hoạch', 1, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanningScreen()));
          }),

          // Center Floating AI Button
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickRecordScreen()));
            },
            child: Container(
              width: 52,
              height: 52,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
            ),
          ),

          _navItem(Icons.insights, 'Cố vấn AI', 2, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvisorScreen()));
          }),
          _navItem(Icons.account_circle, 'Cá nhân', 3, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()));
          }),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, VoidCallback onTap) {
    final isSelected = _currentNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _currentNavIndex = index);
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the notification center and marks everything as read in the background.
  void _showNotificationBottomSheet(BuildContext context) {
    final notifications = ref.read(notificationsProvider).valueOrNull ?? const <NotificationModel>[];
    final unread = notifications.where((n) => !n.isRead).length;
    if (unread > 0) _markNotificationsRead();

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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.notifications_active, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trung tâm thông báo',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                            ),
                            Text(
                              unread > 0 ? '$unread thông báo mới chưa đọc' : 'Bạn đã xem hết thông báo',
                              style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
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
                child: notifications.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có thông báo nào',
                          style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        children: [
                          for (final n in notifications)
                            _buildNotifItem(
                              icon: n.icon,
                              iconColor: n.color,
                              title: n.title,
                              subtitle: n.message,
                              time: _timeAgo(n.createdAt),
                              isUnread: !n.isRead,
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

  Future<void> _markNotificationsRead() async {
    try {
      await ref.read(walletRepositoryProvider).markAllNotificationsRead();
      if (mounted) ref.invalidate(notificationsProvider);
    } catch (_) {
      // Not critical: the badge simply stays until the next refresh.
    }
  }

  /// "12:30" today, "Hôm qua", otherwise "dd/MM".
  static String _formatWhen(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    String two(int v) => v.toString().padLeft(2, '0');
    if (day == today) return '${two(time.hour)}:${two(time.minute)}';
    if (day == today.subtract(const Duration(days: 1))) return 'Hôm qua';
    return '${two(time.day)}/${two(time.month)}';
  }

  static String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return _formatWhen(time);
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
        color: isUnread ? AppColors.primary.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? AppColors.primary.withOpacity(0.2) : Colors.grey.shade200,
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
                  color: iconColor.withOpacity(0.12),
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
                            style:
                                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(tag, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(actionText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when the app opens and some debts are due today or overdue.
class _DueDebtsSheet extends ConsumerWidget {
  const _DueDebtsSheet({required this.debts});

  final List<DebtModel> debts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    return FormSheet(
      title: 'Khoản nợ đã đến hạn',
      submitLabel: 'Để sau',
      onSubmit: () => Navigator.pop(context),
      children: [
        const Text('Các khoản dưới đây đã đến hạn. Đã trả hoặc đã nhận tiền thì xác nhận để cập nhật sổ nợ nhé.',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (final d in debts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              d.type == DebtType.borrow ? 'Tôi nợ ${d.personName}' : '${d.personName} nợ tôi',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${CurrencyFormatter.formatVND(d.remaining)} • ${d.dueLabel(today) ?? ''}',
                style: const TextStyle(color: AppColors.error)),
            trailing: TextButton(
              onPressed: () async {
                final done = await showSettleDebtDialog(context, ref, d);
                if (done && context.mounted) Navigator.pop(context);
              },
              child: Text(d.type == DebtType.borrow ? 'Đã trả' : 'Đã nhận'),
            ),
          ),
      ],
    );
  }
}
