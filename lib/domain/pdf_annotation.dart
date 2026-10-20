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

  CanvasBounds? boundsForPage(int pageNumber) {
    final pageRegions = regions
        .where((r) => r.data['page'] == pageNumber)
        .toList();
    if (pageRegions.isEmpty) return null;
    var b = CanvasBounds(
      pageRegions.first.x,
      pageRegions.first.y,
      pageRegions.first.width,
      pageRegions.first.height,
    );
    for (var i = 1; i < pageRegions.length; i++) {
      final r = pageRegions[i];
      b = b.union(CanvasBounds(r.x, r.y, r.width, r.height));
    }
    return b;
  }

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
  final _markup = <int, List<PdfMarkupRegion>>{};
  final _comments = <int, List<PdfAnnotation>>{};
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
    for (final entry in markupForPage(page).reversed) {
      final r = entry.region;
      if (x >= r.x && x <= r.x + r.width && y >= r.y && y <= r.y + r.height) {
        return entry.annotation;
      }
    }
    return null;
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
