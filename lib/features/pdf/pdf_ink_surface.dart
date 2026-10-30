import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';
import '../../canvas/geometry.dart';
import '../../canvas/scene.dart';
import '../../domain/pdf_ink.dart';
import '../../domain/universal_object.dart';
import '../canvas/canvas_live_ink.dart';
import '../canvas/canvas_painter.dart';
import 'pdf_ink_session.dart';
import '../../app/canvas_performance.dart';

/// A gesture adapter and two independent ink layers around one PDF renderer.
/// Pen samples never setState the reader or invalidate PDFium's raster tiles.
class PdfInkSurface extends StatefulWidget {
  const PdfInkSurface({
    super.key,
    required this.viewer,
    required this.session,
    required this.child,
  });
  final PdfViewerController viewer;
  final PdfInkSession session;
  final Widget child;
  @override
  State<PdfInkSurface> createState() => _PdfInkSurfaceState();
}

class _PdfInkSurfaceState extends State<PdfInkSurface> {
  final _performanceSurface = CanvasPerformance.instance.attach();
  final _live = ValueNotifier(0);
  final _eraseChanges = ValueNotifier(0);
  final _cache = CanvasLiveInkCache();
  final _saved = CanvasInkCache();
  final _layout = PdfInkPageIndex();
  final _surface = GlobalKey();
  final _samples = <Map<String, dynamic>>[];
  final _erased = <String, CanvasElement>{};
  final _pending = <CanvasElement>[];
  CanvasElement? _stroke;
  int? _pointer;
  int _generation = 0, _page = 0;
  Size _pageSize = Size.zero;
  Rect _pageRect = Rect.zero;
  Duration _started = Duration.zero;
  double _pressure = 1;
  Offset? _erasePrevious;
  late Listenable _changes;
  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _changes = Listenable.merge([widget.viewer, widget.session, _saved]);
    widget.session.addListener(_sessionChanged);
    widget.viewer.addListener(_cameraChanged);
    CanvasPerformance.instance.context(_performanceSurface, {
      'pdfInk': 1,
      'strokes': widget.session.document.elements.length,
      'samples': widget.session.document.sampleCount,
    });
  }

  @override
  void didUpdateWidget(PdfInkSurface old) {
    super.didUpdateWidget(old);
    if (old.viewer != widget.viewer || old.session != widget.session) {
      old.session.removeListener(_sessionChanged);
      old.viewer.removeListener(_cameraChanged);
      _cancel();
      _listen();
    }
  }

  void _sessionChanged() {
    if (_pointer != null &&
        (_generation != widget.session.generation ||
            !widget.session.canEdit ||
            !widget.session.drawing)) {
      _cancel();
    }
  }

  void _cameraChanged() {
    if (_pointer != null && widget.viewer.isReady) {
      // Freeze the coordinate system of a captured pen gesture. Palm events
      // cannot stretch a stroke between pages while the viewport moves.
      final rect = widget.viewer.layout.pageLayouts[_page - 1];
      if (rect != _pageRect) _cancel();
      _live.value++;
    }
  }

  RenderBox? get _box =>
      _surface.currentContext?.findRenderObject() as RenderBox?;
  Offset? _documentPoint(Offset global) {
    final box = _box;
    if (!widget.viewer.isReady ||
        box == null ||
        !box.hasSize ||
        !(Offset.zero & box.size).contains(box.globalToLocal(global))) {
      return null;
    }
    return widget.viewer.globalToDocument(global);
  }

  bool _allow(PointerDownEvent e) {
    if (_pointer != null) return true; // Reject palms in the same arena.
    final session = widget.session;
    if (!session.canEdit ||
        !session.drawing ||
        session.rejected != null ||
        e.kind == PointerDeviceKind.touch && !session.fingerDrawing ||
        e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton) {
      return false;
    }
    final point = _documentPoint(e.position);
    return point != null && _layout.pageAt(widget.viewer.layout, point) != null;
  }

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    final point = _documentPoint(e.position);
    if (point == null) return;
    final page = _layout.pageAt(widget.viewer.layout, point);
    if (page == null) return;
    _page = page + 1;
    final native = widget.viewer.document.pages[page];
    _pageSize = Size(native.width, native.height);
    _pageRect = widget.viewer.layout.pageLayouts[page];
    _pointer = e.pointer;
    _pressure = 1;
    _erasePrevious = null;
    _generation = widget.session.generation;
    _started = e.timeStamp;
    _samples.clear();
    _erased.clear();
    _pending.clear();
    _cache.clear();
    _move(e, force: true);
  }

  Offset _point(Offset global) {
    final p = widget.viewer.globalToDocument(global)!;
    return Offset(
      ((p.dx - _pageRect.left) * _pageSize.width / _pageRect.width).clamp(
        0,
        _pageSize.width,
      ),
      ((p.dy - _pageRect.top) * _pageSize.height / _pageRect.height).clamp(
        0,
        _pageSize.height,
      ),
    );
  }

  void _move(PointerEvent e, {bool force = false}) {
    final started = CanvasPerformance.instance.begin();
    try {
      _sample(e, force: force);
    } finally {
      CanvasPerformance.instance.duration(
        CanvasPerfEvent.input,
        _performanceSurface,
        started,
      );
    }
  }

  void _sample(PointerEvent e, {bool force = false}) {
    if (_pointer != e.pointer ||
        !widget.viewer.isReady ||
        !e.position.dx.isFinite ||
        !e.position.dy.isFinite) {
      return;
    }
    final p = _point(e.position);
    final s = widget.session;
    final erasing =
        s.tool == PdfInkTool.eraser ||
        e.kind == PointerDeviceKind.invertedStylus;
    if (erasing) {
      final radius =
          8 / (widget.viewer.currentZoom * _pageRect.width / _pageSize.width);
      final from = _erasePrevious ?? p;
      final sweep = Rect.fromPoints(from, p).inflate(radius);
      for (final stroke in s.query(
        _page,
        CanvasBounds(sweep.left, sweep.top, sweep.width, sweep.height),
      )) {
        if (_erased.containsKey(stroke.id) ||
            !pdfInkSweepHit(stroke, from, p, radius)) {
          continue;
        }
        _erased[stroke.id] = stroke;
      }
      _erasePrevious = p;
      _eraseChanges.value++;
      return;
    }
    if (e is! PointerUpEvent && e.pressure.isFinite && e.pressure > 0) {
      final range = e.pressureMax - e.pressureMin;
      _pressure =
          (range > .001 ? (e.pressure - e.pressureMin) / range : e.pressure)
              .clamp(0, 1);
    }
    if (_samples.isNotEmpty && !force) {
      final last = _samples.last;
      final distance =
          (p - Offset(last['x'] as double, last['y'] as double)).distance;
      final zoom =
          widget.viewer.currentZoom * _pageRect.width / _pageSize.width;
      if (distance < .7 / zoom &&
          (_pressure - (last['pressure'] as double)).abs() < .01) {
        return;
      }
    }
    if (_samples.length >= PdfInkDocument.maxSamples) {
      // Split without dropping source points; one release remains one command.
      _pending.add(_freezeStroke());
      _eraseChanges.value++;
      final last = _samples.last;
      _samples.clear();
      _samples.add(last);
      _cache.clear();
    }
    _samples.add({
      'x': p.dx,
      'y': p.dy,
      'pressure': _pressure,
      'timeMs': (e.timeStamp - _started).inMilliseconds.clamp(0, 1000000000000),
    });
    _stroke = CanvasElement({
      'id': 'live-pdf-ink',
      'type': 'ink',
      'x': 0.0,
      'y': 0.0,
      'width': _pageSize.width,
      'height': _pageSize.height,
      'points': UnmodifiableListView(_samples),
      'color': s.color,
      'strokeWidth': s.width,
      'penStyle': s.tool == PdfInkTool.highlighter
          ? 'highlighter'
          : 'ballpoint',
      'isHighlighter': s.tool == PdfInkTool.highlighter,
    });
    _live.value++;
  }

  CanvasElement _freezeStroke() {
    final left = _samples.map((p) => p['x'] as double).reduce(math.min);
    final top = _samples.map((p) => p['y'] as double).reduce(math.min);
    final right = _samples.map((p) => p['x'] as double).reduce(math.max);
    final bottom = _samples.map((p) => p['y'] as double).reduce(math.max);
    return CanvasElement(
      immutableObjectData({
        ..._stroke!.data,
        'id': const Uuid().v4(),
        'page': _page,
        'pageWidth': _pageSize.width,
        'pageHeight': _pageSize.height,
        'x': left,
        'y': top,
        'width': right - left,
        'height': bottom - top,
        'points': [
          for (final p in _samples)
            {
              ...p,
              'x': (p['x'] as double) - left,
              'y': (p['y'] as double) - top,
            },
        ],
      }),
    );
  }

  void _up(PointerUpEvent e) {
    if (_pointer != e.pointer) return;
    final started = CanvasPerformance.instance.begin();
    _move(e, force: true);
    final strokes = [..._pending, if (_samples.isNotEmpty) _freezeStroke()];
    final delta = PdfInkDelta(add: strokes, remove: _erased.values.toList());
    _pointer = null;
    if (!delta.isEmpty) widget.session.commit(delta);
    CanvasPerformance.instance.duration(
      CanvasPerfEvent.inputEnd,
      _performanceSurface,
      started,
      {'samples': _samples.length},
    );
    _cancel();
  }

  void _cancel() {
    _pointer = null;
    _stroke = null;
    _samples.clear();
    _erased.clear();
    _pending.clear();
    _cache.clear();
    _live.value++;
    _eraseChanges.value++;
  }

  CanvasCamera _camera() {
    if (!widget.viewer.isReady || _box == null || _stroke == null) {
      return const CanvasCamera();
    }
    final origin = _box!.globalToLocal(
      widget.viewer.documentToGlobal(_pageRect.topLeft)!,
    );
    final scale = widget.viewer.currentZoom * _pageRect.width / _pageSize.width;
    return CanvasCamera(
      x: -origin.dx / scale,
      y: -origin.dy / scale,
      zoom: scale,
    );
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    key: _surface,
    behavior: HitTestBehavior.translucent,
    gestures: {
      _PdfPenGesture: GestureRecognizerFactoryWithHandlers<_PdfPenGesture>(
        () => _PdfPenGesture(),
        (r) {
          r.allow = _allow;
          r.down = _down;
          r.move = _move;
          r.up = _up;
          r.cancel = (e) {
            if (e.pointer == _pointer) _cancel();
          };
        },
      ),
    },
    child: Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: widget.child),
        IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _PdfSavedInkPainter(
                widget.viewer,
                widget.session,
                _layout,
                _saved,
                Listenable.merge([_changes, _eraseChanges]),
                _erased,
                _pending,
                _performanceSurface,
              ),
              isComplex: true,
            ),
          ),
        ),
        IgnorePointer(
          child: CanvasLiveInkLayer(
            changes: _live,
            stroke: () => _stroke,
            camera: _camera,
            cache: _cache,
            performanceSurface: _performanceSurface,
          ),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    CanvasPerformance.instance.detach(_performanceSurface);
    widget.session.removeListener(_sessionChanged);
    widget.viewer.removeListener(_cameraChanged);
    _cache.clear();
    _saved.dispose();
    _live.dispose();
    _eraseChanges.dispose();
    super.dispose();
  }
}

