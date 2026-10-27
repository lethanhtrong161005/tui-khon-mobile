import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/offline/local_store.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/utils/currency_formatter.dart';
import 'monthly_report.dart';
import 'monthly_ai_report.dart';

class MonthlyReportScreen extends ConsumerStatefulWidget {
  const MonthlyReportScreen({super.key, this.initialMonth});
  final DateTime? initialMonth;
  @override
  ConsumerState<MonthlyReportScreen> createState() =>
      _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends ConsumerState<MonthlyReportScreen> {
  late DateTime _month;
  MonthlyReport? _report;
  bool _busy = false, _stale = false;
  bool _aiBusy = false, _pending = false;
  CachedMonthlyAdvice? _advice;
  String? _aiError;
  String? _error;
  int _generation = 0;
  StreamSubscription<int>? _changes;
  LocalStore? _subscribedStore;

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMonth;
    final now = DateTime.now();
    _month = initial == null
        ? DateTime(now.year, now.month - 1)
        : DateTime(initial.year, initial.month);
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final month = _month;
    setState(() {
      _busy = true;
      _error = null;
      _stale = _report != null;
    });
    try {
      final store = ref.read(localStoreProvider);
      if (store == null) throw StateError('Đăng nhập để xem báo cáo cục bộ');
      if (!identical(store, _subscribedStore)) {
        await _changes?.cancel();
        _subscribedStore = store;
        _changes = store.changes.listen((_) {
          if (mounted) {
            setState(() => _stale = true);
            _load();
          }
        });
      }
      final report = MonthlyReport.compute(
          month,
          await store.rows('transactions'),
          await store.rows('categories'),
          await store.rows('budgets'));
      final advice = await _service(store).cached(month);
      final pending = await store.pendingCount() > 0;
      if (!mounted ||
          generation != _generation ||
          !identical(store, ref.read(localStoreProvider))) {
        return;
      }
      setState(() {
        if (_report?.fingerprint != report.fingerprint) _report = report;
        _stale = false;
        _advice = advice;
        _pending = pending;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = '$e');
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  MonthlyAiReports _service(LocalStore store) =>
      MonthlyAiReports(store, (body) async {
        final response = await ref
            .read(supabaseClientProvider)
            .functions
            .invoke('ai-advisor', body: body);
        final envelope = Map<String, dynamic>.from(response.data as Map);
        if (envelope['success'] != true || envelope['data'] is! Map) {
          throw StateError(
              'Không thể tạo nhận xét AI. Hãy kiểm tra kết nối và thử lại.');
        }
        return Map<String, dynamic>.from(envelope['data'] as Map);
      });

  Future<void> _generateAdvice() async {
    final store = ref.read(localStoreProvider);
    if (store == null) return;
    final month = _month;
    setState(() {
      _aiBusy = true;
      _aiError = null;
    });
    bool current() =>
        mounted &&
        identical(store, ref.read(localStoreProvider)) &&
        ref.read(currentUserIdProvider) == store.userId;
    try {
      final advice =
          await _service(store).generate(month, isCurrentAccount: current);
      if (current() && _month == month) setState(() => _advice = advice);
    } catch (e) {
      if (current() && _month == month) setState(() => _aiError = '$e');
    } finally {
      if (mounted) {
        setState(() => _aiBusy = false);
        await _load();
      }
    }
  }

  void _move(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _report = null;
      _advice = null;
      _aiError = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(localStoreProvider, (_, __) {
      setState(() {
        _report = null;
        _advice = null;
        _aiError = null;
        _pending = true;
        _generation++;
      });
      _load();
    });
    final r = _report;
    String money(int value) => CurrencyFormatter.formatVND(value);
    return Scaffold(
        appBar: AppBar(title: const Text('Báo cáo tháng'), actions: [
          IconButton(
              onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))
        ]),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                            onPressed: () => _move(-1),
                            icon: const Icon(Icons.chevron_left)),
                        Text('${_month.month}/${_month.year}'),
                        IconButton(
                            onPressed: () => _move(1),
                            icon: const Icon(Icons.chevron_right))
                      ]),
                  const Text(
                      'Tính từ dữ liệu trên thiết bị • múi giờ Việt Nam (UTC+7) • cả tháng lịch'),
                  if (_busy) const LinearProgressIndicator(),
                  if (_stale)
                    const Text('Bản lưu có thể đã cũ. Làm mới để tính lại.'),
                  if (_error != null) Text(_error!),
                  const Divider(),
                  const Text('Nhận xét AI (tùy chọn)'),
                  const Text(
                      'AI dùng dữ liệu đã đồng bộ của đúng tháng này và tháng lịch trước. Bản nhận xét đã lưu có thể đọc ngoại tuyến.'),
                  if (_pending)
                    const Text(
                        'Có dữ liệu chưa đồng bộ hoặc lỗi/xung đột. Hãy đồng bộ trước khi tạo nhận xét AI.'),
                  if (_aiError != null) Text(_aiError!),
                  if (_advice != null && r != null) ...[
                    if (_stale || _advice!.isStale(r, pending: _pending))
                      const Text(
                          'Nhận xét đã cũ — dữ liệu đã thay đổi hoặc chưa đồng bộ.'),
                    Text('Đã lưu: ${_advice!.generatedAt.toLocal()}'),
                    SelectableText('${_advice!.data['summary']}'),
                    for (final insight in _advice!.data['insights'] as List)
                      ListTile(
                          title: Text('${insight['category']}'),
                          subtitle: SelectableText('${insight['advice']}')),
                  ],
                  if (_aiBusy) const LinearProgressIndicator(),
                  FilledButton.icon(
                    onPressed: _busy || _aiBusy || _pending || r == null
                        ? null
                        : _generateAdvice,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(_advice == null
                        ? 'Tạo nhận xét AI'
                        : 'Tạo lại nhận xét AI'),
                  ),
                  if (r != null) ...[
                    ListTile(
                        title: const Text('Thu nhập'),
                        trailing: Text(money(r.income))),
                    ListTile(
                        title: const Text('Chi tiêu'),
                        trailing: Text(money(r.expense))),
                    ListTile(
                        title: const Text('Thu − chi'),
                        trailing: Text(money(r.balance))),
                    const Divider(),
                    const Text('So với tháng trước (toàn tháng)'),
                    ListTile(
                        title: Text('Thu: ${money(r.previousIncome)}'),
                        subtitle: Text(
                            'Chênh lệch: ${money(r.income - r.previousIncome)}')),
                    ListTile(
                        title: Text('Chi: ${money(r.previousExpense)}'),
                        subtitle: Text(
                            'Chênh lệch: ${money(r.expense - r.previousExpense)}')),
                    const Divider(),
                    const Text('Chi theo danh mục'),
                    if (r.byCategory.isEmpty)
                      const Text('Chưa có chi tiêu trong tháng.'),
                    for (final c
                        in (r.byCategory.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value))))
                      ListTile(
                          title: Text(c.key), trailing: Text(money(c.value))),
                    const Divider(),
                    const Text('Ngân sách'),
                    if (r.budgets.isEmpty)
                      const Text('Chưa đặt ngân sách tháng này.'),
                    for (final b in r.budgets)
                      ListTile(
                          title: Text('${b['name']}'),
                          subtitle: Text(
                              '${money((b['spent'] as num).toInt())} / ${money((b['limit_amount'] as num).toInt())}'),
                          trailing: Text(
                              (b['spent'] as num) > (b['limit_amount'] as num)
                                  ? 'Vượt hạn mức'
                                  : 'Trong hạn mức')),
                  ],
                ])));
  }
}
