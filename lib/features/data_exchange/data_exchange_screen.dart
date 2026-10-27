import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/offline/local_store.dart';
import 'csv_exchange.dart';
import 'csv_import_plan.dart';

class DataExchangeScreen extends ConsumerStatefulWidget {
  const DataExchangeScreen({super.key});
  @override
  ConsumerState<DataExchangeScreen> createState() => _DataExchangeScreenState();
}

class _DataExchangeScreenState extends ConsumerState<DataExchangeScreen> {
  List<CsvPreviewRow> _preview = [];
  List<JsonRow> _wallets = [], _categories = [];
  final Map<String, String> _mapping = {};
  bool _busy = false, _skipDuplicates = true, _create = false;
  String? _message;
  List<int>? _bytes;
  final Set<int> _selected = {};
  CsvImportPlan _plan = CsvImportPlan();
  int _page = 0;
  bool _filteredExport = false;
  DateTimeRange? _dateRange;
  String? _exportType, _exportSource;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  LocalStore get _store =>
      ref.read(localStoreProvider) ??
      (throw StateError('Đăng nhập để dùng dữ liệu cục bộ'));

  Future<void> _share(String name, String csv) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${exchangeId()}-$name.csv');
    await file.writeAsBytes(utf8.encode(csv));
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size));
  }

  Future<void> _load() async {
    final picked = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv']);
    if (picked.isEmpty) return;
    final selectedFile = File(picked.single.path!);
    if (await selectedFile.length() > 20 * 1024 * 1024) {
      throw const FormatException('Tệp tối đa 20 MB');
    }
    _bytes = await selectedFile.readAsBytes();
    _mapping.clear();
    _create = false;
    await _refreshPreview();
    _selected.clear();
    _selected.addAll(_preview
        .where((p) => p.error == null && !p.conflict)
        .map((p) => p.line));
    _page = 0;
    await _recheck();
  }

  Future<void> _refreshPreview() async {
    final store = _store;
    final bytes = _bytes!;
    final wallets = await store.rows('wallets');
    final categories = await store.rows('categories');
    final existing = await store.rows('transactions');
    if (!mounted || !identical(store, ref.read(localStoreProvider))) {
      throw StateError('Tài khoản đã thay đổi');
    }
    _wallets = wallets;
    _categories = categories;
    String name(List<JsonRow> rows, dynamic id) =>
        rows
            .where((r) => r['id'] == id)
            .map((r) => '${r['name']}')
            .firstOrNull ??
        '';
    final prior = [
      for (final r in existing)
        {
          ...r,
          'wallet': name(_wallets, r['wallet_id']),
          'category': name(_categories, r['category_id']),
        }
          ..remove('wallet_id')
          ..remove('category_id')
    ];
    _preview = CsvExchange.preview(bytes, prior);
  }

  String _key(String entity, JsonRow row) => csvMappingKey(entity, row);
  List<JsonRow> _options(String entity, JsonRow row) =>
      (entity == 'wallets' ? _wallets : _categories)
          .where((r) =>
              r['is_archived'] != true &&
              (entity != 'categories' || r['type'] == row['type']))
          .toList();
  String? _resolve(String entity, JsonRow row) {
    final selected = _mapping[_key(entity, row)];
    final options = _options(entity, row);
    if (selected != null && options.any((o) => o['id'] == selected)) {
      return selected;
    }
    final name = '${row[entity == 'wallets' ? 'wallet' : 'category']}'
        .trim()
        .toLowerCase();
    final matches = options
        .where((o) => '${o['name']}'.trim().toLowerCase() == name)
        .toList();
    return matches.length == 1 ? '${matches.single['id']}' : null;
  }

  Future<void> _recheck() async {
    final store = _store;
    final plan = await CsvImportPlanner(store).build(
        _preview, Set.of(_selected),
        resolve: _resolve,
        allowCreation: _create,
        skipDuplicates: _skipDuplicates);
    if (!mounted || !identical(store, ref.read(localStoreProvider))) {
      throw StateError('Tài khoản đã thay đổi');
    }
    _plan = plan;
  }

  Future<void> _save() async {
    final store = _store;
    await _refreshPreview();
    await _recheck();
    if (_plan.errors.isNotEmpty) throw StateError(_plan.errors.values.first);
    if (!identical(store, ref.read(localStoreProvider))) {
      throw StateError('Tài khoản đã thay đổi');
    }
    await store.writeBatch(_plan.mutations);
    if (mounted) {
      setState(() {
        _message = 'Đã nhập ${_plan.transactionCount} giao dịch';
        _preview = [];
        _bytes = null;
        _selected.clear();
        _plan = CsvImportPlan();
      });
    }
  }

  Future<void> _export() async {
    final store = _store;
    var rows = await store.rows('transactions');
    if (_filteredExport) {
      rows = CsvExportFilter(
              from: _dateRange?.start,
              to: _dateRange?.end,
              type: _exportType,
              source: _exportSource)
          .apply(rows);
    }
    await _share(
        'giao-dich',
        CsvExchange.export(
            rows, await store.rows('wallets'), await store.rows('categories')));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(localStoreProvider, (_, __) {
      if (mounted) {
        setState(() {
          _preview = [];
          _bytes = null;
          _mapping.clear();
          _selected.clear();
          _plan = CsvImportPlan();
        });
      }
    });
    final mappings = <String, (String, JsonRow)>{};
    for (final p in _preview.where(
        (p) => _selected.contains(p.line) && p.error == null && !p.conflict)) {
      for (final entity in ['wallets', 'categories']) {
        if (entity == 'categories' && p.values['category'] == '') continue;
        mappings[_key(entity, p.values)] = (entity, p.values);
      }
    }
    return Scaffold(
        appBar: AppBar(title: const Text('Nhập / xuất CSV')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              'CSV UTF-8, tối đa 10.000 dòng. Số tiền nguyên VND; ngày ISO 8601 có múi giờ. Nguồn tiền = wallet; source = cách ghi nhận.'),
          const Text(
              'Nguồn ghi nhận: manual, ai, voice, receipt, debt. Giao dịch debt nhập vào là giao dịch độc lập, không liên kết thanh toán nợ.'),
          SwitchListTile(
              title: const Text('Xuất theo bộ lọc'),
              subtitle: const Text('Tắt để xuất tất cả giao dịch'),
              value: _filteredExport,
              onChanged:
                  _busy ? null : (v) => setState(() => _filteredExport = v)),
          if (_filteredExport) ...[
            TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2100),
                            initialDateRange: _dateRange);
                        if (range != null && mounted) {
                          setState(() => _dateRange = range);
                        }
                      },
                child: Text(_dateRange == null
                    ? 'Chọn khoảng ngày (UTC+7)'
                    : '${_dateRange!.start.toString().substring(0, 10)} → ${_dateRange!.end.toString().substring(0, 10)}')),
            if (_dateRange != null)
              TextButton(
                  onPressed:
                      _busy ? null : () => setState(() => _dateRange = null),
                  child: const Text('Bỏ lọc ngày')),
            DropdownButtonFormField<String>(
                initialValue: _exportType,
                decoration: const InputDecoration(labelText: 'Loại giao dịch'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tất cả')),
                  DropdownMenuItem(value: 'income', child: Text('Thu nhập')),
                  DropdownMenuItem(value: 'expense', child: Text('Chi tiêu'))
                ],
                onChanged:
                    _busy ? null : (v) => setState(() => _exportType = v)),
            DropdownButtonFormField<String>(
                initialValue: _exportSource,
                decoration: const InputDecoration(labelText: 'Nguồn ghi nhận'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tất cả')),
                  for (final source in CsvExchange.sources)
                    DropdownMenuItem(value: source, child: Text(source))
                ],
                onChanged:
                    _busy ? null : (v) => setState(() => _exportSource = v)),
          ],
          Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => _share('mau-giao-dich', CsvExchange.template())),
                child: const Text('Tải / chia sẻ mẫu')),
            OutlinedButton(
                onPressed: _busy ? null : () => _run(_export),
                child:
                    Text(_filteredExport ? 'Xuất theo bộ lọc' : 'Xuất tất cả')),
            FilledButton(
                onPressed: _busy ? null : () => _run(_load),
                child: const Text('Chọn CSV')),
          ]),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null) Text(_message!),
          if (_preview.isNotEmpty) ...[
            Text(
                '${_preview.length} dòng • ${_preview.where((p) => p.error != null).length} lỗi • ${_preview.where((p) => p.duplicate).length} trùng • ${_preview.where((p) => p.conflict).length} xung đột ID'),
            const Text(
                'Dòng lỗi và ID khác nội dung luôn bị bỏ qua. ID hiện có không được cập nhật.'),
            Text(
                'Đã chọn ${_selected.length} dòng • có thể trùng: ${_plan.duplicates.length} • sẽ nhập: ${_plan.transactionCount}'),
            const Text(
                'Có thể trùng = cùng loại, số tiền, nguồn tiền đã ánh xạ trong vòng 10 phút, đối chiếu dữ liệu hiện có và các dòng đã chọn.'),
            Wrap(children: [
              TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            _selected.addAll(_preview
                                .where((p) => p.error == null && !p.conflict)
                                .map((p) => p.line));
                            await _recheck();
                          }),
                  child: const Text('Chọn tất cả hợp lệ')),
              TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            _selected.clear();
                            await _recheck();
                          }),
                  child: const Text('Bỏ chọn tất cả'))
            ]),
            CheckboxListTile(
                value: _skipDuplicates,
                onChanged: _busy
                    ? null
                    : (v) => _run(() async {
                          _skipDuplicates = v!;
                          await _recheck();
                        }),
                title: const Text('Bỏ qua giao dịch có thể trùng (10 phút)')),
            for (final entry in mappings.entries)
              DropdownButtonFormField<String>(
                key: ValueKey('${entry.key}-${_mapping[entry.key]}'),
                initialValue: _resolve(entry.value.$1, entry.value.$2),
                isExpanded: true,
                decoration: InputDecoration(
                    labelText:
                        '${entry.value.$1 == 'wallets' ? 'Nguồn tiền' : 'Danh mục'}: ${entry.key.split('|').last}'),
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('Chưa chọn / tạo mới')),
                  for (final o in _options(entry.value.$1, entry.value.$2))
                    DropdownMenuItem(
                        value: '${o['id']}', child: Text('${o['name']}'))
                ],
                onChanged: _busy
                    ? null
                    : (v) => _run(() async {
                          if (v == null) {
                            _mapping.remove(entry.key);
                          } else {
                            _mapping[entry.key] = v;
                          }
                          await _recheck();
                        }),
              ),
            CheckboxListTile(
                value: _create,
                onChanged: _busy
                    ? null
                    : (v) => _run(() async {
                          _create = v!;
                          await _recheck();
                        }),
                title: const Text(
                    'Xác nhận tạo danh mục / nguồn tiền chưa ánh xạ (số dư ban đầu 0)')),
            for (final p in _preview.skip(_page * 100).take(100))
              CheckboxListTile(
                  value: _selected.contains(p.line),
                  onChanged: _busy || p.error != null || p.conflict
                      ? null
                      : (v) => _run(() async {
                            if (v == true) {
                              _selected.add(p.line);
                            } else {
                              _selected.remove(p.line);
                            }
                            await _recheck();
                          }),
                  title: Text(
                      'Dòng ${p.line}: ${p.values['amount'] ?? ''} ${p.values['note'] ?? ''}'),
                  subtitle: Text(p.error ??
                      _plan.errors[p.line] ??
                      (p.conflict
                          ? 'ID đã tồn tại với nội dung khác — bỏ qua'
                          : _plan.existingIds.contains(p.line)
                              ? 'ID hiện có — không nhập lại'
                              : _plan.duplicates.contains(p.line)
                                  ? 'Có thể trùng trong vòng 10 phút'
                                  : 'Hợp lệ'))),
            if (_preview.length > 100)
              Row(children: [
                IconButton(
                    onPressed:
                        _page == 0 ? null : () => setState(() => _page--),
                    icon: const Icon(Icons.chevron_left)),
                Text('Trang ${_page + 1}/${(_preview.length / 100).ceil()}'),
                IconButton(
                    onPressed: (_page + 1) * 100 >= _preview.length
                        ? null
                        : () => setState(() => _page++),
                    icon: const Icon(Icons.chevron_right))
              ]),
            FilledButton(
                onPressed: _busy || _selected.isEmpty || _plan.errors.isNotEmpty
                    ? null
                    : () => _run(_save),
                child: const Text('Xác nhận nhập các dòng đã chọn')),
          ],
        ]));
  }
}
