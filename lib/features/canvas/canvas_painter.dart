import '../../canvas/presentation.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../canvas/geometry.dart';
import '../../canvas/scene.dart';
import '../../canvas/connectors.dart';
import '../../canvas/uml.dart';
import '../../canvas/uml_interaction.dart';
import '../../app/orbit_theme.dart';
import '../../canvas/groups.dart';
import '../../domain/object_reference.dart';
import '../../domain/document_anchors.dart';
import '../../domain/model_asset.dart';
import 'canvas_rich_text.dart';

class CanvasObjectReference {
  const CanvasObjectReference({
    required this.id,
    required this.title,
    required this.typeId,
    this.body = '',
    this.properties = const {},
    this.viewMemberIds,
    this.viewQueryIssue,
    this.lifeSummary,
  });
  final String id;
  final String title;
  final String typeId;
  final String body;
  final Map<String, dynamic> properties;
  final List<String>? viewMemberIds;
  final String? viewQueryIssue;
  final String? lifeSummary;

  bool get isCompleted =>
      properties['completed'] == true || properties['status'] == 'done';
  String? get project => properties['project'] as String?;
  String? get folder => properties['folder'] as String?;
  String? get contentRef =>
      (properties['contentRef'] ??
              properties['attachmentRef'] ??
              properties['fileRef'] ??
              properties['filePath'])
          as String?;
  String? get mimeType => properties['mimeType'] as String?;
  bool get isPdf =>
      typeId == 'orbit.file' &&
      ((mimeType == 'application/pdf') || title.toLowerCase().endsWith('.pdf'));
  bool get isImage =>
      typeId == 'orbit.file' &&
      ((mimeType?.startsWith('image/') ?? false) ||
          const [
            'png',
            'jpg',
            'jpeg',
            'webp',
            'gif',
            'svg',
          ].any(title.toLowerCase().endsWith));
  Map<String, dynamic>? get pdfSource => properties['pdfSource'] is Map
      ? Map<String, dynamic>.from(properties['pdfSource'] as Map)
      : null;
  List<String> get tags => properties['tags'] is List
      ? (properties['tags'] as List).whereType<String>().toList()
      : const [];
  String? get priority => properties['priority'] as String?;
  String? get dueDate => properties['dueDate'] as String?;

  @override
  bool operator ==(Object other) =>
      other is CanvasObjectReference &&
      other.id == id &&
      other.title == title &&
      other.typeId == typeId &&
      other.body == body &&
      other.lifeSummary == lifeSummary &&
      mapEquals(other.properties, properties) &&
      listEquals(other.viewMemberIds, viewMemberIds) &&
      other.viewQueryIssue == viewQueryIssue;
  @override
  int get hashCode => Object.hash(
    id,
    title,
    typeId,
    body,
    properties.length,
    lifeSummary,
    Object.hashAll(viewMemberIds ?? const <String>[]),
    viewQueryIssue,
  );
}

/// One retained vector display list; replacement/disposal releases its native
/// resources. Replaying keeps the original geometry, antialiasing and detail.
class CanvasPictureCache {
  Object? _key;
  ui.Picture? _picture;

  void draw(Canvas canvas, Object key, void Function(Canvas) paint) {
    if (_picture == null || _key != key) {
      final recorder = ui.PictureRecorder();
      paint(Canvas(recorder));
      final next = recorder.endRecording();
      _picture?.dispose();
      _picture = next;
      _key = key;
    }
    canvas.drawPicture(_picture!);
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
    _key = null;
  }
}

class _InkDisplayEntry {
  _InkDisplayEntry(this.picture, this.samples, this.bounds, this.element);
  final ui.Picture picture;
  final int samples;
  final Rect? bounds;
  final CanvasElement element;
  ui.Image? image;
  double imageScale = 0;
  double? failedScale;
  int serial = 0;
  bool alive = true;
}

class _InkRasterRequest {
  _InkRasterRequest(
    this.entry,
    this.scale,
    this.width,
    this.height,
    this.serial,
  );
  final _InkDisplayEntry entry;
  final double scale;
  final int width, height, serial;
  int get pixels => width * height;
}

/// Bounded vector originals plus optional disposable previews at native pixel
/// density. Zooming past a preview's resolution uses vectors until a sharper
/// preview is ready. Exports and source samples never depend on these images.
class CanvasInkCache extends ChangeNotifier {
  CanvasInkCache({
    this.maxEntries = 256,
    this.maxSamples = 200000,
    this.rasterizeSavedInk = false,
    this.maxRasterPixels = 16 * 1024 * 1024,
    Future<ui.Image> Function(ui.Picture, int, int)? rasterize,
  }) : assert(maxEntries > 0),
       assert(maxSamples > 0),
       assert(maxRasterPixels > 0),
       _rasterize =
           rasterize ??
           ((picture, width, height) => picture.toImage(width, height));
  final int maxEntries, maxSamples, maxRasterPixels;
  final bool rasterizeSavedInk;
  final Future<ui.Image> Function(ui.Picture, int, int) _rasterize;
  final _entries = <(CanvasElement, Color), _InkDisplayEntry>{};
  final _rasters = <_InkDisplayEntry>{};
  final _pending = <_InkDisplayEntry, _InkRasterRequest>{};
  final _active = <_InkRasterRequest>{};
  Set<CanvasElement> _visible = {};
  Completer<void>? _idle;
  int _samples = 0, _pixels = 0, _reserved = 0;
  int _recordingCount = 0, _rasterHits = 0;
  bool _closed = false;
  int get entryCount => _entries.length;
  int get retainedSamples => _samples;
  int get recordingCount => _recordingCount;
  int get rasterEntryCount => _rasters.length;
  int get retainedRasterPixels => _pixels + _reserved;
  int get rasterHits => _rasterHits;
  Future<void> get rasterizationIdle => _idle?.future ?? Future.value();

  void retainVisible(Iterable<CanvasElement> elements) {
    if (!rasterizeSavedInk) return;
    _visible = {
      for (final element in elements)
        if (element.type == 'ink') element,
    };
  }

  Rect? _strokeBounds(CanvasElement element) {
    if (element.points.isEmpty) return null;
    var left = double.infinity, top = double.infinity;
    var right = double.negativeInfinity, bottom = double.negativeInfinity;
    for (final p in element.points) {
      left = math.min(left, p.x);
      top = math.min(top, p.y);
      right = math.max(right, p.x);
      bottom = math.max(bottom, p.y);
    }
    final width = element.data['isHighlighter'] == true
        ? math.max(16.0, element.strokeWidth)
        : element.strokeWidth;
    // Includes brush pressure, chisel tips, pencil grain and round caps.
    final padding = width * 2 + 2;
    final bounds = Rect.fromLTRB(
      element.x + left,
      element.y + top,
      element.x + right,
      element.y + bottom,
    ).inflate(padding);
    return bounds.isFinite ? bounds : null;
  }

  void draw(
    Canvas canvas,
    CanvasElement element,
    Color color,
    void Function(Canvas) paint, {
    double pixelScale = 1,
  }) {
    if (_closed) {
      paint(canvas);
      return;
    }
    final key = (element, color);
    var entry = _entries.remove(key);
    if (entry == null) {
      final count = element.data['points'] is List
          ? (element.data['points'] as List).length
          : 0;
      if (count > maxSamples) {
        paint(canvas);
        return;
      }
      final recorder = ui.PictureRecorder();
      try {
        paint(Canvas(recorder));
        entry = _InkDisplayEntry(
          recorder.endRecording(),
          count,
          rasterizeSavedInk ? _strokeBounds(element) : null,
          element,
        );
      } catch (_) {
        if (recorder.isRecording) recorder.endRecording().dispose();
        rethrow;
      }
      _recordingCount++;
      _samples += count;
    }
    _entries[key] = entry;
    while (_entries.length > maxEntries || _samples > maxSamples) {
      final oldest = _entries.remove(_entries.keys.first)!;
      _retire(oldest);
      _samples -= oldest.samples;
    }
    final image = entry.image;
    final bounds = entry.bounds;
    if (image != null &&
        bounds != null &&
        pixelScale.isFinite &&
        pixelScale > 0 &&
        entry.imageScale >= pixelScale) {
      _rasters.remove(entry);
      _rasters.add(entry);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(
          bounds.left,
          bounds.top,
          image.width / entry.imageScale,
          image.height / entry.imageScale,
        ),
        Paint()..filterQuality = FilterQuality.medium,
      );
      _rasterHits++;
    } else {
      canvas.drawPicture(entry.picture);
    }
    if (rasterizeSavedInk && entry.samples >= 256) {
      _ensureRaster(entry, pixelScale);
    }
  }

  void _ensureRaster(_InkDisplayEntry entry, double requested) {
    final bounds = entry.bounds;
    if (bounds == null || !requested.isFinite || requested <= 0) return;
    // Half-octaves avoid regenerating on every tiny zoom step; always round up.
    final scale = math
        .pow(2, (math.log(requested) / math.ln2 * 2).ceil() / 2)
        .toDouble();
    if (!scale.isFinite || scale <= 0) return;
    if (entry.image != null &&
        entry.imageScale >= scale &&
        entry.imageScale <= scale * 1.5) {
      return;
    }
    if (entry.failedScale == scale ||
        _pending[entry]?.scale == scale ||
        _active.any(
          (r) =>
              identical(r.entry, entry) &&
              r.serial == entry.serial &&
              r.scale == scale,
        )) {
      return;
    }
    final pixelWidth = bounds.width * scale,
        pixelHeight = bounds.height * scale;
    if (!pixelWidth.isFinite ||
        !pixelHeight.isFinite ||
        pixelWidth > 4096 ||
        pixelHeight > 4096) {
      return;
    }
    final w = pixelWidth.ceil(), h = pixelHeight.ceil();
    if (w < 1 || h < 1 || w > 4096 || h > 4096 || w * h > maxRasterPixels) {
      return;
    }
    _pending[entry] = _InkRasterRequest(entry, scale, w, h, ++entry.serial);
    _idle ??= Completer<void>();
    _drain();
  }

  void _drain() {
    while (!_closed && _active.length < 2 && _pending.isNotEmpty) {
      final request = _pending.remove(_pending.keys.first)!;
      if (!request.entry.alive ||
          request.serial != request.entry.serial ||
          !_visible.contains(request.entry.element)) {
        continue;
      }
      while (_rasters.isNotEmpty &&
          _pixels + _reserved + request.pixels > maxRasterPixels) {
        final evictable = _rasters
            .where((entry) => !_visible.contains(entry.element))
            .firstOrNull;
        if (evictable == null) break;
        _dropRaster(evictable);
      }
      if (_pixels + _reserved + request.pixels > maxRasterPixels) {
        // Never churn images that are still visible. Excess visible complexity
        // uses vectors; a later viewport change can admit a new preview.
        continue;
      }
      _active.add(request);
      _reserved += request.pixels;
      unawaited(_createRaster(request));
    }
    if (_active.isEmpty && _pending.isEmpty) {
      _idle?.complete();
      _idle = null;
    }
  }

  Future<void> _createRaster(_InkRasterRequest request) async {
    ui.Picture? picture;
    ui.Image? image;
    var changed = false;
    final entry = request.entry;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..scale(request.scale)
        ..translate(-entry.bounds!.left, -entry.bounds!.top);
      canvas.drawPicture(entry.picture);
      picture = recorder.endRecording();
      image = await _rasterize(picture, request.width, request.height);
      if (image.width != request.width || image.height != request.height) {
        throw StateError('Unexpected ink preview dimensions');
      }
      if (!_closed &&
          entry.alive &&
          request.serial == entry.serial &&
          _visible.contains(entry.element)) {
        _dropRaster(entry);
        entry.image = image;
        entry.imageScale = request.scale;
        _pixels += request.pixels;
        _rasters.add(entry);
        image = null;
        changed = true;
      }
    } catch (_) {
      if (entry.alive && request.serial == entry.serial) {
        entry.failedScale = request.scale;
      }
      // A preview is optional. Keep the exact vectors on native allocation or
      // backend failure instead of losing ink or repeatedly retrying every frame.
    } finally {
      image?.dispose();
      picture?.dispose();
      _active.remove(request);
      _reserved -= request.pixels;
      _drain();
      if (changed && !_closed && entry.alive) notifyListeners();
    }
  }

  void _dropRaster(_InkDisplayEntry entry) {
    final image = entry.image;
    if (image != null) {
      _pixels -= image.width * image.height;
      image.dispose();
      entry.image = null;
    }
    _rasters.remove(entry);
  }

  void _retire(_InkDisplayEntry entry) {
    entry.alive = false;
    entry.serial++;
    _pending.remove(entry);
    _dropRaster(entry);
    entry.picture.dispose();
  }

  void clear() {
    for (final entry in _entries.values) {
      _retire(entry);
    }
    _entries.clear();
    _pending.clear();
    _visible.clear();
    _samples = 0;
    if (_active.isEmpty) {
      _idle?.complete();
      _idle = null;
    }
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    clear();
    super.dispose();
  }
}

class CanvasTextCache {
  final LinkedHashMap<Object, TextPainter> _entries = LinkedHashMap();
  final LinkedHashMap<String, List<CanvasRichLine>> _richEntries =
      LinkedHashMap();
  int _richCharacters = 0;

  /// Content-keyed parsing shared by painting and checkbox hit testing. Camera,
  /// theme and font changes do not change the parse; edited text has a new key.
  List<CanvasRichLine> richLines(String text) {
    final cached = _richEntries.remove(text);
    if (cached != null) {
      _richEntries[text] = cached;
      return cached;
    }
    final lines = List<CanvasRichLine>.unmodifiable(
      CanvasRichText.parseLines(text),
    );
    const characterBudget = 262144;
    if (text.length <= characterBudget) {
      _richEntries[text] = lines;
      _richCharacters += text.length;
      while (_richEntries.length > 256 || _richCharacters > characterBudget) {
        final oldest = _richEntries.keys.first;
        _richCharacters -= oldest.length;
        _richEntries.remove(oldest);
      }
    }
    return lines;
  }

