import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'canvas_transfer_quality_test.dart' as canvas;
import 'support/capture_ui.dart';

void main() {
  testWidgets(
    'spacing guides and failed-image recovery stay readable beside actual Canvas objects',
    (t) async {
      t.view.physicalSize = const Size(1200, 850);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await prepareCapture(t);
      final boundary = GlobalKey();
      var loads = 0, writes = 0;
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'layout',
                title: 'Equal spacing',
                data: canvas.board([
                  for (var i = 0; i < 3; i++)
                    {
                      'id': 'node-$i',
                      'type': 'rectangle',
                      'x': 40.0 + i * 200,
                      'y': 160.0,
                      'width': 100.0,
                      'height': 80.0,
                      'text': ['Plan', 'Build', 'Review'][i],
                    },
                  {
                    'id': 'image',
                    'type': 'image',
                    'x': 700.0,
                    'y': 160.0,
                    'width': 220.0,
                    'height': 130.0,
                    'contentRef': 'Attachments/missing.png',
                  },
                ]),
                objects: const [],
                imageLoader: (_) async {
                  loads++;
                  return null;
                },
                onOpenObject: (_) {},
                onChanged: (_) => writes++,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byTooltip('Retry unavailable images'), findsOneWidget);
      expect(
        canvas.painter(t).failedImages,
        contains('Attachments/missing.png'),
      );
      final pointer = await t.startGesture(
        canvas.at(t, const CanvasPoint(290, 200)),
      );
      await pointer.moveBy(const Offset(2, 0));
      await t.pump();
      expect(canvas.painter(t).guides.where((g) => g.label == '100').length, 2);
      await captureUi(
        t,
        'quiet-spacing-and-image-retry',
        target: find.byKey(boundary),
      );
      await pointer.up();
      await t.pumpAndSettle();
      final before = writes, previousLoads = loads;
      await t.tap(find.byTooltip('Retry unavailable images'));
      await t.pumpAndSettle();
      expect(loads, greaterThan(previousLoads));
      expect(writes, before);
      expect(t.takeException(), isNull);
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpWidget(const SizedBox());
    },
  );
}
