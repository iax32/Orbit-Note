import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/notes/rich/math_grid_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Canvas Grid Presets Rendering (CAN-02, CAN-14)', () {
    const allPresets = [
      'dots',
      'grid',
      'graph',
      'cornell',
      'lines',
      'ruled',
      'isometric',
      'cross',
      'hex',
      'blueprint',
      'blueprint_classic',
      'music',
      'ledger',
      'triangular',
      'blank',
    ];

    for (final preset in allPresets) {
      test(
        'OrbitCanvasPainter paints "$preset" grid preset without errors',
        () {
          final scene = CanvasScene.fromJson({
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
          });
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1000, 700));
          final textCache = CanvasTextCache();

          // Test at default zoom
          final painter = OrbitCanvasPainter(
            scene: scene,
            camera: const CanvasCamera(x: 100, y: 150, zoom: 1.0),
            selection: const {},
            objects: const {},
            colors: const ColorScheme.dark(),
            backgroundStyle: preset,
            textCache: textCache,
          );

          expect(
            () => painter.paint(canvas, const Size(1000, 700)),
            returnsNormally,
          );

          // Test zoomed in
          final zoomedPainter = OrbitCanvasPainter(
            scene: scene,
            camera: const CanvasCamera(x: -50, y: -80, zoom: 2.5),
            selection: const {},
            objects: const {},
            colors: const ColorScheme.dark(),
            backgroundStyle: preset,
            textCache: textCache,
          );
          expect(
            () => zoomedPainter.paint(canvas, const Size(1000, 700)),
            returnsNormally,
          );

          // Test zoomed out
          final zoomedOutPainter = OrbitCanvasPainter(
            scene: scene,
            camera: const CanvasCamera(x: 500, y: 300, zoom: 0.25),
            selection: const {},
            objects: const {},
            colors: const ColorScheme.dark(),
            backgroundStyle: preset,
            textCache: textCache,
          );
          expect(
            () => zoomedOutPainter.paint(canvas, const Size(1000, 700)),
            returnsNormally,
          );

          textCache.dispose();
        },
      );
    }

    test(
      'renderCanvasToPng exports raster PNG with new grid presets',
      () async {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'c1',
              'type': 'card',
              'x': 50,
              'y': 50,
              'width': 200,
              'height': 120,
              'text': 'Test Card',
            },
          ],
        });

        for (final style in [
          'cross',
          'hex',
          'blueprint',
          'music',
          'ledger',
          'triangular',
        ]) {
          final pngBytes = await renderCanvasToPng(
            scene: scene,
            colors: const ColorScheme.dark(),
            backgroundStyle: style,
            scale: 1.0,
          );
          expect(pngBytes, isNotNull);
          expect(pngBytes!.isNotEmpty, isTrue);
          // PNG header signature: 0x89, 0x50, 0x4E, 0x47
          expect(pngBytes[0], 0x89);
          expect(pngBytes[1], 0x50);
          expect(pngBytes[2], 0x4E);
          expect(pngBytes[3], 0x47);
        }
      },
    );
  });

  group('Canvas Editor Paper Style Menu', () {
    testWidgets(
      'Paper style menu contains all original and newly added grid presets',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sceneData = {'schemaVersion': 1, 'elements': []};
        String? emittedStyle;

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'board-grid-presets-test',
                data: sceneData,
                objects: const [],
                onOpenObject: (_) {},
                onChanged: (data) =>
                    emittedStyle = data['backgroundStyle'] as String?,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final paperBtn = find.byTooltip('Canvas paper style');
        expect(paperBtn, findsOneWidget);

        await tester.tap(paperBtn);
        await tester.pumpAndSettle();

        // Original 8 presets
        expect(find.text('Dot grid (Default)'), findsOneWidget);
        expect(find.text('Standard grid'), findsOneWidget);
        expect(find.text('Engineering graph paper'), findsOneWidget);
        expect(find.text('Cornell Notes layout'), findsOneWidget);
        expect(find.text('Ruled notebook lines'), findsOneWidget);
        expect(find.text('Student / Legal ruled margin'), findsOneWidget);
        expect(find.text('Isometric 3D grid'), findsOneWidget);
        expect(find.text('Blank paper'), findsOneWidget);

        // New 6 presets
        expect(find.text('Cross / Reticle grid (+)'), findsOneWidget);
        expect(find.text('Hexagonal / Honeycomb grid'), findsOneWidget);
        expect(find.text('Architectural blueprint grid'), findsOneWidget);
        expect(
          find.text('Traditional blueprint · white drawing'),
          findsOneWidget,
        );
        expect(find.text('Music manuscript staff'), findsOneWidget);
        expect(find.text('Columnar / Accounting ledger'), findsOneWidget);
        expect(find.text('Equilateral triangular grid'), findsOneWidget);

        // Select Cross grid
        await tester.tap(find.text('Cross / Reticle grid (+)'));
        await tester.pumpAndSettle();

        expect(emittedStyle, 'cross');
      },
    );

    testWidgets(
      'architectural drafting preset selects blueprint and white pen',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        Map<String, dynamic>? emitted;
        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'board-architectural-preset-test',
                data: const {'schemaVersion': 1, 'elements': <dynamic>[]},
                objects: const [],
                onOpenObject: (_) {},
                onChanged: (data) => emitted = data,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Canvas paper style'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Architectural drafting preset · white pen'),
        );
        await tester.pumpAndSettle();

        expect(emitted?['backgroundStyle'], 'blueprint');
        expect(find.byTooltip('Color'), findsOneWidget);
        final colorButton = tester.widget<PopupMenuButton<int>>(
          find.byWidgetPredicate(
            (widget) =>
                widget is PopupMenuButton<int> && widget.tooltip == 'Color',
          ),
        );
        expect((colorButton.icon as Icon).color, const Color(0xfff7fbff));
        expect(find.byTooltip('Pen style (ballpoint)'), findsOneWidget);
      },
    );
  });

  group('Math Grid Editor Presets', () {
    test('mathGridPresets has expected default configurations', () {
      expect(mathGridPresets.isNotEmpty, isTrue);
      expect(mathGridPresets.any((p) => p.name == '2×2 Identity'), isTrue);
      expect(mathGridPresets.any((p) => p.name == '3×3 Identity'), isTrue);
      expect(
        mathGridPresets.any((p) => p.name == '2D Rotation Matrix'),
        isTrue,
      );
      expect(mathGridPresets.any((p) => p.name == '3D Column Vector'), isTrue);
      expect(mathGridPresets.any((p) => p.name == '2-Case Piecewise'), isTrue);
      expect(mathGridPresets.any((p) => p.name == '3-Case Piecewise'), isTrue);
      expect(mathGridPresets.any((p) => p.name == '2×2 Linear System'), isTrue);
    });

    testWidgets('math grid presets button populates matrix structure', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showMathGridEditor(context);
                },
                child: const Text('Open Grid Builder'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Grid Builder'));
      await tester.pumpAndSettle();

      // Verify preset button is present
      final presetBtn = find.byKey(const ValueKey('math-grid-preset-button'));
      expect(presetBtn, findsOneWidget);

      // Tap presets button
      await tester.tap(presetBtn);
      await tester.pumpAndSettle();

      // Tap 2×2 Identity preset
      final identityItem = find.text('2×2 Identity');
      expect(identityItem, findsOneWidget);
      await tester.tap(identityItem);
      await tester.pumpAndSettle();

      // Apply grid
      await tester.tap(find.text('Apply grid'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result, contains(r'\begin{pmatrix}'));
      expect(result, contains(r'1 & 0'));
      expect(result, contains(r'0 & 1'));
      expect(result, contains(r'\end{pmatrix}'));
    });
  });
}
