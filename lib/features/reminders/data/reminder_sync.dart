import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/debt_reminder_service.dart';
import '../../planning/data/planning_repository.dart';
import 'payable_repository.dart';
import 'reminder_scheduler.dart';

/// Watch at the authenticated app root to refresh schedules on launch and local
/// changes. Permission prompts are reserved for the settings screen.
final reminderSyncProvider = FutureProvider<void>((ref) async {
  final scheduler = ref.watch(reminderSchedulerProvider);
  final debts = await ref.watch(debtsProvider.future);
  final payables = await ref.watch(payablesProvider.future);
  final payments = await ref.watch(payablePaymentsProvider.future);
  await ref.read(debtRemindersProvider).sync(debts);
  await scheduler.syncPayables(
      payables,
      payments
          .where((p) => p['status'] == 'paid')
          .map((p) => p['id'] as String)
          .toSet());
  await scheduler.syncGeneral();
});
