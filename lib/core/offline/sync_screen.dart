import '../../l10n/app_l10n.dart';
import '../utils/localized_format.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/planning/models/planning_models.dart';
import '../../features/planning/presentation/debt_history_screen.dart';

import 'local_store.dart';
import 'sync_controller.dart';

class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(localStoreProvider) == null) return const SizedBox.shrink();
    final state = ref.watch(syncControllerProvider);
    final label = state.running
        ? appL10n(context).msgSyncing0
        : state.conflicts > 0
            ? appL10n(context).msgItemsNeedReview1(state.conflicts)
            : state.pending > 0
                ? appL10n(context).msgChangesOnThisDevice2(state.pending)
                : appL10n(context).msgSynced3;
    return ListTile(
        dense: true,
        leading: Icon(state.error != null ? Icons.cloud_off : Icons.cloud_sync),
        title: Text(label),
        subtitle: state.error == null
            ? null
            : Text(appL10n(context).msgYourRecordsAreStillSavedOn4),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SyncScreen())));
  }
}

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});
  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  String _entity(Object? key) =>
      {
        'transactions': appL10n(context).msgTransactions5,
        'wallets': appL10n(context).wallets,
        'categories': appL10n(context).categories,
        'budgets': appL10n(context).msgBudgets8,
        'debts': appL10n(context).msgDebtBook9,
        'debt_payments': appL10n(context).msgPaymentHistory10,
        'goals': appL10n(context).msgGoals11,
        'payables': appL10n(context).payables,
        'payable_occurrences': appL10n(context).msgPaymentOccurrence13,
        'category_rules': appL10n(context).msgCategoryRules14,
        'notifications': appL10n(context).msgNotifications15
      }[key] ??
      appL10n(context).msgRecord16;
  String _error(Map<String, dynamic> row) => row['entity'] == 'debt_payments'
      ? appL10n(context).msgCheckThePaymentAmountAndRemaining17
      : appL10n(context)
          .msgCheckTheContentsInThenTry18((_entity(row['entity'])).toString());
  Future<void> _openError(Map<String, dynamic> e) async {
    final row =
        (jsonDecode(e['payload'] as String) as Map).cast<String, dynamic>();
    if (e['entity'] == 'debt_payments') {
      final debt = await ref
          .read(localStoreProvider)!
          .record('debts', row['debt_id'] as String);
      if (debt != null && mounted) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    DebtHistoryScreen(debt: DebtModel.fromJson(debt))));
        if (mounted) setState(() {});
        return;
      }
    }
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(_entity(e['entity'])),
                content: SingleChildScrollView(
                    child: Text(
                        '${_display(e['payload'] as String?, 0)}\n\n${_error(e)}')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(appL10n(context).msgClose19))
                ]));
  }

  Future<void> _resolve(Map<String, dynamic> c, bool keep) async {
    await ref.read(localStoreProvider)!.resolveConflict(
        c['entity'] as String, c['record_id'] as String,
        keepLocal: keep);
    if (!mounted) return;
    await ref.read(syncControllerProvider.notifier).sync();
    if (mounted) setState(() {});
  }

  String _display(String? raw, int deleted) {
    if (deleted == 1) return appL10n(context).msgDeleted20;
    if (raw == null) return appL10n(context).msgDoesNotExistYet21;
    final row = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final fields = [
      'name',
      'person_name',
      'note',
      'type',
      'amount',
      'initial_balance',
      'paid_at',
      'occurred_at',
      'saved_amount',
      'target_amount',
      'limit_amount'
    ];
    final names = {
      'name': appL10n(context).msgName22,
      'person_name': appL10n(context).msgPerson23,
      'note': appL10n(context).msgNote24,
      'type': appL10n(context).msgType25,
      'amount': appL10n(context).msgAmount26,
      'initial_balance': appL10n(context).msgOpeningBalanceVnd440,
      'paid_at': appL10n(context).msgPaymentDate27,
      'occurred_at': appL10n(context).msgDateAndTime28,
      'saved_amount': appL10n(context).msgSaved29,
      'target_amount': appL10n(context).msgGoals11,
      'limit_amount': appL10n(context).msgLimit30
    };
    return fields.where((k) => row[k] != null).map((k) {
      final value = row[k];
      const moneyFields = {
        'amount',
        'initial_balance',
        'saved_amount',
        'target_amount',
        'limit_amount'
      };
      final display = moneyFields.contains(k) && value is num
          ? formatMoney(context, value, showSign: value < 0)
          : '$value';
      return '${names[k]}: $display';
    }).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(localStoreProvider)!;
    final status = ref.watch(syncControllerProvider);
    ref.watch(localRevisionProvider);
    return Scaffold(
        appBar: AppBar(title: Text(appL10n(context).dataSync)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(appL10n(context).msgPendingChangesConflicts32(
              (status.pending).toString(), (status.conflicts).toString())),
          if (status.lastSuccess != null)
            Text(appL10n(context).msgLastSuccessfulSync33(
                financialDateTime(status.lastSuccess!))),
          if (status.error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appL10n(context).syncError,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      ExpansionTile(
                          title: Text(appL10n(context).errorDetails),
                          children: [SelectableText(status.error!)])
                    ])),
          FilledButton.icon(
              onPressed: status.running
                  ? null
                  : () => ref
                      .read(syncControllerProvider.notifier)
                      .sync(retryErrors: true),
              icon: const Icon(Icons.sync),
              label: Text(status.running
                  ? appL10n(context).msgSyncing34
                  : appL10n(context).msgSyncNow35)),
          Text(appL10n(context).msgYourDataStaysOnThisDevice36),
          FutureBuilder(
              future: store.conflicts(),
              builder: (context, snapshot) => Column(children: [
                    for (final c in snapshot.data ?? <Map<String, dynamic>>[])
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_entity(c['entity'])),
                                    const SizedBox(height: 8),
                                    Text(appL10n(context).msgOnThisDevice37,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(_display(c['local_data'] as String?,
                                        c['local_deleted'] as int)),
                                    Text(appL10n(context).msgOnTheServer38,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(_display(c['server_data'] as String?,
                                        c['server_deleted'] as int)),
                                    Wrap(spacing: 8, children: [
                                      TextButton(
                                          onPressed: () => _resolve(c, true),
                                          child: Text(appL10n(context)
                                              .msgKeepDeviceVersion39)),
                                      TextButton(
                                          onPressed: () => _resolve(c, false),
                                          child: Text(appL10n(context)
                                              .msgKeepServerVersion40))
                                    ]),
                                  ])))
                  ])),
          FutureBuilder(
              future: store.errors(),
              builder: (context, snapshot) => Column(children: [
                    for (final e in snapshot.data ?? <Map<String, dynamic>>[])
                      ListTile(
                          leading: const Icon(Icons.error_outline),
                          title: Text(_entity(e['entity'])),
                          subtitle: Text(_error(e)),
                          onTap: () => _openError(e))
                  ])),
        ]));
  }
}
