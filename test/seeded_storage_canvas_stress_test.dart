import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';

void main() {
  for (var seed = 0; seed < 8; seed++) {
    test(
      'Canvas seed $seed: 1000 mixed commands retain history, index and opaque data',
      () {
        final random = Random(seed);
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'extension': {
            'keep': [1, 2, 3],
          },
          'elements': [
            {'id': 'future', 'type': 'unknown', 'opaque': true},
          ],
        });
        final history = CanvasHistory(scene);
        final undo = <(String, String)>[], redo = <(String, String)>[];
        String snapshot() => jsonEncode(scene.toJson());
        for (var step = 0; step < 1000; step++) {
          final action = random.nextInt(10);
          if (action == 0 && undo.isNotEmpty) {
            final delta = undo.removeLast();
            expect(history.undo(), isTrue);
            expect(snapshot(), delta.$1, reason: 'seed $seed step $step undo');
            redo.add(delta);
          } else if (action == 1 && redo.isNotEmpty) {
            final delta = redo.removeLast();
            expect(history.redo(), isTrue);
            expect(snapshot(), delta.$2, reason: 'seed $seed step $step redo');
            undo.add(delta);
          } else {
            final before = snapshot();
            final id = 'item-${random.nextInt(160)}';
            if (action == 3 && scene[id] != null) {
              history.remove(id);
            } else if (action == 4 && scene[id] != null) {
              history.reorder([id], () => scene.bringToFront(id));
            } else {
              history.put(
                CanvasElement({
                  'id': id,
                  'type': 'card',
                  'objectId': 'shared',
                  'x': random.nextInt(4000) - 2000.0,
                  'y': random.nextInt(4000) - 2000.0,
                  'width': 40.0,
                  'height': 30.0,
                  'extension': {'seed': seed, 'step': step},
                }),
              );
            }
            if (action == 2) {
              history.cancel();
              expect(snapshot(), before, reason: 'cancel $seed/$step');
            } else if (history.commit()) {
              undo.add((before, snapshot()));
              if (undo.length > 100) undo.removeAt(0);
              redo.clear();
            }
          }
          final root = scene.toJson();
          expect(root['extension'], {
            'keep': [1, 2, 3],
          });
          expect(
            (root['elements'] as List)
                .where((e) => (e as Map)['id'] == 'future')
                .single,
            {'id': 'future', 'type': 'unknown', 'opaque': true},
          );
          final bounds = CanvasBounds(
            random.nextInt(3500) - 1750.0,
            random.nextInt(3500) - 1750.0,
            450,
            450,
          );
          final expected = (root['elements'] as List)
              .whereType<Map>()
              .where((e) => e['type'] == 'card')
              .map((e) => CanvasElement(Map<String, dynamic>.from(e)))
              .where((e) => e.bounds.inflate(e.strokeWidth).intersects(bounds))
              .map((e) => e.id)
              .toSet();
          expect(
            scene.query(bounds).map((e) => e.id).toSet(),
            expected,
            reason: 'index $seed/$step',
          );
          if (step % 100 == 0) {
            expect(
              jsonEncode(
                CanvasScene.fromJson(
                  jsonDecode(snapshot()) as Map<String, dynamic>,
                ).toJson(),
              ),
              snapshot(),
            );
          }
        }
      },
    );
  }
  test(
    'native 24-note 6-round save/reopen stress and external conflicts preserve final bytes',
    () async {
      final folder = await Directory.systemTemp.createTemp('orbit-stress-');
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      addTearDown(() async {
        await repo.close();
        await folder.delete(recursive: true);
      });
      await repo.initialize(path: folder.path);
      final notes = <UniversalObject>[];
      for (var i = 0; i < 24; i++) {
        notes.add(
          await repo.create(
            typeId: 'orbit.note',
            title: 'Stress $i',
            body: 'Initial $i',
            properties: {
              'unknown': {
                'nested': [i, '🎮'],
              },
            },
          ),
        );
      }
      final expected = <String, String>{};
      for (var round = 0; round < 6; round++) {
        await Future.wait(
          notes.asMap().entries.map((entry) async {
            final note = repo.objects.singleWhere(
              (o) => o.id == entry.value.id,
            );
            final body =
                '# Round $round\r\n\r\nNote ${entry.key} 🎮 é **bold**\n\n| A | B |\n|---|---|\n| $round | ${entry.key} |\n';
            await repo.save(note.copyWith(body: body));
            expected[note.id] = body;
          }),
        );
        await repo.initialize(path: folder.path);
        for (final note in repo.objects) {
          expect(note.body, expected[note.id]);
          expect(note.properties['unknown'], isNotNull);
        }
      }
      final note = repo.objects.first;
      final file = File(p.join(folder.path, repo.objectPath(note.id)!));
      final source = await file.readAsString();
      final external = source.replaceFirst(note.body, 'External author edit\n');
      await file.writeAsString(external, flush: true);
      await expectLater(
        repo.save(note.copyWith(body: 'Stale overwrite')),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(await file.readAsString(), external);
      await repo.initialize(path: folder.path);
      expect(
        repo.objects.singleWhere((o) => o.id == note.id).body,
        'External author edit\n',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
