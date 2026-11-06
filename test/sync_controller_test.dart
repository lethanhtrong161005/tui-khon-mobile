import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/core/offline/sync_controller.dart';

class FakeRemote implements SyncRemote {
  @override
  String? userId = 'u';
  final records = <String, Map<String, dynamic>>{};
  final operations = <String, Map<String, dynamic>>{};
  final journal = <Map<String, dynamic>>[];
  bool online = true, loseNextAck = false;
  @override
  Future<Map<String, dynamic>> pull(int cursor) async {
    if (!online) throw StateError('offline');
    return {
      'changes': journal.where((c) => (c['seq'] as int) > cursor).toList(),
      'cursor': journal.length,
      'has_more': false
    };
  }

  @override
  Future<Map<String, dynamic>> push(Map<String, dynamic> parameters) async {
    if (!online) throw StateError('offline');
    final op = parameters['op_id'] as String;
    final replay = operations[op];
    if (replay != null) return replay;
    final key = '${parameters['entity']}/${parameters['record_id']}';
    final existing = records[key];
    if ((existing?['version'] ?? 0) != parameters['base_version'])
      return {'status': 'conflict', 'version': existing?['version'] ?? 0, 'row': existing};
    final row = <String, dynamic>{
      ...?existing,
      ...Map<String, dynamic>.from(parameters['payload'] as Map),
      'id': parameters['record_id'],
      'user_id': 'u',
      'version': (existing?['version'] as int? ?? 0) + 1,
      'deleted': parameters['deleted']
    };
    records[key] = row;
    final response = {'status': 'applied', 'version': row['version'], 'row': row};
    operations[op] = response;
    journal.add({
      'seq': journal.length + 1,
      'entity': parameters['entity'],
      'id': row['id'],
      'version': row['version'],
      'deleted': row['deleted'],
      'row': row
    });
    if (loseNextAck) {
      loseNextAck = false;
      throw StateError('response lost after commit');
    }
    return response;
  }

  @override
  Future<void> upload(String path, Uint8List bytes, String mime) async {
    if (!online) throw StateError('offline');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('lost ACK retries stable operation without duplicate server insert', () async {
    final store = LocalStore.memory('u'), remote = FakeRemote();
    final controller = SyncController.withRemote(store, remote, autoStart: false);
    await store.put('wallets', {'id': 'w', 'name': 'Cash', 'initial_balance': 100});
    remote.loseNextAck = true;
    await controller.sync();
    expect(await store.pendingCount(), 1);
    expect(remote.records.length, 1);
    await controller.sync();
    expect(await store.pendingCount(), 0);
    expect(remote.records.length, 1);
    expect(remote.operations.length, 1);
    controller.dispose();
    await store.close();
  });
  test('two devices preserve edit conflict until explicit selection', () async {
    final remote = FakeRemote(), a = LocalStore.memory('u'), b = LocalStore.memory('u');
    final first = SyncController.withRemote(a, remote, autoStart: false),
        second = SyncController.withRemote(b, remote, autoStart: false);
    await a.put('wallets', {'id': 'w', 'name': 'Cash', 'initial_balance': 100});
    await first.sync();
    await second.sync();
    await a.put('wallets', {'id': 'w', 'name': 'Device A'});
    await b.put('wallets', {'id': 'w', 'name': 'Device B'});
    await first.sync();
    await second.sync();
    expect((await b.conflicts()).length, 1);
    expect((await b.record('wallets', 'w'))!['name'], 'Device B');
    expect(remote.records['wallets/w']!['name'], 'Device A');
    await b.resolveConflict('wallets', 'w', keepLocal: true);
    await second.sync();
    await first.sync();
    expect(remote.records['wallets/w']!['name'], 'Device B');
    expect((await a.record('wallets', 'w'))!['name'], 'Device B');
    first.dispose();
    second.dispose();
    await a.close();
    await b.close();
  });
  test('offline and expired auth preserve records/outbox', () async {
    final store = LocalStore.memory('u'), remote = FakeRemote()..online = false;
    final controller = SyncController.withRemote(store, remote, autoStart: false);
    await store.put('wallets', {'id': 'w', 'name': 'Cash'});
    await controller.sync();
    expect(await store.pendingCount(), 1);
    remote
      ..online = true
      ..userId = null;
    await controller.sync();
    expect((await store.rows('wallets')).length, 1);
    expect(await store.pendingCount(), 1);
    remote.userId = 'u';
    await controller.sync();
    expect(await store.pendingCount(), 0);
    controller.dispose();
    await store.close();
  });
  test('multiple queued edits of same row rebase after each acknowledgement', () async {
    final store = LocalStore.memory('u'), remote = FakeRemote();
    final controller = SyncController.withRemote(store, remote, autoStart: false);
    await store.put('wallets', {'id': 'w', 'name': 'First'});
    await store.put('wallets', {'id': 'w', 'name': 'Second'});
    await store.put('wallets', {'id': 'w', 'name': 'Third'});
    await controller.sync();
    expect(await store.pendingCount(), 0);
    expect(await store.conflicts(), isEmpty);
    expect(remote.records['wallets/w']!['name'], 'Third');
    controller.dispose();
    await store.close();
  });
}
