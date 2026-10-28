import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass.dart';
import '../models/planning_models.dart';
import 'budgets_tab.dart';
import 'debts_tab.dart';
import 'goals_tab.dart';

enum PlanningTab { budgets, debts, goals }

/// "Kế hoạch": monthly budgets, the debt book and savings goals.
class PlanningScreen extends StatefulWidget {
  const PlanningScreen(
      {super.key,
      this.initialTab = PlanningTab.budgets,
      this.embedded = false});

  final PlanningTab initialTab;
  final bool embedded;

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
      length: 3, vsync: this, initialIndex: widget.initialTab.index)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fab = switch (PlanningTab.values[_tabs.index]) {
      PlanningTab.budgets =>
        null, // the budgets tab has its own buttons (month-specific)
      PlanningTab.debts => FloatingActionButton.extended(
          onPressed: () => showDebtForm(context, type: DebtType.borrow),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Thêm khoản nợ'),
        ),
      PlanningTab.goals => FloatingActionButton.extended(
          onPressed: () => showGoalForm(context),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Mục tiêu mới'),
        ),
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: .85),
        automaticallyImplyLeading: !widget.embedded,
        elevation: 0,
        title: const Text('Kế hoạch',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabs,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20)),
          dividerColor: Colors.transparent,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.donut_large, size: 20), text: 'Ngân sách'),
            Tab(icon: Icon(Icons.handshake, size: 20), text: 'Sổ nợ'),
            Tab(icon: Icon(Icons.savings, size: 20), text: 'Mục tiêu'),
          ],
        ),
      ),
      floatingActionButton: fab == null
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: widget.embedded ? 100 : 0),
              child: fab),
      body: NotebookBackground(
          child: TabBarView(
        controller: _tabs,
        children: const [BudgetsTab(), DebtsTab(), GoalsTab()],
      )),
    );
  }
}
