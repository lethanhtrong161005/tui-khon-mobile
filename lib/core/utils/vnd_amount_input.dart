import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// UI-only whole-VND parsing. Never use display strings in CSV or sync payloads.
int parseVndInput(String text) {
  final value = text.trim();
  if (!_valid(value)) return 0;
  return int.tryParse(value.replaceAll(RegExp('[., \u00a0\u202f]'), '')) ?? 0;
}

bool _valid(String text) =>
    RegExp(r'^-?\d+$').hasMatch(text) ||
    RegExp(r'^-?\d{1,3}([., \u00a0\u202f])\d{3}(?:\1\d{3})*$').hasMatch(text);

String _group(String digits, String locale) => digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}${locale.startsWith('en') ? ',' : '.'}');

void formatVndController(TextEditingController controller, String locale) {
  if (controller.text.isEmpty || !_valid(controller.text)) return;
  final formatted = _group('${parseVndInput(controller.text)}', locale);
  if (formatted == controller.text) return;
  int position(int offset) => _offset(
      formatted,
      controller.text
          .substring(0, offset.clamp(0, controller.text.length))
          .replaceAll(RegExp(r'\D'), '')
          .length);
  final selection = controller.selection;
  controller.value = TextEditingValue(
      text: formatted,
      selection: selection.isValid
          ? TextSelection(
              baseOffset: position(selection.baseOffset),
              extentOffset: position(selection.extentOffset))
          : TextSelection.collapsed(offset: formatted.length));
}

int _offset(String text, int digits) {
  if (digits <= 0) return 0;
  var count = 0;
  for (var i = 0; i < text.length; i++) {
    if (RegExp(r'\d').hasMatch(text[i]) && ++count == digits) return i + 1;
  }
  return text.length;
}

/// Groups while typing, preserving cursor and selection. Ambiguous decimal,
/// negative, exponent and shorthand pastes are rejected rather than revalued.
class VndAmountInputFormatter extends TextInputFormatter {
  VndAmountInputFormatter(this.locale);
  final String locale;
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (!newValue.composing.isCollapsed) return newValue;
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^[0-9., \u00a0\u202f]+$').hasMatch(text)) return oldValue;
    var prefix = 0, suffix = 0;
    while (prefix < oldValue.text.length &&
        prefix < text.length &&
        oldValue.text[prefix] == text[prefix]) {
      prefix++;
    }
    while (suffix < oldValue.text.length - prefix &&
        suffix < text.length - prefix &&
        oldValue.text[oldValue.text.length - suffix - 1] ==
            text[text.length - suffix - 1]) {
      suffix++;
    }
    final inserted = text.substring(prefix, text.length - suffix);
    if (RegExp(r'\D').hasMatch(inserted) && !_valid(text)) return oldValue;
    final raw = text.replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty || raw.length > 13) return oldValue;
    final digits = raw.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final formatted = _group(digits, locale);
    int selectionOffset(int offset) {
      final safe = offset.clamp(0, text.length);
      final preceding =
          text.substring(0, safe).replaceAll(RegExp(r'\D'), '').length;
      return _offset(formatted,
          (preceding - (raw.length - digits.length)).clamp(0, digits.length));
    }

    return TextEditingValue(
        text: formatted,
        selection: TextSelection(
            baseOffset: selectionOffset(newValue.selection.baseOffset),
            extentOffset: selectionOffset(newValue.selection.extentOffset)));
  }
}
