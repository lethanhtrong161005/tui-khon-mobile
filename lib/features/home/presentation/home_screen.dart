import '../../../core/utils/debt_labels.dart';
import '../../../core/utils/localized_format.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/home_widget/home_widget_controller.dart';
import '../../../core/services/app_lock_service.dart';
import '../../auth/presentation/app_lock_screen.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/offline/sync_controller.dart';
import '../../../core/offline/sync_screen.dart';
import '../../../core/utils/category_icons.dart';
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
  bool _entryScheduled = false;
  bool _entryBusy = false;
  bool _debtsChecked = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(localStoreProvider) != null) {
      ref.listenManual<String?>(
          pendingNotificationRouteProvider, (_, route) => _scheduleEntryWork(),
          fireImmediately: true);
    }
  }

  bool get _entryReady {
    if (!mounted ||
        !ref.read(homeWidgetForegroundProvider) ||
        !ref.read(homeWidgetStartupProvider).hasValue ||
        ModalRoute.of(context)?.isCurrent != true ||
        ref.read(appNavigationObserverProvider).hasOverlays ||
        ref.read(currentUserIdProvider) == null) return false;
    final lock = ref.read(appLockEnabledProvider);
    if (lock.isLoading ||
        lock.hasError ||
        (lock.valueOrNull == true && !ref.read(appUnlockedProvider)))
      return false;
    return ref.read(localStoreProvider) == null ||
        ref.read(syncControllerProvider).initialized;
  }

  void _scheduleEntryWork() {
    if (_entryScheduled || !mounted) return;
    _entryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _entryScheduled = false;
      if (!_entryReady || _entryBusy) return;
      _entryBusy = true;
      final controller = ref.read(homeWidgetControllerProvider.notifier);
      final request = controller.begin();
      try {
        if (request != null) {
          if (request.action == HomeWidgetAction.quickRecord ||
              request.action == HomeWidgetAction.scanReceipt) {
            await Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => QuickRecordScreen(
                        initialAction:
                            request.action == HomeWidgetAction.scanReceipt
                                ? QuickRecordStart.scan
                                : QuickRecordStart.none)));
          } else {
            await _addTransaction(request.action == HomeWidgetAction.income
                ? TransactionType.income
                : TransactionType.expense);
          }
        } else {
          final route = ref.read(localStoreProvider) == null
              ? null
              : ref.read(pendingNotificationRouteProvider);
          if (route != null) {
            await _openNotification(route);
          } else if (!_debtsChecked) {
            await _checkDebts();
          }
        }
      } finally {
        if (request != null) controller.finish(request.id);
        _entryBusy = false;
        if (mounted && (request != null || controller.hasWork)) {
          _scheduleEntryWork();
          WidgetsBinding.instance.ensureVisualUpdate();
        }
      }
    });
  }

  Future<void> _openNotification(String route) async {
    ref.read(pendingNotificationRouteProvider.notifier).state = null;
    if (route.contains('/debts/')) {
      final id = route.split('/').last;
      final debt = (await ref.read(debtsProvider.future))
          .where((d) => d.id == id)
          .firstOrNull;
      if (!mounted) return;
      if (debt != null) {
        await Navigator.push(context,
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
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  /// On opening the app: re-schedule device reminders and ask about debts
  /// that are due today or overdue.
  Future<void> _checkDebts() async {
    List<DebtModel> debts;
    try {
      debts = await ref.read(debtsProvider.future);
    } catch (_) {
      _debtsChecked = true;
      return;
    }
    if (!_entryReady ||
        ref.read(homeWidgetControllerProvider.notifier).hasWork) {
      return;
    }
    _debtsChecked = true;
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
    if (!mounted) return;
    final draft = await showTransactionFormSheet(context,
        initial: tx.toDraft(), excludingId: tx.id);
    if (draft == null || !mounted) return;
    try {
      await ref.read(walletRepositoryProvider).updateTransaction(tx.id, draft);
      ref.refreshWalletData();
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e, context: context));
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
    final account = ref.read(currentUserIdProvider);
    final draft = await showTransactionFormSheet(context,
        initial: TransactionDraft(type: type, amount: 0));
    if (draft == null || !mounted || ref.read(currentUserIdProvider) != account)
      return;
    try {
      await ref.saveTransaction(draft);
      if (mounted) showToast(context, appL10n(context).msgTransactionSaved145);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e, context: context));
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
    ref.watch(homeWidgetControllerProvider);
    ref.watch(homeWidgetStartupProvider);
    ref.watch(homeWidgetForegroundProvider);
    ref.watch(appNavigationObserverProvider);
    ref.watch(appLockEnabledProvider);
    ref.watch(appUnlockedProvider);
    _scheduleEntryWork();
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
      extendBody: false,
      body: NotebookBackground(
          child: SafeArea(
              top: false,
              bottom: false,
              child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: page)))),
      bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Align(
              heightFactor: 1,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: NotebookNavigation(
                      index: _currentNavIndex,
                      menuOpen: _menuOpen,
                      onSelect: (value) =>
                          setState(() => _currentNavIndex = value),
                      onAdd: _openActions)))),
    );
  }

  Widget _dashboard() {
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final summary = summaryAsync.valueOrNull;
    final profile = ref.watch(profileProvider).valueOrNull;
    final unread = ref.watch(unreadNotificationCountProvider);
    return RefreshIndicator(
        onRefresh: _refresh,
        color: appPalette(context).primary,
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
                                  label: Text(friendlyError(summaryAsync.error!,
                                      context: context)))),
                        _spendingCard(summary),
                        const SizedBox(height: 18),
                        _quickActions(),
                        const SizedBox(height: 22),
                        _section(
                            appL10n(context).msgQuickOverview146,
                            appL10n(context).msgViewAll147,
                            () => setState(() => _currentNavIndex = 1)),
                        const SizedBox(height: 12),
                        _overview(summary),
                        const SizedBox(height: 20),
                        _insight(summary),
                        const SizedBox(height: 22),
                        _section(
                            appL10n(context).msgRecentTransactions148,
                            appL10n(context).msgViewAll147,
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const TransactionHistoryScreen()))),
                        const SizedBox(height: 10),
                        _recent(ref.watch(recentTransactionsProvider)),
                        const SizedBox(height: 24),
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
                        style: TextStyle(
                            color: appPalette(context).primary,
                            fontWeight: FontWeight.w800))
                    : null)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              DateTime.now().hour < 12
                  ? appL10n(context).msgGoodMorning149
                  : DateTime.now().hour < 18
                      ? appL10n(context).msgGoodAfternoon150
                      : appL10n(context).msgGoodEvening151,
              style: const TextStyle(fontSize: 12)),
          Text(profile?.displayName ?? appL10n(context).msgYou152,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(appL10n(context).msgRecordTodayPlanForTomorrow153,
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
        IconButton(
            tooltip: appL10n(context).msgNotifications15,
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
                colors: const [
                  Color(0xFF006443),
                  Color(0xFF00976D),
                  Color(0xFF58C78B)
                ]),
            boxShadow: [
              BoxShadow(
                  color: appPalette(context).primary.withValues(alpha: .2),
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
                              child: Text(
                                  appL10n(context).msgTotalSpendingInMonth154(
                                      (month.month).toString()),
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
                                      ? appL10n(context).msgHideAmounts155
                                      : appL10n(context).msgShowAmounts156,
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
                                        : formatMoney(context, summary.expense),
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
                                backgroundColor: appPalette(context)
                                    .surfaceContainer
                                    .withValues(alpha: .22),
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
                                      ? appL10n(context).msgNoBudgetSet157
                                      : appL10n(context).msgSpent158(
                                          ((ratio * 100).round()).toString()),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  budget == null
                                      ? appL10n(context)
                                          .msgSetALimitInPlanning159
                                      : _isBalanceVisible
                                          ? appL10n(context).msgLimit160(
                                              (formatMoney(context,
                                                      budget.limitAmount))
                                                  .toString())
                                          : appL10n(context).msgLimit161,
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
          color:
              appPalette(context).surfaceContainer.withValues(alpha: opacity)));

  Widget _quickActions() =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _quick(
            appL10n(context).msgAddExpense162,
            Icons.add_rounded,
            appPalette(context).primary,
            () => _addTransaction(TransactionType.expense)),
        const SizedBox(width: 9),
        _quick(
            appL10n(context).msgIncome163,
            Icons.arrow_upward_rounded,
            AppColors.primaryContainer,
            () => _addTransaction(TransactionType.income)),
        const SizedBox(width: 9),
        _quick(
            appL10n(context).msgDebtBook9,
            Icons.handshake_outlined,
            const Color(0xFFE58D27),
            () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const PlanningScreen(initialTab: PlanningTab.debts)))),
        const SizedBox(width: 9),
        _quick(
            appL10n(context).msgBudgets8,
            Icons.donut_large_rounded,
            appPalette(context).secondary,
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
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  Icon(Icons.chevron_right_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)
                ]))),
      ]);

  Widget _overview(MonthlySummary? summary) {
    String money(int? value) => !_isBalanceVisible
        ? '••••••'
        : value == null
            ? '…'
            : formatMoney(context, value, showSign: value < 0);
    final items = [
      (
        appL10n(context).msgIncome163,
        money(summary?.income),
        Icons.arrow_upward_rounded,
        appPalette(context).primary
      ),
      (
        appL10n(context).msgExpenses164,
        money(summary?.expense),
        Icons.arrow_downward_rounded,
        appPalette(context).error
      ),
      (
        appL10n(context).msgMonthlyNetIncome165,
        money(summary == null ? null : summary.income - summary.expense),
        Icons.account_balance_wallet_outlined,
        const Color(0xFF238BCC)
      ),
      (
        appL10n(context).msgRecordedBalance166,
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
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant)),
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
            TintedIcon(Icons.auto_awesome_rounded,
                color: appPalette(context).secondary, size: 38),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(appL10n(context).msgALittlePlanningEveryDay167,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      summary == null
                          ? appL10n(context).msgSummarizingYourRecords168
                          : appL10n(context)
                              .msgYouSpentTodaySeeSuggestionsFrom169(
                                  (formatMoney(context,
                                          summary.expenseOn(DateTime.now())))
                                      .toString()),
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.6)),
                ])),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ])));

  Widget _recent(AsyncValue<List<TransactionModel>> transactions) =>
      transactions.when(
          loading: () => const Center(
              child: const Padding(
                  padding: const EdgeInsets.all(24),
                  child: const CircularProgressIndicator())),
          error: (e, _) => Text(friendlyError(e, context: context)),
          data: (items) => items.isEmpty
              ? GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      appL10n(context).msgNoTransactionsYetTapToStart170,
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
                                  appPalette(context).primary,
                              size: 40),
                          title: Text(transactionDisplayTitle(context, tx),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              '${tx.categoryName ?? appL10n(context).msgUncategorized441} · ${_formatWhen(tx.occurredAt)}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                          trailing: Text(
                              _isBalanceVisible
                                  ? formatMoney(context, tx.signedAmount,
                                      showSign: true)
                                  : '•••••',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: tx.isIncome
                                      ? appPalette(context).primary
                                      : appPalette(context).error))),
                  ])));

  void _showNotificationBottomSheet(BuildContext context) {
    final notifications =
        ref.read(notificationsProvider).valueOrNull ?? <NotificationModel>[];
    final unread = notifications.where((n) => !n.isRead).length;
    if (unread > 0) _markNotificationsRead();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: appPalette(context).surfaceContainer,
            borderRadius:
                const BorderRadius.vertical(top: const Radius.circular(28)),
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
                            color: appPalette(context).primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.notifications_active,
                              color: appPalette(context).primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appL10n(context).msgNotificationCenter171,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                            ),
                            Text(
                              unread > 0
                                  ? appL10n(context).msgUnreadNotifications172(
                                      (unread).toString())
                                  : appL10n(context).msgYouAreAllCaughtUp173,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
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
                    ? Center(
                        child: Text(
                          appL10n(context).msgNoNotificationsYet174,
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
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
  String _formatWhen(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    String two(int v) => v.toString().padLeft(2, '0');
    if (day == today) return '${two(time.hour)}:${two(time.minute)}';
    if (day == today.subtract(const Duration(days: 1)))
      return appL10n(context).msgYesterday175;
    return '${two(time.day)}/${two(time.month)}';
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return appL10n(context).msgJustNow176;
    if (diff.inMinutes < 60)
      return appL10n(context).msgMinutesAgo177((diff.inMinutes).toString());
    if (diff.inHours < 24)
      return appL10n(context).msgHoursAgo178((diff.inHours).toString());
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
            ? appPalette(context).primary.withOpacity(0.04)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? appPalette(context).primary.withOpacity(0.2)
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
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface),
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
                      color: appPalette(context).surfaceContainer,
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
                      backgroundColor: appPalette(context).primary,
                      foregroundColor: appPalette(context).onPrimary,
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
      title: appL10n(context).msgDebtPaymentsAreDue179,
      submitLabel: appL10n(context).msgLater180,
      onSubmit: () => Navigator.pop(context),
      children: [
        Text(appL10n(context).msgTheseDebtsAreDueIfYou181,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (final d in debts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              d.type == DebtType.borrow
                  ? appL10n(context).msgIOwe182((d.personName).toString())
                  : appL10n(context).msgOwesMe183((d.personName).toString()),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
                '${formatMoney(context, d.remaining)} • ${debtDueLabel(context, d, today) ?? ''}',
                style: TextStyle(color: appPalette(context).error)),
            trailing: TextButton(
              onPressed: () async {
                final done = await showSettleDebtDialog(context, ref, d);
                if (done && context.mounted) Navigator.pop(context);
              },
              child: Text(d.type == DebtType.borrow
                  ? appL10n(context).msgPaid184
                  : appL10n(context).msgCollected185),
            ),
          ),
      ],
    );
  }
}
