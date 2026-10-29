// Local-only renderer probe. Reads a supplied board into memory; never opens a
// repository, account or Vault writer. Input paths/content are not in its report.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:orbit_note/app/app_preferences.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/app/canvas_performance.dart';
import 'package:orbit_note/platform/performance_log_native.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'performance/frame_statistics.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.length < 2) {
    throw ArgumentError('Supply input board and output report paths.');
  }
  final doc = jsonDecode(await File(args[0]).readAsString()) as Map;
  final camera = args.length > 2
      ? Map<String, dynamic>.from(
          jsonDecode(await File(args[2]).readAsString()) as Map,
        )
      : <String, dynamic>{'x': 0.0, 'y': 0.0, 'zoom': 1.0};
  final store = NativePerformanceLogStore(
    Directory('${args[1]}.logs'),
    defaultEnabled: true,
  );
  await store.initialize();
  await CanvasPerformance.instance.start(store: store);
  runApp(
    MaterialApp(
      theme: orbitThemeForPreferences(
        AppPreferences(themePreset: 'paper'),
        Brightness.light,
      ),
      home: _Probe(
        immutableObjectData(Map<String, dynamic>.from(doc['data'] as Map)),
        args[1],
        camera,
      ),
    ),
  );
}

class _Probe extends StatefulWidget {
  const _Probe(this.data, this.output, this.camera);
  final Map<String, dynamic> data;
  final String output;
  final Map<String, dynamic> camera;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final _frames = <ui.FrameTiming>[];
  final _stages = <Map<String, dynamic>>[];
  final _errors = <String>[];
  final _surface = GlobalKey();
  final _clock = Stopwatch()..start();
  String _status = 'Local Canvas profile';
  int _saves = 0;
  void _timings(List<ui.FrameTiming> values) => _frames.addAll(values);
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_timings);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    super.dispose();
  }

  Future<void> _frame([int count = 1]) async {
    for (var i = 0; i < count; i++) {
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame.timeout(
        const Duration(seconds: 30),
      );
    }
  }

  int get _number => ui.PlatformDispatcher.instance.frameData.frameNumber;
  Future<void> _stage(String name, Future<void> Function() action) async {
    // ignore: avoid_print
    print('CANVAS_PROFILE: $name');
    setState(() => _status = name);
    await _frame(2);
    final start = _number;
    await action();
    await _frame(2);
    _stages.add({'name': name, 'start': start, 'end': _number});
  }

  Offset get _center =>
      (_surface.currentContext!.findRenderObject() as RenderBox).localToGlobal(
        (_surface.currentContext!.findRenderObject() as RenderBox).size.center(
          Offset.zero,
        ),
      );
  void _event(PointerEvent event) =>
      GestureBinding.instance.handlePointerEvent(event);
  Future<void> _run() async {
    try {
      await _stage('cold-open', () => _frame(20));
      await _stage('idle', () async {
        await Future<void>.delayed(const Duration(seconds: 2));
        await _frame(10);
      });
      await _stage('pan-and-return', () async {
        for (var i = 0; i < 180; i++) {
          _event(
            PointerScrollEvent(
              position: _center,
              scrollDelta: Offset(math.sin(i * .04) * 8, i < 90 ? 12 : -12),
            ),
          );
          await _frame();
        }
      });
      await _stage('unrelated-parent-rebuild', () async {
        for (var i = 0; i < 60; i++) {
          setState(() {});
          await _frame();
        }
      });
      await _stage('pen-on-existing-drawing', () async {
        final start = _center - const Offset(180, 40);
        _event(
          PointerDownEvent(
            pointer: 47,
            kind: PointerDeviceKind.stylus,
            position: start,
            pressure: .5,
            timeStamp: _clock.elapsed,
          ),
        );
        for (var frame = 0; frame < 120; frame++) {
          for (var p = 0; p < 4; p++) {
            final i = frame * 4 + p;
            _event(
              PointerMoveEvent(
                pointer: 47,
                kind: PointerDeviceKind.stylus,
                position: start + Offset(i * .65, math.sin(i * .08) * 24),
                pressure: .4 + (i % 30) / 100,
                timeStamp: _clock.elapsed,
              ),
            );
          }
          await _frame();
        }
        _event(
          PointerUpEvent(
            pointer: 47,
            kind: PointerDeviceKind.stylus,
            position: start + const Offset(312, 0),
            timeStamp: _clock.elapsed,
          ),
        );
        await _frame(10);
        if (_saves != 1) _errors.add('unexpected-commit-count');
      });
      for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.stylus]) {
        await _stage('long-${kind.name}-stroke', () async {
          final start = _center;
          _event(
            PointerDownEvent(
              pointer: 48,
              kind: kind,
              position: start,
              pressure: kind == PointerDeviceKind.mouse ? 1 : .5,
              timeStamp: _clock.elapsed,
            ),
          );
          for (var frame = 0; frame < 300; frame++) {
            for (var p = 0; p < 16; p++) {
              final i = frame * 16 + p;
              _event(
                PointerMoveEvent(
                  pointer: 48,
                  kind: kind,
                  position:
                      start +
                      Offset(
                        math.sin(i * .014) * 200,
                        math.sin(i * .023) * 130,
                      ),
                  pressure: kind == PointerDeviceKind.mouse
                      ? 1
                      : .4 + (i % 30) / 100,
                  timeStamp: _clock.elapsed,
                ),
              );
            }
            await _frame();
          }
          // Exercise the drawing path without saving extra fixture edits.
          _event(
            PointerCancelEvent(
              pointer: 48,
              kind: kind,
              timeStamp: _clock.elapsed,
            ),
          );
          await _frame(10);
          if (_saves != 1) _errors.add('canceled-stroke-committed');
        });
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    } catch (error) {
      _errors.add(error.runtimeType.toString());
    }
    final unique = {for (final f in _frames) f.frameNumber: f};
    if (!mounted) return;
    final refreshRate = View.of(context).display.refreshRate;
    for (final stage in _stages) {
      final frames = unique.values
          .where(
            (f) =>
                f.frameNumber > (stage['start'] as int) &&
                f.frameNumber <= (stage['end'] as int),
          )
          .map(
            (f) => {
              'buildUs': f.buildDuration.inMicroseconds,
              'rasterUs': f.rasterDuration.inMicroseconds,
              'totalUs': f.totalSpan.inMicroseconds,
            },
          )
          .toList();
      stage['metrics'] = summarizeFrames(
        frames,
        budgetUs: 1000000 / refreshRate,
      );
      stage['frames'] = frames;
    }
    await File(widget.output).writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'stages': _stages, 'errors': _errors, 'commits': _saves}),
    );
    // ignore: avoid_print
    print('CANVAS_PROFILE: completed');
    await CanvasPerformance.instance.flush();
    exit(_errors.isEmpty ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_status)),
    body: SizedBox.expand(
      key: _surface,
      child: CanvasEditor(
        canvasId: 'local-profile',
        data: widget.data,
        camera: {
          ...widget.camera,
          'drawingTools': {
            'tool': 'pen',
            'penStyle': 'ballpoint',
            'penWidth': 1.5,
          },
        },
        objects: const [],
        onOpenObject: (_) {},
        onChanged: (_) {
          _saves++;
        },
      ),
    ),
  );
}
