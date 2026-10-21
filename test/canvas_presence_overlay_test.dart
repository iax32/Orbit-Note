import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/features/canvas/canvas_presence_overlay.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

void main() {
  testWidgets('presence repaint retains the Canvas painter and local scene', (
    t,
  ) async {
    final peers = ValueNotifier<List<Map<String, dynamic>>>([]);
    addTearDown(peers.dispose);
    var edits = 0;
    await t.pumpWidget(
      MaterialApp(
        home: CanvasEditor(
          canvasId: 'board',
          data: const {'schemaVersion': 1, 'elements': []},
          onChanged: (_) => edits++,
          objects: const [],
          onOpenObject: (_) {},
          remotePresence: peers,
        ),
      ),
    );
    await t.pumpAndSettle();
    final paint = find
        .byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
        )
        .first;
    final painter = t.widget<CustomPaint>(paint).painter;
    peers.value = [
      {
        'objectId': 'board',
        'space': 'canvas',
        'session': 'bob',
        'name': 'Bob',
        'x': 20,
        'y': 30,
      },
    ];
    await t.pumpAndSettle();
    expect(find.text('↖ Bob'), findsOneWidget);
    expect(identical(t.widget<CustomPaint>(paint).painter, painter), isTrue);
    expect(edits, 0);
    peers.value = [];
    await t.pumpAndSettle();
    expect(find.text('↖ Bob'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Canvas publishes selection and clears presence when pointer leaves',
    (t) async {
      List<String> selected = [];
      var leaves = 0, edits = 0;
      await t.pumpWidget(
        MaterialApp(
          home: CanvasEditor(
            canvasId: 'board',
            data: const {
              'schemaVersion': 1,
              'elements': [
                {
                  'id': 'a',
                  'type': 'rectangle',
                  'x': 100,
                  'y': 100,
                  'width': 80,
                  'height': 60,
                },
              ],
            },
            camera: const {'x': 0, 'y': 0, 'zoom': 1},
            onChanged: (_) => edits++,
            objects: const [],
            onOpenObject: (_) {},
            onPresence: (_, _) {},
            onPresenceSelection: (ids) => selected = ids,
            onPresenceLeave: () => leaves++,
          ),
        ),
      );
      await t.pumpAndSettle();
      final origin = t.getTopLeft(find.byType(CanvasPresenceOverlay));
      await t.tapAt(origin + const Offset(130, 130));
      await t.pumpAndSettle();
      expect(selected, ['a']);
      expect(edits, 0);
      final before = leaves;
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: origin + const Offset(130, 130));
      await t.pump();
      await mouse.moveTo(const Offset(1, 1));
      await t.pumpAndSettle();
      expect(leaves, greaterThan(before));
      await mouse.removePointer();
      await t.pumpWidget(const SizedBox());
    },
  );
  final scene = CanvasScene.fromJson({
    'schemaVersion': 1,
    'elements': [
      {
        'id': 'a',
        'type': 'rectangle',
        'x': 100,
        'y': 150,
        'width': 80,
        'height': 60,
      },
      {
        'id': 'hidden',
        'type': 'rectangle',
        'x': 100,
        'y': 150,
        'width': 80,
        'height': 60,
        'hidden': true,
      },
      {
        'id': 'far',
        'type': 'rectangle',
        'x': 100000,
        'y': 100000,
        'width': 80,
        'height': 60,
      },
    ],
  });
  Future<void> open(
    WidgetTester t,
    List<Map<String, dynamic>> peers, {
    double zoom = 1,
  }) async {
    await t.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 600,
          height: 600,
          child: CanvasPresenceOverlay(
            scene: scene,
            camera: CanvasCamera(x: 20, y: 30, zoom: zoom),
            peers: peers,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('long emoji names remain valid UTF-16 at the label boundary', (
    t,
  ) async {
    await open(t, [
      {'name': '${'A' * 79}😀 tail', 'x': 20, 'y': 30},
    ]);
    expect(find.text('↖ ${'A' * 79}😀'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'selection outlines use world geometry and do not capture input',
    (t) async {
      await open(t, [
        {
          'session': 'bob',
          'name': 'Bob',
          'x': 100,
          'y': 150,
          'selection': ['a'],
        },
      ], zoom: 2);
      final outline = find.byKey(const ValueKey('peer-selection-bob-a'));
      expect(outline, findsOneWidget);
      expect(find.text('↖ Bob'), findsOneWidget);
      final position = t.widget<Positioned>(
        find.ancestor(of: outline, matching: find.byType(Positioned)),
      );
      expect(position.left, 157);
      expect(position.top, 237);
      expect(position.width, 166);
      expect(position.height, 126);
      expect(
        t.widget<IgnorePointer>(find.byType(IgnorePointer).last).ignoring,
        isTrue,
      );
    },
  );
  testWidgets(
    'invalid inactive unknown hidden and offscreen selections stay out of the overlay',
    (t) async {
      await open(t, [
        {'name': 'Invalid', 'x': double.nan, 'y': 0},
        {'name': 'Malformed', 'x': 'oops', 'y': 0},
        {'name': 'Gone', 'x': 0, 'y': 0, 'active': false},
        {
          'session': 'bob',
          'name': 'Bob',
          'x': 20,
          'y': 30,
          'selection': ['a', 'a', 'missing', 'hidden', 'far'],
        },
      ]);
      expect(find.text('↖ Bob'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('peer-selection-bob-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('peer-selection-bob-hidden')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('peer-selection-bob-far')),
        findsNothing,
      );
      expect(find.text('↖ Invalid'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
}
