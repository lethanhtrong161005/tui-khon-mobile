import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/utils/currency_formatter.dart';
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
    backgroundColor: const Color(0xFFF8FBF9),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
  String? _error, _walletError, _amountError;
  bool get _borrow => widget.debt.type == DebtType.borrow;
  bool get _legacy => widget.payment?['is_legacy'] == true;
  int get _limit =>
      widget.debt.remaining + (widget.payment?['amount'] as num? ?? 0).toInt();
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
      setState(() => _walletError = 'Chọn nguồn tiền');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _walletError = null;
    });
    try {
      final repository = ref.read(planningRepositoryProvider);
      final value = int.parse(_amount.text);
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
          final message = friendlyError(e);
          if (message.contains('vượt')) {
            _amountError = message;
          } else if (message.contains('nguồn tiền')) {
            _walletError = message;
          } else {
            _error = message;
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
        ? 'Chỉnh sửa lần ${_borrow ? 'trả' : 'thu'} nợ'
        : (_borrow ? 'Ghi trả nợ' : 'Ghi thu nợ');
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
                              tooltip: 'Đóng',
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
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: InputDecoration(
                                labelText: 'Số tiền',
                                suffixText: '₫',
                                errorText: _amountError),
                            onChanged: (_) {
                              if (_amountError != null)
                                setState(() => _amountError = null);
                            },
                            validator: (v) {
                              final n = int.tryParse(v ?? '') ?? 0;
                              if (n <= 0) return 'Nhập số tiền lớn hơn 0';
                              if (n > _limit)
                                return 'Số tiền vượt quá số còn lại (${CurrencyFormatter.formatVND(_limit)})';
                              return null;
                            }),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _pickDate,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(
                                'Ngày ${_borrow ? 'trả' : 'thu'}: ${paymentDate(_date.toIso8601String())}',
                                textAlign: TextAlign.center)),
                        const SizedBox(height: 14),
                        TextFormField(
                            key: const Key('payment-note'),
                            controller: _note,
                            enabled: !_busy,
                            maxLength: 255,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'Ghi chú (tùy chọn)')),
                        if (_legacy)
                          const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                  'Số tiền trước nâng cấp: không có chi tiết từng lần và không tạo thêm thu/chi.')),
                        SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            secondary: const TintedIcon(
                                Icons.account_balance_wallet_outlined,
                                size: 38),
                            title: Text(
                                'Ghi kèm khoản ${_borrow ? 'chi' : 'thu'}'),
                            subtitle:
                                const Text('Tạo một khoản ghi chép tương ứng'),
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
                            const Text(
                                'Không tải được nguồn tiền. Hãy đóng và thử lại.'),
                          DropdownButtonFormField<String>(
                              key: ValueKey(
                                  'wallet-$_wallet-${available.length}'),
                              initialValue:
                                  available.any((w) => w['id'] == _wallet)
                                      ? _wallet
                                      : null,
                              isExpanded: true,
                              decoration: InputDecoration(
                                  labelText: 'Nguồn tiền',
                                  errorText: _walletError),
                              items: [
                                for (final w in available)
                                  DropdownMenuItem(
                                      value: w['id'] as String,
                                      child: Text(
                                          '${w['name']}${w['is_archived'] == true ? ' · Đã lưu trữ' : ''}',
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
                              child: Text(_error!,
                                  style: const TextStyle(color: Colors.red))),
                        const SizedBox(height: 20),
                        EmeraldButton(
                            label: _busy
                                ? 'Đang lưu…'
                                : widget.payment != null
                                    ? 'Cập nhật'
                                    : title,
                            onPressed: _busy ? null : _save),
                      ])),
            )),
      ),
    );
  }
}
