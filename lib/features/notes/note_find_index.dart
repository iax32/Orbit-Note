import 'rich/markdown_document.dart';
import '../../domain/note_composition.dart';
import 'rich/structured_text_projection.dart';
import 'rich/fenced_code_source.dart';
import 'rich/unicode_case_fold.dart';

/// Search uses visible prose in Rich/Read and literal source in Source/Split.
/// Each result retains its source coordinates; no rendered document is saved.
class NoteFindMatch {
  const NoteFindMatch(this.start, this.end, this.segment, this.from, this.to);
  final int start, end, segment, from, to;
}

/// A match in the case-folded search projection, mapped back to the original
/// UTF-16 offsets used by Flutter text selections.
class _FoldedMatch {
  const _FoldedMatch(this.start, this.end);

  final int start;
  final int end;
}

/// Builds a case-folded projection without losing authored source boundaries.
///
/// Full Unicode folding can expand one source rune into several UTF-16 code
/// units (for example `ß` becomes `ss`).  We only accept matches that start
/// and end on rune boundaries so a query cannot match half of an expansion.
class _FoldedSegment {
  _FoldedSegment(String source) {
    final folded = StringBuffer();
    final starts = <int>[];
    final ends = <int>[];
    final boundaries = <bool>[true];
    var sourceOffset = 0;
    for (final rune in source.runes) {
      final original = String.fromCharCode(rune);
      final nextSourceOffset = sourceOffset + original.length;
      final value = unicodeCaseFold(original);
      folded.write(value);
      for (var i = 0; i < value.length; i++) {
        starts.add(sourceOffset);
        ends.add(nextSourceOffset);
        boundaries.add(i == value.length - 1);
      }
      sourceOffset = nextSourceOffset;
    }
    text = folded.toString();
    _sourceStarts = starts;
    _sourceEnds = ends;
    _boundaries = boundaries;
  }

  late final String text;
  late final List<int> _sourceStarts;
  late final List<int> _sourceEnds;
  late final List<bool> _boundaries;

  List<_FoldedMatch> matches(String query) {
    if (query.isEmpty) return const [];
    final foldedQuery = unicodeCaseFold(query);
    if (foldedQuery.isEmpty) return const [];
    final result = <_FoldedMatch>[];
    var searchStart = 0;
    while (searchStart <= text.length - foldedQuery.length) {
      final index = text.indexOf(foldedQuery, searchStart);
      if (index < 0) break;
      final foldedEnd = index + foldedQuery.length;
      if (_boundaries[index] && _boundaries[foldedEnd]) {
        result.add(
          _FoldedMatch(_sourceStarts[index], _sourceEnds[foldedEnd - 1]),
        );
      }
      searchStart = index + foldedQuery.length;
    }
    return result;
  }
}

class NoteFindIndex {
  NoteFindIndex(
    this.source, {
    required this.rich,
    Map<String, String>? definitions,
  }) : referenceDefinitions =
           definitions ?? MarkdownDocument.referenceDefinitionsFor(source) {
    if (!rich) {
      _segments.add((0, source, null, null));
      return;
    }
    var offset = 0;
    for (final block in MarkdownDocument.parse(source).blocks) {
      final columns = NoteColumns.parse(block.source);
      if (columns != null) {
        for (var partIndex = 0; partIndex < columns.parts.length; partIndex++) {
          final partOffset = columns.offsets[partIndex];
          final part = columns.parts[partIndex];
          final child = NoteFindIndex(
            part,
            rich: true,
            definitions: referenceDefinitions,
          );
          final base = _segments.length;
          for (final segment in child._segments) {
            _segments.add((
              offset + partOffset + segment.$1,
              segment.$2,
              segment.$3,
              segment.$4,
            ));
          }
          _titleSegments.addAll(child._titleSegments.map((i) => i + base));
          for (final entry in child._codeSegments.entries) {
            _codeSegments[base + entry.key] = entry.value;
          }
        }
        offset += block.source.length;
        continue;
      }
      if (NoteObjectBlock.parse(block.source) != null) {
        offset += block.source.length;
        continue;
      }
      if (block.kind == MarkdownBlockKind.code) {
        _codeSegments[_segments.length] = block;
        _segments.add((
          offset + block.prefix.length,
          block.content,
          null,
          null,
        ));
        offset += block.source.length;
        continue;
      }
      if (block.kind == MarkdownBlockKind.table) {
        for (final cell in MarkdownTable.sourceCells(block.source)) {
          final raw = block.source.substring(cell.start, cell.end);
          _segments.add((
            offset + cell.start,
            raw,
            null,
            StructuredTextProjection.cell(raw),
          ));
        }
        offset += block.source.length;
        continue;
      }
      if (block.kind == MarkdownBlockKind.callout) {
        final parts = CalloutSourceParts(block.source);
        _titleSegments.add(_segments.length);
        _segments.add((
          offset + parts.titleStart,
          block.source.substring(parts.titleStart, parts.titleEnd),
          null,
          null,
        ));
        _segments.add((
          offset + parts.headerEnd,
          block.source.substring(parts.headerEnd),
          null,
          parts.body,
        ));
        offset += block.source.length;
        continue;
      }
      final prose = switch (block.kind) {
        MarkdownBlockKind.text ||
        MarkdownBlockKind.heading ||
        MarkdownBlockKind.list ||
        MarkdownBlockKind.quote => true,
        _ => false,
      };
      // Other specialized/raw blocks remain literal, including equations.
      final content = prose ? block.content : block.source;
      _segments.add((
        offset + (prose ? block.prefix.length : 0),
        content,
        prose
            ? InlineProjection(
                content,
                referenceDefinitions: referenceDefinitions,
              )
            : null,
        null,
      ));
      offset += block.source.length;
    }
  }

