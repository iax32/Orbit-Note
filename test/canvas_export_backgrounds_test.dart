import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/canvas_svg.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vector SVG Export Engine (CAN-14, PORT-05, INK-10)', () {
    test('canvasToSvg generates valid XML SVG with header and defs', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'r1',
            'type': 'rectangle',
            'x': 100,
            'y': 100,
            'width': 200,
            'height': 150,
            'color': 0xff3b82f6,
          },
        ],
      });

      final svg = canvasToSvg(scene);
      expect(
        svg.startsWith(
          '<?xml version="1.0" encoding="UTF-8" standalone="no"?>',
        ),
        isTrue,
      );
      expect(svg.contains('<svg xmlns="http://www.w3.org/2000/svg"'), isTrue);
      expect(svg.contains('viewBox="'), isTrue);
      expect(svg.contains('</svg>'), isTrue);
      expect(svg.contains('<rect'), isTrue);
    });

    test(
      'canvasToSvg renders standard shapes, text, sticky, card, and section',
      () {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'r1',
              'type': 'rectangle',
              'x': 20,
              'y': 20,
              'width': 100,
              'height': 60,
              'text': 'Box',
              'color': 0xff3b82f6,
            },
            {
              'id': 'e1',
              'type': 'ellipse',
              'x': 140,
              'y': 20,
              'width': 80,
              'height': 80,
              'color': 0xff22c55e,
            },
            {
              'id': 'd1',
              'type': 'diamond',
              'x': 240,
              'y': 20,
              'width': 70,
              'height': 70,
              'color': 0xffeab308,
            },
            {
              'id': 't1',
              'type': 'text',
              'x': 340,
              'y': 20,
              'width': 100,
              'height': 40,
              'text': 'Header 1\nSubheader',
              'color': 0xffffffff,
            },
            {
              'id': 's1',
              'type': 'sticky',
              'x': 20,
              'y': 120,
              'width': 140,
              'height': 120,
              'text': 'Idea sticky note',
              'color': 0xfffef08a,
            },
            {
              'id': 'c1',
              'type': 'card',
              'x': 180,
              'y': 120,
              'width': 180,
              'height': 100,
              'data': {
                'title': 'Feature Card',
                'subtitle': 'Details here',
                'badge': 'TASK',
              },
              'color': 0xffa855f7,
            },
            {
              'id': 'sec1',
              'type': 'section',
              'x': 20,
              'y': 260,
              'width': 300,
              'height': 40,
              'text': 'Sprint Section',
              'color': 0xff06b6d4,
            },
            {
              'id': 'sw1',
              'type': 'swatch',
              'x': 340,
              'y': 120,
              'width': 90,
              'height': 100,
              'color': 0xffec4899,
            },
            {
              'id': 'col1',
              'type': 'column',
              'x': 20,
              'y': 320,
              'width': 220,
              'height': 300,
              'text': 'In Progress',
              'color': 0xff64748b,
            },
          ],
        });

        final svg = canvasToSvg(scene);
        expect(svg.contains('<ellipse'), isTrue);
        expect(svg.contains('<polygon'), isTrue);
        expect(svg.contains('Header 1'), isTrue);
        expect(svg.contains('Subheader'), isTrue);
        expect(svg.contains('Idea sticky note'), isTrue);
        expect(svg.contains('FEATURE CARD'), isFalse);
        expect(svg.contains('Feature Card'), isTrue);
        expect(svg.contains('SPRINT SECTION'), isTrue);
        expect(svg.contains('#ec4899'), isTrue);
        expect(svg.contains('In Progress'), isTrue);
      },
    );

    test('canvasToSvg renders ink and highlighter paths with opacity', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'ink1',
            'type': 'ink',
            'x': 10,
            'y': 10,
            'width': 100,
            'height': 50,
            'strokeWidth': 4.0,
            'color': 0xff3b82f6,
            'points': [
              {'x': 0.0, 'y': 0.0},
              {'x': 50.0, 'y': 25.0},
              {'x': 100.0, 'y': 50.0},
            ],
          },
          {
            'id': 'hl1',
            'type': 'ink',
            'x': 10,
            'y': 70,
            'width': 120,
            'height': 30,
            'strokeWidth': 22.0,
            'color': 0xffeab308,
            'isHighlighter': true,
            'points': [
              {'x': 0.0, 'y': 10.0},
              {'x': 60.0, 'y': 10.0},
              {'x': 120.0, 'y': 10.0},
            ],
          },
        ],
      });

      final svg = canvasToSvg(scene);
      expect(svg.contains('stroke-linecap="round"'), isTrue);
      expect(svg.contains('opacity="1.0"'), isTrue);
      expect(svg.contains('opacity="0.38"'), isTrue);
    });

    test('canvasToSvg renders connectors with routing, styles and markers', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'b1',
            'type': 'rectangle',
            'x': 50,
            'y': 50,
            'width': 100,
            'height': 60,
          },
          {
            'id': 'b2',
            'type': 'rectangle',
            'x': 300,
            'y': 50,
            'width': 100,
            'height': 60,
          },
          {
            'id': 'conn1',
            'type': 'connector',
            'startId': 'b1',
            'endId': 'b2',
            'strokeStyle': 'dashed',
            'startMarker': 'dot',
            'endMarker': 'arrow',
            'routing': 'curved',
            'text': 'leads to',
            'color': 0xff3b82f6,
          },
        ],
      });

      final svg = canvasToSvg(scene);
      expect(svg.contains('stroke-dasharray="8,5"'), isTrue);
      expect(svg.contains('<circle'), isTrue);
      expect(svg.contains('<polyline'), isTrue);
      expect(svg.contains('leads to'), isTrue);
    });

    test(
      'canvasToSvg supports transparent background and element filtering',
      () {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'e1',
              'type': 'rectangle',
              'x': 0,
              'y': 0,
              'width': 100,
              'height': 100,
              'color': 0xff3b82f6,
            },
            {
              'id': 'e2',
              'type': 'ellipse',
              'x': 200,
              'y': 200,
              'width': 100,
              'height': 100,
              'color': 0xff22c55e,
            },
          ],
        });

        // Transparent
        final svgTransparent = canvasToSvg(scene, transparent: true);
        expect(svgTransparent.contains('<rect x="'), isTrue);
        expect(svgTransparent.contains('fill="#121218"'), isFalse);

        // Filtered
        final svgFiltered = canvasToSvg(scene, elementIds: ['e1']);
        expect(svgFiltered.contains('<rect'), isTrue);
        expect(svgFiltered.contains('<ellipse'), isFalse);
      },
    );
  });

  group('Raster PNG Export Engine (PORT-05, INK-10)', () {
    test('renderCanvasToPng outputs valid PNG byte data', () async {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'r1',
            'type': 'rectangle',
            'x': 20,
            'y': 20,
            'width': 120,
            'height': 80,
            'color': 0xff3b82f6,
          },
        ],
      });

      final bytes = await renderCanvasToPng(
        scene: scene,
        colors: const ColorScheme.dark(),
        backgroundStyle: 'grid',
        scale: 1.0,
      );

      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(100));
      // Standard PNG 8-byte header: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x4E);
      expect(bytes[3], 0x47);
    });

    test(
      'renderCanvasToPng supports transparent background and scale factor',
      () async {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'r1',
              'type': 'rectangle',
              'x': 0,
              'y': 0,
              'width': 100,
              'height': 100,
            },
          ],
        });

        final bytesTransparent = await renderCanvasToPng(
          scene: scene,
          colors: const ColorScheme.dark(),
          backgroundStyle: 'dots',
          scale: 2.0,
          transparent: true,
        );

        expect(bytesTransparent, isNotNull);
        expect(bytesTransparent![0], 0x89);
      },
    );
  });

  group('Canvas Background Paper Presets (INK-07)', () {
    test('OrbitCanvasPainter paints graph paper preset without errors', () {
      final scene = CanvasScene.fromJson({'schemaVersion': 1, 'elements': []});
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 800, 600));
      final textCache = CanvasTextCache();

      final painter = OrbitCanvasPainter(
        scene: scene,
        camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
        selection: const {},
        objects: const {},
        colors: const ColorScheme.dark(),
        backgroundStyle: 'graph',
        textCache: textCache,
      );

      expect(
        () => painter.paint(canvas, const Size(800, 600)),
        returnsNormally,
      );
      textCache.dispose();
    });

    test('OrbitCanvasPainter paints cornell notes preset without errors', () {
      final scene = CanvasScene.fromJson({'schemaVersion': 1, 'elements': []});
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 800, 600));
      final textCache = CanvasTextCache();

      final painter = OrbitCanvasPainter(
        scene: scene,
        camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
        selection: const {},
        objects: const {},
        colors: const ColorScheme.dark(),
        backgroundStyle: 'cornell',
        textCache: textCache,
      );

      expect(
        () => painter.paint(canvas, const Size(800, 600)),
        returnsNormally,
      );
      textCache.dispose();
    });
  });

  group('Canvas Editor Export Dialog & UI Actions', () {
    testWidgets('export button is present in toolbar and opens export dialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sceneData = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'r1',
            'type': 'rectangle',
            'x': 50,
            'y': 50,
            'width': 100,
            'height': 100,
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board-export-test',
              data: sceneData,
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find export icon button
      final exportBtn = find.byTooltip('Export canvas (PNG, SVG, JSON)');
      expect(exportBtn, findsOneWidget);

      // Tap export button
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      // Verify Export Canvas dialog appears
      expect(find.text('Export Canvas'), findsOneWidget);
      expect(find.text('SCOPE'), findsOneWidget);
      expect(find.text('FORMAT'), findsOneWidget);
      expect(find.text('PNG Image'), findsOneWidget);
      expect(find.text('Vector SVG'), findsOneWidget);
      expect(find.text('JSON Backup'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel to dismiss
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Export Canvas'), findsNothing);
    });

    testWidgets('paper style popup menu contains graph and cornell options', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sceneData = {'schemaVersion': 1, 'elements': []};

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board-style-test',
              data: sceneData,
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find paper style button
      final paperBtn = find.byTooltip('Canvas paper style');
      expect(paperBtn, findsOneWidget);

      await tester.tap(paperBtn);
      await tester.pumpAndSettle();

      // Verify new presets exist
      expect(find.text('Engineering graph paper'), findsOneWidget);
      expect(find.text('Cornell Notes layout'), findsOneWidget);
    });
  });
}
