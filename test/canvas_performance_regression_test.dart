import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';

CanvasElement node(String id, double x) => CanvasElement({
  'id': id,
  'type': 'rectangle',
  'x': x,
  'y': 0.0,
  'width': 100.0,
  'height': 80.0,
});

void expectMatchesReopened(CanvasScene scene) {
  final reopened = CanvasScene.fromJson(scene.toJson());
  final a = scene.contentBounds, b = reopened.contentBounds;
  expect(a == null, b == null);
  if (a != null && b != null) {
    expect(
      [a.left, a.top, a.width, a.height],
      [b.left, b.top, b.width, b.height],
    );
  }
  for (var x = -400.0; x < 2000; x += 160) {
    final view = CanvasBounds(x, -100, 150, 300);
    expect(
      scene.query(view).map((e) => e.id),
      reopened.query(view).map((e) => e.id),
    );
    expect(
      scene.hit(CanvasPoint(x, 40))?.id,
      reopened.hit(CanvasPoint(x, 40))?.id,
    );
  }
}

void main() {
  test('measure minimap recording cost on a 10000-element board', () {
    final scene = CanvasScene.fromJson({
      'schemaVersion': 1,
      'elements': [
        for (var i = 0; i < 10000; i++)
          node('$i', (i % 100) * 200.0).copy({'y': (i ~/ 100) * 120.0}).data,
      ],
    });
    final cache = CanvasPictureCache();
    addTearDown(cache.dispose);
    final colors = ColorScheme.fromSeed(seedColor: Colors.purple);
    int record(CanvasPictureCache? cache) {
      final watch = Stopwatch()..start();
      for (var i = 0; i < 60; i++) {
        final recorder = ui.PictureRecorder();
        CanvasMinimapPainter(
          scene: scene,
          camera: CanvasCamera(x: i.toDouble()),
          viewportSize: const Size(800, 600),
          colors: colors,
          pictureCache: cache,
        ).paint(Canvas(recorder), const Size(160, 110));
        recorder.endRecording().dispose();
      }
      return watch.elapsedMicroseconds;
    }

    final uncached = record(null), cached = record(cache);
    // Informational measurement; correctness tests never depend on wall time.
    debugPrint(
      'Minimap 10000 elements, 60 pans: uncached=$uncached us cached=$cached us',
    );
  });

  testWidgets(
    'minimap cache preserves pixels through pan, edits and theme changes',
    (tester) async {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [node('a', 0).data, node('b', 1200).data],
      });
      final cache = CanvasPictureCache();
      addTearDown(cache.dispose);
      final colors = ColorScheme.fromSeed(seedColor: Colors.purple);
      Future<List<int>> pixels(CanvasMinimapPainter painter) async {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(160, 110));
        final picture = recorder.endRecording();
        final image = await picture.toImage(160, 110);
        final bytes = (await image.toByteData())!.buffer.asUint8List().toList();
        image.dispose();
        picture.dispose();
        return bytes;
      }

      await tester.runAsync(() async {
        for (var i = 0; i < 6; i++) {
          if (i == 3) scene.put(node('a', 400));
          CanvasMinimapPainter painter(CanvasPictureCache? c) =>
              CanvasMinimapPainter(
                scene: scene,
                camera: CanvasCamera(x: i * 20.0),
                viewportSize: const Size(800, 600),
                colors: i > 3
                    ? ColorScheme.fromSeed(seedColor: Colors.teal)
                    : colors,
                searchMatchIds: i > 1 ? {'a'} : {},
                activeSearchMatchId: i > 2 ? 'a' : null,
                pictureCache: c,
              );
          expect(await pixels(painter(cache)), await pixels(painter(null)));
        }
      });
      final before = CanvasMinimapPainter(
        scene: scene,
        camera: const CanvasCamera(),
        viewportSize: const Size(800, 600),
        colors: colors,
      );
      scene.put(node('a', 700));
      final after = CanvasMinimapPainter(
        scene: scene,
        camera: const CanvasCamera(),
        viewportSize: const Size(800, 600),
        colors: colors,
      );
      expect(after.shouldRepaint(before), isTrue);
    },
  );

  test(
    'connector index stays correct across retarget, hide, delete and undo',
    () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          node('a', 0).data,
          node('b', 600).data,
          node('c', 1200).data,
          for (final type in ['connector', 'line', 'arrow'])
            {'id': type, 'type': type, 'startId': 'a', 'endId': 'b'},
          {
            'id': 'missing',
            'type': 'connector',
            'startId': 'absent',
            'endId': 'a',
          },
        ],
      });
      final history = CanvasHistory(scene);
      final random = Random(42);
      for (var i = 0; i < 50; i++) {
        history.put(node('a', random.nextDouble() * 1500 - 300));
        history.put(
          scene['connector']!.copy({
            'endId': i.isEven ? 'c' : 'b',
            'hidden': i % 3 == 0,
          }),
        );
        if (i.isEven) {
          history.remove('b');
          history.put(node('absent', 300));
        } else {
          history.put(node('b', 600));
          history.remove('absent');
        }
        history.commit();
        expectMatchesReopened(scene);
        history.undo();
        expectMatchesReopened(scene);
        history.redo();
        expectMatchesReopened(scene);
      }
      scene.put(node('connector', 900)); // Same ID, no longer a connector.
      scene.remove('line');
      scene.put(node('a', -200));
      expectMatchesReopened(scene);
    },
  );

  test('bounds cache invalidates on removal, visibility and empty scenes', () {
    final scene = CanvasScene.fromJson({'schemaVersion': 1, 'elements': []});
    expect(scene.contentBounds, isNull);
    scene.put(node('a', 0));
    expect(scene.contentBounds!.right, 100);
    scene.put(node('a', 700));
    expect(scene.contentBounds!.right, 800);
    scene.put(scene['a']!.copy({'hidden': true}));
    expect(scene.contentBounds, isNull);
    scene.put(node('a', -500));
    expect(scene.contentBounds!.left, -500);
    scene.remove('a');
    expect(scene.contentBounds, isNull);
  });

  testWidgets('cached rich card painting is pixel-identical to a cold cache', (
    tester,
  ) async {
    final scene = CanvasScene.fromJson({
      'schemaVersion': 1,
      'elements': [
        {
          'id': 'note',
          'type': 'sticky',
          'x': 10.0,
          'y': 10.0,
          'width': 280.0,
          'height': 300.0,
          'text': '# Heading\n- [x] Done\n- [ ] Next\n\$x^2\$\n> Quote',
        },
      ],
    });
    final cache = CanvasTextCache();
    addTearDown(cache.dispose);
    Future<List<int>> pixels() async {
      final recorder = ui.PictureRecorder();
      OrbitCanvasPainter(
        scene: scene,
        camera: const CanvasCamera(),
        selection: {},
        objects: {},
        colors: ColorScheme.fromSeed(seedColor: Colors.purple),
        textCache: cache,
      ).paint(Canvas(recorder), const Size(320, 340));
      final picture = recorder.endRecording();
      final image = await picture.toImage(320, 340);
      final bytes = (await image.toByteData())!.buffer.asUint8List().toList();
      image.dispose();
      picture.dispose();
      return bytes;
    }

    await tester.runAsync(() async {
      expect(await pixels(), await pixels());
    });
    final old = cache.richLines('# Old');
    expect(cache.richLines('# New').single.contentText, 'New');
    for (var i = 0; i < 300; i++) {
      cache.richLines('# $i');
    }
    expect(cache.richLines('# Old').single.contentText, old.single.contentText);
    expect(() => cache.richLines('hello').clear(), throwsUnsupportedError);
  });
}