class _PdfPenGesture extends OneSequenceGestureRecognizer {
  late bool Function(PointerDownEvent) allow;
  late void Function(PointerDownEvent) down;
  late void Function(PointerEvent) move;
  late void Function(PointerUpEvent) up;
  late void Function(PointerCancelEvent) cancel;
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      allow(event) && super.isPointerAllowed(event);
  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
    down(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) move(event);
    if (event is PointerUpEvent) {
      up(event);
      stopTrackingPointer(event.pointer);
    }
    if (event is PointerCancelEvent) {
      cancel(event);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}
  @override
  String get debugDescription => 'PDF pen';
}

/// Page rows may contain two pages. Queries cost log(pages) + visible pages,
/// independent of the length of the PDF, and retain mixed page dimensions.
class PdfInkPageIndex {
  PdfPageLayout? _layout;
  final _order = <int>[];
  final _prefixBottom = <double>[];
  void _ensure(PdfPageLayout layout) {
    if (identical(layout, _layout)) return;
    _layout = layout;
    _order.clear();
    _prefixBottom.clear();
    _order.addAll(
      List.generate(layout.pageLayouts.length, (i) => i)..sort(
        (a, b) =>
            layout.pageLayouts[a].top.compareTo(layout.pageLayouts[b].top),
      ),
    );
    var bottom = double.negativeInfinity;
    for (final i in _order) {
      bottom = math.max(bottom, layout.pageLayouts[i].bottom);
      _prefixBottom.add(bottom);
    }
  }

