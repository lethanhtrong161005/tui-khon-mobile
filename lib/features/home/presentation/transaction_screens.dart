import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/local_wallet_repository.dart';
import '../models/transaction_model.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final _repository = LocalWalletRepository.instance;
  TransactionType? _type;
  String? _categoryId;
  DateTime? _from;
  DateTime? _to;
  int _pageSize = 20;

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_from ?? DateTime.now()) : (_to ?? DateTime.now()),
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => isFrom ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _repository,
      builder: (context, _) {
        final transactions = _repository.listTransactions(
          type: _type,
          categoryId: _categoryId,
          from: _from,
          to: _to,
        );
        final page = transactions.take(_pageSize).toList();
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Giao dịch'),
            actions: [
              IconButton(
                tooltip: 'Quản lý danh mục',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CategoryManagementScreen())),
                icon: const Icon(Icons.category_outlined),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Thêm giao dịch'),
          ),
          body: Column(
            children: [
              _buildFilters(),
              Expanded(
                child: page.isEmpty
                    ? const Center(child: Text('Chưa có giao dịch phù hợp.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: page.length +
                            (page.length < transactions.length ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == page.length) {
                            return TextButton(
                                onPressed: () =>
                                    setState(() => _pageSize += 20),
                                child: const Text('Tải thêm'));
                          }
                          final tx = page[index];
                          return _TransactionTile(
                            transaction: tx,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => TransactionDetailScreen(
                                        transactionId: tx.id))),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    final categories = _repository.categories
        .where((c) => _type == null || c.type == _type)
        .toList();
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId))
      _categoryId = null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: AppColors.surface,
      child: Column(
        children: [
          SegmentedButton<TransactionType?>(
            segments: const [
              ButtonSegment(value: null, label: Text('Tất cả')),
              ButtonSegment(
                  value: TransactionType.income, label: Text('Thu nhập')),
              ButtonSegment(
                  value: TransactionType.expense, label: Text('Chi tiêu')),
            ],
            selected: {_type},
            onSelectionChanged: (selection) => setState(() {
              _type = selection.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _categoryId,
                  decoration: const InputDecoration(
                      labelText: 'Danh mục',
                      isDense: true,
                      border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Tất cả danh mục')),
                    ...categories.map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.name)))
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
              ),
              IconButton(
                  tooltip: 'Từ ngày',
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.calendar_month)),
              IconButton(
                  tooltip: 'Đến ngày',
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.event)),
              if (_from != null || _to != null)
                IconButton(
                    tooltip: 'Xóa ngày lọc',
                    onPressed: () => setState(() {
                          _from = null;
                          _to = null;
                        }),
                    icon: const Icon(Icons.clear)),
            ],
          ),
          if (_from != null || _to != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  '${_from == null ? '...' : _formatDate(_from!)} – ${_to == null ? '...' : _formatDate(_to!)}',
                  style: const TextStyle(color: AppColors.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  void _openForm([TransactionModel? transaction]) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TransactionFormScreen(transaction: transaction)));
  }
}

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({super.key, this.transaction});
  final TransactionModel? transaction;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _repository = LocalWalletRepository.instance;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late TransactionType _type;
  late DateTime _date;
  String? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _type = tx?.type ?? TransactionType.expense;
    _date = tx?.timestamp ?? DateTime.now();
    _categoryId = tx?.categoryId;
    _amountController.text = tx == null ? '' : tx.amount.toStringAsFixed(0);
    _descriptionController.text = tx?.description ?? '';
    _noteController.text = tx?.note ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _repository,
      builder: (context, _) {
        final categories =
            _repository.categories.where((c) => c.type == _type).toList();
        if (_categoryId != null && !categories.any((c) => c.id == _categoryId))
          _categoryId = null;
        return Scaffold(
          appBar: AppBar(
              title: Text(widget.transaction == null
                  ? 'Thêm giao dịch'
                  : 'Sửa giao dịch')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Chi tiêu'),
                        icon: Icon(Icons.arrow_upward)),
                    ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Thu nhập'),
                        icon: Icon(Icons.arrow_downward)),
                  ],
                  selected: {_type},
                  onSelectionChanged: _saving
                      ? null
                      : (selection) => setState(() {
                            _type = selection.first;
                            _categoryId = null;
                          }),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Số tiền (₫)',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder()),
                  validator: (value) {
                    final amount = double.tryParse(
                        (value ?? '').replaceAll(',', '').replaceAll('.', ''));
                    return amount == null || amount <= 0
                        ? 'Số tiền phải lớn hơn 0'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: const InputDecoration(
                      labelText: 'Danh mục', border: OutlineInputBorder()),
                  items: categories
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (value) =>
                      value == null ? 'Vui lòng chọn danh mục' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      hintText: 'Ví dụ: Ăn trưa cùng đồng nghiệp',
                      border: OutlineInputBorder()),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Vui lòng nhập mô tả'
                      : null,
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ngày giao dịch'),
                  subtitle: Text(_formatDate(_date)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: _pickDate,
                ),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Ghi chú (không bắt buộc)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(widget.transaction == null
                      ? 'Lưu giao dịch'
                      : 'Cập nhật giao dịch'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(1970),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null)
      setState(() => _date = DateTime(
          picked.year, picked.month, picked.day, _date.hour, _date.minute));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    TransactionCategory? category;
    for (final candidate in _repository.categories) {
      if (candidate.id == _categoryId && candidate.type == _type)
        category = candidate;
    }
    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Danh mục không hợp lệ.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final previous = widget.transaction;
      final amount = double.parse(
          _amountController.text.replaceAll(',', '').replaceAll('.', ''));
      final tx = TransactionModel(
        id: previous?.id ?? 'tx_${DateTime.now().microsecondsSinceEpoch}',
        title: _descriptionController.text.trim(),
        description: _descriptionController.text.trim(),
        note: _noteController.text.trim(),
        category: category.name,
        categoryId: category.id,
        amount: amount,
        type: _type,
        ownerId: LocalWalletRepository.localUserId,
        walletSource: previous?.walletSource ?? 'Tiền mặt',
        timestamp: _date,
        icon: previous?.icon ??
            (_type == TransactionType.income ? Icons.savings : Icons.payments),
      );
      if (previous == null) {
        await _repository.addTransaction(tx);
      } else {
        await _repository.updateTransaction(previous.id, tx);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});
  final String transactionId;

  @override
  Widget build(BuildContext context) {
    final repository = LocalWalletRepository.instance;
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final tx = repository.getTransaction(transactionId);
        return Scaffold(
          appBar: AppBar(title: const Text('Chi tiết giao dịch')),
          body: tx == null
              ? const Center(child: Text('Không tìm thấy giao dịch.'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Icon(tx.icon,
                        size: 48,
                        color: tx.type == TransactionType.income
                            ? AppColors.primary
                            : AppColors.error),
                    const SizedBox(height: 12),
                    Text(tx.description,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                        '${tx.type == TransactionType.income ? '+' : '-'}${CurrencyFormatter.formatVND(tx.amount)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: tx.type == TransactionType.income
                                ? AppColors.primary
                                : AppColors.error)),
                    const SizedBox(height: 24),
                    _detailRow(
                        'Loại',
                        tx.type == TransactionType.income
                            ? 'Thu nhập'
                            : 'Chi tiêu'),
                    _detailRow('Danh mục', tx.category),
                    _detailRow('Ngày', _formatDate(tx.timestamp)),
                    _detailRow('Tài khoản', tx.walletSource),
                    if (tx.note.isNotEmpty) _detailRow('Ghi chú', tx.note),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  TransactionFormScreen(transaction: tx))),
                      icon: const Icon(Icons.edit),
                      label: const Text('Sửa giao dịch'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _confirmDelete(context, repository),
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.error),
                      label: const Text('Xóa giao dịch',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, LocalWalletRepository repository) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content: const Text('Thao tác này sẽ cập nhật lại số dư.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repository.deleteTransaction(transactionId);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }
}

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});
  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _repository = LocalWalletRepository.instance;
  TransactionType _type = TransactionType.expense;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _repository,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Danh mục')),
          floatingActionButton: FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Thêm danh mục')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Chi tiêu')),
                    ButtonSegment(
                        value: TransactionType.income, label: Text('Thu nhập')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (value) =>
                      setState(() => _type = value.first),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  children: _repository.categories
                      .where((c) => c.type == _type)
                      .map((category) => Card(
                            child: ListTile(
                              leading: Icon(_type == TransactionType.income
                                  ? Icons.savings_outlined
                                  : Icons.category_outlined),
                              title: Text(category.name),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) => action == 'edit'
                                    ? _edit(category)
                                    : _delete(category),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'edit', child: Text('Đổi tên')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('Xóa')),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _add() async {
    final name = await _nameDialog('Thêm danh mục');
    if (name == null) return;
    try {
      await _repository.addCategory(name, _type);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _edit(TransactionCategory category) async {
    final name = await _nameDialog('Đổi tên danh mục', initial: category.name);
    if (name == null) return;
    try {
      await _repository.updateCategory(category.id, name);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(TransactionCategory category) async {
    try {
      await _repository.deleteCategory(category.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<String?> _nameDialog(String title, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Tên danh mục')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('Lưu'))
              ],
            ));
    controller.dispose();
    if (result != null && result.isEmpty)
      _showError(ArgumentError('Tên danh mục không được để trống.'));
    return result?.isEmpty == true ? null : result;
  }

  void _showError(Object error) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.onTap});
  final TransactionModel transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final income = transaction.type == TransactionType.income;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
            backgroundColor: (income ? AppColors.primary : AppColors.tertiary)
                .withOpacity(0.12),
            child: Icon(transaction.icon,
                color: income ? AppColors.primary : AppColors.tertiary)),
        title: Text(transaction.description,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${transaction.category} • ${_formatDate(transaction.timestamp)}'),
        trailing: Text(
            '${income ? '+' : '-'}${CurrencyFormatter.formatVND(transaction.amount)}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: income ? AppColors.primary : AppColors.onSurface)),
      ),
    );
  }
}

Widget _detailRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: AppColors.onSurfaceVariant))),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)))
      ]),
    );

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _errorMessage(Object error) {
  final message = error
      .toString()
      .replaceFirst('ArgumentError: ', '')
      .replaceFirst('Bad state: ', '');
  return message;
}
