import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/planning/models/planning_models.dart';
import '../utils/currency_formatter.dart';

/// Device notifications for the debt book: 08:00 the day before and on the
/// due date. Only debt reminders are scheduled, so [sync] can simply cancel
/// everything and re-schedule from the current list.
abstract class DebtReminders {
  Future<void> sync(List<DebtModel> debts);
}

class LocalDebtReminders implements DebtReminders {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  static const _channel = AndroidNotificationDetails(
    'debt_reminders',
    'Nhắc hạn sổ nợ',
    channelDescription: 'Nhắc trước và đúng ngày đến hạn các khoản nợ',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> _init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    // Android 13+ / iOS ask once; a refusal simply means no device reminders.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  @override
  Future<void> sync(List<DebtModel> debts) async {
    if (kIsWeb) return;
    try {
      await (_ready ??= _init());
      await _plugin.cancelAll();
      final now = tz.TZDateTime.now(tz.local);
      for (final debt in debts) {
        if (debt.isSettled || debt.dueDate == null || debt.id == null) continue;
        for (final (daysBefore, title) in const [(1, 'Ngày mai đến hạn trả nợ'), (0, 'Hôm nay đến hạn trả nợ')]) {
          final due = debt.dueDate!;
          final at = tz.TZDateTime(tz.local, due.year, due.month, due.day - daysBefore, 8);
          if (!at.isAfter(now)) continue;
          await _plugin.zonedSchedule(
            id: _notificationId(debt.id!, daysBefore),
            title: title,
            body: _body(debt),
            scheduledDate: at,
            notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: debt.id,
          );
        }
      }
    } catch (e) {
      // Reminders are a convenience: never break the debt book because of them.
      debugPrint('Debt reminders not scheduled: $e');
    }
  }

  static String _body(DebtModel debt) {
    final money = CurrencyFormatter.formatVND(debt.remaining);
    return debt.type == DebtType.borrow
        ? 'Bạn nợ ${debt.personName} $money. Trả rồi thì xác nhận trong Túi Khôn nhé.'
        : '${debt.personName} nợ bạn $money. Nhận rồi thì xác nhận trong Túi Khôn nhé.';
  }

  /// Stable positive 31-bit id per (debt, reminder).
  static int _notificationId(String debtId, int daysBefore) =>
      ('$debtId-$daysBefore'.hashCode & 0x3fffffff);
}

final debtRemindersProvider = Provider<DebtReminders>((ref) => LocalDebtReminders());
