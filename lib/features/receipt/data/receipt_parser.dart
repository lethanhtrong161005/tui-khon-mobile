import 'dart:math' as math;

import '../../../core/services/vietnamese_nlp_service.dart';
import '../../home/models/category_model.dart';
import '../../home/models/transaction_model.dart';
import '../../home/models/wallet_model.dart';
import '../../quick_record/data/quick_record_repository.dart';
import 'receipt_ocr_service.dart';

/// Parses printed money without treating thousands or trailing .00 as decimals.
/// Nonzero fractional VND, identifiers and unlabelled numbers are not amounts.
int? printedVnd(String raw) {
  var value = raw.replaceAll(
    RegExp(r'\s|VND|VNĐ|đ|₫', caseSensitive: false),
    '',
  );
  if (!RegExp(r'^\d[\d.,]*$').hasMatch(value)) return null;
  final both = value.contains(',') && value.contains('.');
  if (both) {
    final decimal = value.lastIndexOf(',') > value.lastIndexOf('.') ? ',' : '.';
    final split = value.split(decimal);
    if (split.last != '00') return null;
    value = split.take(split.length - 1).join(decimal);
  } else if (RegExp(r'[.,]\d{2}$').hasMatch(value)) {
    if (!value.endsWith('00')) return null;
    value = value.substring(0, value.length - 3);
  }
  if (!RegExp(r'^\d+(?:[.,]\d{3})*$').hasMatch(value)) return null;
  final amount = int.tryParse(value.replaceAll(RegExp(r'[.,]'), ''));
  return amount != null && amount > 0 && amount <= 9999999999999
      ? amount
      : null;
}

