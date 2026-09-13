import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/sync/sync_engine.dart';
import 'package:orbit_note/application/sync/sync_provider.dart';
import 'package:orbit_note/domain/sync_entry.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/workspace_sync_state_store.dart';

import 'support/fake_sync_provider.dart';
import 'support/memory_store.dart';

const vaultId = '11111111-1111-4111-8111-111111111111';

void main() {
  late FakeSyncProvider server;
  late _Replica a, b, c;
  late MemoryStore stateA, stateB, stateC;
  SyncEngine engine(_Replica replica, MemoryStore state) => SyncEngine(
    replica: replica,
    provider: server,
    stateStore: WorkspaceSyncStateStore(state),
  );
  setUp(() {
    server = FakeSyncProvider(vaultId);
    a = _Replica();
    b = _Replica();
    c = _Replica();
    stateA = MemoryStore();
    stateB = MemoryStore();
    stateC = MemoryStore();
  });

  test(
    'a local edit during upload remains pending and uploads next pass',
    () async {
      a.edit('note', 'captured');
      a.onRead = () {
        a.onRead = null;
        a.edit('note', 'newer local');
      };
      expect((await engine(a, stateA).sync()).pending, 1);
      expect(a.text('note'), 'newer local');
      expect(utf8.decode(server.bytes['note']!), 'captured');
      expect((await engine(a, stateA).sync()).upToDate, isTrue);
      expect(utf8.decode(server.bytes['note']!), 'newer local');
    },
  );

  test(
    'apply followed by checkpoint failure replays without applying twice',
    () async {
      a.edit('note', 'remote');
      await engine(a, stateA).sync();
      b.onApply = () => stateB.failWrites = true;
      await expectLater(
        engine(b, stateB).sync(),
        throwsA(isA<WorkspaceFailure>()),
      );
      expect(b.text('note'), 'remote');
      expect((await WorkspaceSyncStateStore(stateB).load())!['cursor'], isNull);
      stateB.failWrites = false;
      b.onApply = null;
      await engine(b, stateB).sync();
      expect(b.applies, 1);
    },
  );

  test(
    'download checksum mismatch leaves local content and cursor untouched',
    () async {
      a.edit('note', 'remote');
      await engine(a, stateA).sync();
      server.bytes['note'] = Uint8List.fromList(
        utf8.encode('corrupt transport'),
      );
      await expectLater(
        engine(b, stateB).sync(),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(b.entries, isEmpty);
      expect((await WorkspaceSyncStateStore(stateB).load())!['cursor'], isNull);
    },
  );

  test(
    'A to B, B to A and a later C converge without duplicate identities',
    () async {
      a.edit('note', 'from laptop');
      await engine(a, stateA).sync();
      await engine(b, stateB).sync();
      expect(b.text('note'), 'from laptop');
      b.edit('note', 'from phone');
      await engine(b, stateB).sync();
      await engine(a, stateA).sync();
      await engine(c, stateC).sync();
      expect(a.text('note'), 'from phone');
      expect(c.text('note'), 'from phone');
      expect(server.records.length, 1);
      expect((await engine(c, stateC).sync()).upToDate, isTrue);
    },
  );

  test(
    'offline edits coalesce and pending operations survive engine restart',
    () async {
      server.offline = true;
      a.edit('note', 'first');
      await expectLater(
        engine(a, stateA).sync(),
        throwsA(isA<WorkspaceFailure>()),
      );
      a.edit('note', 'latest local save');
      await expectLater(
        engine(a, stateA).sync(),
        throwsA(isA<WorkspaceFailure>()),
      );
      final state = await WorkspaceSyncStateStore(stateA).load();
      expect((state!['pending'] as Map).length, 1);
      final replicaId = state['replicaId'];
      server.offline = false;
      await engine(a, stateA).sync();
      expect(server.uploads, 1);
      expect(utf8.decode(server.bytes['note']!), 'latest local save');
      expect(
        (await WorkspaceSyncStateStore(stateA).load())!['replicaId'],
        replicaId,
      );
    },
  );

  test('independent offline edits to different objects both survive', () async {
    a.edit('one', 'base');
    a.edit('two', 'base');
    await engine(a, stateA).sync();
    await engine(b, stateB).sync();
    a.edit('one', 'laptop');
    b.edit('two', 'phone');
    await engine(a, stateA).sync();
    await engine(b, stateB).sync();
    await engine(a, stateA).sync();
    expect(a.text('two'), 'phone');
    expect(b.text('one'), 'laptop');
  });

  test(
    'concurrent same-object edits preserve both byte versions and base',
    () async {
      a.edit('note', 'base');
      await engine(a, stateA).sync();
      await engine(b, stateB).sync();
      a.edit('note', 'laptop alternative');
      b.edit('note', 'phone alternative');
      await engine(a, stateA).sync();
      final result = await engine(b, stateB).sync();
      expect(result.conflicts, 1);
      expect(result.upToDate, isFalse);
      expect(b.text('note'), 'phone alternative');
      expect(utf8.decode(b.conflictBytes.values.single), 'laptop alternative');
      expect(utf8.decode(server.bytes['note']!), 'laptop alternative');
      final saved = await WorkspaceSyncStateStore(stateB).load();
      expect(
        ((saved!['base'] as Map)['note'] as Map)['hash'],
        sha256.convert(utf8.encode('base')).toString(),
      );
    },
  );

  test(
    'explicit deletion propagates while delete versus edit conflicts',
    () async {
      a.edit('note', 'base');
      await engine(a, stateA).sync();
      await engine(b, stateB).sync();
      await engine(c, stateC).sync();
      a.edit('note', 'explicit tombstone', deleted: true);
      b.edit('note', 'offline edit');
      await engine(a, stateA).sync();
      expect((await engine(b, stateB).sync()).conflicts, 1);
      await engine(c, stateC).sync();
      expect(c.entries['note']!.deleted, isTrue);
      expect(b.text('note'), 'offline edit');
    },
  );

  test(
    'remote absence never authorizes local deletion or stale reupload',
    () async {
      a.edit('note', 'keep');
      await engine(a, stateA).sync();
      server.removeOutsideOrbit('note');
      final result = await engine(a, stateA).sync();
      expect(result.missing, 1);
      expect(a.text('note'), 'keep');
      expect(server.uploads, 1);
      expect(result.upToDate, isFalse);
    },
  );

  test(
    'move versus edit conflicts and a simple move preserves remote ID',
    () async {
      a.edit('note', 'base');
      await engine(a, stateA).sync();
      await engine(b, stateB).sync();
      final remoteId = server.records['note']!.remoteId;
      a.edit('note', 'base', path: 'Notes/Course/note.md');
      await engine(a, stateA).sync();
      expect(server.records['note']!.remoteId, remoteId);
      b.edit('note', 'phone');
      expect((await engine(b, stateB).sync()).conflicts, 1);
    },
  );

  test(
    'lost upload acknowledgement retries without a duplicate file',
    () async {
      a.edit('note', 'saved');
      server.failAfterUpload = true;
      await expectLater(
        engine(a, stateA).sync(),
        throwsA(isA<WorkspaceFailure>()),
      );
      expect(server.uploads, 1);
      await engine(a, stateA).sync();
      expect(server.uploads, 1);
      expect(server.records.length, 1);
      expect((await engine(a, stateA).sync()).upToDate, isTrue);
    },
  );

  test(
    'failed apply does not acknowledge cursor; replay later succeeds',
    () async {
      a.edit('note', 'download');
      await engine(a, stateA).sync();
      b.failApply = true;
      await expectLater(
        engine(b, stateB).sync(),
        throwsA(isA<WorkspaceFailure>()),
      );
      expect((await WorkspaceSyncStateStore(stateB).load())!['cursor'], isNull);
      b.failApply = false;
      await engine(b, stateB).sync();
      expect(b.text('note'), 'download');
    },
  );

  test('simultaneous triggers join a single serialized pass', () async {
    a.edit('note', 'one');
    final sync = engine(a, stateA);
    await Future.wait([sync.sync(), sync.sync(), sync.sync()]);
    expect(server.fetches, 1);
    expect(server.uploads, 1);
  });

  test(
    'foreign binding and newer state fail closed before network writes',
    () async {
      a.edit('note', 'safe');
      final store = WorkspaceSyncStateStore(stateA);
      await store.load();
      await store.save({
        'format': 'orbit-note-sync-state',
        'version': 2,
        'workspaceId': vaultId,
        'bindingId': server.bindingId,
      });
      await expectLater(
        engine(a, stateA).sync(),
        throwsA(isA<WorkspaceFailure>()),
      );
      expect(server.uploads, 0);
      expect(server.fetches, 0);
      expect(a.text('note'), 'safe');
    },
  );

  test('providers without atomic publication cannot upload', () async {
    server.supportsConditionalPublication = false;
    a.edit('note', 'safe');
    await expectLater(
      engine(a, stateA).sync(),
      throwsA(isA<WorkspaceFailure>()),
    );
    expect(server.uploads, 0);
  });
}

class _Replica implements SyncReplica {
  @override
  String get workspaceId => vaultId;
  final entries = <String, SyncEntry>{};
  final payloads = <String, Uint8List>{};
  final conflictBytes = <String, Uint8List>{};
  bool failApply = false;
  void Function()? onRead, onApply;
  int applies = 0;
  void edit(String key, String text, {String? path, bool deleted = false}) {
    final bytes = Uint8List.fromList(utf8.encode(text));
    entries[key] = SyncEntry(
      key: key,
      path: path ?? 'Notes/$key.md',
      hash: sha256.convert(bytes).toString(),
      deleted: deleted,
    );
    payloads[key] = bytes;
  }

  String text(String key) => utf8.decode(payloads[key]!);
  @override
  Future<Map<String, SyncEntry>> inventory() async => Map.of(entries);
  @override
  Stream<List<int>> read(SyncEntry expected) async* {
    if (!expected.sameAs(entries[expected.key])) {
      throw const WorkspaceConflict('Local changed');
    }
    yield Uint8List.fromList(payloads[expected.key]!);
    onRead?.call();
  }

  Future<Uint8List> _verified(SyncEntry entry, Stream<List<int>> source) async {
    final bytes = Uint8List.fromList(
      await source.expand((chunk) => chunk).toList(),
    );
    if (sha256.convert(bytes).toString() != entry.hash) {
      throw const WorkspaceConflict('Download hash mismatch');
    }
    return bytes;
  }

  @override
  Future<void> apply(
    SyncEntry incoming,
    Stream<List<int>> source, {
    required SyncEntry? expected,
  }) async {
    final bytes = await _verified(incoming, source);
    if (failApply) throw const WorkspaceFailure('Disk full');
    final current = entries[incoming.key];
    if (expected == null ? current != null : !expected.sameAs(current)) {
      throw const WorkspaceConflict('Local changed during download');
    }
    entries[incoming.key] = incoming;
    payloads[incoming.key] = bytes;
    applies++;
    onApply?.call();
  }

  @override
  Future<void> preserveConflict(
    String conflictId,
    SyncEntry local,
    RemoteSyncEntry remote,
    Stream<List<int>> source,
  ) async {
    conflictBytes[conflictId] = await _verified(remote.entry, source);
  }
}
