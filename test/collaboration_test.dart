import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:orbit_note/app/collaboration_controller.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/backup_bundle.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/collaboration.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/workspace/collaboration_settings.dart';
import 'package:orbit_note/infrastructure/collaboration/server.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryStore store;
  late WorkspaceRepository repository;
  setUp(() async {
    HttpOverrides.global = null;
    store = MemoryStore();
    repository = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    await repository.initialize();
  });
  tearDown(() => repository.close());
  test(
    'independent UTF-16 text edits combine and overlapping edits refuse',
    () async {
      final note = await repository.create(
        typeId: 'orbit.note',
        title: 'Shared',
        body: '😀 hello world',
      );
      final base = collaborationSnapshot(note);
      final merged = mergeCollaboration(
        base,
        collaborationSnapshot(note.copyWith(body: '😀 hello world!')),
        collaborationSnapshot(note.copyWith(body: '😀 Hi world')),
      );
      expect(collaborationObject(merged).body, '😀 Hi world!');
      expect(
        () => mergeCollaboration(
          base,
          collaborationSnapshot(note.copyWith(body: '😀 Hi world')),
          collaborationSnapshot(note.copyWith(body: '😀 Hey world')),
        ),
        throwsA(isA<CollaborationConflict>()),
      );
      expect(
        collaborationObject(
          mergeCollaboration(
            base,
            collaborationSnapshot(note.copyWith(body: '😀 Ahello world')),
            collaborationSnapshot(note.copyWith(body: '😀 Bhello world')),
          ),
        ).body,
        '😀 BAhello world',
      );
      expect(
        () => mergeCollaboration(base, {
          ...base,
          'documentExtra': {'future': true},
        }, base),
        throwsA(isA<CollaborationConflict>()),
      );
    },
  );
  test(
    'Canvas independent placements, fields and delete versus edit retain identity',
    () async {
      final canvas = await repository.create(
        typeId: 'orbit.canvas',
        title: 'Shared',
        data: {
          'schemaVersion': 1,
          'custom': 'retained',
          'elements': [
            {'id': 'a', 'type': 'text', 'text': 'A', 'x': 0, 'y': 0},
            {'id': 'b', 'type': 'text', 'text': 'B', 'x': 0, 'y': 0},
          ],
        },
      );
      final base = collaborationSnapshot(canvas);
      final a = collaborationSnapshot(
        canvas.copyWith(
          data: {
            ...canvas.data,
            'elements': [
              {'id': 'a', 'type': 'text', 'text': 'A', 'x': 20, 'y': 0},
              canvas.data['elements'][1],
            ],
          },
        ),
      );
      final b = collaborationSnapshot(
        canvas.copyWith(
          data: {
            ...canvas.data,
            'elements': [
              canvas.data['elements'][0],
              {'id': 'b', 'type': 'text', 'text': 'B', 'x': 0, 'y': 30},
            ],
          },
        ),
      );
      final merged = collaborationObject(mergeCollaboration(base, a, b));
      expect(merged.id, canvas.id);
      expect(merged.data['custom'], 'retained');
      expect(merged.data['elements'][0]['x'], 20);
      expect(merged.data['elements'][1]['y'], 30);
      final deletion = collaborationSnapshot(
        canvas.copyWith(
          data: {
            ...canvas.data,
            'elements': [canvas.data['elements'][1]],
          },
        ),
      );
      expect(
        () => mergeCollaboration(base, a, deletion),
        throwsA(isA<CollaborationConflict>()),
      );
    },
  );
  test(
    'transport refuses insecure remote endpoints and embedded credentials',
    () {
      expect(
        () => CollaborationController.validateEndpoint('http://example.com'),
        throwsFormatException,
      );
      expect(
        () => CollaborationController.validateEndpoint(
          'https://user:pass@example.com',
        ),
        throwsFormatException,
      );
      expect(
        CollaborationController.validateEndpoint('http://127.0.0.1:47831').port,
        47831,
      );
    },
  );
  test(
    'failed journal write stops further mutations until a clean restart',
    () async {
      final note = await repository.create(
        typeId: 'orbit.note',
        title: 'Shared',
        body: 'Before',
      );
      final temp = await Directory.systemTemp.createTemp(
        'orbit-collaboration-storage-',
      );
      var server = CollaborationServer(temp, 'owner-key');
      var endpoint = Uri.parse(
        'http://127.0.0.1:${await server.start(port: 0)}',
      );
      final client = http.Client();
      addTearDown(() async {
        client.close();
        await server.close();
        await temp.delete(recursive: true);
      });
      Future<http.Response> post(String path, String token, Map body) =>
          client.post(
            Uri.parse('$endpoint$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );
      final created =
          jsonDecode(
                (await post('/v1/rooms', 'owner-key', {
                  'name': 'Alice',
                  'backup': await repository.exportBundle(),
                })).body,
              )
              as Map;
      final path = '/v1/rooms/${created['room']}/edit',
          token = created['token'] as String;
      final journal = File('${temp.path}/events.jsonl');
      final retained = await journal.rename('${temp.path}/retained.jsonl');
      final obstruction = await Directory(journal.path).create();
      final proposal = {
        'id': note.id,
        'version': 1,
        'operation': 'storage-test',
        'snapshot': collaborationSnapshot(note.copyWith(body: 'After')),
      };
      expect((await post(path, token, proposal)).statusCode, 503);
      await obstruction.delete();
      await retained.rename(journal.path);
      expect((await post(path, token, proposal)).statusCode, 503);
      await server.close();
      server = CollaborationServer(temp, 'owner-key');
      endpoint = Uri.parse('http://127.0.0.1:${await server.start(port: 0)}');
      final accepted = await post(path, token, proposal);
      expect(accepted.statusCode, 200);
      expect(jsonDecode(accepted.body)['snapshot']['body'], 'After');
      expect(jsonDecode(accepted.body)['version'], 2);
    },
  );
  test(
    'real server: two clients, names, roles, merge, replay, revoke and restart',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'orbit-collaboration-test-',
      );
      var server = CollaborationServer(temp, 'owner-key');
      final port = await server.start(port: 0);
      final client = http.Client();
      addTearDown(() async {
        client.close();
        await server.close();
        await temp.delete(recursive: true);
      });
      var endpoint = Uri.parse('http://127.0.0.1:$port');
      Future<http.Response> send(
        String method,
        String path,
        String token, [
        Map? body,
      ]) async {
        final request = http.Request(method, Uri.parse('$endpoint$path'));
        request.headers['Authorization'] = 'Bearer $token';
        if (body != null) {
          request.headers['Content-Type'] = 'application/json';
          request.body = jsonEncode(body);
        }
        return http.Response.fromStream(await client.send(request));
      }

      final note = await repository.create(
        typeId: 'orbit.note',
        title: 'Shared',
        body: 'hello world',
      );
      final created =
          jsonDecode(
                (await send('POST', '/v1/rooms', 'owner-key', {
                  'name': 'Alice',
                  'backup': await repository.exportBundle(),
                })).body,
              )
              as Map;
      final room = created['room'], owner = created['token'] as String;
      final path = '/v1/rooms/$room';
      final editor =
          jsonDecode(
                (await send('POST', '$path/invite', owner, {
                  'name': 'Bob',
                  'role': 'editor',
                })).body,
              )['token']
              as String;
      final viewer =
          jsonDecode(
                (await send('POST', '$path/invite', owner, {
                  'name': 'Viewer',
                  'role': 'viewer',
                })).body,
              )['token']
              as String;
      final initial =
          jsonDecode((await send('GET', '$path/state', editor)).body) as Map;
      expect(initial['workspaceId'], repository.workspaceId);
      final base = Map<String, dynamic>.from(
        initial['documents'][note.id]['snapshot'] as Map,
      );
      final first = {
        'id': note.id,
        'version': 1,
        'operation': 'alice-1',
        'snapshot': collaborationSnapshot(note.copyWith(body: 'hello world!')),
      };
      expect((await send('POST', '$path/edit', viewer, first)).statusCode, 403);
      expect((await send('GET', '$path/state', 'bad')).statusCode, 403);
      expect((await send('POST', '$path/edit', owner, first)).statusCode, 200);
      final second = {
        'id': note.id,
        'version': 1,
        'operation': 'bob-1',
        'snapshot': collaborationSnapshot(note.copyWith(body: 'Hi world')),
      };
      final merged =
          jsonDecode((await send('POST', '$path/edit', editor, second)).body)
              as Map;
      expect(merged['snapshot']['body'], 'Hi world!');
      final duplicate =
          jsonDecode((await send('POST', '$path/edit', editor, second)).body)
              as Map;
      expect(duplicate['version'], merged['version']);
      expect(
        (await send('POST', '$path/edit', editor, {
          ...second,
          'snapshot': {...base, 'body': 'Overwrite'},
        })).statusCode,
        409,
      );
      final delta =
          jsonDecode(
                (await send(
                  'GET',
                  '$path/state?since=${merged['version']}',
                  owner,
                )).body,
              )
              as Map;
      expect(delta['documents'], isEmpty);
      expect(
        (await send('POST', '$path/edit', owner, {
          'id': note.id,
          'version': 1,
          'operation': 'alice-2',
          'snapshot': {...base, 'body': 'Hey world'},
        })).statusCode,
        409,
      );
      expect(
        (await send('POST', '$path/presence', editor, {
          'session': 'bob-device',
          'objectId': note.id,
          'x': .2,
          'y': .4,
          'name': 'Spoofed',
          'space': 'note',
        })).statusCode,
        200,
      );
      final state =
          jsonDecode((await send('GET', '$path/state', owner)).body) as Map;
      expect(state['peers'][0]['name'], 'Bob');
      expect(
        (await send('POST', '$path/presence', owner, {
          'session': 'bob-device',
          'objectId': note.id,
          'x': .3,
          'y': .4,
        })).statusCode,
        403,
      );
      final backup = BackupBundle.parse(
        (await send('GET', '$path/backup', editor)).body,
      );
      expect(
        utf8.decode(
          backup.files.values.firstWhere(
            (v) => utf8.decode(v, allowMalformed: true).contains('Hi world!'),
          ),
        ),
        contains('Hi world!'),
      );
      await send('POST', '$path/revoke', owner, {'token': editor});
      expect((await send('GET', '$path/state', editor)).statusCode, 403);
      await server.close();
      // Simulate a torn unacknowledged record after all durably accepted edits.
      await File(
        '${temp.path}/events.jsonl',
      ).writeAsString('{"kind":', mode: FileMode.append, flush: true);
      server = CollaborationServer(temp, 'owner-key');
      endpoint = Uri.parse('http://127.0.0.1:${await server.start(port: 0)}');
      final reopened =
          jsonDecode((await send('GET', '$path/state', owner)).body) as Map;
      expect(reopened['documents'][note.id]['snapshot']['body'], 'Hi world!');
      expect(reopened['peers'], isEmpty);
      expect((await send('POST', '$path/edit', owner, first)).statusCode, 200);
      expect((await send('GET', '$path/state', editor)).statusCode, 403);
    },
  );
  test(
    'two application sessions save merged remote edits through repository history',
    () async {
      final note = await repository.create(
        typeId: 'orbit.note',
        title: 'Shared',
        body: 'hello world',
      );
      final otherStore = MemoryStore()..files.addAll(store.files);
      final otherRepository = WorkspaceRepository(
        store: otherStore,
        index: MemoryObjectIndex(),
      );
      Future<(ProviderContainer, WorkspaceController)> controllerFor(
        WorkspaceRepository repo,
      ) async {
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        final controller = container.read(workspaceProvider.notifier);
        await controller.initialize();
        return (container, controller);
      }

      final (oneContainer, oneWorkspace) = await controllerFor(repository);
      final (twoContainer, twoWorkspace) = await controllerFor(otherRepository);
      final first = CollaborationController(oneWorkspace, http.Client()),
          second = CollaborationController(twoWorkspace, http.Client());
      var permissionChanges = 0;
      first.viewerChanges.addListener(() => permissionChanges++);
      final temp = await Directory.systemTemp.createTemp(
        'orbit-collaboration-session-',
      );
      final server = CollaborationServer(temp, 'owner-key');
      final endpoint = Uri.parse(
        'http://127.0.0.1:${await server.start(port: 0)}',
      );
      addTearDown(() async {
        first.dispose();
        second.dispose();
        oneContainer.dispose();
        twoContainer.dispose();
        await otherRepository.close();
        await server.close();
        await temp.delete(recursive: true);
      });
      final room = await first.createRoom(endpoint, 'owner-key', 'Alice');
      await first.connect(
        endpoint,
        room['room'] as String,
        room['token'] as String,
      );
      final invite = await first.invite('Bob', 'editor');
      await second.connect(endpoint, room['room'] as String, invite);
      oneWorkspace.edit(note.id, body: 'hello world!');
      twoWorkspace.edit(note.id, body: 'Hi world');
      await first.pump();
      await second.pump();
      await first.pump();
      expect(
        permissionChanges,
        0,
        reason: 'Presence and edit polls retain the note editor subtree.',
      );
      expect(oneWorkspace.find(note.id)!.body, 'Hi world!');
      expect(twoWorkspace.find(note.id)!.body, 'Hi world!');
      expect(first.conflicts, isEmpty);
      expect(second.conflicts, isEmpty);
      expect(
        repository.objects.firstWhere((v) => v.id == note.id).body,
        'Hi world!',
      );
      expect(
        otherRepository.objects.firstWhere((v) => v.id == note.id).body,
        'Hi world!',
      );
      await oneWorkspace.initialize();
      await first.pump();
      expect(
        first.connected,
        isFalse,
        reason: 'Reopening the same UUID invalidates the old session.',
      );
      first.disconnect();
      second.disconnect();
      await otherRepository.initialize();
      expect(
        otherRepository.objects.firstWhere((v) => v.id == note.id).body,
        'Hi world!',
      );
    },
  );
  test(
    'invalid complete journal records refuse startup and release the lock',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'orbit-collaboration-journal-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final journal = File('${temp.path}/events.jsonl');
      await journal.writeAsString('{"kind":"future","room":"unknown"}\n');
      final invalid = CollaborationServer(temp, 'owner-key');
      await expectLater(invalid.start(port: 0), throwsFormatException);
      await journal.writeAsString('');
      final repaired = CollaborationServer(temp, 'owner-key');
      await repaired.start(port: 0);
      await repaired.close();
    },
  );
  testWidgets('Viewer reads long notes without editable text controls', (
    tester,
  ) async {
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            noteId: 'shared',
            title: 'Shared',
            viewOnly: true,
            body: List.generate(
              100,
              (i) => 'Paragraph $i with useful content.',
            ).join('\n\n'),
            onTitleChanged: (_) => changes++,
            onBodyChanged: (_) => changes++,
            linkTargets: const [],
            onOpenObject: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      greaterThan(0),
    );
    expect(changes, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Viewer pans Canvas without altering placements or undo history',
    (tester) async {
      var changes = 0;
      Map<String, dynamic>? camera;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'shared',
              readOnly: true,
              data: const {
                'schemaVersion': 1,
                'elements': [
                  {
                    'id': 'rectangle',
                    'type': 'rectangle',
                    'x': 0,
                    'y': 0,
                    'width': 200,
                    'height': 100,
                  },
                ],
              },
              onChanged: (_) => changes++,
              onCameraChanged: (v) => camera = v,
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(400, 350), const Offset(70, 40));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(camera, isNotNull);
      expect(changes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('shared controls wrap at narrow widths and large text', (
    tester,
  ) async {
    final c = CollaborationController(WorkspaceController(), http.Client());
    addTearDown(() {
      c.dispose();
    });
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCollaborationSettings(context, c),
              child: const Text('Share'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(find.text('Join shared Vault'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Canvas remote cursor uses world position through the shared engine',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CanvasEditor(
            canvasId: 'shared',
            data: const {'schemaVersion': 1, 'elements': []},
            onChanged: (_) {},
            objects: const [],
            onOpenObject: (_) {},
            remoteCursors: const [
              {'name': 'Bob', 'x': 100, 'y': 200},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('↖ Bob'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