  TextPainter layout(
    String text,
    TextStyle style,
    double width,
    int? maxLines,
  ) {
    final key = (text, style, width, maxLines);
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    )..layout(maxWidth: width);
    _entries[key] = painter;
    while (_entries.length > 256) {
      _entries.remove(_entries.keys.first)?.dispose();
    }
    return painter;
  }

  void dispose() {
    for (final painter in _entries.values) {
      painter.dispose();
    }
    _entries.clear();
    _richEntries.clear();
    _richCharacters = 0;
  }
}

class OrbitCanvasPainter extends CustomPainter {
  OrbitCanvasPainter({
    required this.scene,
    required this.camera,
    required this.selection,
    required this.objects,
    required this.colors,
    this.semanticColors,
    this.region,
    this.lassoPoints,
    this.preview,
    this.editingId,
    this.guides = const [],
    this.images = const {},
    this.backgroundStyle = 'dots',
    this.hoveredAnchorElementId,
    this.connectingStartElementId,
    required this.textCache,
    this.exportElementIds,
    this.transparentBackground = false,
    this.fontFamily = 'Segoe UI',
    this.searchMatchIds = const {},
    this.activeSearchMatchId,
    this.forceUmlDetails = false,
    this.revealProgress = const {},
    this.inkCache,
    this.devicePixelRatio = 1,
  }) : sceneRevision = scene.revision,
       super(repaint: inkCache);
  final CanvasTextCache textCache;
  final CanvasInkCache? inkCache;
  final double devicePixelRatio;
  final int sceneRevision;
  final CanvasScene scene;
  final CanvasCamera camera;
  final Set<String> selection;
  final Map<String, CanvasObjectReference> objects;
  final ColorScheme colors;
  final OrbitColors? semanticColors;
  Color get _success => semanticColors?.success ?? colors.tertiary;
  Color get _warning => semanticColors?.warning ?? colors.secondary;
  final CanvasBounds? region;
  final List<CanvasPoint>? lassoPoints;
  final CanvasElement? preview;
  final String? editingId;
  final List<CanvasGuideLine> guides;
  final Map<String, ui.Image> images;
  final String backgroundStyle;
  final String? hoveredAnchorElementId;
  final String? connectingStartElementId;
  final Set<String>? exportElementIds;
  final bool transparentBackground;
  final String fontFamily;
  final Set<String> searchMatchIds;
  final String? activeSearchMatchId;
  final bool forceUmlDetails;
  final Map<String, double> revealProgress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (!transparentBackground) {
      canvas.drawColor(
        semanticColors?.canvasBackground ?? colors.surface,
        BlendMode.src,
      );
      _grid(canvas, size);
    }
    canvas.save();
    canvas.scale(camera.zoom);
    canvas.translate(-camera.x, -camera.y);
    final visible =
        (exportElementIds != null
                ? scene.elements.where((e) => exportElementIds!.contains(e.id))
                : scene.query(
                    camera
                        .viewport(size.width, size.height)
                        .inflate(80 / camera.zoom),
                  ))
            .toList(growable: false);
    inkCache?.retainVisible(visible);
    for (final element in visible.where((e) => e.type == 'column')) {
      _element(canvas, element);
    }
    for (final element in visible.where((e) => e.type != 'column')) {
      _element(canvas, element);
    }
    if (preview != null) _element(canvas, preview!);
    if (exportElementIds == null) {
      if (searchMatchIds.isNotEmpty) {
        final matchBorderPaint = Paint()
          ..color = _warning.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / camera.zoom;
        final matchFillPaint = Paint()
          ..color = _warning.withValues(alpha: 0.14)
          ..style = PaintingStyle.fill;
        final activeMatchBorderPaint = Paint()
          ..color = colors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 / camera.zoom;
        final activeMatchGlowPaint = Paint()
          ..color = colors.primary.withValues(alpha: 0.24)
          ..style = PaintingStyle.fill;

        for (final id in searchMatchIds) {
          final element = scene[id];
          if (element == null || element.hidden) continue;
          final isActive = id == activeSearchMatchId;
          final bounds = _rect(
            element.bounds.inflate(
              isActive ? 6 / camera.zoom : 4 / camera.zoom,
            ),
          );
          final rrect = RRect.fromRectAndRadius(
            bounds,
            Radius.circular(8 / camera.zoom),
          );
          canvas.drawRRect(
            rrect,
            isActive ? activeMatchGlowPaint : matchFillPaint,
          );
          canvas.drawRRect(
            rrect,
            isActive ? activeMatchBorderPaint : matchBorderPaint,
          );
        }
      }

      final selectionPaint = Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / camera.zoom;
      for (final id in selection) {
        final element = scene[id];
        if (element == null || element.hidden) continue;
        final bounds = _rect(element.bounds.inflate(4 / camera.zoom));
        canvas.drawRRect(
          RRect.fromRectAndRadius(bounds, Radius.circular(8 / camera.zoom)),
          selectionPaint,
        );
        if (element.locked) {
          _text(
            canvas,
            '🔒',
            Rect.fromLTWH(
              bounds.right - 18 / camera.zoom,
              bounds.top - 18 / camera.zoom,
              18 / camera.zoom,
              18 / camera.zoom,
            ),
            color: colors.primary,
            size: 12 / camera.zoom,
          );
        }
        if (selection.length == 1 &&
            isConnectorElement(element) &&
            !element.locked) {
          final endpoints = resolveConnectorEndpoints(element, scene);
          for (final point in [endpoints.start, endpoints.end]) {
            canvas.drawCircle(
              Offset(point.x, point.y),
              5 / camera.zoom,
              Paint()..color = colors.primary,
            );
            canvas.drawCircle(
              Offset(point.x, point.y),
              5 / camera.zoom,
              Paint()
                ..color = colors.onSurface
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1 / camera.zoom,
            );
          }
        } else if (selection.length == 1 && element.type != 'ink') {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: bounds.bottomRight,
                width: 9 / camera.zoom,
                height: 9 / camera.zoom,
              ),
              Radius.circular(2 / camera.zoom),
            ),
            Paint()..color = colors.primary,
          );
        }
      }
      final selectedGroupIds = selection
          .map((id) => scene[id]?.groupId)
          .whereType<String>()
          .toSet();
      for (final gid in selectedGroupIds) {
        final gBounds = calculateGroupBounds(scene, gid);
        if (gBounds != null) {
          final groupRect = _rect(gBounds.inflate(8 / camera.zoom));
          final groupPaint = Paint()
            ..color = colors.primary.withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2 / camera.zoom;
          _drawDashedRect(canvas, groupRect, groupPaint, camera.zoom);

          final badgeWidth = 46.0 / camera.zoom;
          final badgeHeight = 15.0 / camera.zoom;
          final badgeRect = Rect.fromLTWH(
            groupRect.left,
            groupRect.top - badgeHeight - 2 / camera.zoom,
            badgeWidth,
            badgeHeight,
          );
          final badgeBg = Paint()
            ..color = colors.primary.withValues(alpha: 0.16)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              badgeRect,
              Radius.circular(3 / camera.zoom),
            ),
            badgeBg,
          );
          _text(
            canvas,
            'GROUP',
            badgeRect,
            color: colors.primary,
            size: 9 / camera.zoom,
          );
        }
      }
      if (region != null) {
        canvas.drawRect(
          _rect(region!),
          Paint()..color = colors.primary.withValues(alpha: .08),
        );
        canvas.drawRect(_rect(region!), selectionPaint);
      }
      if (lassoPoints != null && lassoPoints!.length >= 2) {
        final path = Path();
        path.moveTo(lassoPoints!.first.x, lassoPoints!.first.y);
        for (var i = 1; i < lassoPoints!.length; i++) {
          path.lineTo(lassoPoints![i].x, lassoPoints![i].y);
        }
        final lassoFill = Paint()
          ..color = colors.primary.withValues(alpha: .09)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, lassoFill);

        final lassoStroke = Paint()
          ..color = colors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / camera.zoom
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < lassoPoints!.length - 1; i++) {
          _drawDashedLine(
            canvas,
            Offset(lassoPoints![i].x, lassoPoints![i].y),
            Offset(lassoPoints![i + 1].x, lassoPoints![i + 1].y),
            lassoStroke,
            dashLength: 5.0 / camera.zoom,
            gapLength: 3.0 / camera.zoom,
          );
        }
      }
      if (guides.isNotEmpty) {
        final guidePaint = Paint()
          ..color = colors.primary.withValues(alpha: .75)
          ..strokeWidth = 1.0 / camera.zoom
          ..style = PaintingStyle.stroke;
        final vp = camera.viewport(size.width, size.height);
        for (final guide in guides) {
          if (guide.isVertical) {
            _drawDashedLine(
              canvas,
              Offset(guide.position, vp.top),
              Offset(guide.position, vp.bottom),
              guidePaint,
              dashLength: 5.0 / camera.zoom,
              gapLength: 4.0 / camera.zoom,
            );
          } else {
            _drawDashedLine(
              canvas,
              Offset(vp.left, guide.position),
              Offset(vp.right, guide.position),
              guidePaint,
              dashLength: 5.0 / camera.zoom,
              gapLength: 4.0 / camera.zoom,
            );
          }
        }
      }
      final anchorTargetIds = {
        hoveredAnchorElementId,
        connectingStartElementId,
      }.whereType<String>();
      if (anchorTargetIds.isNotEmpty) {
        final dotPaint = Paint()
          ..color = colors.primary
          ..style = PaintingStyle.fill;
        final ringPaint = Paint()
          ..color = colors.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / camera.zoom;
        for (final elemId in anchorTargetIds) {
          final elem = scene[elemId];
          if (elem != null) {
            final anchors = getElementAnchors(elem.bounds);
            for (final anchor in anchors.values) {
              canvas.drawCircle(
                Offset(anchor.x, anchor.y),
                5.0 / camera.zoom,
                ringPaint,
              );
              canvas.drawCircle(
                Offset(anchor.x, anchor.y),
                3.5 / camera.zoom,
                dotPaint,
              );
            }
          }
        }
      }
    }
    canvas.restore();
    canvas.restore();
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance == 0) return;
    final nx = dx / distance;
    final ny = dy / distance;
    var current = 0.0;
    while (current < distance) {
      final next = math.min(current + dashLength, distance);
      canvas.drawLine(
        Offset(p1.dx + nx * current, p1.dy + ny * current),
        Offset(p1.dx + nx * next, p1.dy + ny * next),
        paint,
      );
      current = next + gapLength;
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint, double zoom) {
    final dash = 6.0 / zoom;
    final gap = 4.0 / zoom;
    _drawDashedLine(
      canvas,
      rect.topLeft,
      rect.topRight,
      paint,
      dashLength: dash,
      gapLength: gap,
    );
    _drawDashedLine(
      canvas,
      rect.topRight,
      rect.bottomRight,
      paint,
      dashLength: dash,
      gapLength: gap,
    );
    _drawDashedLine(
      canvas,
      rect.bottomRight,
      rect.bottomLeft,
      paint,
      dashLength: dash,
      gapLength: gap,
    );
    _drawDashedLine(
      canvas,
      rect.bottomLeft,
      rect.topLeft,
      paint,
      dashLength: dash,
      gapLength: gap,
    );
  }

  void _grid(Canvas canvas, Size size) {
    if (backgroundStyle == 'blank') return;

    // Theme grid ink is independent of text ink. Publication renderers keep
    // using their explicit paper scheme when no semantic palette is supplied.
    Color gridInk(double opacity) {
      final ink = semanticColors?.canvasGrid;
      return ink == null
          ? colors.onSurface.withValues(alpha: opacity)
          : ink.withValues(alpha: ink.a * (opacity * 4).clamp(0.0, 1.0));
    }

    var step = 24 * camera.zoom;
    while (step < 15) {
      step *= 4;
    }
    final origin = camera.toScreen(const CanvasPoint(0, 0));

    if (backgroundStyle == 'grid') {
      final linePaint = Paint()
        ..color = gridInk(.08)
        ..strokeWidth = 1.0;
      for (var x = origin.x % step; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
      for (var y = origin.y % step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    } else if (backgroundStyle == 'graph') {
      // Engineering / Math graph paper: minor grid + prominent major grid
      var minorStep = 8.0 * camera.zoom;
      while (minorStep < 6.0) {
        minorStep *= 4.0;
      }
      final majorStep = minorStep * 4.0;
      final minorPaint = Paint()
        ..color = gridInk(.045)
        ..strokeWidth = 0.75;
      final majorPaint = Paint()
        ..color = gridInk(.15)
        ..strokeWidth = 1.25;

      for (var x = origin.x % minorStep; x < size.width; x += minorStep) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorPaint);
      }
      for (var y = origin.y % minorStep; y < size.height; y += minorStep) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
      }
      for (var x = origin.x % majorStep; x < size.width; x += majorStep) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
      }
      for (var y = origin.y % majorStep; y < size.height; y += majorStep) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
      }
    } else if (backgroundStyle == 'cornell') {
      // Cornell Notes layout: Ruled lines + Left Cue divider + Bottom Summary divider
      final rulePaint = Paint()
        ..color = gridInk(.09)
        ..strokeWidth = 1.0;
      for (var y = origin.y % step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
      }

      final cueScreenX = camera.toScreen(const CanvasPoint(200, 0)).x;
      final dividerPaint = Paint()
        ..color = colors.primary.withValues(alpha: .38)
        ..strokeWidth = 1.75;
      if (cueScreenX >= 0 && cueScreenX <= size.width) {
        canvas.drawLine(
          Offset(cueScreenX, 0),
          Offset(cueScreenX, size.height),
          dividerPaint,
        );
      }

      final summaryScreenY = camera.toScreen(const CanvasPoint(0, 700)).y;
      if (summaryScreenY >= 0 && summaryScreenY <= size.height) {
        canvas.drawLine(
          Offset(0, summaryScreenY),
          Offset(size.width, summaryScreenY),
          dividerPaint,
        );
      }

      if (camera.zoom > 0.35) {
        final labelColor = colors.primary.withValues(alpha: .60);
        if (cueScreenX > 60 && cueScreenX <= size.width + 100) {
          _text(
            canvas,
            'CUES / QUESTIONS',
            Rect.fromLTWH(
              math.max(12, cueScreenX - 160),
              math.max(12, origin.y + 12),
              150,
              20,
            ),
            color: labelColor,
            size: 10,
            weight: FontWeight.w700,
          );
        }
        if (cueScreenX + 16 < size.width) {
          _text(
            canvas,
            'NOTES',
            Rect.fromLTWH(
              math.max(12, cueScreenX + 16),
              math.max(12, origin.y + 12),
              100,
              20,
            ),
            color: labelColor,
            size: 10,
            weight: FontWeight.w700,
          );
        }
        if (summaryScreenY >= 0 && summaryScreenY + 8 < size.height) {
          _text(
            canvas,
            'SUMMARY',
            Rect.fromLTWH(
              math.max(12, origin.x + 12),
              summaryScreenY + 8,
              120,
              20,
            ),
            color: labelColor,
            size: 10,
            weight: FontWeight.w700,
          );
        }
      }
    } else if (backgroundStyle == 'lines' || backgroundStyle == 'ruled') {
      final linePaint = Paint()
        ..color = gridInk(.09)
        ..strokeWidth = 1.0;
      for (var y = origin.y % step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
      if (backgroundStyle == 'ruled') {
        final marginScreenX = camera.toScreen(const CanvasPoint(72, 0)).x;
        if (marginScreenX >= 0 && marginScreenX <= size.width) {
          final marginPaint = Paint()
            ..color = const Color(0xffef4444).withValues(alpha: .38)
            ..strokeWidth = 1.5;
          canvas.drawLine(
            Offset(marginScreenX, 0),
            Offset(marginScreenX, size.height),
            marginPaint,
          );
        }
      }
    } else if (backgroundStyle == 'isometric') {
      final isoPaint = Paint()
        ..color = gridInk(.07)
        ..strokeWidth = 0.8;
      final isoStepX = step * 1.5;
      final isoStepY = isoStepX * 0.57735;
      for (var x = origin.x % isoStepX; x < size.width; x += isoStepX) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), isoPaint);
      }
      final diagCount =
          ((size.height + size.width * 0.57735) / isoStepY).ceil() + 2;
      final startK = -((size.width * 0.57735) / isoStepY).ceil() - 1;
      for (var i = startK; i < diagCount; i++) {
        final startY = origin.y % isoStepY + i * isoStepY;
        canvas.drawLine(
          Offset(0, startY),
          Offset(size.width, startY + size.width * 0.57735),
          isoPaint,
        );
        canvas.drawLine(
          Offset(0, startY),
          Offset(size.width, startY - size.width * 0.57735),
          isoPaint,
        );
      }
    } else if (backgroundStyle == 'cross') {
      final crossPaint = Paint()
        ..color = gridInk(.15)
        ..strokeWidth = 1.0;
      final arm = math.min(step * 0.18, 4.0 * camera.zoom).clamp(1.5, 6.0);
      for (var x = origin.x % step; x < size.width; x += step) {
        for (var y = origin.y % step; y < size.height; y += step) {
          canvas.drawLine(Offset(x - arm, y), Offset(x + arm, y), crossPaint);
          canvas.drawLine(Offset(x, y - arm), Offset(x, y + arm), crossPaint);
        }
      }
    } else if (backgroundStyle == 'hex') {
      var r = 28.0 * camera.zoom;
      while (r < 14.0) {
        r *= 2.0;
      }
      final w = 1.7320508 * r;
      final vertDist = 1.5 * r;
      final hexPaint = Paint()
        ..color = gridInk(.08)
        ..strokeWidth = 0.9;

      final startRow = ((-origin.y - 2 * r) / vertDist).floor();
      final endRow = ((size.height - origin.y + 2 * r) / vertDist).ceil();
      final startCol = ((-origin.x - 2 * w) / w).floor();
      final endCol = ((size.width - origin.x + 2 * w) / w).ceil();

      for (var row = startRow; row <= endRow; row++) {
        final rowOffset = row.isOdd ? w * 0.5 : 0.0;
        final cy = origin.y + row * vertDist;
        for (var col = startCol; col <= endCol; col++) {
          final cx = origin.x + col * w + rowOffset;
          final v0 = Offset(cx + w * 0.5, cy + r * 0.5);
          final v1 = Offset(cx, cy + r);
          final v2 = Offset(cx - w * 0.5, cy + r * 0.5);
          final v3 = Offset(cx - w * 0.5, cy - r * 0.5);
          canvas.drawLine(v0, v1, hexPaint);
          canvas.drawLine(v1, v2, hexPaint);
          canvas.drawLine(v2, v3, hexPaint);
        }
      }
    } else if (backgroundStyle == 'blueprint' ||
        backgroundStyle == 'blueprint_classic') {
      // Blueprint paper is intentionally independent from the active app theme.
      // A real drafting sheet needs enough contrast for fine white ink while
      // remaining quiet behind filled cards and diagrams.
      final sheet = Rect.fromLTWH(0, 0, size.width, size.height);
      if (backgroundStyle == 'blueprint_classic') {
        canvas.drawRect(sheet, Paint()..color = const Color(0xff123b70));
      } else {
        final paper = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff173f69), Color(0xff24557f)],
          ).createShader(sheet);
        canvas.drawRect(sheet, paper);
      }

      final frame = sheet.deflate(
        math.min(18.0, math.min(size.width, size.height) / 2),
      );
      final framePaint = Paint()
        ..color = const Color(0xfff4f8ff).withValues(alpha: .28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRect(frame, framePaint);

      // Registration marks and a restrained title-block hint give the canvas
      // the visual language of a drafting sheet without covering the work.
      final markPaint = Paint()
        ..color = const Color(0xfff4f8ff).withValues(alpha: .38)
        ..strokeWidth = 1.0;
      const markLength = 9.0;
      for (final corner in [
        Offset(frame.left, frame.top),
        Offset(frame.right, frame.top),
        Offset(frame.left, frame.bottom),
        Offset(frame.right, frame.bottom),
      ]) {
        final xDirection = corner.dx == frame.left ? 1.0 : -1.0;
        final yDirection = corner.dy == frame.top ? 1.0 : -1.0;
        canvas.drawLine(
          corner,
          corner.translate(xDirection * markLength, 0),
          markPaint,
        );
        canvas.drawLine(
          corner,
          corner.translate(0, yDirection * markLength),
          markPaint,
        );
      }

      var minorStep = 12.0 * camera.zoom;
      while (minorStep < 6.0) {
        minorStep *= 4.0;
      }
      final majorStep = minorStep * 5.0;

      final minorPaint = Paint()
        ..color = const Color(0xfff4f8ff).withValues(alpha: .075)
        ..strokeWidth = 0.6;
      final majorPaint = Paint()
        ..color = const Color(0xfff4f8ff).withValues(alpha: .17)
        ..strokeWidth = 1.2;

      for (var x = origin.x % minorStep; x < size.width; x += minorStep) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorPaint);
      }
      for (var y = origin.y % minorStep; y < size.height; y += minorStep) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
      }
      for (var x = origin.x % majorStep; x < size.width; x += majorStep) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
      }
      for (var y = origin.y % majorStep; y < size.height; y += majorStep) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
      }

      // A centre line is a familiar architectural drafting cue. Keep it
      // dashed and low contrast so it reads as guidance rather than content.
      final centrePaint = Paint()
        ..color = const Color(0xfff4f8ff).withValues(alpha: .22)
        ..strokeWidth = .8;
      final centreX = size.width / 2;
      final centreY = size.height / 2;
      for (var x = frame.left; x < frame.right; x += 12) {
        canvas.drawLine(
          Offset(x, centreY),
          Offset(math.min(x + 6, frame.right), centreY),
          centrePaint,
        );
      }
      for (var y = frame.top; y < frame.bottom; y += 12) {
        canvas.drawLine(
          Offset(centreX, y),
          Offset(centreX, math.min(y + 6, frame.bottom)),
          centrePaint,
        );
      }
    } else if (backgroundStyle == 'music') {
      var lineGap = 7.0 * camera.zoom;
      while (lineGap < 3.5) {
        lineGap *= 2.0;
      }
      final staffHeight = lineGap * 4.0;
      final staffGap = lineGap * 6.0;
      final staffPeriod = staffHeight + staffGap;

      final staffPaint = Paint()
        ..color = gridInk(.15)
        ..strokeWidth = 0.9;
      final barPaint = Paint()
        ..color = gridInk(.12)
        ..strokeWidth = 1.0;

      final barStep = 180.0 * camera.zoom;
      final startY = origin.y % staffPeriod - staffPeriod;

      for (var sy = startY; sy < size.height + staffHeight; sy += staffPeriod) {
        for (var k = 0; k < 5; k++) {
          final y = sy + k * lineGap;
          if (y >= 0 && y <= size.height) {
            canvas.drawLine(Offset(0, y), Offset(size.width, y), staffPaint);
          }
        }
        for (var bx = origin.x % barStep; bx < size.width; bx += barStep) {
          canvas.drawLine(
            Offset(bx, sy),
            Offset(bx, sy + staffHeight),
            barPaint,
          );
        }
      }
    } else if (backgroundStyle == 'ledger') {
      final rulePaint = Paint()
        ..color = gridInk(.09)
        ..strokeWidth = 0.9;
      for (var y = origin.y % step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
      }

      final colWidths = [
        90.0 * camera.zoom,
        360.0 * camera.zoom,
        80.0 * camera.zoom,
        100.0 * camera.zoom,
        100.0 * camera.zoom,
        110.0 * camera.zoom,
      ];
      final colTotal = colWidths.fold<double>(0, (a, b) => a + b);
      final colNames = [
        'DATE',
        'DESCRIPTION',
        'REF',
        'DEBIT',
        'CREDIT',
        'BALANCE',
      ];

      final pageX = origin.x % colTotal - colTotal;
      for (var px = pageX; px < size.width + colTotal; px += colTotal) {
        var cx = px;
        for (var c = 0; c < colWidths.length; c++) {
          final w = colWidths[c];
          if (c == 3) {
            canvas.drawRect(
              Rect.fromLTWH(cx, 0, w, size.height),
              Paint()..color = const Color(0xffef4444).withValues(alpha: .02),
            );
          } else if (c == 4) {
            canvas.drawRect(
              Rect.fromLTWH(cx, 0, w, size.height),
              Paint()..color = const Color(0xff10b981).withValues(alpha: .02),
            );
          }

          final divPaint = Paint()
            ..color = (c == 0 || c == 3 || c == 4)
                ? colors.primary.withValues(alpha: .30)
                : gridInk(.10)
            ..strokeWidth = (c == 0 || c == 3 || c == 4) ? 1.4 : 0.8;
          if (cx >= 0 && cx <= size.width) {
            canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), divPaint);
          }

          if (camera.zoom > 0.45 && origin.y >= -30 && origin.y < size.height) {
            _text(
              canvas,
              colNames[c],
              Rect.fromLTWH(cx + 6, origin.y + 6, w - 12, 16),
              color: colors.primary.withValues(alpha: .65),
              size: 9,
              weight: FontWeight.w700,
            );
          }
          cx += w;
        }
        if (cx >= 0 && cx <= size.width) {
          canvas.drawLine(
            Offset(cx, 0),
            Offset(cx, size.height),
            Paint()
              ..color = colors.primary.withValues(alpha: .40)
              ..strokeWidth = 1.6,
          );
        }
      }
    } else if (backgroundStyle == 'triangular') {
      final triPaint = Paint()
        ..color = gridInk(.08)
        ..strokeWidth = 0.8;
      var triStep = 32.0 * camera.zoom;
      while (triStep < 16.0) {
        triStep *= 2.0;
      }
      final triH = triStep * 0.8660254;

      for (var y = origin.y % triH; y < size.height; y += triH) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), triPaint);
      }

      const slope = 1.7320508;
      final extraY = size.width * slope;
      final startX =
          (origin.x % triStep) - (extraY / slope).ceilToDouble() - triStep;
      final endX = size.width + (extraY / slope).ceilToDouble() + triStep;

      for (var x = startX; x < endX; x += triStep) {
        final yAt0 = (origin.y % triH) - x * slope;
        canvas.drawLine(
          Offset(0, yAt0),
          Offset(size.width, yAt0 + size.width * slope),
          triPaint,
        );
        final yAt0Opp = (origin.y % triH) + x * slope;
        canvas.drawLine(
          Offset(0, yAt0Opp),
          Offset(size.width, yAt0Opp - size.width * slope),
          triPaint,
        );
      }
    } else {
      // 'dots' (default)
      final paint = Paint()..color = gridInk(.11);
      for (var x = origin.x % step; x < size.width; x += step) {
        for (var y = origin.y % step; y < size.height; y += step) {
          canvas.drawCircle(Offset(x, y), .75, paint);
        }
      }
    }
  }

  void _element(Canvas canvas, CanvasElement element) {
    final progress = revealProgress[element.id] ?? 1;
    if (progress <= 0) return;
    if (progress >= 1) {
      _paintElement(canvas, element);
      return;
    }
    if (element.type == 'ink') {
      _paintElement(canvas, revealCanvasInk(element, progress));
    } else {
      final bounds = _rect(element.bounds.inflate(element.strokeWidth + 2));
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          bounds.left,
          bounds.top,
          bounds.width * progress,
          bounds.height,
        ),
      );
      _paintElement(canvas, element);
      canvas.restore();
    }
  }

  static double _inkPressure(dynamic raw, double fallback) {
    final value = raw is Map ? raw['pressure'] : null;
    return value is num && value.isFinite
        ? value.toDouble().clamp(0.0, 1.0)
        : fallback;
  }

  void _paintInk(Canvas canvas, CanvasElement element, Color accent) {
    final isHighlighter = element.data['isHighlighter'] == true;
    final penStyle =
        (element.data['penStyle'] is String
            ? element.data['penStyle'] as String
            : null) ??
        (isHighlighter ? 'highlighter' : 'ballpoint');
    final isFountain = penStyle == 'fountain';
    final isMarker = penStyle == 'marker';
    final isPencil = penStyle == 'pencil';
    final isCalligraphy = penStyle == 'calligraphy';
    final isBrush = penStyle == 'brush';
    final inkWidth = isHighlighter
        ? math.max(16.0, element.strokeWidth)
        : element.strokeWidth;
    final inkColor = isHighlighter
        ? accent.withValues(alpha: 0.38)
        : (isMarker
              ? accent.withValues(alpha: 0.90)
              : (isPencil ? accent.withValues(alpha: 0.72) : accent));
    final points = element.points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(
        Offset(element.x + points.first.x, element.y + points.first.y),
        inkWidth / 2,
        Paint()..color = inkColor,
      );
      return;
    }

    final rawPoints = element.data['points'] is List
        ? (element.data['points'] as List).whereType<Map>().toList(
            growable: false,
          )
        : null;
    final hasPressure =
        isFountain ||
        isBrush ||
        isPencil ||
        (rawPoints != null && rawPoints.any((p) => _inkPressure(p, 1) < 0.95));

    if (isCalligraphy) {
      // Chisel nib held at a constant 45-degree angle (pi / 4).
      const nibAngle = math.pi / 4;
      for (var i = 0; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];
        final dx = p2.x - p1.x;
        final dy = p2.y - p1.y;
        final strokeAngle = math.atan2(dy, dx);
        final angleDiff = strokeAngle - nibAngle;
        final chiselFactor = (0.24 + 0.82 * math.sin(angleDiff).abs()).clamp(
          0.2,
          1.0,
        );
        var pressureMultiplier = 1.0;
        if (rawPoints != null && i < rawPoints.length) {
          final raw = rawPoints[i];
          if (raw['pressure'] is num) {
            pressureMultiplier = 0.6 + _inkPressure(raw, 0.8) * 0.5;
          }
        }
        final segWidth = math.max(
          1.0,
          inkWidth * chiselFactor * pressureMultiplier,
        );
        final segPaint = Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = segWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawLine(
          Offset(element.x + p1.x, element.y + p1.y),
          Offset(element.x + p2.x, element.y + p2.y),
          segPaint,
        );
      }
    } else if (isPencil) {
      // Pencil: graphite texture with subtle jitter & paper tooth shading
      for (var i = 0; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];
        var pressure = 0.7;
        if (rawPoints != null && i < rawPoints.length) {
          final raw = rawPoints[i];
          if (raw['pressure'] is num) {
            pressure = _inkPressure(raw, 0.7);
          }
        }
        final segWidth = math.max(
          0.6,
          inkWidth * (0.65 + pressure.clamp(0.1, 1.0) * 0.45),
        );
        final pencilAlpha = (0.48 + pressure.clamp(0.1, 1.0) * 0.42).clamp(
          0.2,
          0.9,
        );
        final pPaint = Paint()
          ..color = accent.withValues(alpha: pencilAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = segWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawLine(
          Offset(element.x + p1.x, element.y + p1.y),
          Offset(element.x + p2.x, element.y + p2.y),
          pPaint,
        );
        // Subtle grain offset pass for graphite feel
        if (segWidth > 1.2) {
          final grainPaint = Paint()
            ..color = accent.withValues(alpha: pencilAlpha * 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = segWidth * 0.6
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(element.x + p1.x + 0.35, element.y + p1.y + 0.35),
            Offset(element.x + p2.x + 0.35, element.y + p2.y + 0.35),
            grainPaint,
          );
        }
      }
    } else if (isBrush) {
      // Brush: wide dynamic pressure range and entry/exit tapering
      for (var i = 0; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];
        var pressure1 = 0.7;
        var pressure2 = 0.7;
        if (rawPoints != null && rawPoints.length == points.length) {
          if (rawPoints[i]['pressure'] is num) {
            pressure1 = _inkPressure(rawPoints[i], 0.7);
          }
          if (rawPoints[i + 1]['pressure'] is num) {
            pressure2 = _inkPressure(rawPoints[i + 1], 0.7);
          }
        }
        final avgPressure = ((pressure1 + pressure2) / 2).clamp(0.1, 1.0);
        var taper = 1.0;
        if (i == 0) taper = 0.55;
        if (i == points.length - 2) taper = 0.55;
        final segWidth = math.max(
          0.8,
          inkWidth * (0.25 + avgPressure * avgPressure * 1.8) * taper,
        );
        final segPaint = Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = segWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawLine(
          Offset(element.x + p1.x, element.y + p1.y),
          Offset(element.x + p2.x, element.y + p2.y),
          segPaint,
        );
      }
    } else if (hasPressure &&
        rawPoints != null &&
        rawPoints.length == points.length) {
      for (var i = 0; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];
        final pressure1 = (rawPoints[i]['pressure'] is num)
            ? _inkPressure(rawPoints[i], 0.7)
            : 0.7;
        final pressure2 = (rawPoints[i + 1]['pressure'] is num)
            ? _inkPressure(rawPoints[i + 1], 0.7)
            : 0.7;
        final avgPressure = ((pressure1 + pressure2) / 2).clamp(0.1, 1.0);
        final segWidth = math.max(0.8, inkWidth * (0.35 + avgPressure * 0.9));
        final segPaint = Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = segWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawLine(
          Offset(element.x + p1.x, element.y + p1.y),
          Offset(element.x + p2.x, element.y + p2.y),
          segPaint,
        );
      }
    } else {
      final path = Path()
        ..moveTo(element.x + points.first.x, element.y + points.first.y);
      if (points.length == 2) {
        path.lineTo(element.x + points[1].x, element.y + points[1].y);
      } else {
        for (var i = 1; i < points.length - 1; i++) {
          final p1 = points[i];
          final p2 = points[i + 1];
          final midX = element.x + (p1.x + p2.x) / 2;
          final midY = element.y + (p1.y + p2.y) / 2;
          path.quadraticBezierTo(
            element.x + p1.x,
            element.y + p1.y,
            midX,
            midY,
          );
        }
        path.lineTo(element.x + points.last.x, element.y + points.last.y);
      }
      final inkStroke = Paint()
        ..color = inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = inkWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, inkStroke);
    }
  }

  void _paintElement(Canvas canvas, CanvasElement element) {
    if (!element.renderable || element.id == editingId) return;
    final bounds = _rect(element.bounds);
    final accent = isInteractionItem(element) && element.data['color'] is! int
        ? colors.onSurface
        : Color(element.color);
    final stroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = element.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (isInteractionNode(element)) {
      final glyph = interactionGlyph(element);
      final line = Paint()
        ..color = accent.withValues(alpha: .75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = element.strokeWidth;
      for (final box in glyph.boxes) {
        if (box.fill) {
          canvas.drawRect(_rect(box.bounds), Paint()..color = colors.surface);
        }
        canvas.drawRect(_rect(box.bounds), line);
      }
      for (final oval in glyph.ovals) {
        if (oval.fill) {
          canvas.drawOval(_rect(oval.bounds), Paint()..color = colors.surface);
        }
        canvas.drawOval(_rect(oval.bounds), line);
      }
      for (final shape in glyph.paths) {
        final path = Path()..moveTo(shape.points.first.x, shape.points.first.y);
        for (final p in shape.points.skip(1)) {
          path.lineTo(p.x, p.y);
        }
        if (!shape.dashed) {
          canvas.drawPath(path, line);
        } else {
          for (final metric in path.computeMetrics()) {
            for (var d = 0.0; d < metric.length; d += 13) {
              canvas.drawPath(
                metric.extractPath(d, math.min(d + 8, metric.length)),
                line,
              );
            }
          }
        }
      }
      if (camera.zoom > .2 || forceUmlDetails) {
        for (final label in glyph.texts) {
          final r = _rect(label.bounds);
          if (r.width <= 0 || r.height <= 0) continue;
          final text = wrapUmlText(label.text, r.width, label.size).join('\n');
          final tp = textCache.layout(
            text,
            TextStyle(
              color: colors.onSurface,
              fontFamily: fontFamily,
              fontSize: label.size,
              fontWeight: label.bold ? FontWeight.w600 : FontWeight.normal,
            ),
            r.width,
            80,
          );
          canvas.save();
          canvas.clipRect(r);
          tp.paint(
            canvas,
            Offset(
              label.center ? r.center.dx - tp.width / 2 : r.left,
              r.top + math.max(0, (r.height - tp.height) / 2),
            ),
          );
          canvas.restore();
        }
      }
      return;
    }
    if (isUmlClass(element)) {
      final model = UmlClass(element);
      final palette = UmlPalette(
        colors.surface.toARGB32(),
        foreground: colors.onSurface.toARGB32(),
      );
      final outline = Paint()
        ..color = Color(palette.border)
        ..style = PaintingStyle.stroke
        ..strokeWidth = element.strokeWidth;
      final shape = RRect.fromRectAndRadius(
        bounds,
        const Radius.circular(OrbitRadius.control),
      );
      canvas.save();
      canvas.clipRRect(shape);
      canvas.drawRect(bounds, Paint()..color = Color(palette.body));
      final headerBottom = bounds.top + model.headerHeight;
      final membersBottom = headerBottom + model.attributeHeight;
      canvas.drawRect(
        Rect.fromLTRB(bounds.left, bounds.top, bounds.right, headerBottom),
        Paint()..color = Color(palette.header),
      );
      for (final y in [headerBottom, membersBottom]) {
        canvas.drawLine(
          Offset(bounds.left, y),
          Offset(bounds.right, y),
          Paint()
            ..color = Color(palette.divider)
            ..strokeWidth = 1,
        );
      }
      canvas.drawLine(
        Offset(bounds.left + 14, headerBottom - 1),
        Offset(bounds.left + 44, headerBottom - 1),
        Paint()
          ..color = accent.withValues(alpha: .75)
          ..strokeWidth = 2,
      );
      if (camera.zoom > .25 || forceUmlDetails) {
        void centered(String value, double top, {bool title = false}) {
          final tp = textCache.layout(
            value,
            TextStyle(
              color: colors.onSurface,
              fontFamily: fontFamily,
              fontSize: title ? 16 : 12,
              fontWeight: title ? FontWeight.w600 : FontWeight.w400,
              fontStyle: title && model.abstractClass
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
            math.max(1, bounds.width - 24),
            1,
          );
          tp.paint(canvas, Offset(bounds.center.dx - tp.width / 2, top));
        }

        if (model.stereotype.isNotEmpty) {
          centered('«${model.stereotype}»', bounds.top + 10);
        }
        centered(
          model.name,
          bounds.top + (model.stereotype.isEmpty ? 14 : 36),
          title: true,
        );
        void members(List<String> lines, double top, double bottom) {
          canvas.save();
          canvas.clipRect(
            Rect.fromLTRB(
              bounds.left,
              top,
              bounds.right,
              math.max(top, bottom),
            ),
          );
          for (var i = 0; i < lines.length; i++) {
            if (top + 10 + i * 22 >= bottom) break;
            _text(
              canvas,
              lines[i],
              Rect.fromLTWH(
                bounds.left + 14,
                top + 10 + i * 22,
                math.max(0, bounds.width - 28),
                22,
              ),
              color: colors.onSurface,
              size: 15,
              maxLines: 1,
            );
          }
          canvas.restore();
        }

        members(
          model.attributes,
          headerBottom,
          math.min(membersBottom, bounds.bottom),
        );
        members(
          model.operations,
          membersBottom,
          math.max(membersBottom, bounds.bottom),
        );
      }
      canvas.restore();
      canvas.drawRRect(shape, outline);
      return;
    }
    switch (element.type) {
      case 'column':
        canvas.drawRRect(
          RRect.fromRectAndRadius(bounds, const Radius.circular(12)),
          Paint()..color = colors.surfaceContainerLow,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bounds, const Radius.circular(12)),
          Paint()
            ..color = colors.outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        canvas.drawLine(
          Offset(bounds.left + 16, bounds.top + 42),
          Offset(bounds.right - 16, bounds.top + 42),
          Paint()
            ..color = accent.withValues(alpha: .45)
            ..strokeWidth = 2,
        );
        if (camera.zoom > .25) {
          _text(
            canvas,
            element.text,
            Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 12,
              math.max(1, bounds.width - 32),
              26,
            ),
            color: colors.onSurface,
            size: 15,
            weight: FontWeight.w600,
            maxLines: 1,
          );
        }
      case 'link':
        canvas.drawRRect(
          RRect.fromRectAndRadius(bounds, const Radius.circular(12)),
          Paint()..color = colors.surfaceContainerHigh,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bounds, const Radius.circular(12)),
          Paint()
            ..color = colors.outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        if (camera.zoom > .25) {
          _text(
            canvas,
            'WEBSITE ↗',
            Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 14,
              math.max(1, bounds.width - 32),
              20,
            ),
            color: accent,
            size: 10,
          );
          _text(
            canvas,
            element.text,
            Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 40,
              math.max(1, bounds.width - 32),
              44,
            ),
            color: colors.onSurface,
            size: 16,
            weight: FontWeight.w600,
            maxLines: 2,
          );
          _text(
            canvas,
            element.url,
            Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 92,
              math.max(1, bounds.width - 32),
              22,
            ),
            color: colors.onSurfaceVariant,
            size: 11,
            maxLines: 1,
          );
        }
      case 'image':
        final image = images[element.data['contentRef']];
        final destination = Rect.fromLTWH(
          element.x,
          element.y,
          element.width,
          element.height,
        );
        if (image != null) {
          paintImage(
            canvas: canvas,
            rect: destination,
            image: image,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          );
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(destination, const Radius.circular(10)),
            Paint()..color = colors.surfaceContainerHigh,
          );
        }
      case 'ink':
        final cache = inkCache;
        // A growing preview/replay is transient; do not retain one display list
        // for every sample. Only committed immutable scene snapshots are cached.
        if (cache != null && identical(scene[element.id], element)) {
          cache.draw(
            canvas,
            element,
            accent,
            (target) => _paintInk(target, element, accent),
            pixelScale: camera.zoom * devicePixelRatio,
          );
        } else {
          _paintInk(canvas, element, accent);
        }
      case 'connector':
      case 'arrow':
      case 'line':
        final endpoints = resolveConnectorEndpoints(element, scene);
        final start = Offset(endpoints.start.x, endpoints.start.y);
        final end = Offset(endpoints.end.x, endpoints.end.y);
        final routing = ConnectorRouting.parse(element.routing);
        final style = ConnectorStyle.parse(element.strokeStyle);
        final startMarker = ConnectorMarker.parse(element.startMarker);
        final endMarker = ConnectorMarker.parse(
          element.endMarker,
          defaultMarker: (element.type == 'arrow' || element.type == 'connector'
              ? ConnectorMarker.arrow
              : ConnectorMarker.none),
        );

        final path = Path();
        path.moveTo(start.dx, start.dy);
        if (routing == ConnectorRouting.curved &&
            endpoints.controlPoints.length >= 2) {
          final cp1 = Offset(
            endpoints.controlPoints[0].x,
            endpoints.controlPoints[0].y,
          );
          final cp2 = Offset(
            endpoints.controlPoints[1].x,
            endpoints.controlPoints[1].y,
          );
          path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
        } else if (routing == ConnectorRouting.orthogonal &&
            endpoints.controlPoints.isNotEmpty) {
          for (final cp in endpoints.controlPoints) {
            path.lineTo(cp.x, cp.y);
          }
          path.lineTo(end.dx, end.dy);
        } else {
          path.lineTo(end.dx, end.dy);
        }

        if (style == ConnectorStyle.solid) {
          canvas.drawPath(path, stroke);
        } else {
          final isDashed = style == ConnectorStyle.dashed;
          final dashLen = isDashed ? 8.0 : 1.0;
          final gapLen = isDashed
              ? 5.0
              : math.max(6.0, stroke.strokeWidth * 2.5);
          for (final metric in path.computeMetrics()) {
            var distance = 0.0;
            while (distance < metric.length) {
              final next = math.min(distance + dashLen, metric.length);
              final extract = metric.extractPath(distance, next);
              canvas.drawPath(extract, stroke);
              distance = next + gapLen;
            }
          }
        }

        // Start marker
        if (startMarker != ConnectorMarker.none) {
          final target = endpoints.tangentTarget(atStart: true);
          final firstTarget = Offset(target.x, target.y);
          final startAngle = math.atan2(
            start.dy - firstTarget.dy,
            start.dx - firstTarget.dx,
          );
          final polygon = umlMarkerPolygon(
            startMarker,
            endpoints.start,
            target,
          );
          if (polygon.isNotEmpty) {
            final markerPath = Path()
              ..addPolygon(polygon.map((p) => Offset(p.x, p.y)).toList(), true);
            canvas.drawPath(
              markerPath,
              Paint()
                ..color =
                    (startMarker == ConnectorMarker.filledDiamond ||
                        startMarker == ConnectorMarker.filledTriangle)
                    ? stroke.color
                    : colors.surface,
            );
            canvas.drawPath(markerPath, stroke);
          } else if (startMarker == ConnectorMarker.arrow) {
            final head = math.min(16.0, (firstTarget - start).distance / 3);
            canvas.drawPath(
              Path()
                ..moveTo(
                  start.dx - math.cos(startAngle - 0.48) * head,
                  start.dy - math.sin(startAngle - 0.48) * head,
                )
                ..lineTo(start.dx, start.dy)
                ..lineTo(
                  start.dx - math.cos(startAngle + 0.48) * head,
                  start.dy - math.sin(startAngle + 0.48) * head,
                ),
              stroke,
            );
          } else if (startMarker == ConnectorMarker.dot) {
            canvas.drawCircle(
              start,
              math.max(3.0, stroke.strokeWidth * 1.5 + 2),
              Paint()..color = stroke.color,
            );
          } else if (startMarker == ConnectorMarker.diamond) {
            final dSize = math.max(6.0, stroke.strokeWidth * 2.5 + 4);
            final dPath = Path()
              ..moveTo(
                start.dx - math.cos(startAngle) * dSize,
                start.dy - math.sin(startAngle) * dSize,
              )
              ..lineTo(
                start.dx - math.cos(startAngle + math.pi / 2) * (dSize * 0.55),
                start.dy - math.sin(startAngle + math.pi / 2) * (dSize * 0.55),
              )
              ..lineTo(start.dx, start.dy)
              ..lineTo(
                start.dx - math.cos(startAngle - math.pi / 2) * (dSize * 0.55),
                start.dy - math.sin(startAngle - math.pi / 2) * (dSize * 0.55),
              )
              ..close();
            canvas.drawPath(dPath, Paint()..color = stroke.color);
          }
        }

        // End marker
        if (endMarker != ConnectorMarker.none) {
          final target = endpoints.tangentTarget(atStart: false);
          final lastTarget = Offset(target.x, target.y);
          final endAngle = math.atan2(
            end.dy - lastTarget.dy,
            end.dx - lastTarget.dx,
          );
          final polygon = umlMarkerPolygon(endMarker, endpoints.end, target);
          if (polygon.isNotEmpty) {
            final markerPath = Path()
              ..addPolygon(polygon.map((p) => Offset(p.x, p.y)).toList(), true);
            canvas.drawPath(
              markerPath,
              Paint()
                ..color =
                    (endMarker == ConnectorMarker.filledDiamond ||
                        endMarker == ConnectorMarker.filledTriangle)
                    ? stroke.color
                    : colors.surface,
            );
            canvas.drawPath(markerPath, stroke);
          } else if (endMarker == ConnectorMarker.arrow) {
            final head = math.min(16.0, (end - lastTarget).distance / 3);
            canvas.drawPath(
              Path()
                ..moveTo(
                  end.dx - math.cos(endAngle - 0.48) * head,
                  end.dy - math.sin(endAngle - 0.48) * head,
                )
                ..lineTo(end.dx, end.dy)
                ..lineTo(
                  end.dx - math.cos(endAngle + 0.48) * head,
                  end.dy - math.sin(endAngle + 0.48) * head,
                ),
              stroke,
            );
          } else if (endMarker == ConnectorMarker.dot) {
            canvas.drawCircle(
              end,
              math.max(3.0, stroke.strokeWidth * 1.5 + 2),
              Paint()..color = stroke.color,
            );
          } else if (endMarker == ConnectorMarker.diamond) {
            final dSize = math.max(6.0, stroke.strokeWidth * 2.5 + 4);
            final dPath = Path()
              ..moveTo(
                end.dx - math.cos(endAngle) * dSize,
                end.dy - math.sin(endAngle) * dSize,
              )
              ..lineTo(
                end.dx - math.cos(endAngle + math.pi / 2) * (dSize * 0.55),
                end.dy - math.sin(endAngle + math.pi / 2) * (dSize * 0.55),
              )
              ..lineTo(end.dx, end.dy)
              ..lineTo(
                end.dx - math.cos(endAngle - math.pi / 2) * (dSize * 0.55),
                end.dy - math.sin(endAngle - math.pi / 2) * (dSize * 0.55),
              )
              ..close();
            canvas.drawPath(dPath, Paint()..color = stroke.color);
          }
        }

        for (final label in connectorEndLabels(element, endpoints)) {
          final rect = _rect(label.bounds);
          canvas.drawRect(rect, Paint()..color = colors.surface);
          _text(
            canvas,
            label.text,
            rect.deflate(2),
            color: colors.onSurface,
            size: 12,
            maxLines: 2,
          );
        }

        // Label pill
        if (element.text.trim().isNotEmpty && element.id != editingId) {
          final mid = Offset(endpoints.midpoint.x, endpoints.midpoint.y);
          final tp = textCache.layout(
            element.text.trim(),
            TextStyle(
              color: stroke.color,
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            200,
            2,
          );
          const padH = 6.0;
          const padV = 3.0;
          final pillRect = Rect.fromCenter(
            center: mid,
            width: tp.width + padH * 2,
            height: tp.height + padV * 2,
          );
          final rrect = RRect.fromRectAndRadius(
            pillRect,
            const Radius.circular(5),
          );
          canvas.drawRRect(rrect, Paint()..color = colors.surface);
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = accent.withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
          tp.paint(
            canvas,
            Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2),
          );
        }
      case 'rectangle':
      case 'ellipse':
      case 'diamond':
      case 'frame':
        final fill = Paint()
          ..color = accent.withValues(
            alpha: element.type == 'frame' ? .035 : .08,
          );
        if (element.type == 'ellipse') {
          canvas.drawOval(bounds, fill);
          canvas.drawOval(bounds, stroke);
        } else if (element.type == 'diamond') {
          final path = Path()
            ..moveTo(bounds.center.dx, bounds.top)
            ..lineTo(bounds.right, bounds.center.dy)
            ..lineTo(bounds.center.dx, bounds.bottom)
            ..lineTo(bounds.left, bounds.center.dy)
            ..close();
          canvas.drawPath(path, fill);
          canvas.drawPath(path, stroke);
        } else {
          final rect = RRect.fromRectAndRadius(
            bounds,
            const Radius.circular(10),
          );
          canvas.drawRRect(rect, fill);
          canvas.drawRRect(rect, stroke);
        }
        if (element.text.isNotEmpty && camera.zoom > .3) {
          _text(
            canvas,
            element.text,
            bounds.deflate(14),
            color: colors.onSurface,
            size: 15,
          );
        }
      case 'text':
        if (camera.zoom < .2) return;
        final textElemFont =
            (element.data['fontFamily'] as String?) ?? fontFamily;
        if (CanvasRichText.hasRichFormatting(element.text)) {
          CanvasRichText.draw(
            canvas: canvas,
            text: element.text,
            bounds: bounds.deflate(6),
            accent: accent,
            colors: colors,
            textCache: textCache,
            defaultFontSize: 17.0,
            fontFamily: textElemFont,
          );
        } else {
          _text(
            canvas,
            element.text,
            bounds.deflate(6),
            color: colors.onSurface,
            size: 18,
            customFontFamily: textElemFont,
          );
        }
      case 'sticky':
        final customColorVal = element.data['color'];
        Color stickyAccent = accent;
        if (customColorVal is int) {
          stickyAccent = Color(customColorVal);
        } else if (customColorVal is String &&
            customColorVal.trim().isNotEmpty) {
          final s = customColorVal.trim();
          if (s.startsWith('#') && (s.length == 7 || s.length == 9)) {
            final hex = s.length == 7 ? 'FF${s.substring(1)}' : s.substring(1);
            final val = int.tryParse(hex, radix: 16);
            if (val != null) stickyAccent = Color(val);
          }
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(bounds, const Radius.circular(5)),
          Paint()
            ..color = Color.alphaBlend(
              stickyAccent.withValues(alpha: .23),
              colors.surfaceContainerHigh,
            ),
        );
        canvas.drawRect(
          Rect.fromLTWH(bounds.left, bounds.top, bounds.width, 5),
          Paint()..color = stickyAccent.withValues(alpha: .5),
        );
        if (camera.zoom > .25) {
          final stickyElemFont =
              (element.data['fontFamily'] as String?) ?? fontFamily;
          CanvasRichText.draw(
            canvas: canvas,
            text: element.text,
            bounds: bounds.deflate(16),
            accent: accent,
            colors: colors,
            textCache: textCache,
            defaultFontSize: 16.0,
            fontFamily: stickyElemFont,
          );
        }
      case 'card':
        final referenceFooterHeight =
            element.data['referenceStatus'] is String && bounds.height >= 160
            ? ((element.data['referenceCaption'] is String &&
                      (element.data['referenceCaption'] as String).isNotEmpty)
                  ? 74.0
                  : 36.0)
            : 0.0;
        final hasObjectId =
            element.objectId != null && element.objectId!.isNotEmpty;
        var object = hasObjectId ? objects[element.objectId] : null;
        var missingFragment = false;
        final target = element.data['referenceTarget'];
        if (object != null && target is String) {
          final reference = ObjectReference.parse(target);
          final fragment = reference.id == object.id
              ? resolveDocumentFragment(
                  object.body,
                  reference,
                  latex: object.properties['documentFormat'] == 'latex',
                )
              : null;
          missingFragment = fragment == null;
          object = CanvasObjectReference(
            id: object.id,
            title: object.title,
            typeId: object.typeId,
            properties: object.properties,
            body: fragment == null
                ? 'Missing source block · Open source to repair'
                : fragment.text.replaceFirst(
                    RegExp(r'\s+\^[A-Za-z0-9][A-Za-z0-9_-]*\s*$'),
                    '',
                  ),
          );
        }
        final hasText = element.text.trim().isNotEmpty;
        final isStandalone = !hasObjectId;
        final isUnresolved =
            missingFragment || (hasObjectId && object == null && !hasText);
        final cardElemFont =
            (element.data['fontFamily'] as String?) ?? fontFamily;

        final isCanvas = object?.typeId == 'orbit.canvas';
        final pdfSource = object?.pdfSource;
        final nestedData = element.data['data'] is Map
            ? (element.data['data'] as Map)
            : const {};
        final rawQuote = element.data['quote'] is String
            ? element.data['quote'] as String
            : (nestedData['quote'] is String
                  ? nestedData['quote'] as String
                  : null);
        final rawPage =
            (element.data['page'] as num?)?.toInt() ??
            (nestedData['page'] as num?)?.toInt() ??
            1;
        final rawSourceTitle =
            element.data['sourceTitle'] as String? ??
            (nestedData['sourceTitle'] as String?) ??
            object?.title ??
            'PDF Document';
        final rawSourceId =
            element.data['sourceId'] as String? ??
            (nestedData['sourceId'] as String?) ??
            element.objectId;
        final quoteData = (rawQuote != null && rawQuote.trim().isNotEmpty)
            ? {
                'quote': rawQuote.trim(),
                'page': rawPage,
                'sourceTitle': rawSourceTitle,
                'sourceId': rawSourceId,
                'color': element.color != 0 ? element.color : null,
              }
            : null;
        final effectivePdfSource = pdfSource ?? quoteData;
        final isPdfQuote = effectivePdfSource != null;
        final isPdf = (object?.isPdf ?? false) && !isPdfQuote;
        final isImage = object?.isImage ?? (element.data['contentRef'] != null);
        final isTask =
            object?.typeId == 'orbit.task' || element.data['isTask'] == true;
        final isDone = object?.isCompleted ?? (element.data['isDone'] == true);
        final contentRef =
            element.data['contentRef'] as String? ?? object?.contentRef;

        final viewConfig = element.data['viewConfig'] is Map
            ? Map<String, dynamic>.from(element.data['viewConfig'] as Map)
            : (object?.typeId == 'orbit.view' &&
                      object?.properties['viewConfig'] is Map
                  ? Map<String, dynamic>.from(
                      object!.properties['viewConfig'] as Map,
                    )
                  : null);
        final savedSmartView = object?.properties['smartQuery'] != null
            ? object
            : objects[(viewConfig?['view'] ?? viewConfig?['viewId'])
                  ?.toString()];
        final isDynamicView =
            viewConfig != null ||
            savedSmartView?.viewMemberIds != null ||
            savedSmartView?.viewQueryIssue != null;

        Color stripColor = isUnresolved
            ? colors.error
            : (isDynamicView
                  ? colors.primary
                  : (isDone
                        ? _success
                        : (effectivePdfSource != null
                              ? (effectivePdfSource['color'] is int
                                    ? Color(effectivePdfSource['color'] as int)
                                    : colors.error)
                              : (isPdf ? colors.error : accent))));

        String typeLabel;
        String titleText;
        String bodyText;

        if (isDynamicView) {
          final vt = (viewConfig?['type'] ?? 'SAVED VIEW')
              .toString()
              .toUpperCase();
          typeLabel = 'SAVED VIEW · $vt';
          titleText =
              viewConfig?['title'] as String? ??
              (object?.title.isNotEmpty == true ? object!.title : 'Saved View');
          bodyText = '';
        } else if (effectivePdfSource != null) {
          final page = effectivePdfSource['page'] is int
              ? effectivePdfSource['page'] as int
              : 1;
          final quote = effectivePdfSource['quote'] is String
              ? (effectivePdfSource['quote'] as String).trim()
              : '';
          typeLabel = object?.pdfSource != null
              ? 'PDF HIGHLIGHT · P. $page'
              : 'PDF CITATION · P. $page';
          titleText =
              effectivePdfSource['sourceTitle'] as String? ??
              (object != null && object.title.isNotEmpty
                  ? object.title
                  : (quote.isNotEmpty ? quote : 'PDF Citation'));
          final comment = object != null && object.typeId != 'orbit.file'
              ? object.body.replaceAll(RegExp(r'[#*`\[\]]'), '').trim()
              : '';
          bodyText = quote.isNotEmpty
              ? (comment.isNotEmpty && comment != quote
                    ? '“$quote”\n\n$comment'
                    : '“$quote”')
              : (comment.isNotEmpty ? comment : element.text.trim());
        } else if (object != null) {
          if (object.typeId == 'orbit.file') {
            typeLabel = isPdf
                ? 'PDF DOCUMENT'
                : (isImage
                      ? 'IMAGE ATTACHMENT'
                      : isModelAsset(
                          object.properties['originalName'] as String? ??
                              object.title,
                        )
                      ? '3D MODEL ASSET'
                      : 'ATTACHMENT');
            titleText = object.title.isEmpty ? 'Untitled File' : object.title;
            bodyText = [
              if (object.lifeSummary != null) object.lifeSummary!,
              object.body.replaceAll(RegExp(r'[#*`\[\]]'), '').trim(),
            ].join('\n\n');
            if (isModelAsset(
                  object.properties['originalName'] as String? ?? object.title,
                ) &&
                bodyText.isEmpty) {
              bodyText =
                  'Open to rotate, inspect and view wireframe.\nLinked original asset';
            }
          } else if (object.typeId == 'orbit.task') {
            typeLabel = isDone ? 'TASK (DONE)' : 'TASK';
            titleText = object.title.isEmpty ? 'Untitled Task' : object.title;
            bodyText = [
              if (object.lifeSummary != null) object.lifeSummary!,
              object.body.replaceAll(RegExp(r'[#*`\[\]]'), '').trim(),
            ].join('\n\n');
          } else {
            typeLabel = isCanvas
                ? 'CANVAS BOARD'
                : object.typeId.replaceFirst('orbit.', '').toUpperCase();
            titleText = object.title.isEmpty ? 'Untitled' : object.title;
            bodyText = [
              if (object.lifeSummary != null) object.lifeSummary!,
              object.body.replaceAll(RegExp(r'[#*`\[\]]'), '').trim(),
            ].join('\n\n');
          }
        } else if (hasText) {
          typeLabel = 'CARD';
          final lines = element.text.trim().split('\n');
          titleText = lines.first.trim();
          bodyText = lines.length > 1 ? lines.skip(1).join('\n').trim() : '';
        } else if (isStandalone) {
          typeLabel = 'CARD';
          titleText = 'Card';
          bodyText = '';
        } else {
          typeLabel = 'UNRESOLVED REFERENCE';
          titleText = 'Missing object';
          bodyText = element.objectId ?? '';
        }

        final presentation =
            element.data['presentation'] as String? ??
            (bounds.height <= 95 ? 'compact' : 'card');

        final card = RRect.fromRectAndRadius(bounds, const Radius.circular(12));
        canvas.drawRRect(card, Paint()..color = colors.surfaceContainerHigh);
        canvas.drawRRect(
          card,
          Paint()
            ..color = colors.outlineVariant.withValues(alpha: .55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );

        if (presentation == 'compact') {
          // Compact single-line presentation
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                bounds.left + 12,
                bounds.top + (bounds.height - 18) / 2,
                4,
                18,
              ),
              const Radius.circular(2),
            ),
            Paint()..color = stripColor,
          );
          double contentLeft = bounds.left + 22;
          if (isTask) {
            final cbRect = Rect.fromLTWH(
              contentLeft,
              bounds.top + (bounds.height - 16) / 2,
              16,
              16,
            );
            _drawCheckbox(canvas, cbRect, isDone, stripColor, colors);
            contentLeft += 22;
          }
          final rightBadgeWidth = isDone ? 54.0 : 64.0;
          final titleWidth = math.max(
            1.0,
            bounds.right - contentLeft - rightBadgeWidth - 14,
          );
          _text(
            canvas,
            titleText,
            Rect.fromLTWH(
              contentLeft,
              bounds.top + (bounds.height - 18) / 2,
              titleWidth,
              18,
            ),
            color: isDone ? colors.onSurfaceVariant : colors.onSurface,
            size: 13,
            weight: FontWeight.w600,
            maxLines: 1,
            strikeThrough: isDone,
          );
          _drawBadge(
            canvas,
            isDone
                ? 'DONE'
                : (isTask
                      ? 'TASK'
                      : (isPdfQuote
                            ? 'CITATION'
                            : (isPdf ? 'PDF' : typeLabel))),
            Rect.fromLTWH(
              bounds.right - rightBadgeWidth - 12,
              bounds.top + (bounds.height - 18) / 2,
              rightBadgeWidth,
              18,
            ),
            textColor: isDone
                ? _success
                : (isPdfQuote
                      ? stripColor
                      : (isPdf ? colors.error : colors.onSurfaceVariant)),
            bgColor: isDone
                ? (semanticColors?.tinted(_success) ?? colors.tertiaryContainer)
                : (isPdfQuote
                      ? stripColor.withValues(alpha: 0.14)
                      : (isPdf
                            ? (semanticColors?.tinted(colors.error) ??
                                  colors.errorContainer)
                            : colors.surfaceContainerHighest)),
          );
        } else if (presentation == 'properties') {
          // Selected-properties presentation
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(bounds.left + 16, bounds.top + 16, 5, 18),
              const Radius.circular(2),
            ),
            Paint()..color = stripColor,
          );
          _text(
            canvas,
            typeLabel,
            Rect.fromLTWH(
              bounds.left + 30,
              bounds.top + 18,
              math.max(1, bounds.width - 46),
              18,
            ),
            color: (isCanvas || effectivePdfSource != null)
                ? stripColor
                : (isUnresolved ? colors.error : colors.onSurfaceVariant),
            size: 10,
            weight: FontWeight.w600,
            maxLines: 1,
          );
          _text(
            canvas,
            titleText,
            Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 42,
              math.max(1, bounds.width - 32),
              22,
            ),
            color: colors.onSurface,
            size: 14,
            weight: FontWeight.w600,
            maxLines: 1,
          );
          final dividerY = bounds.top + 68;
          canvas.drawLine(
            Offset(bounds.left + 16, dividerY),
            Offset(bounds.right - 16, dividerY),
            Paint()
              ..color = colors.outlineVariant.withValues(alpha: 0.4)
              ..strokeWidth = 1,
          );
          double currentY = dividerY + 10;
          final propList = <(String, String)>[];
          if (isTask) {
            propList.add(('Status', isDone ? 'Completed' : 'Open'));
          }
          if (object?.priority != null) {
            propList.add(('Priority', object!.priority!));
          }
          if (object?.project != null) {
            propList.add(('Project', object!.project!));
          }
          if (object?.folder != null) {
            propList.add(('Folder', object!.folder!));
          }
          if (object?.tags.isNotEmpty ?? false) {
            propList.add(('Tags', object!.tags.map((t) => '#$t').join(' ')));
          }
          if (object?.dueDate != null) {
            propList.add(('Due', object!.dueDate!));
          }
          if (effectivePdfSource != null) {
            propList.add(('Page', '${effectivePdfSource['page'] ?? 1}'));
          }
          if (isPdf) {
            propList.add(('Format', 'PDF Document'));
          }
          if (isImage) {
            propList.add(('Type', 'Image File'));
          }
          if (propList.isEmpty) {
            propList.add((
              'Identity',
              object?.id.substring(0, math.min(8, object.id.length)) ?? 'Local',
            ));
          }

          for (final prop in propList.take(5)) {
            if (currentY + 20 > bounds.bottom - 8) break;
            _text(
              canvas,
              '${prop.$1}:',
              Rect.fromLTWH(bounds.left + 16, currentY, 64, 16),
              color: colors.onSurfaceVariant,
              size: 11,
              weight: FontWeight.w500,
              maxLines: 1,
            );
            _text(
              canvas,
              prop.$2,
              Rect.fromLTWH(
                bounds.left + 84,
                currentY,
                math.max(1, bounds.width - 100),
                16,
              ),
              color: colors.onSurface,
              size: 11,
              weight: FontWeight.w600,
              maxLines: 1,
            );
            currentY += 20;
          }
        } else if (presentation == 'preview') {
          // Expanded preview presentation
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(bounds.left + 16, bounds.top + 14, 5, 18),
              const Radius.circular(2),
            ),
            Paint()..color = stripColor,
          );
          _text(
            canvas,
            typeLabel,
            Rect.fromLTWH(
              bounds.left + 30,
              bounds.top + 16,
              math.max(1, bounds.width - 46),
              18,
            ),
            color: (isCanvas || effectivePdfSource != null)
                ? stripColor
                : (isUnresolved ? colors.error : colors.onSurfaceVariant),
            size: 10,
            weight: FontWeight.w600,
            maxLines: 1,
          );

          double titleTop = bounds.top + 38;
          double titleLeft = bounds.left + 16;
          if (isTask) {
            _drawCheckbox(
              canvas,
              Rect.fromLTWH(titleLeft, titleTop + 2, 20, 20),
              isDone,
              stripColor,
              colors,
            );
            titleLeft += 26;
          }
          _text(
            canvas,
            titleText,
            Rect.fromLTWH(
              titleLeft,
              titleTop,
              math.max(1, bounds.right - titleLeft - 16),
              24,
            ),
            color: isDone ? colors.onSurfaceVariant : colors.onSurface,
            size: 15,
            weight: FontWeight.w600,
            maxLines: 1,
            strikeThrough: isDone,
          );

          final previewArea = Rect.fromLTWH(
            bounds.left + 16,
            bounds.top + 68,
            math.max(1, bounds.width - 32),
            math.max(1, bounds.height - 78 - referenceFooterHeight),
          );

          if (isImage && contentRef != null && images.containsKey(contentRef)) {
            final img = images[contentRef]!;
            final imgRRect = RRect.fromRectAndRadius(
              previewArea,
              const Radius.circular(8),
            );
            canvas.save();
            canvas.clipRRect(imgRRect);
            paintImage(
              canvas: canvas,
              rect: previewArea,
              image: img,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            );
            canvas.restore();
            canvas.drawRRect(
              imgRRect,
              Paint()
                ..color = colors.outlineVariant.withValues(alpha: 0.4)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1,
            );
          } else if (isImage) {
            final phRRect = RRect.fromRectAndRadius(
              previewArea,
              const Radius.circular(8),
            );
            canvas.drawRRect(
              phRRect,
              Paint()
                ..color = colors.surfaceContainerHighest.withValues(alpha: 0.5),
            );
            _text(
              canvas,
              'Image Preview',
              Rect.fromLTWH(
                previewArea.left + 12,
                previewArea.top + (previewArea.height - 18) / 2,
                previewArea.width - 24,
                18,
              ),
              color: colors.onSurfaceVariant,
              size: 12,
              weight: FontWeight.w500,
            );
          } else if (effectivePdfSource != null) {
            final quoteRRect = RRect.fromRectAndRadius(
              previewArea,
              const Radius.circular(6),
            );
            canvas.drawRRect(
              quoteRRect,
              Paint()..color = stripColor.withValues(alpha: 0.08),
            );
            canvas.drawLine(
              Offset(previewArea.left, previewArea.top),
              Offset(previewArea.left, previewArea.bottom),
              Paint()
                ..color = stripColor
                ..strokeWidth = 3,
            );
            _drawBadge(
              canvas,
              'PAGE ${effectivePdfSource['page'] ?? 1}',
              Rect.fromLTWH(previewArea.left + 10, previewArea.top + 8, 62, 16),
              textColor: stripColor,
              bgColor: stripColor.withValues(alpha: 0.16),
            );
            final quoteBodyRect = Rect.fromLTWH(
              previewArea.left + 10,
              previewArea.top + 28,
              previewArea.width - 20,
              math.max(1, previewArea.height - 34),
            );
            _text(
              canvas,
              bodyText,
              quoteBodyRect,
              color: colors.onSurface,
              size: 11,
              maxLines: 4,
            );
          } else if (isDynamicView) {
            final vType = viewConfig?['type'] ?? 'tasks';
            if (savedSmartView?.viewMemberIds != null ||
                savedSmartView?.viewQueryIssue != null) {
              final ids = savedSmartView?.viewMemberIds ?? const <String>[];
              _text(
                canvas,
                savedSmartView?.viewQueryIssue ??
                    '${ids.length} matching objects',
                Rect.fromLTWH(
                  previewArea.left,
                  previewArea.top,
                  previewArea.width,
                  28,
                ),
                color: colors.onSurfaceVariant,
                size: 10,
                maxLines: 2,
              );
              var itemY = previewArea.top + 30;
              for (final id in ids.take(4)) {
                final row = objects[id];
                if (row == null || itemY + 18 > previewArea.bottom) continue;
                _text(
                  canvas,
                  row.title,
                  Rect.fromLTWH(previewArea.left, itemY, previewArea.width, 18),
                  color: colors.onSurface,
                  size: 11,
                  maxLines: 1,
                );
                itemY += 20;
              }
            } else if (vType == 'tasks') {
              var tasks = objects.values
                  .where((o) => o.typeId == 'orbit.task')
                  .toList();
              final statusFilter = viewConfig?['status'] as String? ?? 'all';
              if (statusFilter == 'open') {
                tasks = tasks.where((t) => !t.isCompleted).toList();
              } else if (statusFilter == 'completed') {
                tasks = tasks.where((t) => t.isCompleted).toList();
              }
              final totalTasks = objects.values
                  .where((o) => o.typeId == 'orbit.task')
                  .length;
              final doneTasks = objects.values
                  .where((o) => o.typeId == 'orbit.task' && o.isCompleted)
                  .length;
              final pct = totalTasks > 0 ? (doneTasks / totalTasks) : 0.0;

              _text(
                canvas,
                '$doneTasks of $totalTasks completed (${(pct * 100).toInt()}%)',
                Rect.fromLTWH(
                  previewArea.left,
                  previewArea.top,
                  previewArea.width,
                  16,
                ),
                color: colors.onSurfaceVariant,
                size: 10,
                weight: FontWeight.w600,
              );
              _drawProgressBar(
                canvas,
                Rect.fromLTWH(
                  previewArea.left,
                  previewArea.top + 18,
                  previewArea.width,
                  5,
                ),
                pct,
                barColor: colors.primary,
                bgColor: colors.outlineVariant.withValues(alpha: 0.3),
              );
              double itemY = previewArea.top + 28;
              for (final task in tasks.take(3)) {
                if (itemY + 18 > previewArea.bottom) break;
                _drawCheckbox(
                  canvas,
                  Rect.fromLTWH(previewArea.left, itemY, 14, 14),
                  task.isCompleted,
                  colors.primary,
                  colors,
                );
                _text(
                  canvas,
                  task.title.isEmpty ? 'Untitled task' : task.title,
                  Rect.fromLTWH(
                    previewArea.left + 20,
                    itemY,
                    math.max(1, previewArea.width - 24),
                    16,
                  ),
                  color: task.isCompleted
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                  size: 11,
                  maxLines: 1,
                  strikeThrough: task.isCompleted,
                );
                itemY += 20;
              }
            } else {
              final notes = objects.values
                  .where(
                    (o) => o.typeId != 'orbit.file' && o.typeId != 'orbit.task',
                  )
                  .take(4);
              double itemY = previewArea.top;
              for (final note in notes) {
                if (itemY + 18 > previewArea.bottom) break;
                canvas.drawCircle(
                  Offset(previewArea.left + 4, itemY + 8),
                  3,
                  Paint()..color = colors.primary,
                );
                _text(
                  canvas,
                  note.title.isEmpty ? 'Untitled note' : note.title,
                  Rect.fromLTWH(
                    previewArea.left + 14,
                    itemY,
                    math.max(1, previewArea.width - 16),
                    16,
                  ),
                  color: colors.onSurface,
                  size: 11,
                  maxLines: 1,
                );
                itemY += 20;
              }
            }
          } else {
            double contentY = previewArea.top;
            if (object?.tags.isNotEmpty ?? false) {
              _drawBadge(
                canvas,
                '#${object!.tags.first}',
                Rect.fromLTWH(previewArea.left, contentY, 60, 16),
                textColor: accent,
                bgColor: accent.withValues(alpha: 0.12),
              );
              contentY += 22;
            }
            if (bodyText.isNotEmpty) {
              final textRect = Rect.fromLTWH(
                previewArea.left,
                contentY,
                previewArea.width,
                math.max(1, previewArea.bottom - contentY),
              );
              if (CanvasRichText.hasRichFormatting(bodyText)) {
                CanvasRichText.draw(
                  canvas: canvas,
                  text: bodyText,
                  bounds: textRect,
                  accent: accent,
                  colors: colors,
                  textCache: textCache,
                  defaultFontSize: 11.0,
                  maxLines: 3,
                  fontFamily: cardElemFont,
                );
              } else {
                _text(
                  canvas,
                  bodyText,
                  textRect,
                  color: colors.onSurfaceVariant,
                  size: 11,
                  maxLines: 3,
                  customFontFamily: cardElemFont,
                );
              }
            }
          }
        } else if (presentation == 'transclusion') {
          // Live Embedded Note Block Transclusion (CAN-02, NOTE-07)
          final transBarColor = effectivePdfSource != null
              ? stripColor
              : colors.secondary;
          // Top accent bar
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTWH(
                bounds.left + 1,
                bounds.top + 1,
                bounds.width - 2,
                4,
              ),
              topLeft: const Radius.circular(11),
              topRight: const Radius.circular(11),
            ),
            Paint()..color = transBarColor,
          );

          // Header: Live Transclusion badge and note reference link
          final badgeLabel = effectivePdfSource != null
              ? 'PDF CITATION'
              : 'LIVE TRANSCLUSION';
          final badgeWidth = effectivePdfSource != null ? 104.0 : 120.0;
          _drawBadge(
            canvas,
            badgeLabel,
            Rect.fromLTWH(bounds.left + 14, bounds.top + 12, badgeWidth, 18),
            textColor: transBarColor,
            bgColor: transBarColor.withValues(alpha: 0.14),
          );

          final blockId =
              element.data['blockId'] as String? ??
              element.data['blockRef'] as String?;
          final rawRef = element.data['referenceTarget'] is String
              ? element.data['referenceTarget'] as String
              : (nestedData['referenceTarget'] is String
                    ? nestedData['referenceTarget'] as String
                    : null);
          final targetRef = rawRef != null
              ? '[[$rawRef]]'
              : effectivePdfSource != null
              ? '[[$titleText · p. ${effectivePdfSource['page'] ?? 1}]]'
              : blockId != null && blockId.isNotEmpty
              ? '[[$titleText#^$blockId]]'
              : '[[$titleText]]';
          final refWidth = math.max(1.0, bounds.width - badgeWidth - 42);
          _text(
            canvas,
            targetRef,
            Rect.fromLTWH(
              bounds.left + badgeWidth + 22,
              bounds.top + 12,
              refWidth,
              18,
            ),
            color: colors.primary,
            size: 11.5,
            weight: FontWeight.w600,
            maxLines: 1,
          );

          final dividerY = bounds.top + 36;
          canvas.drawLine(
            Offset(bounds.left + 14, dividerY),
            Offset(bounds.right - 14, dividerY),
            Paint()
              ..color = colors.outlineVariant.withValues(alpha: 0.35)
              ..strokeWidth = 1,
          );

          // Body text extraction
          String rawContent = effectivePdfSource != null
              ? bodyText
              : (object?.body ?? (hasText ? element.text : ''));
          if (effectivePdfSource == null &&
              blockId != null &&
              blockId.isNotEmpty &&
              rawContent.isNotEmpty) {
            final lines = rawContent.split('\n');
            String? matched;
            for (final line in lines) {
              if (line.contains('^$blockId')) {
                matched = line.replaceAll('^$blockId', '').trim();
                break;
              }
            }
            if (matched != null) {
              rawContent = matched;
            }
          }

          final contentTop = dividerY + 8;
          final contentHeight = math.max(1.0, bounds.bottom - contentTop - 26);
          final contentArea = Rect.fromLTWH(
            bounds.left + 14,
            contentTop,
            math.max(1.0, bounds.width - 28),
            contentHeight,
          );
          final maxLines = math.max(1, (contentHeight / 18).floor());

          if (effectivePdfSource != null) {
            final quoteBox = RRect.fromRectAndRadius(
              contentArea,
              const Radius.circular(6),
            );
            canvas.drawRRect(
              quoteBox,
              Paint()..color = stripColor.withValues(alpha: 0.07),
            );
            canvas.drawLine(
              Offset(contentArea.left, contentArea.top),
              Offset(contentArea.left, contentArea.bottom),
              Paint()
                ..color = stripColor
                ..strokeWidth = 3,
            );
            final innerQuoteRect = Rect.fromLTWH(
              contentArea.left + 10,
              contentArea.top + 6,
              math.max(1.0, contentArea.width - 16),
              math.max(1.0, contentArea.height - 12),
            );
            _text(
              canvas,
              bodyText,
              innerQuoteRect,
              color: colors.onSurface,
              size: 11.5,
              maxLines: maxLines,
              customFontFamily: cardElemFont,
            );
          } else if (isUnresolved) {
            _text(
              canvas,
              'Missing referenced note (${element.objectId}).\nRemoving this placement card does not delete an object.',
              contentArea,
              color: colors.error,
              size: 11,
              maxLines: maxLines,
            );
          } else if (rawContent.trim().isEmpty) {
            _text(
              canvas,
              '(Empty note content)',
              contentArea,
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              size: 11.5,
              maxLines: 1,
            );
          } else if (CanvasRichText.hasRichFormatting(rawContent)) {
            CanvasRichText.draw(
              canvas: canvas,
              text: rawContent,
              bounds: contentArea,
              accent: transBarColor,
              colors: colors,
              textCache: textCache,
              defaultFontSize: 11.5,
              maxLines: maxLines,
              fontFamily: cardElemFont,
            );
          } else {
            _text(
              canvas,
              rawContent,
              contentArea,
              color: colors.onSurface,
              size: 11.5,
              maxLines: maxLines,
              customFontFamily: cardElemFont,
            );
          }

          // Footer status line
          final footerRect = Rect.fromLTWH(
            bounds.left + 14,
            bounds.bottom - 20,
            bounds.width - 28,
            14,
          );
          final footerText = isUnresolved
              ? 'Unresolved Reference'
              : (effectivePdfSource != null
                    ? 'Cited from ${effectivePdfSource['sourceTitle'] ?? titleText} · Page ${effectivePdfSource['page'] ?? 1}'
                    : 'Bidirectional sync · ${rawContent.length} chars${blockId != null ? ' · Block ^$blockId' : ''}');
          _text(
            canvas,
            footerText,
            footerRect,
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            size: 9.5,
            weight: FontWeight.w500,
            maxLines: 1,
          );
        } else {
          // Standard card presentation (default)
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(bounds.left + 16, bounds.top + 16, 5, 18),
              const Radius.circular(2),
            ),
            Paint()..color = stripColor,
          );
          _text(
            canvas,
            typeLabel,
            Rect.fromLTWH(
              bounds.left + 30,
              bounds.top + 18,
              math.max(1, bounds.width - 46),
              18,
            ),
            color: (isCanvas || effectivePdfSource != null)
                ? stripColor
                : (isUnresolved ? colors.error : colors.onSurfaceVariant),
            size: 10,
            weight: FontWeight.w600,
            maxLines: 1,
          );

          double titleTop = bounds.top + 46;
          double titleLeft = bounds.left + 16;
          if (isTask) {
            _drawCheckbox(
              canvas,
              Rect.fromLTWH(titleLeft, titleTop + 2, 20, 20),
              isDone,
              stripColor,
              colors,
            );
            titleLeft += 28;
          }
          _text(
            canvas,
            titleText,
            Rect.fromLTWH(
              titleLeft,
              titleTop,
              math.max(1, bounds.right - titleLeft - 16),
              48,
            ),
            color: isDone ? colors.onSurfaceVariant : colors.onSurface,
            size: 16,
            weight: FontWeight.w600,
            maxLines: 2,
            strikeThrough: isDone,
            customFontFamily: cardElemFont,
          );
          if (camera.zoom > .5 && bounds.height > 105 && bodyText.isNotEmpty) {
            final cardBodyRect = Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 98,
              math.max(1, bounds.width - 32),
              math.max(1, bounds.height - 110 - referenceFooterHeight),
            );
            if (CanvasRichText.hasRichFormatting(bodyText)) {
              CanvasRichText.draw(
                canvas: canvas,
                text: bodyText,
                bounds: cardBodyRect,
                accent: accent,
                colors: colors,
                textCache: textCache,
                defaultFontSize: 12.0,
                maxLines: 4,
                fontFamily: cardElemFont,
              );
            } else {
              _text(
                canvas,
                bodyText,
                cardBodyRect,
                color: colors.onSurfaceVariant,
                size: 12,
                maxLines: 4,
                customFontFamily: cardElemFont,
              );
            }
          }
        }
        final referenceStatus = element.data['referenceStatus'];
        if (referenceStatus is String &&
            camera.zoom > .4 &&
            bounds.height >= 160) {
          final caption = element.data['referenceCaption'] is String
              ? element.data['referenceCaption'] as String
              : '';
          final tags = element.data['referenceTags'] is List
              ? (element.data['referenceTags'] as List)
                    .whereType<String>()
                    .take(3)
                    .join(' · ')
              : '';
          final height = caption.isEmpty ? 28.0 : 66.0;
          final panel = Rect.fromLTWH(
            bounds.left + 10,
            bounds.bottom - height - 8,
            math.max(1, bounds.width - 20),
            height,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(panel, const Radius.circular(6)),
            Paint()..color = colors.surfaceContainerHigh,
          );
          if (caption.isNotEmpty) {
            _text(
              canvas,
              caption,
              Rect.fromLTWH(
                panel.left + 4,
                panel.top + 4,
                math.max(1, panel.width - 8),
                36,
              ),
              color: colors.onSurface,
              size: 11,
              maxLines: 2,
              customFontFamily: cardElemFont,
            );
          }
          _text(
            canvas,
            '$referenceStatus${tags.isEmpty ? '' : ' · $tags'}',
            Rect.fromLTWH(
              panel.left + 4,
              panel.bottom - 18,
              math.max(1, panel.width - 8),
              16,
            ),
            color: stripColor,
            size: 10,
            maxLines: 1,
          );
        }
      case 'section':
        if (camera.zoom > .2) {
          final rawText = element.text.trim();
          String title = rawText.isEmpty ? 'SECTION' : rawText;
          if (title.startsWith('### ')) {
            title = title.substring(4);
          } else if (title.startsWith('## ')) {
            title = title.substring(3);
          } else if (title.startsWith('# ')) {
            title = title.substring(2);
          }
          title = title.toUpperCase();

          final fontSize = element.sectionFontSize;
          final strokeWidth = element.sectionStrokeWidth;
          final textHeight = fontSize * 1.5;
          _text(
            canvas,
            title,
            Rect.fromLTWH(bounds.left, bounds.top, bounds.width, textHeight),
            color: accent,
            size: fontSize,
            weight: FontWeight.w700,
            maxLines: 1,
          );
          final lineGap = (fontSize * 0.35 + 1.0).clamp(3.0, 14.0);
          final lineY = bounds.top + textHeight + lineGap;
          canvas.drawLine(
            Offset(bounds.left, lineY),
            Offset(bounds.right, lineY),
            Paint()
              ..color = accent.withValues(alpha: 0.45)
              ..strokeWidth = strokeWidth
              ..strokeCap = StrokeCap.round,
          );
        }
      case 'swatch':
        final swatchCard = RRect.fromRectAndRadius(
          bounds,
          const Radius.circular(10),
        );
        canvas.drawRRect(
          swatchCard,
          Paint()..color = colors.surfaceContainerHigh,
        );
        canvas.drawRRect(
          swatchCard,
          Paint()
            ..color = colors.outlineVariant.withValues(alpha: .4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        final colorHeight = bounds.height * 0.62;
        final colorFill = RRect.fromRectAndCorners(
          Rect.fromLTWH(bounds.left, bounds.top, bounds.width, colorHeight),
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
        );
        canvas.drawRRect(colorFill, Paint()..color = Color(element.color));
        if (camera.zoom > .25) {
          final hex =
              '#${(element.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
          _text(
            canvas,
            hex,
            Rect.fromLTWH(
              bounds.left + 10,
              bounds.top + colorHeight + 8,
              math.max(1, bounds.width - 20),
              16,
            ),
            color: colors.onSurface,
            size: 11,
            weight: FontWeight.w600,
            maxLines: 1,
          );
          if (element.text.isNotEmpty) {
            _text(
              canvas,
              element.text,
              Rect.fromLTWH(
                bounds.left + 10,
                bounds.top + colorHeight + 26,
                math.max(1, bounds.width - 20),
                16,
              ),
              color: colors.onSurfaceVariant,
              size: 10,
              maxLines: 1,
            );
          }
        }
      case 'audio':
        final audioCard = RRect.fromRectAndRadius(
          bounds,
          const Radius.circular(12),
        );
        canvas.drawRRect(
          audioCard,
          Paint()..color = colors.surfaceContainerHigh,
        );
        canvas.drawRRect(
          audioCard,
          Paint()
            ..color = accent.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );

        if (camera.zoom > 0.2) {
          final playRadius = math.min(18.0, bounds.height * 0.22);
          final playCenter = Offset(
            bounds.left + playRadius + 14,
            bounds.top + bounds.height * 0.45,
          );
          canvas.drawCircle(
            playCenter,
            playRadius,
            Paint()..color = accent.withValues(alpha: 0.16),
          );
          canvas.drawCircle(
            playCenter,
            playRadius,
            Paint()
              ..color = accent.withValues(alpha: 0.45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );

          final playPath = Path()
            ..moveTo(
              playCenter.dx - playRadius * 0.3,
              playCenter.dy - playRadius * 0.45,
            )
            ..lineTo(playCenter.dx + playRadius * 0.45, playCenter.dy)
            ..lineTo(
              playCenter.dx - playRadius * 0.3,
              playCenter.dy + playRadius * 0.45,
            )
            ..close();
          canvas.drawPath(playPath, Paint()..color = accent);

          final contentLeft = playCenter.dx + playRadius + 14;
          final contentWidth = math.max(1.0, bounds.right - contentLeft - 14);

          _text(
            canvas,
            element.text.isNotEmpty ? element.text : 'Voice Memo',
            Rect.fromLTWH(contentLeft, bounds.top + 10, contentWidth, 18),
            color: colors.onSurface,
            size: 13,
            weight: FontWeight.w600,
            maxLines: 1,
          );

          final durationStr = element.data['duration']?.toString() ?? '1:45';
          _text(
            canvas,
            'AUDIO • $durationStr',
            Rect.fromLTWH(contentLeft, bounds.top + 28, contentWidth, 14),
            color: accent,
            size: 9.5,
            weight: FontWeight.w600,
            maxLines: 1,
          );

          final waveY = bounds.top + 46;
          final waveHeight = math.max(12.0, bounds.bottom - waveY - 10);
          final waveWidth = contentWidth;
          const barCount = 24;
          final barW = math.max(2.0, (waveWidth / barCount) - 2.5);
          final barGap = (waveWidth - (barCount * barW)) / (barCount - 1);
          final progress = finiteNumber(
            element.data['progress'],
            0.35,
          ).clamp(0.0, 1.0);

          const amplitudes = [
            0.3,
            0.5,
            0.7,
            0.4,
            0.85,
            1.0,
            0.65,
            0.5,
            0.75,
            0.9,
            0.55,
            0.35,
            0.6,
            0.8,
            0.95,
            0.45,
            0.35,
            0.6,
            0.85,
            0.7,
            0.5,
            0.75,
            0.8,
            0.4,
          ];

          for (int i = 0; i < barCount; i++) {
            final bx = contentLeft + i * (barW + barGap);
            final frac = (i + 1) / barCount;
            final isPlayed = frac <= progress;
            final amp = amplitudes[i % amplitudes.length];
            final bH = math.max(3.0, waveHeight * amp);
            final by = waveY + (waveHeight - bH) / 2;

            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(bx, by, barW, bH),
                Radius.circular(barW / 2),
              ),
              Paint()
                ..color = isPlayed
                    ? accent
                    : colors.outlineVariant.withValues(alpha: 0.4),
            );
          }
        }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Rect bounds, {
    required Color color,
    required double size,
    int? maxLines,
    FontWeight? weight,
    bool strikeThrough = false,
    String? customFontFamily,
  }) {
    if (bounds.width <= 0 || bounds.height <= 0) return;
    final painter = textCache.layout(
      text,
      TextStyle(
        fontFamily: customFontFamily ?? fontFamily,
        color: color,
        fontSize: size,
        height: 1.4,
        fontWeight: weight,
        decoration: strikeThrough ? TextDecoration.lineThrough : null,
      ),
      bounds.width,
      maxLines,
    );
    canvas.save();
    canvas.clipRect(bounds);
    painter.paint(canvas, bounds.topLeft);
    canvas.restore();
  }

  void _drawCheckbox(
    Canvas canvas,
    Rect rect,
    bool checked,
    Color accentColor,
    ColorScheme colors,
  ) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    if (checked) {
      canvas.drawRRect(rrect, Paint()..color = accentColor);
      final p1 = Offset(
        rect.left + rect.width * 0.25,
        rect.top + rect.height * 0.52,
      );
      final p2 = Offset(
        rect.left + rect.width * 0.44,
        rect.top + rect.height * 0.72,
      );
      final p3 = Offset(
        rect.left + rect.width * 0.76,
        rect.top + rect.height * 0.30,
      );
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = OrbitContrast.inkOn(accentColor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, rect.width * 0.12)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = colors.surfaceContainerHighest.withValues(alpha: 0.5)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = colors.outline.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawBadge(
    Canvas canvas,
    String text,
    Rect rect, {
    required Color textColor,
    required Color bgColor,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = bgColor);
    _text(
      canvas,
      text,
      Rect.fromLTWH(
        rect.left + 4,
        rect.top + (rect.height - 11) / 2,
        math.max(1, rect.width - 8),
        12,
      ),
      color: textColor,
      size: 9,
      weight: FontWeight.w700,
      maxLines: 1,
    );
  }

  void _drawProgressBar(
    Canvas canvas,
    Rect rect,
    double progress, {
    required Color barColor,
    required Color bgColor,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(rrect, Paint()..color = bgColor);
    if (progress > 0) {
      final fillWidth = (rect.width * progress.clamp(0.0, 1.0)).clamp(
        3.0,
        rect.width,
      );
      final fillRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top, fillWidth, rect.height),
        const Radius.circular(3),
      );
      canvas.drawRRect(fillRRect, Paint()..color = barColor);
    }
  }

  Rect _rect(CanvasBounds bounds) =>
      Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height);
  @override
  bool shouldRepaint(covariant OrbitCanvasPainter oldDelegate) =>
      !identical(scene, oldDelegate.scene) ||
      sceneRevision != oldDelegate.sceneRevision ||
      inkCache != oldDelegate.inkCache ||
      devicePixelRatio != oldDelegate.devicePixelRatio ||
      camera.x != oldDelegate.camera.x ||
      camera.y != oldDelegate.camera.y ||
      camera.zoom != oldDelegate.camera.zoom ||
      !mapEquals(revealProgress, oldDelegate.revealProgress) ||
      forceUmlDetails != oldDelegate.forceUmlDetails ||
      fontFamily != oldDelegate.fontFamily ||
      !setEquals(selection, oldDelegate.selection) ||
      !mapEquals(objects, oldDelegate.objects) ||
      !mapEquals(images, oldDelegate.images) ||
      colors != oldDelegate.colors ||
      semanticColors != oldDelegate.semanticColors ||
      region != oldDelegate.region ||
      !listEquals(lassoPoints, oldDelegate.lassoPoints) ||
      preview != oldDelegate.preview ||
      editingId != oldDelegate.editingId ||
      backgroundStyle != oldDelegate.backgroundStyle ||
      hoveredAnchorElementId != oldDelegate.hoveredAnchorElementId ||
      connectingStartElementId != oldDelegate.connectingStartElementId ||
      transparentBackground != oldDelegate.transparentBackground ||
      !setEquals(exportElementIds, oldDelegate.exportElementIds) ||
      !setEquals(searchMatchIds, oldDelegate.searchMatchIds) ||
      activeSearchMatchId != oldDelegate.activeSearchMatchId ||
      !listEquals(guides, oldDelegate.guides);
}

