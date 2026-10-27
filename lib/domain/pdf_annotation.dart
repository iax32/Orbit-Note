import '../canvas/geometry.dart';
import '../canvas/scene.dart';
import 'universal_object.dart';
import 'object_reference.dart';

/// Versioned text regions reuse Canvas rectangles in normalized page space.
class PdfAnnotation {
  PdfAnnotation(this.object);
  final UniversalObject object;
  Map get source => object.properties['pdfSource'] is Map
      ? object.properties['pdfSource'] as Map
      : const {};
  String? get checksum =>
      source['checksum'] is String ? source['checksum'] as String : null;
  String? get fileId =>
      source['objectId'] is String ? source['objectId'] as String : null;
  bool get isPageComment => source['kind'] == 'pageComment';
  bool get resolved =>
      object.properties['pdfReview'] is Map &&
      (object.properties['pdfReview'] as Map)['version'] == 1 &&
      (object.properties['pdfReview'] as Map)['resolved'] == true;
  int get page => source['page'] is int ? source['page'] as int : 1;
  int get pageNumber => page;
  String get quote =>
      source['quote'] is String ? source['quote'] as String : '';
  String get note => object.body.trim();
  // UniversalObject freezes its source tree. Decode geometry once per snapshot,
  // rather than allocating maps repeatedly inside every page paint/drag frame.
  late final List<CanvasElement> regions = source['regions'] is List
      ? List<CanvasElement>.unmodifiable(
          (source['regions'] as List)
              .whereType<Map>()
              .map((v) => CanvasElement(Map<String, dynamic>.from(v)))
              .where(validRegion)
              .toList(),
        )
      : const [];

  int get color {
    if (regions.isNotEmpty) {
      final c = regions.first.color;
      if (c != 0) return c;
    }
    return 0xff8b7cf6;
  }

  String get style {
    if (regions.isNotEmpty) {
      final s = regions.first.data['style'];
      if (s is String &&
          (s == 'underline' || s == 'strikeout' || s == 'highlight')) {
        return s;
      }
    }
    return 'highlight';
  }

  late final Map<int, CanvasBounds> _pageBounds = () {
    final result = <int, CanvasBounds>{};
    for (final region in regions) {
      final page = region.data['page'] as int;
      result[page] = result[page]?.union(region.bounds) ?? region.bounds;
    }
    return Map<int, CanvasBounds>.unmodifiable(result);
  }();

  CanvasBounds? boundsForPage(int pageNumber) => _pageBounds[pageNumber];

  String summaryMarkdown(String pdfTitle) {
    final quote = source['quote'] is String ? source['quote'] as String : '';
    final comment = object.body.trim();
    final buffer = StringBuffer();
    final reference = ObjectReference(fileId ?? pdfTitle, page: page);
    buffer.writeln(reference.markdown(pdfTitle));
    // Existing annotation notes already contain the quote and source link. Keep
    // their authored body once instead of duplicating the quote in each digest.
    final quoted = quote.split('\n').map((line) => '> $line').join('\n');
    if (quote.isNotEmpty && !comment.contains(quoted)) buffer.writeln(quoted);
    if (comment.isNotEmpty && comment != quote) buffer.writeln(comment);
    return buffer.toString();
  }

  bool matches(String? version) => version != null && checksum == version;
  static bool validRegion(CanvasElement e) =>
      e.renderable &&
      e.type == 'rectangle' &&
      e.data['page'] is int &&
      (e.data['page'] as int) > 0 &&
      (e.data['page'] as int) <= 999999 &&
      e.x >= 0 &&
      e.y >= 0 &&
      e.width > 0 &&
      e.height > 0 &&
      e.x + e.width <= 1.000001 &&
      e.y + e.height <= 1.000001;
  static bool isAnnotation(UniversalObject o) =>
      !o.isDeleted &&
      o.typeId == 'orbit.note' &&
      o.properties['pdfHighlightVersion'] == 1;
}

typedef PdfMarkupRegion = ({PdfAnnotation annotation, CanvasElement region});

