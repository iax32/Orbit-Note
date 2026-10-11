import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/diagram_export.dart';
import 'package:orbit_note/canvas/diagram_import.dart';
import 'package:orbit_note/canvas/shape_recognizer.dart';
import 'package:orbit_note/canvas/arrangement.dart';
import 'package:orbit_note/canvas/canvas_svg.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';

CanvasScene _sceneFrom(List<CanvasElement> elements) =>
    CanvasScene.fromJson({'elements': elements.map((e) => e.data).toList()});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mermaid Diagram Export (CAN-16, PORT-05)', () {
    test('exports nodes with matching shape brackets and labels', () {
      final scene = _sceneFrom([
        CanvasElement({
          'id': 'n1',
          'type': 'rectangle',
          'text': 'Task Step',
          'x': 50.0,
          'y': 50.0,
          'width': 120.0,
          'height': 60.0,
        }),
        CanvasElement({
          'id': 'n2',
          'type': 'diamond',
          'text': 'Is Valid?',
          'x': 50.0,
          'y': 180.0,
          'width': 100.0,
          'height': 60.0,
        }),
        CanvasElement({
          'id': 'n3',
          'type': 'ellipse',
          'text': 'End State',
          'x': 50.0,
          'y': 300.0,
          'width': 100.0,
          'height': 60.0,
        }),
        CanvasElement({
          'id': 'c1',
          'type': 'connector',
          'startId': 'n1',
          'endId': 'n2',
          'endMarker': 'arrow',
        }),
        CanvasElement({
          'id': 'c2',
          'type': 'connector',
          'startId': 'n2',
          'endId': 'n3',
          'endMarker': 'arrow',
          'text': 'Yes',
          'strokeStyle': 'dashed',
        }),
      ]);

      final mmd = exportToMermaid(scene, direction: 'TD');

      expect(mmd.contains('flowchart TD'), isTrue);
      expect(mmd.contains('n1["Task Step"]'), isTrue);
      expect(mmd.contains('n2{"Is Valid?"}'), isTrue);
      expect(mmd.contains('n3(("End State"))'), isTrue);
      expect(mmd.contains('n1 --> n2'), isTrue);
      expect(mmd.contains('n2 -.->|Yes| n3'), isTrue);
    });

    test('supports custom direction, thick arrows, and round-trip parsing', () {
      final scene = _sceneFrom([
        CanvasElement({
          'id': 'start',
          'type': 'rectangle',
          'text': 'Alpha',
          'x': 100.0,
          'y': 100.0,
          'width': 120.0,
          'height': 50.0,
        }),
        CanvasElement({
          'id': 'finish',
          'type': 'rectangle',
          'text': 'Omega',
          'x': 400.0,
          'y': 100.0,
          'width': 120.0,
          'height': 50.0,
        }),
        CanvasElement({
          'id': 'link',
          'type': 'connector',
          'startId': 'start',
          'endId': 'finish',
          'strokeWidth': 4.0,
          'endMarker': 'arrow',
        }),
      ]);

      final mmd = exportToMermaid(scene, direction: 'LR');
      expect(mmd.contains('flowchart LR'), isTrue);
      expect(mmd.contains('start ==> finish'), isTrue);

      // Verify round-trip parsing back into canvas scene
      final imported = parseMermaidFlowchart(mmd);
      expect(imported.elements.length, 3);
      final importedNodes = imported.elements
          .where((e) => e.type != 'connector')
          .toList();
      final importedConns = imported.elements
          .where((e) => e.type == 'connector')
          .toList();
      expect(
        importedNodes.map((n) => n.text).toSet(),
        containsAll(['Alpha', 'Omega']),
      );
      expect(importedConns.length, 1);
      expect(importedConns.first.endMarker, equals('arrow'));
    });

    test('groups nodes enclosed in a frame into a Mermaid subgraph', () {
      final frame = CanvasElement({
        'id': 'frame1',
        'type': 'frame',
        'text': 'Core Processing',
        'x': 50.0,
        'y': 50.0,
        'width': 400.0,
        'height': 300.0,
      });
      final nodeIn = CanvasElement({
        'id': 'nodeA',
        'type': 'rectangle',
        'text': 'Worker',
        'x': 80.0,
        'y': 80.0,
        'width': 100.0,
        'height': 50.0,
      });
      final nodeOut = CanvasElement({
        'id': 'nodeB',
        'type': 'rectangle',
        'text': 'Sink',
        'x': 600.0,
        'y': 80.0,
        'width': 100.0,
        'height': 50.0,
      });
      final scene = _sceneFrom([frame, nodeIn, nodeOut]);

      final mmd = exportToMermaid(scene);
      expect(mmd.contains('subgraph frame1["Core Processing"]'), isTrue);
      expect(mmd.contains('nodeA["Worker"]'), isTrue);
      expect(mmd.contains('end'), isTrue);
      expect(mmd.contains('nodeB["Sink"]'), isTrue);
    });

    test('supports selection-only Mermaid export', () {
      final scene = _sceneFrom([
        CanvasElement({
          'id': 'a',
          'type': 'rectangle',
          'text': 'A',
          'x': 0,
          'y': 0,
          'width': 50,
          'height': 50,
        }),
        CanvasElement({
          'id': 'b',
          'type': 'rectangle',
          'text': 'B',
          'x': 100,
          'y': 0,
          'width': 50,
          'height': 50,
        }),
        CanvasElement({
          'id': 'c',
          'type': 'rectangle',
          'text': 'C',
          'x': 200,
          'y': 0,
          'width': 50,
          'height': 50,
        }),
        CanvasElement({
          'id': 'e1',
          'type': 'connector',
          'startId': 'a',
          'endId': 'b',
        }),
        CanvasElement({
          'id': 'e2',
          'type': 'connector',
          'startId': 'b',
          'endId': 'c',
        }),
      ]);

      final mmd = exportToMermaid(scene, elementIds: {'a', 'b', 'e1'});
      expect(mmd.contains('a["A"]'), isTrue);
      expect(mmd.contains('b["B"]'), isTrue);
      expect(mmd.contains('c["C"]'), isFalse);
      expect(mmd.contains('a --> b'), isTrue);
      expect(mmd.contains('b --> c'), isFalse);
    });
  });

  group('Selection to Note Extraction (PORT-05)', () {
    test(
      'extracts structured Markdown with backlinks, cards, checklists and flows',
      () {
        final scene = _sceneFrom([
          CanvasElement({
            'id': 'card1',
            'type': 'card',
            'text': 'Architecture Design\nDetailed microservices breakdown',
            'x': 50,
            'y': 50,
            'width': 200,
            'height': 100,
          }),
          CanvasElement({
            'id': 'task1',
            'type': 'card',
            'text': 'Implement API endpoints',
            'isTask': true,
            'isDone': true,
            'x': 50,
            'y': 180,
            'width': 200,
            'height': 60,
          }),
          CanvasElement({
            'id': 'task2',
            'type': 'card',
            'text': 'Write unit test suite',
            'isTask': true,
            'isDone': false,
            'x': 50,
            'y': 260,
            'width': 200,
            'height': 60,
          }),
          CanvasElement({
            'id': 'conn1',
            'type': 'connector',
            'startId': 'card1',
            'endId': 'task1',
            'text': 'triggers',
          }),
        ]);

        final md = extractSelectionToMarkdown(
          scene,
          {'card1', 'task1', 'task2', 'conn1'},
          canvasId: 'board_42',
          canvasTitle: 'Sprint 5 Planning',
        );

        expect(md.contains('# Sprint 5 Planning — Extracted Notes'), isTrue);
        expect(
          md.contains('[Sprint 5 Planning](orbit://canvas/board_42)'),
          isTrue,
        );
        expect(md.contains('### Architecture Design'), isTrue);
        expect(md.contains('Detailed microservices breakdown'), isTrue);
        expect(md.contains('- [x] Implement API endpoints'), isTrue);
        expect(md.contains('- [ ] Write unit test suite'), isTrue);
        expect(
          md.contains(
            'Architecture Design --> Implement API endpoints (triggers)',
          ),
          isTrue,
        );
      },
    );
  });

  group('Shape Recognition & Cleanup Engine (INK-09, CAN-16)', () {
    test('recognizes circle/ellipse from circular stroke', () {
      final points = <Map<String, dynamic>>[];
      const count = 36;
      const radius = 60.0;
      const cx = 100.0;
      const cy = 100.0;
      for (var i = 0; i <= count; i++) {
        final angle = (i / count) * 2 * math.pi;
        points.add({
          'x': radius * math.cos(angle) + cx - 40,
          'y': radius * math.sin(angle) + cy - 40,
        });
      }

      final inkElement = CanvasElement({
        'id': 'stroke1',
        'type': 'ink',
        'x': 40.0,
        'y': 40.0,
        'width': 120.0,
        'height': 120.0,
        'color': 0xff8b7cf6,
        'strokeWidth': 3.0,
        'points': points,
      });

      final shape = recognizeShape(inkElement);
      expect(shape, isNotNull);
      expect(shape!.type, equals('ellipse'));
      expect(shape.confidence, greaterThan(0.70));

      final converted = convertInkToShape(inkElement);
      expect(converted, isNotNull);
      expect(converted!.type, equals('ellipse'));
      expect(converted.id, equals('stroke1'));
      expect(converted.color, equals(0xff8b7cf6));
    });

    test('recognizes rectangle from box-shaped stroke', () {
      final points = <Map<String, dynamic>>[
        // Top edge
        {'x': 0.0, 'y': 0.0},
        {'x': 40.0, 'y': 1.0},
        {'x': 80.0, 'y': 0.0},
        {'x': 120.0, 'y': 0.0},
        // Right edge
        {'x': 121.0, 'y': 30.0},
        {'x': 120.0, 'y': 60.0},
        {'x': 119.0, 'y': 90.0},
        // Bottom edge
        {'x': 80.0, 'y': 91.0},
        {'x': 40.0, 'y': 90.0},
        {'x': 1.0, 'y': 89.0},
        // Left edge
        {'x': 0.0, 'y': 50.0},
        {'x': 1.0, 'y': 5.0},
      ];

      final inkElement = CanvasElement({
        'id': 'rect_stroke',
        'type': 'ink',
        'x': 50.0,
        'y': 50.0,
        'width': 120.0,
        'height': 90.0,
        'points': points,
      });

      final shape = recognizeShape(inkElement);
      expect(shape, isNotNull);
      expect(shape!.type, equals('rectangle'));

      final converted = convertInkToShape(inkElement);
      expect(converted, isNotNull);
      expect(converted!.type, equals('rectangle'));
      expect(converted.width, greaterThanOrEqualTo(120.0));
      expect(converted.height, greaterThanOrEqualTo(90.0));
    });

    test('recognizes straight arrow stroke and converts with endMarker', () {
      final points = <Map<String, dynamic>>[
        {'x': 0.0, 'y': 0.0},
        {'x': 30.0, 'y': 2.0},
        {'x': 60.0, 'y': 1.0},
        {'x': 100.0, 'y': 0.0},
        {'x': 140.0, 'y': 1.0},
        // Arrow barb hooking back
        {'x': 125.0, 'y': -12.0},
      ];

      final inkElement = CanvasElement({
        'id': 'arrow_stroke',
        'type': 'ink',
        'x': 50.0,
        'y': 50.0,
        'width': 140.0,
        'height': 15.0,
        'points': points,
      });

      final shape = recognizeShape(inkElement);
      expect(shape, isNotNull);
      expect(shape!.type, equals('arrow'));

      final converted = convertInkToShape(inkElement);
      expect(converted, isNotNull);
      expect(converted!.type, equals('arrow'));
      expect(converted.endMarker, equals('arrow'));
    });

    test('forceShape override cleanly converts any stroke', () {
      final inkElement = CanvasElement({
        'id': 's1',
        'type': 'ink',
        'x': 20.0,
        'y': 20.0,
        'width': 80.0,
        'height': 80.0,
        'points': [
          {'x': 0.0, 'y': 0.0},
          {'x': 40.0, 'y': 40.0},
          {'x': 80.0, 'y': 80.0},
        ],
      });

      final diamond = convertInkToShape(inkElement, forceShape: 'diamond');
      expect(diamond, isNotNull);
      expect(diamond!.type, equals('diamond'));

      final line = convertInkToShape(inkElement, forceShape: 'line');
      expect(line, isNotNull);
      expect(line!.type, equals('line'));
    });
  });

  group('Ray-Casting Point-in-Polygon (INK-04)', () {
    test('detects inside, outside, and boundary points', () {
      final square = [
        const CanvasPoint(100, 100),
        const CanvasPoint(200, 100),
        const CanvasPoint(200, 200),
        const CanvasPoint(100, 200),
        const CanvasPoint(100, 100),
      ];

      // Inside
      expect(isPointInPolygon(const CanvasPoint(150, 150), square), isTrue);
      expect(isPointInPolygon(const CanvasPoint(110, 190), square), isTrue);

      // Outside
      expect(isPointInPolygon(const CanvasPoint(50, 150), square), isFalse);
      expect(isPointInPolygon(const CanvasPoint(250, 150), square), isFalse);
      expect(isPointInPolygon(const CanvasPoint(150, 50), square), isFalse);
      expect(isPointInPolygon(const CanvasPoint(150, 250), square), isFalse);
    });

    test('handles non-convex concave polygons', () {
      // V-shaped / concave polygon
      final concave = [
        const CanvasPoint(0, 0),
        const CanvasPoint(100, 0),
        const CanvasPoint(50, 50),
        const CanvasPoint(100, 100),
        const CanvasPoint(0, 100),
        const CanvasPoint(0, 0),
      ];

      expect(isPointInPolygon(const CanvasPoint(20, 50), concave), isTrue);
      // In the right indentation (outside)
      expect(isPointInPolygon(const CanvasPoint(80, 50), concave), isFalse);
    });
  });

  group('Advanced Auto-Arrange Layouts (CAN-10)', () {
    test(
      'mindMap arranges root and leaf nodes radially across balanced branches',
      () {
        final elements = List.generate(
          7,
          (i) => CanvasElement({
            'id': 'node_$i',
            'type': 'rectangle',
            'x': i * 20.0,
            'y': 0.0,
            'width': 100.0,
            'height': 60.0,
          }),
        );

        final arranged = arrangeCanvas(elements, CanvasArrangement.mindMap);
        expect(arranged.length, 7);

        final root = arranged.first; // Center root
        final children = arranged.skip(1).toList();

        // Check that children are positioned on both left and right sides of root
        final leftBranch = children.where((c) => c.x < root.x).toList();
        final rightBranch = children.where((c) => c.x > root.x).toList();

        expect(leftBranch.isNotEmpty, isTrue);
        expect(rightBranch.isNotEmpty, isTrue);
      },
    );

    test('timeline arranges elements sequentially along horizontal axis', () {
      final elements = List.generate(
        5,
        (i) => CanvasElement({
          'id': 'step_$i',
          'type': 'card',
          'x': 500.0 - i * 50.0, // randomly scattered
          'y': 200.0,
          'width': 120.0,
          'height': 70.0,
        }),
      );

      final arranged = arrangeCanvas(elements, CanvasArrangement.timeline);
      expect(arranged.length, 5);

      // Verify strict left-to-right progression
      for (var i = 0; i < arranged.length - 1; i++) {
        expect(arranged[i].x < arranged[i + 1].x, isTrue);
      }
    });

    test('treeV arranges elements in vertical hierarchy levels', () {
      final elements = List.generate(
        6,
        (i) => CanvasElement({
          'id': 'e_$i',
          'type': 'rectangle',
          'x': 0.0,
          'y': 0.0,
          'width': 100.0,
          'height': 50.0,
        }),
      );

      final arranged = arrangeCanvas(elements, CanvasArrangement.treeV);
      expect(arranged.length, 6);

      // Root level (y=0) has 1 node, level 1 has 2 nodes, level 2 has 3 nodes
      final level0 = arranged.where((e) => e.y == arranged.first.y).toList();
      expect(level0.length, 1);

      final yValues = arranged.map((e) => e.y).toSet().toList()..sort();
      expect(yValues.length, greaterThanOrEqualTo(2));
      for (var i = 0; i < yValues.length - 1; i++) {
        expect(yValues[i] < yValues[i + 1], isTrue);
      }
    });
  });

  group('Scaled SVG Vector Export with Pen Styles (PORT-05, INK-09)', () {
    test('exports scaled SVG with custom pen styles faithfully', () {
      final scene = _sceneFrom([
        CanvasElement({
          'id': 'p1',
          'type': 'ink',
          'x': 10.0,
          'y': 10.0,
          'width': 100.0,
          'height': 50.0,
          'penStyle': 'pencil',
          'strokeWidth': 2.0,
          'color': 0xff334155,
          'points': [
            {'x': 0.0, 'y': 0.0},
            {'x': 50.0, 'y': 25.0},
            {'x': 100.0, 'y': 50.0},
          ],
        }),
        CanvasElement({
          'id': 'c1',
          'type': 'ink',
          'x': 10.0,
          'y': 80.0,
          'width': 100.0,
          'height': 50.0,
          'penStyle': 'calligraphy',
          'strokeWidth': 4.0,
          'color': 0xff8b7cf6,
          'points': [
            {'x': 0.0, 'y': 0.0},
            {'x': 50.0, 'y': 25.0},
            {'x': 100.0, 'y': 50.0},
          ],
        }),
      ]);

      // 2x Scaled SVG
      final svg2x = canvasToSvg(scene, scale: 2.0);
      expect(svg2x.contains('<svg'), isTrue);
      expect(
        svg2x.contains('stroke-dasharray="0.8,1.2"'),
        isTrue,
      ); // pencil texture
      expect(svg2x.contains('stroke-linecap="round"'), isTrue);

      // 4x Scaled SVG
      final svg4x = canvasToSvg(scene, scale: 4.0);
      expect(svg4x.contains('<svg'), isTrue);
      expect(svg4x.contains('width='), isTrue);
    });
  });

  group('CanvasEditor Widget Advanced Interaction (INK-04, INK-07)', () {
    testWidgets('Lasso selection tool is available on toolbar and shortcut L', (
      tester,
    ) async {
      final sceneData = {
        'elements': [
          {
            'id': 'elem_target',
            'type': 'rectangle',
            'text': 'Target Box',
            'x': 200.0,
            'y': 200.0,
            'width': 100.0,
            'height': 100.0,
          },
          {
            'id': 'elem_outside',
            'type': 'rectangle',
            'text': 'Outside Box',
            'x': 800.0,
            'y': 800.0,
            'width': 100.0,
            'height': 100.0,
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'test_canvas',
              title: 'Lasso Test',
              data: sceneData,
              objects: const [],
              onChanged: (_) {},
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Lasso tool button exists on toolbar
      final lassoButtonFinder = find.byTooltip('Lasso selection (L)');
      expect(lassoButtonFinder, findsOneWidget);

      // Tap to activate Lasso tool
      await tester.tap(lassoButtonFinder);
      await tester.pumpAndSettle();

      // Draw a lasso polygon loop around the target element
      final gesture = await tester.startGesture(const Offset(150, 150));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveTo(const Offset(350, 150));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveTo(const Offset(350, 350));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveTo(const Offset(150, 350));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveTo(const Offset(150, 150));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.up();
      await tester.pumpAndSettle();

      // Also verify key L shortcut switches tool
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'Background paper dropdown includes ruled and isometric styles',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        String? updatedStyle;
        final sceneData = {
          'backgroundStyle': 'dots',
          'elements': <Map<String, dynamic>>[],
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'test_bg',
                title: 'Paper Test',
                data: sceneData,
                objects: const [],
                onChanged: (data) {
                  updatedStyle = data['backgroundStyle'] as String?;
                },
                onOpenObject: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap paper style popup
        final paperPopupFinder = find.byTooltip('Canvas paper style');
        expect(paperPopupFinder, findsOneWidget);
        await tester.tap(paperPopupFinder);
        await tester.pumpAndSettle();

        // Verify options
        expect(find.text('Student / Legal ruled margin'), findsOneWidget);
        expect(find.text('Isometric 3D grid'), findsOneWidget);

        // Select Ruled
        await tester.tap(find.text('Student / Legal ruled margin'));
        await tester.pumpAndSettle();
        expect(updatedStyle, equals('ruled'));
      },
    );
  });
}
