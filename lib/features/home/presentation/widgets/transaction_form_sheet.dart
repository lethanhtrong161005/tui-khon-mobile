import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/home_providers.dart';

/// Bottom sheet to enter a transaction by hand or correct an AI draft.
/// Returns the edited [TransactionDraft], or null when dismissed.
Future<TransactionDraft?> showTransactionFormSheet(BuildContext context, {TransactionDraft? initial}) {
  return showModalBottomSheet<TransactionDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TransactionFormSheet(initial: initial),
  );
}

class _TransactionFormSheet extends ConsumerStatefulWidget {
  const _TransactionFormSheet({this.initial});

  final TransactionDraft? initial;

  @override
  ConsumerState<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<_TransactionFormSheet> {
  late TransactionType _type = widget.initial?.type ?? TransactionType.expense;
  late final _amountController = TextEditingController(
    text: (widget.initial?.amount ?? 0) > 0 ? '${widget.initial!.amount}' : '',
  );
  late final _noteController = TextEditingController(text: widget.initial?.note ?? '');
  late String? _categoryId = widget.initial?.categoryId;
  late String? _walletId = widget.initial?.walletId;
  late DateTime _date = widget.initial?.occurredAt ?? DateTime.now();

  int get _amount => int.tryParse(_amountController.text) ?? 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      // Keep the current time of day so the order within the day stays natural.
      setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  void _submit(List<CategoryModel> categories, List<WalletModel> wallets) {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập số tiền lớn hơn 0')));
      return;
    }
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn danh mục')));
      return;
    }
    final category = categories.firstWhere((c) => c.id == _categoryId);
    final wallet = wallets.firstWhere((w) => w.id == _walletId);
    Navigator.pop(
      context,
      TransactionDraft(
        type: _type,
        amount: _amount,
        categoryId: category.id,
        categoryName: category.name,
        walletId: wallet.id,
        walletName: wallet.name,
        note: _noteController.text.trim(),
        occurredAt: _date,
        source: widget.initial?.source ?? TransactionSource.manual,
        receiptPath: widget.initial?.receiptPath,
        merchant: widget.initial?.merchant,
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final walletsAsync = ref.watch(walletsProvider);
    final categories = (categoriesAsync.valueOrNull ?? const <CategoryModel>[]).where((c) => c.type == _type).toList();
    final wallets = (walletsAsync.valueOrNull ?? const <WalletModel>[]).where((w) => !w.isArchived).toList();

    // Drop selections that do not fit the current type / list.
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) _categoryId = null;
    if (wallets.isNotEmpty && !wallets.any((w) => w.id == _walletId)) _walletId = wallets.first.id;

    final loading = categoriesAsync.isLoading || walletsAsync.isLoading;

    return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        // Material (not a decorated Container) so the date ListTile can paint ink.
        child: Material(
          color: AppColors.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.outlineVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.initial == null ? 'Thêm giao dịch' : 'Chỉnh sửa giao dịch',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<TransactionType>(
                      segments: const [
                        ButtonSegment(
                            value: TransactionType.expense, label: Text('Chi tiêu'), icon: Icon(Icons.arrow_downward)),
                        ButtonSegment(
                            value: TransactionType.income, label: Text('Thu nhập'), icon: Icon(Icons.arrow_upward)),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => setState(() => _type = s.first),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)],
                      autofocus: widget.initial == null,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      decoration: InputDecoration(
                        labelText: 'Số tiền (VND)',
                        helperText: _amount > 0 ? CurrencyFormatter.formatVND(_amount) : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // Rebuilt when the type or the loaded list changes so initialValue applies again.
                      key: ValueKey('category-${_type.name}-${categories.length}'),
                      initialValue: _categoryId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Danh mục',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: [
                        for (final c in categories)
                          DropdownMenuItem(
                            value: c.id,
                            child: Row(
                              children: [
                                Icon(c.iconData, size: 18, color: c.colorValue),
                                const SizedBox(width: 8),
                                Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('wallet-${wallets.length}'),
                      initialValue: _walletId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Nguồn tiền',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: [
                        for (final w in wallets)
                          DropdownMenuItem(
                            value: w.id,
                            child: Text('${w.name} • ${CurrencyFormatter.formatVND(w.balance)}',
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() => _walletId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      maxLength: 255,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú',
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event, color: AppColors.primary),
                      title: Text(
                        '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: loading || wallets.isEmpty ? null : () => _submit(categories, wallets),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: Text(_type == TransactionType.income ? 'Lưu khoản thu' : 'Lưu giao dịch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}
