import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/offline/local_store.dart';
import '../../planning/data/planning_repository.dart';
import '../../planning/presentation/debt_history_screen.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../home/models/category_model.dart';
import '../../home/models/transaction_model.dart';
import '../../home/models/wallet_model.dart';
import '../../home/presentation/widgets/transaction_form_sheet.dart';
import '../../home/providers/home_providers.dart';
import '../../receipt/data/receipt_repository.dart';
import '../../receipt/presentation/receipt_picker.dart';

/// Full transaction history: month by month, filtered by type / category /
/// money source / note, grouped by day. Tap to edit, swipe left to delete.
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  static const _pageSize = 50;

  late TransactionFilter _filter = TransactionFilter(month: DateTime(DateTime.now().year, DateTime.now().month));
  final List<TransactionModel> _items = [];
  final _scroll = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final filter = _filter;
    try {
      final page =
          await ref.read(walletRepositoryProvider).fetchTransactions(filter, offset: _items.length, limit: _pageSize);
      if (!mounted || filter != _filter) return; // filter changed while loading
      setState(() {
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFilter(TransactionFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    _loading = false;
    _reload();
  }

  Future<void> _edit(TransactionModel tx) async {
    final store = ref.read(localStoreProvider);
    if (store != null) {
      final payment = (await store.rows('debt_payments')).where((p) => p['transaction_id'] == tx.id).firstOrNull;
      if (payment != null) {
        final debt = (await ref.read(debtsProvider.future)).where((d) => d.id == payment['debt_id']).firstOrNull;
        if (debt != null && mounted) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => DebtHistoryScreen(debt: debt)));
          if (mounted) await _reload();
        }
        return;
      }
    }
    final draft = await showTransactionFormSheet(context, initial: tx.toDraft(), excludingId: tx.id);
    if (draft == null || !mounted) return;
    try {
      await ref.read(walletRepositoryProvider).updateTransaction(tx.id, draft);
      ref.refreshWalletData();
      await _reload();
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
    }
  }

  Future<bool> _delete(TransactionModel tx) async {
    final ok = await confirmDialog(
      context,
      title: 'Xoá giao dịch?',
      message: '${tx.title} • ${CurrencyFormatter.formatVND(tx.amount)}',
    );
    if (!ok) return false;
    try {
      await ref.read(walletRepositoryProvider).deleteTransaction(tx.id);
      ref.refreshWalletData();
      setState(() => _items.removeWhere((t) => t.id == tx.id));
      return true;
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <CategoryModel>[];
    final wallets = ref.watch(walletsProvider).valueOrNull ?? const <WalletModel>[];
    final income = _items.where((t) => t.isIncome).fold(0, (s, t) => s + t.amount);
    final expense = _items.where((t) => !t.isIncome).fold(0, (s, t) => s + t.amount);

    // Group by calendar day, newest first (items are already sorted).
    final groups = <DateTime, List<TransactionModel>>{};
    for (final t in _items) {
      groups.putIfAbsent(DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day), () => []).add(t);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Lịch sử giao dịch', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildFilters(categories, wallets),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                    child: Text('Thu: ${CurrencyFormatter.formatVND(income)}',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12))),
                Text('Chi: ${CurrencyFormatter.formatVND(expense)}',
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _reload,
              child: ListView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  for (final entry in groups.entries) ...[
                    _dayHeader(entry.key, entry.value),
                    for (final tx in entry.value) _tile(tx),
                  ],
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        Text(friendlyError(_error!), textAlign: TextAlign.center),
                        TextButton(onPressed: _reload, child: const Text('Thử lại')),
                      ]),
                    )
                  else if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Không có giao dịch nào khớp bộ lọc.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(List<CategoryModel> categories, List<WalletModel> wallets) {
    final m = _filter.month;
    final visibleCategories = categories.where((c) => _filter.type == null || c.type == _filter.type).toList();
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _setFilter(_filter.copyWith(month: DateTime(m.year, m.month - 1))),
              ),
              Text('Tháng ${m.month.toString().padLeft(2, '0')}/${m.year}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _setFilter(_filter.copyWith(month: DateTime(m.year, m.month + 1))),
              ),
            ],
          ),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Tìm theo ghi chú...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onChanged: (text) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 400), () {
                if (mounted) _setFilter(_filter.copyWith(search: text));
              });
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (label, type) in [
                  ('Tất cả', null),
                  ('Chi', TransactionType.expense),
                  ('Thu', TransactionType.income),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter.type == type,
                      onSelected: (_) => _setFilter(_filter.copyWith(type: () => type, categoryId: () => null)),
                    ),
                  ),
                const SizedBox(width: 4),
                _dropdownChip<String>(
                  label: 'Danh mục',
                  value: _filter.categoryId,
                  items: {for (final c in visibleCategories) c.id: c.name},
                  onChanged: (v) => _setFilter(_filter.copyWith(categoryId: () => v)),
                ),
                const SizedBox(width: 6),
                _dropdownChip<String>(
                  label: 'Nguồn tiền',
                  value: _filter.walletId,
                  items: {for (final w in wallets) w.id: w.name},
                  onChanged: (v) => _setFilter(_filter.copyWith(walletId: () => v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownChip<T>({
    required String label,
    required T? value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return PopupMenuButton<T?>(
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem<T?>(value: null, child: Text('Tất cả ${label.toLowerCase()}')),
        for (final e in items.entries) PopupMenuItem<T?>(value: e.key, child: Text(e.value)),
      ],
      child: Chip(
        avatar: const Icon(Icons.filter_list, size: 16),
        label: Text(value == null ? label : (items[value] ?? label)),
        backgroundColor: value == null ? null : AppColors.primaryFixed.withOpacity(0.5),
      ),
    );
  }

  Widget _dayHeader(DateTime day, List<TransactionModel> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = day == today
        ? 'Hôm nay'
        : day == today.subtract(const Duration(days: 1))
            ? 'Hôm qua'
            : formatDate(day);
    final net = items.fold(0, (s, t) => s + t.signedAmount);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Text(CurrencyFormatter.formatVND(net, showSign: true),
              style: TextStyle(fontSize: 12, color: net >= 0 ? AppColors.primary : AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _tile(TransactionModel tx) {
    final color = colorFromHex(tx.categoryColor) ?? (tx.isIncome ? AppColors.primary : AppColors.tertiary);
    final time = '${tx.occurredAt.hour.toString().padLeft(2, '0')}:${tx.occurredAt.minute.toString().padLeft(2, '0')}';
    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _delete(tx),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        elevation: 0,
        color: AppColors.surfaceContainerLowest,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          onTap: () => _edit(tx),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(tx.icon, color: color, size: 20),
          ),
          title: Text(tx.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(
            [tx.categoryName ?? 'Chưa phân loại', tx.walletName ?? '', time].where((s) => s.isNotEmpty).join(' • '),
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tx.receiptPath != null)
                IconButton(
                  tooltip: 'Xem hóa đơn',
                  icon: const Icon(Icons.receipt_long, size: 18, color: AppColors.secondary),
                  onPressed: () =>
                      showReceiptImage(context, ref.read(receiptRepositoryProvider).signedUrl(tx.receiptPath!)),
                ),
              Text(
                CurrencyFormatter.formatVND(tx.signedAmount, showSign: true),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: tx.isIncome ? AppColors.primary : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
