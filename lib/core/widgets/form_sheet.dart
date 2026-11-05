import '../utils/localized_format.dart';
import '../utils/vnd_amount_input.dart';
import '../theme/semantic_colors.dart';
import '../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';

/// Opens [child] as a rounded bottom sheet that moves above the keyboard.
Future<T?> showFormSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => child,
  );
}

/// Frame of every add / edit sheet: handle, title, fields, primary button.
/// Uses [Material] (not a decorated Container) so ListTiles inside can paint ink.
class FormSheet extends StatelessWidget {
  const FormSheet({
    super.key,
    required this.title,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    this.busy = false,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final bool busy;

  /// Optional action next to the title (e.g. a delete button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: appPalette(context).surfaceContainerLowest,
        borderRadius:
            const BorderRadius.vertical(top: const Radius.circular(28)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom -
                          MediaQuery.paddingOf(context).top)
                      .clamp(0.0, double.infinity) *
                  0.9),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            appPalette(context).outlineVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...children,
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: busy ? null : onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appPalette(context).primary,
                        foregroundColor: appPalette(context).onPrimary,
                        minimumSize: const Size(0, 50),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(submitLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration sheetInputDecoration(String label,
        {String? helper, String? hint}) =>
    InputDecoration(
      labelText: label,
      helperText: helper,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );

/// Whole-VND amount input showing the formatted value underneath.
class MoneyField extends StatefulWidget {
  const MoneyField(
      {super.key,
      required this.controller,
      required this.label,
      this.autofocus = false});

  final TextEditingController controller;
  final String label;
  final bool autofocus;

  static int valueOf(TextEditingController controller) =>
      parseVndInput(controller.text);

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    formatVndController(widget.controller, appL10n(context).localeName);
  }

  @override
  void didUpdateWidget(covariant MoneyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      formatVndController(widget.controller, appL10n(context).localeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = MoneyField.valueOf(widget.controller);
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [VndAmountInputFormatter(appL10n(context).localeName)],
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      decoration: sheetInputDecoration(widget.label,
          helper: value > 0 ? formatMoney(context, value) : null),
      onChanged: (_) => setState(() {}),
    );
  }
}

/// Date row that opens a date picker; [onChanged] receives null when cleared.
class DatePickerTile extends StatelessWidget {
  const DatePickerTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.event, color: appPalette(context).primary),
      title: Text(value == null ? label : '$label: ${formatDate(value!)}',
          style: const TextStyle(fontSize: 14)),
      trailing: value == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => onChanged(null)),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: firstDate ?? DateTime(now.year - 5),
          lastDate: lastDate ?? DateTime(now.year + 10),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String? confirm}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(appL10n(context).msgCancel42)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm ?? appL10n(context).msgDelete41,
              style: TextStyle(color: appPalette(context).error)),
        ),
      ],
    ),
  );
  return ok == true;
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Asks for a single amount; returns null when cancelled.
/// The dialog owns its controller so the closing animation never touches a disposed one.
Future<int?> showAmountDialog(BuildContext context,
    {required String title, String? label}) {
  return showDialog<int>(
      context: context,
      builder: (_) => _AmountDialog(
          title: title, label: label ?? appL10n(context).msgAmount26));
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.title, required this.label});

  final String title;
  final String label;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: MoneyField(
          controller: _controller, label: widget.label, autofocus: true),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(appL10n(context).msgCancel42)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: appPalette(context).primary,
              foregroundColor: appPalette(context).onPrimary),
          onPressed: () =>
              Navigator.pop(context, MoneyField.valueOf(_controller)),
          child: Text(appL10n(context).msgSave43),
        ),
      ],
    );
  }
}
