import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/canvas_svg.dart';
import 'package:orbit_note/canvas/connectors.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/uml_interaction.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/canvas/uml_interaction_dialog.dart';

CanvasElement node(
  String id,
  UmlNodeKind kind,
  double x,
  double y,
  String name,
) => newInteractionNode(id, kind, CanvasPoint(x, y)).copy({'text': name});
CanvasElement link(
  String id,
  CanvasElement a,
  CanvasElement b,
  String count, {
  UmlLinkKind kind = UmlLinkKind.association,
  String toCount = '',
}) {
  final e = CanvasElement({'id': id, 'type': 'connector'});
  return e.copy(
    editInteractionLink(
      e,
      [a, b],
      kind: kind,
      from: a.id,
      to: b.id,
      fromMultiplicity: count,
      toMultiplicity: toCount,
    ),
  );
}

CanvasScene sample() {
  final a = node('a', UmlNodeKind.actor, 30, 90, 'Dozentin');
  final b = node('b', UmlNodeKind.actor, 50, 400, 'Kursteilnehmer*in');
  final cases = [
    node('c0', UmlNodeKind.useCase, 300, 20, 'Proberäume reservieren'),
    node('c1', UmlNodeKind.useCase, 300, 185, 'Aufführung organisieren'),
    node('c2', UmlNodeKind.useCase, 300, 350, 'Kostüme ausborgen'),
    node('c3', UmlNodeKind.useCase, 235, 530, 'Textbücher drucken'),
    node('c4', UmlNodeKind.useCase, 690, 155, 'Requisiten organisieren'),
    node('c5', UmlNodeKind.useCase, 690, 475, 'Theaterstück einstudieren'),
  ];
  return CanvasScene.fromJson({
    'schemaVersion': 1,
    'unknown': 12,
    'elements': [
      a.data,
      b.data,
      ...cases.map((e) => e.data),
      for (final i in [0, 1, 3, 4, 5])
        link('a-$i', a, cases[i], i >= 4 ? '1' : '').data,
      for (final i in [2, 3, 4, 5])
        link(
          'b-$i',
          b,
          cases[i],
          i == 4
              ? '2'
              : i == 5
              ? '2..*'
              : '0..1',
        ).data,
      link('include', cases[1], cases[4], '', kind: UmlLinkKind.include).data,
      link('extend', cases[3], cases[5], '', kind: UmlLinkKind.extend).data,
    ],
  });
}

List<CanvasPoint> path(CanvasElement e, CanvasScene scene) {
  final p = resolveConnectorEndpoints(e, scene);
  return [p.start, ...p.controlPoints, p.end];
}

