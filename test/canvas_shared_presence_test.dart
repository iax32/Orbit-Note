import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:orbit_note/app/collaboration_controller.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/collaboration/server.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

class SharedTransport extends http.BaseClient {
  final inner = http.Client();
  bool loseNextEdit = false;
  bool loseNextCreation = false, loseNextChunk = false;
  final chunkOffsets = <int>[];
  final presence = <Map>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request && request.url.path.endsWith('/presence')) {
      presence.add(jsonDecode(request.body) as Map);
    }
    final response = await inner.send(request);
    if (request.method == 'PUT' && request.url.path.endsWith('/blob')) {
      chunkOffsets.add(int.parse(request.url.queryParameters['offset']!));
      if (loseNextChunk) {
        loseNextChunk = false;
        await response.stream.drain<void>();
        throw http.ClientException('Synthetic interrupted chunk');
      }
    }
    if (loseNextCreation && request.url.path.endsWith('/put')) {
      loseNextCreation = false;
      await response.stream.drain<void>();
      throw http.ClientException('Synthetic lost creation acknowledgement');
    }
    if (loseNextEdit && request.url.path.endsWith('/edit')) {
      loseNextEdit = false;
      await response.stream.drain<void>();
      throw http.ClientException('Synthetic lost acknowledgement');
    }
    return response;
  }

  @override
  void close() => inner.close();
}

