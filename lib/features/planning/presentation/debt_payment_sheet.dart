import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/localized_format.dart';
import '../../../core/utils/vnd_amount_input.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/glass.dart';
import '../../home/providers/home_providers.dart';
import '../data/planning_repository.dart';
import '../models/planning_models.dart';
import 'debt_actions.dart';

DateTime vietnamTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 7));
String paymentDate(dynamic value) => DateFormat('dd/MM/yyyy · HH:mm')
    .format(vietnamTime(DateTime.parse('$value')));

final paymentWalletsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(localRevisionProvider);
  return await ref.watch(localStoreProvider)?.rows('wallets') ?? [];
});

Future<void> showDebtPaymentSheet(
    BuildContext context, WidgetRef ref, DebtModel debt,
    {Map<String, dynamic>? payment}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // A solid base keeps the timeline text from bleeding through the form.
    backgroundColor: adaptiveSurface(context, const Color(0xFFF8FBF9)),
    shape: const RoundedRectangleBorder(
        borderRadius:
            const BorderRadius.vertical(top: const Radius.circular(28))),
    clipBehavior: Clip.antiAlias,
    builder: (_) => DebtPaymentSheet(debt: debt, payment: payment),
  );
  if (saved == true) {
    ref.refreshWalletData();
    await ref.refreshDebts();
  }
}

class DebtPaymentSheet extends ConsumerStatefulWidget {
  const DebtPaymentSheet({super.key, required this.debt, this.payment});
  final DebtModel debt;
  final Map<String, dynamic>? payment;
  @override
  ConsumerState<DebtPaymentSheet> createState() => _DebtPaymentSheetState();
}

