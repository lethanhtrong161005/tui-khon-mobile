import '../../../l10n/app_l10n.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(appL10n(context).msgCouldNotUpdateRemindersPleaseTry409)));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(appL10n(context).msgCouldNotUpdateReminderTimePlease410)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(appL10n(context).reminderSettings)),
      body: prefs == null
          ? const Center(child: const CircularProgressIndicator())
          : ListView(children: [
              for (final item in [
                (
                  'diary',
                  appL10n(context).msgIncomeExpenseDiary412,
                  appL10n(context).msgEveryDay413,
                  false
                ),
                (
                  'debts',
                  appL10n(context).msgDebtBook9,
                  appL10n(context).msgOneDayBeforeAndOnThe414,
                  true
                ),
                (
                  'payables',
                  appL10n(context).payables,
                  appL10n(context).msgOneDayBeforeAndOnThe414,
                  true
                ),
                (
                  'report',
                  appL10n(context).monthlyReport,
                  appL10n(context).msgOnTheFirstDayOfThe415,
                  true
                )
              ])
                SwitchListTile(
                    title: Text(item.$2),
                    subtitle: Text(item.$1 == 'diary'
                        ? appL10n(context).msgDailyAtTheSelectedTime416
                        : item.$3),
                    value: prefs!.getBool('reminder_${item.$1}') ?? item.$4,
                    onChanged: busy ? null : (v) => change(item.$1, v)),
              ListTile(
                title: Text(appL10n(context).msgDiaryReminderTime417),
                subtitle: Text(TimeOfDay(
                        hour: prefs!.getInt('reminder_diary_hour') ?? 21,
                        minute: prefs!.getInt('reminder_diary_minute') ?? 0)
                    .format(context)),
                trailing: const Icon(Icons.schedule),
                onTap: busy ? null : pickDiaryTime,
              ),
            ]));
}
