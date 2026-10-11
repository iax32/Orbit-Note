import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

void main() {
  test(
    'Canvas refreshes canonical status, saved query membership and failure previews without scene edits',
    () {
      final scene = CanvasScene.fromJson({'schemaVersion': 1, 'elements': []});
      final colors = ColorScheme.fromSeed(seedColor: Colors.indigo);
      final cache = CanvasTextCache();
      OrbitCanvasPainter painter(CanvasObjectReference object) =>
          OrbitCanvasPainter(
            scene: scene,
            camera: const CanvasCamera(),
            selection: const {},
            objects: {object.id: object},
            colors: colors,
            textCache: cache,
          );
      const task = CanvasObjectReference(
        id: 'task',
        title: 'Work',
        typeId: 'orbit.task',
        properties: {'completed': false},
      );
      const completed = CanvasObjectReference(
        id: 'task',
        title: 'Work',
        typeId: 'orbit.task',
        properties: {'completed': true},
      );
      expect(painter(completed).shouldRepaint(painter(task)), true);
      expect(painter(task).shouldRepaint(painter(task)), false);
      const view = CanvasObjectReference(
        id: 'view',
        title: 'Sources',
        typeId: 'orbit.view',
        viewMemberIds: ['a'],
      );
      const changed = CanvasObjectReference(
        id: 'view',
        title: 'Sources',
        typeId: 'orbit.view',
        viewMemberIds: ['b'],
      );
      const failed = CanvasObjectReference(
        id: 'view',
        title: 'Sources',
        typeId: 'orbit.view',
        viewQueryIssue: 'Unsupported version',
      );
      expect(painter(changed).shouldRepaint(painter(view)), true);
      expect(painter(failed).shouldRepaint(painter(view)), true);
      expect(scene.elements, isEmpty);
      cache.dispose();
    },
  );
}
