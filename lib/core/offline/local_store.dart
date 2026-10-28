import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../supabase/supabase_providers.dart';
import '../utils/id_generator.dart';

/// Generic, versioned records keep the sync wire format independent of UI models.
/// Every write and its durable outbox entry commit in one SQLite transaction.
class LocalMutation {
  const LocalMutation(this.entity, this.row, {this.deleted = false});
  final String entity;
  final Map<String, dynamic> row;
  final bool deleted;
}

class _Database extends GeneratedDatabase {
  _Database(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (_) async {
        await customStatement(
            'CREATE TABLE records (entity TEXT NOT NULL, id TEXT NOT NULL, data TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(entity,id))');
        await customStatement(
            'CREATE TABLE outbox (op_id TEXT PRIMARY KEY, entity TEXT NOT NULL, record_id TEXT NOT NULL, base_version INTEGER NOT NULL, payload TEXT NOT NULL, deleted INTEGER NOT NULL, state TEXT NOT NULL DEFAULT \'pending\', error TEXT, created_at TEXT NOT NULL)');
        await customStatement('CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await customStatement(
            'CREATE TABLE conflicts (entity TEXT NOT NULL, record_id TEXT NOT NULL, local_data TEXT NOT NULL, server_data TEXT, server_version INTEGER NOT NULL, local_deleted INTEGER NOT NULL, server_deleted INTEGER NOT NULL, PRIMARY KEY(entity,record_id))');
        await customStatement(
            'CREATE TABLE attachments (path TEXT PRIMARY KEY, bytes BLOB NOT NULL, mime TEXT NOT NULL, uploaded INTEGER NOT NULL DEFAULT 0, error TEXT)');
      });
}

class LocalStore {
  LocalStore._(this.userId, QueryExecutor executor) : _db = _Database(executor);
  factory LocalStore.memory(String userId) => LocalStore._(userId, NativeDatabase.memory());
  factory LocalStore.file(String userId, File file) => LocalStore._(userId, NativeDatabase(file));
  factory LocalStore.forUser(String userId) => LocalStore._(userId, LazyDatabase(() async {
        final root = await getApplicationSupportDirectory();
        final dir = Directory('${root.path}/accounts');
        await dir.create(recursive: true);
        // Auth UUID is never an arbitrary path supplied by a CSV or model.
        final safeId = userId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
        return NativeDatabase.createInBackground(File('${dir.path}/$safeId.sqlite'));
      }));

  final String userId;
  final _Database _db;
  final _changes = StreamController<int>.broadcast();
  int _revision = 0;
  Stream<int> get changes => _changes.stream;
  int get revision => _revision;
  bool _closed = false;
  void notify() {
    if (!_closed) _changes.add(++_revision);
  }

