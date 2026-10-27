import 'dart:convert';
import 'dart:math';

typedef JsonRow = Map<String, dynamic>;

String exchangeId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class CsvPreviewRow {
  CsvPreviewRow(this.line, this.values,
      {this.error, this.duplicate = false, this.conflict = false});
  final int line;
  final JsonRow values;
  final String? error;
  final bool duplicate;
  final bool conflict;
}

/// Portable VND format. wallet/category contain display names; source is the
/// transaction provenance, not the funding wallet.
class CsvExchange {
  static const sources = ['manual', 'ai', 'voice', 'receipt', 'debt'];
  static const columns = [
    'id',
    'type',
    'amount',
    'occurred_at',
    'wallet',
    'category',
    'note',
    'source'
  ];
  static const maxRows = 10000;

  static String encode(List<List<String>> records) =>
      '\ufeff${records.map((r) => r.map((s) {
            // Prevent spreadsheet formula execution in user-controlled text.
            if (RegExp(r'^[=+@\-\t\r]').hasMatch(s)) s = "'$s";
            return '"${s.replaceAll('"', '""')}"';
          }).join(',')).join('\r\n')}\r\n';

  static String template() => encode([
        columns,
        [
          '',
          'expense',
          '50000',
          '2026-01-15T12:00:00+07:00',
          'Tiền mặt',
          'Ăn uống',
          'Bữa trưa',
          'manual'
        ]
      ]);

  static String export(List<JsonRow> transactions, List<JsonRow> wallets,
      List<JsonRow> categories) {
    String name(List<JsonRow> rows, dynamic id) =>
        rows
            .where((r) => r['id'] == id)
            .map((r) => '${r['name']}')
            .firstOrNull ??
        '';
    return encode([
      columns,
      for (final t in transactions)
        [
          '${t['id'] ?? ''}',
          '${t['type']}',
          '${t['amount']}',
          '${t['occurred_at']}',
          name(wallets, t['wallet_id']),
          name(categories, t['category_id']),
          '${t['note'] ?? ''}',
          sources.contains(t['source']) ? '${t['source']}' : 'manual',
        ]
    ]);
  }

  static List<List<String>> decode(List<int> bytes) {
    var text = utf8.decode(bytes);
    if (text.startsWith('\ufeff')) text = text.substring(1);
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    var closed = false;
    void finishField() {
      var value = field.toString();
      if (value.startsWith("'") &&
          value.length > 1 &&
          RegExp(r'^[=+@\-\t\r]').hasMatch(value.substring(1))) {
        value = value.substring(1);
      }
      row.add(value);
      field = StringBuffer();
      closed = false;
    }

    void finishRow() {
      finishField();
      if (row.any((v) => v.isNotEmpty)) rows.add(row);
      row = [];
      if (rows.length > maxRows + 1) {
        throw const FormatException('Tối đa 10.000 giao dịch');
      }
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          field.write(c);
        }
      } else if (c == ',') {
        finishField();
      } else if (c == '\r' || c == '\n') {
        finishRow();
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      } else if (c == '"' && field.isEmpty && !closed) {
        quoted = true;
      } else {
        if (closed || c == '"') {
          throw const FormatException('CSV sai dấu ngoặc kép');
        }
        field.write(c);
      }
    }
    if (quoted) throw const FormatException('CSV chưa đóng dấu ngoặc kép');
    if (field.isNotEmpty || row.isNotEmpty || closed) finishRow();
    return rows;
  }

  static List<CsvPreviewRow> preview(List<int> bytes, List<JsonRow> existing) {
    final records = decode(bytes);
    if (records.isEmpty || records.first.join(',') != columns.join(',')) {
      throw FormatException('Cột bắt buộc: ${columns.join(', ')}');
    }
    final seen = <String, JsonRow>{for (final r in existing) '${r['id']}': r};
    final signatures = existing.map(signature).toSet();
    return [
      for (var i = 1; i < records.length; i++)
        _validate(i + 1, records[i], seen, signatures)
    ];
  }

  static String signature(JsonRow r) => jsonEncode([
        r['type'],
        r['amount'],
        DateTime.tryParse('${r['occurred_at']}')?.toUtc().toIso8601String(),
        r['wallet_id'] ?? r['wallet'],
        r['category_id'] ?? r['category'],
        r['note'] ?? '',
        r['source'] ?? 'manual',
      ]);

  static CsvPreviewRow _validate(int line, List<String> cells,
      Map<String, JsonRow> seen, Set<String> signatures) {
    if (cells.length != columns.length) {
      return CsvPreviewRow(line, {}, error: 'Sai số cột');
    }
    final r = <String, dynamic>{
      for (var i = 0; i < columns.length; i++) columns[i]: cells[i]
    };
    final amount = int.tryParse(cells[2]);
    final date = DateTime.tryParse(cells[3]);
    String? error;
    if (!['income', 'expense'].contains(r['type'])) {
      error = 'Loại phải là income/expense';
    } else if (amount == null || amount <= 0 || amount > 9007199254740991) {
      error = 'Số tiền VND phải là số nguyên dương';
    } else if (date == null || !_validDate(cells[3])) {
      error = 'Ngày ISO 8601 phải có múi giờ';
    } else if (r['wallet'].toString().trim().isEmpty) {
      error = 'Thiếu nguồn tiền';
    } else if (!sources.contains(r['source'])) {
      error = 'Nguồn ghi nhận không hợp lệ';
    } else if (cells[0].isNotEmpty &&
        !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
            .hasMatch(cells[0])) {
      error = 'ID phải là UUID hoặc để trống';
    }
    r['amount'] = amount;
    r['occurred_at'] = date?.toUtc().toIso8601String();
    final prior = cells[0].isEmpty ? null : seen[cells[0]];
    final sig = signature(r);
    final conflict = prior != null && signature(prior) != sig;
    final duplicate = prior != null && !conflict || signatures.contains(sig);
    if (error == null) {
      if (cells[0].isNotEmpty) seen.putIfAbsent(cells[0], () => r);
      signatures.add(sig);
    }
    return CsvPreviewRow(line, r,
        error: error, duplicate: duplicate, conflict: conflict);
  }

  static bool _validDate(String value) {
    final match = RegExp(
            r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?(Z|[+-]\d{2}:\d{2})$')
        .firstMatch(value);
    if (match == null) return false;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final civil = DateTime.utc(year, month, day);
    final zone = match[8]!;
    return civil.year == year &&
        civil.month == month &&
        civil.day == day &&
        int.parse(match[4]!) < 24 &&
        int.parse(match[5]!) < 60 &&
        int.parse(match[6]!) < 60 &&
        (zone == 'Z' ||
            int.parse(zone.substring(1, 3)) < 24 &&
                int.parse(zone.substring(4)) < 60);
  }
}

/// Inclusive calendar dates in the same UTC+7 calendar as monthly reports.
class CsvExportFilter {
  const CsvExportFilter({this.from, this.to, this.type, this.source});
  final DateTime? from, to;
  final String? type, source;

  List<JsonRow> apply(List<JsonRow> rows) => rows.where((r) {
        if (type != null && r['type'] != type) return false;
        if (source != null && (r['source'] ?? 'manual') != source) return false;
        if (from == null && to == null) return true;
        final d = DateTime.tryParse('${r['occurred_at']}')
            ?.toUtc()
            .add(const Duration(hours: 7));
        if (d == null) return false;
        if (from != null &&
            d.isBefore(DateTime.utc(from!.year, from!.month, from!.day))) {
          return false;
        }
        if (to != null &&
            !d.isBefore(DateTime.utc(to!.year, to!.month, to!.day + 1))) {
          return false;
        }
        return true;
      }).toList();
}
