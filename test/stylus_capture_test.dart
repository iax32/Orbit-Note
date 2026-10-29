import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'canvas_transfer_quality_test.dart' show painter, surface;

void main() {
  for (final touches in [0, 1, 2]) {
    testWidgets('pen retains capture with $touches earlier palm contacts', (
      t,
    ) async {
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'pen',
              data: const {'schemaVersion': 1, 'elements': []},
              objects: const [],
              onChanged: (_) {},
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final origin = t.getTopLeft(surface) + const Offset(250, 250);
      for (var i = 0; i < touches; i++) {
        await t.sendEventToBinding(
          PointerDownEvent(
            pointer: 10 + i,
            kind: PointerDeviceKind.touch,
            position: origin + Offset(70.0 * i, 60),
          ),
        );
      }
      await t.sendEventToBinding(
        PointerDownEvent(
          pointer: 30,
          kind: PointerDeviceKind.stylus,
          position: origin,
          pressure: .2,
          buttons: kPrimaryMouseButton,
        ),
      );
      await t.pump();
      // A pressure-only change must survive spatial sample filtering.
      await t.sendEventToBinding(
        PointerMoveEvent(
          pointer: 30,
          kind: PointerDeviceKind.stylus,
          position: origin,
          pressure: .8,
          timeStamp: const Duration(milliseconds: 5),
        ),
      );
      // Fresh palm contacts and their cancellation must not cancel this pen.
      await t.sendEventToBinding(
        PointerDownEvent(
          pointer: 50,
          kind: PointerDeviceKind.touch,
          position: origin,
        ),
      );
      await t.sendEventToBinding(
        const PointerCancelEvent(pointer: 50, kind: PointerDeviceKind.touch),
      );
      await t.sendEventToBinding(
        PointerMoveEvent(
          pointer: 30,
          kind: PointerDeviceKind.stylus,
          position: origin + const Offset(80, 30),
          pressure: .5,
          timeStamp: const Duration(milliseconds: 10),
        ),
      );
      await t.pump();
      await t.sendEventToBinding(
        PointerUpEvent(
          pointer: 30,
          kind: PointerDeviceKind.stylus,
          position: origin + const Offset(100, 40),
          timeStamp: const Duration(milliseconds: 15),
        ),
      );
      for (var i = 0; i < touches; i++) {
        await t.sendEventToBinding(
          PointerUpEvent(
            pointer: 10 + i,
            kind: PointerDeviceKind.touch,
            position: origin,
          ),
        );
      }
      await t.pump();
      final ink = painter(
        t,
      ).scene.elements.where((e) => e.type == 'ink').toList();
      expect(ink, hasLength(1));
      expect(ink.single.inkSamples!.map((s) => s['pressure']), [
        .2,
        .8,
        .5,
        .5,
      ]);
      expect(ink.single.inkSamples!.last['timeMs'], 15);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 500));
    });
  }
}
