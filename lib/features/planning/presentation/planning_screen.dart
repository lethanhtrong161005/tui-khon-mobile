import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';

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
          backgroundColor: appPalette(context).primary,
          foregroundColor: appPalette(context).onPrimary,
          icon: const Icon(Icons.add),
          label: Text(appL10n(context).msgAddDebt248),
        ),
      PlanningTab.goals => FloatingActionButton.extended(
          onPressed: () => showGoalForm(context),
          backgroundColor: appPalette(context).primary,
          foregroundColor: appPalette(context).onPrimary,
          icon: const Icon(Icons.add),
          label: Text(appL10n(context).msgNewGoal327),
        ),
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: appPalette(context).surface.withValues(alpha: .85),
        automaticallyImplyLeading: !widget.embedded,
        elevation: 0,
        title: Text(appL10n(context).planning,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabs,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
              color: appPalette(context).primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20)),
          dividerColor: Colors.transparent,
          labelColor: appPalette(context).primary,
          indicatorColor: appPalette(context).primary,
          unselectedLabelColor: appPalette(context).onSurfaceVariant,
          tabs: [
            Tab(
                icon: const Icon(Icons.donut_large, size: 20),
                text: appL10n(context).msgBudgets8),
            Tab(
                icon: const Icon(Icons.handshake, size: 20),
                text: appL10n(context).msgDebtBook9),
            Tab(
                icon: const Icon(Icons.savings, size: 20),
                text: appL10n(context).msgGoals11),
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
