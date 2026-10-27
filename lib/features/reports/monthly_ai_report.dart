import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../core/offline/local_store.dart';
import 'monthly_report.dart';

typedef MonthlyAiRequest = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> body);

String reportMonthKey(DateTime month) =>
    '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01';

/// Compare SQL aggregates, not server/device timestamps or JSON key ordering.
String groundingFingerprint(Map<String, dynamic> grounding) {
  List<String> sorted(Iterable<dynamic> values) =>
      values.map(jsonEncode).toList()..sort();
  Object period(dynamic value, bool current) {
    final p = Map<String, dynamic>.from(value as Map);
    return [
      p['income'],
      p['expense'],
      p['transaction_count'],
      sorted((p['by_category'] as List).map((c) => [
            c['type'],
            c['category_id'],
            c['name'] ?? 'Chưa phân loại',
            c['total'],
            c['count']
          ])),
      if (current)
        sorted((p['budgets'] as List)
            .map((b) => [b['category_id'], b['limit_amount'], b['spent']])),
    ];
  }

  return sha256
      .convert(utf8.encode(jsonEncode([
        period(grounding['current'], true),
        period(grounding['previous'], false)
      ])))
      .toString();
}

class CachedMonthlyAdvice {
  CachedMonthlyAdvice(this.fingerprint, this.generatedAt, this.data);
  final String fingerprint;
  final DateTime generatedAt;
  final Map<String, dynamic> data;

  bool isStale(MonthlyReport report, {required bool pending}) =>
      pending ||
      fingerprint != report.fingerprint ||
      groundingFingerprint(
              Map<String, dynamic>.from(data['grounding'] as Map)) !=
          groundingFingerprint(report.grounding);
  String encode() => jsonEncode({
        'fingerprint': fingerprint,
        'generated_at': generatedAt.toUtc().toIso8601String(),
        'data': data
      });
  factory CachedMonthlyAdvice.decode(String raw) {
    final value = jsonDecode(raw) as Map;
    return CachedMonthlyAdvice(
        value['fingerprint'] as String,
        DateTime.parse(value['generated_at'] as String),
        Map<String, dynamic>.from(value['data'] as Map));
  }
}

class MonthlyAiReports {
  MonthlyAiReports(this.store, this.request);
  final LocalStore store;
  final MonthlyAiRequest request;
  String _key(DateTime month) => 'monthly_advice_v1:${reportMonthKey(month)}';

  Future<MonthlyReport> snapshot(DateTime month) async => MonthlyReport.compute(
      month,
      await store.rows('transactions'),
      await store.rows('categories'),
      await store.rows('budgets'));

  Future<CachedMonthlyAdvice?> cached(DateTime month) async {
    final raw = await store.meta(_key(month));
    if (raw == null) return null;
    try {
      final cache = CachedMonthlyAdvice.decode(raw);
      groundingFingerprint(
          Map<String, dynamic>.from(cache.data['grounding'] as Map));
      return cache;
    } catch (_) {
      return null;
    }
  }

  Future<CachedMonthlyAdvice> generate(DateTime month,
      {required bool Function() isCurrentAccount}) async {
    if (!isCurrentAccount()) throw StateError('Tài khoản đã thay đổi');
    // Includes errored/conflicting outbox rows, not just queued operations.
    if (await store.pendingCount() > 0) {
      throw StateError(
          'Hãy đồng bộ và xử lý lỗi/xung đột trước khi tạo nhận xét AI. Bản lưu vẫn đọc được ngoại tuyến.');
    }
    final before = await snapshot(month);
    if (!isCurrentAccount()) throw StateError('Tài khoản đã thay đổi');
    if (await store.pendingCount() > 0) {
      throw StateError('Hãy đồng bộ dữ liệu trước khi tạo nhận xét AI.');
    }
    final data = await request({'month': reportMonthKey(month)});
    final period = data['period'] as Map?;
    if (period?['month'] != reportMonthKey(month) ||
        period?['timezone'] != 'Asia/Ho_Chi_Minh' ||
        data['summary'] is! String ||
        (data['summary'] as String).trim().isEmpty ||
        data['insights'] is! List) {
      throw StateError(
          'Máy chủ chưa hỗ trợ báo cáo đúng tháng. Vui lòng thử lại sau.');
    }
    final after = await snapshot(month);
    final pending = await store.pendingCount() > 0;
    if (!isCurrentAccount()) throw StateError('Tài khoản đã thay đổi');
    if (pending ||
        before.fingerprint != after.fingerprint ||
        groundingFingerprint(
                Map<String, dynamic>.from(data['grounding'] as Map)) !=
            groundingFingerprint(after.grounding)) {
      throw StateError(
          'Dữ liệu thiết bị và máy chủ đã khác nhau. Hãy đồng bộ rồi tạo lại; bản lưu trước được giữ nguyên.');
    }
    final result = CachedMonthlyAdvice(after.fingerprint, DateTime.now(), data);
    await store.setMeta(_key(month), result.encode());
    return result;
  }
}
