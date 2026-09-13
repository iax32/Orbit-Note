import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/connectors.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';

void main() {
  for (final end in [
    const CanvasPoint(400, 200),
    const CanvasPoint(200, 400),
    const CanvasPoint(80, 80),
  ]) {
    test('explicit endpoints survive serialization and translation: $end', () {
      final element = CanvasElement({
        'id': 'edge',
        'type': 'arrow',
        'text': 'Flow',
        ...connectorEndpointData(const CanvasPoint(200, 200), end),
      });
      final restored = CanvasElement(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(element.data)) as Map),
      );
      expect(restored.renderable, isTrue);
      expect(storedConnectorStart(restored), const CanvasPoint(200, 200));
      expect(storedConnectorEnd(restored), end);
      final moved = restored.translated(const CanvasPoint(20, 30));
      expect(storedConnectorStart(moved), const CanvasPoint(220, 230));
      expect(storedConnectorEnd(moved), end + const CanvasPoint(20, 30));
      expect(moved.text, 'Flow');
    });
  }
  test('legacy reverse flags still resolve without rewriting data', () {
    final e = CanvasElement({
      'id': 'old',
      'type': 'line',
      'x': 10,
      'y': 20,
      'width': 80,
      'height': 0,
      'reverseX': true,
    });
    expect(storedConnectorStart(e), const CanvasPoint(90, 20));
    expect(storedConnectorEnd(e), const CanvasPoint(10, 20));
    expect(e.data.containsKey('startX'), isFalse);
  });

  testWidgets(
    'horizontal connector endpoint drag and undo preserve opposite endpoint',
    (tester) async {
      Map<String, dynamic> latest = {'schemaVersion': 1, 'elements': []};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'test',
              data: latest,
              camera: const {'x': 0, 'y': 0, 'zoom': 1},
              onChanged: (value) => latest = value,
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Shapes and diagrams'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arrow'));
      await tester.pumpAndSettle();
      final draw = await tester.startGesture(
        const Offset(250, 250),
        kind: PointerDeviceKind.mouse,
      );
      await draw.moveTo(const Offset(450, 250));
      await draw.up();
      await tester.pumpAndSettle();
      Map<String, dynamic> edge() =>
          Map<String, dynamic>.from((latest['elements'] as List).single as Map);
      final before = edge();
      expect(before['height'], 0);
      expect(before['endX'], 450);
      await tester.tap(find.byTooltip('Select (V)'));
      final drag = await tester.startGesture(
        const Offset(450, 250),
        kind: PointerDeviceKind.mouse,
      );
      await drag.moveTo(const Offset(250, 400));
      await drag.up();
      await tester.pumpAndSettle();
      expect(edge()['startX'], before['startX']);
      expect(edge()['startY'], before['startY']);
      expect(edge()['endX'], 250);
      expect(edge()['endY'], (before['endY'] as num) + 150);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(edge(), before);
      expect(tester.takeException(), isNull);
    },
  );
}
