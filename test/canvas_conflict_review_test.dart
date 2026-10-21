import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/collaboration.dart';
import 'package:orbit_note/domain/universal_object.dart';

UniversalObject board() => UniversalObject(
  id: 'board',
  workspaceId: 'workspace',
  typeId: 'orbit.canvas',
  title: 'Board',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  data: {
    'schemaVersion': 1,
    'future': {
      'keep': [1, 2],
    },
    'elements': [
      for (final id in ['a', 'b', 'c'])
        {
          'id': id,
          'type': 'card',
          'objectId': 'canonical-$id',
          'x': 0,
          'y': 0,
          'future': {'keep': true},
        },
    ],
  },
);
Map<String, dynamic> changed(
  UniversalObject b,
  Map<String, Map<String, dynamic>?> edits, {
  List<String>? order,
}) =>
    jsonDecode(
          jsonEncode(
            collaborationSnapshot(
              b.copyWith(
                data: {
                  ...b.data,
                  'elements': [
                    for (final id in order ?? ['a', 'b', 'c'])
                      if (!edits.containsKey(id) || edits[id] != null)
                        {
                          ...(b.data['elements'] as List).singleWhere(
                                (e) => e['id'] == id,
                              )
                              as Map,
                          ...?edits[id],
                        },
                  ],
                },
              ),
            ),
          ),
        )
        as Map<String, dynamic>;

