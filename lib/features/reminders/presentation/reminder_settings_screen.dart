import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/debt_reminder_service.dart';
import '../../planning/data/planning_repository.dart';
import '../data/payable_repository.dart';
import '../data/reminder_scheduler.dart';
export '../data/reminder_scheduler.dart' show pendingNotificationRouteProvider;

class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});
  @override
  ConsumerState<ReminderSettingsScreen> createState() =>
      _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState
    extends ConsumerState<ReminderSettingsScreen> {
  SharedPreferences? prefs;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((v) {
      if (mounted) setState(() => prefs = v);
    });
  }

  Future<void> change(String key, bool value) async {
    setState(() => busy = true);
    try {
      await prefs!.setBool('reminder_$key', value);
      final scheduler = ref.read(reminderSchedulerProvider);
      if (value) await scheduler.requestPermission();
      await scheduler.syncGeneral();
      await ref
          .read(debtRemindersProvider)
          .sync(await ref.read(debtsProvider.future));
      await scheduler.syncPayables(
          await ref.read(payablesProvider.future),
          (await ref.read(payablePaymentsProvider.future))
              .where((r) => r['status'] == 'paid')
              .map((r) => r['id'] as String)
              .toSet());
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Không thể cập nhật lịch nhắc. Vui lòng thử lại.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickDiaryTime() async {
    final selected = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: prefs!.getInt('reminder_diary_hour') ?? 21,
          minute: prefs!.getInt('reminder_diary_minute') ?? 0,
        ));
    if (selected == null || !mounted) return;
    setState(() => busy = true);
    try {
      await prefs!.setInt('reminder_diary_hour', selected.hour);
      await prefs!.setInt('reminder_diary_minute', selected.minute);
      await ref.read(reminderSchedulerProvider).syncGeneral();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Không thể cập nhật giờ nhắc. Vui lòng thử lại.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Cài đặt nhắc nhở')),
      body: prefs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(children: [
              for (final item in const [
                ('diary', 'Nhật ký thu chi', '21:00 mỗi ngày', false),
                (
                  'debts',
                  'Sổ nợ',
                  '08:00 trước hạn một ngày và đúng ngày',
                  true
                ),
                (
                  'payables',
                  'Khoản phải trả',
                  '08:00 trước hạn một ngày và đúng ngày',
                  true
                ),
                ('report', 'Báo cáo tháng', '08:00 ngày đầu tháng', true)
              ])
                SwitchListTile(
                    title: Text(item.$2),
                    subtitle: Text(item.$1 == 'diary'
                        ? 'Mỗi ngày vào giờ đã chọn'
                        : item.$3),
                    value: prefs!.getBool('reminder_${item.$1}') ?? item.$4,
                    onChanged: busy ? null : (v) => change(item.$1, v)),
              ListTile(
                title: const Text('Giờ nhắc nhật ký'),
                subtitle: Text(TimeOfDay(
                        hour: prefs!.getInt('reminder_diary_hour') ?? 21,
                        minute: prefs!.getInt('reminder_diary_minute') ?? 0)
                    .format(context)),
                trailing: const Icon(Icons.schedule),
                onTap: busy ? null : pickDiaryTime,
              ),
            ]));
}
