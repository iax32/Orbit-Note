import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/canvas_comfort.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/domain/portable_preferences.dart';
import 'package:orbit_note/features/canvas/canvas_comfort_panel.dart';
import 'package:orbit_note/features/canvas/canvas_focus_controls.dart';

void main() {
  test(
    'device placement survives restart and stays out of portable preferences',
    () {
      final session = SessionState.fromJson({
        'canvasComfort': {
          'x': .25,
          'y': 1,
          'locked': true,
          'largeControls': true,
          'future': {'keep': true},
        },
        'futureSession': 'keep',
      });
      final reopened = SessionState.fromJson(
        jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
      );
      final comfort = CanvasComfort(reopened.canvasComfort);
      expect(comfort.x, .25);
      expect(comfort.y, 1);
      expect(comfort.locked, isTrue);
      expect(comfort.touchSize, 56);
      expect(
        PortablePreferences.select(reopened.toJson()),
        isNot(contains('canvasComfort')),
      );
      expect(comfort.reset['future'], {'keep': true});
      expect(reopened.toJson()['futureSession'], 'keep');
      expect(CanvasComfort(comfort.reset).touchSize, 48);
      expect(CanvasComfort({'x': double.nan, 'y': double.infinity}).x, 1);
      expect(CanvasComfort({'x': -5, 'y': 10}).x, 0);
      expect(CanvasComfort({'x': -5, 'y': 10}).y, 1);
      expect(
        SessionState.fromJson({'canvasComfort': 'broken'}).canvasComfort,
        isEmpty,
      );
    },
  );

  testWidgets('comfort preset, handedness and reset work on a narrow screen', (
    t,
  ) async {
    var value = <String, dynamic>{'future': 17};
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (context, update) => SingleChildScrollView(
                  child: CanvasComfortPanel(
                    value: value,
                    onChanged: (next) => update(() => value = next),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.ensureVisible(find.text('Use tablet comfort'));
    await t.tap(find.text('Use tablet comfort'));
    await t.pumpAndSettle();
    expect(CanvasComfort(value).largeControls, isTrue);
    expect(CanvasComfort(value).softGrid, isTrue);
    await t.ensureVisible(find.text('Left side'));
    await t.tap(find.text('Left side'));
    await t.pumpAndSettle();
    expect(CanvasComfort(value).x, 0);
    expect(CanvasComfort(value).y, 1);
    await t.ensureVisible(find.text('Reset comfort options'));
    await t.tap(find.text('Reset comfort options'));
    await t.pumpAndSettle();
    expect(CanvasComfort(value).softGrid, isFalse);
    expect(value['future'], 17);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'saved placement updates live and comfort grip has a large touch target',
    (t) async {
      Widget host(Offset anchor, bool locked) => MaterialApp(
        home: Scaffold(
          body: CanvasFocusControls(
            initialAnchor: anchor,
            initialLocked: locked,
            touchSize: 56,
            expanded: false,
            toolbar: const SizedBox(height: 64),
            dock: const SizedBox(width: 100, height: 56),
          ),
        ),
      );
      final grip = find.byKey(const ValueKey('canvas-focus-position'));
      await t.pumpWidget(host(const Offset(1, 0), false));
      final before = t.getRect(grip);
      expect(before.size, const Size(56, 56));
      await t.pumpWidget(host(const Offset(0, 1), true));
      await t.pumpAndSettle();
      final after = t.getRect(grip);
      expect(after.left, lessThan(before.left));
      expect(after.top, greaterThan(before.top));
      await t.drag(grip, const Offset(200, -200));
      await t.pumpAndSettle();
      expect(t.getRect(grip), after);
      expect(t.takeException(), isNull);
    },
  );
}
