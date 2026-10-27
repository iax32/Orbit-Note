import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/canvas_svg.dart';
import 'package:orbit_note/canvas/connectors.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/use_case_routing.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import '../tool/use_case_stress_fixtures.dart';
import '../tool/use_case_routing_benchmark.dart';

void verifyRoutes(CanvasScene scene, {bool allowPending = false}) {
  final paths = <List<CanvasPoint>>[];
  for (final edge in scene.elements.where(isConnectorElement)) {
    final route = resolveConnectorEndpoints(edge, scene);
    if (allowPending && route.routeBlocked) continue;
    expect(route.routeBlocked, false, reason: edge.id);
    final points = [route.start, ...route.controlPoints, route.end];
    double turn(CanvasPoint p, CanvasPoint q, CanvasPoint r) =>
        (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
    for (final prior in paths) {
      for (var i = 1; i < points.length; i++) {
        for (var j = 1; j < prior.length; j++) {
          final a = points[i - 1],
              b = points[i],
              c = prior[j - 1],
              d = prior[j];
          expect(
            turn(a, b, c) * turn(a, b, d) < -.001 &&
                turn(c, d, a) * turn(c, d, b) < -.001,
            false,
            reason: '${edge.id} crosses another connection',
          );
          expect(
            [
              distanceToSegment(a, c, d),
              distanceToSegment(b, c, d),
              distanceToSegment(c, a, b),
              distanceToSegment(d, a, b),
            ].reduce((a, b) => a < b ? a : b),
            greaterThan(.005),
            reason: '${edge.id} shares a trunk/touch point',
          );
        }
      }
    }
    for (final node in scene.elements.where(
      (e) =>
          !isConnectorElement(e) && e.id != edge.startId && e.id != edge.endId,
    )) {
      for (var i = 1; i < points.length; i++) {
        // Uniform samples across every segment independently of the route solver.
        final steps = ((points[i] - points[i - 1]).length / 3).ceil().clamp(
          1,
          4000,
        );
        for (var n = 0; n <= steps; n++) {
          expect(
            node.bounds.contains(
              points[i - 1] + (points[i] - points[i - 1]) * (n / steps),
            ),
            false,
            reason: '${edge.id} crosses ${node.id}',
          );
        }
      }
    }
    paths.add(points);
  }
}

void main() {
  test(
    'a large mixed board keeps unrelated placements and usable actor routes',
    () {
      final data = coffeeMachineRoutingFixture();
      (data['elements'] as List).addAll(<Map<String, dynamic>>[
        for (var i = 0; i < 600; i++)
          {
            'id': 'distant-$i',
            'type': 'rectangle',
            'x': 100000.0 + (i % 30) * 300,
            'y': 100000.0 + (i ~/ 30) * 200,
            'width': 120.0,
            'height': 80.0,
            'future': i,
          },
      ]);
      final original = jsonEncode(data);
      final watch = Stopwatch()..start();
      final scene = CanvasScene.fromJson(data);
      for (final edge in scene.elements.where(isConnectorElement)) {
        expect(
          resolveConnectorEndpoints(edge, scene).routeBlocked,
          false,
          reason: edge.id,
        );
      }
      debugPrint(
        'Mixed board 600 unrelated items + 16 links: ${watch.elapsedMilliseconds} ms',
      );
      expect(jsonEncode(scene.toJson()), original);
    },
  );
  test('manual diagonal grid-corner crossings remain hard obstacles', () {
    final data = highDegreeRoutingFixture(1, bothSides: false);
    (data['elements'] as List).add({
      'id': 'manual',
      'type': 'line',
      'startX': 700.0,
      'startY': -192.0,
      'endX': 892.0,
      'endY': 192.0,
      'startMarker': 'none',
      'endMarker': 'none',
    });
    final scene = CanvasScene.fromJson(data);
    final before = jsonEncode(scene['manual']!.data);
    verifyRoutes(scene);
    scene.put(scene['a']!.translated(const CanvasPoint(96, -96)));
    verifyRoutes(scene);
    expect(jsonEncode(scene['manual']!.data), before);
  });
  test('small coffee layout nudges retain all sixteen connections', () {
    for (final delta in [
      const CanvasPoint(-2, -2),
      const CanvasPoint(-2, 2),
      const CanvasPoint(2, -2),
      const CanvasPoint(2, 2),
    ]) {
      final scene = CanvasScene.fromJson(coffeeMachineRoutingFixture());
      scene.put(scene['a']!.translated(delta));
      verifyRoutes(scene);
    }
  });
  test('missing endpoints do not poison the remaining high-degree fan', () {
    final data = highDegreeRoutingFixture(24);
    (data['elements'] as List).removeWhere((e) => e['id'] == 'c0');
    final scene = CanvasScene.fromJson(data);
    for (final e in scene.elements.where(isConnectorElement)) {
      final p = resolveConnectorEndpoints(e, scene);
      expect(p.start.x.isFinite && p.end.y.isFinite, true);
      if (e.endId != 'c0') expect(p.routeBlocked, false, reason: e.id);
    }
    expect(
      scene['a-c0'],
      isNotNull,
      reason: 'Unresolved authoring data is retained',
    );
  });
  test(
    'coffee-machine topology keeps all sixteen independent routes and source data',
    () {
      final data = coffeeMachineRoutingFixture();
      final original = jsonEncode(data);
      final scene = CanvasScene.fromJson(data);
      verifyRoutes(scene);
      expect(scene.elements.where(isConnectorElement), hasLength(16));
      expect(
        canvasToSvg(scene),
        isNot(contains('data-route-status="blocked"')),
      );
      expect(jsonEncode(data), original);
      expect(
        routingSnapshot(CanvasScene.fromJson(scene.toJson())),
        routingSnapshot(scene),
      );
    },
  );

  for (final count in [12, 24, 48, 64]) {
    for (final both in [false, true]) {
      test(
        '$count connections on ${both ? 'two sides' : 'one side'} retain distinct paths',
        () {
          final clock = Stopwatch()..start();
          final scene = CanvasScene.fromJson(
            highDegreeRoutingFixture(count, bothSides: both),
          );
          debugPrint(
            '$count links, bothSides=$both layout: ${clock.elapsedMilliseconds} ms',
          );
          verifyRoutes(scene);
          final labels = <CanvasBounds>[];
          for (final edge in scene.elements.where(isConnectorElement)) {
            for (final label in connectorEndLabels(
              edge,
              resolveConnectorEndpoints(edge, scene),
            )) {
              for (final node in scene.elements.where(
                (e) => !isConnectorElement(e),
              )) {
                expect(
                  label.bounds.intersects(node.bounds),
                  false,
                  reason: '${edge.id} label on ${node.id}',
                );
              }
              for (final old in labels) {
                expect(
                  label.bounds.intersects(old),
                  false,
                  reason: '${edge.id} labels overlap',
                );
              }
              labels.add(label.bounds);
            }
          }
        },
      );
    }
  }

  test(
    'large fan moves safely, finalizes in worker, and undo restores all routes',
    () async {
      final scene = CanvasScene.fromJson(highDegreeRoutingFixture(48));
      final source = jsonEncode(scene.toJson());
      final before = routingSnapshot(scene);
      final history = CanvasHistory(scene);
      scene.beginInteractiveRouting();
      final samples = <int>[];
      for (var i = 0; i < 12; i++) {
        final watch = Stopwatch()..start();
        history.put(scene['a']!.translated(const CanvasPoint(1, .5)));
        routingSnapshot(scene);
        for (final edge in scene.elements.where(isConnectorElement)) {
          expect(
            resolveConnectorEndpoints(edge, scene).start.x,
            closeTo(scene['a']!.bounds.center.x, .001),
            reason: '${edge.id} detached during drag',
          );
        }
        samples.add(watch.elapsedMicroseconds);
        verifyRoutes(scene, allowPending: true);
      }
      history.commit();
      final deferred = scene.finishInteractiveRouting(deferCanonical: true);
      if (deferred) {
        final prepared = await compute(prepareUseCaseRouting, scene.toJson());
        expect(scene.applyPreparedRouting(prepared), true);
      }
      verifyRoutes(scene);
      expect(
        routingSnapshot(CanvasScene.fromJson(scene.toJson())),
        routingSnapshot(scene),
      );
      expect(history.undo(), true);
      expect(jsonEncode(scene.toJson()), source);
      expect(routingSnapshot(scene), before);
      samples.sort();
      debugPrint(
        '48-link drag event p95: ${samples[(samples.length * .95).floor()]} us',
      );
    },
  );

  testWidgets('actual-font coffee diagram remains legible in both palettes', (
    t,
  ) async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Segoe UI')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }
    final scene = CanvasScene.fromJson(coffeeMachineRoutingFixture());
    for (final dark in [false, true]) {
      final recorder = ui.PictureRecorder();
      OrbitCanvasPainter(
        scene: scene,
        camera: const CanvasCamera(x: -50, y: -20, zoom: 1),
        selection: const {},
        textCache: CanvasTextCache(),
        objects: const {},
        fontFamily: 'Segoe UI',
        colors:
            (dark ? orbitDarkTheme() : orbitTheme(preset: 'palette-sage-light'))
                .colorScheme,
        backgroundStyle: 'grid',
      ).paint(Canvas(recorder), const Size(1200, 1080));
      final picture = recorder.endRecording();
      await t.runAsync(() async {
        final image = await picture.toImage(1200, 1080);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('.local/coffee-routing-preview').createSync(recursive: true);
        File(
          '.local/coffee-routing-preview/${dark ? 'dark' : 'light'}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      picture.dispose();
    }
  });
}
