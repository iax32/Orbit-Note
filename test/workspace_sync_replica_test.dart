import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/application/sync/sync_engine.dart';
import 'package:orbit_note/domain/sync_entry.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/workspace_sync_state_store.dart';

import 'support/fake_sync_provider.dart';

class _InterruptedStore extends NativeWorkspaceStore {
  bool failAfterDelete = false, failAfterMove = false;
  @override
  Future<void> deleteFile(String path, {required String? expectedHash}) async {
    await super.deleteFile(path, expectedHash: expectedHash);
    if (failAfterDelete && path.startsWith('Notes/')) {
      failAfterDelete = false;
      throw const WorkspaceFailure('Interrupted after physical deletion');
    }
  }

  @override
  Future<void> moveSyncPath(
    String source,
    String target,
    Map<String, FileReplacement> replacements, {
    required void Function() checkCurrent,
  }) async {
    await super.moveSyncPath(
      source,
      target,
      replacements,
      checkCurrent: checkCurrent,
    );
    if (failAfterMove) {
      failAfterMove = false;
      throw const WorkspaceFailure('Lost move acknowledgement');
    }
  }
}

void main() {
  late Directory root;
  late WorkspaceRepository a, b;
  late NativeWorkspaceStore storeA;
  late _InterruptedStore storeB;
  late WorkspaceSyncReplica replicaA, replicaB;
  late FakeSyncProvider server;
  var drafts = false;
  SyncEngine engine(WorkspaceSyncReplica replica, NativeWorkspaceStore store) =>
      SyncEngine(
        replica: replica,
        provider: server,
        stateStore: replica.createStateStore(),
      );
  Future<void> syncA() async {
    await engine(replicaA, storeA).sync();
  }

  Future<void> syncB() async {
    await engine(replicaB, storeB).sync();
  }

  Future<SyncEntry> entry(WorkspaceSyncReplica r, String id) async =>
      (await r.inventory())[id]!;
  Future<Uint8List> read(WorkspaceSyncReplica r, SyncEntry e) async =>
      Uint8List.fromList(await r.read(e).expand((chunk) => chunk).toList());
  Future<SyncEntry> seed() async {
    final note = await a.create(
      typeId: 'orbit.note',
      title: 'Shared',
      body: 'exact **Markdown**\r\n',
    );
    await syncA();
    await syncB();
    return entry(replicaA, note.id);
  }

  setUp(() async {
    drafts = false;
    root = await Directory.systemTemp.createTemp('orbit-real-sync-');
    storeA = NativeWorkspaceStore();
    storeB = _InterruptedStore();
    a = WorkspaceRepository(store: storeA, index: MemoryObjectIndex());
    b = WorkspaceRepository(store: storeB, index: MemoryObjectIndex());
    await a.initialize(path: '${root.path}/a');
    await Directory('${root.path}/b').create();
    await File(
      '${root.path}/a/workspace.json',
    ).copy('${root.path}/b/workspace.json');
    await b.initialize(path: '${root.path}/b');
    replicaA = WorkspaceSyncReplica(a, canApply: () => true);
    replicaB = WorkspaceSyncReplica(b, canApply: () => !drafts);
    server = FakeSyncProvider(a.workspaceId);
  });
  tearDown(() async {
    await a.close();
    await b.close();
    await root.delete(recursive: true);
  });

  test('late state checkpoint cannot write a newly opened Vault', () async {
    final state = replicaB.createStateStore();
    await state.load();
    await b.initialize(path: '${root.path}/other');
    await expectLater(
      state.save({'old': 'state'}),
      throwsA(isA<WorkspaceConflict>()),
    );
    expect(await storeB.read(WorkspaceSyncStateStore.path), isNull);
  });

  test(
    'two real Vaults exchange exact Markdown and keep before-images',
    () async {
      final base = await seed();
      final raw = await read(replicaA, base);
      expect(await read(replicaB, await entry(replicaB, base.key)), raw);
      await b.save(b.objects.single.copyWith(body: 'phone $raw\n'));
      await syncB();
      await syncA();
      expect(a.objects.single.body, b.objects.single.body);
      expect(a.objects.single.id, base.key);
      final backups = (await storeA.listFiles()).where(
        (p) => p.startsWith('.orbit/history/') && p.endsWith('.before'),
      );
      final history = await Future.wait(backups.map(storeA.read));
      expect(
        history.whereType<Uint8List>().map(
          (bytes) => sha256.convert(bytes).toString(),
        ),
        contains(base.hash),
      );
    },
  );

  test(
    'loose PDFs and media transfer exactly, update safely and survive reopen',
    () async {
      final paths = [
        'seWS26_ue1_angabe.pdf',
        'Courses/Week 1/SLIDES.PDF',
        'Notes/Week 1/diagram.png',
        'References/report.docx',
        'Models/chair.glb',
      ];
      final payload = Uint8List.fromList(
        List.generate(1024 * 1024 + 17, (i) => i % 251),
      );
      for (final path in paths) {
        final file = File('${a.location}/$path');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(payload);
      }
      expect((await a.syncInventory()).issues, isEmpty);
      await syncA();
      await syncB();
      for (final path in paths) {
        expect(await File('${b.location}/$path').readAsBytes(), payload);
        expect(
          (await entry(replicaB, 'blob:$path')).hash,
          sha256.convert(payload).toString(),
        );
      }
      final updated = Uint8List.fromList([0, 255, 128, 10]);
      await File('${a.location}/${paths.first}').writeAsBytes(updated);
      await syncA();
      await syncB();
      await b.initialize(path: b.location);
      expect(await File('${b.location}/${paths.first}').readAsBytes(), updated);
      expect((await b.syncInventory()).ready, isTrue);
      expect(b.objects, isEmpty); // No invented IDs or implicit imports.
      replicaB = WorkspaceSyncReplica(b, canApply: () => !drafts);
      await File('${a.location}/${paths.first}').writeAsBytes([1, 2]);
      await File('${b.location}/${paths.first}').writeAsBytes([3, 4]);
      await syncA();
      final result = await engine(replicaB, storeB).sync();
      expect(result.conflicts, 1);
      expect(await File('${b.location}/${paths.first}').readAsBytes(), [3, 4]);
    },
  );

  test(
    'streamed attachment precedes its owning file and survives reopen',
    () async {
      final payload = Uint8List.fromList(
        List.generate(2 * 1024 * 1024, (i) => i % 251),
      );
      final file = await a.importAttachment(name: 'sample.pdf', bytes: payload);
      await syncA();
      await syncB();
      expect(
        await b.readAttachment(file.properties['contentRef'] as String),
        payload,
      );
      await b.initialize(path: b.location);
      expect(b.objects.single.id, file.id);
      expect((await b.syncInventory()).ready, isTrue);
    },
  );

  test(
    'canvas, saved View, Trash and unknown metadata retain exact bytes',
    () async {
      final board = await a.create(
        typeId: 'orbit.canvas',
        title: 'Board',
        data: {
          'elements': [],
          'future': {'keep': 42},
        },
      );
      await a.create(
        typeId: 'orbit.view',
        title: 'Board view',
        properties: {'viewType': 'board'},
      );
      final trash = await a.create(typeId: 'orbit.note', title: 'Trash');
      await a.trash(trash.id);
      await syncA();
      await syncB();
      expect(b.objects.length, 3);
      expect(b.objects.singleWhere((o) => o.id == trash.id).isDeleted, isTrue);
      expect(
        await read(replicaA, await entry(replicaA, board.id)),
        await read(replicaB, await entry(replicaB, board.id)),
      );
    },
  );

  test('dirty drafts reject apply before consuming a network stream', () async {
    final base = await seed();
    drafts = true;
    var consumed = false;
    Stream<List<int>> bytes() async* {
      consumed = true;
      yield [1];
    }

    await expectLater(
      replicaB.apply(base, bytes(), expected: base),
      throwsA(isA<WorkspaceConflict>()),
    );
    expect(consumed, isFalse);
    expect(b.objects.single.body, 'exact **Markdown**\r\n');
  });

  test(
    'draft arriving during download rejects publication and cleans staging',
    () async {
      final base = await seed();
      await a.save(a.objects.single.copyWith(body: 'remote'));
      final incoming = await entry(replicaA, base.key);
      final bytes = await read(replicaA, incoming);
      Stream<List<int>> arriving() async* {
        yield bytes;
        drafts = true;
      }

      await expectLater(
        replicaB.apply(incoming, arriving(), expected: base),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(b.objects.single.body, 'exact **Markdown**\r\n');
      expect(
        (await storeB.listFiles()).where((p) => p.endsWith('.part')),
        isEmpty,
      );
    },
  );

  test(
    'local save proceeds during a stalled download and prevents stale apply',
    () async {
      final base = await seed();
      await a.save(a.objects.single.copyWith(body: 'remote'));
      final incoming = await entry(replicaA, base.key);
      final bytes = await read(replicaA, incoming);
      final started = Completer<void>(), gate = Completer<void>();
      Stream<List<int>> network() async* {
        started.complete();
        await gate.future;
        yield bytes;
      }

      final applying = replicaB.apply(incoming, network(), expected: base);
      final failed = expectLater(applying, throwsA(isA<WorkspaceConflict>()));
      await started.future;
      await b.save(b.objects.single.copyWith(body: 'new local'));
      gate.complete();
      await failed;
      expect(b.objects.single.body, 'new local');
    },
  );

  test(
    'Vault switch invalidates a download even reopening the same UUID',
    () async {
      final base = await seed();
      final bytes = await read(replicaA, base);
      final started = Completer<void>(), gate = Completer<void>();
      Stream<List<int>> network() async* {
        started.complete();
        await gate.future;
        yield bytes;
      }

      final applying = replicaB.apply(base, network(), expected: base);
      final failed = expectLater(applying, throwsA(isA<WorkspaceConflict>()));
      await started.future;
      await b.initialize(path: b.location);
      gate.complete();
      await failed;
      await expectLater(
        replicaB.inventory(),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(b.objects.single.id, base.key);
    },
  );

  test(
    'bad transport checksum leaves local bytes and checkpoint unchanged',
    () async {
      final base = await seed();
      await a.save(a.objects.single.copyWith(body: 'remote'));
      await syncA();
      final before = await WorkspaceSyncStateStore(storeB).load();
      server.bytes[base.key] = Uint8List.fromList([1, 2, 3]);
      await expectLater(syncB(), throwsA(isA<WorkspaceConflict>()));
      expect(
        (await WorkspaceSyncStateStore(storeB).load())!['cursor'],
        before!['cursor'],
      );
      expect((await entry(replicaB, base.key)).hash, base.hash);
    },
  );

  test(
    'simultaneous edits retain both conflict copies without live duplicates',
    () async {
      final base = await seed();
      await a.save(a.objects.single.copyWith(body: 'laptop'));
      await b.save(b.objects.single.copyWith(body: 'phone'));
      await syncA();
      final result = await engine(replicaB, storeB).sync();
      expect(result.conflicts, 1);
      expect(b.objects.single.body, 'phone');
      final files = (await storeB.listFiles())
          .where((p) => p.startsWith('.orbit/sync-conflicts/'))
          .toList();
      expect(files.where((p) => p.endsWith('/remote')).length, 1);
      expect(
        utf8.decode(
          (await storeB.read(files.singleWhere((p) => p.endsWith('/remote'))))!,
        ),
        contains('laptop'),
      );
      await syncB();
      expect(
        (await storeB.listFiles())
            .where((p) => p.endsWith('/conflict.json'))
            .length,
        1,
      );
      expect(b.objects.single.id, base.key);
    },
  );

  test(
    'Note move with edited source preserves UUID and raw Markdown',
    () async {
      final base = await seed();
      await a.createFolder('Notes/Topic');
      await a.moveNote(base.key, 'Notes/Topic');
      await a.save(a.objects.single.copyWith(body: 'moved and edited'));
      await syncA();
      await syncB();
      expect(b.objectPath(base.key), a.objectPath(base.key));
      expect(await storeB.read(base.path), isNull);
      expect(
        await read(replicaB, await entry(replicaB, base.key)),
        await read(replicaA, await entry(replicaA, base.key)),
      );
    },
  );

  test(
    'committed move with lost acknowledgement is refreshed and replay-safe',
    () async {
      final base = await seed();
      await a.createFolder('Notes/Topic');
      await a.moveNote(base.key, 'Notes/Topic');
      await syncA();
      storeB.failAfterMove = true;
      await expectLater(syncB(), throwsA(isA<WorkspaceFailure>()));
      expect(b.objectPath(base.key), a.objectPath(base.key));
      await syncB();
      expect(b.objects.length, 1);
      expect((await engine(replicaB, storeB).sync()).upToDate, isTrue);
    },
  );

  test(
    'interrupted remote deletion reopens with exact tombstone and recovery bytes',
    () async {
      final base = await seed();
      final raw = await read(replicaA, base);
      await a.trash(base.key);
      await syncA();
      await syncB();
      await a.deletePermanently(base.key);
      await syncA();
      storeB.failAfterDelete = true;
      await expectLater(syncB(), throwsA(isA<WorkspaceFailure>()));
      expect(b.readOnly, isTrue);
      await b.initialize(path: b.location);
      replicaB = WorkspaceSyncReplica(b, canApply: () => !drafts);
      expect(b.readOnly, isFalse);
      expect(b.objects, isEmpty);
      expect(
        (await entry(replicaB, base.key)).hash,
        (await entry(replicaA, base.key)).hash,
      );
      final backups = (await storeB.listFiles()).where(
        (p) => p.startsWith('.orbit/sync-conflicts/delete-'),
      );
      expect(backups, isNotEmpty);
      expect(
        utf8.decode((await storeB.read(backups.single))!),
        contains(utf8.decode(raw).split('---').last),
      );
      await syncB();
      expect((await engine(replicaB, storeB).sync()).upToDate, isTrue);
    },
  );

  test(
    'remote manifest rename keeps UUID and permits subsequent local saves',
    () async {
      await seed();
      await a.renameWorkspace('Renamed vault');
      await syncA();
      await syncB();
      expect(b.name, 'Renamed vault');
      expect(b.workspaceId, a.workspaceId);
      await b.save(b.objects.single.copyWith(body: 'after rename'));
      await syncB();
      await syncA();
      expect(a.objects.single.body, 'after rename');
    },
  );

  test(
    'remote identity substitution is rejected with original source intact',
    () async {
      final base = await seed();
      final bytes = Uint8List.fromList(
        utf8.encode(
          utf8
              .decode(await read(replicaA, base))
              .replaceAll(base.key, '99999999-9999-4999-8999-999999999999'),
        ),
      );
      final incoming = SyncEntry(
        key: base.key,
        path: base.path,
        hash: sha256.convert(bytes).toString(),
      );
      await expectLater(
        replicaB.apply(incoming, Stream.value(bytes), expected: base),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect((await entry(replicaB, base.key)).hash, base.hash);
    },
  );
}
