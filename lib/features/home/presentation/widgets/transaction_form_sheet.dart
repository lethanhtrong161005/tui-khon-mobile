import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/offline/duplicate_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/glass.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/home_providers.dart';

/// Bottom sheet to enter a transaction by hand or correct an AI draft.
/// Returns the edited [TransactionDraft], or null when dismissed.
Future<TransactionDraft?> showTransactionFormSheet(BuildContext context,
    {TransactionDraft? initial, String? excludingId}) {
  return showModalBottomSheet<TransactionDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _TransactionFormSheet(initial: initial, excludingId: excludingId),
  );
}

class _TransactionFormSheet extends ConsumerStatefulWidget {
  const _TransactionFormSheet({this.initial, this.excludingId});

  final TransactionDraft? initial;
  final String? excludingId;

  @override
  ConsumerState<_TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<_TransactionFormSheet> {
  late TransactionType _type = widget.initial?.type ?? TransactionType.expense;
  late final _amountController = TextEditingController(
    text: (widget.initial?.amount ?? 0) > 0 ? '${widget.initial!.amount}' : '',
  );
  late final _noteController =
      TextEditingController(text: widget.initial?.note ?? '');
  late String? _categoryId = widget.initial?.categoryId;
  late String? _walletId = widget.initial?.walletId;
  late DateTime _date = widget.initial?.occurredAt ?? DateTime.now();

  bool _showAllCategories = false;

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
      setState(() => _date = DateTime(
          picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  Future<void> _submit(
      List<CategoryModel> categories, List<WalletModel> wallets) async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập số tiền lớn hơn 0')));
      return;
    }
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn danh mục')));
      return;
    }
    final category = categories.firstWhere((c) => c.id == _categoryId);
    if (!wallets.any((w) => w.id == _walletId)) return;
    final wallet = wallets.firstWhere((w) => w.id == _walletId);
    final checker = ref.read(duplicateServiceProvider);
    if (checker != null) {
      final matches = await checker.find(
          TransactionDraft(
              type: _type,
              amount: _amount,
              walletId: wallet.id,
              occurredAt: _date,
              receiptPath: widget.initial?.receiptPath),
          excludingId: widget.excludingId);
      if (!mounted) return;
      if (!await confirmPossibleDuplicate(context, matches) || !mounted) return;
    }
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
    final categories = (categoriesAsync.valueOrNull ?? const <CategoryModel>[])
        .where((c) => c.type == _type)
        .toList();
    final wallets = (walletsAsync.valueOrNull ?? const <WalletModel>[])
        .where((w) => !w.isArchived)
        .toList();
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId))
      _categoryId = null;
    if (wallets.isNotEmpty && !wallets.any((w) => w.id == _walletId))
      _walletId = wallets.first.id;
    final loading = categoriesAsync.isLoading || walletsAsync.isLoading;
    final isNew = (widget.initial?.amount ?? 0) == 0;
    final visible = _showAllCategories ||
            categories.length <= 8 ||
            categories.indexWhere((c) => c.id == _categoryId) >= 7
        ? categories
        : categories.take(7).toList();

    return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .92 -
                    MediaQuery.viewInsetsOf(context).bottom),
            child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
                child: Material(
                    color: AppColors.surface,
                    child: NotebookBackground(
                        child: SafeArea(
                            top: false,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                      width: 36,
                                      height: 4,
                                      margin: const EdgeInsets.only(top: 10),
                                      decoration: BoxDecoration(
                                          color: AppColors.outlineVariant,
                                          borderRadius:
                                              BorderRadius.circular(4))),
                                  Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          10, 4, 16, 4),
                                      child: Row(children: [
                                        IconButton(
                                            tooltip: 'Đóng',
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            icon: const Icon(
                                                Icons.arrow_back_rounded)),
                                        Expanded(
                                            child: Text(
                                                isNew
                                                    ? (_type ==
                                                            TransactionType
                                                                .expense
                                                        ? 'Thêm chi tiêu'
                                                        : 'Thêm thu nhập')
                                                    : 'Chỉnh sửa giao dịch',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight:
                                                        FontWeight.w800))),
                                        const SizedBox(width: 40),
                                      ])),
                                  Flexible(
                                      child: SingleChildScrollView(
                                          padding: const EdgeInsets.fromLTRB(
                                              20, 4, 20, 16),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                SegmentedButton<
                                                        TransactionType>(
                                                    showSelectedIcon: false,
                                                    style: SegmentedButton.styleFrom(
                                                        backgroundColor: Colors
                                                            .white
                                                            .withValues(
                                                                alpha: .65),
                                                        selectedBackgroundColor:
                                                            AppColors.primary
                                                                .withValues(
                                                                    alpha: .12),
                                                        selectedForegroundColor:
                                                            AppColors.primary,
                                                        side: const BorderSide(
                                                            color: Color(
                                                                0xFFD7E6DD))),
                                                    segments: const [
                                                      ButtonSegment(
                                                          value: TransactionType
                                                              .expense,
                                                          label:
                                                              Text('Chi tiêu')),
                                                      ButtonSegment(
                                                          value: TransactionType
                                                              .income,
                                                          label:
                                                              Text('Thu nhập'))
                                                    ],
                                                    selected: {_type},
                                                    onSelectionChanged: (v) =>
                                                        setState(() =>
                                                            _type = v.first)),
                                                const SizedBox(height: 16),
                                                TextField(
                                                    controller:
                                                        _amountController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter
                                                          .digitsOnly,
                                                      LengthLimitingTextInputFormatter(
                                                          13)
                                                    ],
                                                    style: const TextStyle(
                                                        fontSize: 32,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: -1),
                                                    decoration: InputDecoration(
                                                        labelText:
                                                            'Số tiền (VND)',
                                                        suffixText: 'đ',
                                                        suffixIcon: IconButton(
                                                            tooltip:
                                                                'Xóa số tiền',
                                                            icon: const Icon(
                                                                Icons
                                                                    .cancel_rounded,
                                                                size: 19),
                                                            onPressed: () =>
                                                                setState(
                                                                    _amountController
                                                                        .clear)),
                                                        helperText: _amount > 0
                                                            ? CurrencyFormatter
                                                                .formatVND(
                                                                    _amount)
                                                            : 'Nhập số tiền nguyên bằng đồng'),
                                                    onChanged: (_) =>
                                                        setState(() {})),
                                                const SizedBox(height: 14),
                                                if (loading)
                                                  const LinearProgressIndicator(),
                                                if (categoriesAsync.hasError ||
                                                    walletsAsync.hasError)
                                                  TextButton(
                                                      onPressed: () {
                                                        ref.invalidate(
                                                            categoriesProvider);
                                                        ref.invalidate(
                                                            walletsProvider);
                                                      },
                                                      child: const Text(
                                                          'Không tải được dữ liệu. Thử lại')),
                                                if (!loading &&
                                                    categories.isEmpty)
                                                  const Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 12),
                                                      child: Text(
                                                          'Chưa có danh mục cho loại giao dịch này. Thêm danh mục trong Cá nhân → Danh mục.',
                                                          style: TextStyle(
                                                              fontSize: 12))),
                                                LayoutBuilder(
                                                    builder: (context, bounds) {
                                                  final columns = bounds
                                                                  .maxWidth <
                                                              300 ||
                                                          MediaQuery.textScalerOf(
                                                                      context)
                                                                  .scale(1) >
                                                              1.3
                                                      ? 3
                                                      : 4;
                                                  final width = (bounds
                                                              .maxWidth -
                                                          8 * (columns - 1)) /
                                                      columns;
                                                  return Wrap(
                                                      spacing: 8,
                                                      runSpacing: 12,
                                                      children: [
                                                        for (final c in visible)
                                                          SizedBox(
                                                              width: width,
                                                              child: Semantics(
                                                                  selected:
                                                                      _categoryId ==
                                                                          c.id,
                                                                  button: true,
                                                                  child: InkWell(
                                                                      borderRadius: BorderRadius.circular(18),
                                                                      onTap: () => setState(() => _categoryId = c.id),
                                                                      child: Column(children: [
                                                                        AnimatedContainer(
                                                                            duration: MediaQuery.of(context).disableAnimations
                                                                                ? Duration
                                                                                    .zero
                                                                                : const Duration(
                                                                                    milliseconds:
                                                                                        180),
                                                                            width:
                                                                                55,
                                                                            height:
                                                                                55,
                                                                            decoration: BoxDecoration(
                                                                                borderRadius: BorderRadius.circular(
                                                                                    18),
                                                                                gradient: _categoryId == c.id
                                                                                    ? const LinearGradient(colors: [
                                                                                        AppColors.primary,
                                                                                        AppColors.primaryContainer
                                                                                      ])
                                                                                    : null,
                                                                                color: _categoryId == c.id ? null : Colors.white.withValues(alpha: .9),
                                                                                border: Border.all(color: Colors.white)),
                                                                            child: Icon(c.iconData, size: 25, color: _categoryId == c.id ? Colors.white : c.colorValue)),
                                                                        const SizedBox(
                                                                            height:
                                                                                6),
                                                                        Text(c.name,
                                                                            textAlign: TextAlign
                                                                                .center,
                                                                            maxLines:
                                                                                2,
                                                                            style:
                                                                                TextStyle(fontSize: 10, fontWeight: _categoryId == c.id ? FontWeight.w700 : FontWeight.w500)),
                                                                      ])))),
                                                        if (visible.length <
                                                            categories.length)
                                                          SizedBox(
                                                              width: width,
                                                              child: InkWell(
                                                                  onTap: () =>
                                                                      setState(() =>
                                                                          _showAllCategories =
                                                                              true),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              18),
                                                                  child: const Column(
                                                                      children: [
                                                                        TintedIcon(
                                                                            Icons
                                                                                .more_horiz_rounded,
                                                                            size:
                                                                                55,
                                                                            color:
                                                                                AppColors.onSurfaceVariant),
                                                                        SizedBox(
                                                                            height:
                                                                                6),
                                                                        Text(
                                                                            'Tất cả',
                                                                            style:
                                                                                TextStyle(fontSize: 10))
                                                                      ]))),
                                                      ]);
                                                }),
                                                const SizedBox(height: 20),
                                                DropdownButtonFormField<String>(
                                                    key: ValueKey(
                                                        'wallet-${wallets.length}'),
                                                    initialValue: _walletId,
                                                    isExpanded: true,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                'Nguồn tiền',
                                                            prefixIcon: Icon(
                                                                Icons
                                                                    .account_balance_wallet_outlined,
                                                                size: 20)),
                                                    items: [
                                                      for (final w in wallets)
                                                        DropdownMenuItem(
                                                            value: w.id,
                                                            child: Text(
                                                                '${w.name} • ${CurrencyFormatter.formatVND(w.balance)}',
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            12)))
                                                    ],
                                                    onChanged: (v) => setState(
                                                        () => _walletId = v)),
                                                if (!loading && wallets.isEmpty)
                                                  const Padding(
                                                      padding: EdgeInsets.only(
                                                          top: 8),
                                                      child: Text(
                                                          'Thêm nguồn tiền trong Cá nhân → Nguồn tiền để ghi giao dịch.',
                                                          style: TextStyle(
                                                              fontSize: 12))),
                                                const SizedBox(height: 14),
                                                GlassCard(
                                                    radius: 18,
                                                    child: ListTile(
                                                        dense: true,
                                                        leading: const Icon(
                                                            Icons
                                                                .calendar_today_outlined,
                                                            size: 19),
                                                        title: const Text(
                                                            'Thời gian',
                                                            style: TextStyle(
                                                                fontSize: 10,
                                                                color: AppColors
                                                                    .onSurfaceVariant)),
                                                        subtitle: Text(
                                                            '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                                                            style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)),
                                                        trailing: const Icon(
                                                            Icons.chevron_right_rounded,
                                                            size: 20),
                                                        onTap: _pickDate)),
                                                const SizedBox(height: 14),
                                                TextField(
                                                    controller: _noteController,
                                                    maxLength: 255,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                'Ghi chú',
                                                            hintText:
                                                                'Bạn đã dùng khoản tiền này cho việc gì?',
                                                            counterText: '')),
                                                const SizedBox(height: 10),
                                                Wrap(spacing: 6, children: [
                                                  for (final note in [
                                                    'Ăn sáng',
                                                    'Cà phê',
                                                    'Đi chợ'
                                                  ])
                                                    ActionChip(
                                                        label: Text(note,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        10)),
                                                        side: BorderSide.none,
                                                        backgroundColor: Colors
                                                            .white
                                                            .withValues(
                                                                alpha: .7),
                                                        onPressed: () =>
                                                            _noteController
                                                                .text = note)
                                                ]),
                                              ]))),
                                  Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 8, 20, 16),
                                      child: SizedBox(
                                          width: double.infinity,
                                          child: EmeraldButton(
                                              label: _type ==
                                                      TransactionType.income
                                                  ? 'Lưu khoản thu'
                                                  : 'Lưu giao dịch',
                                              onPressed: loading ||
                                                      categoriesAsync
                                                          .hasError ||
                                                      walletsAsync.hasError ||
                                                      wallets.isEmpty ||
                                                      categories.isEmpty
                                                  ? null
                                                  : () => _submit(
                                                      categories, wallets)))),
                                ])))))));
  }
}
