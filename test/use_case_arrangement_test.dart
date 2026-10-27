import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/connectors.dart';
import 'package:orbit_note/canvas/canvas_svg.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/uml_interaction.dart';
import 'package:orbit_note/canvas/use_case_arrangement.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import '../tool/use_case_routing_benchmark.dart';

void apply(CanvasScene scene, List<CanvasElement> edits) => scene.batch(() {
  for (final e in edits) {
    scene.put(e);
  }
});

void separated(CanvasScene scene) {
  final routes = <List<CanvasPoint>>[];
  for (final edge in scene.elements.where(isConnectorElement)) {
    final p = resolveConnectorEndpoints(edge, scene);
    expect(p.routeBlocked, false, reason: edge.id);
    final points = [p.start, ...p.controlPoints, p.end];
    double turn(CanvasPoint p, CanvasPoint q, CanvasPoint r) =>
        (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
    for (final other in routes) {
      for (var i = 1; i < points.length; i++) {
        for (var j = 1; j < other.length; j++) {
          final a = points[i - 1],
              b = points[i],
              c = other[j - 1],
              d = other[j];
          expect(
            turn(a, b, c) * turn(a, b, d) < -.001 &&
                turn(c, d, a) * turn(c, d, b) < -.001,
            false,
            reason: '${edge.id} crosses another line',
          );
          for (final distance in [
            distanceToSegment(a, c, d),
            distanceToSegment(b, c, d),
            distanceToSegment(c, a, b),
            distanceToSegment(d, a, b),
          ]) {
            expect(
              distance,
              greaterThan(.7),
              reason: '${edge.id} shares a line/touch',
            );
          }
        }
      }
    }
    for (final node in scene.elements.where(
      (e) =>
          !isConnectorElement(e) && e.id != edge.startId && e.id != edge.endId,
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
    routes.add(points);
  }
}

void main() {
  test(
    'blocked automatic connection never invents an overlapping fallback',
    () {
      final a = newInteractionNode(
        'a',
        UmlNodeKind.actor,
        const CanvasPoint(0, 0),
      );
      final b = newInteractionNode(
        'b',
        UmlNodeKind.useCase,
        const CanvasPoint(500, 0),
      );
      final obstacle = CanvasElement({
        'id': 'blocking',
        'type': 'rectangle',
        'x': -100.0,
        'y': -100.0,
        'width': 350.0,
        'height': 400.0,
      });
      final e = CanvasElement({'id': 'edge', 'type': 'connector'});
      final link = e.copy(
        editInteractionLink(
          e,
          [a, b],
          kind: UmlLinkKind.association,
          from: a.id,
          to: b.id,
          fromMultiplicity: '2..*',
        ),
      );
      final scene = CanvasScene.fromJson({
        'elements': [a.data, b.data, obstacle.data, link.data],
      });
      final unresolved = resolveConnectorEndpoints(link, scene);
      expect(unresolved.routeBlocked, true);
      final warning = connectorRouteWarningBounds(unresolved);
      expect(scene.hit(warning.center)?.id, link.id);
      expect(scene.query(warning).map((e) => e.id), contains(link.id));
      final ghost = List.generate(
        10,
        (i) =>
            unresolved.start +
            (unresolved.end - unresolved.start) * ((i + 1) / 11),
      ).firstWhere((p) => !warning.inflate(6).contains(p));
      expect(hitTestConnector(link, scene, ghost), false);
      final svg = canvasToSvg(scene, elementIds: [link.id]);
      expect(svg, contains('data-route-status="blocked"'));
      expect(svg, contains('Organize diagram'));
      expect(svg, isNot(contains('<path')));
      expect(scene[link.id]!.startId, a.id);
      expect(scene[link.id]!.endId, b.id);
      scene.remove(obstacle.id);
      expect(resolveConnectorEndpoints(link, scene).routeBlocked, false);
    },
  );

  test(
    'containing boundary expands; unrelated and locked boundary data stay',
    () {
      final scene = CanvasScene.fromJson(routingBenchmarkFixture());
      final frame = newInteractionNode(
        'system',
        UmlNodeKind.system,
        const CanvasPoint(200, -20),
      ).copy({'width': 850.0, 'height': 740.0, 'future': 42});
      final lockedFrame = frame.copy({'id': 'locked-frame', 'locked': true});
      scene.batch(() {
        scene.put(frame);
        scene.put(lockedFrame);
      });
      apply(scene, organizeUseCases(scene));
      for (final e in scene.elements.where(
        (e) => umlNodeKind(e) == UmlNodeKind.useCase,
      )) {
        expect(
          scene[frame.id]!.bounds.contains(e.bounds.center),
          true,
          reason: e.id,
        );
      }
      expect(scene[frame.id]!.data['future'], 42);
      expect(scene[lockedFrame.id]!.data, lockedFrame.data);
    },
  );

  test(
    'organize crowded actor diagram: separate lines, metadata, undo and reopen',
    () {
      final data = routingBenchmarkFixture()..['futureRoot'] = {'version': 7};
      final scene = CanvasScene.fromJson(data);
      scene.put(
        scene['c2']!.copy({
          'future': [1, 2],
          'objectId': 'canonical-source',
        }),
      );
      final before = jsonEncode(scene.toJson());
      final history = CanvasHistory(scene);
      final watch = Stopwatch()..start();
      final edits = organizeUseCases(scene);
      scene.batch(() {
        for (final e in edits) {
          history.put(e);
        }
      });
      history.commit();
      debugPrint('Organize 8 nodes/11 links: ${watch.elapsedMicroseconds} us');
      expect(edits, isNotEmpty);
      expect(scene['a']!.x, lessThan(scene['c0']!.x));
      expect(scene['b']!.x, greaterThan(scene['c0']!.bounds.right));
      expect(scene['c2']!.objectId, 'canonical-source');
      expect(scene['c2']!.data['future'], [1, 2]);
      separated(scene);
      final after = jsonEncode(scene.toJson());
      expect(
        routingSnapshot(CanvasScene.fromJson(jsonDecode(after))),
        routingSnapshot(scene),
      );
      expect(
        organizeUseCases(scene),
        isEmpty,
        reason: 'Organization is stable',
      );
      expect(history.undo(), true);
      expect(jsonEncode(scene.toJson()), before);
      expect(history.redo(), true);
      expect(jsonEncode(scene.toJson()), after);
    },
  );

  test(
    'selection scopes connected component; locks and unrelated content survive',
    () {
      final scene = CanvasScene.fromJson(routingBenchmarkFixture());
      final unrelated = newInteractionNode(
        'outside',
        UmlNodeKind.useCase,
        const CanvasPoint(0, 0),
      );
      final locked = scene['c2']!.copy({'locked': true});
      final manual = scene['a-0']!.copy({
        'routing': 'curved',
        'startAnchor': 'left',
        'controlPoints': [
          {'x': -12, 'y': -34},
        ],
        'future': 'keep',
      });
      scene.batch(() {
        scene.put(unrelated);
        scene.put(locked);
        scene.put(manual);
      });
      apply(scene, organizeUseCases(scene, selection: {'a-1'}));
      expect(scene['outside']!.data, unrelated.data);
      expect(scene['c2']!.data, locked.data);
      expect(scene['a-0']!.routing, 'curved');
      expect(scene['a-0']!.startAnchor, 'left');
      expect(scene['a-0']!.data['controlPoints'], manual.data['controlPoints']);
      expect(scene['a-0']!.data['future'], 'keep');
      expect(organizeUseCases(scene, selection: {'missing'}), isEmpty);
      final readOnly = CanvasScene.fromJson({
        ...scene.toJson(),
        'schemaVersion': 999,
      });
      expect(organizeUseCases(readOnly), isEmpty);
    },
  );

  test(
    'short front-side path beats a back-side loop around a clear use case',
    () {
      final a = newInteractionNode(
        'a',
        UmlNodeKind.actor,
        const CanvasPoint(0, 0),
      );
      final b = newInteractionNode(
        'b',
        UmlNodeKind.useCase,
        const CanvasPoint(300, 260),
      );
      final edge = CanvasElement({'id': 'edge', 'type': 'connector'});
      final link = edge.copy(
        editInteractionLink(
          edge,
          [a, b],
          kind: UmlLinkKind.association,
          from: a.id,
          to: b.id,
          fromMultiplicity: '2..*',
        ),
      );
      final scene = CanvasScene.fromJson({
        'elements': [a.data, b.data, link.data],
      });
      final route = resolveConnectorEndpoints(link, scene);
      expect(route.routeBlocked, false);
      expect(route.end.x, lessThanOrEqualTo(b.bounds.center.x));
      expect(
        [
          route.start,
          ...route.controlPoints,
          route.end,
        ].every((p) => p.x <= b.bounds.right),
        true,
      );
      expect(route.controlPoints.length, lessThanOrEqualTo(3));
    },
  );

  testWidgets('organize button emits one reversible placement command', (
    t,
  ) async {
    t.view.physicalSize = const Size(1800, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final original = routingBenchmarkFixture();
    final writes = <Map<String, dynamic>>[];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanvasEditor(
            canvasId: 'layout',
            data: original,
            objects: const [],
            onOpenObject: (_) {},
            onChanged: writes.add,
          ),
        ),
      ),
    );
    await t.pump();
    await t.tap(find.byKey(const ValueKey('canvas-organize-use-cases')));
    await t.pump();
    expect(writes, hasLength(1));
    separated(CanvasScene.fromJson(writes.single));
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    expect(writes, hasLength(2));
    expect(writes.last['elements'], original['elements']);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('organized real-font light and dark diagram previews', (t) async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Segoe UI')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }
    final scene = CanvasScene.fromJson(routingBenchmarkFixture());
    apply(scene, organizeUseCases(scene));
    for (final dark in [false, true]) {
      final recorder = ui.PictureRecorder();
      OrbitCanvasPainter(
        scene: scene,
        camera: const CanvasCamera(x: -40, y: -40, zoom: .8),
        selection: const {},
        textCache: CanvasTextCache(),
        objects: const {},
        colors:
            (dark ? orbitDarkTheme() : orbitTheme(preset: 'palette-sage-light'))
                .colorScheme,
        fontFamily: 'Segoe UI',
        backgroundStyle: 'grid',
      ).paint(Canvas(recorder), const Size(1450, 1200));
      final picture = recorder.endRecording();
      await t.runAsync(() async {
        final image = await picture.toImage(1450, 1200);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('.local/uml-organized-preview').createSync(recursive: true);
        File(
          '.local/uml-organized-preview/${dark ? 'dark' : 'light'}.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
      picture.dispose();
    }
  });
}
