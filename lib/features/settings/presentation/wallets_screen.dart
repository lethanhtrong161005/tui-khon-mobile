import '../../../core/utils/localized_format.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
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
      backgroundColor: appPalette(context).surface,
      appBar: AppBar(
        backgroundColor: appPalette(context).surface,
        elevation: 0,
        title: Text(appL10n(context).wallets,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: appPalette(context).primary,
        foregroundColor: appPalette(context).onPrimary,
        icon: const Icon(Icons.add),
        label: Text(appL10n(context).msgAddMoneySource426),
        onPressed: () => showFormSheet<void>(context, const _WalletForm()),
      ),
      body: wallets == null
          ? Center(
              child: async.hasError
                  ? Text(friendlyError(async.error!, context: context))
                  : const CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Text(
                    appL10n(context)
                        .msgTotal427((formatMoney(context, total)).toString()),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  appL10n(context).msgMoneySourcesAreLabelsForTracking428,
                  style: TextStyle(
                      fontSize: 11,
                      color: appPalette(context).onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                for (final w in wallets)
                  Card(
                    elevation: 0,
                    color: appPalette(context).surfaceContainerLowest,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primaryFixed.withOpacity(0.5),
                        child: Icon(w.iconData,
                            color: appPalette(context).primary, size: 20),
                      ),
                      title: Text(w.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          switch (w.type) {
                            'cash' => appL10n(context).msgCash429,
                            'bank' => appL10n(context).msgBankAccount430,
                            'ewallet' => appL10n(context).msgEWallet431,
                            _ => appL10n(context).msgOther432,
                          },
                          style: const TextStyle(fontSize: 11)),
                      trailing: Text(
                        formatMoney(context, w.balance),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: w.balance < 0
                              ? appPalette(context).error
                              : appPalette(context).onSurface,
                        ),
                      ),
                      onTap: () =>
                          showFormSheet<void>(context, _WalletForm(initial: w)),
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
  Map<String, (String, String)> get _types => {
        'cash': (appL10n(context).msgCash429, 'payments'),
        'bank': (appL10n(context).msgBankAccount430, 'account_balance'),
        'ewallet': (appL10n(context).msgEWallet431, 'account_balance_wallet'),
        'other': (appL10n(context).msgOther432, 'savings'),
      };

  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _initial = TextEditingController(
    text: (widget.initial?.initialBalance ?? 0) == 0
        ? ''
        : '${widget.initial!.initialBalance}',
  );
  late String _type = widget.initial?.type ?? 'cash';
  bool _busy = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty)
      return showToast(context, appL10n(context).msgEnterAMoneySourceNameE433);
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
      if (mounted) showToast(context, friendlyError(e, context: context));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final ok = await confirmDialog(
      context,
      title: appL10n(context).msgDelete434((widget.initial!.name).toString()),
      message: appL10n(context).msgIfItHasTransactionsThisSource435,
    );
    if (!ok) return;
    try {
      final archived = await ref
          .read(walletRepositoryProvider)
          .removeWallet(widget.initial!.id);
      ref.refreshWalletData();
      if (mounted) {
        Navigator.pop(context);
        showToast(
            context,
            archived
                ? appL10n(context).msgMoneySourceArchivedTransactionHistoryIs436
                : appL10n(context).msgMoneySourceDeleted437);
      }
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e, context: context));
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
      title: widget.initial == null
          ? appL10n(context).msgAddMoneySource426
          : appL10n(context).msgEditMoneySource438,
      submitLabel: appL10n(context).msgSave43,
      busy: _busy,
      onSubmit: _save,
      trailing: widget.initial == null
          ? null
          : IconButton(
              icon:
                  Icon(Icons.delete_outline, color: appPalette(context).error),
              onPressed: _remove),
      children: [
        TextField(
            controller: _name,
            maxLength: 50,
            decoration: sheetInputDecoration(
                appL10n(context).msgNameEGBankAccountMomo439)),
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
        MoneyField(
            controller: _initial,
            label: appL10n(context).msgOpeningBalanceVnd440),
      ],
    );
  }
}