  Iterable<int> visible(PdfPageLayout layout, Rect rect) sync* {
    _ensure(layout);
    var lo = 0, hi = _order.length;
    while (lo < hi) {
      final m = (lo + hi) ~/ 2;
      if (_prefixBottom[m] < rect.top) {
        lo = m + 1;
      } else {
        hi = m;
      }
    }
    for (var n = lo; n < _order.length; n++) {
      final i = _order[n], page = layout.pageLayouts[i];
      if (page.top > rect.bottom) break;
      if (page.overlaps(rect)) yield i;
    }
  }

  int? pageAt(PdfPageLayout layout, Offset point) => visible(
    layout,
    Rect.fromCircle(center: point, radius: .001),
  ).where((i) => layout.pageLayouts[i].contains(point)).firstOrNull;
}

bool pdfInkHit(CanvasElement e, Offset p, double radius) =>
    pdfInkSweepHit(e, p, p, radius);

bool pdfInkSweepHit(CanvasElement e, Offset from, Offset p, double radius) {
  final nib = e.data['isHighlighter'] == true
      ? math.max(16.0, e.strokeWidth)
      : e.strokeWidth;
  final bounds = Rect.fromLTWH(
    e.x,
    e.y,
    e.width,
    e.height,
  ).inflate(radius + nib);
  if (!bounds.overlaps(Rect.fromPoints(from, p).inflate(.001))) return false;
  final points = e.points;
  final local = p - Offset(e.x, e.y),
      start = from - Offset(e.x, e.y),
      r = radius + nib / 2;
  double distance(Offset p, Offset a, Offset b) => distanceToSegment(
    CanvasPoint(p.dx, p.dy),
    CanvasPoint(a.dx, a.dy),
    CanvasPoint(b.dx, b.dy),
  );
  if (points.length == 1) {
    return distance(Offset(points[0].x, points[0].y), start, local) <= r;
  }
  for (var i = 1; i < points.length; i++) {
    final a = Offset(points[i - 1].x, points[i - 1].y),
        b = Offset(points[i].x, points[i].y);
    final d = b - a, s = local - start, denominator = d.dx * s.dy - d.dy * s.dx;
    if (denominator.abs() > 1e-9) {
      final v = start - a,
          t = (v.dx * s.dy - v.dy * s.dx) / denominator,
          u = (v.dx * d.dy - v.dy * d.dx) / denominator;
      if (t >= 0 && t <= 1 && u >= 0 && u <= 1) return true;
    }
    if (distance(local, a, b) <= r ||
        distance(start, a, b) <= r ||
        distance(a, start, local) <= r ||
        distance(b, start, local) <= r) {
      return true;
    }
  }
  return false;
}

