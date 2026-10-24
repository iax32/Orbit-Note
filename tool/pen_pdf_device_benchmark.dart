// Native Windows profile harness. Uses synthetic, in-memory documents only.
// No workspace/account controller is constructed. dart:io stays in this tool.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import '../test/support/pdf_fixture.dart' show largeResearchPdf;
import 'performance/frame_statistics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  runApp(const MaterialApp(home: _DeviceBenchmark()));
}

class _DeviceBenchmark extends StatefulWidget {
  const _DeviceBenchmark();
  @override
  State<_DeviceBenchmark> createState() => _DeviceBenchmarkState();
}

class _DeviceBenchmarkState extends State<_DeviceBenchmark> {
  final _surface = GlobalKey();
  final _clock = Stopwatch()..start();
  final _timings = <ui.FrameTiming>[];
  final _stages = <Map<String, dynamic>>[];
  final _errors = <String>[];
  final _latency = <int>[];
  late final Map<String, dynamic> _data = {
    'schemaVersion': 1,
    'elements': [
      for (var s = 0; s < 100; s++)
        {
          'id': 'ink-$s',
          'type': 'ink',
          'x': 20.0,
          'y': 5 + s * 6.0,
          'width': 800.0,
          'height': 10.0,
          'strokeWidth': 3.0,
          'color': 0xff76c8aa,
          'penStyle': 'ballpoint',
          'points': [
            for (var p = 0; p < 1000; p++)
              {
                'x': p * .8,
                'y': 5 + math.sin(p * .03) * 4,
                'pressure': .2 + (p % 100) / 125,
                'timeMs': p,
              },
          ],
        },
    ],
  };
  late final _pdf = largeResearchPdf();
  late final _annotations = [
    for (var p = 1; p <= 300; p++)
      for (var n = 0; n < 10; n++)
        PdfAnnotation(
          UniversalObject(
            id: 'mark-$p-$n',
            workspaceId: 'benchmark',
            typeId: 'orbit.note',
            title: 'Synthetic highlight',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            properties: {
              'pdfHighlightVersion': 1,
              'pdfSource': {
                'objectId': 'benchmark-pdf',
                'checksum': 'synthetic-v1',
                'page': p,
                'quote': 'Synthetic evidence',
                'regions': [
                  for (var r = 0; r < 8; r++)
                    {
                      'id': '$p:$n:$r',
                      'type': 'rectangle',
                      'page': p,
                      'x': .08 + r * .09,
                      'y': .12 + n * .04,
                      'width': .07,
                      'height': .018,
                      'color': 0xffeab308,
                    },
                ],
              },
            },
          ),
        ),
  ];
  bool _pdfMode = false;
  String _status = 'Preparing isolated performance run';
  int _saves = 0, _pdfPage = 1;
  double _refreshRate = 60;
  int _inputEvents = 0;
  FlutterExceptionHandler? _oldErrorHandler;

