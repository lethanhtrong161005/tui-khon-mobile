export '../../features/reminders/data/reminder_scheduler.dart'
    show pendingNotificationRouteProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/planning/models/planning_models.dart';
import '../../features/reminders/data/reminder_scheduler.dart';
import '../utils/currency_formatter.dart';

abstract class DebtReminders {
  Future<void> sync(List<DebtModel> debts);
}

class LocalDebtReminders implements DebtReminders {
  LocalDebtReminders([ReminderScheduler? scheduler])
      : _scheduler = scheduler ?? ReminderScheduler(onRoute: (_) {});
  final ReminderScheduler _scheduler;
  @override
  Future<void> sync(List<DebtModel> debts) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final notices = <ReminderNotice>[];
      if (prefs.getBool('reminder_debts') ?? true) {
        for (final debt in debts) {
          if (debt.isSettled ||
              debt.remaining <= 0 ||
              debt.dueDate == null ||
              debt.id == null) continue;
          final due = debt.dueDate!;
          for (final before in [1, 0]) {
            notices.add(ReminderNotice(
                '${debt.id}:$before',
                before == 1
                    ? 'Ngày mai đến hạn trả nợ'
                    : 'Hôm nay đến hạn trả nợ',
                '${debt.personName} · ${CurrencyFormatter.formatVND(debt.remaining)}',
                DateTime(due.year, due.month, due.day - before, 8),
                '/planning/debts/${debt.id}'));
          }
        }
      }
      notices.sort((a, b) => a.date.compareTo(b.date));
      await _scheduler.replace('debts', notices);
    } catch (e) {
      debugPrint('Debt reminders not scheduled: $e');
    }
  }
}

final debtRemindersProvider = Provider<DebtReminders>(
    (ref) => LocalDebtReminders(ref.watch(reminderSchedulerProvider)));
