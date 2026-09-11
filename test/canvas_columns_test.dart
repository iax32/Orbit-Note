import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/columns.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/geometry.dart';

CanvasElement element(String id, {String type = 'card', double y = 10}) =>
    CanvasElement({
      'id': id,
      'type': type,
      'x': 20.0,
      'y': y,
      'width': 200.0,
      'height': 100.0,
      'objectId': 'same-object',
      'future': {'preserve': true},
    });

void main() {
  test(
    'columns pack placements, retain object IDs and unknown fields across reload/undo',
    () {
      final history = CanvasHistory(
        CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [element('a').data, element('b', y: 180).data],
        }),
      );
      final before = history.scene.toJson();
      final column = element('column', type: 'column', y: 0);
      for (final item in arrangeColumn(column, history.scene.elements)) {
        history.put(item);
      }
      expect(history.commit(), isTrue);
      final reloaded = CanvasScene.fromJson(history.scene.toJson());
      final members = columnMembers(reloaded, 'column');
      expect(members.map((e) => e.id), ['a', 'b']);
      expect(members[1].y, members[0].y + members[0].height + 16);
      expect(members.every((e) => e.objectId == 'same-object'), isTrue);
      expect(members.first.data['future'], {'preserve': true});
      expect(
        reloaded
            .hit(CanvasPoint(members.first.x + 10, members.first.y + 10))
            ?.id,
        'a',
      );
      expect(history.undo(), isTrue);
      expect(history.scene.toJson(), before);
    },
  );

  test(
    'locked placements prevent column rearrangement without partial changes',
    () {
      expect(
        arrangeColumn(element('column', type: 'column'), [
          element('locked').copy({'locked': true}),
        ]),
        isEmpty,
      );
    },
  );
}
