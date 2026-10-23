import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../models/advisor_models.dart';

class AdvisorRepository {
  AdvisorRepository(this._client);

  final SupabaseClient _client;

  /// Calls the `ai-advisor` Edge Function (10 analyses per day).
  Future<AdvisorReport> analyze({required int range}) async {
    final response = await _client.functions.invoke('ai-advisor', body: {'range': range});
    final data = ((response.data as Map)['data'] as Map).cast<String, dynamic>();
    return AdvisorReport.fromJson(data);
  }

  /// Totals by category and by day — plain SQL, no AI quota.
  Future<PeriodSummary> fetchPeriod({required DateTime from, required DateTime to}) async {
    final data = await _client.rpc('get_period_summary', params: {'p_from': _isoDate(from), 'p_to': _isoDate(to)});
    return PeriodSummary.fromJson((data as Map).cast<String, dynamic>());
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final advisorRepositoryProvider = Provider<AdvisorRepository>(
  (ref) => AdvisorRepository(ref.watch(supabaseClientProvider)),
);

/// AI report per range (30 / 90 days). Not auto-disposed: reopening the
/// screen reuses the last analysis instead of spending another AI call.
final advisorReportProvider = FutureProvider.family<AdvisorReport, int>((ref, range) {
  ref.watch(currentUserIdProvider);
  return ref.watch(advisorRepositoryProvider).analyze(range: range);
});

/// Spending of the last [range] days, ending today.
final periodSummaryProvider = FutureProvider.autoDispose.family<PeriodSummary, int>((ref, range) {
  ref.watch(currentUserIdProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return ref.watch(advisorRepositoryProvider).fetchPeriod(
        from: today.subtract(Duration(days: range - 1)),
        to: today,
      );
});
