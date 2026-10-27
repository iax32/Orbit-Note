import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/connectors.dart';
import 'package:orbit_note/canvas/canvas_svg.dart';
import 'package:orbit_note/canvas/uml.dart';
import 'package:orbit_note/canvas/uml_interaction.dart';
import 'package:orbit_note/canvas/sequence_class_draft.dart';
import 'package:orbit_note/features/canvas/uml_dialog.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';

CanvasScene fixture() {
  final nodes = [
    for (final name in ['a1:A', 'a2:A', 'b1:B', 'b2:B', 'c1:C'])
      newInteractionNode(
        name.split(':').first,
        UmlNodeKind.lifeline,
        const CanvasPoint(0, 0),
      ).copy({'text': name}),
  ];
  var n = 0;
  CanvasElement message(
    String from,
    String to,
    String label, {
    bool reply = false,
  }) {
    final e = CanvasElement({'id': 'm${n++}', 'type': 'connector'});
    return e.copy(
      editInteractionLink(
        e,
        nodes,
        kind: reply ? UmlLinkKind.reply : UmlLinkKind.synchronous,
        from: from,
        to: to,
        label: label,
        position: .12 + n * .04,
      ),
    );
  }

  return CanvasScene.fromJson({
    'futureRoot': true,
    'elements': [
      ...nodes.map((e) => e.data),
      message('b1', 'c1', 'z').data,
      message('c1', 'b1', 'z: "yayy"', reply: true).data,
      message('b1', 'a2', 'x').data,
      message('a1', 'a1', 'x').data,
      message('b1', 'b2', 'y(123)').data,
      message('a2', 'b2', 'y(333)').data,
      message('b2', 'c1', 'z').data,
      message('c1', 'b2', 'z: "hallo"', reply: true).data,
      message('a1', 'b1', 'y(999)').data,
      message('a2', 'a2', 'x').data,
      message('a1', 'a1', 'x(123)').data,
      message('a1', 'a1', 'x: 456', reply: true).data,
      message('b2', 'b1', 'y(333)').data,
      message('b1', 'b1', 'y(229)').data,
      message('c1', 'a1', 'x').data,
    ],
  });
}

