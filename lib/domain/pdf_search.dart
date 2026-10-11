import 'universal_object.dart';
import 'object_reference.dart';
import 'orbit_search.dart';
import 'ocr_document.dart';

class PdfTextPage {
  const PdfTextPage(this.number, this.text, this.total);
  final int number, total;
  final String text;
}

/// Disposable extracted text, bound to the actual bytes and attachment path.
class PdfTextDocument {
  static const maxTextCharacters = 32 * 1024 * 1024;
  const PdfTextDocument(
    this.path,
    this.checksum,
    this.pages, {
    this.ocr,
    this.ocrPages = const {},
  });
  final OcrDocument? ocr;
  final Set<int> ocrPages;
  final String path, checksum;
  final List<String> pages;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'path': path,
    'checksum': checksum,
    'pages': pages,
  };
  static PdfTextDocument? parse(dynamic raw) {
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['path'] is! String ||
        raw['checksum'] is! String ||
        raw['pages'] is! List ||
        (raw['pages'] as List).isEmpty ||
        !(raw['pages'] as List).every((p) => p is String)) {
      return null;
    }
    var size = 0;
    for (final page in raw['pages'] as List) {
      size += (page as String).length;
      if (size > maxTextCharacters) return null;
    }
    return PdfTextDocument(
      raw['path'] as String,
      raw['checksum'] as String,
      List<String>.unmodifiable(raw['pages'] as List),
    );
  }

  bool get hasText => pages.any((p) => p.trim().isNotEmpty);

  List<OrbitSearchResult> search(UniversalObject object, String query) {
    final needle = query.trim();
    if (needle.isEmpty) return [];
    final pattern = RegExp(
      RegExp.escape(needle),
      caseSensitive: false,
      unicode: true,
    );
    return [
      for (var page = 0; page < pages.length; page++)
        ..._pageMatches(object, page, pattern),
    ];
  }

  Iterable<OrbitSearchResult> _pageMatches(
    UniversalObject object,
    int page,
    RegExp pattern,
  ) sync* {
    final source = pages[page];
    for (final match in pattern.allMatches(source)) {
      final at = match.start;
      final begin = (at - 45).clamp(0, source.length);
      final end = (match.end + 65).clamp(0, source.length);
      final spaces = RegExp(r'\s+');
      final prefix = source.substring(begin, at).replaceAll(spaces, ' ');
      final visibleMatch = source
          .substring(at, match.end)
          .replaceAll(spaces, ' ');
      yield OrbitSearchResult(
        object: object,
        location: ObjectReference(object.id, page: page + 1),
        matchKind: ocrPages.contains(page) ? 'Recognized text' : 'PDF text',
        score: 60,
        sourceOffset: at,
        matchLength: match.end - match.start,
        matchedText: source.substring(begin, end).replaceAll(spaces, ' '),
        excerptOffset: prefix.length,
        excerptLength: visibleMatch.length,
        sourceChecksum: checksum,
        sourcePath: path,
        sourceRegions: ocrPages.contains(page)
            ? ocr?.regions(page, at, match.end) ?? const []
            : const [],
      );
    }
  }
}

class PdfIndexEntry {
  const PdfIndexEntry(
    this.phase, {
    this.pages = 0,
    this.total = 0,
    this.unsearchablePages = 0,
    this.detail,
  });
  final String phase;
  final int pages, total, unsearchablePages;
  final String? detail;
}
