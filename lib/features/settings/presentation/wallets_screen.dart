import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../home/models/wallet_model.dart';
import '../../home/providers/home_providers.dart';

/// "Nguồn tiền": self-declared places where money sits (cash, a bank account,
/// an e-wallet...). Only labels with an opening balance — nothing is linked.
class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(walletsProvider);
    final wallets = async.valueOrNull?.where((w) => !w.isArchived).toList();
    final total = wallets?.fold(0, (s, w) => s + w.balance) ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Nguồn tiền', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm nguồn tiền'),
        onPressed: () => showFormSheet<void>(context, const _WalletForm()),
      ),
      body: wallets == null
          ? Center(child: async.hasError ? Text(friendlyError(async.error!)) : const CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Text('Tổng: ${CurrencyFormatter.formatVND(total)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Nguồn tiền chỉ để bạn biết tiền đang nằm ở đâu. Túi Khôn không liên kết ngân hàng hay ví điện tử; '
                  'số dư = số dư ban đầu + thu − chi bạn đã ghi.',
                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                for (final w in wallets)
                  Card(
                    elevation: 0,
                    color: AppColors.surfaceContainerLowest,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryFixed.withOpacity(0.5),
                        child: Icon(w.iconData, color: AppColors.primary, size: 20),
                      ),
                      title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(w.typeLabel, style: const TextStyle(fontSize: 11)),
                      trailing: Text(
                        CurrencyFormatter.formatVND(w.balance),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: w.balance < 0 ? AppColors.error : AppColors.onSurface,
                        ),
                      ),
                      onTap: () => showFormSheet<void>(context, _WalletForm(initial: w)),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _WalletForm extends ConsumerStatefulWidget {
  const _WalletForm({this.initial});

  final WalletModel? initial;

  @override
  ConsumerState<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends ConsumerState<_WalletForm> {
  static const _types = {
    'cash': ('Tiền mặt', 'payments'),
    'bank': ('Tài khoản ngân hàng', 'account_balance'),
    'ewallet': ('Ví điện tử', 'account_balance_wallet'),
    'other': ('Khác', 'savings'),
  };

  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _initial = TextEditingController(
    text: (widget.initial?.initialBalance ?? 0) == 0 ? '' : '${widget.initial!.initialBalance}',
  );
  late String _type = widget.initial?.type ?? 'cash';
  bool _busy = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return showToast(context, 'Nhập tên nguồn tiền (vd: TK Vietcombank)');
    setState(() => _busy = true);
    try {
      await ref.read(walletRepositoryProvider).saveWallet(WalletModel(
            id: widget.initial?.id ?? '',
            name: _name.text,
            type: _type,
            icon: _types[_type]!.$2,
            color: widget.initial?.color,
            initialBalance: MoneyField.valueOf(_initial),
          ));
      ref.refreshWalletData();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final ok = await confirmDialog(
      context,
      title: 'Xoá "${widget.initial!.name}"?',
      message: 'Nếu đã có giao dịch, nguồn tiền sẽ được ẩn đi (giao dịch cũ giữ nguyên) thay vì xoá hẳn.',
    );
    if (!ok) return;
    try {
      final archived = await ref.read(walletRepositoryProvider).removeWallet(widget.initial!.id);
      ref.refreshWalletData();
      if (mounted) {
        Navigator.pop(context);
        showToast(context, archived ? 'Đã ẩn nguồn tiền (vẫn giữ lịch sử giao dịch)' : 'Đã xoá nguồn tiền');
      }
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: widget.initial == null ? 'Thêm nguồn tiền' : 'Sửa nguồn tiền',
      submitLabel: 'Lưu',
      busy: _busy,
      onSubmit: _save,
      trailing: widget.initial == null
          ? null
          : IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: _remove),
      children: [
        TextField(controller: _name, maxLength: 50, decoration: sheetInputDecoration('Tên (vd: TK Vietcombank, Ví MoMo)')),
        Wrap(
          spacing: 8,
          children: [
            for (final e in _types.entries)
              ChoiceChip(
                label: Text(e.value.$1),
                selected: _type == e.key,
                onSelected: (_) => setState(() => _type = e.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        MoneyField(controller: _initial, label: 'Số dư ban đầu (VND)'),
      ],
    );
  }
}