  @override
  void initState() {
    super.initState();
    _oldErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      _errors.add(details.exceptionAsString());
      _oldErrorHandler?.call(details);
    };
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _onTimings(List<ui.FrameTiming> timings) => _timings.addAll(timings);

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    FlutterError.onError = _oldErrorHandler;
    super.dispose();
  }

  Future<void> _frames(int count) async {
    for (var i = 0; i < count; i++) {
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame.timeout(
        const Duration(seconds: 30),
      );
    }
  }

  int get _frameNumber => ui.PlatformDispatcher.instance.frameData.frameNumber;

  Future<void> _stage(String name, Future<void> Function() action) async {
    stdout.writeln('ORBIT_BENCH_STAGE: $name');
    setState(() => _status = name);
    await _frames(2);
    final start = _frameNumber;
    final rss = ProcessInfo.currentRss;
    final watch = Stopwatch()..start();
    await action();
    await _frames(2);
    _stages.add({
      'name': name,
      'startExclusive': start,
      'endInclusive': _frameNumber,
      'wallMs': watch.elapsedMilliseconds,
      'rssStartBytes': rss,
      'rssEndBytes': ProcessInfo.currentRss,
    });
  }

  Offset _canvasCenter() {
    Offset? found;
    void visit(Element e) {
      if (e.widget is CustomPaint &&
          (e.widget as CustomPaint).painter is OrbitCanvasPainter) {
        final box = e.renderObject as RenderBox;
        found = box.localToGlobal(box.size.center(Offset.zero));
        return;
      }
      e.visitChildElements(visit);
    }

    (_surface.currentContext! as Element).visitChildElements(visit);
    return found ?? (throw StateError('Canvas surface did not mount'));
  }

  CanvasInkCache? _canvasCache() {
    CanvasInkCache? found;
    void visit(Element e) {
      final w = e.widget;
      if (w is CustomPaint && w.painter is OrbitCanvasPainter) {
        found = (w.painter as OrbitCanvasPainter).inkCache;
        return;
      }
      e.visitChildElements(visit);
    }

    (_surface.currentContext! as Element).visitChildElements(visit);
    return found;
  }

  PdfViewerController? _pdfController() {
    PdfViewerController? found;
    void visit(Element e) {
      if (e.widget is PdfViewer) {
        found = (e.widget as PdfViewer).controller;
        return;
      }
      e.visitChildElements(visit);
    }

    (_surface.currentContext! as Element).visitChildElements(visit);
    return found;
  }

  void _dispatch(PointerEvent event) {
    final start = _clock.elapsedMicroseconds;
    _inputEvents++;
    GestureBinding.instance.handlePointerEvent(event);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _latency.add(_clock.elapsedMicroseconds - start);
    });
  }

  Future<void> _run() async {
    final view = View.of(context);
    _refreshRate = view.display.refreshRate;
    if (!_refreshRate.isFinite || _refreshRate <= 0) {
      _refreshRate = 60;
    }
    try {
      if (!kProfileMode) {
        throw StateError('Run this harness in profile mode');
      }
      await _frames(30);
      await _stage('Canvas derived-preview warmup', () async {
        await _canvasCache()?.rasterizationIdle.timeout(
          const Duration(seconds: 60),
        );
        await _frames(5);
      });
      final center = _canvasCenter();
      // Inject only into this isolated Flutter binding, never the OS cursor.
      await _stage('Canvas warm pan — 100000 pressure samples', () async {
        for (var i = 0; i < 180; i++) {
          _dispatch(
            PointerScrollEvent(
              position: center,
              scrollDelta: Offset(i < 90 ? 1 : -1, 0),
            ),
          );
          await _frames(1);
        }
      });
      await _stage('Active synthetic stylus — 100000 saved samples', () async {
        const pointer = 7001;
        final start = center - const Offset(220, 80);
        _dispatch(
          PointerDownEvent(
            pointer: pointer,
            kind: PointerDeviceKind.stylus,
            position: start,
            pressure: .6,
            timeStamp: _clock.elapsed,
          ),
        );
        for (var frame = 0; frame < 180; frame++) {
          for (var sample = 0; sample < 4; sample++) {
            final p = frame * 4 + sample;
            _dispatch(
              PointerMoveEvent(
                pointer: pointer,
                kind: PointerDeviceKind.stylus,
                position: start + Offset(p * .5, math.sin(p * .1) * 30),
                pressure: .3 + (p % 50) / 100,
                timeStamp: _clock.elapsed,
              ),
            );
          }
          await _frames(1);
        }
        _dispatch(
          PointerUpEvent(
            pointer: pointer,
            kind: PointerDeviceKind.stylus,
            position: start + const Offset(360, 0),
            timeStamp: _clock.elapsed,
          ),
        );
        await _frames(3);
        if (_saves != 1 || (_data['elements'] as List).length != 101) {
          throw StateError('Expected exactly one committed synthetic stroke');
        }
      });
      await _stage('PDF cold open — 300 pages and 24000 regions', () async {
        setState(() => _pdfMode = true);
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (_pdfController()?.isReady != true) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('Native PDF load timed out');
          }
          await Future<void>.delayed(const Duration(milliseconds: 25));
          await _frames(1);
        }
        await _frames(30);
      });
      final pdf = _pdfController()!;
      await _stage('PDF warm navigation — 300-page document', () async {
        final origin = pdf.centerPosition;
        for (var i = 0; i < 180; i++) {
          await pdf.goTo(
            pdf.calcMatrixFor(
              origin + Offset(0, math.sin(i * .04) * 120),
              zoom: pdf.currentZoom,
            ),
            duration: Duration.zero,
          );
          await _frames(1);
        }
      });
      await _stage('PDF distant page jumps — 24 destinations', () async {
        for (var i = 0; i < 24; i++) {
          final page = i == 23 ? 300 : (i * 47) % 300 + 1;
          await pdf.goToPage(pageNumber: page, duration: Duration.zero);
          await _frames(6);
        }
        await _frames(10);
      });
      if (pdf.pageNumber != 300) {
        throw StateError('Final PDF destination was lost');
      }
      setState(() => _status = 'Flushing native frame measurements');
      await _frames(2);
      await Future<void>.delayed(const Duration(seconds: 2));
    } catch (error, stack) {
      _errors.add('$error\n$stack');
    }
    final unique = <int, ui.FrameTiming>{
      for (final f in _timings) f.frameNumber: f,
    };
    for (final stage in _stages) {
      final frames = unique.values
          .where(
            (f) =>
                f.frameNumber > (stage['startExclusive'] as int) &&
                f.frameNumber <= (stage['endInclusive'] as int),
          )
          .map(
            (f) => {
              'number': f.frameNumber,
              'buildUs': f.buildDuration.inMicroseconds,
              'rasterUs': f.rasterDuration.inMicroseconds,
              'totalUs': f.totalSpan.inMicroseconds,
            },
          )
          .toList();
      stage['metrics'] = summarizeFrames(
        frames,
        budgetUs: 1000000 / _refreshRate,
      );
      stage['frames'] = frames;
      if (frames.isEmpty) {
        _errors.add('No native frame timings for ${stage['name']}');
      }
    }
    final output = const String.fromEnvironment('ORBIT_BENCH_REPORT');
    final report = {
      'version': 1,
      'buildMode': kProfileMode ? 'profile' : 'unsupported',
      'syntheticInput': true,
      'physicalPenTested': false,
      'refreshRateHz': _refreshRate,
      'physicalSize': {
        'width': view.physicalSize.width,
        'height': view.physicalSize.height,
      },
      'devicePixelRatio': view.devicePixelRatio,
      'os': Platform.operatingSystemVersion,
      'logicalProcessors': Platform.numberOfProcessors,
      'processPeakRssBytes': ProcessInfo.maxRss,
      'stages': _stages,
      'syntheticInputEvents': _inputEvents,
      'dispatchToFrameworkPostFrame': durationStatistics(_latency),
      'inputMeasurementLimit':
          'Application dispatch to framework post-frame only; excludes hardware delivery, GPU completion and display scanout.',
      'committedCanvasStrokes': _saves,
      'lastSavedPdfPage': _pdfPage,
      'errors': _errors,
    };
    if (output.isEmpty) {
      stderr.writeln('Supply ORBIT_BENCH_REPORT as an absolute output path');
      exit(2);
    }
    final target = File(output);
    await target.parent.create(recursive: true);
    await target.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
      flush: true,
    );
    stdout.writeln(
      'ORBIT_DEVICE_BENCHMARK: ${_errors.isEmpty ? 'completed' : 'failed'}; report=$output',
    );
    runApp(const SizedBox());
    await _frames(2);
    exit(_errors.isEmpty ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: orbitDarkTheme(),
    child: Scaffold(
      appBar: AppBar(
        title: Text(_status),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: Text(
            'Isolated synthetic documents · no Vault or account · automatic profile run',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ),
      body: SizedBox.expand(
        key: _surface,
        child: _pdfMode
            ? OrbitPdfReader(
                objectId: 'benchmark-pdf',
                title: 'Synthetic 300-page research',
                checksum: 'synthetic-v1',
                annotations: _annotations,
                loadBytes: () async => _pdf,
                onOpenOriginal: () {},
                onOpenExternal: (_) {},
                onReadingState: (page, _) => _pdfPage = page,
                onQuote: (_, _) async {},
                onBookmarks: (_) {},
              )
            : CanvasEditor(
                canvasId: 'benchmark-canvas',
                data: _data,
                objects: const [],
                onOpenObject: (_) {},
                onChanged: (data) {
                  _data.addAll(data);
                  _saves++;
                },
              ),
      ),
    ),
  );
}
