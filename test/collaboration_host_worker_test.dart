import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/collaboration/host_worker.dart';
import 'package:orbit_note/infrastructure/collaboration/server.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => HttpOverrides.global = null);
  test(
    'worker shutdown drains durable rooms and restart retains their identity',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-host-worker-');
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      final owner = collaborationToken();
      CollaborationHostWorker? worker;
      final client = http.Client();
      try {
        await repo.initialize();
        final note = await repo.create(
          typeId: 'orbit.note',
          title: 'Synthetic large note',
          body: 'x' * 3000000,
        );
        worker = await CollaborationHostWorker.start(root, owner);
        final response = await client.post(
          Uri.parse('http://127.0.0.1:${worker.port}/v1/rooms'),
          headers: {
            'Authorization': 'Bearer $owner',
            'Content-Type': 'application/json',
            'X-Orbit-Client': '2',
            'Content-Encoding': 'gzip',
          },
          body: gzip.encode(
            utf8.encode(
              jsonEncode({
                'name': 'Synthetic host',
                'backup': await repo.exportBundle(),
                'replicationVersion': 2,
              }),
            ),
          ),
        );
        expect(response.statusCode, 200);
        expect(response.headers['x-orbit-accept-encoding'], 'gzip');
        final grant = jsonDecode(response.body) as Map;
        final rejected = await client.post(
          Uri.parse(
            'http://127.0.0.1:${worker.port}/v1/rooms/${grant['room']}/invite',
          ),
          headers: {
            'Authorization': 'Bearer ${grant['token']}',
            'Content-Type': 'application/json',
            'Content-Encoding': 'gzip',
          },
          body: gzip.encode(
            utf8.encode(jsonEncode({'name': 'x' * 10000, 'role': 'editor'})),
          ),
        );
        expect(
          rejected.statusCode,
          400,
          reason: 'Decoded limits apply even to a tiny compressed body.',
        );
        await worker.close();
        await worker.done;
        worker = await CollaborationHostWorker.start(root, owner);
        final restored = await client.get(
          Uri.parse(
            'http://127.0.0.1:${worker.port}/v1/rooms/${grant['room']}/state',
          ),
          headers: {
            'Authorization': 'Bearer ${grant['token']}',
            'X-Orbit-Client': '2',
          },
        );
        expect(restored.statusCode, 200);
        final state = jsonDecode(restored.body) as Map;
        expect(state['workspaceId'], repo.workspaceId);
        expect(state['documents'][note.id]['snapshot']['body'], 'x' * 3000000);
        final raw = IOClient(HttpClient()..autoUncompress = false);
        try {
          final compressed = await raw.get(
            Uri.parse(
              'http://127.0.0.1:${worker.port}/v1/rooms/${grant['room']}/state',
            ),
            headers: {
              'Authorization': 'Bearer ${grant['token']}',
              'X-Orbit-Client': '2',
              'Accept-Encoding': 'gzip',
            },
          );
          expect(compressed.headers['content-encoding'], 'gzip');
          expect(
            compressed.bodyBytes.length,
            lessThan(restored.bodyBytes.length ~/ 4),
          );
          expect(
            jsonDecode(utf8.decode(gzip.decode(compressed.bodyBytes))),
            state,
          );
        } finally {
          raw.close();
        }
      } finally {
        client.close();
        await worker?.close();
        await repo.close();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'worker startup refuses a Vault directory and releases startup resources',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-host-boundary-',
      );
      try {
        await File('${root.path}/workspace.json').writeAsString('{}');
        await expectLater(
          CollaborationHostWorker.start(
            Directory('${root.path}/server'),
            collaborationToken(),
          ),
          throwsA(isA<StateError>()),
        );
        expect(await File('${root.path}/workspace.json').readAsString(), '{}');
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