class ReceiptParser {
  ReceiptParser({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  static String normalize(String text) =>
      VietnameseNlpService.normalizeText(text);

  QuickRecordResult parse(
    ReceiptOcrResult ocr, {
    required List<CategoryModel> categories,
    required List<WalletModel> wallets,
    required String receiptPath,
  }) {
    final lines = _visualLines(ocr);
    final text = lines.join('\n');
    final normalized = normalize(text);
    final transfer =
        RegExp(r'chuyen tien|chuyen khoan|transfer|giao dich thanh cong')
            .hasMatch(normalized) &&
        !RegExp(r'phieu tinh tien|hoa don|receipt').hasMatch(normalized);
    final totals = <int>{};
    final fallback = <int>{};
    for (var i = 0; i < lines.length; i++) {
      final label = normalize(lines[i]);
      if (RegExp(
        r'giam gia|tien thua|tra lai|vat|so luong|ma giao dich|so du|phi giao dich|khach tra|cash tendered|change',
      ).hasMatch(label))
        continue;
      final strong = RegExp(
        r'tong thanh toan|tong cong|thanh tien phai tra|grand total|total payment|so tien chuyen|so tien giao dich|^so tien\b',
      ).hasMatch(label);
      final weak = RegExp(r'^tong tien\b|^total\b').hasMatch(label);
      if (!strong && !weak) continue;
      var amounts = _amounts(lines[i]);
      if (amounts.isEmpty &&
          i + 1 < lines.length &&
          !RegExp(
            r'[a-z]',
            caseSensitive: false,
          ).hasMatch(normalize(lines[i + 1]).replaceAll(RegExp('vnd'), ''))) {
        amounts = _amounts(lines[i + 1]);
      }
      (strong ? totals : fallback).addAll(amounts);
    }
    final candidates = totals.isEmpty ? fallback : totals;
    final amount = candidates.length == 1 ? candidates.single : 0;
    DateTime? date;
    final match = RegExp(
      r'\b(\d{2})\s*[/-]\s*(\d{2})\s*[/-]\s*(\d{4})(?:\s+(\d{1,2})\s*:\s*(\d{2}))?',
    ).firstMatch(text);
    if (match != null) {
      final day = int.parse(match[1]!),
          month = int.parse(match[2]!),
          year = int.parse(match[3]!);
      final hour = int.parse(match[4] ?? '12'),
          minute = int.parse(match[5] ?? '0');
      final calendar = DateTime.utc(year, month, day, hour, minute);
      if (calendar.year == year &&
          calendar.month == month &&
          calendar.day == day &&
          hour < 24 &&
          minute < 60 &&
          year >= 2020 &&
          !calendar.isAfter(now().toUtc().add(const Duration(hours: 7)))) {
        date = calendar.subtract(const Duration(hours: 7));
      }
    }
    final active = wallets.where((w) => !w.isArchived).toList();
    final matchedWallets = active.where((w) {
      final name = normalize(w.name)
          .replaceFirst(RegExp(r'^(tk|tai khoan|vi)\s+'), '');
      const banks = [
        'vietcombank',
        'techcombank',
        'vietinbank',
        'bidv',
        'agribank',
        'mb bank',
        'momo',
      ];
      return name.length >= 3 &&
          (normalized.contains(name) ||
              banks.any(
                (bank) => name.contains(bank) && normalized.contains(bank),
              ));
    }).toList();
    final wallet = matchedWallets.length == 1 ? matchedWallets.single : null;
    // A bank's logo or the words "recipient" do not establish the owner's role.
    final incoming = RegExp(r'ban da nhan|tien vao|ghi co|credited|received')
        .hasMatch(normalized);
    final outgoing = RegExp(r'ban da chuyen|ban da gui|tien ra|ghi no|debited')
        .hasMatch(normalized);
    final unknownType = transfer && incoming == outgoing;
    final type = transfer && incoming && !outgoing
        ? TransactionType.income
        : TransactionType.expense;
    final food = RegExp(r'banh mi|pho |com |ca phe|nuoc uong|food')
        .hasMatch(normalized);
    final sameType = categories.where((c) => c.type == type);
    final category =
        sameType
            .where((c) => food && normalize(c.name) == 'an uong')
            .firstOrNull ??
        sameType.where((c) => normalize(c.name).contains('khac')).firstOrNull;
    final merchant =
        lines
            .where(
              (l) =>
                  RegExp(r'co\.?op\s?food', caseSensitive: false).hasMatch(l),
            )
            .firstOrNull ??
        lines
            .where(
              (l) => RegExp(r'saigon co', caseSensitive: false).hasMatch(l),
            )
            .firstOrNull ??
        lines
            .take(5)
            .where(
              (l) =>
                  l.length >= 5 &&
                  l.length <= 100 &&
                  RegExp(r'^[A-Za-zÀ-ỹ]').hasMatch(l) &&
                  !RegExp(
                    r'hoa don|phieu|receipt|vat|dia chi|hotline|tong|so |ngay|date|tel|ma ',
                  ).hasMatch(normalize(l)),
            )
            .firstOrNull;
    final lowConfidence = ocr.lines.any(
      (l) =>
          l.confidence != null &&
          l.confidence! < .6 &&
          RegExp(r'tong tien|tong thanh toan|tong cong|so tien|total')
              .hasMatch(normalize(l.text)),
    );
    final missing = [
      if (amount == 0) 'amount',
      if (date == null) 'date',
      if (wallet == null) 'wallet',
      if (unknownType) 'type',
      if (lowConfidence) 'review',
    ];
    return QuickRecordResult(
      items: [
        QuickRecordItem(
          sourceText: text,
          missingFields: missing,
          draft: TransactionDraft(
            type: type,
            amount: amount,
            occurredAt: date,
            walletId: wallet?.id,
            walletName: wallet?.name,
            categoryId: category?.id,
            categoryName: category?.name,
            note: merchant ?? (transfer ? null : lines.firstOrNull),
            merchant: merchant,
            source: TransactionSource.receipt,
            receiptPath: receiptPath,
          ),
        ),
      ],
      warnings: [if (candidates.length > 1) 'AMOUNT_MISMATCH'],
      recognition: 'ocr',
    );
  }

  static List<int> _amounts(String line) =>
      RegExp(
            r'\d{1,3}(?:\s+\d{3})+(?:[.,]00)?|\d[\d.,]*(?:\s*(?:VND|VNĐ|đ|₫))?',
            caseSensitive: false,
          )
          .allMatches(
            line.replaceAll(
              RegExp(r'(?<=\d)\s+(?=[.,]\d)|(?<=[.,])\s+(?=\d)'),
              '',
            ),
          )
          .map((m) => printedVnd(m[0]!))
          .whereType<int>()
          .toList();

  /// ML Kit may return labels and the right-hand amount as separate blocks.
  /// Rebuild rows geometrically instead of relying on block traversal order.
  static List<String> _visualLines(ReceiptOcrResult ocr) {
    if (ocr.lines.every((l) => l.bounds.isEmpty))
      return ocr.lines.map((l) => l.text).toList();
    final angles =
        ocr.lines
            .where((l) => !l.bounds.isEmpty && l.angle.abs() < .6)
            .map((l) => l.angle)
            .toList()
          ..sort();
    final slope = math.tan(angles.isEmpty ? 0 : angles[angles.length ~/ 2]);
    double rowY(ReceiptOcrLine line) =>
        line.bounds.center.dy - slope * line.bounds.center.dx;
    final sorted = [...ocr.lines]..sort((a, b) => rowY(a).compareTo(rowY(b)));
    final rows = <List<ReceiptOcrLine>>[];
    for (final line in sorted) {
      final row = rows
          .where(
            (r) =>
                (rowY(r.first) - rowY(line)).abs() <
                (r.first.bounds.height < line.bounds.height
                        ? r.first.bounds.height
                        : line.bounds.height) *
                    .55,
          )
          .lastOrNull;
      if (row == null) {
        rows.add([line]);
      } else {
        row.add(line);
      }
    }
    return rows.map((r) {
      r.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
      return r.map((l) => l.text).join(' ');
    }).toList();
  }
}
