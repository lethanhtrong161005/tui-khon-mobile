import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Matches private.debt_payment_transaction_id in PostgreSQL. Existing linked
/// transaction IDs are always retained, including while recording is disabled.
String debtPaymentTransactionId(String paymentId) {
  final h = md5
      .convert(utf8.encode('tuikhon:debt-payment:${paymentId.toLowerCase()}'))
      .toString();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

final Random _random = Random.secure();

/// Random RFC 4122 v4 UUID, used as `transactions.client_id` so a retried
/// insert (e.g. offline sync) never creates a duplicate row.
String newUuidV4() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