void main() {
  test(
    'dense actor associations retain separate 2 and 2..* endpoint labels',
    () {
      final scene = sample();
      final labels = <CanvasBounds>[];
      for (final e in scene.elements.where(isConnectorElement)) {
        final p = resolveConnectorEndpoints(e, scene);
        expect(p.isPolyline, true, reason: e.id);
        expect(
          p.routeBlocked,
          false,
          reason: 'The crowded reference must remain routable: ${e.id}',
        );
        for (final label in connectorEndLabels(e, p)) {
          for (final n in scene.elements.where((n) => !isConnectorElement(n))) {
            expect(
              label.bounds.intersects(n.bounds),
              false,
              reason: '${e.id} label overlaps ${n.id}',
            );
          }
          for (final prior in labels) {
            expect(prior.intersects(label.bounds), false, reason: e.id);
          }
          labels.add(label.bounds);
          expect(scene.query(label.bounds).map((e) => e.id), contains(e.id));
          expect(scene.hit(label.bounds.center)?.id, e.id);
        }
      }
      for (final entry in {'b-4': '2', 'b-5': '2..*'}.entries) {
        final e = scene[entry.key]!;
        expect(
          connectorEndLabels(
            e,
            resolveConnectorEndpoints(e, scene),
          ).single.text,
          entry.value,
        );
      }
    },
  );

  test(
    'independent links and label hit areas follow actor move, undo and reopen',
    () {
      final a = node('a', UmlNodeKind.actor, 0, 100, 'Actor');
      final b = node('b', UmlNodeKind.useCase, 700, 85, 'Case');
      final e = link('edge', a, b, '2..*');
      final scene = CanvasScene.fromJson({
        'elements': [a.data, b.data, e.data],
      });
      final history = CanvasHistory(scene);
      final before = path(e, scene);
      history.put(scene['a']!.translated(const CanvasPoint(0, 150)));
      history.commit();
      final after = path(e, scene);
      expect(after, isNot(before));
      expect(resolveConnectorEndpoints(e, scene).routeBlocked, false);
      final label = connectorEndLabels(
        e,
        resolveConnectorEndpoints(e, scene),
      ).single;
      expect(scene.query(label.bounds).map((e) => e.id), contains(e.id));
      expect(scene.hit(label.bounds.center)?.id, e.id);
      final reopened = CanvasScene.fromJson(
        jsonDecode(jsonEncode(scene.toJson())),
      );
      expect(path(reopened[e.id]!, reopened), after);
      expect(history.undo(), true);
      expect(path(e, scene), before);
      expect(history.redo(), true);
      expect(path(e, scene), after);
    },
  );

  test('manual routing, anchors and unknown metadata survive label edits', () {
    final scene = sample(), e = sample()['b-5']!;
    final custom = e.copy({
      'routing': 'curved',
      'startAnchor': 'right',
      'startAnchorOffset': .3,
      'future': 42,
    });
    final edited = custom.copy(
      editInteractionLink(
        custom,
        scene.elements.where(isInteractionNode).toList(),
        kind: UmlLinkKind.association,
        from: custom.startId!,
        to: custom.endId!,
        fromMultiplicity: '2..*',
      ),
    );
    scene.put(edited);
    expect(edited.routing, 'curved');
    expect(edited.startAnchor, 'right');
    expect(edited.data['startAnchorOffset'], .3);
    expect(edited.data['future'], 42);
    expect(resolveConnectorEndpoints(edited, scene).isPolyline, false);
  });

  test(
    'hidden obstacles and enclosing boundaries do not block use-case links',
    () {
      final scene = sample();
      final e = scene['b-5']!;
      final before = path(e, scene);
      scene.put(
        node(
          'frame',
          UmlNodeKind.system,
          -50,
          -50,
          'System',
        ).copy({'width': 1100.0, 'height': 850.0}),
      );
      scene.put(
        node(
          'hidden',
          UmlNodeKind.useCase,
          200,
          400,
          'Hidden',
        ).copy({'hidden': true}),
      );
      expect(path(e, scene), before);
      expect(scene.toJson()['unknown'], 12);
    },
  );

  test('reversed association keeps only To label beside its actor', () {
    final a = node('a', UmlNodeKind.actor, 0, 50, 'Person');
    final b = node('b', UmlNodeKind.useCase, 400, 150, 'Action');
    final e = link('e', b, a, '', toCount: '2..*');
    final scene = CanvasScene.fromJson({
      'elements': [a.data, b.data, e.data],
    });
    final p = resolveConnectorEndpoints(e, scene);
    final label = connectorEndLabels(e, p).single;
    expect(label.text, '2..*');
    expect(
      (label.bounds.center - p.end).length,
      lessThan((label.bounds.center - p.start).length),
    );
    expect(canvasToSvg(scene), contains('2..*'));
    final before = jsonEncode(scene.toJson());
    resolveConnectorEndpoints(e, scene);
    canvasToSvg(scene);
    expect(jsonEncode(scene.toJson()), before);
  });

  test(
    'routed associations avoid nodes, crossing, touch points and shared lanes',
    () {
      final scene = sample();
      final paths = <List<CanvasPoint>>[];
      bool near(CanvasPoint a, CanvasPoint b, CanvasPoint c, CanvasPoint d) {
        double turn(CanvasPoint p, CanvasPoint q, CanvasPoint r) =>
            (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
        return turn(a, b, c) * turn(a, b, d) < -.001 &&
                turn(c, d, a) * turn(c, d, b) < -.001 ||
            distanceToSegment(a, c, d) < .7 ||
            distanceToSegment(b, c, d) < .7 ||
            distanceToSegment(c, a, b) < .7 ||
            distanceToSegment(d, a, b) < .7;
      }

      for (final edge in scene.elements.where(isConnectorElement)) {
        final resolved = resolveConnectorEndpoints(edge, scene);
        expect(resolved.routeBlocked, false, reason: edge.id);
        final points = path(edge, scene);
        for (final prior in paths) {
          for (var i = 1; i < points.length; i++) {
            for (var j = 1; j < prior.length; j++) {
              expect(
                near(points[i - 1], points[i], prior[j - 1], prior[j]),
                false,
                reason: '${edge.id} touches or crosses another relationship',
              );
            }
          }
        }
        for (final node in scene.elements.where(
          (e) =>
              !isConnectorElement(e) &&
              e.id != edge.startId &&
              e.id != edge.endId,
        )) {
          for (var i = 1; i < points.length; i++) {
            for (var n = 0; n <= 100; n++) {
              expect(
                node.bounds.contains(
                  points[i - 1] + (points[i] - points[i - 1]) * (n / 100),
                ),
                false,
                reason: '${edge.id} enters ${node.id}',
              );
            }
          }
        }
        paths.add(points);
      }
    },
  );

  test('temporary endpoint edits do not reuse a cached committed route', () {
    final scene = sample(), e = sample()['b-5']!;
    final before = path(e, scene);
    final preview = e.copy({'endId': 'c0'});
    final after = path(preview, scene);
    expect(after.last, isNot(before.last));
    expect(path(e, scene), before);
  });

  test(
    'selected SVG export includes the independent line and endpoint labels',
    () {
      final scene = sample(), e = scene['b-5']!;
      final svg = canvasToSvg(scene, elementIds: [e.id]);
      final match = RegExp(r'viewBox="([^"]+)"').firstMatch(svg)!;
      final values = match.group(1)!.split(' ').map(double.parse).toList();
      final bounds = CanvasBounds(values[0], values[1], values[2], values[3]);
      for (final p in path(e, scene)) {
        expect(bounds.contains(p), true);
      }
      for (final label in connectorEndLabels(
        e,
        resolveConnectorEndpoints(e, scene),
      )) {
        expect(
          bounds.contains(CanvasPoint(label.bounds.left, label.bounds.top)),
          true,
        );
        expect(
          bounds.contains(CanvasPoint(label.bounds.right, label.bounds.bottom)),
          true,
        );
      }
      expect(svg, contains('2..*'));
    },
  );

  test(
    'large use-case scene repeated navigation retains routes and authored data',
    () {
      final a = node('a', UmlNodeKind.actor, -200, 300, 'Actor');
      final cases = List.generate(
        18,
        (i) => node(
          'c$i',
          UmlNodeKind.useCase,
          200 + (i % 3) * 340.0,
          (i ~/ 3) * 200.0,
          'Use case $i',
        ),
      );
      final links = [
        for (var i = 0; i < cases.length; i++)
          link('edge-$i', a, cases[i], '2..*'),
      ];
      final clock = Stopwatch()..start();
      final scene = CanvasScene.fromJson({
        'elements': [
          a.data,
          ...cases.map((e) => e.data),
          ...links.map((e) => e.data),
        ],
      });
      final before = jsonEncode(scene.toJson());
      for (var pass = 0; pass < 25; pass++) {
        for (final edge in links) {
          final p = resolveConnectorEndpoints(edge, scene);
          expect(p.start.x.isFinite && p.end.y.isFinite, true);
          scene.query(p.bounds);
        }
      }
      expect(jsonEncode(scene.toJson()), before);
      // Diagnostic only: avoid flaky wall-clock pass/fail thresholds on shared hosts.
      debugPrint(
        '18-link layout + 450 route/query lookups: ${clock.elapsedMilliseconds} ms',
      );
    },
  );

  testWidgets(
    'swap direction carries endpoint multiplicities with their named node',
    (t) async {
      final a = node('a', UmlNodeKind.actor, 0, 0, 'Student');
      final b = node('b', UmlNodeKind.useCase, 400, 0, 'Rehearse');
      final e = link('e', a, b, '2..*', toCount: '1');
      Map<String, dynamic>? saved;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showInteractionEditor(context, e, [a, b]);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.textContaining('Shown beside Student'), findsOneWidget);
      await t.ensureVisible(find.text('Swap direction'));
      await t.tap(find.text('Swap direction'));
      await t.pumpAndSettle();
      final from = t.widget<TextField>(
        find.widgetWithText(TextField, 'From multiplicity (optional)'),
      );
      final to = t.widget<TextField>(
        find.widgetWithText(TextField, 'To multiplicity (optional)'),
      );
      expect(from.controller!.text, '1');
      expect(to.controller!.text, '2..*');
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      expect(saved!['startId'], b.id);
      expect(saved!['endId'], a.id);
      expect(saved!['endMultiplicity'], '2..*');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('real-font routed use-case preview in light and dark', (t) async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Segoe UI')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await t.runAsync(loader.load);
    }
    final scene = sample();
    for (final dark in [false, true]) {
      final colors =
          (dark ? orbitDarkTheme() : orbitTheme(preset: 'palette-sage-light'))
              .colorScheme;
      final recorder = ui.PictureRecorder();
      OrbitCanvasPainter(
        scene: scene,
        camera: const CanvasCamera(),
        selection: const {},
        textCache: CanvasTextCache(),
        colors: colors,
        objects: const {},
        fontFamily: 'Segoe UI',
        backgroundStyle: 'grid',
      ).paint(Canvas(recorder), const Size(1000, 740));
      final picture = recorder.endRecording();
      await t.runAsync(() async {
        final image = await picture.toImage(1000, 740);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('.local/uml-routing-preview')
          ..createSync(recursive: true);
        File(
          '${dir.path}/${dark ? 'dark' : 'light'}.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
      picture.dispose();
    }
  });
}
