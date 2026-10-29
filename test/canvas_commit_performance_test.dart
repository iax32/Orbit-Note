import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/object_codec.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/memory_store.dart';

Map<String, dynamic> drawing() => {
  'schemaVersion': 1,
  'futureRoot': {'preserved': true},
  'elements': [
    for (var i = 0; i < 1500; i++)
      {
        'id': 'ink-$i',
        'type': 'ink',
        'x': i * 2.0,
        'y': 1.0,
        'width': 20.0,
        'height': 10.0,
        'penStyle': 'ballpoint',
        'points': [
          for (var p = 0; p < 40; p++)
            {
              'x': p * .5,
              'y': p % 4 * 1.0,
              'pressure': .7,
              'timeMs': p,
              'futureSample': {
                'keep': [1, 2, 3],
              },
            },
        ],
      },
  ],
};

UniversalObject board(Map<String, dynamic> data) => UniversalObject(
  id: 'board',
  workspaceId: 'workspace',
  typeId: 'orbit.canvas',
  title: 'Board',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  data: data,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'immutable scene snapshots detach legacy aliases and preserve order, unknown data and undo',
    () {
      final nested = <String, dynamic>{'value': 1};
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'unknownRoot': nested,
        'elements': [
          {
            'id': 'a',
            'type': 'rectangle',
            'x': 0.0,
            'y': 0.0,
            'unknown': nested,
          },
          {'id': 'b', 'type': 'rectangle', 'x': 50.0, 'y': 0.0},
          {'id': 'future', 'type': 'future-shape', 'unknown': nested},
          'opaque',
        ],
      });
      final first = scene.snapshotJson();
      expect(first, scene.toJson());
      nested['value'] = 2;
      expect(first['unknownRoot'], {'value': 1});
      expect(scene.snapshotJson()['unknownRoot'], {'value': 2});
      expect(
        () => (first['elements'] as List).first['x'] = 99,
        throwsUnsupportedError,
      );
      // A caller sorting its returned list must not corrupt the cached scene order.
      scene.elementsInOrder.clear();
      expect(scene.elementsInOrder.map((e) => e.id), ['a', 'b', 'future']);
      final history = CanvasHistory(scene);
      history.reorder(['a'], () => scene.bringToFront('a'));
      history.commit();
      expect(scene.snapshotJson(), scene.toJson());
      expect(
        (scene.snapshotJson()['elements'] as List).map(
          (e) => e is Map ? e['id'] : e,
        ),
        ['b', 'future', 'a', 'opaque'],
      );
      history.undo();
      expect(scene.snapshotJson(), scene.toJson());
      expect(scene.elementsInOrder.map((e) => e.id), ['a', 'b', 'future']);
      history.redo();
      expect(scene.snapshotJson(), scene.toJson());
      expect(scene.elementsInOrder.map((e) => e.id), ['b', 'future', 'a']);
    },
  );
  test(
    'large native board saves validate before writes and survive reopen with unknown samples',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'orbit-large-commit-',
      );
      var repo = WorkspaceRepository(
        store: NativeWorkspaceStore(rememberWorkspace: false),
        index: MemoryObjectIndex(),
      );
      addTearDown(() async {
        await repo.close();
        await folder.delete(recursive: true);
      });
      await repo.initialize(path: folder.path);
      final created = await repo.create(
        typeId: 'orbit.canvas',
        title: 'Large board',
        data: drawing(),
      );
      final saved = await repo.save(
        created.copyWith(data: {...created.data, 'extraEdit': true}),
      );
      final file = File('${folder.path}/${repo.objectPath(saved.id)}');
      final before = await file.readAsString();
      await expectLater(
        repo.save(saved.copyWith(data: {...saved.data, 'invalid': double.nan})),
        throwsA(anything),
      );
      expect(await file.readAsString(), before);
      expect(
        repo.objects.firstWhere((o) => o.id == saved.id).revision,
        saved.revision,
      );
      await repo.close();
      repo = WorkspaceRepository(
        store: NativeWorkspaceStore(rememberWorkspace: false),
        index: MemoryObjectIndex(),
      );
      await repo.initialize(path: folder.path);
      final reopened = repo.objects.firstWhere((o) => o.id == saved.id);
      var ticks = 0;
      final heartbeat = Timer.periodic(
        const Duration(milliseconds: 1),
        (_) => ticks++,
      );
      expect(
        await repo.hasExternalChanges(
          changedPaths: {repo.objectPath(saved.id)!},
        ),
        false,
      );
      expect(await repo.hasExternalChanges(), false);
      await repo.refresh();
      heartbeat.cancel();
      expect(ticks, greaterThan(0));
      expect(
        identical(repo.objects.firstWhere((o) => o.id == saved.id), reopened),
        true,
        reason: 'Unchanged byte hashes must preserve the renderer snapshot',
      );
      expect(reopened.data, saved.data);
      expect(reopened.data['elements'][1499]['points'][39]['futureSample'], {
        'keep': [1, 2, 3],
      });
      // A background-encoded edit must still obey the existing external-write
      // precondition rather than replacing the other writer's source.
      await file.writeAsString('$before\n');
      expect(
        await repo.hasExternalChanges(
          changedPaths: {repo.objectPath(saved.id)!},
        ),
        true,
      );
      await expectLater(
        repo.save(reopened.copyWith(title: 'Competing')),
        throwsA(anything),
      );
      expect(await file.readAsString(), '$before\n');
    },
  );
  test(
    'large immutable drawings share unchanged samples without exposing mutable aliases',
    () {
      final input = drawing();
      final object = board(input);
      final elements = object.data['elements'] as List;
      final points = (elements.first as Map)['points'] as List;
      final scene = CanvasScene.fromJson(object.data);
      scene.put(
        CanvasElement({
          'id': 'new',
          'type': 'ink',
          'x': 0.0,
          'y': 0.0,
          'points': [
            {'x': 1.0, 'y': 2.0},
          ],
        }),
      );
      final watch = Stopwatch()..start();
      final next = object.copyWith(data: scene.snapshotJson());
      watch.stop();
      expect(next.data['elements'], hasLength(1501));
      expect(
        identical((next.data['elements'] as List).first['points'], points),
        true,
      );
      expect(
        identical((next.data['elements'] as List).first, elements.first),
        true,
      );
      expect(() => points.add({}), throwsUnsupportedError);
      expect(() => points.first['x'] = 99, throwsUnsupportedError);
      expect(
        () => (points.first['futureSample']['keep'] as List).clear(),
        throwsUnsupportedError,
      );
      input['elements'][0]['points'][0]['x'] = 99;
      input['elements'].clear();
      expect(points.first['x'], 0.0);
      expect(elements, hasLength(1500));
      expect(next.data['futureRoot'], {'preserved': true});
      final codec = ObjectCodec();
      addTearDown(codec.close);
      expect(
        codec.decode(codec.encode(next), 'workspace', markdown: false).data,
        next.data,
      );
      debugPrint(
        '60000 existing samples / snapshot append: ${watch.elapsedMicroseconds} us',
      );
    },
  );

  test(
    'large save encoding yields to input and preserves exact file bytes and hash',
    () async {
      final object = board(drawing());
      final codec = ObjectCodec();
      addTearDown(codec.close);
      var ticks = 0;
      final heartbeat = Timer.periodic(
        const Duration(milliseconds: 1),
        (_) => ticks++,
      );
      final encoded = await codec.encodeForSave(object);
      heartbeat.cancel();
      expect(
        ticks,
        greaterThan(0),
        reason: 'Large encoding must not block the calling event loop',
      );
      expect(encoded.source, codec.encode(object));
      expect(utf8.decode(encoded.bytes), encoded.source);
      expect(encoded.hash, sha256.convert(encoded.bytes).toString());
      ticks = 0;
      final hashHeartbeat = Timer.periodic(
        const Duration(milliseconds: 1),
        (_) => ticks++,
      );
      expect(await codec.hashBytes(encoded.bytes), encoded.hash);
      hashHeartbeat.cancel();
      expect(ticks, greaterThan(0));
      ticks = 0;
      final decodeHeartbeat = Timer.periodic(
        const Duration(milliseconds: 1),
        (_) => ticks++,
      );
      final loaded = await codec.decodeForLoad(
        encoded.bytes,
        'workspace',
        markdown: false,
      );
      decodeHeartbeat.cancel();
      expect(ticks, greaterThan(0));
      expect(loaded.source, encoded.source);
      expect(loaded.object.data, object.data);
      expect(
        codec.decode(encoded.source, 'workspace', markdown: false).data,
        object.data,
      );
    },
  );

  test(
    'repeated large Canvas commits stay guarded and durable without serializing no-op comparisons',
    () async {
      final store = MemoryStore();
      final repository = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repository)],
      );
      container.read(workspaceProvider);
      final c = container.read(workspaceProvider.notifier);
      addTearDown(() {
        c.cancelAllTimers();
        container.dispose();
      });
      while (c.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      c.pausePdfIndex(true);
      final object = (await c.create('orbit.canvas', data: drawing()))!;
      c.cancelAllTimers();
      final base = c.find(object.id)!.data;
      final scene = CanvasScene.fromJson(base);
      final watch = Stopwatch()..start();
      for (var i = 0; i < 20; i++) {
        scene.put(
          CanvasElement(
            immutableObjectData({
              'id': 'new-$i',
              'type': 'ink',
              'x': 0.0,
              'y': 0.0,
              'points': [
                for (var p = 0; p < 200; p++)
                  {'x': p * .5, 'y': p % 2 * 1.0, 'pressure': .4, 'timeMs': p},
              ],
            }),
          ),
        );
        expect(
          c.publishCanvasDraft(
            'left',
            object.id,
            c.find(object.id)!.data,
            scene.snapshotJson(),
          ),
          true,
        );
        c.cancelAllTimers();
        expect(
          identical(
            scene['new-$i']!.data['points'],
            (c.find(object.id)!.data['elements'] as List).last['points'],
          ),
          true,
        );
      }
      watch.stop();
      expect(c.find(object.id)!.data['elements'], hasLength(1520));
      expect(
        c.publishCanvasDraft('right', object.id, base, {
          ...base,
          'newCompetingField': true,
        }),
        false,
      );
      expect(c.editorDraftConflicts, contains('right'));
      await c.flush(object.id);
      expect(c.dirty, isNot(contains(object.id)));
      expect(
        repository.objects.firstWhere((o) => o.id == object.id).data,
        c.find(object.id)!.data,
      );
      expect(c.find(object.id)!.data['futureRoot'], {'preserved': true});
      debugPrint(
        '60000 existing samples / 20 guarded app commits: ${watch.elapsedMilliseconds} ms',
      );
    },
  );
}
