import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/glass.dart';
import 'report_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/offline/local_store.dart';
import '../../core/supabase/supabase_providers.dart';
import 'monthly_report.dart';
import 'monthly_ai_report.dart';

final monthlyAiRequestProvider =
    Provider<MonthlyAiRequest>((ref) => (body) async {
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
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
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
      if (mounted && generation == _generation)
        setState(() => _error = friendlyError(e));
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  MonthlyAiReports _service(LocalStore store) =>
      MonthlyAiReports(store, ref.read(monthlyAiRequestProvider));

  Future<void> _generateAdvice() async {
    if (_aiBusy || _busy || _pending || _report == null) return;
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
      if (current() && _month == month)
        setState(() => _aiError = friendlyError(e));
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
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final currentMonth = _month.year == now.year && _month.month == now.month;
    final staleAdvice = r != null &&
        _advice != null &&
        (_stale || _advice!.isStale(r, pending: _pending));
    final sortedBudgets =
        r?.budgets.where((b) => b['category_id'] != null).toList() ?? [];
    sortedBudgets.sort((a, b) =>
        ((b['spent'] as num) / (b['limit_amount'] as num))
            .compareTo((a['spent'] as num) / (a['limit_amount'] as num)));
    final previewBudgets = [
      ...?r?.budgets.where((b) => b['category_id'] == null),
      ...sortedBudgets.take(3)
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo tháng'), actions: [
        IconButton(
            tooltip: 'Tính lại báo cáo',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded))
      ]),
      body: NotebookBackground(
          child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                  children: [
                    Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 8,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                                tooltip: 'Tháng trước',
                                onPressed: () => _move(-1),
                                icon: const Icon(Icons.chevron_left)),
                            Text('${_month.month}/${_month.year}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                            IconButton(
                                tooltip: 'Tháng sau',
                                onPressed: () => _move(1),
                                icon: const Icon(Icons.chevron_right)),
                          ]),
                          if (currentMonth)
                            _Status('Tháng đang diễn ra',
                                color: AppColors.primary),
                        ]),
                    const Text('Toàn tháng • Giờ Việt Nam',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.onSurfaceVariant)),
                    if (_busy)
                      const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: LinearProgressIndicator()),
                    if (_error != null)
                      GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(children: [
                            Text(_error!),
                            TextButton(
                                onPressed: _busy ? null : _load,
                                child: const Text('Thử lại'))
                          ])),
                    if (_stale)
                      const Text('Đang cập nhật số liệu trên thiết bị…',
                          style: TextStyle(fontSize: 12)),
                    if (r != null) ...[
                      const ReportSectionTitle('Tổng quan tài chính'),
                      AdaptiveReportGrid(children: [
                        ReportMetric('Thu nhập', r.income,
                            Icons.arrow_upward_rounded, AppColors.primary),
                        ReportMetric('Chi tiêu', r.expense,
                            Icons.arrow_downward_rounded, AppColors.error),
                        ReportMetric(
                            'Chênh lệch thu − chi',
                            r.balance,
                            Icons.bar_chart_rounded,
                            r.balance < 0 ? AppColors.error : AppColors.primary,
                            signed: true),
                      ]),
                      const ReportSectionTitle('So với tháng trước'),
                      Text(
                          'So sánh toàn tháng ${_month.month == 1 ? 12 : _month.month - 1}/${_month.month == 1 ? _month.year - 1 : _month.year}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 10),
                      AdaptiveReportGrid(columns: 2, children: [
                        ReportComparison(
                            income: true,
                            current: r.income,
                            previous: r.previousIncome),
                        ReportComparison(
                            income: false,
                            current: r.expense,
                            previous: r.previousExpense),
                      ]),
                      ReportSectionTitle('Cơ cấu chi tiêu',
                          action: TextButton(
                              onPressed: () => _showDetails(r, budgets: false),
                              child: const Text('Xem chi tiết'))),
                      ReportCategories(report: r),
                      ReportSectionTitle('Ngân sách tháng',
                          action: TextButton(
                              onPressed: () => _showDetails(r, budgets: true),
                              child: const Text('Xem tất cả'))),
                      if (r.budgets.isEmpty)
                        const GlassCard(
                            padding: EdgeInsets.all(20),
                            child: Text('Chưa đặt ngân sách tháng này.')),
                      for (final b in previewBudgets) ReportBudget(budget: b),
                      const SizedBox(height: 14),
                      GlassCard(
                          padding: const EdgeInsets.all(16),
                          radius: 22,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TintedIcon(
                                                Icons.auto_awesome_outlined,
                                                size: 30),
                                            SizedBox(width: 8),
                                            Text('Góc nhìn từ AI',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800))
                                          ]),
                                      _Status(
                                          _aiBusy
                                              ? 'Đang tạo…'
                                              : _aiError != null
                                                  ? 'Thử lại'
                                                  : staleAdvice
                                                      ? 'Cần cập nhật'
                                                      : _advice != null
                                                          ? 'Đã lưu'
                                                          : 'Chưa tạo',
                                          color: _aiError != null
                                              ? AppColors.error
                                              : staleAdvice
                                                  ? Colors.orange.shade800
                                                  : AppColors.primary),
                                    ]),
                                const SizedBox(height: 10),
                                const Text('Nhận xét AI (tùy chọn)',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                const Text(
                                    'Phân tích tháng đang xem và toàn tháng trước. Bản đã lưu đọc được ngoại tuyến.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.onSurfaceVariant)),
                                if (_pending)
                                  const Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: Text(
                                          'Có dữ liệu chưa đồng bộ hoặc lỗi/xung đột. Hãy đồng bộ trước khi tạo nhận xét AI.',
                                          style: TextStyle(fontSize: 12))),
                                if (_aiError != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(_aiError!,
                                          style: const TextStyle(
                                              color: AppColors.error,
                                              fontSize: 12))),
                                if (_advice != null) ...[
                                  if (staleAdvice)
                                    const Padding(
                                        padding: EdgeInsets.only(top: 10),
                                        child: Text(
                                            'Nhận xét đã cũ — dữ liệu đã thay đổi hoặc chưa đồng bộ.',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.tertiary))),
                                  const SizedBox(height: 12),
                                  SelectableText('${_advice!.data['summary']}'),
                                  for (final insight
                                      in _advice!.data['insights'] as List)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('${insight['category']}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              SelectableText(
                                                  '${insight['advice']}')
                                            ])),
                                  const SizedBox(height: 10),
                                  Text(
                                      'Đã lưu: ${DateFormat('dd/MM/yyyy · HH:mm').format(_advice!.generatedAt.toUtc().add(const Duration(hours: 7)))}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.onSurfaceVariant)),
                                ],
                                const SizedBox(height: 12),
                                if (_aiBusy) const LinearProgressIndicator(),
                                FilledButton.icon(
                                    onPressed: _busy || _aiBusy || _pending
                                        ? null
                                        : _generateAdvice,
                                    icon: const Icon(Icons.auto_awesome),
                                    label: Text(_aiBusy
                                        ? 'Đang tạo nhận xét…'
                                        : _advice == null
                                            ? 'Tạo nhận xét AI'
                                            : 'Tạo lại nhận xét AI')),
                              ])),
                    ],
                  ]))),
    );
  }

  void _showDetails(MonthlyReport report, {required bool budgets}) {
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => Scaffold(
                  appBar: AppBar(
                      title: Text(
                          '${budgets ? 'Ngân sách' : 'Chi theo danh mục'} · ${report.month.month}/${report.month.year}')),
                  body: NotebookBackground(
                      child: ListView(
                          padding: const EdgeInsets.all(18),
                          children: budgets
                              ? [
                                  if (report.budgets.isEmpty)
                                    const Text('Chưa đặt ngân sách tháng này.'),
                                  for (final b in report.budgets)
                                    ReportBudget(budget: b)
                                ]
                              : [ReportCategories(report: report, all: true)])),
                )));
  }
}

class _Status extends StatelessWidget {
  const _Status(this.text, {required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(16)),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)));
}
