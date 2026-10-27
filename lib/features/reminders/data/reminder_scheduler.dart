import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/payable.dart';

final pendingNotificationRouteProvider = StateProvider<String?>((ref) => null);
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) =>
    ReminderScheduler(
        onRoute: (route) =>
            ref.read(pendingNotificationRouteProvider.notifier).state = route));

int reminderNotificationId(String group, String key) {
  var hash = 2166136261;
  for (final c in '$group:$key'.codeUnits) {
    hash = ((hash ^ c) * 16777619) & 0x7fffffff;
  }
  final prefix = {'debts': 1, 'payables': 2, 'diary': 3, 'report': 4}[group]!;
  return prefix * 100000000 + hash % 100000000;
}

class ReminderNotice {
  const ReminderNotice(this.key, this.title, this.body, this.date, this.route);
  final String key, title, body, route;
  final DateTime date;
}

class ReminderScheduler {
  ReminderScheduler({required this.onRoute});
  final void Function(String) onRoute;
  final plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;
  Future<void> _tail = Future.value();
  Future<void> _init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await plugin.initialize(
        settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false)),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) onRoute(response.payload!);
        });
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse?.payload != null)
      onRoute(launch!.notificationResponse!.payload!);
  }

  Future<void> requestPermission() async {
    if (kIsWeb) return;
    await (_ready ??= _init());
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> replace(String group, List<ReminderNotice> notices) {
    final result = _tail.then((_) => _replace(group, notices));
    _tail = result.catchError((Object e) {
      debugPrint('Reminder scheduling failed: $e');
    });
    return result;
  }

  Future<void> _replace(String group, List<ReminderNotice> notices) async {
    if (kIsWeb) return;
    await (_ready ??= _init());
    final prefs = await SharedPreferences.getInstance();
    final key = 'reminder_ids_$group';
    final previous = prefs.getStringList(key) ?? [];
    for (final id in previous) {
      await plugin.cancel(id: int.parse(id));
    }
    final future =
        notices.where((n) => n.date.isAfter(DateTime.now())).take(24).toList();
    // Persist before scheduling, so interrupted scheduling can still be cancelled.
    await prefs.setStringList(key,
        future.map((n) => '${reminderNotificationId(group, n.key)}').toList());
    for (final n in future) {
      await plugin.zonedSchedule(
          id: reminderNotificationId(group, n.key),
          title: n.title,
          body: n.body,
          scheduledDate: tz.TZDateTime.from(n.date, tz.local),
          notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                  'reminders_$group', 'Nhắc nhở $group'),
              iOS: const DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: group == 'diary'
              ? DateTimeComponents.time
              : group == 'report'
                  ? DateTimeComponents.dayOfMonthAndTime
                  : null,
          payload: n.route);
    }
  }

  Future<void> syncPayables(List<Payable> payables, Set<String> paid) async {
    final prefs = await SharedPreferences.getInstance();
    final notices = <ReminderNotice>[];
    if (prefs.getBool('reminder_payables') ?? true) {
      final end = DateTime.now().add(const Duration(days: 60));
      for (final p in payables.where((p) => p.active)) {
        for (final date in p.through(end)) {
          if (paid.contains(p.occurrenceId(date))) continue;
          for (final before in [1, 0]) {
            notices.add(ReminderNotice(
                '${p.occurrenceId(date)}:$before',
                'Khoản phải trả',
                p.title,
                DateTime(date.year, date.month, date.day - before, 8),
                '/payables'));
          }
        }
      }
    }
    notices.sort((a, b) => a.date.compareTo(b.date));
    await replace('payables', notices);
  }

  Future<void> syncGeneral() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final hour = (prefs.getInt('reminder_diary_hour') ?? 21).clamp(0, 23);
    final minute = (prefs.getInt('reminder_diary_minute') ?? 0).clamp(0, 59);
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    final first = DateTime(now.year, now.month, 1, 8);
    await replace('diary', [
      if (prefs.getBool('reminder_diary') ?? false)
        ReminderNotice(
            'daily',
            'Ghi chép hôm nay',
            'Dành một phút ghi lại thu chi hôm nay.',
            today.isAfter(now)
                ? today
                : DateTime(now.year, now.month, now.day + 1, hour, minute),
            '/transactions')
    ]);
    await replace('report', [
      if (prefs.getBool('reminder_report') ?? true)
        ReminderNotice(
            'monthly',
            'Báo cáo tháng',
            'Xem lại thu chi tháng vừa qua.',
            first.isAfter(now)
                ? first
                : DateTime(now.year, now.month + 1, 1, 8),
            '/reports')
    ]);
  }
}