  Future<List<Map<String, dynamic>>> rows(String entity) async {
    final result = await _db.customSelect('SELECT data FROM records WHERE entity = ? AND deleted = 0 ORDER BY id',
        variables: [Variable(entity)]).get();
    return result.map((r) => (jsonDecode(r.read<String>('data')) as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>?> record(String entity, String id) async {
    final r = await _db.customSelect('SELECT data FROM records WHERE entity = ? AND id = ? AND deleted = 0',
        variables: [Variable(entity), Variable(id)]).getSingleOrNull();
    return r == null ? null : (jsonDecode(r.read<String>('data')) as Map).cast<String, dynamic>();
  }

  Future<void> put(String entity, Map<String, dynamic> row) => writeBatch([LocalMutation(entity, row)]);
  Future<void> remove(String entity, String id) => writeBatch([
        LocalMutation(entity, {'id': id}, deleted: true)
      ]);

  Future<void> writeBatch(List<LocalMutation> mutations) async {
    await _db.transaction(() async {
      for (final mutation in mutations) {
        await _write(mutation);
      }
      await _derivePayments();
      await _deriveOccurrences();
      await _deriveGoals();
    });
    notify();
  }

  Future<void> _write(LocalMutation m) async {
    final id = (m.row['id'] as String?) ?? newUuidV4();
    final existing = await _db.customSelect('SELECT * FROM records WHERE entity = ? AND id = ?',
        variables: [Variable(m.entity), Variable(id)]).getSingleOrNull();
    final previous = existing == null
        ? <String, dynamic>{}
        : (jsonDecode(existing.read<String>('data')) as Map).cast<String, dynamic>();
    final now = DateTime.now().toUtc().toIso8601String();
    final data = <String, dynamic>{
      ...previous,
      ...m.row,
      'id': id,
      'user_id': userId,
      'created_at': previous['created_at'] ?? now,
      'updated_at': now
    };
    if (m.entity == 'transactions' && !m.deleted) {
      if ((data['amount'] as num? ?? 0) <= 0 || data['wallet_id'] == null)
        throw StateError('Giao dịch thiếu số tiền hoặc nguồn tiền');
      data['occurred_at'] ??= now;
      data['source'] ??= 'manual';
      data['client_id'] ??= id;
    }
    if (m.entity == 'debt_payments' && !m.deleted) {
      if ((data['amount'] as num? ?? 0) <= 0)
        throw StateError('Số tiền trả phải lớn hơn 0');
      data['is_legacy'] ??= false;
      if (data['record_transaction'] == true)
        data['transaction_id'] ??= debtPaymentTransactionId(id);
      final firstLink = previous['transaction_id'] == null &&
          data['transaction_id'] == debtPaymentTransactionId(id) &&
          data['record_transaction'] == true;
      if (previous.isNotEmpty &&
          (data['debt_id'] != previous['debt_id'] ||
              (data['transaction_id'] != previous['transaction_id'] &&
                  !firstLink) ||
              data['is_legacy'] != previous['is_legacy']))
        throw StateError('Không thể đổi liên kết của lần trả nợ');
      if (data['is_legacy'] == true &&
          (data['record_transaction'] == true ||
              data['transaction_id'] != null)) {
        throw StateError('Số tiền trước nâng cấp không được tạo thu/chi');
      }
      if (firstLink &&
          await record('transactions', data['transaction_id'] as String) !=
              null) {
        throw StateError('Giao dịch liên kết đã tồn tại');
      }
      data['paid_at'] ??= now;
      data['record_transaction'] ??= false;
      data['is_legacy'] ??= false;
    }
    if (m.entity == 'debts' && !m.deleted) {
      if ((data['amount'] as num? ?? 0) <= 0) throw StateError('Số tiền nợ phải lớn hơn 0');
      if (previous.isNotEmpty &&
          data['type'] != previous['type'] &&
          (await rows('debt_payments')).any((p) => p['debt_id'] == id))
        throw StateError('Khoản nợ đã có lịch sử trả; không thể đổi chiều vay/cho vay');
    }
    if (m.entity == 'goals' &&
        !m.deleted &&
        ((data['target_amount'] as num? ?? 0) <= 0 || (data['saved_amount'] as num? ?? 0) < 0))
      throw StateError('Số tiền mục tiêu không hợp lệ');
    if (m.entity == 'budgets' && !m.deleted && (data['limit_amount'] as num? ?? 0) <= 0)
      throw StateError('Hạn mức phải lớn hơn 0');
    final version = existing?.read<int>('version') ?? 0;
    await _db.customStatement(
        'INSERT INTO records(entity,id,data,version,deleted) VALUES(?,?,?,?,?) ON CONFLICT(entity,id) DO UPDATE SET data=excluded.data, deleted=excluded.deleted',
        [m.entity, id, jsonEncode(data), version, m.deleted ? 1 : 0]);
    // Do not rewrite an operation that may already be in flight. Each edit gets
    // an immutable operation id; the sync worker rebases following edits on ACK.
    await _db.customStatement("DELETE FROM outbox WHERE entity=? AND record_id=? AND state='error'", [m.entity, id]);
    final conflictRow = await _db.customSelect('SELECT 1 FROM conflicts WHERE entity=? AND record_id=?',
        variables: [Variable(m.entity), Variable(id)]).getSingleOrNull();
    if (conflictRow != null) {
      await _db.customStatement('UPDATE conflicts SET local_data=?,local_deleted=? WHERE entity=? AND record_id=?',
          [jsonEncode(data), m.deleted ? 1 : 0, m.entity, id]);
    } else {
      await _db.customStatement(
          'INSERT INTO outbox(op_id,entity,record_id,base_version,payload,deleted,created_at) VALUES(?,?,?,?,?,?,?)',
          [newUuidV4(), m.entity, id, version, jsonEncode(data), m.deleted ? 1 : 0, now]);
    }
    if (m.entity == 'categories' && m.deleted) {
      for (final tx in await rows('transactions')) {
        if (tx['category_id'] == id) await _derived('transactions', {...tx, 'category_id': null});
      }
      for (final b in await rows('budgets')) {
        if (b['category_id'] == id) await _derived('budgets', b, deleted: true);
      }
      for (final rule in await rows('category_rules')) {
        if (rule['category_id'] == id) await _derived('category_rules', rule, deleted: true);
      }
      for (final p in await rows('payable_occurrences')) {
        if (p['category_id'] == id) await _derived('payable_occurrences', {...p, 'category_id': null});
      }
    }
    if (m.entity == 'debts' && m.deleted) {
      for (final p in await rows('debt_payments')) {
        if (p['debt_id'] == id) await _derived('debt_payments', p, deleted: true);
      }
    }
    if (m.entity == 'payables' && m.deleted) {
      for (final p in await rows('payable_occurrences')) {
        if (p['payable_id'] == id) await _derived('payable_occurrences', p, deleted: true);
      }
    }
  }

  Future<void> _derived(String entity, Map<String, dynamic> row, {bool deleted = false}) async {
    await _db.customStatement(
        'INSERT INTO records(entity,id,data,version,deleted) VALUES(?,?,?,0,?) ON CONFLICT(entity,id) DO UPDATE SET data=excluded.data, deleted=excluded.deleted',
        [entity, row['id'], jsonEncode(row), deleted ? 1 : 0]);
  }

  Future<void> _derivePayments({bool strict = true}) async {
    final payments = await rows('debt_payments');
    final debts = await rows('debts');
    final categories = await rows('categories');
    for (final debt in debts) {
      final list = payments.where((p) => p['debt_id'] == debt['id']);
      final paid = list.fold<int>(0, (n, p) => n + (p['amount'] as num).toInt());
      if (list.isEmpty && (debt['paid_amount'] as num? ?? 0) > 0 && await meta('bootstrapped') != 'true') continue;
      if (paid > (debt['amount'] as num).toInt()) {
        if (strict) throw StateError('Số tiền trả vượt khoản nợ còn lại');
        continue; // Keep server aggregate while the rejected local payment awaits correction.
      }
      await _derived(
          'debts', {...debt, 'paid_amount': paid, 'status': paid >= (debt['amount'] as num) ? 'settled' : 'active'});
    }
    final paymentRecords =
        await _db.customSelect("SELECT data,deleted FROM records WHERE entity='debt_payments'").get();
    for (final r in paymentRecords) {
      final p = (jsonDecode(r.read<String>('data')) as Map).cast<String, dynamic>();
      final txId = p['transaction_id'];
      if (txId == null) continue;
      final debt = debts.where((d) => d['id'] == p['debt_id']).firstOrNull;
      final oldTx = await record('transactions', txId as String);
      if (r.read<int>('deleted') == 1 || p['record_transaction'] != true || debt == null) {
        if (oldTx != null) await _derived('transactions', oldTx, deleted: true);
        continue;
      }
      final borrow = debt['type'] == 'borrow';
      final matchingCategories = categories.where((c) =>
          c['type'] == (borrow ? 'expense' : 'income') &&
          c['name'] == (borrow ? 'Cho vay & Trả nợ' : 'Thu nợ')).toList()
        ..sort((a, b) {
          final order = '${a['created_at'] ?? ''}'.compareTo('${b['created_at'] ?? ''}');
          return order == 0 ? '${a['id']}'.compareTo('${b['id']}') : order;
        });
      final category = matchingCategories.firstOrNull;
      await _derived('transactions', {
        ...?oldTx,
        'id': txId,
        'user_id': userId,
        'wallet_id': p['wallet_id'],
        'category_id': category?['id'],
        'type': borrow ? 'expense' : 'income',
        'amount': p['amount'],
        'occurred_at': p['paid_at'],
        'note': (p['note'] as String?)?.trim().isNotEmpty == true
            ? (p['note'] as String).trim()
            : '${borrow ? 'Trả nợ' : 'Thu nợ từ'} ${debt['person_name']}',
        'source': 'debt',
        'client_id': txId,
        'debt_payment_id': p['id'],
      });
    }
  }

  Future<void> _deriveGoals() async {
    for (final goal in await rows('goals')) {
      if (goal['status'] == 'cancelled') continue;
      await _derived('goals', {
        ...goal,
        'saved_amount': goal['saved_amount'] ?? 0,
        'status': (goal['saved_amount'] as num? ?? 0) >= (goal['target_amount'] as num) ? 'completed' : 'active'
      });
    }
  }

  /// A pulled derived transaction must not overwrite the preview of a dirty
  /// payment. Run after a complete journal page sequence, not mid-bootstrap.
  Future<void> reconcileDerived() async {
    await _db.transaction(() async {
      await _derivePayments(strict: false);
      await _deriveOccurrences();
      await _deriveGoals();
    });
    notify();
  }

  Future<void> _deriveOccurrences() async {
    final entries = await _db.customSelect("SELECT data,deleted FROM records WHERE entity='payable_occurrences'").get();
    for (final entry in entries) {
      final p = (jsonDecode(entry.read<String>('data')) as Map).cast<String, dynamic>();
      final id = p['transaction_id'] as String?;
      if (id == null) continue;
      final old = await record('transactions', id);
      if (entry.read<int>('deleted') == 1 || p['status'] != 'paid' || p['record_transaction'] == false) {
        if (old != null) await _derived('transactions', old, deleted: true);
        continue;
      }
      if (p['wallet_id'] == null || (p['amount'] as num? ?? 0) <= 0)
        throw StateError('Khoản chi phải có số tiền và nguồn tiền');
      await _derived('transactions', {
        ...?old,
        'id': id,
        'user_id': userId,
        'wallet_id': p['wallet_id'],
        'category_id': p['category_id'],
        'type': 'expense',
        'amount': p['amount'],
        'note': p['note'],
        'occurred_at': p['paid_at'] ?? DateTime.now().toUtc().toIso8601String(),
        'source': 'manual',
        'client_id': id,
        'payable_occurrence_id': p['id']
      });
    }
  }

  Future<String?> meta(String key) async =>
      (await _db.customSelect('SELECT value FROM metadata WHERE key=?', variables: [Variable(key)]).getSingleOrNull())
          ?.read<String>('value');
  Future<void> setMeta(String key, String value) => _db.customStatement(
      'INSERT INTO metadata(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value', [key, value]);
  Future<List<Map<String, dynamic>>> pending() async =>
      (await _db.customSelect("SELECT * FROM outbox WHERE state='pending' ORDER BY created_at,rowid").get())
          .map((r) => r.data)
          .toList();
  Future<int> pendingCount() async => (await _db
          .customSelect('SELECT (SELECT COUNT(*) FROM outbox)+(SELECT COUNT(*) FROM attachments WHERE uploaded=0) AS n')
          .getSingle())
      .read<int>('n');
  Future<List<Map<String, dynamic>>> errors() async =>
      (await _db.customSelect("SELECT * FROM outbox WHERE state='error'").get()).map((r) => r.data).toList();
  Future<void> operationError(String opId, String error) async {
    await _db.customStatement("UPDATE outbox SET state='error',error=? WHERE op_id=?", [error, opId]);
    notify();
  }

  Future<void> retryErrors() async {
    await _db.customStatement("UPDATE outbox SET state='pending',error=NULL WHERE state='error'");
    notify();
  }

  Future<void> discardOperation(String opId) async {
    await _db.customStatement('DELETE FROM outbox WHERE op_id=?', [opId]);
    notify();
  }

  Future<void> acknowledge(
      String opId, String entity, String id, Map<String, dynamic>? server, int version, bool deleted) async {
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM outbox WHERE op_id=?', [opId]);
      await _db
          .customStatement('UPDATE outbox SET base_version=? WHERE entity=? AND record_id=?', [version, entity, id]);
      final rest = await _db.customSelect('SELECT 1 FROM outbox WHERE entity=? AND record_id=? LIMIT 1',
          variables: [Variable(entity), Variable(id)]).get();
      if (rest.isEmpty && server != null) {
        await _db.customStatement(
            'INSERT INTO records(entity,id,data,version,deleted) VALUES(?,?,?,?,?) ON CONFLICT(entity,id) DO UPDATE SET data=excluded.data,version=excluded.version,deleted=excluded.deleted',
            [entity, id, jsonEncode(server), version, deleted ? 1 : 0]);
      } else {
        await _db.customStatement('UPDATE records SET version=? WHERE entity=? AND id=?', [version, entity, id]);
      }
    });
    notify();
  }

  Future<void> conflict(String entity, String id, Map<String, dynamic>? server, int version, bool deleted) async {
    final local = await _db.customSelect('SELECT * FROM records WHERE entity=? AND id=?',
        variables: [Variable(entity), Variable(id)]).getSingle();
    await _db.customStatement(
        'INSERT OR REPLACE INTO conflicts(entity,record_id,local_data,server_data,server_version,local_deleted,server_deleted) VALUES(?,?,?,?,?,?,?)',
        [
          entity,
          id,
          local.read<String>('data'),
          server == null ? null : jsonEncode(server),
          version,
          local.read<int>('deleted'),
          deleted ? 1 : 0
        ]);
    await _db.customStatement("UPDATE outbox SET state='conflict' WHERE entity=? AND record_id=?", [entity, id]);
    notify();
  }

  Future<List<Map<String, dynamic>>> conflicts() async =>
      (await _db.customSelect('SELECT * FROM conflicts').get()).map((r) => r.data).toList();
  Future<void> resolveConflict(String entity, String id, {required bool keepLocal}) async {
    await _db.transaction(() async {
      final c = await _db.customSelect('SELECT * FROM conflicts WHERE entity=? AND record_id=?',
          variables: [Variable(entity), Variable(id)]).getSingle();
      await _db.customStatement('DELETE FROM outbox WHERE entity=? AND record_id=?', [entity, id]);
      final server = c.readNullable<String>('server_data');
      await _db.customStatement('UPDATE records SET data=?,version=?,deleted=? WHERE entity=? AND id=?', [
        server ?? c.read<String>('local_data'),
        c.read<int>('server_version'),
        c.read<int>('server_deleted'),
        entity,
        id
      ]);
      await _db.customStatement('DELETE FROM conflicts WHERE entity=? AND record_id=?', [entity, id]);
      if (keepLocal)
        await _write(LocalMutation(entity, (jsonDecode(c.read<String>('local_data')) as Map).cast<String, dynamic>(),
            deleted: c.read<int>('local_deleted') == 1));
      await _derivePayments();
      await _deriveOccurrences();
    });
    notify();
  }

  /// Applied pages and their cursor commit together; never skip changes on crash.
  Future<void> applyPage(List<Map<String, dynamic>> changes, String cursor) async {
    await _db.transaction(() async {
      for (final c in changes) {
        final entity = c['entity'] as String;
        final id = c['id'] as String;
        final dirty = await _db.customSelect('SELECT 1 FROM outbox WHERE entity=? AND record_id=? LIMIT 1',
            variables: [Variable(entity), Variable(id)]).get();
        if (dirty.isNotEmpty) continue;
        final row = (c['row'] as Map?)?.cast<String, dynamic>() ?? {'id': id};
        await _db.customStatement(
            'INSERT INTO records(entity,id,data,version,deleted) VALUES(?,?,?,?,?) ON CONFLICT(entity,id) DO UPDATE SET data=excluded.data,version=excluded.version,deleted=excluded.deleted',
            [entity, id, jsonEncode(row), (c['version'] as num).toInt(), c['deleted'] == true ? 1 : 0]);
      }
      await setMeta('cursor', cursor);
    });
    if (changes.isNotEmpty) notify();
  }

  Future<void> attach(String path, Uint8List bytes, String mime) async {
    await _db.customStatement(
        'INSERT OR REPLACE INTO attachments(path,bytes,mime,uploaded) VALUES(?,?,?,0)', [path, bytes, mime]);
    notify();
  }

  Future<List<Map<String, dynamic>>> attachments() async =>
      (await _db.customSelect('SELECT * FROM attachments WHERE uploaded=0').get()).map((r) => r.data).toList();
  Future<Uint8List?> attachment(String path) async => (await _db
          .customSelect('SELECT bytes FROM attachments WHERE path=?', variables: [Variable(path)]).getSingleOrNull())
      ?.read<Uint8List>('bytes');
  Future<void> uploaded(String path) async =>
      _db.customStatement('UPDATE attachments SET uploaded=1,error=NULL WHERE path=?', [path]);

  Future<void> close() async {
    _closed = true;
    await _changes.close();
    await _db.close();
  }
}

final localStoreProvider = Provider<LocalStore?>((ref) {
  final id = ref.watch(currentUserIdProvider);
  if (id == null) return null;
  final store = LocalStore.forUser(id);
  ref.onDispose(() {
    unawaited(store.close());
  });
  return store;
});

final localRevisionProvider = StreamProvider<int>((ref) {
  final store = ref.watch(localStoreProvider);
  return store?.changes ?? const Stream.empty();
});
