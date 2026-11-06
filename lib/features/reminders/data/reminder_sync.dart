import '../../../core/theme/appearance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/debt_reminder_service.dart';
import '../../planning/data/planning_repository.dart';
import 'payable_repository.dart';
import 'reminder_scheduler.dart';

/// Watch at the authenticated app root to refresh schedules on launch and local
/// changes. Permission prompts are reserved for the settings screen.
final reminderSyncProvider = FutureProvider<void>((ref) async {
  var active = true;
  ref.onDispose(() => active = false);
  ref.watch(effectiveLocaleProvider);
  final scheduler = ref.watch(reminderSchedulerProvider);
  final debts = await ref.watch(debtsProvider.future);
  if (!active) return;
  final payables = await ref.watch(payablesProvider.future);
  if (!active) return;
  final payments = await ref.watch(payablePaymentsProvider.future);
  if (!active) return;
  await ref.read(debtRemindersProvider).sync(debts);
  if (!active) return;
  await scheduler.syncPayables(
      payables,
      payments
          .where((p) => p['status'] == 'paid')
          .map((p) => p['id'] as String)
          .toSet());
  if (!active) return;
  await scheduler.syncGeneral();
});
