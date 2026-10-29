import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_live_ink.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/canvas/canvas_scene_viewport.dart';
import 'package:orbit_note/features/canvas/canvas_presence_overlay.dart';
import 'pen_pdf_performance_test.dart' show stroke;

class _CountPainter extends OrbitCanvasPainter {
  _CountPainter({
    required super.scene,
    required super.camera,
    required super.paintElements,
    required super.textCache,
    required this.count,
    super.semanticColors,
  }) : super(
         selection: {},
         objects: {},
         colors: _colors,
         transparentBackground: true,
       );
  final VoidCallback count;
  @override
  void paint(Canvas canvas, Size size) {
    if (paintElements?.isNotEmpty ?? true) count();
    super.paint(canvas, size);
  }
}

final _colors = ColorScheme.fromSeed(seedColor: Colors.purple);

void main() {
  test(
    'equivalent palettes retain layers; every real color change invalidates them',
    () {
      const colors = OrbitColors();
      final recreated = colors.copyWith();
      expect(recreated, colors);
      expect(recreated.hashCode, colors.hashCode);
      expect(colors.lerp(recreated, .5), colors);
      for (final role in colors.roles.keys) {
        final changed = colors.withOverrides({role: 0xff123456});
        expect(changed, isNot(colors), reason: role);
      }
    },
  );
  testWidgets(
    'pan, peer cursor and a local edit reuse unaffected drawing layers',
    (tester) async {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          stroke('ink', count: 150).copy({
            'width': 50.0,
            'points': [
              {'x': 0.0, 'y': 0.0},
              {'x': 50.0, 'y': 15.0},
            ],
          }).data,
        ],
      });
      final text = CanvasTextCache();
      addTearDown(text.dispose);
      var camera = const CanvasCamera();
      var paints = 0;
      final peers = ValueNotifier<List<Map<String, dynamic>>>(const []);
      addTearDown(peers.dispose);
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, set) {
              update = set;
              return SizedBox.expand(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CanvasSceneViewport(
                        scene: scene,
                        camera: camera,
                        builder: (view, elements) => _CountPainter(
                          scene: scene,
                          camera: view,
                          paintElements: elements,
                          textCache: text,
                          count: () => paints++,
                          semanticColors: const OrbitColors().copyWith(),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: ValueListenableBuilder(
                        valueListenable: peers,
                        builder: (_, value, _) => CanvasPresenceOverlay(
                          scene: scene,
                          camera: camera,
                          peers: value,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      final initial = paints;
      expect(initial, greaterThan(0));
      for (var i = 1; i <= 20; i++) {
        update(() => camera = CanvasCamera(x: i.toDouble(), y: 10));
        peers.value = [
          {'name': 'Peer $i', 'x': i.toDouble(), 'y': 40.0},
        ];
        await tester.pump();
      }
      expect(
        paints,
        initial,
        reason:
            'Camera and cursors must move retained layers without redrawing saved ink',
      );
      update(() => scene.put(scene['ink']!.copy({'color': 0xff445566})));
      await tester.pump();
      expect(
        paints - initial,
        1,
        reason: 'Only the tile containing the edited stroke changes',
      );
      update(() => camera = const CanvasCamera(zoom: 1.5));
      await tester.pump();
      expect(
        paints,
        greaterThan(initial + 1),
        reason: 'Zoom regenerates vectors at the new density',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tile edges preserve full-scene pen, highlight and paper pixels', (
    tester,
  ) async {
    final text = CanvasTextCache();
    addTearDown(text.dispose);
    final scene = CanvasScene.fromJson({
      'schemaVersion': 1,
      'elements': [
        for (final (i, style) in [
          'ballpoint',
          'fountain',
          'marker',
          'pencil',
          'brush',
          'calligraphy',
          'highlighter',
        ].indexed)
          stroke('$i', style: style, y: 50 + i * 65.0, count: 300).data,
      ],
    });
    final boundary = GlobalKey();
    Future<List<int>> capture(bool tiles, CanvasCamera camera) async {
      OrbitCanvasPainter painter(
        CanvasCamera view, [
        List<CanvasElement>? elements,
      ]) => OrbitCanvasPainter(
        scene: scene,
        camera: view,
        selection: {},
        objects: {},
        colors: _colors,
        textCache: text,
        paintElements: elements,
        transparentBackground: elements != null,
        backgroundStyle: 'grid',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: tiles
                ? CanvasSceneViewport(
                    scene: scene,
                    camera: camera,
                    builder: painter,
                  )
                : CustomPaint(
                    painter: painter(camera),
                    child: const SizedBox.expand(),
                  ),
          ),
        ),
      );
      await tester.pump();
      return (await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = (await image.toByteData())!.buffer.asUint8List().toList();
        image.dispose();
        return bytes;
      }))!;
    }

    for (final camera in [
      const CanvasCamera(),
      const CanvasCamera(x: -32, y: -16, zoom: 1.25),
      const CanvasCamera(x: 382, y: 120, zoom: 2),
    ]) {
      final full = await capture(false, camera);
      final tiled = await capture(true, camera);
      var largest = 0, changed = 0;
      for (var i = 0; i < full.length; i++) {
        final delta = (full[i] - tiled[i]).abs();
        if (delta > largest) largest = delta;
        if (delta > 2) {
          changed++;
        }
      }
      debugPrint(
        'Layer fidelity ${camera.x}/${camera.y}/${camera.zoom}: max channel delta=$largest, >2=$changed',
      );
      // Separate transforms can differ at isolated antialiased edge pixels.
      expect(
        largest,
        lessThanOrEqualTo(8),
        reason: 'No missing ink or palette changes',
      );
      expect(
        changed,
        lessThan(full.length ~/ 5000),
        reason: 'Only isolated subpixel AA rounding may differ',
      );
    }
  });

  testWidgets(
    'long live strokes match full renderer through append, ruler and restart',
    (tester) async {
      final cache = CanvasLiveInkCache();
      addTearDown(cache.dispose);
      Future<List<int>> paint(CanvasElement ink, bool cached) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        if (cached) {
          cache.paint(canvas, ink);
        } else {
          OrbitCanvasPainter.paintInk(canvas, ink, Color(ink.color));
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(850, 100);
        final bytes = (await image.toByteData())!.buffer.asUint8List().toList();
        image.dispose();
        picture.dispose();
        return bytes;
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
          cache.clear();
          final ink = stroke(style, style: style, count: 1200);
          final raw = ink.data['points'] as List;
          for (final count in [1, 2, 129, 259, 600, 1200, 2]) {
            final current = ink.copy({'points': raw.take(count).toList()});
            expect(
              await paint(current, true),
              await paint(current, false),
              reason: '$style at $count',
            );
            expect(cache.parsedSamples, count);
          }
          final next = stroke('next', style: style, count: 400);
          expect(await paint(next, true), await paint(next, false));
        }
      });
    },
  );
}
