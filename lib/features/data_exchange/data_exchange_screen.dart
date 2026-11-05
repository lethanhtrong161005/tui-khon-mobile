import '../../l10n/app_l10n.dart';
import '../../core/utils/app_failure.dart';
import '../../core/utils/error_messages.dart';
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
  Object? _message;
  int? _importedCount;
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
      _importedCount = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _message = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  LocalStore get _store =>
      ref.read(localStoreProvider) ??
      (throw AppFailure('csvLocalSignIn', [], 'Local sign-in required'));

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
      throw AppFormatFailure('csvFileSize', [], 'CSV exceeds 20MB');
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
      throw AppFailure('accountChanged', [], 'Account changed');
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
      throw AppFailure('accountChanged', [], 'Account changed');
    }
    _plan = plan;
  }

  Future<void> _save() async {
    final store = _store;
    await _refreshPreview();
    await _recheck();
    if (_plan.errors.isNotEmpty)
      throw AppFailure(
          'csvMapping', [], 'Resolve CSV row errors before importing');
    if (!identical(store, ref.read(localStoreProvider))) {
      throw AppFailure('accountChanged', [], 'Account changed');
    }
    await store.writeBatch(_plan.mutations);
    if (mounted) {
      setState(() {
        _message = null;
        _importedCount = _plan.transactionCount;
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
        appBar: AppBar(title: Text(appL10n(context).csvExchange)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(appL10n(context).msgUtfCsvUpToRowsWhole471),
          Text(appL10n(context).msgRecordingMethodsManualAiVoiceReceipt472),
          SwitchListTile(
              title: Text(appL10n(context).msgExportFilteredRecords473),
              subtitle:
                  Text(appL10n(context).msgTurnOffToExportAllTransactions474),
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
                    ? appL10n(context).msgSelectDateRangeUtc475
                    : '${_dateRange!.start.toString().substring(0, 10)} → ${_dateRange!.end.toString().substring(0, 10)}')),
            if (_dateRange != null)
              TextButton(
                  onPressed:
                      _busy ? null : () => setState(() => _dateRange = null),
                  child: Text(appL10n(context).msgClearDateFilter476)),
            DropdownButtonFormField<String>(
                initialValue: _exportType,
                decoration: InputDecoration(
                    labelText: appL10n(context).msgTransactionType477),
                items: [
                  DropdownMenuItem(
                      value: null, child: Text(appL10n(context).msgAll206)),
                  DropdownMenuItem(
                      value: 'income',
                      child: Text(appL10n(context).msgIncome163)),
                  DropdownMenuItem(
                      value: 'expense',
                      child: Text(appL10n(context).msgExpenses164))
                ],
                onChanged:
                    _busy ? null : (v) => setState(() => _exportType = v)),
            DropdownButtonFormField<String>(
                initialValue: _exportSource,
                decoration: InputDecoration(
                    labelText: appL10n(context).msgRecordingMethod478),
                items: [
                  DropdownMenuItem(
                      value: null, child: Text(appL10n(context).msgAll206)),
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
                child: Text(appL10n(context).msgDownloadShareTemplate479)),
            OutlinedButton(
                onPressed: _busy ? null : () => _run(_export),
                child: Text(_filteredExport
                    ? appL10n(context).msgExportFilteredRecords473
                    : appL10n(context).msgExportAll480)),
            FilledButton(
                onPressed: _busy ? null : () => _run(_load),
                child: Text(appL10n(context).msgChooseCsv481)),
          ]),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Text(friendlyError(_message!, context: context)),
          if (_importedCount != null)
            Text(appL10n(context).msgImportedTransactions470(_importedCount!)),
          if (_preview.isNotEmpty) ...[
            Text(appL10n(context).msgRowsErrorsDuplicatesIdConflicts482(
                (_preview.length).toString(),
                (_preview.where((p) => p.error != null).length).toString(),
                (_preview.where((p) => p.duplicate).length).toString(),
                (_preview.where((p) => p.conflict).length).toString())),
            Text(appL10n(context).msgInvalidRowsAndIdsWithDifferent483),
            Text(appL10n(context).msgRowsSelectedPossibleDuplicatesToImport484(
                (_selected.length).toString(),
                (_plan.duplicates.length).toString(),
                (_plan.transactionCount).toString())),
            Text(appL10n(context).msgAPossibleDuplicateHasTheSame485),
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
                  child: Text(appL10n(context).msgSelectAllValidRows486)),
              TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            _selected.clear();
                            await _recheck();
                          }),
                  child: Text(appL10n(context).msgDeselectAll487))
            ]),
            CheckboxListTile(
                value: _skipDuplicates,
                onChanged: _busy
                    ? null
                    : (v) => _run(() async {
                          _skipDuplicates = v!;
                          await _recheck();
                        }),
                title:
                    Text(appL10n(context).msgSkipPossibleDuplicatesMinutes488)),
            for (final entry in mappings.entries)
              DropdownButtonFormField<String>(
                key: ValueKey('${entry.key}-${_mapping[entry.key]}'),
                initialValue: _resolve(entry.value.$1, entry.value.$2),
                isExpanded: true,
                decoration: InputDecoration(
                    labelText:
                        '${entry.value.$1 == 'wallets' ? appL10n(context).wallets : appL10n(context).categories}: ${entry.key.split('|').last}'),
                items: [
                  DropdownMenuItem<String>(
                      value: null,
                      child: Text(appL10n(context).msgNotMappedCreateNew489)),
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
                title: Text(appL10n(context)
                    .msgConfirmCreationOfUnmappedCategoriesMoney490)),
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
                  title: Text(appL10n(context).msgRow491(
                      (p.line).toString(),
                      (p.values['amount'] ?? '').toString(),
                      (p.values['note'] ?? '').toString())),
                  subtitle: Text((p.issue != null
                          ? csvIssueMessage(appL10n(context), p.issue!)
                          : null) ??
                      (_plan.issues[p.line] != null
                          ? csvIssueMessage(
                              appL10n(context), _plan.issues[p.line]!)
                          : null) ??
                      (p.conflict
                          ? appL10n(context)
                              .msgIdExistsWithDifferentContentsSkipped492
                          : _plan.existingIds.contains(p.line)
                              ? appL10n(context)
                                  .msgExistingIdDoNotImportAgain493
                              : _plan.duplicates.contains(p.line)
                                  ? appL10n(context)
                                      .msgPossibleDuplicateWithinMinutes494
                                  : appL10n(context).msgValid495))),
            if (_preview.length > 100)
              Row(children: [
                IconButton(
                    onPressed:
                        _page == 0 ? null : () => setState(() => _page--),
                    icon: const Icon(Icons.chevron_left)),
                Text(appL10n(context)
                    .pageOf(_page + 1, (_preview.length / 100).ceil())),
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
                child:
                    Text(appL10n(context).msgConfirmSelectedRowsForImport496)),
          ],
        ]));
  }
}

String csvIssueMessage(AppLocalizations l, CsvIssue issue) =>
    switch (issue.code) {
      CsvIssueCode.columns => l.csvColumns,
      CsvIssueCode.type => l.csvType,
      CsvIssueCode.amount => l.csvAmount,
      CsvIssueCode.date => l.csvDate,
      CsvIssueCode.wallet => l.csvWallet,
      CsvIssueCode.source => l.csvSource,
      CsvIssueCode.id => l.csvId,
      CsvIssueCode.mapping => l.csvMapping(issue.label),
    };
