import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/connectors.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/use_case_routing.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

import '../tool/use_case_routing_benchmark.dart';

void expectIndexMatchesFresh(CanvasScene scene) {
  final fresh = CanvasScene.fromJson(scene.toJson());
  final a = scene.contentBounds!, b = fresh.contentBounds!;
  expect(
    [a.left, a.top, a.width, a.height],
    [b.left, b.top, b.width, b.height],
  );
  for (var x = -100.0; x < 1100; x += 150) {
    final bounds = CanvasBounds(x, -100, 120, 1000);
    expect(
      scene.query(bounds).map((e) => e.id),
      fresh.query(bounds).map((e) => e.id),
    );
  }
}

void main() {
  test(
    'ignored future routing metadata remains portable through the worker',
    () async {
      final data = routingBenchmarkFixture();
      final elements = data['elements'] as List;
      final index = elements.indexWhere((e) => e is Map && e['id'] == 'a-0');
      elements[index] = {
        ...Map<String, dynamic>.from(elements[index] as Map),
        'startAnchorOffset': {'future': true},
        'routingOffset': {'version': 2},
        'umlLink': {
          'kind': 'association',
          'position': {'future': true},
        },
      };
      final scene = CanvasScene.fromJson(data);
      scene.beginInteractiveRouting();
      scene.put(scene['a']!.translated(const CanvasPoint(4, 2)));
      expect(scene.finishInteractiveRouting(deferCanonical: true), true);
      final source = jsonEncode(scene.toJson());
      final prepared = await compute(prepareUseCaseRouting, scene.toJson());
      expect(scene.applyPreparedRouting(prepared), true);
      expect(jsonEncode(scene.toJson()), source);
      expect(
        routingSnapshot(scene),
        routingSnapshot(CanvasScene.fromJson(scene.toJson())),
      );
    },
  );
  test(
    'background canonical routing preserves authored data, exact routes and bounds',
    () async {
      final scene = CanvasScene.fromJson(routingBenchmarkFixture());
      scene.beginInteractiveRouting();
      scene.put(scene['a']!.translated(const CanvasPoint(4, 2)));
      expect(scene.finishInteractiveRouting(deferCanonical: true), true);
      final source = jsonEncode(scene.toJson());
      final clock = Stopwatch()..start();
      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 2),
        (_) => ticks++,
      );
      try {
        final prepared = await compute(prepareUseCaseRouting, scene.toJson());
        expect(scene.applyPreparedRouting(prepared), true);
        expect(scene.canonicalRoutingPending, false);
        expect(ticks, greaterThan(0));
        expect(jsonEncode(scene.toJson()), source);
        expect(
          routingSnapshot(scene),
          routingSnapshot(CanvasScene.fromJson(scene.toJson())),
        );
        expectIndexMatchesFresh(scene);
        debugPrint(
          'Background canonical routing: ${clock.elapsedMicroseconds} us wall time, $ticks event-loop ticks',
        );
      } finally {
        timer.cancel();
      }
    },
  );

  test(
    'late worker geometry cannot replace a later move or active drag',
    () async {
      final scene = CanvasScene.fromJson(routingBenchmarkFixture());
      scene.beginInteractiveRouting();
      scene.put(scene['a']!.translated(const CanvasPoint(4, 2)));
      expect(scene.finishInteractiveRouting(deferCanonical: true), true);
      final worker = compute(prepareUseCaseRouting, scene.toJson());
      scene.beginInteractiveRouting();
      scene.put(scene['a']!.translated(const CanvasPoint(2, 1)));
      final stale = await worker;
      expect(scene.applyPreparedRouting(stale), false);
      scene.finishInteractiveRouting(deferCanonical: true);
      expect(scene.applyPreparedRouting(stale), false);
      final authored = jsonEncode(scene.toJson());
      final latest = await compute(prepareUseCaseRouting, scene.toJson());
      expect(scene.applyPreparedRouting(latest), true);
      expect(jsonEncode(scene.toJson()), authored);
      expectIndexMatchesFresh(scene);
    },
  );

  test(
    'worker preserves later appearance and retires when all links disappear',
    () async {
      final scene = CanvasScene.fromJson(routingBenchmarkFixture());
      scene.beginInteractiveRouting();
      scene.put(scene['a']!.translated(const CanvasPoint(4, 2)));
      scene.finishInteractiveRouting(deferCanonical: true);
      final work = compute(prepareUseCaseRouting, scene.toJson());
      scene.put(
        scene['a']!.copy({
          'color': 0xffabcdef,
          'future-field': {'keep': true},
        }),
      );
      final authored = jsonEncode(scene.toJson());
      expect(scene.applyPreparedRouting(await work), true);
      expect(jsonEncode(scene.toJson()), authored);
      scene.beginInteractiveRouting();
      scene.put(scene['a']!.translated(const CanvasPoint(2, 1)));
      expect(scene.finishInteractiveRouting(deferCanonical: true), true);
      scene.batch(() {
        for (final e in scene.elements.where(isConnectorElement).toList()) {
          scene.remove(e.id);
        }
      });
      final empty = await compute(prepareUseCaseRouting, scene.toJson());
      expect(scene.applyPreparedRouting(empty), false);
      expect(scene.canonicalRoutingPending, false);
    },
  );

  testWidgets(
    'cold diagram preparation ignores a replaced Canvas and never emits authored edits',
    (t) async {
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final large = routingBenchmarkFixture();
      final elements = large['elements'] as List;
      elements.add({
        ...Map<String, dynamic>.from(
          elements.firstWhere((e) => e is Map && e['id'] == 'a-0') as Map,
        ),
        'id': 'extra',
      });
      var writes = 0;
      Widget host(String id, Map<String, dynamic> data) => MaterialApp(
        home: Scaffold(
          body: CanvasEditor(
            canvasId: id,
            data: data,
            onChanged: (_) => writes++,
            objects: const [],
            onOpenObject: (_) {},
            camera: const {'x': 0.0, 'y': 0.0, 'zoom': 1.0},
          ),
        ),
      );
      final paint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
      );
      await t.pumpWidget(host('old', large));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.pumpWidget(
        host('new', {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'only',
              'type': 'rectangle',
              'width': 100.0,
              'height': 100.0,
            },
          ],
        }),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await t.pump();
      expect(
        (t.widget<CustomPaint>(paint).painter! as OrbitCanvasPainter)
            .scene
            .length,
        1,
      );
      await t.pumpWidget(host('large', large));
      for (var i = 0; i < 400 && paint.evaluate().isEmpty; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump();
      }
      expect(paint, findsOneWidget);
      final scene =
          (t.widget<CustomPaint>(paint).painter! as OrbitCanvasPainter).scene;
      expect(scene.canonicalRoutingPending, false);
      expect(writes, 0);
      expect(
        routingSnapshot(scene),
        routingSnapshot(CanvasScene.fromJson(large)),
      );
      expectIndexMatchesFresh(scene);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  test(
    'appearance, stacking and attached fallback writes preserve routes and labels',
    () {
      final scene = CanvasScene.fromJson(routingBenchmarkFixture());
      final original = routingSnapshot(scene);
      final watch = Stopwatch()..start();
      for (var i = 0; i < 12; i++) {
        scene.batch(() {
          scene.put(
            scene['a']!.copy({'color': 0xff123456 + i, 'locked': i.isEven}),
          );
          for (final e in scene.elements.where(isConnectorElement).toList()) {
            final p = resolveConnectorEndpoints(e, scene);
            scene.put(e.copy(connectorEndpointData(p.start, p.end)));
          }
        });
        scene.bringToFront('a');
        expect(routingSnapshot(scene), original);
      }
      debugPrint(
        '12 style/fallback transactions: ${watch.elapsedMicroseconds} us',
      );
      expectIndexMatchesFresh(scene);
    },
  );

  test('nested batches and throwing mutations leave valid spatial bounds', () {
    final scene = CanvasScene.fromJson(routingBenchmarkFixture());
    expect(
      () => scene.batch(() {
        scene.put(scene['a']!.translated(const CanvasPoint(15, 7)));
        scene.batch(
          () => scene.put(scene['c0']!.translated(const CanvasPoint(20, 0))),
        );
        // A query within the batch must never observe stale connector hit bounds.
        final p = resolveConnectorEndpoints(scene['a-0']!, scene);
        expect(scene.query(p.bounds).map((e) => e.id), contains('a-0'));
        throw StateError('cancel caller');
      }),
      throwsStateError,
    );
    expectIndexMatchesFresh(scene);
    scene.remove('a-0');
    scene.batch(() => scene.remove('a-4'));
    expectIndexMatchesFresh(scene);
  });

  test(
    'interactive movement finalizes to the same canonical routes after reopening',
    () {
      final scene = CanvasScene.fromJson(routingBenchmarkFixture());
      final original = jsonEncode(scene.toJson());
      final history = CanvasHistory(scene);
      scene.beginInteractiveRouting();
      for (var i = 0; i < 12; i++) {
        scene.batch(() {
          history.put(scene['a']!.translated(const CanvasPoint(1, .5)));
          for (final e
              in scene.elements
                  .where((e) => isConnectorElement(e) && e.startId == 'a')
                  .toList()) {
            final p = resolveConnectorEndpoints(e, scene);
            history.put(e.copy(connectorEndpointData(p.start, p.end)));
          }
        });
        for (final e in scene.elements.where(isConnectorElement)) {
          expect(resolveConnectorEndpoints(e, scene).start.x.isFinite, true);
        }
      }
      history.cancel();
      scene.finishInteractiveRouting();
      expect(scene.interactiveRouting, false);
      expect(jsonEncode(scene.toJson()), original);
      expect(
        routingSnapshot(scene),
        routingSnapshot(CanvasScene.fromJson(scene.toJson())),
      );
      expectIndexMatchesFresh(scene);
      scene.beginInteractiveRouting();
      scene.put(scene['a']!.translated(const CanvasPoint(17, 9)));
      scene.finishInteractiveRouting();
      expect(
        routingSnapshot(scene),
        routingSnapshot(CanvasScene.fromJson(scene.toJson())),
      );
    },
  );

  test('a moved unrelated obstacle invalidates preview geometry safely', () {
    final fixture = routingBenchmarkFixture();
    final scene = CanvasScene.fromJson(fixture);
    scene.beginInteractiveRouting();
    scene.put(scene['c2']!.translated(const CanvasPoint(-70, -80)));
    final during = routingSnapshot(scene);
    expect(during.keys, hasLength(11));
    scene.finishInteractiveRouting();
    expect(
      routingSnapshot(scene),
      routingSnapshot(CanvasScene.fromJson(scene.toJson())),
    );
    expectIndexMatchesFresh(scene);
  });

  testWidgets(
    'real editor drag batches related edges and releases interactive routing',
    (t) async {
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var data = routingBenchmarkFixture();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'synthetic',
              data: data,
              onChanged: (v) => data = v,
              objects: const [],
              onOpenObject: (_) {},
              camera: const {'x': 0.0, 'y': 0.0, 'zoom': 1.0},
              defaultSnapToGrid: false,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final finder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
      );
      OrbitCanvasPainter painter() =>
          t.widget<CustomPaint>(finder).painter! as OrbitCanvasPainter;
      final actor = painter().scene['a']!;
      final screen = painter().camera.toScreen(
        CanvasPoint(actor.x + 25, actor.y + 35),
      );
      final gesture = await t.startGesture(
        t.getTopLeft(finder) + Offset(screen.x, screen.y),
      );
      await t.pump();
      final times = <int>[];
      for (var i = 0; i < 12; i++) {
        final clock = Stopwatch()..start();
        await gesture.moveBy(const Offset(2, 1));
        await t.pump(const Duration(milliseconds: 16));
        times.add(clock.elapsedMicroseconds);
      }
      expect(painter().scene.interactiveRouting, true);
      await gesture.up();
      await t.pumpAndSettle();
      for (var i = 0; i < 400 && painter().scene.canonicalRoutingPending; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump();
      }
      expect(painter().scene.canonicalRoutingPending, false);
      expect(painter().scene.interactiveRouting, false);
      expect(
        routingSnapshot(painter().scene),
        routingSnapshot(CanvasScene.fromJson(data)),
      );
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final f = File('.local/uml-perf-widget-drag.json');
        f.parent.createSync(recursive: true);
        f.writeAsStringSync(
          jsonEncode({
            'synthetic': true,
            'mode': 'flutter-test-debug',
            'includesPointerAndPump': true,
            'microseconds': times,
          }),
        );
      });
    },
  );
}