class _DebtPaymentSheetState extends ConsumerState<DebtPaymentSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
      text: widget.payment == null ? '' : '${widget.payment!['amount']}');
  late final _note =
      TextEditingController(text: widget.payment?['note'] as String? ?? '');
  late DateTime _date = widget.payment == null
      ? DateTime.now().toUtc()
      : DateTime.parse('${widget.payment!['paid_at']}');
  late bool _record = widget.payment?['record_transaction'] == true;
  late String? _wallet = widget.payment?['wallet_id'] as String?;
  bool _busy = false;
  Object? _error, _walletError, _amountError;
  bool get _borrow => widget.debt.type == DebtType.borrow;
  bool get _legacy => widget.payment?['is_legacy'] == true;
  int get _limit =>
      widget.debt.remaining + (widget.payment?['amount'] as num? ?? 0).toInt();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    formatVndController(_amount, appL10n(context).localeName);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final local = vietnamTime(_date);
    final day = await showDatePicker(
        context: context,
        initialDate: local,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200));
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(local));
    if (time != null && mounted)
      setState(() => _date = DateTime.utc(
          day.year, day.month, day.day, time.hour - 7, time.minute));
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final allowed = ref.read(paymentWalletsProvider).valueOrNull ?? [];
    final selected = allowed.where((w) => w['id'] == _wallet).firstOrNull;
    final retainArchived = widget.payment?['record_transaction'] == true &&
        widget.payment?['wallet_id'] == _wallet;
    if (_record &&
        (selected == null ||
            (selected['is_archived'] == true && !retainArchived))) {
      setState(() =>
          _walletError = AppFailure('failure13', [], 'Select a money source'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _walletError = null;
    });
    try {
      final repository = ref.read(planningRepositoryProvider);
      final value = parseVndInput(_amount.text);
      if (widget.payment == null) {
        await repository.settleDebt(widget.debt.id!,
            amount: value,
            paidAt: _date,
            note: _note.text,
            recordTransaction: _record,
            walletId: _wallet);
      } else {
        await repository.updateDebtPayment(widget.payment!['id'] as String,
            amount: value,
            paidAt: _date,
            note: _note.text,
            recordTransaction: _record,
            walletId: _wallet);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() {
          if (e is CodedFailure &&
              ['failure1', 'failure9'].contains((e).code)) {
            _amountError = e;
          } else if (e is CodedFailure && (e).code == 'failure13') {
            _walletError = e;
          } else {
            _error = e;
          }
          _busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(paymentWalletsProvider);
    final available = (wallets.valueOrNull ?? [])
        .where((w) =>
            w['is_archived'] != true ||
            (w['id'] == widget.payment?['wallet_id'] &&
                widget.payment?['record_transaction'] == true))
        .toList();
    final title = widget.payment != null
        ? (_borrow
            ? appL10n(context).editRepayment
            : appL10n(context).editCollection)
        : (_borrow
            ? appL10n(context).msgRecordRepayment280
            : appL10n(context).msgRecordCollection281);
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: (media.size.height -
                    media.viewInsets.bottom -
                    media.padding.top) *
                .96),
        child: GlassCard(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SingleChildScrollView(
              child: Form(
                  key: _form,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                            child: Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(4)))),
                        Row(children: [
                          Expanded(
                              child: Text(title,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800))),
                          IconButton(
                              tooltip: appL10n(context).msgClose19,
                              onPressed:
                                  _busy ? null : () => Navigator.pop(context),
                              icon: const Icon(Icons.close))
                        ]),
                        const SizedBox(height: 12),
                        TextFormField(
                            key: const Key('payment-amount'),
                            controller: _amount,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              VndAmountInputFormatter(
                                  appL10n(context).localeName)
                            ],
                            decoration: InputDecoration(
                                labelText: appL10n(context).msgAmount26,
                                suffixText: '₫',
                                errorText: _amountError == null
                                    ? null
                                    : friendlyError(_amountError!,
                                        context: context)),
                            onChanged: (_) {
                              if (_amountError != null)
                                setState(() => _amountError = null);
                            },
                            validator: (v) {
                              final n = parseVndInput(v ?? '');
                              if (n <= 0)
                                return appL10n(context)
                                    .msgEnterAnAmountGreaterThan246;
                              if (n > _limit)
                                return appL10n(context)
                                    .msgAmountExceedsTheRemainingDebt305(
                                        (formatMoney(context, _limit))
                                            .toString());
                              return null;
                            }),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _pickDate,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(
                                (_borrow
                                    ? appL10n(context).paymentDate(
                                        paymentDate(_date.toIso8601String()))
                                    : appL10n(context).collectionDate(
                                        paymentDate(_date.toIso8601String()))),
                                textAlign: TextAlign.center)),
                        const SizedBox(height: 14),
                        TextFormField(
                            key: const Key('payment-note'),
                            controller: _note,
                            enabled: !_busy,
                            maxLength: 255,
                            minLines: 1,
                            maxLines: 3,
                            decoration: InputDecoration(
                                labelText:
                                    appL10n(context).msgNoteOptional307)),
                        if (_legacy)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(appL10n(context)
                                  .msgAmountPaidBeforeTheUpgradeIndividual308)),
                        SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            secondary: const TintedIcon(
                                Icons.account_balance_wallet_outlined,
                                size: 38),
                            title: Text((_borrow
                                ? appL10n(context).addMatchingExpense
                                : appL10n(context).addMatchingIncome)),
                            subtitle: Text(appL10n(context)
                                .msgCreateACorrespondingTransactionRecord310),
                            value: _record,
                            onChanged: _legacy || _busy
                                ? null
                                : (v) => setState(() {
                                      _record = v;
                                      _walletError = null;
                                    })),
                        if (_record) ...[
                          const SizedBox(height: 8),
                          if (wallets.isLoading)
                            const LinearProgressIndicator(),
                          if (wallets.hasError)
                            Text(appL10n(context)
                                .msgCouldNotLoadMoneySourcesClose311),
                          DropdownButtonFormField<String>(
                              key: ValueKey(
                                  'wallet-$_wallet-${available.length}'),
                              initialValue:
                                  available.any((w) => w['id'] == _wallet)
                                      ? _wallet
                                      : null,
                              isExpanded: true,
                              decoration: InputDecoration(
                                  labelText: appL10n(context).wallets,
                                  errorText: _walletError == null
                                      ? null
                                      : friendlyError(_walletError!,
                                          context: context)),
                              items: [
                                for (final w in available)
                                  DropdownMenuItem(
                                      value: w['id'] as String,
                                      child: Text(
                                          '${w['name']}${w['is_archived'] == true ? appL10n(context).archivedSuffix : ''}',
                                          overflow: TextOverflow.ellipsis))
                              ],
                              onChanged: _busy
                                  ? null
                                  : (v) => setState(() {
                                        _wallet = v;
                                        _walletError = null;
                                      })),
                        ],
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                  friendlyError(_error!, context: context),
                                  style: const TextStyle(color: Colors.red))),
                        const SizedBox(height: 20),
                        EmeraldButton(
                            label: _busy
                                ? appL10n(context).msgSaving312
                                : widget.payment != null
                                    ? appL10n(context).msgUpdate313
                                    : title,
                            onPressed: _busy ? null : _save),
                      ])),
            )),
      ),
    );
  }
}
