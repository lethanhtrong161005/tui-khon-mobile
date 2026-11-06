import 'dart:convert';
import 'package:crypto/crypto.dart';

enum PayableFrequency { once, weekly, monthly }

String payableDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class Payable {
  const Payable(
      {required this.id,
      required this.title,
      required this.amount,
      required this.start,
      this.frequency = PayableFrequency.once,
      this.active = true,
      this.note});
  final String id, title;
  final String? note;
  final int amount;
  final DateTime start;
  final PayableFrequency frequency;
  final bool active;
  factory Payable.fromJson(Map<String, dynamic> row) => Payable(
      id: row['id'] as String,
      title: row['name'] as String,
      amount: (row['amount'] as num).toInt(),
      start: DateTime.parse(row['due_date'] as String),
      frequency: row['recurrence'] == 'none'
          ? PayableFrequency.once
          : PayableFrequency.values.byName(row['recurrence'] as String),
      active: row['enabled'] != false,
      note: row['note'] as String?);
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': title.trim(),
        'amount': amount,
        'due_date': payableDateKey(start),
        'recurrence':
            frequency == PayableFrequency.once ? 'none' : frequency.name,
        'note': note == null || note!.trim().isEmpty ? null : note!.trim(),
        'enabled': active
      };
  DateTime occurrence(int index) {
    if (index < 0 || (frequency == PayableFrequency.once && index != 0))
      throw RangeError.index(index, [start]);
    if (frequency == PayableFrequency.once)
      return DateTime(start.year, start.month, start.day);
    if (frequency == PayableFrequency.weekly)
      return DateTime(start.year, start.month, start.day + 7 * index);
    final month = DateTime(start.year, start.month + index);
    final last = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(
        month.year, month.month, start.day > last ? last : start.day);
  }

  String occurrenceId(DateTime date) {
    return stablePayableUuid('$id:${payableDateKey(date)}');
  }

  Iterable<DateTime> through(DateTime end) sync* {
    for (var i = 0;; i++) {
      if (frequency == PayableFrequency.once && i > 0) break;
      final date = occurrence(i);
      if (date.isAfter(end)) break;
      yield date;
    }
  }
}

String stablePayableUuid(String key) {
  final bytes = sha256.convert(utf8.encode(key)).bytes.take(16).toList();
  bytes[6] = (bytes[6] & 15) | 80;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
