import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/application/sync/sync_engine.dart';
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
  GoogleDriveSyncProvider provider(WorkspaceSyncReplica replica) =>
      GoogleDriveSyncProvider(
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
        engine(rb, pb).sync(),
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
}