class _PdfSavedInkPainter extends CustomPainter {
  _PdfSavedInkPainter(
    this.viewer,
    this.session,
    this.index,
    this.cache,
    Listenable changes,
    this.erased,
    this.pending,
    this.performanceSurface,
  ) : super(repaint: changes);
  final PdfViewerController viewer;
  final PdfInkSession session;
  final PdfInkPageIndex index;
  final CanvasInkCache cache;
  final Map<String, CanvasElement> erased;
  final List<CanvasElement> pending;
  final int performanceSurface;
  @override
  void paint(Canvas canvas, Size size) {
    final started = CanvasPerformance.instance.begin();
    try {
      _paint(canvas, size);
    } finally {
      CanvasPerformance.instance.duration(
        CanvasPerfEvent.scenePaint,
        performanceSurface,
        started,
        {'pdfInk': 1},
      );
    }
  }

  void _paint(Canvas canvas, Size size) {
    if (!viewer.isReady) return;
    final viewport = viewer.visibleRect;
    final visible = <CanvasElement>[];
    for (final i in index.visible(viewer.layout, viewport)) {
      final page = viewer.document.pages[i],
          rect = viewer.layout.pageLayouts[i];
      final scale = rect.width / page.width;
      final origin = viewer.documentToLocal(rect.topLeft);
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.translate(origin.dx, origin.dy);
      canvas.scale(viewer.currentZoom * scale);
      canvas.clipRect(Rect.fromLTWH(0, 0, page.width, page.height));
      final pageViewport = Rect.fromLTRB(
        (viewport.left - rect.left) / scale,
        (viewport.top - rect.top) / scale,
        (viewport.right - rect.left) / scale,
        (viewport.bottom - rect.top) / scale,
      );
      for (final e in [
        ...session.query(
          i + 1,
          CanvasBounds(
            pageViewport.left,
            pageViewport.top,
            pageViewport.width,
            pageViewport.height,
          ),
        ),
        ...pending.where((e) => e.data['page'] == i + 1),
        ...session.recoveryStrokes.where((e) => e.data['page'] == i + 1),
      ]) {
        if (erased.containsKey(e.id)) continue;
        if (((e.data['pageWidth'] as num) - page.width).abs() > .01 ||
            ((e.data['pageHeight'] as num) - page.height).abs() > .01) {
          continue;
        }
        final b = Rect.fromLTWH(
          e.x,
          e.y,
          e.width,
          e.height,
        ).inflate(e.strokeWidth * 2 + 32);
        final docBounds = Rect.fromLTWH(
          rect.left + b.left * scale,
          rect.top + b.top * scale,
          b.width * scale,
          b.height * scale,
        );
        if (!docBounds.overlaps(viewport)) continue;
        visible.add(e);
        cache.draw(
          canvas,
          e,
          Color(e.color),
          (c) => OrbitCanvasPainter.paintInk(c, e, Color(e.color)),
          pixelScale: viewer.currentZoom * scale,
        );
      }
      canvas.restore();
    }
    cache.retainVisible(visible);
  }

  @override
  bool shouldRepaint(_PdfSavedInkPainter old) => true;
}
