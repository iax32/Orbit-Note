import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'use_case_routing_benchmark.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final output = args.firstOrNull ?? '.local/uml-perf-device.json';
  runApp(_Benchmark(output, args.length > 1 ? args[1] : null));
}

class _Benchmark extends StatefulWidget {
  const _Benchmark(this.output, this.fixture);
  final String output;
  final String? fixture;
  @override
  State<_Benchmark> createState() => _BenchmarkState();
}

class _BenchmarkState extends State<_Benchmark> {
  final key = GlobalKey();
  late final Map<String, dynamic> data = widget.fixture == null
      ? routingBenchmarkFixture()
      : jsonDecode(File(widget.fixture!).readAsStringSync())
            as Map<String, dynamic>;
  late final Map<String, dynamic> camera = () {
    final elements = (data['elements'] as List).whereType<Map>();
    final actor = elements.firstWhere(
      (e) => e['umlNode'] is Map && (e['umlNode'] as Map)['kind'] == 'actor',
    );
    return {
      'x': (actor['x'] as num).toDouble() - 300,
      'y': (actor['y'] as num).toDouble() - 250,
      'zoom': 1.0,
    };
  }();
  final frames = <ui.FrameTiming>[];
  final startupFrames = <ui.FrameTiming>[];
  void _startupTimings(List<ui.FrameTiming> values) =>
      startupFrames.addAll(values);
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_startupTimings);
    WidgetsBinding.instance.addPostFrameCallback((_) => run());
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: orbitDarkTheme(),
    home: Scaffold(
      body: CanvasEditor(
        key: key,
        canvasId: 'isolated-performance',
        data: data,
        camera: camera,
        onChanged: (_) {},
        objects: const [],
        onOpenObject: (_) {},
        defaultSnapToGrid: false,
      ),
    ),
  );

  Future<void> run() async {
    final errors = <String>[];
    final events = <int>[];
    final displacement = <double>[];
    var release = 0;
    void timings(List<ui.FrameTiming> values) => frames.addAll(values);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      SchedulerBinding.instance.removeTimingsCallback(_startupTimings);
      RenderCustomPaint? target;
      void visit(Element e) {
        if (e.widget is CustomPaint &&
            (e.widget as CustomPaint).painter is OrbitCanvasPainter) {
          target = e.renderObject as RenderCustomPaint;
        }
        e.visitChildElements(visit);
      }

      (key.currentContext! as Element).visitChildElements(visit);
      if (target == null) throw StateError('Canvas painter unavailable');
      final painter = target!.painter! as OrbitCanvasPainter;
      final a =
          painter.scene['a'] ??
          painter.scene.elements.firstWhere(
            (e) =>
                e.data['umlNode'] is Map &&
                (e.data['umlNode'] as Map)['kind'] == 'actor',
          );
      // Avoid measuring a nearby connector/route-warning hit instead of a drag.
      final candidates = [
        CanvasPoint(a.x + a.width / 2, a.y + a.height - 18),
        CanvasPoint(a.x + 25, a.y + 35),
        a.bounds.center,
      ];
      final hit = candidates.firstWhere(
        (p) => painter.scene.hit(p)?.id == a.id,
        orElse: () => throw StateError('No accessible actor hit target'),
      );
      final point = painter.camera.toScreen(hit);
      final start = target!.localToGlobal(Offset(point.x, point.y));
      SchedulerBinding.instance.addTimingsCallback(timings);
      GestureBinding.instance.handlePointerEvent(
        PointerDownEvent(
          pointer: 71,
          kind: ui.PointerDeviceKind.mouse,
          position: start,
          buttons: kPrimaryMouseButton,
        ),
      );
      for (var i = 1; i <= 32; i++) {
        final watch = Stopwatch()..start();
        GestureBinding.instance.handlePointerEvent(
          PointerMoveEvent(
            pointer: 71,
            kind: ui.PointerDeviceKind.mouse,
            position: start + Offset(i.toDouble(), i * .5),
            delta: const Offset(1, .5),
            buttons: kPrimaryMouseButton,
          ),
        );
        events.add(watch.elapsedMicroseconds);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final watch = Stopwatch()..start();
      GestureBinding.instance.handlePointerEvent(
        PointerUpEvent(
          pointer: 71,
          kind: ui.PointerDeviceKind.mouse,
          position: start + const Offset(32, 16),
        ),
      );
      release = watch.elapsedMicroseconds;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (painter.scene.canonicalRoutingPending) {
        throw StateError('Canonical background routing did not settle');
      }
      final moved = painter.scene[a.id]!;
      final delta = CanvasPoint(moved.x - a.x, moved.y - a.y);
      displacement.addAll([delta.x, delta.y]);
      // Smart alignment guides remain enabled and may adjust the final offset.
      if (delta.length < 8) {
        throw StateError('Pointer samples did not actually drag the actor');
      }
    } catch (e) {
      errors.add(e.toString());
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(timings);
      SchedulerBinding.instance.removeTimingsCallback(_startupTimings);
      final file = File(widget.output);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'synthetic': widget.fixture == null,
          'anonymizedLayout': widget.fixture != null,
          'mode': 'native-flutter-profile',
          'errors': errors,
          'eventMicroseconds': events,
          'releaseMicroseconds': release,
          'actorDisplacement': displacement,
          'startupBuildMicroseconds': startupFrames
              .map((f) => f.buildDuration.inMicroseconds)
              .toList(),
          'startupRasterMicroseconds': startupFrames
              .map((f) => f.rasterDuration.inMicroseconds)
              .toList(),
          'frameBuildMicroseconds': frames
              .map((f) => f.buildDuration.inMicroseconds)
              .toList(),
          'frameRasterMicroseconds': frames
              .map((f) => f.rasterDuration.inMicroseconds)
              .toList(),
        }),
      );
      exit(errors.isEmpty ? 0 : 1);
    }
  }
}
