import 'dart:convert';

import 'writing_structure.dart';

/// Bibliographic metadata stays in the owning Markdown note, with readable
/// citation fallbacks. No network lookup or external database is required.
class CitationSource {
  const CitationSource({
    required this.id,
    required this.title,
    this.author = '',
    this.year = '',
    this.publisher = '',
    this.doi = '',
    this.isbn = '',
    this.url = '',
  });
  final String id, title, author, year, publisher, doi, isbn, url;
  Map<String, Object> toJson() => {
    'v': 1,
    'id': id,
    'title': title,
    'author': author,
    'year': year,
    'publisher': publisher,
    'doi': doi,
    'isbn': isbn,
    'url': url,
  };
  factory CitationSource.fromJson(Map<String, dynamic> data) {
    if (data['v'] != 1) {
      throw const FormatException('Unsupported source version.');
    }
    String field(String key) => data[key] == null ? '' : data[key] as String;
    final value = CitationSource(
      id: field('id'),
      title: field('title'),
      author: field('author'),
      year: field('year'),
      publisher: field('publisher'),
      doi: field('doi'),
      isbn: field('isbn'),
      url: field('url'),
    );
    value.validate();
    return value;
  }
  void validate() {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id) ||
        title.trim().isEmpty) {
      throw const FormatException(
        'A source needs a valid identifier and title.',
      );
    }
    for (final value in [title, author, year, publisher, doi, isbn, url]) {
      if (value.length > 2000 || RegExp(r'[\x00-\x1f]').hasMatch(value)) {
        throw const FormatException(
          'Source fields must be single lines, at most 2,000 characters.',
        );
      }
    }
    final destination = Uri.tryParse(url);
    if (url.isNotEmpty &&
        (!['https', 'http'].contains(destination?.scheme) ||
            destination!.host.isEmpty)) {
      throw const FormatException('Source URLs must use HTTP or HTTPS.');
    }
  }

  String get label =>
      '${author.isEmpty ? title : author}, ${year.isEmpty ? 'n.d.' : year}';
  String get description => [
    author,
    year.isEmpty ? '' : '($year)',
    title,
    publisher,
    doi.isEmpty ? '' : 'DOI: $doi',
    isbn.isEmpty ? '' : 'ISBN: $isbn',
    url,
  ].where((s) => s.isNotEmpty).join('. ');
  String get marker => '<!-- orbit:source ${_json(toJson())} -->';
}

String _json(Object data) =>
    jsonEncode(data).replaceAll('<', r'\u003c').replaceAll('>', r'\u003e');
String _text(String value) =>
    value.replaceAllMapped(RegExp(r'[\\`*_\[\]<>]'), (m) => '\\${m[0]}');

class CitationOccurrence {
  const CitationOccurrence(this.start, this.end, this.id, this.locator);
  final int start, end;
  final String id, locator;
}

