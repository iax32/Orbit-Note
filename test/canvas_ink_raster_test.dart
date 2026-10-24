import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'pen_pdf_performance_test.dart' show stroke;

const _viewport = Size(420, 180);

ui.Picture record(
  CanvasScene scene,
  CanvasTextCache text,
  CanvasInkCache? cache, {
  double zoom = 1,
  double density = 1,
}) {
  final recorder = ui.PictureRecorder();
  OrbitCanvasPainter(
    scene: scene,
    camera: CanvasCamera(zoom: zoom),
    selection: {},
    objects: {},
    colors: ColorScheme.fromSeed(seedColor: Colors.purple),
    textCache: text,
    inkCache: cache,
    devicePixelRatio: density,
    transparentBackground: true,
    backgroundStyle: 'none',
  ).paint(Canvas(recorder)..scale(density), _viewport);
  return recorder.endRecording();
}

Future<int> alphaMass(ui.Picture picture, {double density = 1}) async {
  final image = await picture.toImage(
    (_viewport.width * density).ceil(),
    (_viewport.height * density).ceil(),
  );
  try {
    final data = (await image.toByteData())!.buffer.asUint8List();
    var sum = 0;
    for (var i = 3; i < data.length; i += 4) {
      sum += data[i];
    }
    return sum;
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  for (final style in [
    'ballpoint',
    'pencil',
    'brush',
    'calligraphy',
    'fountain',
    'marker',
    'highlighter',
  ]) {
    testWidgets(
      '$style previews retain stroke coverage and regenerate at zoom/device density',
      (tester) async {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [stroke('ink', style: style, count: 300).data],
        });
        final original = scene.toJson();
        final text = CanvasTextCache(),
            cache = CanvasInkCache(rasterizeSavedInk: true);
        addTearDown(text.dispose);
        addTearDown(cache.dispose);
        await tester.runAsync(() async {
          record(scene, text, cache).dispose();
          await cache.rasterizationIdle;
          expect(cache.rasterEntryCount, 1);
          for (final (zoom, density) in [(1.0, 1.0), (2.0, 1.0), (1.0, 3.0)]) {
            final hits = cache.rasterHits;
            record(scene, text, cache, zoom: zoom, density: density).dispose();
            if (zoom * density > 1) {
              // A lower-resolution old preview cannot be stretched for this frame.
              expect(cache.rasterHits, hits);
            }
            await cache.rasterizationIdle;
            final expected = await alphaMass(
              record(scene, text, null, zoom: zoom, density: density),
              density: density,
            );
            final actual = await alphaMass(
              record(scene, text, cache, zoom: zoom, density: density),
              density: density,
            );
            expect(expected, greaterThan(10000));
            expect(
              actual / expected,
              closeTo(1, .05),
              reason:
                  '$style zoom=$zoom density=$density coverage=$actual/$expected',
            );
            expect(cache.rasterHits, greaterThan(hits));
            expect(
              cache.retainedRasterPixels,
              lessThanOrEqualTo(cache.maxRasterPixels),
            );
          }
        });
        expect(scene.toJson(), original);
      },
    );
  }

  testWidgets(
    'native previews stay bounded and edits/undo never reuse stale pixels',
    (tester) async {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [stroke('ink', count: 300).data],
      });
      final text = CanvasTextCache(),
          cache = CanvasInkCache(
            rasterizeSavedInk: true,
            maxEntries: 2,
            maxRasterPixels: 200000,
          );
      addTearDown(text.dispose);
      addTearDown(cache.dispose);
      await tester.runAsync(() async {
        final history = CanvasHistory(scene);
        for (var i = 0; i < 5; i++) {
          history.put(scene['ink']!.copy({'color': 0xff112200 + i * 100}));
          history.commit();
          record(scene, text, cache).dispose();
          await cache.rasterizationIdle;
          expect(cache.entryCount, lessThanOrEqualTo(2));
          expect(cache.retainedRasterPixels, lessThanOrEqualTo(200000));
        }
        history.undo();
        final expected = await alphaMass(record(scene, text, null));
        record(scene, text, cache).dispose();
        await cache.rasterizationIdle;
        expect(
          await alphaMass(record(scene, text, cache)) / expected,
          closeTo(1, .05),
        );
        cache.clear();
        await cache.rasterizationIdle;
        expect(cache.entryCount, 0);
        expect(cache.retainedRasterPixels, 0);
        record(scene, text, cache).dispose();
        await cache.rasterizationIdle;
        expect(cache.rasterEntryCount, 1);
      });
    },
  );

  testWidgets(
    'late image completion after clear/dispose releases the image without notifying',
    (tester) async {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [stroke('ink', count: 300).data],
      });
      final text = CanvasTextCache();
      addTearDown(text.dispose);
      await tester.runAsync(() async {
        for (final dispose in [false, true]) {
          final result = Completer<ui.Image>();
          ui.Picture? pending;
          var width = 0, height = 0, notifications = 0;
          final cache = CanvasInkCache(
            rasterizeSavedInk: true,
            rasterize: (p, w, h) {
              pending = p;
              width = w;
              height = h;
              return result.future;
            },
          );
          cache.addListener(() => notifications++);
          record(scene, text, cache).dispose();
          final idle = cache.rasterizationIdle;
          if (dispose) {
            cache.dispose();
          } else {
            cache.clear();
          }
          final image = await pending!.toImage(width, height);
          result.complete(image);
          await idle;
          expect(image.debugDisposed, true);
          expect(notifications, 0);
          expect(cache.rasterEntryCount, 0);
          expect(cache.retainedRasterPixels, 0);
          cache.dispose();
        }
      });
    },
  );

  testWidgets(
    'allocation failure and oversized requests retain exact vector fallback',
    (tester) async {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [stroke('ink', count: 300).data],
      });
      final text = CanvasTextCache();
      addTearDown(text.dispose);
      var calls = 0;
      final cache = CanvasInkCache(
        rasterizeSavedInk: true,
        rasterize: (_, _, _) async {
          calls++;
          throw StateError('Synthetic backend allocation failure');
        },
      );
      addTearDown(cache.dispose);
      await tester.runAsync(() async {
        record(scene, text, cache).dispose();
        await cache.rasterizationIdle;
        final expected = await alphaMass(record(scene, text, null));
        expect(await alphaMass(record(scene, text, cache)), expected);
        expect(calls, 1); // No allocation storm on repaint.
        record(scene, text, cache, density: 1e308).dispose();
        expect(calls, 1);
      });
    },
  );

  testWidgets(
    'a saturated visible set settles instead of endlessly replacing its own previews',
    (tester) async {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          for (final id in ['a', 'b', 'c']) stroke(id, count: 300).data,
        ],
      });
      final text = CanvasTextCache();
      addTearDown(text.dispose);
      var allocations = 0, notifications = 0;
      final cache = CanvasInkCache(
        rasterizeSavedInk: true,
        maxRasterPixels: 30000,
        rasterize: (picture, width, height) {
          allocations++;
          return picture.toImage(width, height);
        },
      );
      cache.addListener(() => notifications++);
      addTearDown(cache.dispose);
      await tester.runAsync(() async {
        for (var frame = 0; frame < 20; frame++) {
          record(scene, text, cache).dispose();
          await cache.rasterizationIdle;
          expect(cache.retainedRasterPixels, lessThanOrEqualTo(30000));
        }
        expect(allocations, 1);
        expect(notifications, 1);
        scene.remove('a');
        record(scene, text, cache).dispose();
        await cache.rasterizationIdle;
        expect(allocations, 2); // Offscreen/deleted preview may now be evicted.
        expect(cache.rasterEntryCount, 1);
      });
    },
  );
}