/// High-fidelity raster PNG export for a [CanvasScene].
Future<Uint8List?> renderCanvasToPng({
  required CanvasScene scene,
  required ColorScheme colors,
  OrbitColors? semanticColors,
  required String backgroundStyle,
  CanvasBounds? bounds,
  Set<String>? elementIds,
  double scale = 2.0,
  bool transparent = false,
  Map<String, ui.Image> images = const {},
  Map<String, CanvasObjectReference> objects = const {},
  String fontFamily = 'Segoe UI',
  bool forceUmlDetails = false,
}) async {
  CanvasBounds exportBounds;
  if (elementIds != null && elementIds.isNotEmpty) {
    CanvasBounds? unionBounds;
    for (final id in elementIds) {
      final elem = scene[id];
      if (elem != null) {
        unionBounds = unionBounds?.union(elem.bounds) ?? elem.bounds;
      }
    }
    exportBounds = (unionBounds ?? const CanvasBounds(0, 0, 800, 600)).inflate(
      40,
    );
  } else if (bounds != null) {
    exportBounds = bounds;
  } else {
    exportBounds = (scene.contentBounds ?? const CanvasBounds(0, 0, 800, 600))
        .inflate(40);
  }

  final width = (exportBounds.width * scale).ceilToDouble().clamp(
    10.0,
    16384.0,
  );
  final height = (exportBounds.height * scale).ceilToDouble().clamp(
    10.0,
    16384.0,
  );

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

  final exportCamera = CanvasCamera(
    x: exportBounds.left,
    y: exportBounds.top,
    zoom: scale,
  );

  final textCache = CanvasTextCache();
  final painter = OrbitCanvasPainter(
    semanticColors: semanticColors,
    scene: scene,
    camera: exportCamera,
    selection: const {},
    objects: objects,
    colors: colors,
    backgroundStyle: backgroundStyle,
    images: images,
    textCache: textCache,
    exportElementIds: elementIds,
    transparentBackground: transparent,
    fontFamily: fontFamily,
    forceUmlDetails: forceUmlDetails,
  );

  ui.Picture? picture;
  ui.Image? img;
  try {
    painter.paint(canvas, Size(width, height));
    picture = recorder.endRecording();
    img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  } finally {
    if (recorder.isRecording) recorder.endRecording().dispose();
    img?.dispose();
    picture?.dispose();
    textCache.dispose();
  }
}
