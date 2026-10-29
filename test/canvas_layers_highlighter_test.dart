import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/canvas/canvas_scene_viewport.dart';

void main() {
  group('CanvasScene Stacking Order (CAN-08)', () {
    test('initial order reflects element insertion index', () {
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
          },
          {
            'id': 'e2',
            'type': 'ellipse',
            'x': 50,
            'y': 50,
            'width': 100,
            'height': 100,
          },
          {
            'id': 'e3',
            'type': 'sticky',
            'x': 100,
            'y': 100,
            'width': 100,
            'height': 100,
          },
        ],
      });

      expect(scene.orderOf('e1'), 0);
      expect(scene.orderOf('e2'), 1);
      expect(scene.orderOf('e3'), 2);
      expect(scene.elementsInOrder.map((e) => e.id).toList(), [
        'e1',
        'e2',
        'e3',
      ]);
    });

    test('bringToFront moves element above all other elements', () {
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
          },
          {
            'id': 'e2',
            'type': 'ellipse',
            'x': 50,
            'y': 50,
            'width': 100,
            'height': 100,
          },
          {
            'id': 'e3',
            'type': 'sticky',
            'x': 100,
            'y': 100,
            'width': 100,
            'height': 100,
          },
        ],
      });

      scene.bringToFront('e1');
      expect(scene.orderOf('e1')! > scene.orderOf('e3')!, isTrue);
      expect(scene.elementsInOrder.map((e) => e.id).toList(), [
        'e2',
        'e3',
        'e1',
      ]);
    });

    test('sendToBack moves element below all other elements', () {
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
          },
          {
            'id': 'e2',
            'type': 'ellipse',
            'x': 50,
            'y': 50,
            'width': 100,
            'height': 100,
          },
          {
            'id': 'e3',
            'type': 'sticky',
            'x': 100,
            'y': 100,
            'width': 100,
            'height': 100,
          },
        ],
      });

      scene.sendToBack('e3');
      expect(scene.orderOf('e3')! < scene.orderOf('e1')!, isTrue);
      expect(scene.elementsInOrder.map((e) => e.id).toList(), [
        'e3',
        'e1',
        'e2',
      ]);
    });

    test('bringForward and sendBackward swap with adjacent elements', () {
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
          },
          {
            'id': 'e2',
            'type': 'ellipse',
            'x': 50,
            'y': 50,
            'width': 100,
            'height': 100,
          },
          {
            'id': 'e3',
            'type': 'sticky',
            'x': 100,
            'y': 100,
            'width': 100,
            'height': 100,
          },
        ],
      });

      scene.bringForward('e1');
      expect(scene.elementsInOrder.map((e) => e.id).toList(), [
        'e2',
        'e1',
        'e3',
      ]);

      scene.bringForward('e1');
      expect(scene.elementsInOrder.map((e) => e.id).toList(), [
        'e2',
        'e3',
        'e1',
      ]);

      // Already at top; no-op
      scene.bringForward('e1');
      expect(scene.elementsInOrder.map((e) => e.id).toList(), [
        'e2',
        'e3',
        'e1',
      ]);

      scene.sendBackward('e1');
      expect(scene.elementsInOrder.map((e) => e.id).toList(), [
        'e2',
        'e1',
        'e3',
      ]);

      scene.sendBackward('e1');
      expect(scene.elementsInOrder.map((e) => e.id).toList(), [
        'e1',
        'e2',
        'e3',
      ]);

      // Already at bottom; no-op
      scene.sendBackward('e1');
      expect(scene.elementsInOrder.map((e) => e.id).toList(), [
        'e1',
        'e2',
        'e3',
      ]);
    });

    test('toJson and fromJson preserve ordered element stack', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'bottom',
            'type': 'rectangle',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 100,
          },
          {
            'id': 'middle',
            'type': 'ellipse',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 100,
          },
          {
            'id': 'top',
            'type': 'sticky',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 100,
          },
        ],
      });

      scene.bringToFront('bottom');
      final json = scene.toJson();
      final elementsJson = (json['elements'] as List)
          .cast<Map<String, dynamic>>();
      expect(elementsJson.map((e) => e['id']).toList(), [
        'middle',
        'top',
        'bottom',
      ]);

      final restored = CanvasScene.fromJson(json);
      expect(restored.elementsInOrder.map((e) => e.id).toList(), [
        'middle',
        'top',
        'bottom',
      ]);
    });

    test(
      'CanvasHistory.reorder enables complete undo and redo of layer ordering',
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
            },
            {
              'id': 'e2',
              'type': 'ellipse',
              'x': 0,
              'y': 0,
              'width': 100,
              'height': 100,
            },
          ],
        });
        final history = CanvasHistory(scene);

        expect(scene.elementsInOrder.map((e) => e.id).toList(), ['e1', 'e2']);

        history.reorder(['e1'], () {
          scene.bringToFront('e1');
        });
        history.commit();

        expect(scene.elementsInOrder.map((e) => e.id).toList(), ['e2', 'e1']);

        // Undo restores original stacking
        expect(history.canUndo, isTrue);
        history.undo();
        expect(scene.elementsInOrder.map((e) => e.id).toList(), ['e1', 'e2']);

        // Redo restores brought-to-front stacking
        expect(history.canRedo, isTrue);
        history.redo();
        expect(scene.elementsInOrder.map((e) => e.id).toList(), ['e2', 'e1']);
      },
    );
  });

  group('Freeform Highlighter Tool (INK-03)', () {
    test('highlighter element preserves data properties and hit-testing', () {
      final highlighter = CanvasElement({
        'id': 'hl-1',
        'type': 'ink',
        'x': 50.0,
        'y': 50.0,
        'width': 100.0,
        'height': 20.0,
        'color': 0xFFFFFF00,
        'strokeWidth': 22.0,
        'isHighlighter': true,
        'points': [
          {'x': 0.0, 'y': 10.0, 'pressure': 1.0, 'timeMs': 0},
          {'x': 100.0, 'y': 10.0, 'pressure': 1.0, 'timeMs': 50},
        ],
      });

      expect(highlighter.type, 'ink');
      expect(highlighter.data['isHighlighter'], true);
      expect(highlighter.strokeWidth, 22.0);

      // Hit test segment
      expect(
        highlighter.hit(const CanvasPoint(100.0, 60.0), tolerance: 5.0),
        isTrue,
      );
    });

    testWidgets('OrbitCanvasPainter renders highlighter ink without error', (
      tester,
    ) async {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'hl-1',
            'type': 'ink',
            'x': 20.0,
            'y': 20.0,
            'width': 80.0,
            'height': 30.0,
            'color': 0xFFFFEB3B,
            'strokeWidth': 22.0,
            'isHighlighter': true,
            'points': [
              {'x': 0.0, 'y': 15.0, 'pressure': 1.0, 'timeMs': 0},
              {'x': 80.0, 'y': 15.0, 'pressure': 1.0, 'timeMs': 100},
            ],
          },
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CustomPaint(
              size: const Size(400, 400),
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

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('Canvas Editor Layer Manager & Stacking UI', () {
    testWidgets(
      'highlighter button is present and activates highlighter tool',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        Map<String, dynamic> canvasData = {'schemaVersion': 1, 'elements': []};

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'board-1',
                data: canvasData,
                objects: const [],
                onOpenObject: (_) {},
                onChanged: (data) => canvasData = data,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Draw and erase'));
        await tester.pumpAndSettle();
        final highlighterButton = find.text('Highlighter (Y)');
        expect(highlighterButton, findsOneWidget);

        await tester.tap(highlighterButton);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('layer manager dialog opens and displays stacked elements', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      Map<String, dynamic> canvasData = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'e1',
            'type': 'rectangle',
            'x': 10,
            'y': 10,
            'width': 50,
            'height': 50,
            'color': 0xFFFF0000,
          },
          {
            'id': 'e2',
            'type': 'sticky',
            'text': 'My Sticky',
            'x': 80,
            'y': 80,
            'width': 100,
            'height': 100,
            'color': 0xFF00FF00,
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board-1',
              data: canvasData,
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (data) => canvasData = data,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final layersButton = find.byTooltip('Layers & element list');
      expect(layersButton, findsOneWidget);

      await tester.tap(layersButton);
      await tester.pumpAndSettle();

      expect(find.text('Layers & Stacking Order'), findsOneWidget);
      expect(find.text('2 layers'), findsOneWidget);
      expect(find.text('My Sticky'), findsOneWidget);
      expect(find.text('Rectangle'), findsOneWidget);

      expect(find.byTooltip('Bring Forward'), findsWidgets);
      expect(find.byTooltip('Send Backward'), findsWidgets);
      expect(find.byTooltip('Lock layer'), findsWidgets);
      expect(find.byTooltip('Hide layer'), findsWidgets);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Layers & Stacking Order'), findsNothing);
    });

    testWidgets('layer order keyboard shortcuts shift stacking order', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      Map<String, dynamic> canvasData = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'e1',
            'type': 'rectangle',
            'x': 300,
            'y': 200,
            'width': 50,
            'height': 50,
          },
          {
            'id': 'e2',
            'type': 'sticky',
            'text': 'Note',
            'x': 400,
            'y': 200,
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
              canvasId: 'board-1',
              data: canvasData,
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (data) => canvasData = data,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final surface = find.byType(CanvasSceneViewport);
      final origin = tester.getTopLeft(surface);

      // Tap e1 to select it
      await tester.tapAt(origin + const Offset(325, 225));
      await tester.pumpAndSettle();

      // Press ']' to bring forward
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pumpAndSettle();

      final elements = canvasData['elements'] as List;
      expect(elements.last['id'], 'e1');
    });
  });
}
