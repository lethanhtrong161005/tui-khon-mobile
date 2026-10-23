import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/icon_color_picker.dart';
import '../../home/models/category_model.dart';
import '../../home/models/transaction_model.dart';
import '../../home/providers/home_providers.dart';

/// Thêm / sửa / xoá danh mục thu chi.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesProvider);
    final categories = async.valueOrNull;

    Widget list(TransactionType type) {
      if (categories == null) {
        return Center(
          child: async.hasError ? Text(friendlyError(async.error!)) : const CircularProgressIndicator(),
        );
      }
      final items = categories.where((c) => c.type == type).toList();
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          for (final c in items)
            Card(
              elevation: 0,
              color: AppColors.surfaceContainerLowest,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: c.colorValue.withOpacity(0.15),
                  child: Icon(c.iconData, color: c.colorValue, size: 20),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showCategoryForm(context, type: type, initial: c),
              ),
            ),
        ],
      );
    }

    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: const Text('Danh mục', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            bottom: const TabBar(
              labelColor: AppColors.primary,
              indicatorColor: AppColors.primary,
              tabs: [Tab(text: 'Chi tiêu'), Tab(text: 'Thu nhập')],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Thêm danh mục'),
            onPressed: () => showCategoryForm(
              context,
              type: DefaultTabController.of(context).index == 0 ? TransactionType.expense : TransactionType.income,
            ),
          ),
          body: TabBarView(children: [list(TransactionType.expense), list(TransactionType.income)]),
        ),
      ),
    );
  }
}

Future<void> showCategoryForm(BuildContext context, {required TransactionType type, CategoryModel? initial}) {
  return showFormSheet<void>(context, _CategoryForm(type: type, initial: initial));
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({required this.type, this.initial});

  final TransactionType type;
  final CategoryModel? initial;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late String _icon = widget.initial?.icon ?? 'category';
  late String _color = widget.initial?.color ?? kPaletteColors.first;
  bool _busy = false;

  void _refresh() {
    ref.invalidate(categoriesProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(monthlySummaryProvider);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return showToast(context, 'Nhập tên danh mục');
    setState(() => _busy = true);
    try {
      await ref.read(walletRepositoryProvider).saveCategory(CategoryModel(
            id: widget.initial?.id ?? '',
            name: _name.text,
            type: widget.initial?.type ?? widget.type,
            icon: _icon,
            color: _color,
          ));
      _refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Xoá danh mục "${widget.initial!.name}"?',
      message: 'Các giao dịch cũ vẫn được giữ và chuyển thành "Chưa phân loại". Ngân sách của danh mục này sẽ bị xoá.',
    );
    if (!ok) return;
    try {
      await ref.read(walletRepositoryProvider).deleteCategory(widget.initial!.id);
      _refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.initial?.type ?? widget.type;
    return FormSheet(
      title: widget.initial == null
          ? (type == TransactionType.expense ? 'Danh mục chi mới' : 'Danh mục thu mới')
          : 'Sửa danh mục',
      submitLabel: 'Lưu',
      busy: _busy,
      onSubmit: _save,
      trailing: widget.initial == null
          ? null
          : IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: _delete),
      children: [
        TextField(controller: _name, maxLength: 50, decoration: sheetInputDecoration('Tên danh mục')),
        const Text('Biểu tượng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        IconPickerGrid(selected: _icon, color: colorFromHex(_color)!, onChanged: (v) => setState(() => _icon = v)),
        const SizedBox(height: 12),
        const Text('Màu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ColorPickerRow(selected: _color, onChanged: (v) => setState(() => _color = v)),
      ],
    );
  }
}
