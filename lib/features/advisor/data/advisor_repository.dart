import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/offline/offline_wallet_repository.dart';
import '../../home/models/monthly_summary.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../models/advisor_models.dart';

class AdvisorRepository {
  AdvisorRepository(this._client, [this._store]);

  final SupabaseClient _client;
  final LocalStore? _store;

  Future<String> _fingerprint() async {
    if (_store == null) return '';
    return sha256
        .convert(utf8.encode(jsonEncode(
            [await _store.rows('transactions'), await _store.rows('categories'), await _store.rows('budgets')])))
        .toString();
  }

  /// Calls the `ai-advisor` Edge Function (10 analyses per day).
  Future<AdvisorReport> analyze({required int range}) async {
    final fingerprint = await _fingerprint();
    final cached = await _store?.meta('advisor:$range');
    try {
      if (_store != null && await _store.pendingCount() > 0)
        throw StateError('Đồng bộ dữ liệu trước khi tạo nhận xét AI mới');
      final response = await _client.functions.invoke('ai-advisor', body: {'range': range});
      final data = ((response.data as Map)['data'] as Map).cast<String, dynamic>();
      await _store?.setMeta('advisor:$range', jsonEncode({'fingerprint': fingerprint, 'data': data}));
      return AdvisorReport.fromJson(data);
    } catch (_) {
      if (cached == null) rethrow;
      final cache = (jsonDecode(cached) as Map).cast<String, dynamic>();
      return AdvisorReport.fromJson({
        ...Map<String, dynamic>.from(cache['data'] as Map),
        'cached': true,
        'stale': cache['fingerprint'] != fingerprint
      });
    }
  }

  /// Totals by category and by day — plain SQL, no AI quota.
  Future<PeriodSummary> fetchPeriod({required DateTime from, required DateTime to}) async {
    if (_store != null) {
      final end = DateTime(to.year, to.month, to.day + 1);
      final tx = (await OfflineWalletRepository(_store).allTransactions())
          .where((t) => !t.occurredAt.isBefore(from) && t.occurredAt.isBefore(end));
      final categories = <String, Map<String, dynamic>>{};
      final days = <String, Map<String, dynamic>>{};
      var income = 0, expense = 0;
      for (final t in tx) {
        if (t.isIncome) {
          income += t.amount;
        } else {
          expense += t.amount;
        }
        final key = '${t.type.name}:${t.categoryId}';
        final c = categories.putIfAbsent(
            key,
            () => {
                  'name': t.categoryName ?? 'Chưa phân loại',
                  'type': t.type.name,
                  'category_id': t.categoryId,
                  'icon': t.categoryIcon,
                  'color': t.categoryColor,
                  'total': 0,
                  'count': 0
                });
        c['total'] = (c['total'] as int) + t.amount;
        c['count'] = (c['count'] as int) + 1;
        final date = t.occurredAt.toIso8601String().substring(0, 10);
        final d = days.putIfAbsent(date, () => {'day': date, 'income': 0, 'expense': 0});
        d[t.type.name] = (d[t.type.name] as int) + t.amount;
      }
      return PeriodSummary(
          income: income,
          expense: expense,
          byCategory: categories.values.map(CategoryTotal.fromJson).toList(),
          byDay: days.values.map(DailyTotal.fromJson).toList());
    }
    final data = await _client.rpc('get_period_summary', params: {'p_from': _isoDate(from), 'p_to': _isoDate(to)});
    return PeriodSummary.fromJson((data as Map).cast<String, dynamic>());
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final advisorRepositoryProvider = Provider<AdvisorRepository>(
  (ref) => AdvisorRepository(ref.watch(supabaseClientProvider), ref.watch(localStoreProvider)),
);

/// AI report per range (30 / 90 days). Not auto-disposed: reopening the
/// screen reuses the last analysis instead of spending another AI call.
final advisorReportProvider = FutureProvider.family<AdvisorReport, int>((ref, range) {
  ref.watch(currentUserIdProvider);
  return ref.watch(advisorRepositoryProvider).analyze(range: range);
});

final advisorStaleProvider = FutureProvider.autoDispose.family<bool, int>((ref, range) async {
  ref.watch(localRevisionProvider);
  final store = ref.watch(localStoreProvider);
  if (store == null) return false;
  final raw = await store.meta('advisor:$range');
  if (raw == null) return false;
  final fingerprint = await ref.watch(advisorRepositoryProvider)._fingerprint();
  return (jsonDecode(raw) as Map)['fingerprint'] != fingerprint || await store.pendingCount() > 0;
});

/// Spending of the last [range] days, ending today.
final periodSummaryProvider = FutureProvider.autoDispose.family<PeriodSummary, int>((ref, range) {
  ref.watch(localRevisionProvider);
  ref.watch(currentUserIdProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return ref.watch(advisorRepositoryProvider).fetchPeriod(
        from: today.subtract(Duration(days: range - 1)),
        to: today,
      );
});
