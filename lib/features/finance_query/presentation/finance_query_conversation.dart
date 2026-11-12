import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/local_store.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/localized_format.dart';
import '../../../core/widgets/form_sheet.dart' show formatDate;
import '../../../l10n/app_l10n.dart';
import '../data/finance_query_repository.dart';

class _Turn {
  _Turn(this.question, {this.result, this.error});
  final String question;
  final FinanceQueryResult? result;
  final FinanceQueryFailure? error;
  int visible = 20;
}

class FinanceQueryConversation extends ConsumerStatefulWidget {
  const FinanceQueryConversation({super.key, required this.onBusy});
  final ValueChanged<bool> onBusy;
  @override
  ConsumerState<FinanceQueryConversation> createState() =>
      FinanceQueryConversationState();
}

class FinanceQueryConversationState
    extends ConsumerState<FinanceQueryConversation> {
  final _turns = <_Turn>[];
  final _scroll = ScrollController();
  bool _busy = false;
  String? _clarificationFor;
  int _generation = 0;
  void clear() {
    _generation++;
    if (mounted)
      setState(() {
        _turns.clear();
        _clarificationFor = null;
        _busy = false;
      });
  }

  Future<void> send(String question) async {
    if (_busy || question.trim().isEmpty) return;
    final repository = ref.read(financeQueryRepositoryProvider);
    final account = ref.read(currentUserIdProvider);
    final generation = _generation;
    final previous = _turns
        .map((t) => t.result?.plan)
        .whereType<FinanceQueryPlan>()
        .lastOrNull;
    setState(() => _busy = true);
    widget.onBusy(true);
    try {
      if (repository == null) throw const FinanceQueryFailure('offline');
      final result = await repository.ask(
        question,
        previous: previous,
        clarificationFor: _clarificationFor,
      );
      if (!mounted ||
          generation != _generation ||
          account != ref.read(currentUserIdProvider))
        return;
      setState(() {
        _clarificationFor = null;
        _turns.add(_Turn(question, result: result));
      });
    } catch (error) {
      if (!mounted ||
          generation != _generation ||
          account != ref.read(currentUserIdProvider))
        return;
      if (error is FinanceQueryFailure &&
          ['clarification', 'ambiguous'].contains(error.code)) {
        _clarificationFor ??= question;
      }
      setState(
        () => _turns.add(
          _Turn(
            question,
            error: error is FinanceQueryFailure
                ? error
                : const FinanceQueryFailure('offline'),
          ),
        ),
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        widget.onBusy(false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients)
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localRevisionProvider);
    final l = appL10n(context);
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.financeQueryIntro),
        const SizedBox(height: 8),
        Text(
          l.financeQueryExamples,
          style: TextStyle(color: appPalette(context).onSurfaceVariant),
        ),
        for (final turn in _turns) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              turn.question,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: turn.result == null
                  ? Text(_error(turn.error!))
                  : _result(turn),
            ),
          ),
        ],
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  String _error(FinanceQueryFailure failure) {
    final l = appL10n(context);
    return switch (failure.code) {
      'ambiguous' => '${l.financeQueryAmbiguous}\n${failure.detail}',
      'clarification' => failure.detail,
      'changed' => l.financeQueryChanged,
      'readOnly' => l.financeQueryReadOnly,
      'quota' => l.financeQueryQuota,
      'auth' => l.financeQueryAuth,
      'monthlyBudget' => l.financeQueryMonthlyBudget,
      'invalid' => l.financeQueryInvalid,
      _ => l.financeQueryOffline,
    };
  }

  Widget _result(_Turn turn) {
    final result = turn.result!, plan = result.plan, l = appL10n(context);
    final dated =
        [
          FinanceQueryKind.summary,
          FinanceQueryKind.comparison,
          FinanceQueryKind.ranking,
          FinanceQueryKind.transactions,
          FinanceQueryKind.budgets,
          FinanceQueryKind.payables,
        ].contains(plan.kind) ||
        plan.periodFilter;
    String type(String? value) => switch (value) {
      'income' => l.financeIncome,
      'expense' => l.financeExpense,
      'borrow' => l.financeBorrow,
      'lend' => l.financeLend,
      _ => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _title(plan.kind),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        Text(
          dated
              ? '${formatDate(plan.from)} – ${formatDate(plan.to.subtract(const Duration(days: 1)))} · ${l.financeVietnamTime}'
              : l.financeCurrentSnapshot,
        ),
        if (result.categoryName != null)
          Text('${l.financeCategory}: ${result.categoryName}'),
        if (result.walletName != null)
          Text('${l.financeWallet}: ${result.walletName}'),
        if (plan.type != null) Text(type(plan.type)),
        if (plan.search.isNotEmpty) Text('${l.financeFilter}: ${plan.search}'),
        if (result.pending > 0) Text(l.financeUnsynced),
        if (result.revision != ref.read(localStoreProvider)?.revision)
          Text(
            l.financeQueryChanged,
            style: TextStyle(color: appPalette(context).error),
          ),
        const SizedBox(height: 8),
        if ([
          FinanceQueryKind.summary,
          FinanceQueryKind.comparison,
          FinanceQueryKind.transactions,
        ].contains(plan.kind)) ...[
          Text('${l.financeIncome}: ${formatMoney(context, result.income)}'),
          Text('${l.financeExpense}: ${formatMoney(context, result.expense)}'),
          if (result.previousExpense != null) ...[
            Text(
              '${l.financePreviousIncome}: ${formatMoney(context, result.previousIncome!)}',
            ),
            Text(
              '${l.financePreviousExpense}: ${formatMoney(context, result.previousExpense!)}',
            ),
            Text(
              '${l.financeExpenseChange}: ${formatMoney(context, result.expense - result.previousExpense!)}',
            ),
          ],
        ],
        if (plan.kind == FinanceQueryKind.balances ||
            plan.kind == FinanceQueryKind.payables)
          Text(
            '${l.financeTotal}: ${formatMoney(context, result.entries.fold<int>(0, (sum, e) => sum + e.amount))}',
          ),
        if (plan.kind == FinanceQueryKind.debts) ...[
          Text(
            '${l.financeBorrow}: ${formatMoney(context, result.entries.where((e) => e.type == 'borrow').fold<int>(0, (sum, e) => sum + e.amount))}',
          ),
          Text(
            '${l.financeLend}: ${formatMoney(context, result.entries.where((e) => e.type == 'lend').fold<int>(0, (sum, e) => sum + e.amount))}',
          ),
        ],
        if (result.entries.isEmpty) Text(l.financeNoMatches),
        if (plan.kind == FinanceQueryKind.budgets)
          Text(l.financeBudgetRemaining),
        if (plan.kind == FinanceQueryKind.goals) Text(l.financeGoalSaved),
        Text('${l.financeEvidence}: ${result.entries.length}'),
        for (final entry in result.entries.take(turn.visible))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label.isEmpty ? l.financeUncategorized : entry.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${type(entry.type)} ${formatMoney(context, entry.amount)}${entry.target == null ? '' : ' / ${formatMoney(context, entry.target!)}'}',
                ),
                if (entry.date != null) Text(formatDate(entry.date!)),
              ],
            ),
          ),
        if (result.entries.length > turn.visible)
          TextButton(
            onPressed: () => setState(() => turn.visible += 20),
            child: Text(l.financeShowMore),
          ),
      ],
    );
  }

  String _title(FinanceQueryKind kind) {
    final l = appL10n(context);
    return switch (kind) {
      FinanceQueryKind.summary => l.financeSummary,
      FinanceQueryKind.comparison => l.financeComparison,
      FinanceQueryKind.ranking => l.financeRanking,
      FinanceQueryKind.transactions => l.financeTransactions,
      FinanceQueryKind.balances => l.financeBalances,
      FinanceQueryKind.budgets => l.financeBudgets,
      FinanceQueryKind.debts => l.financeDebts,
      FinanceQueryKind.payables => l.financePayables,
      FinanceQueryKind.goals => l.financeGoals,
    };
  }
}
