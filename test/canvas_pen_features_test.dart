import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

void main() {
  group('Canvas Pen Features', () {
    testWidgets(
      'toolbar displays pen style, stroke width, and palm rejection controls',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Map<String, dynamic> canvasData = {
          'schemaVersion': 1,
          'elements': <Map<String, dynamic>>[],
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'test-canvas',
                data: canvasData,
                objects: const [],
                onOpenObject: (_) {},
                onChanged: (data) => canvasData = data,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the Pen tool button
        await tester.tap(find.byTooltip('Draw and erase'));
        await tester.pumpAndSettle();
        final penButton = find.text('Pen (P)');
        expect(penButton, findsOneWidget);
        await tester.tap(penButton);
        await tester.pumpAndSettle();

        // Verify pen style selector exists
        expect(find.byTooltip('Pen style (ballpoint)'), findsOneWidget);
        // Verify stroke width selector exists
        expect(find.byTooltip('Pen thickness (3.0px)'), findsOneWidget);
        // Verify ruler assist button exists
        expect(
          find.byTooltip('Ruler / Straight line assist (Shift or R)'),
          findsOneWidget,
        );
        // Verify palm rejection / finger inking toggle exists
        expect(
          find.byTooltip('Palm rejection active: Stylus draws, finger pans'),
          findsOneWidget,
        );

        // Tap pen style selector to verify options
        await tester.tap(find.byTooltip('Pen style (ballpoint)'));
        await tester.pumpAndSettle();
        expect(find.text('Pencil'), findsOneWidget);
        expect(find.text('Calligraphy'), findsOneWidget);
        expect(find.text('Brush'), findsOneWidget);
        // Select pencil
        await tester.tap(find.text('Pencil'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Pen style (pencil)'), findsOneWidget);

        // Tap finger inking toggle to enable finger inking
        await tester.tap(
          find.byTooltip('Palm rejection active: Stylus draws, finger pans'),
        );
        await tester.pumpAndSettle();
        expect(
          find.byTooltip('Finger inking enabled (tap to pan only)'),
          findsOneWidget,
        );

        // Switch to Eraser tool
        await tester.tap(find.byTooltip('Draw and erase'));
        await tester.pumpAndSettle();
        final eraserButton = find.text('Erase strokes (E)');
        expect(eraserButton, findsOneWidget);
        await tester.tap(eraserButton);
        await tester.pumpAndSettle();

        // Verify eraser radius selector exists
        expect(find.byTooltip('Eraser radius (16px)'), findsOneWidget);
      },
    );

    testWidgets(
      'drawing an ink stroke creates element with pen style and pressure',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Map<String, dynamic> canvasData = {
          'schemaVersion': 1,
          'elements': <Map<String, dynamic>>[],
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'test-canvas',
                data: canvasData,
                objects: const [],
                onOpenObject: (_) {},
                onChanged: (data) => canvasData = data,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select pen tool
        await tester.tap(find.byTooltip('Draw and erase'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pen (P)'));
        await tester.pumpAndSettle();

        // Draw a stroke using touch/mouse
        final gesture = await tester.startGesture(
          const Offset(300, 300),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.moveTo(const Offset(350, 320));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.moveTo(const Offset(400, 310));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify an ink element was saved
        final elements = canvasData['elements'] as List;
        expect(elements.length, 1);
        final stroke = elements.first as Map<String, dynamic>;
        expect(stroke['type'], 'ink');
        expect(stroke['penStyle'], 'ballpoint');
        expect(stroke['strokeWidth'], 3.0);
        expect(stroke['points'], isA<List>());
        expect((stroke['points'] as List).length, greaterThanOrEqualTo(2));
      },
    );

    testWidgets(
      'dropping PdfQuoteDragData onto canvas creates a card element',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Map<String, dynamic> canvasData = {
          'schemaVersion': 1,
          'elements': <Map<String, dynamic>>[],
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'test-canvas',
                data: canvasData,
                objects: const [],
                onOpenObject: (_) {},
                onChanged: (data) => canvasData = data,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final quote = PdfQuoteDragData(
          objectId: 'pdf-doc-123',
          title: 'Deep Learning Book',
          page: 42,
          text: 'Neural networks can approximate any continuous function.',
        );

        // Find the DragTarget
        final dragTargetFinder = find.byType(DragTarget<Object>);
        expect(dragTargetFinder, findsOneWidget);

        final dragTarget = tester.widget<DragTarget<Object>>(dragTargetFinder);
        // Simulate drop on the DragTarget
        dragTarget.onAcceptWithDetails?.call(
          DragTargetDetails<Object>(
            data: quote,
            offset: const Offset(250, 200),
          ),
        );
        await tester.pumpAndSettle();

        final elements = canvasData['elements'] as List;
        expect(elements.length, 1);
        final card = elements.first as Map<String, dynamic>;
        expect(card['type'], 'card');
        expect(card['objectId'], 'pdf-doc-123');
        expect(card['text'], contains('Neural networks can approximate'));
        expect(card['text'], contains('Deep Learning Book, p. 42'));
        expect(card['data']['sourceId'], 'pdf-doc-123');
        expect(card['data']['page'], 42);
      },
    );

    testWidgets('OrbitCanvasPainter paints various pen styles without errors', (
      tester,
    ) async {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'ink-ballpoint',
            'type': 'ink',
            'penStyle': 'ballpoint',
            'strokeWidth': 2.0,
            'color': 0xff000000,
            'points': [
              {'x': 10, 'y': 10, 'p': 0.5},
              {'x': 20, 'y': 20, 'p': 0.8},
              {'x': 30, 'y': 30, 'p': 0.6},
            ],
          },
          {
            'id': 'ink-fountain',
            'type': 'ink',
            'penStyle': 'fountain',
            'strokeWidth': 4.0,
            'color': 0xff2563eb,
            'points': [
              {'x': 50, 'y': 50, 'p': 0.2},
              {'x': 70, 'y': 60, 'p': 0.9},
              {'x': 90, 'y': 70, 'p': 0.4},
            ],
          },
          {
            'id': 'ink-marker',
            'type': 'ink',
            'penStyle': 'marker',
            'strokeWidth': 8.0,
            'color': 0xff16a34a,
            'points': [
              {'x': 100, 'y': 100, 'p': 0.5},
              {'x': 120, 'y': 110, 'p': 0.5},
            ],
          },
          {
            'id': 'ink-pencil',
            'type': 'ink',
            'penStyle': 'pencil',
            'strokeWidth': 2.0,
            'color': 0xff475569,
            'points': [
              {'x': 130, 'y': 130, 'pressure': 0.4},
              {'x': 140, 'y': 135, 'pressure': 0.8},
              {'x': 150, 'y': 140, 'pressure': 0.6},
            ],
          },
          {
            'id': 'ink-calligraphy',
            'type': 'ink',
            'penStyle': 'calligraphy',
            'strokeWidth': 6.0,
            'color': 0xff7c3aed,
            'points': [
              {'x': 160, 'y': 160, 'p': 0.5},
              {'x': 180, 'y': 190, 'p': 0.7},
              {'x': 200, 'y': 170, 'p': 0.8},
            ],
          },
          {
            'id': 'ink-brush',
            'type': 'ink',
            'penStyle': 'brush',
            'strokeWidth': 10.0,
            'color': 0xffdc2626,
            'points': [
              {'x': 210, 'y': 210, 'pressure': 0.3},
              {'x': 240, 'y': 230, 'pressure': 0.9},
              {'x': 270, 'y': 220, 'pressure': 0.4},
            ],
          },
          {
            'id': 'ink-highlighter',
            'type': 'ink',
            'penStyle': 'highlighter',
            'strokeWidth': 16.0,
            'color': 0xfffacc15,
            'points': [
              {'x': 150, 'y': 150, 'p': 0.5},
              {'x': 200, 'y': 150, 'p': 0.5},
            ],
          },
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CustomPaint(
              size: const Size(800, 600),
              painter: OrbitCanvasPainter(
                scene: scene,
                camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
                selection: const {},
                objects: const {},
                colors: orbitDarkTheme().colorScheme,
                textCache: CanvasTextCache(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('ruler mode produces 2-point straight line ink strokes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Map<String, dynamic> canvasData = {
        'schemaVersion': 1,
        'elements': <Map<String, dynamic>>[],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'ruler-canvas',
              data: canvasData,
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (data) => canvasData = data,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select Pen tool
      await tester.tap(find.byTooltip('Draw and erase'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pen (P)'));
      await tester.pumpAndSettle();

      // Tap Ruler toggle button
      final rulerButton = find.byTooltip(
        'Ruler / Straight line assist (Shift or R)',
      );
      expect(rulerButton, findsOneWidget);
      await tester.tap(rulerButton);
      await tester.pumpAndSettle();

      // Verify ruler mode active tooltip
      expect(
        find.byTooltip('Ruler mode active: Drawing straight lines'),
        findsOneWidget,
      );

      // Draw a multi-segment stroke
      final gesture = await tester.startGesture(
        const Offset(200, 200),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(const Offset(250, 240));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(const Offset(320, 280));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify ink element was created with exactly 2 points (straight line)
      final elements = canvasData['elements'] as List;
      expect(elements.length, 1);
      final stroke = elements.first as Map<String, dynamic>;
      expect(stroke['type'], 'ink');
      final pts = stroke['points'] as List;
      expect(pts.length, 2);
    });

    testWidgets('multi-touch pinch-to-zoom updates camera zoom', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Map<String, dynamic>? cameraResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'touch-canvas',
              data: const {'schemaVersion': 1, 'elements': []},
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (_) {},
              onCameraChanged: (cam) => cameraResult = cam,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate two-finger touch pinch-out (zoom in)
      final finger1 = await tester.startGesture(
        const Offset(300, 350),
        pointer: 101,
        kind: PointerDeviceKind.touch,
      );
      final finger2 = await tester.startGesture(
        const Offset(500, 350),
        pointer: 102,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 16));

      // Move fingers farther apart (pinch out)
      await finger1.moveTo(const Offset(200, 350));
      await finger2.moveTo(const Offset(600, 350));
      await tester.pump(const Duration(milliseconds: 16));

      // Release both fingers
      await finger1.up();
      await finger2.up();
      await tester.pumpAndSettle();

      // Verify zoom increased
      expect(cameraResult, isNotNull);
      expect((cameraResult!['zoom'] as num).toDouble(), greaterThan(1.0));
    });

    testWidgets('keyboard shortcuts + and - zoom canvas in and out', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Map<String, dynamic>? cameraResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'key-canvas',
              data: const {'schemaVersion': 1, 'elements': []},
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (_) {},
              onCameraChanged: (cam) => cameraResult = cam,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap canvas to focus
      await tester.tap(find.byType(CustomPaint).first);
      await tester.pumpAndSettle();

      // Press '+' (equal key) to zoom in
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pumpAndSettle();
      expect(cameraResult, isNotNull);
      final zoomIn = (cameraResult!['zoom'] as num).toDouble();
      expect(zoomIn, greaterThan(1.0));

      // Press '-' to zoom out
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pumpAndSettle();
      final zoomOut = (cameraResult!['zoom'] as num).toDouble();
      expect(zoomOut, lessThan(zoomIn));

      // Press '0' to reset zoom (100%)
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pumpAndSettle();
      final zoomReset = (cameraResult!['zoom'] as num).toDouble();
      expect(zoomReset, closeTo(1.0, 0.01));
    });
  });
}