  final String source;
  final bool rich;
  final Map<String, String> referenceDefinitions;
  final _segments =
      <(int, String, InlineProjection?, StructuredTextProjection?)>[];
  final _titleSegments = <int>{};
  final _codeSegments = <int, MarkdownBlock>{};
  static final _word = RegExp(r'[\p{L}\p{N}\p{M}_]', unicode: true);

  /// Visible owning segment for verifying rendered-search correspondence.
  String segmentText(NoteFindMatch match) {
    return _segmentTexts.putIfAbsent(match.segment, () {
      final (_, raw, inline, structured) = _segments[match.segment];
      return structured?.text ?? inline?.text ?? raw;
    });
  }

  final _segmentTexts = <int, String>{};

  String selectedText(int start, int end) {
    final result = StringBuffer();
    for (final (offset, raw, projection, structured) in _segments) {
      final a = (start - offset).clamp(0, raw.length);
      final b = (end - offset).clamp(a, raw.length);
      if (a == b) continue;
      result.write(
        structured != null
            ? structured.text.substring(
                structured.visibleOffset(a),
                structured.visibleOffset(b),
              )
            : projection == null
            ? raw.substring(a, b)
            : projection.text.substring(
                projection.visibleOffset(a),
                projection.visibleOffset(b),
              ),
      );
    }
    return result.toString();
  }

  List<NoteFindMatch> matches(
    String query, {
    bool matchCase = false,
    bool wholeWord = false,
    int start = 0,
    int? end,
  }) {
    if (query.isEmpty) return const [];
    final regex = matchCase ? RegExp(RegExp.escape(query)) : null;
    final wordStart = wholeWord && _word.hasMatch(query.charactersFirst);
    final wordEnd = wholeWord && _word.hasMatch(query.charactersLast);
    final result = <NoteFindMatch>[];
    for (var i = 0; i < _segments.length; i++) {
      final (offset, raw, projection, structured) = _segments[i];
      final text = structured?.text ?? projection?.text ?? raw;
      final matches = matchCase
          ? [
              for (final match in regex!.allMatches(text))
                _FoldedMatch(match.start, match.end),
            ]
          : _FoldedSegment(text).matches(query);
      for (final match in matches) {
        // Test boundaries in the full segment, never a sliced selection.
        if (wholeWord &&
            ((wordStart &&
                    match.start > 0 &&
                    _word.hasMatch(_previousRune(text, match.start))) ||
                (wordEnd &&
                    match.end < text.length &&
                    _word.hasMatch(_nextRune(text, match.end))))) {
          continue;
        }
        final a =
            offset +
            (structured?.sourceOffset(match.start) ??
                projection?.sourceOffset(match.start) ??
                match.start);
        final b =
            offset +
            (structured?.sourceOffset(match.end, end: true) ??
                projection?.sourceOffset(match.end, end: true) ??
                match.end);
        if (a >= start && b <= (end ?? source.length)) {
          result.add(NoteFindMatch(a, b, i, match.start, match.end));
        }
      }
    }
    return result;
  }

  /// End of a single replacement, excluding closing-fence growth after it.
  int replacementEnd(
    NoteFindMatch match,
    String replacement,
    String nextSource,
  ) {
    final code = _codeSegments[match.segment];
    if (code == null) return match.end + nextSource.length - source.length;
    final edited = replaceFencedCodeContent(
      code,
      code.content.replaceRange(match.from, match.to, replacement),
    );
    return match.start +
        edited.prefix.length -
        code.prefix.length +
        replacement.length;
  }