class CanvasSessions {
  late MemoryStore firstStore, secondStore;
  late WorkspaceRepository firstRepo, secondRepo;
  late ProviderContainer firstContainer, secondContainer;
  late WorkspaceController firstWorkspace, secondWorkspace;
  late CollaborationController first, second;
  final transport = SharedTransport();
  late CollaborationServer server;
  late Directory directory;
  late Uri endpoint;
  late String id, room, firstToken, secondToken;
  late Map<String, dynamic> initial;
  DateTime now = DateTime.now();
  List<String> ids = List.generate(
    64,
    (i) => '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
  );
  Future<void> open() async {
    HttpOverrides.global = null;
    final store = firstStore = MemoryStore();
    firstRepo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    await firstRepo.initialize();
    initial = {
      'schemaVersion': 1,
      'future': {'retained': true},
      'elements': [
        for (var i = 0; i < ids.length; i++)
          {
            'id': ids[i],
            'type': 'rectangle',
            'x': i * 100,
            'y': 0,
            'width': 80,
            'height': 80,
          },
      ],
    };
    id = (await firstRepo.create(
      typeId: 'orbit.canvas',
      title: 'Shared board',
      data: initial,
    )).id;
    secondRepo = WorkspaceRepository(
      store: secondStore = (MemoryStore()..files.addAll(store.files)),
      index: MemoryObjectIndex(),
    );
    firstContainer = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(firstRepo)],
    );
    secondContainer = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(secondRepo)],
    );
    firstWorkspace = firstContainer.read(workspaceProvider.notifier);
    secondWorkspace = secondContainer.read(workspaceProvider.notifier);
    while (firstWorkspace.loading || secondWorkspace.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    firstWorkspace.pausePdfIndex(true);
    secondWorkspace.pausePdfIndex(true);
    firstWorkspace.cancelAllTimers();
    secondWorkspace.cancelAllTimers();
    first = CollaborationController(
      firstWorkspace,
      transport,
      automaticPolling: false,
      now: () => now,
    );
    second = CollaborationController(
      secondWorkspace,
      http.Client(),
      automaticPolling: false,
      now: () => now,
    );
    directory = await Directory.systemTemp.createTemp('orbit-canvas-presence-');
    server = CollaborationServer(directory, 'synthetic-owner');
    endpoint = Uri.parse('http://127.0.0.1:${await server.start(port: 0)}');
    final created = await first.createRoom(
      endpoint,
      'synthetic-owner',
      'Alice',
    );
    room = created['room'] as String;
    firstToken = created['token'] as String;
    await first.connect(endpoint, room, firstToken);
    secondToken = await first.invite('Bob', 'editor');
    await second.connect(endpoint, room, secondToken);
  }

  void edit(WorkspaceController workspace, int index, double x) {
    final data = workspace.find(id)!.data;
    workspace.edit(
      id,
      data: {
        ...data,
        'elements': [
          for (final element in data['elements'] as List)
            if (element['id'] == ids[index])
              {...element as Map<String, dynamic>, 'x': x}
            else
              element,
        ],
      },
    );
  }

  Future<void> close() async {
    first.dispose();
    second.dispose();
    firstWorkspace.cancelAllTimers();
    secondWorkspace.cancelAllTimers();
    firstContainer.dispose();
    secondContainer.dispose();
    await firstRepo.close();
    await secondRepo.close();
    await server.close();
    if (!directory.absolute.path.startsWith(
      Directory.systemTemp.absolute.path,
    )) {
      throw StateError('Unexpected test directory');
    }
    await directory.delete(recursive: true);
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
  tearDown(() async => f.close());

  test(
    'switching shared rooms uses a fresh presence session without access denial',
    () async {
      f.first.cursor(f.id, 1, 2, space: 'canvas');
      await f.first.pump();
      final previous = f.first.session;
      final created = await f.first.createRoom(
        f.endpoint,
        'synthetic-owner',
        'Alice',
      );
      await f.first.connect(
        f.endpoint,
        created['room'] as String,
        created['token'] as String,
      );
      f.now = f.now.add(const Duration(seconds: 1));
      f.first.cursor(f.id, 3, 4, space: 'canvas');
      await f.first.pump();
      expect(f.first.accessBlocked, isFalse);
      expect(f.first.session, isNot(previous));
      expect(f.firstWorkspace.find(f.id)!.data, f.initial);
    },
  );
  test(
    'selected placements appear, remain ephemeral and clear when leaving',
    () async {
      f.first.cursor(f.id, 12, 24, space: 'canvas');
      f.first.selectCanvas(f.id, [f.ids[0], 'missing', f.ids[0]]);
      await f.first.pump();
      await f.second.pump();
      final peer = f.second.peers.singleWhere(
        (p) => p['session'] == f.first.session,
      );
      expect(peer['name'], 'Alice');
      expect(peer['selection'], [f.ids[0]]);
      expect(f.firstWorkspace.find(f.id)!.data, f.initial);
      f.first.clearCursor(f.id);
      await f.first.pump();
      await f.second.pump();
      expect(
        f.second.peers.where((p) => p['session'] == f.first.session),
        isEmpty,
      );
      final count = f.transport.presence.length;
      await f.first.pump();
      expect(f.transport.presence, hasLength(count));
    },
  );
  test(
    '64 UUID selections fit the bounded request and use the injected clock',
    () async {
      f.first.cursor(f.id, 12, 24, space: 'canvas');
      f.first.selectCanvas(f.id, f.ids);
      await f.first.pump();
      await f.second.pump();
      expect(f.second.peers.single['selection'], f.ids);
      final count = f.transport.presence.length;
      f.now = f.now.add(const Duration(milliseconds: 399));
      await f.first.pump();
      expect(f.transport.presence, hasLength(count));
      f.now = f.now.add(const Duration(milliseconds: 1));
      await f.first.pump();
      expect(f.transport.presence, hasLength(count + 1));
    },
  );
  test('another grant cannot clear or impersonate an active session', () async {
    f.first.cursor(f.id, 1, 2, space: 'canvas');
    await f.first.pump();
    await expectLater(
      f.second.request(
        f.endpoint,
        f.secondToken,
        'POST',
        '/v1/rooms/${f.room}/presence',
        {'session': f.first.session, 'active': false},
      ),
      throwsA(isA<CollaborationAccessDenied>()),
    );
    await f.second.pump();
    expect(f.second.peers.single['name'], 'Alice');
  });
  test(
    'old presence payloads work and oversized selection is rejected',
    () async {
      final payload = {
        'session': 'legacy-session',
        'objectId': f.id,
        'x': 1,
        'y': 2,
        'space': 'canvas',
      };
      await f.first.request(
        f.endpoint,
        f.firstToken,
        'POST',
        '/v1/rooms/${f.room}/presence',
        payload,
      );
      await f.second.pump();
      expect(f.second.peers.single['selection'], isEmpty);
      await expectLater(
        f.first.request(
          f.endpoint,
          f.firstToken,
          'POST',
          '/v1/rooms/${f.room}/presence',
          {
            ...payload,
            'selection': [...f.ids, 'overflow'],
          },
        ),
        throwsStateError,
      );
    },
  );
  test(
    'presence cache tracks deletion without affecting canonical placement data',
    () async {
      f.first.cursor(f.id, 1, 2, space: 'canvas');
      f.first.selectCanvas(f.id, [f.ids[0]]);
      await f.first.pump();
      final data = f.firstWorkspace.find(f.id)!.data;
      f.firstWorkspace.edit(
        f.id,
        data: {
          ...data,
          'elements': (data['elements'] as List).skip(1).toList(),
        },
      );
      f.now = f.now.add(const Duration(seconds: 1));
      await f.first.pump();
      await f.second.pump();
      expect(f.second.peers.single['selection'], isEmpty);
      expect(
        (f.secondWorkspace.find(f.id)!.data['elements'] as List),
        hasLength(63),
      );
    },
  );
  test(
    'lost Canvas acknowledgement and later independent edits converge once',
    () async {
      f.transport.loseNextEdit = true;
      f.edit(f.firstWorkspace, 0, 30);
      await f.first.pump();
      expect(f.first.pendingChanges, 1);
      f.edit(f.secondWorkspace, 1, 140);
      await f.second.pump();
      f.edit(f.firstWorkspace, 2, 250);
      await f.first.retryNow();
      expect(f.first.pendingChanges, 1);
      await f.first.pump();
      await f.second.pump();
      final first = f.firstWorkspace.find(f.id)!,
          second = f.secondWorkspace.find(f.id)!;
      expect(first.data, second.data);
      expect(first.data['future'], {'retained': true});
      final elements = first.data['elements'] as List;
      expect(elements.map((e) => e['id']).toSet(), hasLength(64));
      expect(
        [elements[0]['x'], elements[1]['x'], elements[2]['x']],
        [30, 140, 250],
      );
      expect(f.first.conflicts, isEmpty);
      expect(f.second.conflicts, isEmpty);
      final state = await f.first.inspectRoom(f.endpoint, f.room, f.firstToken);
      expect((state['documents'] as Map)[f.id]['version'], 4);
      expect(f.first.pendingChanges, 0);
      expect(f.second.pendingChanges, 0);
    },
  );
}