class DocumentCitations {
  DocumentCitations(this.source) {
    final literal = [
      ...writingLiteralRanges(source),
      ...codeSpanRanges(source),
      for (final line in RegExp(
        r'^(?: {4}|\t)[^\n]*(?:\n|$)',
        multiLine: true,
      ).allMatches(source))
        (line.start - 1, line.end),
    ];
    bool protected(int at) => literal.any((r) => at > r.$1 && at < r.$2);
    for (final match in RegExp(
      r'<!-- orbit:source ([^\r\n]*?) -->',
    ).allMatches(source)) {
      if (protected(match.start)) continue;
      try {
        final raw = jsonDecode(match[1]!) as Map<String, dynamic>;
        final item = CitationSource.fromJson(raw);
        if (sources.containsKey(item.id)) {
          warnings.add(
            'Duplicate source identifier: ${item.id}. Repair it in Source before editing metadata.',
          );
          duplicates.add(item.id);
        } else {
          sources[item.id] = item;
          _sourceRanges[item.id] = (match.start, match.end, raw);
        }
      } catch (_) {
        warnings.add('Unrecognized source metadata is preserved.');
      }
    }
    for (final match in RegExp(
      r'<!-- orbit:cite ([^\r\n]*?) -->([\s\S]*?)<!-- /orbit:cite -->',
    ).allMatches(source)) {
      if (protected(match.start)) continue;
      try {
        final data = jsonDecode(match[1]!) as Map<String, dynamic>;
        final id = data['id'] as String,
            locator = data['locator'] as String? ?? '';
        if (data['v'] != 1 ||
            !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id) ||
            locator.length > 200 ||
            locator.contains(RegExp(r'[\r\n]')) ||
            match[2]!.contains('<!--')) {
          throw const FormatException();
        }
        occurrences.add(
          CitationOccurrence(match.start, match.end, id, locator),
        );
        if (!sources.containsKey(id)) {
          warnings.add('Missing citation source: $id');
        }
      } catch (_) {
        warnings.add('Unrecognized citation is preserved.');
      }
    }
  }
  final String source;
  final sources = <String, CitationSource>{};
  final duplicates = <String>{};
  final warnings = <String>[];
  final occurrences = <CitationOccurrence>[];
  final _sourceRanges = <String, (int, int, Map<String, dynamic>)>{};
  static const bibliographyEnd = '<!-- /orbit:bibliography -->';
  static bool metadataLine(String line) {
    final value = line.trim();
    if (value.startsWith('<!-- orbit:source ')) {
      return DocumentCitations(value).sources.isNotEmpty;
    }
    return value == bibliographyEnd ||
        RegExp(
          r'^<!-- orbit:bibliography v=1 style=(?:numbered|author-year) -->$',
        ).hasMatch(value);
  }

  bool get numbered {
    final literal = [
      ...writingLiteralRanges(source),
      ...codeSpanRanges(source),
    ];
    return RegExp(
          r'<!-- orbit:bibliography v=1 style=numbered -->[\s\S]*?<!-- /orbit:bibliography -->',
        )
        .allMatches(source)
        .any((m) => !literal.any((r) => m.start > r.$1 && m.start < r.$2));
  }

  String save(CitationSource item) {
    item.validate();
    return saveRecord(item.toJson());
  }

  Map<String, dynamic> record(String id) => {...?_sourceRanges[id]?.$3};

  String saveRecord(Map<String, dynamic> record) {
    final item = CitationSource.fromJson(record);
    if (duplicates.contains(item.id)) {
      throw const FormatException(
        'Duplicate source identifier; metadata was not changed.',
      );
    }
    final range = _sourceRanges[item.id];
    if (range == null) {
      writingLiteralRanges(source, requireClosed: true);
      return '$source\n\n<!-- orbit:source ${_json(record)} -->\n';
    }
    final merged = {...range.$3, ...record};
    return source.replaceRange(
      range.$1,
      range.$2,
      '<!-- orbit:source ${_json(merged)} -->',
    );
  }

  String saveRecords(List<Map<String, dynamic>> records) {
    final seen = <String>{};
    final edits = <(int, int, String)>[];
    final appended = <String>[];
    for (final record in records) {
      final item = CitationSource.fromJson(record);
      if (!seen.add(item.id) || duplicates.contains(item.id)) {
        throw FormatException('Duplicate source identifier: ${item.id}.');
      }
      final range = _sourceRanges[item.id];
      final marker =
          '<!-- orbit:source ${_json({...?range?.$3, ...record})} -->';
      if (range == null) {
        appended.add(marker);
      } else {
        edits.add((range.$1, range.$2, marker));
      }
    }
    if (appended.isNotEmpty) writingLiteralRanges(source, requireClosed: true);
    edits.sort((a, b) => b.$1.compareTo(a.$1));
    var next = source;
    for (final edit in edits) {
      next = next.replaceRange(edit.$1, edit.$2, edit.$3);
    }
    if (appended.isNotEmpty) next = '$next\n\n${appended.join('\n')}\n';
    return next;
  }

  String remove(String id) {
    if (duplicates.contains(id) || occurrences.any((c) => c.id == id)) {
      throw const FormatException(
        'Remove this source’s citations before deleting its metadata.',
      );
    }
    final range = _sourceRanges[id];
    return range == null ? source : source.replaceRange(range.$1, range.$2, '');
  }

  bool canInsert(int start, int end) {
    if (start < 0 || end < start || end > source.length) return false;
    final protected = [
      ...writingLiteralRanges(source),
      ...codeSpanRanges(source),
      for (final cite in occurrences) (cite.start, cite.end),
      for (final line in RegExp(
        r'^(?: {4}|\t)[^\n]*(?:\n|$)',
        multiLine: true,
      ).allMatches(source))
        (line.start - 1, line.end),
      for (final block in RegExp(
        r'<!-- orbit:bibliography[^\r\n]*-->[\s\S]*?<!-- /orbit:bibliography -->',
      ).allMatches(source))
        (block.start, block.end),
    ];
    return !protected.any(
      (r) => start == end
          ? start > r.$1 && start < r.$2
          : start < r.$2 && end > r.$1,
    );
  }

  static String citation(CitationSource item, String locator) {
    item.validate();
    if (locator.length > 200 || locator.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException(
        'Locator must be a single line, at most 200 characters.',
      );
    }
    return '<!-- orbit:cite ${_json({'v': 1, 'id': item.id, 'locator': locator})} -->'
        '(${_text(item.label)}${locator.isEmpty ? '' : ', ${_text(locator)}'})<!-- /orbit:cite -->';
  }

  /// Updates only recognized generated regions. Unknown extensions remain intact.
  String refresh({bool? numberedStyle, bool addBibliography = true}) {
    final numbered = numberedStyle ?? this.numbered;
    final used = occurrences
        .map((c) => c.id)
        .where(sources.containsKey)
        .toSet()
        .toList();
    if (!numbered) {
      used.sort(
        (a, b) => sources[a]!.description.toLowerCase().compareTo(
          sources[b]!.description.toLowerCase(),
        ),
      );
    }
    var next = source;
    for (final cite in occurrences.reversed) {
      final item = sources[cite.id];
      if (item == null || duplicates.contains(cite.id)) continue;
      final label = numbered
          ? '[${used.indexOf(cite.id) + 1}${cite.locator.isEmpty ? '' : ', ${_text(cite.locator)}'}]'
          : '(${_text(item.label)}${cite.locator.isEmpty ? '' : ', ${_text(cite.locator)}'})';
      final markerEnd = source.indexOf('-->', cite.start) + 3;
      next = next.replaceRange(
        cite.start,
        cite.end,
        '${source.substring(cite.start, markerEnd)}$label<!-- /orbit:cite -->',
      );
    }
    final literal = writingLiteralRanges(next);
    final blocks =
        RegExp(
              r'<!-- orbit:bibliography v=1 style=(?:numbered|author-year) -->[\s\S]*?<!-- /orbit:bibliography -->',
            )
            .allMatches(next)
            .where((m) => !literal.any((r) => m.start > r.$1 && m.start < r.$2))
            .toList();
    if (blocks.length > 1) {
      throw const FormatException(
        'Multiple generated bibliographies; repair them in Source first.',
      );
    }
    final bibliography =
        '<!-- orbit:bibliography v=1 style=${numbered ? 'numbered' : 'author-year'} -->\n## References\n\n'
        '${used.map((id) => '${numbered ? '${used.indexOf(id) + 1}. ' : '- '}${_text(sources[id]!.description)}').join('\n')}\n$bibliographyEnd';
    if (blocks.isNotEmpty) {
      next = next.replaceRange(
        blocks.single.start,
        blocks.single.end,
        bibliography,
      );
    } else if (addBibliography && used.isNotEmpty) {
      writingLiteralRanges(next, requireClosed: true);
      if (next.contains('<!-- orbit:bibliography')) {
        throw const FormatException(
          'Unrecognized bibliography is preserved; no second bibliography was added.',
        );
      }
      next = '$next\n\n$bibliography\n';
    }
    return next;
  }

  String publication({bool refreshContent = true}) {
    var next = refreshContent ? refresh() : source;
    final parsed = DocumentCitations(next);
    final literal = [...writingLiteralRanges(next), ...codeSpanRanges(next)];
    final bibliographyMarkers = <int>{};
    for (final block in RegExp(
      r'<!-- orbit:bibliography v=1 style=(?:numbered|author-year) -->[\s\S]*?<!-- /orbit:bibliography -->',
    ).allMatches(next)) {
      if (literal.any((r) => block.start > r.$1 && block.start < r.$2)) {
        continue;
      }
      bibliographyMarkers.add(block.start);
      bibliographyMarkers.add(block.end - bibliographyEnd.length);
    }
    for (final m in RegExp(
      r'<!-- (?:orbit:source [^\r\n]*?|orbit:cite [^\r\n]*?|/orbit:cite|orbit:bibliography v=1 style=(?:numbered|author-year)|/orbit:bibliography) -->',
    ).allMatches(next).toList().reversed) {
      if (literal.any((r) => m.start > r.$1 && m.start < r.$2)) continue;
      // Only metadata understood by this version may be removed from exports.
      if (m[0]!.startsWith('<!-- orbit:source') &&
          !parsed._sourceRanges.values.any((r) => r.$1 == m.start)) {
        continue;
      }
      if (m[0]!.startsWith('<!-- orbit:cite') &&
          !parsed.occurrences.any((c) => c.start == m.start)) {
        continue;
      }
      if (m[0] == '<!-- /orbit:cite -->' &&
          !parsed.occurrences.any((c) => c.end == m.end)) {
        continue;
      }
      if (m[0]!.contains('orbit:bibliography') &&
          !bibliographyMarkers.contains(m.start)) {
        continue;
      }
      next = next.replaceRange(m.start, m.end, '');
    }
    return next;
  }
}
