import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/application/sync/sync_engine.dart';
import 'package:orbit_note/application/sync/drive_vault_batch.dart';
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/domain/sync_entry.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'google_account_test.dart' show TestGoogleCredentials;
import 'google_drive_account_test.dart' show FakeGoogleAuth;
import 'support/drive_sync_service.dart';

void main() {
  late Directory root;
  late WorkspaceRepository a, b;
  late NativeWorkspaceStore sa, sb;
  late WorkspaceSyncReplica ra, rb;
  late GoogleDriveSyncProvider pa, pb;
  late DriveSyncService server;
  late FakeGoogleAuth auth;
  var current = true, drafts = false;
  GoogleDriveSyncProvider provider(
    WorkspaceSyncReplica replica, {
    DateTime Function()? now,
  }) => GoogleDriveSyncProvider(
    api: GoogleDriveApi(
      auth: auth,
      client: server.client,
      localMetadata: TestGoogleCredentials(),
    ),
    vault: GoogleRemoteVault(
      folderId: 'sync-vault',
      workspaceId: a.workspaceId,
      name: 'Synced Vault',
      accountSubject: 'subject-1',
    ),
    journal: replica.createDriveJournalStore(),
    stage: replica.stageTransfer,
    isCurrent: () => current,
    now: now,
  );
  SyncEngine engine(WorkspaceSyncReplica replica, GoogleDriveSyncProvider p) =>
      SyncEngine(
        replica: replica,
        provider: p,
        stateStore: replica.createStateStore(),
      );
  Future<String> seed() async {
    final note = await a.create(
      typeId: 'orbit.note',
      title: 'Course',
      body: 'original 😀\r\n',
    );
    await engine(ra, pa).sync();
    await engine(rb, pb).sync();
    return note.id;
  }

  void appendHistory(String objectId, int count, String prefix) {
    final base = server.revisions.lastWhere(
      (f) => jsonDecode(utf8.decode(f.bytes))['entry']['key'] == objectId,
    );
    final source = jsonDecode(utf8.decode(base.bytes)) as Map<String, dynamic>;
    var parent = base.metadata['id'] as String;
    for (var i = 0; i < count; i++) {
      final id = '$prefix-$i';
      server.files[id] = DriveTestFile(
        {
          ...base.metadata,
          'id': id,
          'appProperties': {
            ...base.metadata['appProperties'] as Map,
            'orbitOp': id,
          },
        },
        utf8.encode(
          jsonEncode({
            ...source,
            'operation': id,
            'parents': [parent],
          }),
        ),
      );
      parent = id;
    }
  }

  test(
    'catch-up reads independent revisions concurrently with a bounded working set',
    () async {
      final id = await seed();
      appendHistory(id, 12, 'parallel');
      server.mediaDelay = const Duration(milliseconds: 20);
      server.peakMedia = 0;
      final watch = Stopwatch()..start();
      final delta = await provider(rb).fetchChanges(null);
      watch.stop();
      expect(
        delta.entries.singleWhere((e) => e.entry.key == id).version,
        'parallel-11',
      );
      expect(server.peakMedia, 4);
      expect(server.activeMedia, 0);
      final journal = await rb.createDriveJournalStore().load();
      expect(
        (journal!['changeFeed']['ids'] as List).length,
        server.revisions.length,
      );
      debugPrint(
        'DRIVE_CATCHUP: peakReads=${server.peakMedia} wallMs=${watch.elapsedMilliseconds} syntheticMediaLatencyMs=20',
      );
    },
  );

  test(
    'cancelling parallel catch-up drains reads without advancing its checkpoint',
    () async {
      final id = await seed();
      appendHistory(id, 8, 'cancel-catchup');
      final before = await rb.createDriveJournalStore().load();
      server.beforeMediaRead = () async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        current = false;
      };
      await expectLater(
        provider(rb).fetchChanges(null),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(server.activeMedia, 0);
      current = true;
      expect(await rb.createDriveJournalStore().load(), before);
    },
  );

  test(
    'fast large-file uploads use fewer ranges and preserve every byte',
    () async {
      final bytes = Uint8List.fromList(
        List.generate(14 * 1024 * 1024 + 37, (i) => i % 251),
      );
      final entry = SyncEntry(
        key: 'blob:Attachments/range-budget.bin',
        path: 'Attachments/range-budget.bin',
        hash: sha256.convert(bytes).toString(),
      );
      final uploaded = await pa.upload(
        entry,
        Stream.value(bytes),
        operationId: 'range-budget',
        expectedVersion: null,
      );
      expect(
        server.uploadedOffsets.length,
        lessThanOrEqualTo(5),
        reason: 'The previous fixed size needed 15 data requests.',
      );
      expect(server.uploadedOffsets.first, 0);
      expect(
        sha256
            .convert(await pb.download(uploaded).expand((c) => c).toList())
            .toString(),
        entry.hash,
      );
      debugPrint(
        'DRIVE_RANGES: bytes=${bytes.length} requests=${server.uploadedOffsets.length}',
      );
    },
  );

  test('small Vault sync request budget and exact two-client transfer', () async {
    final notes = <String>[];
    for (var i = 0; i < 10; i++) {
      notes.add(
        (await a.create(
          typeId: 'orbit.note',
          title: 'Latency $i',
          body: 'Exact content $i\n' * 100,
        )).id,
      );
    }
    final publishStart = server.requests, publishLists = server.historyLists;
    final published = await engine(ra, pa).sync();
    final publishRequests = server.requests - publishStart;
    final scans = server.historyLists - publishLists;
    final receiveStart = server.requests, reads = server.mediaReads;
    final received = await engine(rb, pb).sync();
    final receiveRequests = server.requests - receiveStart;
    debugPrint(
      'DRIVE_THROUGHPUT: publishRequests=$publishRequests historyLists=$scans receiveRequests=$receiveRequests receiveMedia=${server.mediaReads - reads}',
    );
    expect(published.upToDate, true);
    expect(received.upToDate, true);
    // Round-trip budgets, including normal immutable publication verification.
    // Baseline was 135/23/44; avoid reintroducing per-file duplicate preflights.
    expect(publishRequests, lessThanOrEqualTo(85));
    expect(scans, lessThanOrEqualTo(12));
    expect(receiveRequests, lessThanOrEqualTo(36));
    for (var i = 0; i < notes.length; i++) {
      expect(
        b.objects.singleWhere((n) => n.id == notes[i]).body,
        'Exact content $i\n' * 100,
      );
    }
  });
  test(
    'paused preflight cannot acknowledge an already published retry receipt',
    () async {
      final id = await seed();
      final local = (await ra.inventory())[id]!;
      final journal = await ra.createDriveJournalStore().load();
      final operation = (journal!['operations'] as Map).entries.singleWhere(
        (e) => (e.value as Map)['entry']['key'] == id,
      );
      await pa.inspect(id);
      final requests = server.requests;
      current = false;
      await expectLater(
        pa.upload(
          local,
          const Stream.empty(),
          operationId: operation.key as String,
          expectedVersion: null,
        ),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(server.requests, requests);
    },
  );
  test(
    'opening a cloud Vault reads only its manifest history before import',
    () async {
      for (var i = 0; i < 12; i++) {
        await a.create(
          typeId: 'orbit.note',
          title: 'Open $i',
          body: 'Content $i',
        );
      }
      await engine(ra, pa).sync();
      final reads = server.mediaReads;
      final bundle = await prepareDriveVaultBundle(
        GoogleDriveApi(
          auth: auth,
          client: server.client,
          localMetadata: TestGoogleCredentials(),
        ),
        GoogleRemoteVault(
          folderId: 'sync-vault',
          workspaceId: a.workspaceId,
          name: 'Synthetic',
          accountSubject: 'subject-1',
        ),
        () => current,
      );
      expect(bundle.files.keys, ['workspace.json']);
      expect(
        bundle.files['workspace.json'],
        await File('${a.location}/workspace.json').readAsBytes(),
      );
      expect(
        server.mediaReads - reads,
        lessThanOrEqualTo(2),
        reason:
            'Do not download every note revision twice during a new-device open.',
      );
    },
  );
  for (final incomplete in [true, false]) {
    test(
      'publication verifies readback when upload metadata is ${incomplete ? 'incomplete' : 'inconsistent'}',
      () async {
        server.omitUploadMetadata = incomplete;
        server.wrongUploadChecksum = !incomplete;
        final bytes = Uint8List.fromList([0, 1, 255, 128]);
        final entry = SyncEntry(
          key: 'blob:Attachments/ack.bin',
          path: 'Attachments/ack.bin',
          hash: sha256.convert(bytes).toString(),
        );
        final uploaded = await pa.upload(
          entry,
          Stream.value(bytes),
          operationId: 'ack-fallback',
          expectedVersion: null,
        );
        expect(
          server.mediaReads,
          greaterThan(0),
          reason:
              'An unproven acknowledgement must retain the validated readback path.',
        );
        expect(await pb.download(uploaded).expand((c) => c).toList(), bytes);
        expect(server.recordCreates, 1);
      },
    );
  }
  test(
    'verified publications stay visible while Drive query and feed indexes lag',
    () async {
      server.holdChanges = true;
      server.hideRevisionListings = true;
      final note = await a.create(
        typeId: 'orbit.note',
        title: 'Index lag',
        body: 'Never hide a verified receipt.',
      );
      expect((await engine(ra, pa).sync()).upToDate, true);
      final delta = await provider(ra).fetchChanges(null);
      final published = delta.entries.singleWhere(
        (e) => e.entry.key == note.id,
      );
      expect((await provider(ra).inspect(note.id))?.version, published.version);
      final state = await ra.createDriveJournalStore().load();
      expect(
        (state!['changeFeed']['ids'] as List).length,
        server.revisions.length,
      );
      server.holdChanges = false;
      server.hideRevisionListings = false;
      expect((await engine(rb, pb).sync()).upToDate, true);
      expect(b.objects.singleWhere((o) => o.id == note.id).body, note.body);
    },
  );
  test(
    'Drive transfers loose root PDF and nested mixed-case media without importing objects',
    () async {
      final files = {
        'seWS26_ue1_angabe.pdf': [37, 80, 68, 70, 0, 255, 128],
        'Courses/Week 1/diagram.PNG': [0, 255, 1, 128],
        'Models/chair.GLB': [103, 108, 84, 70, 0],
        'References/empty.txt': <int>[],
      };
      for (final entry in files.entries) {
        final file = File('${a.location}/${entry.key}');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.value);
      }
      await engine(ra, pa).sync();
      await engine(rb, pb).sync();
      for (final entry in files.entries) {
        expect(
          await File('${b.location}/${entry.key}').readAsBytes(),
          entry.value,
        );
      }
      expect((await b.syncInventory()).ready, isTrue);
      expect(b.objects, isEmpty);
      await File(
        '${a.location}/seWS26_ue1_angabe.pdf',
      ).writeAsBytes([37, 80, 68, 70, 2]);
      await engine(ra, pa).sync();
      await engine(rb, pb).sync();
      expect(await File('${b.location}/seWS26_ue1_angabe.pdf').readAsBytes(), [
        37,
        80,
        68,
        70,
        2,
      ]);
    },
  );

  setUp(() async {
    current = true;
    drafts = false;
    root = await Directory.systemTemp.createTemp('orbit-drive-replicas-');
    sa = NativeWorkspaceStore();
    sb = NativeWorkspaceStore();
    a = WorkspaceRepository(store: sa, index: MemoryObjectIndex());
    b = WorkspaceRepository(store: sb, index: MemoryObjectIndex());
    await a.initialize(path: '${root.path}/a');
    await Directory('${root.path}/b').create();
    await File(
      '${root.path}/a/workspace.json',
    ).copy('${root.path}/b/workspace.json');
    await b.initialize(path: '${root.path}/b');
    ra = WorkspaceSyncReplica(
      a,
      canApply: () => true,
      isCurrent: () => current,
    );
    rb = WorkspaceSyncReplica(
      b,
      canApply: () => !drafts,
      isCurrent: () => current,
    );
    server = DriveSyncService(a.workspaceId);
    auth = FakeGoogleAuth();
    pa = provider(ra);
    pb = provider(rb);
  });
  tearDown(() async {
    server.beforeRecord = null;
    server.offline = false;
    current = true;
    await a.close();
    await b.close();
    server.client.close();
    await root.delete(recursive: true);
  });
  test(
    'native replicas synchronize exact source and new objects through Drive HTTP',
    () async {
      final id = await seed();
      expect(b.objects.single.id, id);
      expect(b.objects.single.body, 'original 😀\r\n');
      final next = await b.create(
        typeId: 'orbit.note',
        title: 'New from B',
        body: '**new**',
      );
      await engine(rb, pb).sync();
      await engine(ra, pa).sync();
      expect(a.objects.map((e) => e.id), contains(next.id));
      expect((await engine(ra, pa).sync()).upToDate, isTrue);
      final created = server.recordCreates;
      await engine(ra, provider(ra)).sync();
      expect(server.recordCreates, created);
    },
  );
  test(
    'offline divergent edits retain both exact sources and resolve explicitly',
    () async {
      final id = await seed();
      await a.save(a.objects.single.copyWith(body: 'device A edits'));
      await b.save(b.objects.single.copyWith(body: 'device B edits'));
      server.offline = true;
      await expectLater(engine(rb, pb).sync(), throwsA(anything));
      expect(b.objects.single.body, 'device B edits');
      server.offline = false;
      await engine(ra, pa).sync();
      final eb = engine(rb, pb);
      expect((await eb.sync()).conflicts, 1);
      expect(b.objects.single.body, 'device B edits');
      final recovery = await sb.listFiles();
      expect(
        recovery.where(
          (p) => p.startsWith('.orbit/sync-conflicts/') && p.endsWith('/local'),
        ),
        isNotEmpty,
      );
      expect(
        recovery.where(
          (p) =>
              p.startsWith('.orbit/sync-conflicts/') && p.endsWith('/remote'),
        ),
        isNotEmpty,
      );
      final state = await rb.createStateStore().load();
      final version =
          ((state!['conflicts'] as Map)[id]['remote'] as Map)['version']
              as String;
      expect((await eb.resolve(id, remoteVersion: version)).upToDate, isTrue);
      expect(b.objects.single.body, 'device A edits');
      await engine(ra, pa).sync();
      expect(a.objects.single.body, 'device A edits');
    },
  );
  test(
    'simultaneous publications create visible branches and resolution joins both',
    () async {
      final id = await seed();
      final base = (await pa.inspect(id))!;
      await a.save(a.objects.single.copyWith(body: 'concurrent A'));
      await b.save(b.objects.single.copyWith(body: 'concurrent B'));
      final ea = (await ra.inventory())[id]!, eb = (await rb.inventory())[id]!;
      var entered = 0;
      final gate = Completer<void>();
      server.beforeRecord = () async {
        if (++entered == 2) gate.complete();
        await gate.future;
      };
      final published = await Future.wait([
        pa.upload(
          ea,
          ra.read(ea),
          operationId: 'concurrent-a',
          expectedVersion: base.version,
        ),
        pb.upload(
          eb,
          rb.read(eb),
          operationId: 'concurrent-b',
          expectedVersion: base.version,
        ),
      ]);
      server.beforeRecord = null;
      final delta = await pa.fetchChanges(null);
      expect(
        delta.forks[id]!.map((e) => e.version).toSet(),
        published.map((e) => e.version).toSet(),
      );
      final engineA = engine(ra, pa);
      expect((await engineA.sync()).conflicts, 1);
      expect((await engineA.resolve(id)).upToDate, isTrue);
      await engine(rb, pb).sync();
      // B has a locally authored divergence, so it still requires its own review.
      expect(b.objects.single.body, 'concurrent B');
      final state = await rb.createStateStore().load();
      expect((state!['conflicts'] as Map).containsKey(id), isTrue);
      final revisionCount = server.revisions.length;
      expect(revisionCount, greaterThanOrEqualTo(5));
      expect((await pa.fetchChanges(null)).forks, isEmpty);
    },
  );
  for (final record in [false, true]) {
    test(
      'restart recovers lost ${record ? 'revision' : 'blob'} acknowledgement without duplicate publication',
      () async {
        final id = await seed();
        await a.save(
          a.objects.single.copyWith(body: 'restart after uncertain commit'),
        );
        if (record) {
          server.loseRecordReply = true;
        } else {
          server.loseBlobReply = true;
        }
        await expectLater(engine(ra, pa).sync(), throwsA(anything));
        server.offline = false;
        final creates = server.blobCreates;
        await a.close();
        await a.initialize(path: '${root.path}/a');
        ra = WorkspaceSyncReplica(a, canApply: () => true);
        pa = provider(ra);
        expect((await engine(ra, pa).sync()).upToDate, isTrue);
        expect(server.blobCreates, creates);
        await engine(rb, pb).sync();
        expect(
          b.objects.singleWhere((o) => o.id == id).body,
          'restart after uncertain commit',
        );
        final operations = server.revisions
            .map((f) => jsonDecode(utf8.decode(f.bytes))['operation'])
            .toList();
        expect(operations.toSet().length, operations.length);
      },
    );
  }
  test(
    'cloud source loss stops instead of deleting or resurrecting local knowledge',
    () async {
      await seed();
      final id = server.revisions.first.metadata['id'] as String;
      server.files.remove(id);
      await expectLater(
        engine(ra, pa).sync(),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(a.objects.single.body, 'original 😀\r\n');
    },
  );
  test(
    'changed immutable bytes and incomplete listing never apply over local work',
    () async {
      await seed();
      server.partialList = true;
      await expectLater(
        engine(
          rb,
          provider(
            rb,
            now: () => DateTime.now().add(const Duration(minutes: 16)),
          ),
        ).sync(),
        throwsA(isA<GoogleCloudError>()),
      );
      server.partialList = false;
      server.revisions.first.bytes = Uint8List.fromList(
        utf8.encode('tampered'),
      );
      await expectLater(
        engine(rb, pb).sync(),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(b.objects.single.body, 'original 😀\r\n');
    },
  );
  test(
    'native draft and cancelled-opening guards protect incoming applies',
    () async {
      await seed();
      await a.save(a.objects.single.copyWith(body: 'remote update'));
      await engine(ra, pa).sync();
      drafts = true;
      await expectLater(
        engine(rb, pb).sync(),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(b.objects.single.body, 'original 😀\r\n');
      drafts = false;
      current = false;
      await expectLater(
        engine(rb, pb).sync(),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(b.objects.single.body, 'original 😀\r\n');
    },
  );
  test('multi-chunk attachment transfer is verified and resumable', () async {
    final bytes = Uint8List.fromList(
      List.generate(2 * 1024 * 1024 + 37, (i) => i % 251),
    );
    final entry = SyncEntry(
      key: 'blob:Attachments/model/data.bin',
      path: 'Attachments/model/data.bin',
      hash: sha256.convert(bytes).toString(),
    );
    server.loseBlobReply = true;
    await expectLater(
      pa.upload(
        entry,
        Stream.value(bytes),
        operationId: 'large-attachment',
        expectedVersion: null,
      ),
      throwsA(anything),
    );
    final creates = server.blobCreates;
    final uploaded = await provider(ra).upload(
      entry,
      Stream.value(bytes),
      operationId: 'large-attachment',
      expectedVersion: null,
    );
    expect(server.blobCreates, creates);
    final downloaded = await pa.download(uploaded).expand((e) => e).toList();
    expect(sha256.convert(downloaded).toString(), entry.hash);
    expect(downloaded.length, bytes.length);
  });
  test(
    'Canvas, file ownership, folder moves and permanent deletions propagate without duplicate identities',
    () async {
      final id = await seed();
      final payload = Uint8List.fromList(List.generate(300000, (i) => i % 239));
      final file = await a.importAttachment(name: 'model.glb', bytes: payload);
      final board = await a.create(
        typeId: 'orbit.canvas',
        title: 'Game board',
        data: {
          'elements': [],
          'future': {'keep': true},
        },
      );
      await a.createFolder('Notes/University');
      await a.moveNote(id, 'Notes/University');
      await engine(ra, pa).sync();
      await engine(rb, pb).sync();
      expect(
        await b.readAttachment(file.properties['contentRef'] as String),
        payload,
      );
      expect(b.objects.singleWhere((o) => o.id == board.id).data['future'], {
        'keep': true,
      });
      expect((await rb.inventory())[id]!.path, startsWith('Notes/University/'));
      await a.trash(id);
      await engine(ra, pa).sync();
      await engine(rb, pb).sync();
      await a.deletePermanently(id);
      await engine(ra, pa).sync();
      await engine(rb, pb).sync();
      expect(b.objects.any((o) => o.id == id), isFalse);
      expect((await rb.inventory())[id]!.deleted, isTrue);
      expect(b.objects.map((o) => o.id).toSet().length, b.objects.length);
    },
  );
  test(
    'a local edit after conflict review rejects the stale resolution before publication',
    () async {
      final id = await seed();
      await a.save(a.objects.single.copyWith(body: 'cloud draft'));
      await b.save(b.objects.single.copyWith(body: 'reviewed local draft'));
      await engine(ra, pa).sync();
      final eb = engine(rb, pb);
      await eb.sync();
      final reviewedHash = (await rb.inventory())[id]!.hash;
      await b.save(
        b.objects.single.copyWith(body: 'new local draft after review'),
      );
      final creates = server.recordCreates;
      await expectLater(
        eb.resolve(id, expectedLocalHash: reviewedHash),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(server.recordCreates, creates);
      expect(b.objects.single.body, 'new local draft after review');
    },
  );
  test(
    'empty attachment sources publish and download exact zero bytes',
    () async {
      final entry = SyncEntry(
        key: 'blob:Attachments/empty/empty.txt',
        path: 'Attachments/empty/empty.txt',
        hash: sha256.convert([]).toString(),
      );
      final uploaded = await pa.upload(
        entry,
        Stream.value([]),
        operationId: 'empty-file',
        expectedVersion: null,
      );
      expect(
        await pb.download(uploaded).expand((chunk) => chunk).toList(),
        isEmpty,
      );
      expect(server.blobCreates, 1);
    },
  );
  test(
    'initial cloud branches are retained locally even when this device has no object',
    () async {
      final note = await a.create(
        typeId: 'orbit.note',
        title: 'Initial fork',
        body: 'root branch A',
      );
      final rawA = (await ra.inventory())[note.id]!;
      final bytesA = await ra.read(rawA).expand((c) => c).toList();
      final changed = utf8.encode(
        utf8.decode(bytesA).replaceFirst('root branch A', 'root branch B'),
      );
      final rawB = SyncEntry(
        key: rawA.key,
        path: rawA.path,
        hash: sha256.convert(changed).toString(),
      );
      var entered = 0;
      final gate = Completer<void>();
      server.beforeRecord = () async {
        if (++entered == 2) gate.complete();
        await gate.future;
      };
      await Future.wait([
        pa.upload(
          rawA,
          Stream.value(bytesA),
          operationId: 'initial-a',
          expectedVersion: null,
        ),
        pb.upload(
          rawB,
          Stream.value(changed),
          operationId: 'initial-b',
          expectedVersion: null,
        ),
      ]);
      server.beforeRecord = null;
      final eb = engine(rb, pb);
      expect((await eb.sync()).conflicts, 1);
      expect(b.objects, isEmpty);
      final retained = (await sb.listFiles())
          .where(
            (p) =>
                p.startsWith('.orbit/sync-conflicts/') && p.endsWith('/remote'),
          )
          .toList();
      expect(retained.length, 2);
      final remote = (await pb.fetchChanges(null)).forks[note.id]!.first;
      expect(
        (await eb.resolve(
          note.id,
          remoteVersion: remote.version,
          expectedLocalHash: 'absent',
        )).upToDate,
        isTrue,
      );
      expect(b.objects.single.id, note.id);
    },
  );
  test(
    'unchanged change-feed checks avoid history lists and media reads across restart',
    () async {
      await seed();
      final baseline = await pb.fetchChanges(null);
      final lists = server.historyLists, reads = server.mediaReads;
      final journalFile = File(
        '${root.path}/b/.orbit/device/sync/drive-uploads-v1.json',
      );
      final stamp = DateTime.utc(2020, 1, 1);
      await journalFile.setLastModified(stamp);
      pb = provider(rb);
      for (var i = 0; i < 8; i++) {
        final delta = await pb.fetchChanges(baseline.cursor);
        expect(delta.cursor, baseline.cursor);
        expect(
          delta.entries.map((e) => e.entry.key),
          contains(b.objects.single.id),
        );
      }
      expect(server.historyLists, lists);
      expect(server.mediaReads, reads);
      expect(server.changeLists, greaterThanOrEqualTo(8));
      expect(
        (await journalFile.lastModified()).toUtc(),
        stamp,
        reason:
            'An unchanged cloud must not rewrite the potentially large journal every five seconds.',
      );
    },
  );

  test(
    'paginated changes restore a complete snapshot and reach every new note',
    () async {
      await seed();
      for (var i = 0; i < 4; i++) {
        await a.create(typeId: 'orbit.note', title: 'New $i', body: 'page $i');
      }
      await engine(ra, pa).sync();
      server.changePageSize = 1;
      final lists = server.historyLists;
      final delta = await provider(rb).fetchChanges(null);
      expect(
        delta.entries.map((e) => e.entry.key),
        containsAll(a.objects.map((o) => o.id)),
      );
      expect(server.historyLists, lists);
      await engine(rb, provider(rb)).sync();
      expect(b.objects.length, 5);
      expect(
        b.objects.map((o) => o.id).toSet(),
        a.objects.map((o) => o.id).toSet(),
      );
    },
  );

  test(
    'failed later change page never checkpoints a partial inventory',
    () async {
      await seed();
      final store = rb.createDriveJournalStore();
      final before = await store.load();
      for (var i = 0; i < 3; i++) {
        await a.create(
          typeId: 'orbit.note',
          title: 'Interrupted $i',
          body: 'retained $i',
        );
      }
      await engine(ra, pa).sync();
      server.changePageSize = 1;
      server.failChangePage = int.parse(before!['changeFeed']['token']) + 1;
      await expectLater(
        pb.fetchChanges(null),
        throwsA(isA<GoogleCloudError>()),
      );
      final after = await rb.createDriveJournalStore().load();
      expect(jsonEncode(after), jsonEncode(before));
      expect(b.objects.length, 1);
      server.failChangePage = null;
      expect((await engine(rb, provider(rb)).sync()).upToDate, true);
      expect(b.objects.length, 4);
    },
  );

  for (final broken in ['repeated-page', 'missing-checkpoint']) {
    test('$broken cannot advance the durable change cursor', () async {
      await seed();
      final before = await rb.createDriveJournalStore().load();
      server.repeatChangePage = broken == 'repeated-page';
      server.incompleteChanges = broken == 'missing-checkpoint';
      await expectLater(
        pb.fetchChanges(null),
        throwsA(isA<GoogleCloudError>()),
      );
      expect(await rb.createDriveJournalStore().load(), before);
      server.repeatChangePage = server.incompleteChanges = false;
      expect((await engine(rb, provider(rb)).sync()).upToDate, true);
    });
  }

  test(
    'expired cursor rebuilds safely and still downloads pending remote edits',
    () async {
      await seed();
      await a.save(
        a.objects.single.copyWith(body: 'after cursor invalidation'),
      );
      await engine(ra, pa).sync();
      server.expireCursorOnce = true;
      final lists = server.historyLists;
      await engine(rb, pb).sync();
      expect(server.historyLists, greaterThan(lists));
      expect(b.objects.single.body, 'after cursor invalidation');
    },
  );

  test(
    'old upload journals upgrade without changing retained operations or bytes',
    () async {
      await seed();
      final store = rb.createDriveJournalStore();
      final old = (await store.load())!..remove('changeFeed');
      old['futureExtension'] = {'preserve': true};
      await store.save(old);
      final lists = server.historyLists;
      await provider(rb).fetchChanges(null);
      final upgraded = await rb.createDriveJournalStore().load();
      expect(upgraded!['futureExtension'], {'preserve': true});
      expect(upgraded['operations'], old['operations']);
      expect(upgraded['records'], old['records']);
      expect(upgraded['changeFeed']['ids'], isNotEmpty);
      expect(server.historyLists, lists + 1);
      expect(b.objects.single.body, 'original 😀\r\n');
    },
  );

  for (final change in ['moved', 'routing', 'trashed', 'content']) {
    test(
      'incremental $change tampering preserves the local source and checkpoint',
      () async {
        await seed();
        final before = await rb.createDriveJournalStore().load();
        final record = server.revisions.first;
        switch (change) {
          case 'moved':
            record.metadata['parents'] = ['another-vault'];
          case 'routing':
            (record.metadata['appProperties'] as Map)['orbitRole'] = 'other';
          case 'trashed':
            record.metadata['trashed'] = true;
          case 'content':
            record.bytes = Uint8List.fromList(utf8.encode('changed'));
        }
        await expectLater(
          engine(rb, pb).sync(),
          throwsA(isA<WorkspaceConflict>()),
        );
        expect(await rb.createDriveJournalStore().load(), before);
        expect(b.objects.single.body, 'original 😀\r\n');
      },
    );
  }

  test(
    'periodic full audit and backwards clocks retain integrity checks',
    () async {
      await seed();
      var clock = DateTime.now().add(const Duration(minutes: 16));
      final auditing = provider(rb, now: () => clock);
      var lists = server.historyLists;
      await auditing.fetchChanges(null);
      expect(server.historyLists, lists + 1);
      lists = server.historyLists;
      clock = clock.subtract(const Duration(days: 1));
      await auditing.fetchChanges(null);
      expect(server.historyLists, lists + 1);
    },
  );

  test(
    'interrupted middle attachment range resumes at the server-confirmed offset',
    () async {
      final bytes = Uint8List.fromList(
        List.generate(3 * 1024 * 1024 + 19, (i) => i % 251),
      );
      final entry = SyncEntry(
        key: 'blob:Attachments/large/data.bin',
        path: 'Attachments/large/data.bin',
        hash: sha256.convert(bytes).toString(),
      );
      server.interruptChunkOnce = true;
      await expectLater(
        pa.upload(
          entry,
          Stream.value(bytes),
          operationId: 'interrupted-range',
          expectedVersion: null,
        ),
        throwsA(anything),
      );
      expect(server.uploadedOffsets, [0]);
      final sessions = server.blobCreates;
      final uploaded = await provider(ra).upload(
        entry,
        Stream.value(bytes),
        operationId: 'interrupted-range',
        expectedVersion: null,
      );
      expect(server.blobCreates, sessions);
      expect(server.uploadedOffsets.first, 0);
      expect(
        server.uploadedOffsets[1],
        1024 * 1024,
        reason: 'Resume only at the server-confirmed retained byte offset.',
      );
      expect(
        server.uploadedOffsets.toSet().length,
        server.uploadedOffsets.length,
      );
      expect(
        sha256
            .convert(await pb.download(uploaded).expand((c) => c).toList())
            .toString(),
        entry.hash,
      );
    },
  );
  test(
    'publication racing the baseline listing is replayed from its earlier cursor',
    () async {
      await seed();
      final store = rb.createDriveJournalStore();
      final state = (await store.load())!..remove('changeFeed');
      await store.save(state);
      String? newId;
      server.afterHistoryList = () async {
        server.afterHistoryList = null;
        newId = (await a.create(
          typeId: 'orbit.note',
          title: 'Racing list',
          body: 'not in list reply',
        )).id;
        await engine(ra, pa).sync();
      };
      final initial = await pb.fetchChanges(null);
      expect(initial.entries.map((e) => e.entry.key), isNot(contains(newId)));
      final replayed = await provider(rb).fetchChanges(initial.cursor);
      expect(replayed.entries.map((e) => e.entry.key), contains(newId));
      await engine(rb, provider(rb)).sync();
      expect(b.objects.any((o) => o.id == newId), true);
    },
  );

  test(
    'account change during a feed page never checkpoints or applies it',
    () async {
      await seed();
      final before = await rb.createDriveJournalStore().load();
      final original = auth.current;
      server.beforeChangePage = () async {
        auth.current = const GoogleAccount(subject: 'other-account');
      };
      await expectLater(
        pb.fetchChanges(null),
        throwsA(isA<GoogleCloudError>()),
      );
      expect(await rb.createDriveJournalStore().load(), before);
      expect(b.objects.single.body, 'original 😀\r\n');
      auth.current = original;
      server.beforeChangePage = null;
      expect((await engine(rb, provider(rb)).sync()).upToDate, true);
    },
  );

  test(
    'new malformed graph cannot commit its change cursor before parent validation',
    () async {
      await seed();
      final before = await rb.createDriveJournalStore().load();
      final record = server.revisions.first;
      final body =
          jsonDecode(utf8.decode(record.bytes)) as Map<String, dynamic>;
      body['parents'] = ['absent-parent'];
      server.files['orphan-record'] = DriveTestFile({
        ...record.metadata,
        'id': 'orphan-record',
      }, utf8.encode(jsonEncode(body)));
      await expectLater(
        pb.fetchChanges(null),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(await rb.createDriveJournalStore().load(), before);
      expect(b.objects.single.body, 'original 😀\r\n');
    },
  );
  test(
    'Google can omit an empty changes array without making sync fail',
    () async {
      await seed();
      await pb.fetchChanges(null);
      server.omitEmptyChanges = true;
      expect((await engine(rb, pb).sync()).upToDate, true);
      expect(b.objects.single.body, 'original 😀\r\n');
    },
  );

  test(
    'thousand-revision history stays complete with one-record incremental reads',
    () async {
      await seed();
      final base = server.revisions.firstWhere(
        (f) =>
            jsonDecode(utf8.decode(f.bytes))['entry']['key'] ==
            b.objects.single.id,
      );
      final source =
          jsonDecode(utf8.decode(base.bytes)) as Map<String, dynamic>;
      var parent = base.metadata['id'] as String;
      void append(String id) {
        final value = {
          ...source,
          'operation': id,
          'parents': [parent],
        };
        final metadata = {
          ...base.metadata,
          'id': id,
          'appProperties': {
            ...base.metadata['appProperties'] as Map,
            'orbitOp': id,
          },
        };
        server.files[id] = DriveTestFile(
          metadata,
          utf8.encode(jsonEncode(value)),
        );
        parent = id;
      }

      for (var i = 0; i < 1000; i++) {
        append('stress-revision-$i');
      }
      server.changePageSize = 73;
      final snapshot = await pb.fetchChanges(null);
      expect(
        snapshot.entries
            .singleWhere((e) => e.entry.key == b.objects.single.id)
            .version,
        'stress-revision-999',
      );
      expect(snapshot.forks, isEmpty);
      final lists = server.historyLists, reads = server.mediaReads;
      append('stress-last');
      final delta = await provider(rb).fetchChanges(snapshot.cursor);
      expect(
        delta.entries
            .singleWhere((e) => e.entry.key == b.objects.single.id)
            .version,
        'stress-last',
      );
      expect(server.historyLists, lists);
      expect(server.mediaReads, reads + 1);
      final state = await rb.createDriveJournalStore().load();
      expect(
        (state!['changeFeed']['ids'] as List).length,
        server.revisions.length,
      );
    },
  );
}
