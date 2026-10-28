import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_live_ink.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'pen_pdf_performance_test.dart' show stroke;

void main() {
  test(
    'dense visible ink keeps a stable display-list working set during pans',
    () {
      final ink = [for (var i = 0; i < 1500; i++) stroke('$i', count: 24)];
      (int, int) run(bool stable) {
        final cache = CanvasInkCache(maxEntries: stable ? 1024 : 256);
        if (stable) cache.retainVisible(ink);
        final watch = Stopwatch()..start();
        for (var frame = 0; frame < 20; frame++) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          for (final element in ink) {
            cache.draw(
              canvas,
              element,
              const Color(0xff8b7cf6),
              (target) => OrbitCanvasPainter.paintInk(
                target,
                element,
                const Color(0xff8b7cf6),
              ),
            );
          }
          recorder.endRecording().dispose();
        }
        watch.stop();
        final result = (cache.recordingCount, watch.elapsedMicroseconds);
        expect(cache.entryCount, lessThanOrEqualTo(cache.maxEntries));
        expect(cache.retainedSamples, lessThanOrEqualTo(cache.maxSamples));
        cache.dispose();
        return result;
      }

      final baseline = run(false), fixed = run(true);
      expect(baseline.$1, 30000);
      expect(fixed.$1, 1024);
      debugPrint(
        '1500 strokes / 20 pan paints: LRU ${baseline.$1} recordings, ${baseline.$2} us; stable ${fixed.$1} recordings, ${fixed.$2} us',
      );
    },
  );
  testWidgets('isolated live layer preserves pressure and pen pixels at zoom', (
    tester,
  ) async {
    final changes = ChangeNotifier();
    addTearDown(changes.dispose);
    final text = CanvasTextCache();
    addTearDown(text.dispose);
    final scene = CanvasScene.fromJson({'schemaVersion': 1, 'elements': []});
    const camera = CanvasCamera(x: -5, y: -8, zoom: 1.5);
    Future<List<int>> pixels(CustomPainter painter) async {
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(400, 120));
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 120);
      final data = (await image.toByteData())!.buffer.asUint8List().toList();
      image.dispose();
      picture.dispose();
      return data;
    }

    await tester.runAsync(() async {
      for (final style in [
        'ballpoint',
        'fountain',
        'marker',
        'pencil',
        'brush',
        'calligraphy',
        'highlighter',
      ]) {
        final ink = stroke(style, count: 120, style: style);
        final before = await pixels(
          OrbitCanvasPainter(
            scene: scene,
            camera: camera,
            selection: {},
            objects: {},
            colors: ColorScheme.fromSeed(seedColor: Colors.purple),
            textCache: text,
            preview: ink,
            transparentBackground: true,
          ),
        );
        final after = await pixels(
          CanvasLiveInkPainter(
            changes: changes,
            stroke: () => ink,
            camera: () => camera,
          ),
        );
        expect(after, before, reason: style);
      }
    });
  });
}
