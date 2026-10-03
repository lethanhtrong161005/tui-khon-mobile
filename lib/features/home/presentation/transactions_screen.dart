import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../controllers/home_controller.dart';
import '../models/transaction_model.dart';
import 'widgets/recent_transactions_section.dart';

/// TransactionsScreen provides the complete transaction ledger view (PRM-3 Sections 4 & 5)
/// with type filters (Tất cả / Thu nhập / Chi tiêu), category chips, search,
/// transaction details bottom sheet, and manual transaction creation.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionType? _selectedTypeFilter; // null = Tất cả
  String _selectedCategory = 'Tất cả';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _categories = [
    'Tất cả',
    'Ăn uống',
    'Nhà ở',
    'Mua sắm',
    'Di chuyển',
    'Lương',
    'Thưởng',
    'Khác',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeControllerProvider);
    final filtered = homeState.allTransactions.where((tx) {
      if (_selectedTypeFilter != null && tx.type != _selectedTypeFilter) {
        return false;
      }
      if (_selectedCategory != 'Tất cả' &&
          !tx.category.toLowerCase().contains(_selectedCategory.toLowerCase())) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = tx.title.toLowerCase().contains(q);
        final matchCat = tx.category.toLowerCase().contains(q);
        final matchSource = tx.walletSource.toLowerCase().contains(q);
        return matchTitle || matchCat || matchSource;
      }
      return true;
    }).toList();

    final filteredIncome = filtered
        .where((tx) => tx.isIncome)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    final filteredExpense = filtered
        .where((tx) => !tx.isIncome)
        .fold(0.0, (sum, tx) => sum + tx.amount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.92),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sổ giao dịch',
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => showAddTransactionBottomSheet(context, ref),
              icon: const Icon(Icons.add_circle, size: 18),
              label: const Text(
                'Thêm mới',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Banner (Balance = Income - Expense)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _summaryColumn(
                    label: 'Tổng thu',
                    value: CurrencyFormatter.formatVND(
                      filteredIncome,
                      showSign: true,
                    ),
                    valueColor: AppColors.primaryFixed,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _summaryColumn(
                    label: 'Tổng chi',
                    value: CurrencyFormatter.formatVND(
                      -filteredExpense,
                      showSign: true,
                    ),
                    valueColor: AppColors.errorContainer,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _summaryColumn(
                    label: 'Chênh lệch (Thu - Chi)',
                    value: CurrencyFormatter.formatVND(
                      filteredIncome - filteredExpense,
                      showSign: true,
                    ),
                    valueColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.onSurfaceVariant,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  hintText: 'Tìm theo tên giao dịch, danh mục, ví...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: AppColors.outline,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Type Filter Tabs (Tất cả / Chi tiêu / Thu nhập)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _typeFilterChip('Tất cả', null),
                const SizedBox(width: 8),
                _typeFilterChip('Chi tiêu', TransactionType.expense),
                const SizedBox(width: 8),
                _typeFilterChip('Thu nhập', TransactionType.income),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Category Horizontal Filter
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final cat = _categories[idx];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: AppColors.primaryFixed,
                  backgroundColor: AppColors.surfaceContainerLowest,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Transaction List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy giao dịch phù hợp',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final tx = filtered[idx];
                      return TransactionListTile(
                        transaction: tx,
                        onTap: () =>
                            showTransactionDetailBottomSheet(context, ref, tx),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryColumn({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _typeFilterChip(String label, TransactionType? type) {
    final isSelected = _selectedTypeFilter == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTypeFilter = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a Stitch-styled bottom sheet displaying the details of a single transaction
/// with the option to delete it and recalculate Dashboard balance.
void showTransactionDetailBottomSheet(
  BuildContext context,
  WidgetRef ref,
  TransactionModel tx,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isIncome = tx.isIncome;
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tx.categoryContainerColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(tx.icon, color: tx.categoryAccentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isIncome ? 'Khoản thu nhập' : 'Khoản chi tiêu',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isIncome
                              ? AppColors.primary
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.formatVND(tx.signedAmount, showSign: true),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isIncome ? AppColors.primary : AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _detailRow('Danh mục', tx.category),
            _detailRow('Nguồn tiền / Ví', tx.walletSource),
            _detailRow('Thời gian', tx.formattedFullDate),
            if (tx.badgeText != null) _detailRow('Phương thức ghi', tx.badgeText!),
            if (tx.note != null && tx.note!.isNotEmpty)
              _detailRow('Ghi chú', tx.note!),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(homeControllerProvider.notifier)
                          .deleteTransaction(tx.id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã xóa giao dịch "${tx.title}"'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Xóa giao dịch'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Shows a bottom sheet form to manually add a new transaction and immediately
/// update the Dashboard state via Riverpod.
void showAddTransactionBottomSheet(BuildContext context, WidgetRef ref) {
  final titleCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  TransactionType selectedType = TransactionType.expense;
  String selectedCategory = 'Ăn uống';
  String selectedWallet = 'Tiền mặt';

  const expenseCategories = ['Ăn uống', 'Di chuyển', 'Nhà ở', 'Mua sắm', 'Khác'];
  const incomeCategories = ['Lương', 'Thưởng', 'Thu nhập khác'];
  const wallets = ['Tiền mặt', 'Ví MoMo', 'Vietcombank', 'Techcombank', 'Chuyển khoản'];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final categories = selectedType == TransactionType.expense
              ? expenseCategories
              : incomeCategories;
          if (!categories.contains(selectedCategory)) {
            selectedCategory = categories.first;
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.outlineVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Thêm giao dịch mới',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Type Toggle (Chi tiêu / Thu nhập)
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Chi tiêu (-)'),
                            selected: selectedType == TransactionType.expense,
                            onSelected: (_) => setSheetState(
                              () => selectedType = TransactionType.expense,
                            ),
                            selectedColor: AppColors.errorContainer,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Thu nhập (+)'),
                            selected: selectedType == TransactionType.income,
                            onSelected: (_) => setSheetState(
                              () => selectedType = TransactionType.income,
                            ),
                            selectedColor: AppColors.primaryFixed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tên giao dịch (vd: Ăn trưa, Tiền lương)',
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Số tiền (VND, hoặc gõ 65k, 2tr)',
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Danh mục',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: categories.map((cat) {
                        final isSel = selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSel,
                          onSelected: (_) =>
                              setSheetState(() => selectedCategory = cat),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    const Text(
                      'Nguồn ví',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: wallets.map((w) {
                        final isSel = selectedWallet == w;
                        return ChoiceChip(
                          label: Text(w),
                          selected: isSel,
                          onSelected: (_) =>
                              setSheetState(() => selectedWallet = w),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú (tùy chọn)',
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final rawAmount = amountCtrl.text.trim();
                          final parsedAmount =
                              CurrencyFormatter.parseSlangAmount(rawAmount);
                          if (parsedAmount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Vui lòng nhập số tiền lớn hơn 0'),
                              ),
                            );
                            return;
                          }
                          final title = titleCtrl.text.trim().isEmpty
                              ? selectedCategory
                              : titleCtrl.text.trim();
                          final isInc = selectedType == TransactionType.income;

                          final newTx = TransactionModel(
                            id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
                            title: title,
                            category: selectedCategory,
                            amount: parsedAmount.toDouble(),
                            type: selectedType,
                            walletSource: selectedWallet,
                            timestamp: DateTime.now(),
                            icon: TransactionModel.iconForCategory(
                              selectedCategory,
                              isIncome: isInc,
                            ),
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                          );

                          ref
                              .read(homeControllerProvider.notifier)
                              .addTransaction(newTx);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã lưu "$title" (${CurrencyFormatter.formatVND(newTx.signedAmount, showSign: true)})',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text(
                          'Lưu giao dịch',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
