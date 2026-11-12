import '../../../../core/utils/localized_format.dart';
import '../../../../core/utils/vnd_amount_input.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/offline/duplicate_service.dart';
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
    useSafeArea: true,
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

  DateTime get _vietnamDate => _date.toUtc().add(const Duration(hours: 7));

  bool _showAllCategories = false;
  bool _submitting = false;

  int get _amount => parseVndInput(_amountController.text);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    formatVndController(_amountController, appL10n(context).localeName);
  }

  Future<void> _pickDate() async {
    final vn = _vietnamDate;
    final today = DateTime.now().toUtc().add(const Duration(hours: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(vn.year, vn.month, vn.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (picked != null) {
      // Keep the current time of day so the order within the day stays natural.
      setState(() => _date = DateTime.utc(
          picked.year, picked.month, picked.day, vn.hour, vn.minute).subtract(const Duration(hours: 7)));
    }
  }

  Future<void> _submit(
      List<CategoryModel> categories, List<WalletModel> wallets) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _submitDraft(categories, wallets);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyError(error, context: context))));
      }
    } finally {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _submitDraft(
      List<CategoryModel> categories, List<WalletModel> wallets) async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(appL10n(context).msgEnterAnAmountGreaterThan197)));
      return;
    }
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appL10n(context).msgSelectACategory198)));
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
    final categories = (categoriesAsync.valueOrNull ?? <CategoryModel>[])
        .where((c) => c.type == _type)
        .toList();
    final wallets = (walletsAsync.valueOrNull ?? <WalletModel>[])
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
                    const BorderRadius.vertical(top: const Radius.circular(30)),
                child: Material(
                    color: appPalette(context).surface,
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
                                          color: appPalette(context)
                                              .outlineVariant,
                                          borderRadius:
                                              BorderRadius.circular(4))),
                                  Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          10, 4, 16, 4),
                                      child: Row(children: [
                                        IconButton(
                                            tooltip:
                                                appL10n(context).msgClose19,
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
                                                        ? appL10n(context)
                                                            .msgAddExpense189
                                                        : appL10n(context)
                                                            .msgAddIncome190)
                                                    : appL10n(context)
                                                        .msgEditTransaction199,
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
                                                        backgroundColor:
                                                            appPalette(context)
                                                                .surfaceContainer
                                                                .withValues(
                                                                    alpha: .65),
                                                        selectedBackgroundColor:
                                                            appPalette(context)
                                                                .primary
                                                                .withValues(
                                                                    alpha: .12),
                                                        selectedForegroundColor:
                                                            appPalette(context)
                                                                .primary,
                                                        side: BorderSide(
                                                            color: adaptiveSurface(
                                                                context,
                                                                const Color(
                                                                    0xFFD7E6DD)))),
                                                    segments: [
                                                      ButtonSegment(
                                                          value: TransactionType
                                                              .expense,
                                                          label: Text(appL10n(
                                                                  context)
                                                              .msgExpenses164)),
                                                      ButtonSegment(
                                                          value: TransactionType
                                                              .income,
                                                          label: Text(appL10n(
                                                                  context)
                                                              .msgIncome163))
                                                    ],
                                                    selected: {_type},
                                                    onSelectionChanged: (v) =>
                                                        setState(() => _type = v.first)),
                                                const SizedBox(height: 16),
                                                TextField(
                                                    controller:
                                                        _amountController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    inputFormatters: [
                                                      VndAmountInputFormatter(
                                                          appL10n(context)
                                                              .localeName)
                                                    ],
                                                    style: const TextStyle(
                                                        fontSize: 32,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: -1),
                                                    decoration: InputDecoration(
                                                        labelText: appL10n(context)
                                                            .msgAmountVnd200,
                                                        suffixText:
                                                            appL10n(context)
                                                                .msg201,
                                                        suffixIcon: IconButton(
                                                            tooltip: appL10n(context)
                                                                .msgClearAmount202,
                                                            icon: const Icon(Icons.cancel_rounded,
                                                                size: 19),
                                                            onPressed: () => setState(
                                                                _amountController
                                                                    .clear)),
                                                        helperText: _amount > 0
                                                            ? formatMoney(context, _amount)
                                                            : appL10n(context).msgEnterAWholeAmountInVnd203),
                                                    onChanged: (_) => setState(() {})),
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
                                                      child: Text(appL10n(
                                                              context)
                                                          .msgCouldNotLoadDataRetry204)),
                                                if (!loading &&
                                                    categories.isEmpty)
                                                  Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Text(
                                                          appL10n(context)
                                                              .msgNoCategoriesForThisTransactionType205,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      12))),
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
                                                                                    ? LinearGradient(colors: [
                                                                                        appPalette(context).primary,
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
                                                                  child: Column(
                                                                      children: [
                                                                        TintedIcon(
                                                                            Icons
                                                                                .more_horiz_rounded,
                                                                            size:
                                                                                55,
                                                                            color:
                                                                                appPalette(context).onSurfaceVariant),
                                                                        const SizedBox(
                                                                            height:
                                                                                6),
                                                                        Text(
                                                                            appL10n(context)
                                                                                .msgAll206,
                                                                            style:
                                                                                const TextStyle(fontSize: 10))
                                                                      ]))),
                                                      ]);
                                                }),
                                                const SizedBox(height: 20),
                                                DropdownButtonFormField<String>(
                                                    key: ValueKey(
                                                        'wallet-${wallets.length}'),
                                                    initialValue: _walletId,
                                                    isExpanded: true,
                                                    decoration: InputDecoration(
                                                        labelText:
                                                            appL10n(context)
                                                                .wallets,
                                                        prefixIcon: const Icon(
                                                            Icons
                                                                .account_balance_wallet_outlined,
                                                            size: 20)),
                                                    items: [
                                                      for (final w in wallets)
                                                        DropdownMenuItem(
                                                            value: w.id,
                                                            child: Text(
                                                                '${w.name} • ${formatMoney(context, w.balance)}',
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
                                                  Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 8),
                                                      child: Text(
                                                          appL10n(context)
                                                              .msgAddAMoneySourceInProfile207,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      12))),
                                                const SizedBox(height: 14),
                                                GlassCard(
                                                    radius: 18,
                                                    child: ListTile(
                                                        dense: true,
                                                        leading: const Icon(Icons.calendar_today_outlined,
                                                            size: 19),
                                                        title: Text(
                                                            appL10n(context)
                                                                .msgDateAndTime208,
                                                            style: TextStyle(
                                                                fontSize: 10,
                                                                color: appPalette(context)
                                                                    .onSurfaceVariant)),
                                                        subtitle: Text(
                                                            '${_vietnamDate.day.toString().padLeft(2, '0')}/${_vietnamDate.month.toString().padLeft(2, '0')}/${_vietnamDate.year}',
                                                            style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight: FontWeight
                                                                    .w600)),
                                                        trailing: const Icon(
                                                            Icons.chevron_right_rounded,
                                                            size: 20),
                                                        onTap: _pickDate)),
                                                const SizedBox(height: 14),
                                                TextField(
                                                    controller: _noteController,
                                                    maxLength: 255,
                                                    decoration: InputDecoration(
                                                        labelText:
                                                            appL10n(context)
                                                                .msgNote24,
                                                        hintText: appL10n(
                                                                context)
                                                            .msgWhatWasThisPaymentFor209,
                                                        counterText: '')),
                                                const SizedBox(height: 10),
                                                Wrap(spacing: 6, children: [
                                                  for (final note in [
                                                    appL10n(context)
                                                        .msgBreakfast210,
                                                    appL10n(context)
                                                        .msgCoffee211,
                                                    appL10n(context)
                                                        .msgGroceries212
                                                  ])
                                                    ActionChip(
                                                        label: Text(note,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        10)),
                                                        side: BorderSide.none,
                                                        backgroundColor:
                                                            appPalette(context)
                                                                .surfaceContainer
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
                                                  ? appL10n(context)
                                                      .msgSaveIncome213
                                                  : appL10n(context)
                                                      .msgSaveTransaction214,
                                              onPressed: _submitting ||
                                                      loading ||
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