  /// Edit projected blocks from right to left, then assemble the document once.
  String replace(List<NoteFindMatch> matches, String replacement) {
    final bySegment = <int, List<NoteFindMatch>>{};
    for (final match in matches) {
      bySegment.putIfAbsent(match.segment, () => []).add(match);
    }
    final result = StringBuffer();
    var position = 0;
    for (final index in bySegment.keys.toList()..sort()) {
      if (_titleSegments.contains(index) &&
          replacement.contains(RegExp(r'[\r\n]'))) {
        throw const FormatException('Callout titles must remain on one line.');
      }
      final (offset, original, projection, structured) = _segments[index];
      var raw = original;
      final edits = bySegment[index]!..sort((a, b) => b.from.compareTo(a.from));
      if (structured != null) {
        for (final match in edits) {
          StructuredTextProjection project(String source) => structured.cell
              ? StructuredTextProjection.cell(source)
              : StructuredTextProjection.calloutBody(
                  source,
                  eol: structured.eol,
                );
          final current = project(raw);
          final expected = current.text.replaceRange(
            match.from,
            match.to,
            replacement,
          );
          raw = current.edit(expected);
          if (project(raw).text != expected) {
            throw const FormatException(
              'Replacement cannot preserve this markup.',
            );
          }
        }
      } else if (projection == null) {
        // Source Replace All is one linear assembly, not one whole-document
        // allocation per result. Keep untouched slices byte-for-byte.
        final buffer = StringBuffer();
        var cursor = 0;
        for (final match in edits.reversed) {
          buffer.write(original.substring(cursor, match.from));
          buffer.write(replacement);
          cursor = match.to;
        }
        buffer.write(original.substring(cursor));
        raw = buffer.toString();
      } else {
        for (final match in edits) {
          final current = InlineProjection(
            raw,
            referenceDefinitions: referenceDefinitions,
          );
          final expected = current.text.replaceRange(
            match.from,
            match.to,
            replacement,
          );
          var candidate = current.edit(
            expected,
            selectionStart: match.from,
            selectionEnd: match.to,
          );
          if (InlineProjection(
                candidate,
                referenceDefinitions: referenceDefinitions,
              ).text !=
              expected) {
            // Replacement text is literal. Delimiters must not reinterpret an
            // earlier unmatched marker or shift the remaining match positions.
            final escaped = replacement.replaceAllMapped(
              RegExp(r'[\\`*_\[\]~=]'),
              (m) => '\\${m[0]}',
            );
            candidate = current.edit(
              current.text.replaceRange(match.from, match.to, escaped),
              selectionStart: match.from,
              selectionEnd: match.to,
            );
          }
          // Specialized markup can lack a safe literal encoding. Refuse the
          // complete operation rather than save a partial or lossy replacement.
          if (InlineProjection(
                candidate,
                referenceDefinitions: referenceDefinitions,
              ).text !=
              expected) {
            throw const FormatException(
              'Replacement cannot preserve this markup.',
            );
          }
          raw = candidate;
        }
      }
      final code = _codeSegments[index];
      if (code != null) {
        result.write(source.substring(position, offset - code.prefix.length));
        result.write(replaceFencedCodeContent(code, raw).source);
        position = offset + original.length + code.suffix.length;
      } else {
        result.write(source.substring(position, offset));
        result.write(raw);
        position = offset + original.length;
      }
    }
    result.write(source.substring(position));
    final next = result.toString();
    if (rich && source.contains('<!-- orbit:columns v=1 -->')) {
      int countColumns(String body) => MarkdownDocument.parse(
        body,
      ).blocks.where((b) => NoteColumns.parse(b.source) != null).length;
      if (countColumns(source) != countColumns(next)) {
        throw const FormatException(
          'Replacement would damage a column layout. Edit layout markers in Source.',
        );
      }
    }
    return next;
  }

  static String _previousRune(String text, int end) {
    final unit = text.codeUnitAt(end - 1);
    final start = unit >= 0xdc00 && unit <= 0xdfff && end > 1
        ? end - 2
        : end - 1;
    return text.substring(start, end);
  }

  static String _nextRune(String text, int start) {
    final unit = text.codeUnitAt(start);
    final end = unit >= 0xd800 && unit <= 0xdbff && start + 1 < text.length
        ? start + 2
        : start + 1;
    return text.substring(start, end);
  }
}

extension on String {
  String get charactersFirst => String.fromCharCode(runes.first);
  String get charactersLast => String.fromCharCode(runes.last);
}
