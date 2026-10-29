import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../platform/performance_log.dart';

enum CanvasPerfEvent {
  session,
  context,
  editorUpdate,
  editorBuild,
  viewportBuild,
  scenePaint,
  liveInkPaint,
  liveInkPrepare,
  input,
  inputStart,
  inputEnd,
  hover,
  previewBuild,
  sceneSnapshot,
  draftCompare,
  draftSnapshot,
  draftNotify,
  driveSync,
  driveState,
  save,
  frameStall,
  mainThreadStall,
  imageChange,
  paintInvalidation,
  summary,
}

/// Counts/timings only. No titles, paths, text, point coordinates, attachment
/// references, invitation tokens or credentials enter this recorder.
class CanvasPerformance extends ChangeNotifier {
  CanvasPerformance({this.bindScheduler = true});
  static final instance = CanvasPerformance();
  final bool bindScheduler;
  final _clock = Stopwatch()..start();
  final _surfaces = <int, Map<String, num>>{};
  final _pending = <Map<String, Object>>[];
  final _totals = <CanvasPerfEvent, (int count, int maxUs, int sumUs)>{};
  final _invalidations = <int, int>{};
  PerformanceLogStore? _store;
  Future<void>? _starting, _flushing;
  Timer? _timer;
  Timer? _heartbeat;
  int _nextSurface = 0,
      _lastTick = 0,
      _dropped = 0,
      _frames = 0,
      _slowFrames = 0;
  int _maxUi = 0, _maxRaster = 0;
  int _maxVsync = 0, _lastBeat = 0;
  double _budgetUs = 1000000 / 60;
  bool _closed = false;
  String? error;
  bool get enabled => _store?.enabled == true && !_closed;
  String? get path => _store?.path;
  int get retainedEvents => _pending.length;
  int? begin() => enabled ? _clock.elapsedMicroseconds : null;
  Future<void> start({PerformanceLogStore? store}) =>
      _starting ??= _start(store);
  Future<void> _start(PerformanceLogStore? store) async {
    try {
      _store = store ?? await createPerformanceLogStore();
      if (_closed) return;
      if (_store == null) {
        notifyListeners();
        return;
      }
      if (bindScheduler) {
        SchedulerBinding.instance.addTimingsCallback(_onFrames);
      }
      _lastTick = _clock.elapsedMicroseconds;
      _lastBeat = _lastTick;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
      _heartbeat = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final now = _clock.elapsedMicroseconds;
        final delay = now - _lastBeat - 250000;
        _lastBeat = now;
        if (enabled && _surfaces.isNotEmpty && delay > 50000) {
          event(CanvasPerfEvent.mainThreadStall, 0, {'delayUs': delay});
        }
      });
      event(CanvasPerfEvent.session, 0, {'schemaVersion': 1, 'renderer': 12});
      _recordContexts();
      notifyListeners();
    } on Object {
      error = 'Local performance logging is unavailable.';
      if (!_closed) notifyListeners();
    }
  }

  int attach() {
    final id = ++_nextSurface;
    _surfaces[id] = {};
    return id;
  }

  void detach(int surface) {
    _surfaces.remove(surface);
    unawaited(flush());
  }

  void context(int surface, Map<String, num> counts) {
    _surfaces[surface] = Map.of(counts);
    event(CanvasPerfEvent.context, surface, counts);
  }

  void _recordContexts() {
    for (final item in _surfaces.entries) {
      event(CanvasPerfEvent.context, item.key, item.value);
    }
  }

  void gauge(int surface, Map<String, num> counts) {
    if (!enabled || !_surfaces.containsKey(surface)) return;
    _surfaces[surface]!.addAll(counts);
    final hz = counts['hz'];
    if (hz != null && hz.isFinite && hz > 0) {
      _budgetUs = (1000000 / hz).clamp(4000, 33334);
    }
  }

  void invalidation(int surface, int flags) {
    if (!enabled) return;
    if (!_invalidations.containsKey(flags)) {
      event(CanvasPerfEvent.paintInvalidation, surface, {'flags': flags});
    }
    _invalidations[flags] = (_invalidations[flags] ?? 0) + 1;
  }

  void duration(
    CanvasPerfEvent kind,
    int surface,
    int? start, [
    Map<String, num> counts = const {},
  ]) {
    if (start == null || !enabled) return;
    final elapsed = _clock.elapsedMicroseconds - start;
    final old = _totals[kind] ?? (0, 0, 0);
    _totals[kind] = (
      old.$1 + 1,
      elapsed > old.$2 ? elapsed : old.$2,
      old.$3 + elapsed,
    );
    if (elapsed >= 8000) event(kind, surface, {...counts, 'us': elapsed});
  }

  void event(CanvasPerfEvent kind, int surface, Map<String, num> values) {
    if (!enabled) return;
    if (_pending.length >= 128) {
      if (kind == CanvasPerfEvent.summary) {
        _pending.removeLast();
      } else {
        _dropped++;
        return;
      }
    }
    _pending.add({
      'event': kind.name,
      'surface': surface,
      'tUs': _clock.elapsedMicroseconds,
      'frame': ui.PlatformDispatcher.instance.frameData.frameNumber,
      'utc': DateTime.now().toUtc().toIso8601String(),
      for (final entry in values.entries)
        if (entry.value.isFinite &&
            RegExp(r'^[a-zA-Z][a-zA-Z0-9]{0,31}$').hasMatch(entry.key))
          entry.key: entry.value,
    });
  }

  void _onFrames(List<ui.FrameTiming> timings) {
    if (!enabled || _surfaces.isEmpty) return;
    for (final frame in timings) {
      final build = frame.buildDuration.inMicroseconds,
          raster = frame.rasterDuration.inMicroseconds;
      final vsync = frame.vsyncOverhead.inMicroseconds;
      _frames++;
      if (build > _maxUi) _maxUi = build;
      if (raster > _maxRaster) _maxRaster = raster;
      if (vsync > _maxVsync) _maxVsync = vsync;
      if (build > _budgetUs || raster > _budgetUs || vsync > _budgetUs) {
        _slowFrames++;
        event(CanvasPerfEvent.frameStall, 0, {
          'frame': frame.frameNumber,
          'uiUs': build,
          'gpuUs': raster,
          'vsyncUs': vsync,
          'totalUs': frame.totalSpan.inMicroseconds,
          'surfaces': _surfaces.length,
        });
      }
    }
  }

  void tick() {
    if (_closed || !enabled) return;
    final now = _clock.elapsedMicroseconds;
    final delay = now - _lastTick - 1000000;
    _lastTick = now;
    if (_surfaces.isNotEmpty) {
      if (delay > 50000) {
        event(CanvasPerfEvent.mainThreadStall, 0, {'delayUs': delay});
      }
      event(CanvasPerfEvent.summary, 0, {
        'frames': _frames,
        'slowFrames': _slowFrames,
        'maxUiUs': _maxUi,
        'maxGpuUs': _maxRaster,
        'maxVsyncUs': _maxVsync,
        'budgetUs': _budgetUs,
        'dropped': _dropped,
        'invalidations': _invalidations.values.fold<int>(0, (a, b) => a + b),
        for (final bit in [1, 2, 4, 8, 16, 32, 64, 128])
          'change$bit': _invalidations.entries
              .where((e) => (e.key & bit) != 0)
              .fold<int>(0, (a, e) => a + e.value),
        for (final entry in _totals.entries)
          '${entry.key.name}Count': entry.value.$1,
        for (final entry in _totals.entries)
          '${entry.key.name}MaxUs': entry.value.$2,
      });
      _recordContexts();
    }
    _frames = 0;
    _slowFrames = 0;
    _maxUi = 0;
    _maxRaster = 0;
    _maxVsync = 0;
    _dropped = 0;
    _totals.clear();
    _invalidations.clear();
    unawaited(flush());
  }

  Future<void> flush() =>
      _flushing ??= _flush().whenComplete(() => _flushing = null);
  Future<void> _flush() async {
    if (!enabled || _pending.isEmpty) return;
    final batch = List.of(_pending);
    _pending.clear();
    try {
      await _store!.append('${batch.map(jsonEncode).join('\n')}\n');
    } on Object {
      error = 'Could not write local performance log.';
      if (!_closed) notifyListeners();
    }
  }

  Future<void> setEnabled(bool value) async {
    await start();
    await flush();
    await _store?.setEnabled(value);
    _pending.clear();
    _totals.clear();
    _lastTick = _clock.elapsedMicroseconds;
    _lastBeat = _lastTick;
    if (value) _recordContexts();
    notifyListeners();
  }

  Future<String> read() async {
    await flush();
    await flush();
    return await _store?.read() ?? '';
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    _heartbeat?.cancel();
    if (bindScheduler && _store != null) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrames);
    }
    super.dispose();
  }
}
