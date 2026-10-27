import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_providers.dart';
import 'local_store.dart';

class SyncStatus {
  const SyncStatus(
      {this.running = false,
      this.pending = 0,
      this.conflicts = 0,
      this.error,
      this.lastSuccess,
      this.initialized = false});
  final bool running;
  final int pending;
  final int conflicts;
  final String? error;
  final DateTime? lastSuccess;
  final bool initialized;
}

abstract interface class SyncRemote {
  String? get userId;
  Future<Map<String, dynamic>> pull(int cursor);
  Future<Map<String, dynamic>> push(Map<String, dynamic> parameters);
  Future<void> upload(String path, Uint8List bytes, String mime);
}

class SupabaseSyncRemote implements SyncRemote {
  SupabaseSyncRemote(this.client);
  final SupabaseClient client;
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Future<Map<String, dynamic>> pull(int cursor) async =>
      (await client.rpc('sync_pull', params: {'cursor': cursor, 'limit': 500}) as Map).cast<String, dynamic>();
  @override
  Future<Map<String, dynamic>> push(Map<String, dynamic> parameters) async =>
      (await client.rpc('sync_push', params: parameters) as Map).cast<String, dynamic>();
  @override
  Future<void> upload(String path, Uint8List bytes, String mime) async {
    await client.storage
        .from('receipts')
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: true));
  }
}

class SyncController extends StateNotifier<SyncStatus> with WidgetsBindingObserver {
  SyncController(LocalStore store, SupabaseClient client) : this.withRemote(store, SupabaseSyncRemote(client));
  SyncController.withRemote(this.store, this.remote, {bool autoStart = true}) : super(const SyncStatus()) {
    if (!autoStart) return;
    WidgetsBinding.instance.addObserver(this);
    _local = store.changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 700), () => sync());
    });
    _network = Connectivity().onConnectivityChanged.listen((types) {
      if (!types.contains(ConnectivityResult.none)) sync();
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => sync());
    scheduleMicrotask(sync);
  }
  final LocalStore store;
  final SyncRemote remote;
  StreamSubscription<int>? _local;
  StreamSubscription<List<ConnectivityResult>>? _network;
  Timer? _timer, _debounce;
  bool _working = false, _disposed = false;
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) sync();
  }

  Future<void> _state({bool running = false, String? error}) async {
    final pending = await store.pendingCount();
    final conflicts = (await store.conflicts()).length;
    final last = await store.meta('last_sync');
    final ready = await store.meta('bootstrapped') == 'true';
    if (!_disposed)
      state = SyncStatus(
          running: running,
          pending: pending,
          conflicts: conflicts,
          error: error,
          lastSuccess: last == null ? null : DateTime.tryParse(last),
          initialized: ready);
  }

  Future<void> sync({bool retryErrors = false}) async {
    if (_working || _disposed) return;
    _working = true;
    _debounce?.cancel();
    String? error;
    try {
      await _state(running: true);
      if (retryErrors) await store.retryErrors();
      if (remote.userId != store.userId) throw StateError('Đăng nhập lại để đồng bộ; ghi chép trên máy vẫn được giữ');
      // Validate auth server-side only through the request itself: an expired
      // refresh cannot erase a user's offline database.
      await _pull();
      for (final a in await store.attachments()) {
        if (_disposed) return;
        final path = a['path'] as String;
        try {
          await remote.upload(path, a['bytes'] as Uint8List, a['mime'] as String);
          await store.uploaded(path);
        } catch (_) {
          error = 'Ảnh hóa đơn đang chờ upload. Các ghi chép khác vẫn được đồng bộ.';
        }
      }
      final pending = await store.pending();
      // Preserve operation ordering. Parents are normally created first, but
      // deletes of parents intentionally precede child cleanup in their batch.
      final blocked = <String>{
        for (final error in await store.errors()) '${error['entity']}/${error['record_id']}',
        for (final conflict in await store.conflicts()) '${conflict['entity']}/${conflict['record_id']}',
      };
      for (final original in pending) {
        if (_disposed) return;
        final entity = original['entity'] as String, id = original['record_id'] as String;
        final key = '$entity/$id';
        if (blocked.contains(key)) continue;
        // ACK of an earlier edit rebases later queued edits on its version.
        final op = (await store.pending()).where((o) => o['op_id'] == original['op_id']).firstOrNull;
        if (op == null) continue;
        try {
          final payload = (jsonDecode(op['payload'] as String) as Map).cast<String, dynamic>();
          for (final k in [
            'id',
            'user_id',
            'version',
            'deleted',
            'created_at',
            'updated_at',
            'is_legacy',
            'debt_payment_id'
          ]) {
            payload.remove(k);
          }
          if (entity == 'debts') {
            payload.remove('paid_amount');
            payload.remove('status');
          }
          if (entity == 'payable_occurrences') {
            payload.remove('record_transaction');
          }
          final reply = await remote.push({
            'op_id': op['op_id'],
            'entity': entity,
            'record_id': id,
            'base_version': op['base_version'],
            'payload': payload,
            'deleted': op['deleted'] == 1
          });
          final version = (reply['version'] as num? ?? 0).toInt();
          final row = (reply['row'] as Map?)?.cast<String, dynamic>();
          final deleted = reply['deleted'] == true || row?['deleted'] == true;
          if (reply['status'] == 'conflict') {
            blocked.add(key);
            await store.conflict(entity, id, row, version, deleted);
          } else if (reply['status'] == 'error') {
            blocked.add(key);
            await store.operationError(
                op['op_id'] as String, reply['message']?.toString() ?? 'Thay đổi không được chấp nhận');
          } else {
            await store.acknowledge(op['op_id'] as String, entity, id, row, version, deleted);
          }
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST301' || e.code == '42501') rethrow;
          blocked.add(key);
          await store.operationError(op['op_id'] as String, e.message);
        }
      }
      await _pull();
      await store.setMeta('last_sync', DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      error =
          e is PostgrestException ? e.message : 'Chưa đồng bộ được. Dữ liệu trên máy được giữ; thử lại khi có mạng.';
    } finally {
      if (!_disposed) await _state(error: error);
      _working = false;
      // Ignore revisions emitted by our own pull/ACK; user edits after this
      // point schedule the next pass, otherwise the periodic timer retries.
      _debounce?.cancel();
    }
  }

  Future<void> _pull() async {
    var cursor = int.tryParse(await store.meta('cursor') ?? '0') ?? 0;
    for (var page = 0; page < 1000; page++) {
      final reply = await remote.pull(cursor);
      final changes = ((reply['changes'] as List?) ?? []).map((c) => (c as Map).cast<String, dynamic>()).toList();
      final next = (reply['cursor'] as num? ?? cursor).toInt();
      await store.applyPage(changes, next.toString());
      cursor = next;
      if (reply['has_more'] != true) {
        await store.setMeta('bootstrapped', 'true');
        await store.reconcileDerived();
        return;
      }
    }
    throw StateError('Quá nhiều thay đổi, tiếp tục đồng bộ ở lần sau');
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _local?.cancel();
    _network?.cancel();
    _timer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}

final syncControllerProvider = StateNotifierProvider<SyncController, SyncStatus>((ref) {
  final store = ref.watch(localStoreProvider);
  if (store == null) throw StateError('Cần tài khoản để đồng bộ');
  return SyncController(store, ref.watch(supabaseClientProvider));
});
