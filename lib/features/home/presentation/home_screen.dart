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
import '../../../core/widgets/glass.dart';
import '../../data_exchange/data_exchange_screen.dart';
import '../../statistics/presentation/statistics_screen.dart';
import 'widgets/notebook_navigation.dart';
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
/// Figures are read from the account-scoped SQLite repositories.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Local state toggles
  bool _isBalanceVisible = true;
  int _currentNavIndex = 0;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(localStoreProvider) != null) {
      ref.listenManual<String?>(pendingNotificationRouteProvider,
          (_, route) => _openNotification(route),
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
        final debt = (await ref.read(debtsProvider.future))
            .where((d) => d.id == id)
            .firstOrNull;
        if (!mounted) return;
        if (debt != null) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => DebtHistoryScreen(debt: debt)));
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
    if (due.isEmpty || !mounted || ref.read(dueDebtsPromptShownProvider))
      return;
    ref.read(dueDebtsPromptShownProvider.notifier).state = true;
    await showFormSheet<void>(context, _DueDebtsSheet(debts: due));
  }

  Future<void> _editTransaction(TransactionModel tx) async {
    final store = ref.read(localStoreProvider);
    if (store != null) {
      final linked = (await store.rows('debt_payments'))
          .where((p) => p['transaction_id'] == tx.id)
          .firstOrNull;
      if (linked != null) {
        final debt = (await ref.read(debtsProvider.future))
            .where((d) => d.id == linked['debt_id'])
            .firstOrNull;
        if (debt != null && mounted)
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => DebtHistoryScreen(debt: debt)));
        return;
      }
    }
    final draft = await showTransactionFormSheet(context,
        initial: tx.toDraft(), excludingId: tx.id);
    if (draft == null || !mounted) return;
    try {
      await ref.read(walletRepositoryProvider).updateTransaction(tx.id, draft);
      ref.refreshWalletData();
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
    }
  }

  Future<void> _refresh() async {
    if (ref.read(localStoreProvider) != null)
      await ref.read(syncControllerProvider.notifier).sync();
    ref.refreshWalletData();
    ref.invalidate(profileProvider);
    await ref.read(monthlySummaryProvider.future);
  }

  Future<void> _addTransaction(TransactionType type) async {
    final draft = await showTransactionFormSheet(context,
        initial: TransactionDraft(type: type, amount: 0));
    if (draft == null || !mounted) return;
    try {
      await ref.saveTransaction(draft);
      if (mounted) showToast(context, 'Đã lưu giao dịch');
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
    }
  }

  Future<void> _openActions() async {
    setState(() => _menuOpen = true);
    final action = await showNotebookActions(context);
    if (!mounted) return;
    setState(() => _menuOpen = false);
    if (action == null) return;
    if (action == NotebookAction.expense || action == NotebookAction.income) {
      await _addTransaction(action == NotebookAction.income
          ? TransactionType.income
          : TransactionType.expense);
      return;
    }
    final screen = switch (action) {
      NotebookAction.ai => const QuickRecordScreen(),
      NotebookAction.voice =>
        const QuickRecordScreen(initialAction: QuickRecordStart.voice),
      NotebookAction.receipt =>
        const QuickRecordScreen(initialAction: QuickRecordStart.scan),
      NotebookAction.advisor => const AdvisorScreen(),
      NotebookAction.history => const TransactionHistoryScreen(),
      NotebookAction.csv => const DataExchangeScreen(),
      NotebookAction.payables => const PayablesScreen(),
      NotebookAction.report => const MonthlyReportScreen(),
      NotebookAction.reminders => const ReminderSettingsScreen(),
      _ => const QuickRecordScreen(),
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) ref.refreshWalletData();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(localStoreProvider) != null) ref.watch(reminderSyncProvider);
    // Only build the selected destination. This avoids starting AI, sync or
    // report work for screens the user has never opened.
    final page = switch (_currentNavIndex) {
      1 => const StatisticsScreen(),
      2 => const PlanningScreen(embedded: true),
      3 => const ProfileSettingsScreen(embedded: true),
      _ => _dashboard(),
    };
    return Scaffold(
      extendBody: true,
      body: NotebookBackground(child: page),
      bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: NotebookNavigation(
              index: _currentNavIndex,
              menuOpen: _menuOpen,
              onSelect: (value) => setState(() => _currentNavIndex = value),
              onAdd: _openActions)),
    );
  }

  Widget _dashboard() {
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final summary = summaryAsync.valueOrNull;
    final profile = ref.watch(profileProvider).valueOrNull;
    final unread = ref.watch(unreadNotificationCountProvider);
    return RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverSafeArea(
                  bottom: false,
                  sliver: SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                          child: _header(profile, unread)))),
              SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverToBoxAdapter(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const SyncIndicator(),
                        if (summaryAsync.hasError)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextButton.icon(
                                  onPressed: _refresh,
                                  icon: const Icon(Icons.cloud_off_outlined),
                                  label: Text(
                                      friendlyError(summaryAsync.error!)))),
                        _spendingCard(summary),
                        const SizedBox(height: 18),
                        _quickActions(),
                        const SizedBox(height: 22),
                        _section('Tổng quan nhanh', 'Xem tất cả',
                            () => setState(() => _currentNavIndex = 1)),
                        const SizedBox(height: 12),
                        _overview(summary),
                        const SizedBox(height: 20),
                        _insight(summary),
                        const SizedBox(height: 22),
                        _section(
                            'Giao dịch gần đây',
                            'Xem tất cả',
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const TransactionHistoryScreen()))),
                        const SizedBox(height: 10),
                        _recent(ref.watch(recentTransactionsProvider)),
                        const SizedBox(height: 120),
                      ]))),
            ]));
  }

  Widget _header(UserProfile? profile, int unread) => Row(children: [
        InkWell(
            onTap: () => setState(() => _currentNavIndex = 3),
            borderRadius: BorderRadius.circular(25),
            child: CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.primaryFixed,
                backgroundImage: profile?.avatarUrl == null
                    ? null
                    : NetworkImage(profile!.avatarUrl!),
                child: profile?.avatarUrl == null
                    ? Text(profile?.initials ?? 'T',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800))
                    : null)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              DateTime.now().hour < 12
                  ? 'Chào buổi sáng,'
                  : DateTime.now().hour < 18
                      ? 'Chào buổi chiều,'
                      : 'Chào buổi tối,',
              style: const TextStyle(fontSize: 12)),
          Text(profile?.displayName ?? 'Bạn',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          const Text('Ghi chép hôm nay, sống chủ động hơn',
              style:
                  TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
        ])),
        IconButton(
            tooltip: 'Thông báo',
            onPressed: () => _showNotificationBottomSheet(context),
            icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications_none_rounded))),
      ]);

  Widget _spendingCard(MonthlySummary? summary) {
    final month = summary?.month ?? DateTime.now();
    final budget = summary?.totalBudget;
    final ratio = budget?.ratio ?? 0;
    return Container(
        width: double.infinity,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  Color(0xFF006443),
                  Color(0xFF00976D),
                  Color(0xFF58C78B)
                ]),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: .2),
                  blurRadius: 22,
                  offset: const Offset(0, 8))
            ]),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(children: [
              Positioned(right: -35, top: -42, child: _orb(150, .09)),
              Positioned(right: -14, bottom: -85, child: _orb(190, .1)),
              Positioned(
                  right: 12,
                  top: 24,
                  child: Icon(Icons.spa_rounded,
                      size: 74, color: Colors.white.withValues(alpha: .18))),
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text('Tổng chi tiêu tháng ${month.month}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600))),
                          SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                  padding: EdgeInsets.zero,
                                  tooltip: _isBalanceVisible
                                      ? 'Ẩn số tiền'
                                      : 'Hiện số tiền',
                                  onPressed: () => setState(() =>
                                      _isBalanceVisible = !_isBalanceVisible),
                                  icon: Icon(
                                      _isBalanceVisible
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.white70,
                                      size: 19)))
                        ]),
                        Text(
                            '01/${month.month.toString().padLeft(2, '0')} – ${DateTime(month.year, month.month + 1, 0).day}/${month.month}/${month.year}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white70)),
                        const SizedBox(height: 14),
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                                !_isBalanceVisible
                                    ? '••••••••'
                                    : summary == null
                                        ? '…'
                                        : CurrencyFormatter.formatVND(
                                            summary.expense),
                                style: const TextStyle(
                                    fontSize: 34,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.2))),
                        const SizedBox(height: 18),
                        ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                                value: budget == null ? 0 : ratio.clamp(0, 1),
                                minHeight: 9,
                                backgroundColor:
                                    Colors.white.withValues(alpha: .22),
                                valueColor: AlwaysStoppedAnimation(ratio > 1
                                    ? const Color(0xFFFFCF91)
                                    : AppColors.primaryFixed))),
                        const SizedBox(height: 9),
                        Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                  budget == null
                                      ? 'Chưa đặt ngân sách'
                                      : 'Đã chi ${(ratio * 100).round()}%',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  budget == null
                                      ? 'Đặt hạn mức trong Kế hoạch'
                                      : _isBalanceVisible
                                          ? 'Hạn mức ${CurrencyFormatter.formatVND(budget.limitAmount)}'
                                          : 'Hạn mức ••••',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 10)),
                            ]),
                      ])),
            ])));
  }

  Widget _orb(double size, double opacity) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity)));

  Widget _quickActions() =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _quick('Thêm\nchi tiêu', Icons.add_rounded, AppColors.primary,
            () => _addTransaction(TransactionType.expense)),
        const SizedBox(width: 9),
        _quick(
            'Thu nhập',
            Icons.arrow_upward_rounded,
            AppColors.primaryContainer,
            () => _addTransaction(TransactionType.income)),
        const SizedBox(width: 9),
        _quick(
            'Sổ nợ',
            Icons.handshake_outlined,
            const Color(0xFFE58D27),
            () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const PlanningScreen(initialTab: PlanningTab.debts)))),
        const SizedBox(width: 9),
        _quick('Ngân sách', Icons.donut_large_rounded, AppColors.secondary,
            () => setState(() => _currentNavIndex = 2)),
      ]);

  Widget _quick(String label, IconData icon, Color color, VoidCallback onTap) =>
      Expanded(
          child: GlassCard(
              radius: 20,
              child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 13, horizontal: 3),
                      child: Column(children: [
                        TintedIcon(icon, color: color, size: 40),
                        const SizedBox(height: 9),
                        SizedBox(
                            height: 32,
                            child: Center(
                                child: Text(label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600)))),
                      ])))));

  Widget _section(String title, String action, VoidCallback onTap) =>
      Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800))),
        InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Text(action,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant)),
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppColors.onSurfaceVariant)
                ]))),
      ]);

  Widget _overview(MonthlySummary? summary) {
    String money(int? value) => !_isBalanceVisible
        ? '••••••'
        : value == null
            ? '…'
            : CurrencyFormatter.formatVND(value, showSign: value < 0);
    final items = [
      (
        'Thu nhập',
        money(summary?.income),
        Icons.arrow_upward_rounded,
        AppColors.primary
      ),
      (
        'Chi tiêu',
        money(summary?.expense),
        Icons.arrow_downward_rounded,
        AppColors.error
      ),
      (
        'Thu − chi tháng',
        money(summary == null ? null : summary.income - summary.expense),
        Icons.account_balance_wallet_outlined,
        const Color(0xFF238BCC)
      ),
      (
        'Số dư ghi chép',
        money(summary?.totalBalance),
        Icons.account_balance_outlined,
        const Color(0xFF238BCC)
      ),
    ];
    return LayoutBuilder(
        builder: (context, bounds) =>
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final item in items)
                SizedBox(
                    width: (bounds.maxWidth - 10) / 2,
                    child: GlassCard(
                        radius: 20,
                        padding: const EdgeInsets.all(13),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TintedIcon(item.$3, color: item.$4, size: 32),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(item.$1,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.onSurfaceVariant)),
                                    const SizedBox(height: 5),
                                    FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(item.$2,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800))),
                                  ])),
                            ]))),
            ]));
  }

  Widget _insight(MonthlySummary? summary) => GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdvisorScreen())),
          child: Row(children: [
            const TintedIcon(Icons.auto_awesome_rounded,
                color: AppColors.secondary, size: 38),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Một chút chủ động mỗi ngày',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      summary == null
                          ? 'Đang tổng hợp ghi chép của bạn…'
                          : 'Hôm nay bạn đã chi ${CurrencyFormatter.formatVND(summary.expenseOn(DateTime.now()))}. Cùng xem gợi ý từ cố vấn.',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                          height: 1.6)),
                ])),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ])));

  Widget _recent(AsyncValue<List<TransactionModel>> transactions) =>
      transactions.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator())),
          error: (e, _) => Text(friendlyError(e)),
          data: (items) => items.isEmpty
              ? const GlassCard(
                  padding: EdgeInsets.all(24),
                  child: Text('Chưa có giao dịch. Bấm [+] để bắt đầu ghi chép.',
                      textAlign: TextAlign.center))
              : GlassCard(
                  radius: 22,
                  child: Column(children: [
                    for (final tx in items.take(5))
                      ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          onTap: () => _editTransaction(tx),
                          leading: TintedIcon(tx.icon,
                              color: colorFromHex(tx.categoryColor) ??
                                  AppColors.primary,
                              size: 40),
                          title: Text(tx.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              '${tx.categoryName ?? 'Chưa phân loại'} · ${_formatWhen(tx.occurredAt)}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant)),
                          trailing: Text(
                              _isBalanceVisible
                                  ? CurrencyFormatter.formatVND(tx.signedAmount,
                                      showSign: true)
                                  : '•••••',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: tx.isIncome
                                      ? AppColors.primary
                                      : AppColors.error))),
                  ])));

  void _showNotificationBottomSheet(BuildContext context) {
    final notifications = ref.read(notificationsProvider).valueOrNull ??
        const <NotificationModel>[];
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                          child: const Icon(Icons.notifications_active,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trung tâm thông báo',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface),
                            ),
                            Text(
                              unread > 0
                                  ? '$unread thông báo mới chưa đọc'
                                  : 'Bạn đã xem hết thông báo',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant),
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
                          style: TextStyle(
                              fontSize: 13, color: AppColors.onSurfaceVariant),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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
        color: isUnread
            ? AppColors.primary.withOpacity(0.04)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? AppColors.primary.withOpacity(0.2)
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
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(time,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          height: 1.3),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(tag,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11)),
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
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(actionText,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold)),
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
        const Text(
            'Các khoản dưới đây đã đến hạn. Đã trả hoặc đã nhận tiền thì xác nhận để cập nhật sổ nợ nhé.',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (final d in debts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              d.type == DebtType.borrow
                  ? 'Tôi nợ ${d.personName}'
                  : '${d.personName} nợ tôi',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
                '${CurrencyFormatter.formatVND(d.remaining)} • ${d.dueLabel(today) ?? ''}',
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