void main() {
  test(
    'item review keeps independent changes and opaque references on both sides',
    () {
      final b = board(), base = collaborationSnapshot(board());
      final review = CanvasConflictReview.create(
        base,
        changed(b, {
          'a': {'x': 20},
          'b': {'y': 40},
        }),
        changed(b, {
          'a': {'x': 30},
          'c': {'y': 60},
        }),
      );
      expect(review.placements.map((p) => p.id), ['a']);
      expect(review.placements.single.changedFields, ['x']);
      for (final side in CanvasConflictSide.values) {
        final resolved = collaborationObject(review.resolve({'a': side}));
        final elements = resolved.data['elements'] as List;
        expect(elements[0]['x'], side == CanvasConflictSide.local ? 20 : 30);
        expect(elements[1]['y'], 40);
        expect(elements[2]['y'], 60);
        expect(elements.map((e) => e['objectId']), [
          'canonical-a',
          'canonical-b',
          'canonical-c',
        ]);
        expect(elements[0]['future'], {'keep': true});
        expect(resolved.data['future'], {
          'keep': [1, 2],
        });
      }
    },
  );
  test(
    'edit versus removal explicitly chooses a placement, not its object',
    () {
      final b = board();
      final review = CanvasConflictReview.create(
        collaborationSnapshot(b),
        changed(b, {'a': null}),
        changed(b, {
          'a': {'x': 55},
        }),
      );
      expect(review.placements.single.local, isNull);
      expect(review.placements.single.shared!['objectId'], 'canonical-a');
      expect(
        (collaborationObject(
              review.resolve({'a': CanvasConflictSide.local}),
            ).data['elements']
            as List),
        hasLength(2),
      );
      expect(
        (collaborationObject(
              review.resolve({'a': CanvasConflictSide.shared}),
            ).data['elements']
            as List),
        hasLength(3),
      );
    },
  );
  test(
    'all overlapping items and genuine order conflicts require explicit choices',
    () {
      final b = board();
      final review = CanvasConflictReview.create(
        collaborationSnapshot(b),
        changed(
          b,
          {
            'a': {'x': 1},
            'c': {'x': 1},
          },
          order: ['b', 'a', 'c'],
        ),
        changed(
          b,
          {
            'a': {'x': 2},
            'c': {'x': 2},
          },
          order: ['a', 'c', 'b'],
        ),
      );
      expect(review.hasOrderConflict, isTrue);
      expect(
        () => review.resolve({'a': CanvasConflictSide.local}),
        throwsStateError,
      );
      expect(
        () => review.resolve({
          'a': CanvasConflictSide.local,
          'c': CanvasConflictSide.shared,
        }),
        throwsStateError,
      );
      final resolved = collaborationObject(
        review.resolve({
          'a': CanvasConflictSide.local,
          'c': CanvasConflictSide.shared,
        }, order: CanvasConflictSide.shared),
      );
      expect((resolved.data['elements'] as List).map((e) => e['id']), [
        'a',
        'c',
        'b',
      ]);
      expect(
        () => review.resolve({
          'a': CanvasConflictSide.local,
          'c': CanvasConflictSide.shared,
          'unknown': CanvasConflictSide.local,
        }, order: CanvasConflictSide.local),
        throwsStateError,
      );
    },
  );
  test('snapshot review is immutable and does not mutate authored input', () {
    final b = board(), base = collaborationSnapshot(board());
    final local = changed(b, {
          'a': {'x': 1},
        }),
        shared = changed(b, {
          'a': {'x': 2},
        });
    final review = CanvasConflictReview.create(base, local, shared);
    (local['data']['elements'] as List)[0]['x'] = 99;
    expect(review.placements.single.local!['x'], 1);
    expect(
      () => review.placements.single.local!['future']['keep'] = false,
      throwsUnsupportedError,
    );
    expect(collaborationObject(base).data['elements'][0]['x'], 0);
  });
  test(
    'unsupported metadata and non-Canvas inputs are never resolved away',
    () {
      final b = board(), base = collaborationSnapshot(board());
      expect(
        () => CanvasConflictReview.create(
          base,
          {
            ...changed(b, {
              'a': {'x': 1},
            }),
            'documentExtra': {'unknown': true},
          },
          changed(b, {
            'a': {'x': 2},
          }),
        ),
        throwsA(isA<CollaborationConflict>()),
      );
      final local = changed(b, {
            'a': {'x': 1},
          }),
          shared = changed(b, {
            'a': {'x': 2},
          });
      (local['object'] as Map)['title'] = 'Other local title';
      (shared['object'] as Map)['title'] = 'Other shared title';
      expect(
        () => CanvasConflictReview.create(base, local, shared),
        throwsA(isA<CollaborationConflict>()),
      );
      final note = UniversalObject(
        id: 'n',
        workspaceId: 'workspace',
        typeId: 'orbit.note',
        title: 'Note',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      expect(
        () => CanvasConflictReview.create(
          collaborationSnapshot(note),
          collaborationSnapshot(note),
          collaborationSnapshot(note),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'duplicate IDs refuse review and independent placement additions survive',
    () {
      final b = board(), base = collaborationSnapshot(board());
      final local = changed(b, {
            'a': {'x': 1},
          }),
          shared = changed(b, {
            'a': {'x': 2},
          });
      (local['data']['elements'] as List).add({
        'id': 'new-local',
        'type': 'sticky',
        'text': 'Idea',
      });
      (shared['data']['elements'] as List).add({
        'id': 'new-shared',
        'type': 'sticky',
        'text': 'Evidence',
      });
      final review = CanvasConflictReview.create(base, local, shared);
      expect(
        collaborationObject(
          review.resolve({'a': CanvasConflictSide.local}),
        ).data['elements'],
        hasLength(5),
      );
      (local['data']['elements'] as List).add({'id': 'a', 'type': 'text'});
      expect(
        () => CanvasConflictReview.create(base, local, shared),
        throwsA(isA<CollaborationConflict>()),
      );
    },
  );
  test(
    'three thousand items collect every overlap without losing independent work',
    () {
      final b = board().copyWith(
        data: {
          'schemaVersion': 1,
          'elements': [
            for (var i = 0; i < 3000; i++)
              {
                'id': 'p$i',
                'type': 'rectangle',
                'x': i,
                'y': 0,
                'future': true,
              },
          ],
        },
      );
      final base = collaborationSnapshot(b);
      Map<String, dynamic> version(int delta) => collaborationSnapshot(
        b.copyWith(
          data: {
            ...b.data,
            'elements': [
              for (final e in b.data['elements'] as List)
                {
                  ...e as Map,
                  if ((int.parse(e['id'].toString().substring(1)) % 10) == 0)
                    'x': e['x'] + delta,
                },
            ],
          },
        ),
      );
      final review = CanvasConflictReview.create(base, version(1), version(2));
      expect(review.placements, hasLength(300));
      final result = collaborationObject(
        review.resolve({
          for (final p in review.placements) p.id: CanvasConflictSide.shared,
        }),
      );
      expect(result.data['elements'], hasLength(3000));
      expect(result.data['elements'][2990]['x'], 2992);
      expect(result.data['elements'][2999]['future'], isTrue);
    },
  );
}
