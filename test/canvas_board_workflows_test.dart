import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

void main() {
  testWidgets(
    'moving a column moves its members, undo restores both, delete retains content',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic> data = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'col',
            'type': 'column',
            'x': 50.0,
            'y': 50.0,
            'width': 260.0,
            'height': 180.0,
            'text': 'Research',
          },
          {
            'id': 'card',
            'type': 'sticky',
            'x': 66.0,
            'y': 104.0,
            'width': 200.0,
            'height': 100.0,
            'text': 'Keep this',
            'columnId': 'col',
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board',
              data: data,
              onChanged: (v) => data = v,
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
      );
      final origin = tester.getTopLeft(surface);
      await tester.dragFrom(
        origin + const Offset(100, 70),
        const Offset(100, 50),
      );
      await tester.pump();
      Map item(String id) => (data['elements'] as List).cast<Map>().firstWhere(
        (e) => e['id'] == id,
      );
      expect(item('col')['x'], 150.0);
      expect(item('card')['x'], 166.0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(item('col')['x'], 50.0);
      expect(item('card')['x'], 66.0);
      await tester.tapAt(origin + const Offset(100, 70));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(data['elements'], hasLength(1));
      expect(item('card')['text'], 'Keep this');
      expect(item('card')['columnId'], isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'link cards reject unsafe schemes and persist a real website card',
    (tester) async {
      Map<String, dynamic> data = {'schemaVersion': 1, 'elements': []};
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board',
              data: data,
              onChanged: (v) => data = v,
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Add / organize board content'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Website link card'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Research source',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'https://…'),
        'javascript:alert(1)',
      );
      await tester.tap(find.text('Add link'));
      await tester.pump();
      expect(
        find.text('Enter a complete HTTP or HTTPS address.'),
        findsOneWidget,
      );
      expect(data['elements'], isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, 'https://…'),
        'https://example.org/paper',
      );
      await tester.tap(find.text('Add link'));
      await tester.pumpAndSettle();
      final link = (data['elements'] as List).single as Map;
      expect(link['type'], 'link');
      expect(link['text'], 'Research source');
      expect(link['url'], 'https://example.org/paper');
      await tester.tap(find.byTooltip('Add / organize board content'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit selected link'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Revised source',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'https://…'),
        'https://example.org/revised',
      );
      await tester.tap(find.text('Save link'));
      await tester.pumpAndSettle();
      final updated = (data['elements'] as List).single as Map;
      expect(updated['id'], link['id']);
      expect(updated['x'], link['x']);
      expect(updated['url'], 'https://example.org/revised');
      expect(updated['text'], 'Revised source');
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
}
