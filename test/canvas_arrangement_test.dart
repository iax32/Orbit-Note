import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/arrangement.dart';
import 'package:orbit_note/canvas/scene.dart';

void main() {
  test(
    'arrange preserves object references, locks and restores with one undo',
    () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'a',
            'type': 'card',
            'objectId': 'note-1',
            'x': 10,
            'y': 20,
            'width': 40,
            'height': 30,
            'custom': true,
          },
          {
            'id': 'b',
            'type': 'rectangle',
            'x': 140,
            'y': 90,
            'width': 20,
            'height': 30,
          },
          {
            'id': 'c',
            'type': 'sticky',
            'x': 300,
            'y': 150,
            'width': 60,
            'height': 30,
          },
          {
            'id': 'locked',
            'type': 'rectangle',
            'x': 999,
            'y': 999,
            'width': 20,
            'height': 20,
            'locked': true,
          },
        ],
      });
      final history = CanvasHistory(scene);
      final before = scene.toJson();
      for (final element in arrangeCanvas(
        ['a', 'b', 'c', 'locked'].map((id) => scene[id]!),
        CanvasArrangement.left,
      )) {
        history.put(element);
      }
      history.commit();
      expect(scene['b']!.x, 10);
      expect(scene['locked']!.x, 999);
      expect(scene['a']!.objectId, 'note-1');
      expect(scene['a']!.data['custom'], true);
      history.undo();
      expect(scene.toJson(), before);
      final arranged = arrangeCanvas(
        ['a', 'b', 'c'].map((id) => scene[id]!),
        CanvasArrangement.horizontal,
      );
      expect(
        arranged[1].x - arranged[0].bounds.right,
        arranged[2].x - arranged[1].bounds.right,
      );
    },
  );
}
