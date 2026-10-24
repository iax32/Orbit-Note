import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:orbit_note/domain/collaboration.dart';
import 'package:orbit_note/infrastructure/collaboration/server.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/collaboration_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/application/device_secret_store.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'canvas_shared_presence_test.dart' show CanvasSessions;

class _Secret implements DeviceSecretStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    value = text;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CanvasSessions f;
  setUp(() async {
    HttpOverrides.global = null;
    f = CanvasSessions();
    await f.open();
  });
  tearDown(() async {
    await f.close();
  });
  test(
    'shared rooms capture loose PDFs initially and publish newly added media',
    () async {
      final pdf = Uint8List.fromList([37, 80, 68, 70, 0, 255]);
      f.firstStore.files['lecture.PDF'] = pdf;
      final created = await f.first.createRoom(
        f.endpoint,
        'synthetic-owner',
        'Alice',
      );
      final room = created['room'] as String,
          token = created['token'] as String;
      final initial = await f.first.inspectRoom(f.endpoint, room, token);
      expect(initial['attachments']['lecture.PDF']['size'], pdf.length);
      final gallery = Uint8List.fromList([0, 128, 255]);
      f.firstStore.files['Courses/Week 1/diagram.PNG'] = gallery;
      // Existing connected room must also enumerate files outside Attachments/.
      await f.first.pump();
      await f.second.pump();
      expect(f.secondStore.files['lecture.PDF'], pdf);
      expect(f.secondStore.files['Courses/Week 1/diagram.PNG'], gallery);
    },
  );

  test(
    'failed outbox persistence blocks publication and explains local recovery',
    () async {
      final note = await f.firstRepo.create(
        typeId: 'orbit.note',
        title: 'Do not publish before checkpoint',
      );
      f.firstWorkspace.mergeRepositoryObjects();
      f.firstStore.failWrites = true;
      try {
        await f.first.pump();
      } finally {
        f.firstStore.failWrites = false;
      }
      expect(f.first.accessBlocked, true);
      expect(f.first.status, contains('recovery journal'));
      final state = await f.first.inspectRoom(f.endpoint, f.room, f.firstToken);
      expect(state['documents'], isNot(contains(note.id)));
      expect(f.firstWorkspace.find(note.id), isNotNull);
      await f.first.retryNow();
      expect(f.first.accessBlocked, false);
      await f.second.pump();
      expect(f.secondWorkspace.find(note.id), isNotNull);
    },
  );
  test(
    'unchanged heartbeats do not rewrite the durable shared outbox',
    () async {
      final path = f.firstStore.files.keys.singleWhere(
        (p) => p.startsWith('.orbit/device/shared/') && p.endsWith('.json'),
      );
      final before = f.firstStore.files[path];
      for (var i = 0; i < 4; i++) {
        await f.first.pump();
      }
      expect(identical(before, f.firstStore.files[path]), true);
      f.edit(f.firstWorkspace, 0, 14);
      await f.first.pump();
      expect(identical(before, f.firstStore.files[path]), false);
    },
  );
  test(
    'native interrupted shared download resumes from durable verified staging',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-shared-download-',
      );
      final store = NativeWorkspaceStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: root.path);
        final complete = Uint8List.fromList(
          List.generate(1024 * 1024 + 41, (i) => i % 251),
        );
        final hash = sha256.convert(complete).toString(),
            path = 'Attachments/$hash/asset.glb';
        Stream<List<int>> broken() async* {
          yield complete.sublist(0, 1024 * 1024);
          throw const HttpException('interrupted');
        }

        await expectLater(
          repo.applySharedAttachment(
            path,
            hash,
            broken(),
            size: complete.length,
            isCurrent: () => true,
            resumeRead: (_) => throw StateError('No stage yet'),
          ),
          throwsA(isA<HttpException>()),
        );
        expect(await repo.readAttachment(path), isNull);
        await repo.close();
        await repo.initialize(path: root.path);
        var resumed = -1;
        await repo.applySharedAttachment(
          path,
          hash,
          const Stream.empty(),
          size: complete.length,
          isCurrent: () => true,
          resumeRead: (offset) {
            resumed = offset;
            return Stream.value(complete.sublist(offset));
          },
        );
        expect(resumed, 1024 * 1024);
        expect(await repo.readAttachment(path), complete);
        expect(await store.listAttachmentStages(), isEmpty);
      } finally {
        await repo.close();
        if (!root.absolute.path.startsWith(
          Directory.systemTemp.absolute.path,
        )) {
          throw StateError('Unexpected test directory');
        }
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'unreadable shared recovery journal fails connection without publishing local changes',
    () async {
      f.first.dispose();
      final path = f.firstStore.files.keys.singleWhere(
        (p) => p.startsWith('.orbit/device/shared/') && p.endsWith('.json'),
      );
      f.firstStore.files[path] = Uint8List.fromList(utf8.encode('{broken'));
      f.first = CollaborationController(
        f.firstWorkspace,
        http.Client(),
        automaticPolling: false,
      );
      await expectLater(
        f.first.connect(f.endpoint, f.room, f.firstToken),
        throwsA(isA<Exception>()),
      );
      expect(f.first.connected, false);
      expect(f.firstWorkspace.find(f.id), isNotNull);
    },
  );
  test(
    'live rooms reject unaware clients and legacy snapshots remain readable',
    () async {
      final raw = http.Client();
      addTearDown(raw.close);
      final denied = await raw.get(
        f.endpoint.resolve('/v1/rooms/${f.room}/state'),
        headers: {'Authorization': 'Bearer ${f.firstToken}'},
      );
      expect(denied.statusCode, 400);
      final legacy = await f.first.request(
        f.endpoint,
        'synthetic-owner',
        'POST',
        '/v1/rooms',
        {'name': 'Legacy', 'backup': await f.firstRepo.exportBundle()},
      );
      final allowed = await raw.get(
        f.endpoint.resolve('/v1/rooms/${legacy['room']}/state'),
        headers: {'Authorization': 'Bearer ${legacy['token']}'},
      );
      expect(allowed.statusCode, 200);
      expect((jsonDecode(allowed.body) as Map)['capabilities'], isEmpty);
      expect(f.first.liveReplication, true);
    },
  );
  test(
    'host keeps an exact private journal checkpoint before live event records',
    () async {
      final original = await File(
        '${f.directory.path}/events.jsonl',
      ).readAsBytes();
      final note = await f.firstRepo.create(
        typeId: 'orbit.note',
        title: 'Checkpoint',
      );
      f.firstWorkspace.mergeRepositoryObjects();
      expect(f.first.pendingChanges, greaterThan(0));
      await f.first.pump();
      expect(f.first.conflicts, isEmpty);
      expect(
        await File(
          '${f.directory.path}/events.before-live-v2.jsonl',
        ).readAsBytes(),
        original,
      );
      await f.second.pump();
      expect(f.secondWorkspace.find(note.id), isNotNull);
      expect(f.first.pendingChanges, 0);
    },
  );
  test(
    'viewer cannot upload, publish or permanently delete shared knowledge',
    () async {
      final viewer = await f.first.invite('Reader', 'viewer');
      for (final action in ['put', 'remove', 'attachment']) {
        await expectLater(
          f.first.request(
            f.endpoint,
            viewer,
            'POST',
            '/v1/rooms/${f.room}/$action',
            {},
          ),
          throwsA(isA<CollaborationAccessDenied>()),
        );
      }
      final response = await f.transport.put(
        f.endpoint.resolve(
          '/v1/rooms/${f.room}/blob?hash=${'0' * 64}&offset=0&size=1',
        ),
        headers: {'Authorization': 'Bearer $viewer', 'X-Orbit-Client': '2'},
        body: [1],
      );
      expect(response.statusCode, 403);
      final state = await f.first.inspectRoom(f.endpoint, f.room, f.firstToken);
      expect((state['documents'] as Map).length, 1);
    },
  );
  test(
    'lost edit acknowledgement survives controller restart without duplicate mutation',
    () async {
      f.edit(f.firstWorkspace, 0, 67);
      f.transport.loseNextEdit = true;
      await f.first.pump();
      expect(f.first.retryAt, isNotNull);
      final before = await f.first.inspectRoom(
        f.endpoint,
        f.room,
        f.firstToken,
      );
      f.first.dispose();
      f.first = CollaborationController(
        f.firstWorkspace,
        http.Client(),
        automaticPolling: false,
      );
      await f.first.connect(f.endpoint, f.room, f.firstToken);
      await f.first.pump();
      await f.second.pump();
      final after = await f.first.inspectRoom(f.endpoint, f.room, f.firstToken);
      expect(
        after['documents'][f.id]['version'],
        before['documents'][f.id]['version'],
      );
      expect(f.first.conflicts, isEmpty);
      expect(f.secondWorkspace.find(f.id)!.data['elements'][0]['x'], 67);
    },
  );
  test(
    'automatic reconnect is opt in and manual disconnect suppresses it',
    () async {
      final secret = _Secret();
      f.first.dispose();
      f.first = CollaborationController(
        f.firstWorkspace,
        http.Client(),
        automaticPolling: false,
        secrets: (_) => secret,
      );
      await f.first.connect(f.endpoint, f.room, f.firstToken);
      await f.first.rememberConnection();
      f.first.dispose();
      f.first = CollaborationController(
        f.firstWorkspace,
        http.Client(),
        automaticPolling: false,
        secrets: (_) => secret,
      );
      await f.first.reconnectAutomatically();
      expect(f.first.connected, false);
      await f.first.reconnectSaved();
      await f.first.rememberConnection(autoReconnect: true);
      f.first.dispose();
      f.first = CollaborationController(
        f.firstWorkspace,
        http.Client(),
        automaticPolling: false,
        secrets: (_) => secret,
      );
      await f.first.reconnectAutomatically();
      expect(f.first.connected, true);
      f.first.disconnect();
      await f.first.reconnectAutomatically();
      expect(f.first.connected, false);
    },
  );
  test(
    'new notes tasks and boards arrive with the same identity and unknown data',
    () async {
      final ids = <String>[];
      for (final type in ['orbit.note', 'orbit.task', 'orbit.canvas']) {
        final object = await f.firstRepo.create(
          typeId: type,
          title: 'New shared $type',
          body: 'exact body 😀',
          data: {
            'future': {'preserve': true},
          },
        );
        ids.add(object.id);
      }
      f.firstWorkspace.mergeRepositoryObjects();
      await f.first.pump();
      await f.second.pump();
      expect(f.first.conflicts, isEmpty);
      expect(f.second.conflicts, isEmpty);
      for (final id in ids) {
        expect(f.secondWorkspace.find(id)?.body, 'exact body 😀');
        expect(f.secondWorkspace.find(id)?.data['future'], {'preserve': true});
      }
      final count = f.secondRepo.objects.length;
      await f.first.pump();
      await f.second.pump();
      expect(f.secondRepo.objects.length, count);
    },
  );
  test(
    'trash restore and permanent deletion propagate without resurrection',
    () async {
      await f.firstWorkspace.trash(f.id);
      await f.first.pump();
      await f.second.pump();
      expect(
        f.secondWorkspace.find(f.id)?.isDeleted,
        true,
        reason: 'remote trash',
      );
      expect(f.first.conflicts, isEmpty);
      expect(f.second.conflicts, isEmpty);
      await f.firstWorkspace.restore(f.id);
      await f.first.pump();
      await f.second.pump();
      expect(f.secondWorkspace.find(f.id)?.isDeleted, false);
      await f.firstWorkspace.trash(f.id);
      await f.first.pump();
      await f.second.pump();
      await f.firstWorkspace.deletePermanently(f.id);
      await f.first.pump();
      await f.second.pump();
      expect(f.first.conflicts, isEmpty);
      expect(f.second.conflicts, isEmpty);
      expect(f.secondWorkspace.find(f.id), null);
      expect((await f.secondRepo.sharedDeletions()).containsKey(f.id), true);
      await f.first.pump();
      await f.second.pump();
      expect(f.secondWorkspace.find(f.id), null);
    },
  );
  test(
    'new attachment bytes transfer before their owner and Canvas reference',
    () async {
      final bytes = Uint8List.fromList(
        List.generate(2 * 1024 * 1024 + 37, (i) => i % 251),
      );
      final file = await f.firstRepo.importAttachment(
        name: 'asset.glb',
        bytes: bytes,
      );
      f.firstWorkspace.mergeRepositoryObjects();
      f.edit(f.firstWorkspace, 0, 42);
      await f.first.pump();
      await f.second.pump();
      expect(f.first.conflicts, isEmpty);
      expect(f.second.conflicts, isEmpty);
      expect(
        f.secondWorkspace.find(file.id)?.properties['contentRef'],
        file.properties['contentRef'],
      );
      expect(
        await f.secondRepo.readAttachment(
          file.properties['contentRef'] as String,
        ),
        bytes,
      );
      expect(f.secondWorkspace.find(f.id)!.data['elements'][0]['x'], 42);
    },
  );
  test(
    'remote edit versus permanent local deletion preserves both for review',
    () async {
      f.edit(f.firstWorkspace, 0, 55);
      await f.first.pump();
      await f.secondWorkspace.trash(f.id);
      await f.secondWorkspace.deletePermanently(f.id);
      await f.second.pump();
      expect(f.second.conflicts, contains(f.id));
      expect(f.secondWorkspace.find(f.id), null);
      final state = await f.first.inspectRoom(f.endpoint, f.room, f.firstToken);
      expect(state['documents'][f.id]['removed'], isNot(true));
    },
  );
  test(
    'authenticated change wait wakes on publication and rejects revoked access',
    () async {
      final state = await f.first.inspectRoom(f.endpoint, f.room, f.firstToken);
      final waiting = f.second.request(
        f.endpoint,
        f.secondToken,
        'GET',
        '/v1/rooms/${f.room}/events?since=${state['sequence']}&epoch=${state['epoch']}&awareness=0',
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      f.edit(f.firstWorkspace, 0, 77);
      await f.first.pump();
      final event = await waiting.timeout(const Duration(seconds: 3));
      expect(event['sequence'], greaterThan(state['sequence'] as int));
      await f.first.request(
        f.endpoint,
        f.firstToken,
        'POST',
        '/v1/rooms/${f.room}/revoke',
        {'token': f.secondToken},
      );
      await expectLater(
        f.second.request(
          f.endpoint,
          f.secondToken,
          'GET',
          '/v1/rooms/${f.room}/events?since=0&awareness=0',
        ),
        throwsA(isA<CollaborationAccessDenied>()),
      );
    },
  );
  test(
    'saved common bases reconcile offline edits after reconnect without discarding either author',
    () async {
      final note = await f.firstRepo.create(
        typeId: 'orbit.note',
        title: 'Reconnect',
        body: 'alpha beta gamma 😀',
      );
      f.firstWorkspace.mergeRepositoryObjects();
      await f.first.pump();
      await f.second.pump();
      f.second.disconnect();
      f.secondWorkspace.edit(note.id, body: 'alpha beta gamma 😀 tail');
      await f.secondWorkspace.flush(note.id);
      f.firstWorkspace.edit(note.id, body: 'ALPHA beta gamma 😀');
      await f.first.pump();
      await f.second.connect(f.endpoint, f.room, f.secondToken);
      expect(f.second.conflicts, isEmpty);
      await f.second.pump();
      await f.first.pump();
      expect(f.firstWorkspace.find(note.id)?.body, 'ALPHA beta gamma 😀 tail');
      expect(f.secondWorkspace.find(note.id)?.body, 'ALPHA beta gamma 😀 tail');
      final journals = f.secondStore.files.entries.where(
        (e) => e.key.startsWith('.orbit/device/shared/'),
      );
      expect(journals, isNotEmpty);
      for (final entry in journals) {
        expect(utf8.decode(entry.value), isNot(contains(f.secondToken)));
      }
    },
  );
  test(
    'lost creation reply survives a client restart with the same object identity',
    () async {
      final note = await f.firstRepo.create(
        typeId: 'orbit.note',
        title: 'Lost create',
        body: 'first saved version',
      );
      f.firstWorkspace.mergeRepositoryObjects();
      f.transport.loseNextCreation = true;
      await f.first.pump();
      expect(f.first.retryAt, isNotNull);
      f.first.dispose();
      f.first = CollaborationController(
        f.firstWorkspace,
        http.Client(),
        automaticPolling: false,
        now: () => f.now,
      );
      await f.first.connect(f.endpoint, f.room, f.firstToken);
      await f.first.pump();
      await f.second.pump();
      expect(f.first.conflicts, isEmpty);
      expect(f.secondWorkspace.find(note.id)?.body, 'first saved version');
      final state = await f.first.inspectRoom(f.endpoint, f.room, f.firstToken);
      expect(
        (state['documents'] as Map).keys.where((id) => id == note.id).length,
        1,
      );
    },
  );
  test(
    'interrupted upload resumes its retained chunk and publishes only verified bytes',
    () async {
      final bytes = Uint8List.fromList(
        List.generate(3 * 1024 * 1024 + 19, (i) => i % 239),
      );
      final file = await f.firstRepo.importAttachment(
        name: 'resumed.bin',
        bytes: bytes,
      );
      f.firstWorkspace.mergeRepositoryObjects();
      f.transport.loseNextChunk = true;
      await f.first.pump();
      expect(f.first.retryAt, isNotNull);
      expect(f.transport.chunkOffsets, [0]);
      await f.first.retryNow();
      await f.second.pump();
      expect(f.transport.chunkOffsets, [
        0,
        1024 * 1024,
        2 * 1024 * 1024,
        3 * 1024 * 1024,
      ]);
      expect(
        await f.secondRepo.readAttachment(
          file.properties['contentRef'] as String,
        ),
        bytes,
      );
    },
  );
  test(
    'shared text ranges are grant-bound, UTF-16 safe and invalidated by source changes',
    () async {
      final note = await f.firstRepo.create(
        typeId: 'orbit.note',
        title: 'Presence',
        body: 'one 😀 two',
      );
      f.firstWorkspace.mergeRepositoryObjects();
      await f.first.pump();
      await f.second.pump();
      f.first.textSelection(
        note.id,
        'one 😀 two',
        const TextSelection(baseOffset: 4, extentOffset: 6),
      );
      await f.first.pump();
      await f.second.pump();
      final peer = f.second.peers.singleWhere((p) => p['objectId'] == note.id);
      expect(peer['name'], 'Alice');
      expect(peer['textBase'], 4);
      expect(peer['textExtent'], 6);
      final hash = sha256.convert(utf8.encode('one 😀 two')).toString();
      await expectLater(
        f.first.request(
          f.endpoint,
          f.firstToken,
          'POST',
          '/v1/rooms/${f.room}/presence',
          {
            'session': f.first.session,
            'objectId': note.id,
            'space': 'note',
            'x': 0,
            'y': 0,
            'textHash': hash,
            'textBase': 5,
            'textExtent': 6,
          },
        ),
        throwsA(anything),
      );
      await f.first.request(
        f.endpoint,
        f.firstToken,
        'POST',
        '/v1/rooms/${f.room}/presence',
        {
          'session': f.first.session,
          'objectId': note.id,
          'space': 'note',
          'x': 0,
          'y': 0,
          'textHash': '0' * 64,
          'textBase': 4,
          'textExtent': 6,
        },
      );
      final state = await f.second.inspectRoom(
        f.endpoint,
        f.room,
        f.secondToken,
      );
      final stale = (state['peers'] as List).singleWhere(
        (p) => p['objectId'] == note.id,
      );
      expect(stale['textStale'], true);
      expect(stale['textBase'], null);
    },
  );
  test(
    'server restart retains new owners, attachment references and permanent deletions',
    () async {
      final note = await f.firstRepo.create(
        typeId: 'orbit.note',
        title: 'Restarted',
        body: 'durable owner',
      );
      final file = await f.firstRepo.importAttachment(
        name: 'durable.txt',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      f.firstWorkspace.mergeRepositoryObjects();
      await f.first.pump();
      await f.second.pump();
      await f.firstWorkspace.trash(f.id);
      await f.first.pump();
      await f.second.pump();
      await f.firstWorkspace.deletePermanently(f.id);
      await f.first.pump();
      await f.second.pump();
      final port = f.endpoint.port;
      await f.server.close();
      f.server = CollaborationServer(f.directory, 'synthetic-owner');
      await f.server.start(port: port);
      final state = await f.second.inspectRoom(
        f.endpoint,
        f.room,
        f.secondToken,
      );
      expect(state['documents'][note.id]['snapshot']['body'], 'durable owner');
      expect(state['documents'][f.id]['removed'], true);
      expect(state['attachments'][file.properties['contentRef']]['size'], 3);
      await f.first.pump();
      await f.second.pump();
      expect(f.secondWorkspace.find(f.id), null);
    },
  );
  test(
    'multiple independent character edits merge without swallowing an edit between them',
    () async {
      final note = await f.firstRepo.create(
        typeId: 'orbit.note',
        title: 'Coauthor',
        body: 'alpha beta gamma delta',
      );
      f.firstWorkspace.mergeRepositoryObjects();
      await f.first.pump();
      await f.second.pump();
      final base = collaborationSnapshot(f.firstWorkspace.find(note.id)!);
      final local = collaborationSnapshot(
        f.firstWorkspace
            .find(note.id)!
            .copyWith(body: 'ALPHA beta gamma DELTA'),
      );
      final remote = collaborationSnapshot(
        f.firstWorkspace
            .find(note.id)!
            .copyWith(body: 'alpha BETA gamma delta'),
      );
      expect(
        mergeCollaboration(base, local, remote)['body'],
        'ALPHA BETA gamma DELTA',
      );
      f.firstWorkspace.edit(note.id, body: 'ALPHA beta gamma DELTA');
      f.secondWorkspace.edit(note.id, body: 'alpha BETA gamma delta');
      await f.first.pump();
      await f.second.pump();
      await f.first.pump();
      expect(f.firstWorkspace.find(note.id)?.body, 'ALPHA BETA gamma DELTA');
      expect(f.secondWorkspace.find(note.id)?.body, 'ALPHA BETA gamma DELTA');
    },
  );
}
