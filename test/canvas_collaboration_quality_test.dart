import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/collaboration.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  test(
    'three thousand placements merge independent fields without losing opaque data',
    () async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      addTearDown(repo.close);
      final board = await repo.create(
        typeId: 'orbit.canvas',
        title: 'Large shared board',
        data: {
          'schemaVersion': 1,
          'opaque': {
            'retain': [1, 2],
          },
          'elements': [
            for (var i = 0; i < 3000; i++)
              {
                'id': 'p$i',
                'type': 'rectangle',
                'x': i * 10,
                'y': 0,
                'width': 8,
                'height': 8,
                'future': i,
              },
          ],
        },
      );
      final base = collaborationSnapshot(board);
      Map<String, dynamic> changed(String id, String field, int value) =>
          collaborationSnapshot(
            board.copyWith(
              data: {
                ...board.data,
                'elements': [
                  for (final e in board.data['elements'] as List)
                    if (e['id'] == id)
                      {...e as Map<String, dynamic>, field: value}
                    else
                      e,
                ],
              },
            ),
          );
      final result = collaborationObject(
        mergeCollaboration(
          base,
          changed('p1', 'x', 51),
          changed('p2999', 'y', 73),
        ),
      );
      final elements = result.data['elements'] as List;
      expect(elements, hasLength(3000));
      expect(elements[1]['x'], 51);
      expect(elements.last['y'], 73);
      expect(elements.last['future'], 2999);
      expect(result.data['opaque'], {
        'retain': [1, 2],
      });
      expect(result.id, board.id);
    },
  );
  test(
    'different orders of surviving placements still require conflict review',
    () async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      addTearDown(repo.close);
      final items = [
        for (final id in ['a', 'b', 'c'])
          {'id': id, 'type': 'text', 'text': id, 'x': 0, 'y': 0},
      ];
      final board = await repo.create(
        typeId: 'orbit.canvas',
        title: 'Order',
        data: {'schemaVersion': 1, 'elements': items},
      );
      Map<String, dynamic> ordered(List<String> ids) => collaborationSnapshot(
        board.copyWith(
          data: {
            ...board.data,
            'elements': [
              for (final id in ids) items.singleWhere((e) => e['id'] == id),
            ],
          },
        ),
      );
      expect(
        () => mergeCollaboration(
          collaborationSnapshot(board),
          ordered(['b', 'a', 'c']),
          ordered(['a', 'c', 'b']),
        ),
        throwsA(isA<CollaborationConflict>()),
      );
    },
  );
  test(
    'compatible reorders with independent deletions use common placement order',
    () async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      addTearDown(repo.close);
      final board = await repo.create(
        typeId: 'orbit.canvas',
        title: 'Board',
        data: {
          'schemaVersion': 1,
          'elements': [
            for (final id in ['a', 'b', 'c', 'd'])
              {'id': id, 'type': 'text', 'text': id, 'x': 0, 'y': 0},
          ],
        },
      );
      Map<String, dynamic> snapshot(List<String> ids) => collaborationSnapshot(
        board.copyWith(
          data: {
            ...board.data,
            'elements': [
              for (final id in ids)
                (board.data['elements'] as List).singleWhere(
                  (e) => e['id'] == id,
                ),
            ],
          },
        ),
      );
      final next = collaborationObject(
        mergeCollaboration(
          collaborationSnapshot(board),
          snapshot(['b', 'a', 'c']),
          snapshot(['b', 'a', 'd']),
        ),
      );
      expect((next.data['elements'] as List).map((e) => e['id']), ['b', 'a']);
    },
  );
  test(
    'a one-sided duplicate placement cannot bypass shared identity checks',
    () async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      addTearDown(repo.close);
      final element = {'id': 'a', 'type': 'text', 'text': 'A', 'x': 0, 'y': 0};
      final board = await repo.create(
        typeId: 'orbit.canvas',
        title: 'Board',
        data: {
          'schemaVersion': 1,
          'elements': [element],
        },
      );
      final base = collaborationSnapshot(board);
      final invalid = collaborationSnapshot(
        board.copyWith(
          data: {
            ...board.data,
            'elements': [element, element],
          },
        ),
      );
      expect(
        () => mergeCollaboration(base, base, invalid),
        throwsA(isA<CollaborationConflict>()),
      );
    },
  );
}