/// Disposable page lookup; authored notes and their shared Canvas geometry stay
/// authoritative. Rebuilding wrappers for the same immutable objects is a no-op.
class PdfAnnotationIndex {
  PdfAnnotationIndex(
    List<PdfAnnotation> annotations,
    this.fileId,
    this.checksum, {
    PdfAnnotationIndex? previous,
  }) : _sources = List.of(annotations) {
    final reuse = previous?.fileId == fileId && previous?.checksum == checksum
        ? previous?._decoded
        : null;
    for (final incoming in annotations) {
      if (!PdfAnnotation.isAnnotation(incoming.object) ||
          incoming.fileId != fileId ||
          !incoming.matches(checksum)) {
        continue;
      }
      final cached = reuse?[incoming.object.id];
      final annotation = identical(cached?.object, incoming.object)
          ? cached!
          : incoming;
      _decoded[annotation.object.id] = annotation;
      _paintOrder[annotation.object.id] = _paintOrder.length;
      if (annotation.isPageComment) {
        for (final page
            in annotation.regions.map((r) => r.data['page'] as int).toSet()) {
          (_comments[page] ??= []).add(annotation);
        }
      } else {
        for (final region in annotation.regions) {
          (_markup[region.data['page'] as int] ??= []).add((
            annotation: annotation,
            region: region,
          ));
        }
      }
    }
    for (final page in _markup.keys.toList()) {
      _markup[page] = List.unmodifiable(_markup[page]!);
    }
    for (final page in _comments.keys.toList()) {
      _comments[page] = List.unmodifiable(_comments[page]!);
    }
  }
  final String fileId;
  final String? checksum;
  final List<PdfAnnotation> _sources;
  final _decoded = <String, PdfAnnotation>{};
  final _paintOrder = <String, int>{};
  final _markup = <int, List<PdfMarkupRegion>>{};
  final _comments = <int, List<PdfAnnotation>>{};
  // Build only for dense pages actually clicked, retaining at most 16 pages.
  // Each region appears in intersected vertical bands in original paint order.
  final _hitBands = <int, List<List<PdfMarkupRegion>>>{};
  List<PdfMarkupRegion> markupForPage(int page) => _markup[page] ?? const [];
  List<PdfAnnotation> commentsForPage(int page) => _comments[page] ?? const [];
  bool matches(List<PdfAnnotation> annotations, String id, String? version) =>
      id == fileId &&
      version == checksum &&
      annotations.length == _sources.length &&
      Iterable<int>.generate(
        annotations.length,
      ).every((i) => identical(annotations[i].object, _sources[i].object));
  PdfAnnotation? hitTest(int page, double x, double y) {
    return _hits(page, x, y, firstOnly: true).firstOrNull;
  }

  List<PdfAnnotation> hitTests(
    int page,
    double x,
    double y, {
    double toleranceX = 0,
    double toleranceY = 0,
  }) => _hits(page, x, y, toleranceX: toleranceX, toleranceY: toleranceY);

  List<PdfAnnotation> _hits(
    int page,
    double x,
    double y, {
    double toleranceX = 0,
    double toleranceY = 0,
    bool firstOnly = false,
  }) {
    if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
      return [];
    }
    final tx = toleranceX.isFinite ? toleranceX.clamp(0.0, .1) : 0.0;
    final ty = toleranceY.isFinite ? toleranceY.clamp(0.0, .1) : 0.0;
    var candidates = markupForPage(page);
    if (candidates.length > 128) {
      var bands = _hitBands.remove(page);
      if (bands == null) {
        bands = List.generate(32, (_) => <PdfMarkupRegion>[]);
        for (final entry in candidates) {
          final start = (entry.region.y * 32).floor().clamp(0, 31);
          final end = ((entry.region.y + entry.region.height) * 32)
              .floor()
              .clamp(0, 31);
          for (var i = start; i <= end; i++) {
            bands[i].add(entry);
          }
        }
      }
      _hitBands[page] = bands;
      if (_hitBands.length > 16) _hitBands.remove(_hitBands.keys.first);
      candidates = firstOnly
          ? bands[(y * 32).floor().clamp(0, 31)]
          : bands
                .sublist(
                  ((y - ty) * 32).floor().clamp(0, 31),
                  ((y + ty) * 32).floor().clamp(0, 31) + 1,
                )
                .expand((band) => band)
                .toSet()
                .toList();
    }
    final exact = <PdfAnnotation>[], nearby = <PdfAnnotation>[];
    final seen = <String>{};
    for (final entry in candidates.reversed) {
      final r = entry.region;
      if (x >= r.x && x <= r.x + r.width && y >= r.y && y <= r.y + r.height) {
        if (seen.add(entry.annotation.object.id)) exact.add(entry.annotation);
        if (firstOnly) return exact;
      } else if (x >= r.x - tx &&
          x <= r.x + r.width + tx &&
          y >= r.y - ty &&
          y <= r.y + r.height + ty) {
        nearby.add(entry.annotation);
      }
    }
    int paintOrder(PdfAnnotation a, PdfAnnotation b) =>
        (_paintOrder[b.object.id] ?? 0).compareTo(
          _paintOrder[a.object.id] ?? 0,
        );
    exact.sort(paintOrder);
    nearby.sort(paintOrder);
    for (final a in nearby) {
      if (seen.add(a.object.id)) exact.add(a);
    }
    return exact;
  }
}

String pdfReviewMarkdown(
  String title,
  String fileId,
  List<PdfAnnotation> annotations, {
  String? checksum,
}) {
  var size = title.length;
  for (final a in annotations) {
    final quote = a.source['quote'];
    size +=
        a.object.body.length +
        a.object.title.length +
        (quote is String ? quote.length * 2 : 0) +
        512;
    if (size > 2000000) {
      throw const FormatException('Review too large. Filter to fewer items.');
    }
  }
  final result = StringBuffer('# PDF review\n\n')
    ..writeln(ObjectReference(fileId).markdown(title))
    ..writeln('\n${annotations.length} review items\n');
  for (final annotation in annotations) {
    result.writeln(
      '## ${annotation.resolved ? 'Resolved' : 'Open'} · page ${annotation.page}',
    );
    result.writeln(
      ObjectReference(annotation.object.id).markdown(annotation.object.title),
    );
    if (!annotation.matches(checksum)) {
      result.writeln(
        '\n> Source version differs — verify this annotation against its original PDF.',
      );
    }
    result.writeln('\n${annotation.summaryMarkdown(title)}');
  }
  return result.toString();
}
