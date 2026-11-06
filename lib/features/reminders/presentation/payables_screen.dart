import '../../../core/utils/localized_format.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../home/providers/home_providers.dart';
import '../../home/models/transaction_model.dart';
import '../../home/presentation/widgets/transaction_form_sheet.dart';
import '../data/payable_repository.dart';
import '../data/reminder_scheduler.dart';
import '../models/payable.dart';

class PayablesScreen extends ConsumerWidget {
  const PayablesScreen({super.key});
  Future<void> _pay(
      BuildContext context, WidgetRef ref, Payable p, DateTime date) async {
    final record = await showDialog<bool>(
        context: context,
        builder: (context) => SimpleDialog(
              title: Text(appL10n(context).msgConfirmPaymentOf395(
                  (formatMoney(context, p.amount)).toString())),
              children: [
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(appL10n(context).msgOnlyMarkAsPaid396)),
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(appL10n(context).msgRecordExpense397)),
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(context),
                    child: Text(appL10n(context).msgCancel42)),
              ],
            ));
    if (record == null || !context.mounted) return;
    TransactionDraft? draft;
    if (record) {
      draft = await showTransactionFormSheet(context,
          initial: TransactionDraft(
            type: TransactionType.expense,
            amount: p.amount,
            note: p.note ?? p.title,
            occurredAt: DateTime.now(),
          ));
      if (draft == null || !context.mounted) return;
      if (draft.type != TransactionType.expense) {
        showToast(context, appL10n(context).msgSelectAnExpenseForThisBill398);
        return;
      }
    }
    final store = ref.read(localStoreProvider);
    if (store == null) return;
    try {
      await PayablePayments(store).markPaid(p, date, draft: draft);
      ref.invalidate(payablePaymentsProvider);
      ref.refreshWalletData();
    } catch (e) {
      if (context.mounted)
        showToast(context, friendlyError(e, context: context));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payables = ref.watch(payablesProvider);
    final payments = ref.watch(payablePaymentsProvider);
    void sync() {
      final items = ref.read(payablesProvider).valueOrNull;
      final paid = ref.read(payablePaymentsProvider).valueOrNull;
      if (items == null || paid == null) return;
      ref
          .read(reminderSchedulerProvider)
          .syncPayables(
              items,
              paid
                  .where((r) => r['status'] == 'paid')
                  .map((r) => r['id'] as String)
                  .toSet())
          .catchError((Object _) {});
    }

    ref.listen(payablesProvider, (_, next) => sync());
    ref.listen(payablePaymentsProvider, (_, next) => sync());
    return Scaffold(
        appBar: AppBar(title: Text(appL10n(context).payables)),
        floatingActionButton: FloatingActionButton(
            onPressed: () => showFormSheet<void>(context, const _PayableForm()),
            child: const Icon(Icons.add)),
        body: payables.when(
          loading: () => const Center(child: const CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text(friendlyError(e, context: context))),
          data: (items) => payments.when(
              loading: () =>
                  const Center(child: const CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(friendlyError(e, context: context))),
              data: (paid) {
                final ids = paid
                    .where((r) => r['status'] == 'paid')
                    .map((r) => r['id'])
                    .toSet();
                final end = DateTime.now().add(const Duration(days: 31));
                return ListView(
                    padding: const EdgeInsets.only(bottom: 90),
                    children: [
                      ListTile(
                          subtitle: Text(appL10n(context)
                              .msgRemindersDoNotCreateExpensesAutomatically399)),
                      if (items.isEmpty)
                        ListTile(
                            title: Text(
                                appL10n(context).msgNoBillsYetTapToAdd400)),
                      for (final p in items.where((p) => p.active)) ...[
                        ListTile(
                            title: Text(p.title),
                            subtitle: Text(formatMoney(context, p.amount)),
                            trailing: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => showFormSheet<void>(
                                    context, _PayableForm(initial: p)))),
                        for (final date in p.through(end))
                          ListTile(
                            title: Text(payableDateKey(date)),
                            trailing: ids.contains(p.occurrenceId(date))
                                ? Text(appL10n(context).msgPaid184)
                                : TextButton(
                                    onPressed: () =>
                                        _pay(context, ref, p, date),
                                    child: Text(
                                        appL10n(context).msgMarkAsPaid401)),
                          ),
                      ],
                    ]);
              }),
        ));
  }
}

class _PayableForm extends ConsumerStatefulWidget {
  const _PayableForm({this.initial});
  final Payable? initial;
  @override
  ConsumerState<_PayableForm> createState() => _PayableFormState();
}

class _PayableFormState extends ConsumerState<_PayableForm> {
  late final title = TextEditingController(text: widget.initial?.title ?? '');
  late final amount =
      TextEditingController(text: widget.initial?.amount.toString() ?? '');
  late final note = TextEditingController(text: widget.initial?.note ?? '');
  late DateTime date = widget.initial?.start ?? DateTime.now();
  late PayableFrequency frequency =
      widget.initial?.frequency ?? PayableFrequency.once;
  late bool active = widget.initial?.active ?? true;
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormSheet(
          title: appL10n(context).payables,
          submitLabel: appL10n(context).msgSave43,
          busy: busy,
          onSubmit: () async {
            if (title.text.trim().isEmpty || MoneyField.valueOf(amount) <= 0) {
              showToast(context, appL10n(context).msgEnterANameAndAnAmount402);
              return;
            }
            final store = ref.read(localStoreProvider);
            if (store == null) return;
            setState(() => busy = true);
            try {
              await store.put(
                  'payables',
                  Payable(
                          id: widget.initial?.id ?? newUuidV4(),
                          title: title.text,
                          amount: MoneyField.valueOf(amount),
                          start: date,
                          note: note.text,
                          frequency: frequency,
                          active: active)
                      .toJson());
              ref.invalidate(payablesProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted)
                showToast(context, friendlyError(e, context: context));
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
          children: [
            TextField(
                controller: title,
                decoration: InputDecoration(
                    labelText: appL10n(context).msgBillName403)),
            MoneyField(controller: amount, label: appL10n(context).msgAmount26),
            TextField(
                controller: note,
                maxLength: 255,
                maxLines: 3,
                decoration: InputDecoration(
                    labelText: appL10n(context).msgNoteOptional255)),
            DatePickerTile(
                label: appL10n(context).msgStartDate404,
                value: date,
                onChanged: (v) {
                  if (v != null) setState(() => date = v);
                }),
            DropdownButtonFormField<PayableFrequency>(
                value: frequency,
                items: [
                  DropdownMenuItem(
                      value: PayableFrequency.once,
                      child: Text(appL10n(context).msgOnce405)),
                  DropdownMenuItem(
                      value: PayableFrequency.weekly,
                      child: Text(appL10n(context).msgWeekly406)),
                  DropdownMenuItem(
                      value: PayableFrequency.monthly,
                      child: Text(appL10n(context).msgMonthly407))
                ],
                onChanged: (v) => setState(() => frequency = v!)),
            SwitchListTile(
                title: Text(appL10n(context).msgActive408),
                value: active,
                onChanged: (v) => setState(() => active = v)),
          ]);
}