void main() {
  testWidgets(
    'review cancellation preserves sequence and insertion has one undo',
    (t) async {
      t.view.physicalSize = const Size(1360, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final original = fixture().toJson();
      Map<String, dynamic>? saved;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'sequence',
              data: original,
              onChanged: (data) => saved = data,
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      Future<void> open() async {
        await t.tap(find.byTooltip('Shapes and diagrams'));
        await t.pumpAndSettle();
        await t.ensureVisible(find.text('Class diagram from sequence…'));
        await t.tap(find.text('Class diagram from sequence…'));
        await t.pumpAndSettle();
        expect(find.text('Review class diagram draft'), findsOneWidget);
      }

      await open();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(saved, isNull);
      await open();
      await t.tap(find.text('Insert draft'));
      await t.pumpAndSettle();
      expect(
        CanvasScene.fromJson(saved!).elements.length,
        fixture().elements.length + 7,
      );
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      expect(
        CanvasScene.fromJson(saved!).elements.length,
        fixture().elements.length,
      );
      expect(t.takeException(), isNull);
    },
  );
  test(
    'exercise draft preserves source and infers only observed types and navigation',
    () {
      final scene = fixture(), before = jsonEncode(fixture().toJson());
      var n = 0;
      final draft = draftClassesFromSequence(scene, () => 'draft${n++}');
      final classes = {
        for (final e in draft.elements.where(isUmlClass)) e.text: e,
      };
      expect(classes.keys, containsAll(['A', 'B', 'C']));
      expect(
        UmlClass(classes['A']!).operations,
        containsAll(['x()', 'x(arg1: int)']),
      );
      expect(UmlClass(classes['B']!).operations, ['y(arg1: int)']);
      expect(UmlClass(classes['C']!).operations, ['z(): String']);
      expect(classes.values.every((e) => UmlClass(e).attributes.isEmpty), true);
      final names = {for (final e in classes.values) e.id: e.text};
      final links = {
        for (final e in draft.elements.where(isConnectorElement))
          '${names[e.startId]}-${names[e.endId]}': UmlNavigation.of(e),
      };
      expect(links, {
        'B-C': UmlNavigation.fromTo,
        'B-A': UmlNavigation.both,
        'B-B': UmlNavigation.fromTo,
        'C-A': UmlNavigation.fromTo,
      });
      expect(
        draft.warnings.any((s) => s.contains('Return type needs review')),
        true,
      );
      expect(jsonEncode(scene.toJson()), before);
      final history = CanvasHistory(scene);
      history.begin();
      scene.batch(() {
        for (final e in draft.elements) {
          history.put(e);
        }
      });
      history.commit();
      expect(scene.elements.length, fixture().elements.length + 7);
      expect(history.undo(), true);
      expect(jsonEncode(scene.toJson()), before);
    },
  );
  test('selection scope, unsafe IDs and missing typed sources are handled', () {
    var n = 0;
    final draft = draftClassesFromSequence(
      fixture(),
      () => 'd${n++}',
      selection: {'m0'},
    );
    expect(draft.elements.where(isUmlClass).map((e) => e.text), ['B', 'C']);
    expect(
      () => draftClassesFromSequence(fixture(), () => 'a1'),
      throwsFormatException,
    );
    expect(
      () => draftClassesFromSequence(
        CanvasScene.fromJson({'elements': []}),
        () => 'id',
      ),
      throwsFormatException,
    );
  });
  test(
    'self association loops stay outside the class and follow movement and undo',
    () {
      final node = newUmlClass('a', const CanvasPoint(20, 30));
      for (final side in ['auto', 'left', 'right', 'top', 'bottom']) {
        final edge = CanvasElement({
          'id': 'edge',
          'type': 'connector',
          ...UmlRelationship.association.style,
          ...UmlNavigation.fromTo.style,
          'startId': 'a',
          'endId': 'a',
          'startAnchor': side,
          'endAnchor': side,
          'startAnchorOffset': .5,
          'endAnchorOffset': .5,
        });
        final scene = CanvasScene.fromJson({
          'elements': [node.data, edge.data],
        });
        final points = resolveConnectorEndpoints(edge, scene);
        expect(points.isPolyline, true);
        expect(points.start, isNot(points.end));
        expect(
          points.controlPoints.every((p) => !node.bounds.contains(p)),
          true,
        );
        expect(scene.hit(points.controlPoints.first)?.id, 'edge');
        expect(canvasToSvg(scene), contains('<path'));
        final h = CanvasHistory(scene);
        h.put(node.translated(const CanvasPoint(50, 60)));
        h.commit();
        final moved = resolveConnectorEndpoints(edge, scene);
        expect(moved.start, points.start + const CanvasPoint(50, 60));
        h.undo();
        expect(resolveConnectorEndpoints(edge, scene).start, points.start);
        final reopened = CanvasScene.fromJson(
          jsonDecode(jsonEncode(scene.toJson())),
        );
        expect(
          resolveConnectorEndpoints(reopened['edge']!, reopened).end,
          points.end,
        );
      }
    },
  );
  testWidgets(
    'single class relation saves and editing retains both navigation and custom route',
    (t) async {
      final node = newUmlClass('a', const CanvasPoint(0, 0));
      for (final nav in UmlNavigation.values) {
        final edge = CanvasElement({
          'id': 'edge',
          'type': 'connector',
          ...UmlRelationship.association.style,
          ...nav.style,
          'startId': 'a',
          'endId': 'a',
          'routing': 'curved',
          'future': 42,
        });
        Map<String, dynamic>? patch;
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    patch = await showUmlEditor(context, edge, [node]);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Open'));
        await t.pumpAndSettle();
        expect(find.text('Navigability'), findsOneWidget);
        await t.tap(find.text('Save changes'));
        await t.pumpAndSettle();
        expect(patch, isNotNull);
        final saved = edge.copy(patch!);
        expect(saved.startId, 'a');
        expect(saved.endId, 'a');
        expect(UmlNavigation.of(saved), nav);
        expect(saved.routing, 'curved');
        expect(saved.data['future'], 42);
      }
    },
  );
}
