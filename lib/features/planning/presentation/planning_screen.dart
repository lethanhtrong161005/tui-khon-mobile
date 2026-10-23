import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/planning_models.dart';
import 'budgets_tab.dart';
import 'debts_tab.dart';
import 'goals_tab.dart';

enum PlanningTab { budgets, debts, goals }

/// "Kế hoạch": monthly budgets, the debt book and savings goals.
class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key, this.initialTab = PlanningTab.budgets});

  final PlanningTab initialTab;

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.index)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fab = switch (PlanningTab.values[_tabs.index]) {
      PlanningTab.budgets => null, // the budgets tab has its own buttons (month-specific)
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Kế hoạch', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabs,
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
      floatingActionButton: fab,
      body: TabBarView(
        controller: _tabs,
        children: const [BudgetsTab(), DebtsTab(), GoalsTab()],
      ),
    );
  }
}
