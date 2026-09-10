import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';

CanvasElement card(String id, double x, {String objectId = 'shared'}) =>
    CanvasElement({
      'id': id,
      'type': 'card',
      'objectId': objectId,
      'x': x,
      'y': 0.0,
      'width': 200.0,
      'height': 120.0,
    });
void main() {
  test(
    'delta undo retains only touched elements and restores stacking order',
    () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': List.generate(10000, (i) => card('item-$i', 0).data),
      });
      final history = CanvasHistory(scene);
      history.remove('item-5000');
      history.commit();
      history.undo();
      expect(history.retainedElementStates, 2);
      expect(
        scene.query(const CanvasBounds(0, 0, 300, 300))[5000].id,
        'item-5000',
      );
      final reopened = CanvasScene.fromJson(scene.toJson());
      expect(
        reopened.query(const CanvasBounds(0, 0, 300, 300))[5000].id,
        'item-5000',
      );
      history.redo();
      expect(scene['item-5000'], isNull);
      history.undo();
      expect(scene['item-5000'], isNotNull);
    },
  );
  test('camera round trip and anchored zoom preserve world coordinates', () {
    const camera = CanvasCamera(x: -200, y: 300, zoom: .7),
        world = CanvasPoint(700, -100);
    final screen = camera.toScreen(world), round = camera.toWorld(screen);
    expect(round.x, closeTo(world.x, 1e-9));
    expect(round.y, closeTo(world.y, 1e-9));
    final zoomed = camera.zoomAt(screen, 1.4).toWorld(screen);
    expect(zoomed.x, closeTo(world.x, 1e-9));
    expect(zoomed.y, closeTo(world.y, 1e-9));
  });
  test('visible query excludes distant objects after movement and removal', () {
    final scene = CanvasScene.fromJson({'schemaVersion': 1, 'elements': []});
    for (var i = 0; i < 10000; i++) {
      scene.put(card('$i', i * 600));
    }
    expect(scene.query(const CanvasBounds(0, 0, 400, 400)).map((e) => e.id), [
      '0',
    ]);
    scene.put(card('0', -5000));
    expect(scene.query(const CanvasBounds(0, 0, 400, 400)), isEmpty);
    scene.remove('1');
    expect(scene['1'], isNull);
  });
  test(
    'one gesture undo, cancellation and reference-only removal survive JSON',
    () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'extension': {'keep': true},
        'elements': [card('a', 0).data, card('b', 600).data],
      });
      final history = CanvasHistory(scene);
      history.put(scene['a']!.translated(const CanvasPoint(20, 20)));
      history.put(scene['a']!.translated(const CanvasPoint(20, 20)));
      history.commit();
      expect(history.scene['a']!.x, 40);
      history.undo();
      expect(history.scene['a']!.x, 0);
      history.redo();
      expect(history.scene['a']!.x, 40);
      history.put(card('a', 999));
      history.cancel();
      expect(history.scene['a']!.x, 40);
      history.remove('a');
      history.commit();
      final reopened = CanvasScene.fromJson(
        jsonDecode(jsonEncode(history.scene.toJson())) as Map<String, dynamic>,
      );
      expect(reopened['b']!.objectId, 'shared');
      expect(reopened.toJson()['extension'], {'keep': true});
    },
  );
  test('unknown future scenes stay read-only and preserve their envelope', () {
    final data = {
      'schemaVersion': 99,
      'elements': [
        {'id': 'plugin', 'type': 'future', 'new': 42},
      ],
      'unknown': 'preserve',
    };
    final scene = CanvasScene.fromJson(data);
    scene.put(card('x', 0));
    scene.remove('plugin');
    expect(scene.readOnly, isTrue);
    expect(scene.toJson(), data);
  });
  test('image references round trip without owning attachment bytes', () {
    final scene = CanvasScene.fromJson({
      'elements': [
        {
          'id': 'image',
          'type': 'image',
          'x': 0,
          'y': 0,
          'width': 320,
          'height': 180,
          'contentRef': 'Attachments/hash/image.png',
        },
      ],
    });
    expect(
      scene.query(const CanvasBounds(0, 0, 500, 500)).single.type,
      'image',
    );
    expect(
      scene.toJson()['elements'][0]['contentRef'],
      'Attachments/hash/image.png',
    );
  });
}
