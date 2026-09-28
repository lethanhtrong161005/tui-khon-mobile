import 'package:intl/intl.dart';

/// CurrencyFormatter provides standardized VND currency formatting
/// and parses Vietnamese colloquial slang into numeric values.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  /// Formats an integer or double into standard Vietnamese currency string.
  /// Example: 42850000 -> "42.850.000 ₫"
  static String formatVND(num amount, {bool showSign = false}) {
    final formatted = _formatter.format(amount.abs()).trim();
    if (showSign) {
      if (amount > 0) return '+$formatted';
      if (amount < 0) return '-$formatted';
    }
    return formatted;
  }

  /// Parses natural Vietnamese slang into exact monetary figures.
  /// Handles "50 củ" -> 50,000,000, "65k" -> 65,000, "2 tr" -> 2,000,000.
  static int parseSlangAmount(String input) {
    final lower = input.toLowerCase().trim();

    // Check for "củ" (1 củ = 1,000,000 VND)
    final cuMatch = RegExp(r'(\d+([\.,]\d+)?)\s*(củ|triệu|tr)').firstMatch(lower);
    if (cuMatch != null) {
      final numberPart = double.tryParse(cuMatch.group(1)!.replaceAll(',', '.')) ?? 0;
      return (numberPart * 1000000).round();
    }

    // Check for "k" or "nghìn" (1k = 1,000 VND)
    final kMatch = RegExp(r'(\d+([\.,]\d+)?)\s*(k|nghìn|ngàn)').firstMatch(lower);
    if (kMatch != null) {
      final numberPart = double.tryParse(kMatch.group(1)!.replaceAll(',', '.')) ?? 0;
      return (numberPart * 1000).round();
    }

    // Fallback: extract any digits
    final digitMatch = RegExp(r'(\d+)').firstMatch(lower);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1)!) ?? 0;
    }

    return 0;
  }
}
