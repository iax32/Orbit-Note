// The Markdown package keeps its complete CommonMark entity table in this
// utility; use the pinned dependency's decoder rather than maintaining a
// partial entity list in the editor.
// ignore: implementation_imports
import 'package:markdown/src/util.dart' as markdown_util;

import 'unicode_case_fold.dart';
import '../../../domain/note_composition.dart';
import '../../../domain/linked_section.dart';
import '../../../domain/document_review.dart';
import '../../../domain/document_citations.dart';
import '../../../domain/publication_layout.dart';
import 'media_section_source.dart';

/// Lossless, transient editing projection. The original Markdown remains the
/// document; rendering never serializes a replacement document or frontmatter.
enum MarkdownBlockKind {
  text,
  heading,
  list,
  quote,
  code,
  table,
  math,
  image,
  rule,
  raw,
  blank,
  callout,
  media,
}

class MarkdownBlock {
  MarkdownBlock(
    this.source,
    this.kind, {
    this.prefix = '',
    this.suffix = '',
    this.level = 0,
    this.checked,
    this.language = '',
    this.alignment = 'left',
    this.alignmentPrefix = '',
  });
  String source;
  final MarkdownBlockKind kind;
  final String prefix, suffix, language;
  final String alignment, alignmentPrefix;
  bool get canAlign =>
      kind == MarkdownBlockKind.text || kind == MarkdownBlockKind.heading;
  String withAlignment(String value, {String? lineEnding}) {
    final unaligned = source.substring(alignmentPrefix.length);
    if (value == 'left') return unaligned;
    final eol = lineEnding ?? (source.contains('\r\n') ? '\r\n' : '\n');
    return '<!-- orbit:align=$value -->$eol$unaligned';
  }

  final int level;
  final bool? checked;
  String get content =>
      source.substring(prefix.length, source.length - suffix.length);
  String replaceContent(String value) => '$prefix$value$suffix';
}

class MarkdownDocument {
  MarkdownDocument(this.blocks, {Map<String, String>? referenceDefinitions})
    : referenceDefinitions = Map.unmodifiable(referenceDefinitions ?? const {});
  final List<MarkdownBlock> blocks;

  /// Unicode case-folded, CommonMark-whitespace-normalized reference labels.
  final Map<String, String> referenceDefinitions;
  String get source => blocks.map((b) => b.source).join();
  int offsetOf(int index) =>
      blocks.take(index).fold(0, (n, b) => n + b.source.length);
  int blockAt(int offset) {
    var end = 0;
    for (var i = 0; i < blocks.length; i++) {
      end += blocks[i].source.length;
      if (offset < end) return i;
    }
    return blocks.length - 1;
  }

  static MarkdownDocument parse(
    String source, {
    Map<String, String> inheritedDefinitions = const {},
  }) {
    final lines = RegExp(
      r'[^\n]*\n|[^\n]+$',
    ).allMatches(source).map((m) => m[0]!).toList();
    final textLines = lines.map((line) {
      if (!line.endsWith('\n')) return line;
      final length = line.length - (line.endsWith('\r\n') ? 2 : 1);
      return line.substring(0, length);
    }).toList();
    final definitions = _scanReferenceDefinitions(textLines);
    final references = {
      ..._referenceTargets(definitions),
      ...inheritedDefinitions,
    };
    if (lines.isEmpty) {
      return MarkdownDocument([
        MarkdownBlock('', MarkdownBlockKind.text),
      ], referenceDefinitions: references);
    }
    String text(int i) => textLines[i];
    String ending(int i) => lines[i].substring(text(i).length);
    final blocks = <MarkdownBlock>[];
    var i = 0;
    while (i < lines.length) {
      if (ReviewAnnotation.parse(lines[i]) != null ||
          (i == 0 && PublicationSettings.metadataLine(lines[i]))) {
        blocks.add(MarkdownBlock(lines[i], MarkdownBlockKind.raw));
        i++;
        continue;
      }
      final line = text(i), eol = ending(i);
      if (NoteColumns.opening.hasMatch(line) ||
          NoteObjectBlock.opening.hasMatch(line)) {
        final end = NoteColumns.opening.hasMatch(line)
            ? NoteColumns.endLine(lines, i)
            : (i + 2 < lines.length ? i + 2 : null);
        if (end != null) {
          final raw = lines.sublist(i, end + 1).join();
          if (NoteColumns.parse(raw) != null ||
              NoteObjectBlock.parse(raw) != null) {
            blocks.add(MarkdownBlock(raw, MarkdownBlockKind.raw));
            i = end + 1;
            continue;
          }
        }
      }
      if (LinkedSection.opening.hasMatch(line)) {
        final end = LinkedSection.endLine(lines, i);
        if (end != null) {
          final raw = lines.sublist(i, end + 1).join();
          if (LinkedSection.parse(raw) != null) {
            blocks.add(MarkdownBlock(raw, MarkdownBlockKind.raw));
            i = end + 1;
            continue;
          }
        }
      }
      if (line.trim().isEmpty) {
        blocks.add(MarkdownBlock(lines[i++], MarkdownBlockKind.blank));
        continue;
      }
      // Frontmatter, HTML, reference definitions and unfamiliar extensions stay
      // literal. They never pass through a lossy Markdown renderer/serializer.
      if (MediaSectionSource.opening.hasMatch(line)) {
        final end = MediaSectionSource.endLine(lines, i);
        if (end != null) {
          final raw = lines.sublist(i, end + 1).join();
          if (MediaSectionSource.parse(raw) != null) {
            blocks.add(MarkdownBlock(raw, MarkdownBlockKind.media));
            i = end + 1;
            continue;
          }
        }
      }
      if (i == 0 && line == '---') {
        var end = i + 1;
        while (end < lines.length && text(end) != '---' && text(end) != '...') {
          end++;
        }
        if (end < lines.length) {
          blocks.add(
            MarkdownBlock(
              lines.sublist(i, end + 1).join(),
              MarkdownBlockKind.raw,
            ),
          );
          i = end + 1;
          continue;
        }
      }
      final definition = definitions[i];
      if (definition != null) {
        blocks.add(
          MarkdownBlock(
            lines.sublist(i, definition.endLine + 1).join(),
            MarkdownBlockKind.raw,
          ),
        );
        i = definition.endLine + 1;
        continue;
      }
      final fence = RegExp(r'^ {0,3}(`{3,}|~{3,})([^\r\n]*)$').firstMatch(line);
      if (fence != null &&
          !(fence[1]!.startsWith('`') && fence[2]!.contains('`'))) {
        var end = i + 1;
        final closing = RegExp(
          '^ {0,3}${RegExp.escape(fence[1]![0])}{${fence[1]!.length},}[ \\t]*\$',
        );
        while (end < lines.length && !closing.hasMatch(text(end))) {
          end++;
        }
        if (end == lines.length) {
          blocks.add(
            MarkdownBlock(lines.sublist(i).join(), MarkdownBlockKind.raw),
          );
          break;
        }
        final raw = lines.sublist(i, end + 1).join();
        final contentEnd = end > i + 1 ? ending(end - 1) : '';
        blocks.add(
          MarkdownBlock(
            raw,
            MarkdownBlockKind.code,
            prefix: lines[i],
            suffix: '$contentEnd${lines[end]}',
            language: fence[2]!.trim(),
          ),
        );
        i = end + 1;
        continue;
      }
      if (line.trim() == r'$$') {
        var end = i + 1;
        while (end < lines.length && text(end).trim() != r'$$') {
          end++;
        }
        if (end < lines.length) {
          blocks.add(
            MarkdownBlock(
              lines.sublist(i, end + 1).join(),
              MarkdownBlockKind.math,
              prefix: lines[i],
              suffix: '${end > i + 1 ? ending(end - 1) : ''}${lines[end]}',
            ),
          );
          i = end + 1;
          continue;
        }
        blocks.add(
          MarkdownBlock(lines.sublist(i).join(), MarkdownBlockKind.raw),
        );
        break;
      }
      if (line.startsWith(r'$$') && line.endsWith(r'$$') && line.length > 4) {
        blocks.add(
          MarkdownBlock(
            lines[i++],
            MarkdownBlockKind.math,
            prefix: r'$$',
            suffix: '\$\$$eol',
          ),
        );
        continue;
      }
      if (i + 1 < lines.length &&
          line.contains('|') &&
          MarkdownTable.isSeparator(text(i + 1))) {
        var end = i + 2;
        while (end < lines.length &&
            text(end).trim().isNotEmpty &&
            text(end).contains('|')) {
          end++;
        }
        final raw = lines.sublist(i, end).join();
        final table = MarkdownTable.tryParse(raw);
        blocks.add(
          MarkdownBlock(
            raw,
            table == null ? MarkdownBlockKind.raw : MarkdownBlockKind.table,
          ),
        );
        i = end;
        continue;
      }
      if (RegExp(
        r'^ {0,3}(?:\*\s*){3,}$|^ {0,3}(?:-\s*){3,}$|^ {0,3}(?:_\s*){3,}$',
      ).hasMatch(line)) {
        blocks.add(MarkdownBlock(lines[i++], MarkdownBlockKind.rule));
        continue;
      }
      final heading = RegExp(
        r'^( {0,3}#{1,6}[ \t]+)(.*?)([ \t]+#+[ \t]*)?$',
      ).firstMatch(line);
      final emptyHeading = RegExp(r'^( {0,3}#{1,6}[ \t]*)$').firstMatch(line);
      if (heading != null || emptyHeading != null) {
        final prefix = heading?[1] ?? emptyHeading![1]!;
        blocks.add(
          MarkdownBlock(
            lines[i++],
            MarkdownBlockKind.heading,
            prefix: prefix,
            suffix:
                '${RegExp(r' \^[A-Za-z0-9][A-Za-z0-9_-]*\s*$').firstMatch(line)?.group(0) ?? heading?[3] ?? ''}$eol',
            level: '#'.allMatches(prefix).length,
          ),
        );
        continue;
      }
      if (i + 1 < lines.length &&
          !RegExp(r'^ *(?:[-+*]|\d+[.)]) +|^>').hasMatch(line) &&
          RegExp(r'^ {0,3}(=+|-+) *$').hasMatch(text(i + 1))) {
        blocks.add(
          MarkdownBlock(
            '${lines[i]}${lines[i + 1]}',
            MarkdownBlockKind.heading,
            suffix:
                '${RegExp(r' \^[A-Za-z0-9][A-Za-z0-9_-]*\s*$').firstMatch(line)?.group(0) ?? ''}$eol${lines[i + 1]}',
            level: text(i + 1).trim().startsWith('=') ? 1 : 2,
          ),
        );
        i += 2;
        continue;
      }
      final list = RegExp(
        r'^( *)([-+*]|\d{1,9}[.)])(?:[ \t]+(\[([ xX])\][ \t]+)?|$)',
      ).firstMatch(line);
      if (list != null) {
        blocks.add(
          MarkdownBlock(
            lines[i++],
            MarkdownBlockKind.list,
            prefix: list[0]!,
            suffix:
                '${RegExp(r' \^[A-Za-z0-9][A-Za-z0-9_-]*\s*$').firstMatch(line)?.group(0) ?? ''}$eol',
            level: list[1]!.length,
            checked: list[3] == null ? null : list[4]!.toLowerCase() == 'x',
          ),
        );
        continue;
      }
      if (RegExp(r'^!\[[^\]]*\]\((?:<[^>]+>|[^)]+)\)\s*$').hasMatch(line)) {
        blocks.add(
          MarkdownBlock(lines[i++], MarkdownBlockKind.image, suffix: eol),
        );
        continue;
      }
      if (line.startsWith('> [!')) {
        var end = i + 1;
        while (end < lines.length &&
            (text(end).startsWith('>') ||
                (text(end).trim().isEmpty &&
                    end + 1 < lines.length &&
                    text(end + 1).startsWith('>')))) {
          end++;
        }
        final raw = lines.sublist(i, end).join();
        blocks.add(MarkdownBlock(raw, MarkdownBlockKind.callout));
        i = end;
        continue;
      }
      final quote = RegExp(r'^ {0,3}> ?').firstMatch(line);
      if (quote != null) {
        blocks.add(
          MarkdownBlock(
            lines[i++],
            MarkdownBlockKind.quote,
            prefix: quote[0]!,
            suffix: eol,
          ),
        );
        continue;
      }
      if (RegExp(r'^(?: {4}|\t)').hasMatch(line)) {
        var end = i + 1;
        while (end < lines.length &&
            (text(end).trim().isEmpty ||
                RegExp(r'^(?: {4}|\t)').hasMatch(text(end)))) {
          end++;
        }
        blocks.add(
          MarkdownBlock(lines.sublist(i, end).join(), MarkdownBlockKind.raw),
        );
        i = end;
        continue;
      }
      if (RegExp(r'^\s*(?:<|\[.*\]:|\{\{|:::|\t| {4})').hasMatch(line) &&
          !(line.startsWith('<!-- orbit:cite ') &&
              DocumentCitations(line).occurrences.isNotEmpty)) {
        blocks.add(MarkdownBlock(lines[i++], MarkdownBlockKind.raw));
        continue;
      }
      // Soft-wrapped prose is one editable paragraph. Leave boundary syntax alone.
      var end = i + 1;
      while (end < lines.length &&
          text(end).trim().isNotEmpty &&
          !RegExp(r'^ {0,3}(=+|-+)[ \t]*$').hasMatch(text(end)) &&
          !RegExp(
            r'^\s*(?:#{1,6}(?:[ \t]|$)|>|[-+*][ \t]|\d{1,9}[.)][ \t]|`{3}|~{3}|\$\$|\||!\[|<|\[.*\]:|:::|\{\{)',
          ).hasMatch(text(end)) &&
          !(end + 1 < lines.length &&
              MarkdownTable.isSeparator(text(end + 1)))) {
        end++;
      }
      if (end < lines.length &&
          RegExp(r'^ {0,3}(=+|-+)[ \t]*$').hasMatch(text(end))) {
        blocks.add(
          MarkdownBlock(
            lines.sublist(i, end + 1).join(),
            MarkdownBlockKind.heading,
            suffix: '${ending(end - 1)}${lines[end]}',
            level: text(end).trim().startsWith('=') ? 1 : 2,
          ),
        );
        i = end + 1;
        continue;
      }
      blocks.add(
        MarkdownBlock(
          lines.sublist(i, end).join(),
          MarkdownBlockKind.text,
          suffix:
              RegExp(
                r' \^[A-Za-z0-9][A-Za-z0-9_-]*\s*$',
              ).firstMatch(lines.sublist(i, end).join())?.group(0) ??
              ending(end - 1),
        ),
      );
      i = end;
    }
    if (blocks.last.kind == MarkdownBlockKind.blank ||
        RegExp(
          r'^<!-- orbit:align=(left|center|right|justify) -->\r?\n$',
        ).hasMatch(blocks.last.source)) {
      blocks.add(MarkdownBlock('', MarkdownBlockKind.text));
    }
    // Bind only our exact marker to one immediately following prose/heading
    // block. Unknown comments and unsupported targets remain literal source.
    for (var j = 0; j + 1 < blocks.length; j++) {
      final marker = RegExp(
        r'^<!-- orbit:align=(left|center|right|justify) -->\r?\n$',
      ).firstMatch(blocks[j].source);
      final next = blocks[j + 1];
      if (marker == null ||
          (!next.canAlign && next.kind != MarkdownBlockKind.blank)) {
        continue;
      }
      final prefix = blocks[j].source;
      blocks[j] = MarkdownBlock(
        '$prefix${next.source}',
        next.kind == MarkdownBlockKind.blank
            ? MarkdownBlockKind.text
            : next.kind,
        prefix: '$prefix${next.prefix}',
        suffix: next.kind == MarkdownBlockKind.blank
            ? next.source
            : next.suffix,
        level: next.level,
        alignment: marker[1]!,
        alignmentPrefix: prefix,
      );
      blocks.removeAt(j + 1);
    }
    return MarkdownDocument(blocks, referenceDefinitions: references);
  }

  /// Returns normalized top-level link definitions without building blocks.
  static Map<String, String> referenceDefinitionsFor(String source) =>
      _referenceTargets(
        _scanReferenceDefinitions(source.split(RegExp(r'\r?\n'))),
      );

  static String _referenceKey(String label) {
    final folded = unicodeCaseFold(label);
    var start = 0;
    var end = folded.length;
    while (start < end && _isReferenceWhitespace(folded.codeUnitAt(start))) {
      start++;
    }
    while (end > start && _isReferenceWhitespace(folded.codeUnitAt(end - 1))) {
      end--;
    }
    return folded.substring(start, end).replaceAll(_referenceWhitespace, ' ');
  }

  static final _referenceWhitespace = RegExp(r'[ \t\r\n]+');
  static bool _isReferenceWhitespace(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0a ||
      codeUnit == 0x0d;

  static Map<String, String> _referenceTargets(
    Map<int, _ReferenceDefinition> definitions,
  ) {
    final result = <String, String>{};
    for (final definition in definitions.values) {
      // Orbit footnotes are not shortcut-link destination definitions.
      if (definition.label.startsWith('^')) continue;
      result.putIfAbsent(
        definition.label,
        () => _decodeLinkDestination(definition.destination),
      );
    }
    return result;
  }

  /// Resolves Markdown escapes/entities for link actions without rewriting the
  /// authored definition block. Percent escapes remain byte-for-byte intact.
  static String _decodeLinkDestination(String destination) {
    final unescaped = destination.replaceAllMapped(
      RegExp(r'\\([!-/:-@\[-`{-~])'),
      (match) => match[1]!,
    );
    return markdown_util.decodeHtmlCharacters(unescaped);
  }

  static Map<int, _ReferenceDefinition> _scanReferenceDefinitions(
    List<String> lines,
  ) {
    final result = <int, _ReferenceDefinition>{};
    RegExp? closingFence;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i == 0 && line == '---') {
        final end = lines.indexWhere(
          (line) => line == '---' || line == '...',
          1,
        );
        if (end >= 0) {
          i = end;
          continue;
        }
      }
      if (closingFence != null) {
        if (closingFence.hasMatch(line)) closingFence = null;
        continue;
      }
      final fence = RegExp(r'^ {0,3}(`{3,}|~{3,})([^\r\n]*)$').firstMatch(line);
      if (fence != null &&
          !(fence[1]!.startsWith('`') && fence[2]!.contains('`'))) {
        closingFence = RegExp(
          '^ {0,3}${RegExp.escape(fence[1]![0])}{${fence[1]!.length},}[ \\t]*\$',
        );
        continue;
      }
      final definition = _ReferenceDefinition.tryParse(lines, i);
      if (definition == null) continue;
      result[i] = definition;
      i = definition.endLine;
    }
    return result;
  }
}

/// A validated definition and its exact line ownership. Titles stay in the raw
/// editing block; they never become a separate Rich paragraph or saved rendering.
class _ReferenceDefinition {
  const _ReferenceDefinition(this.label, this.destination, this.endLine);
  final String label, destination;
  final int endLine;
  static final _head = RegExp(r'^ {0,3}\[((?:\\.|[^\[\]\\]){1,999})\]:[ \t]*');
  static final _punctuation = RegExp(r'[!-/:-@\[-`{-~]');

  static bool _escaped(String line, int position) =>
      line[position] == '\\' &&
      position + 1 < line.length &&
      _punctuation.hasMatch(line[position + 1]);

  static int _skipSpaces(String line, int position) {
    while (position < line.length &&
        (line[position] == ' ' || line[position] == '\t')) {
      position++;
    }
    return position;
  }

  static _ReferenceDefinition? tryParse(List<String> lines, int startLine) {
    var lineNumber = startLine;
    var line = lines[lineNumber];
    final head = _head.firstMatch(line);
    if (head == null) return null;
    final label = MarkdownDocument._referenceKey(head[1]!);
    if (label.isEmpty) return null;
    var position = head.end;
    // The destination may follow one line ending, never a blank line.
    if (position == line.length) {
      if (++lineNumber == lines.length) return null;
      line = lines[lineNumber];
      position = _skipSpaces(line, 0);
    }
    if (position == line.length) return null;

    final bracketed = line[position] == '<';
    if (bracketed) position++;
    final destinationStart = position;
    var depth = 0;
    while (position < line.length) {
      if (_escaped(line, position)) {
        position += 2;
        continue;
      }
      final char = line[position];
      if (bracketed) {
        if (char == '>') break;
        if (char == '<') return null;
      } else {
        final code = line.codeUnitAt(position);
        if (code <= 32 || code == 127) break;
        if (char == '(') depth++;
        if (char == ')' && --depth < 0) return null;
      }
      position++;
    }
    final destination = line.substring(destinationStart, position);
    if (bracketed) {
      if (position == line.length) return null;
      position++;
    } else if (destination.isEmpty || depth != 0) {
      return null;
    }
    final end = position;
    position = _skipSpaces(line, position);
    if (position < line.length) {
      // Same-line junk or a malformed title invalidates the entire definition.
      if (position == end) return null;
      final titleEnd = _titleEnd(lines, lineNumber, position);
      if (titleEnd == null) return null;
      return _ReferenceDefinition(label, destination, titleEnd);
    }
    // An invalid next-line title is ordinary prose, leaving the destination
    // valid. Roll back all tentative title lines in that case.
    if (lineNumber + 1 < lines.length) {
      final nextLine = lines[lineNumber + 1];
      final titleEnd = _titleEnd(
        lines,
        lineNumber + 1,
        _skipSpaces(nextLine, 0),
      );
      if (titleEnd != null) {
        return _ReferenceDefinition(label, destination, titleEnd);
      }
    }
    return _ReferenceDefinition(label, destination, lineNumber);
  }

  static int? _titleEnd(List<String> lines, int lineNumber, int position) {
    if (position == lines[lineNumber].length) return null;
    final opening = lines[lineNumber][position];
    if (opening != '"' && opening != "'" && opening != '(') return null;
    final closing = opening == '(' ? ')' : opening;
    position++;
    while (lineNumber < lines.length) {
      final line = lines[lineNumber];
      while (position < line.length) {
        if (_escaped(line, position)) {
          position += 2;
          continue;
        }
        final char = line[position++];
        if (char == closing) {
          return _skipSpaces(line, position) == line.length ? lineNumber : null;
        }
        if (opening == '(' && char == '(') return null;
      }
      if (++lineNumber == lines.length || lines[lineNumber].trim().isEmpty) {
        return null;
      }
      position = 0;
    }
    return null;
  }
}

class MarkdownTable {
  MarkdownTable(
    this.rows,
    this.alignments, {
    this.eol = '\n',
    this.trailing = true,
    String? source,
  }) {
    if (source != null) {
      final lines = RegExp(r'[^\n]*\n|[^\n]+$').allMatches(source).toList();
      String text(int i) => lines[i][0]!.replaceFirst(RegExp(r'\r?\n$'), '');
      String ending(int i) => lines[i][0]!.substring(text(i).length);
      for (var r = 0; r < rows.length; r++) {
        final i = r == 0 ? 0 : r + 1;
        _originalRows[rows[r]] = (text(i), List.of(rows[r]));
        _rowEndings[rows[r]] = ending(i);
      }
      _originalAlignment = (text(1), List.of(alignments));
      _alignmentEnding = ending(1);
      _sourceTail = source.substring(
        lines[rows.length].start + text(rows.length).length,
      );
    }
  }
  final List<List<String>> rows;
  final List<String> alignments;
  final String eol;
  final bool trailing;
  final _originalRows = Map<List<String>, (String, List<String>)>.identity();
  final _rowEndings = Map<List<String>, String>.identity();
  (String, List<String>)? _originalAlignment;
  String? _alignmentEnding, _sourceTail;
  int get columns => alignments.length;
  static List<(int, int)> _cellRanges(String line) {
    final from = line.length - line.trimLeft().length;
    final to = line.trimRight().length;
    var start = from < to && line[from] == '|' ? from + 1 : from;
    final ranges = <(int, int)>[];
    for (var i = start; i < to; i++) {
      if (line[i] == '\\') {
        i++;
        continue;
      }
      if (line[i] == '`') {
        final opening = RegExp(r'`+').matchAsPrefix(line, i)!;
        final closing = RegExp(r'`+')
            .allMatches(line, opening.end)
            .where((m) => m.end - m.start == opening.end - opening.start)
            .firstOrNull;
        // Only a balanced code span can hide an interior pipe.
        i = (closing?.end ?? opening.end) - 1;
        continue;
      }
      if (line[i] == '|') {
        ranges.add((start, i));
        start = i + 1;
      }
    }
    if (start < to || ranges.isEmpty) ranges.add((start, to));
    return ranges;
  }

  static List<String> cells(String line) => [
    for (final (start, end) in _cellRanges(line))
      line.substring(start, end).trim(),
  ];

  static List<({int row, int column, int start, int end})> sourceCells(
    String source,
  ) {
    final lines = RegExp(r'[^\n]*\n|[^\n]+$').allMatches(source).toList();
    final result = <({int row, int column, int start, int end})>[];
    for (var i = 0; i < lines.length; i++) {
      if (i == 1) continue; // Alignment is structure, not a cell.
      final line = lines[i][0]!.replaceFirst(RegExp(r'\r?\n$'), '');
      if (line.trim().isEmpty) continue;
      final ranges = _cellRanges(line);
      for (var c = 0; c < ranges.length; c++) {
        final (a, b) = ranges[c];
        final raw = line.substring(a, b);
        final left = raw.length - raw.trimLeft().length;
        final right = raw.trimRight().length.clamp(left, raw.length);
        result.add((
          row: i == 0 ? 0 : i - 1,
          column: c,
          start: lines[i].start + a + left,
          end: lines[i].start + a + right,
        ));
      }
    }
    return result;
  }

  static bool isSeparator(String line) =>
      line.contains('|') &&
      cells(line).every((c) => RegExp(r'^:?-{3,}:?$').hasMatch(c));
  static MarkdownTable? tryParse(String source) {
    final lines = source.trimRight().split(RegExp(r'\r?\n'));
    if (lines.length < 2 || !isSeparator(lines[1])) return null;
    final align = cells(lines[1]);
    final rows = [cells(lines[0]), ...lines.skip(2).map(cells)];
    if (rows.any((r) => r.length != align.length) ||
        align.length > 50 ||
        rows.length > 1000) {
      return null;
    }
    return MarkdownTable(
      rows,
      align,
      eol: source.contains('\r\n') ? '\r\n' : '\n',
      trailing: source.endsWith('\n'),
      source: source,
    );
  }

  String _encodeRow(List<String> values, (String, List<String>)? original) {
    if (original == null || original.$2.length != values.length) {
      return '| ${values.join(' | ')} |';
    }
    var line = original.$1;
    var unchanged = true;
    for (var c = 0; c < values.length; c++) {
      if (values[c] != original.$2[c]) {
        unchanged = false;
        break;
      }
    }
    if (unchanged) return line;
    final ranges = _cellRanges(line);
    for (var c = values.length - 1; c >= 0; c--) {
      if (values[c] == original.$2[c]) continue;
      final (start, end) = ranges[c];
      final raw = line.substring(start, end);
      final left = raw.length - raw.trimLeft().length;
      final right = raw.trimRight().length.clamp(left, raw.length);
      line = line.replaceRange(start + left, start + right, values[c]);
    }
    return line;
  }

  String encode() {
    final lines = [
      (
        _encodeRow(rows.first, _originalRows[rows.first]),
        _rowEndings[rows.first] ?? eol,
      ),
      (_encodeRow(alignments, _originalAlignment), _alignmentEnding ?? eol),
      for (final row in rows.skip(1))
        (_encodeRow(row, _originalRows[row]), _rowEndings[row] ?? eol),
    ];
    final out = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      out.write(lines[i].$1);
      if (i < lines.length - 1) {
        out.write(lines[i].$2.isEmpty ? eol : lines[i].$2);
      } else {
        out.write(_sourceTail ?? (trailing ? eol : ''));
      }
    }
    return out.toString();
  }

  static String visibleCell(String value) => value.replaceAllMapped(
    RegExp(r'(\\+)\|'),
    (m) => m[1]!.length.isOdd
        ? '${List.filled(m[1]!.length ~/ 2, '\\').join()}|'
        : m[0]!,
  );
  static String cellText(String value) => value
      .replaceAll(RegExp(r'\r\n|[\r\n]'), '<br>')
      .replaceAllMapped(
        RegExp(r'(\\*)\|'),
        (m) => '${List.filled(m[1]!.length * 2 + 1, '\\').join()}|',
      );
}

/// A link within an [InlineProjection] tracking source and visible ranges.
class ProjectedLink {
  const ProjectedLink({
    required this.sourceStart,
    required this.sourceEnd,
    required this.visibleStart,
    required this.visibleEnd,
    required this.target,
    required this.label,
    required this.isWiki,
    this.isReference = false,
    this.isResolved = false,
  });

  final int sourceStart;
  final int sourceEnd;
  final int visibleStart;
  final int visibleEnd;
  final String target;
  final String label;
  final bool isWiki;
  final bool isReference;
  final bool isResolved;
}

class _InlineLinkMatch {
  const _InlineLinkMatch({
    required this.labelEnd,
    required this.sourceEnd,
    required this.destination,
  });
  final int labelEnd;
  final int sourceEnd;
  final String destination;
}

class _ReferenceLabelMatch {
  const _ReferenceLabelMatch(this.start, this.end);
  final int start;
  final int end;
}

class _ReferenceLinkMatch {
  const _ReferenceLinkMatch({
    required this.textEnd,
    required this.labelStart,
    required this.labelEnd,
  });
  final int textEnd;
  final int labelStart;
  final int labelEnd;
  int get end => labelEnd + 1;
}

/// A visible inline projection with a source boundary for every UTF-16 position.
/// Edits splice only the selected range, retaining untouched delimiters/links.
class InlineProjection {
  InlineProjection(this.source, {Map<String, String>? referenceDefinitions})
    : referenceDefinitions = referenceDefinitions ?? const {} {
    _parse(0, source.length, const {});
  }
  final String source;
  final Map<String, String> referenceDefinitions;
  final _text = StringBuffer();
  final List<int> starts = [], ends = [];
  final List<Set<String>> styles = [];
  final _wrappers = <(int, int, int, int)>[];
  final _plainWiki = <(int, int)>[];
  final List<ProjectedLink> links = [];
  static final _autolinkPattern = RegExp(
    r'<((?:[A-Za-z][A-Za-z0-9+.-]{1,31}:[^ <>]*)|(?:[^\s<>@]+@[^\s<>@]+))>',
  );
  static final _asciiPunctuation = RegExp(r'^[!-/:-@\[-`{-~]$');
  static String _referenceKey(String label) {
    final folded = unicodeCaseFold(label);
    var start = 0;
    var end = folded.length;
    while (start < end && _isReferenceWhitespace(folded.codeUnitAt(start))) {
      start++;
    }
    while (end > start && _isReferenceWhitespace(folded.codeUnitAt(end - 1))) {
      end--;
    }
    return folded.substring(start, end).replaceAll(_referenceWhitespace, ' ');
  }

  static final _referenceWhitespace = RegExp(r'[ \t\r\n]+');
  static bool _isReferenceWhitespace(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0a ||
      codeUnit == 0x0d;
  static bool _isAsciiPunctuation(String char) =>
      _asciiPunctuation.hasMatch(char);

  int _backtickRunLength(int start, int limit) {
    var run = 1;
    while (start + run < limit && source[start + run] == '`') {
      run++;
    }
    return run;
  }

  int? _codeSpanEnd(int start, int limit) {
    if (start >= limit || source[start] != '`') return null;
    final run = _backtickRunLength(start, limit);
    var close = start + run;
    while (close < limit) {
      if (source[close] != '`') {
        close++;
        continue;
      }
      var closingRun = 1;
      while (close + closingRun < limit && source[close + closingRun] == '`') {
        closingRun++;
      }
      if (closingRun == run) return close + run;
      close += closingRun;
    }
    return null;
  }

  int? _referenceLabelEnd(int opening, int limit, {required bool allowNested}) {
    var nested = 0;
    for (var i = opening + 1; i < limit; i++) {
      if (source[i] == '\\' &&
          i + 1 < limit &&
          _isAsciiPunctuation(source[i + 1])) {
        i++;
        continue;
      }
      if (allowNested && source[i] == '`') {
        final codeEnd = _codeSpanEnd(i, limit);
        i = (codeEnd ?? i + _backtickRunLength(i, limit)) - 1;
        continue;
      }
      if (source[i] == '[') {
        if (!allowNested) return null;
        nested++;
      } else if (source[i] == ']') {
        if (nested > 0) {
          nested--;
        } else {
          return i;
        }
      } else if (source[i] == '\n' || source[i] == '\r') {
        return null;
      }
    }
    return null;
  }

  _ReferenceLinkMatch? _referenceLinkAt(int start, int limit) {
    if (start >= limit || source[start] != '[') return null;
    final textEnd = _referenceLabelEnd(start, limit, allowNested: true);
    if (textEnd == null || textEnd + 1 >= limit || source[textEnd + 1] != '[') {
      return null;
    }
    final labelOpening = textEnd + 1;
    final labelEnd = _referenceLabelEnd(
      labelOpening,
      limit,
      allowNested: false,
    );
    if (labelEnd == null) return null;
    return _ReferenceLinkMatch(
      textEnd: textEnd,
      labelStart: labelOpening + 1,
      labelEnd: labelEnd,
    );
  }

  _ReferenceLabelMatch? _shortcutReferenceAt(int start, int limit) {
    if (start >= limit || source[start] != '[') return null;
    final end = _referenceLabelEnd(start, limit, allowNested: false);
    if (end == null || end == start + 1) return null;
    return _ReferenceLabelMatch(start + 1, end);
  }

  bool _containsLink(int from, int to) {
    for (var i = from; i < to; i++) {
      if (source[i] == '\\' &&
          i + 1 < to &&
          _isAsciiPunctuation(source[i + 1])) {
        i++;
        continue;
      }
      if (source[i] == '`') {
        final codeEnd = _codeSpanEnd(i, to);
        i = (codeEnd ?? i + _backtickRunLength(i, to)) - 1;
        continue;
      }
      if (source[i] == '<') {
        final autolink = _autolinkPattern.matchAsPrefix(source, i);
        if (autolink != null && autolink.end <= to) return true;
      }
      if (source[i] != '[' || (i > from && source[i - 1] == '!')) continue;
      if (_inlineLinkAt(i, to) != null || _referenceLinkAt(i, to) != null) {
        return true;
      }
      final shortcut = _shortcutReferenceAt(i, to);
      if (shortcut != null &&
          referenceDefinitions.containsKey(
            _referenceKey(source.substring(shortcut.start, shortcut.end)),
          )) {
        return true;
      }
    }
    return false;
  }

  _InlineLinkMatch? _inlineLinkAt(int start, int limit) {
    if (start >= limit || source[start] != '[') return null;
    var labelEnd = -1;
    var nestedBrackets = 0;
    for (var i = start + 1; i < limit; i++) {
      if (source[i] == '\\' &&
          i + 1 < limit &&
          _isAsciiPunctuation(source[i + 1])) {
        i++;
        continue;
      }
      if (source[i] == '`') {
        final codeEnd = _codeSpanEnd(i, limit);
        i = (codeEnd ?? i + _backtickRunLength(i, limit)) - 1;
        continue;
      }
      if (source[i] == '[') {
        nestedBrackets++;
        continue;
      }
      if (source[i] == ']') {
        if (nestedBrackets > 0) {
          nestedBrackets--;
        } else {
          labelEnd = i;
          break;
        }
      }
      if (source[i] == '\n' || source[i] == '\r') return null;
    }
    if (labelEnd < start + 1 ||
        labelEnd + 1 >= limit ||
        source[labelEnd + 1] != '(') {
      return null;
    }
    if (_containsLink(start + 1, labelEnd)) return null;
    var position = labelEnd + 2;
    position = _skipLinkWhitespace(position, limit);
    if (position == -1) return null;
    final bracketed = position < limit && source[position] == '<';
    if (bracketed) position++;
    final rawDestinationStart = position;
    var nested = 0;
    while (position < limit) {
      final char = source[position];
      if (source[position] == '\\' &&
          position + 1 < limit &&
          _isAsciiPunctuation(source[position + 1])) {
        position += 2;
        continue;
      }
      if (bracketed) {
        if (char == '>') break;
        if (char == '<' || char == '\n' || char == '\r') return null;
        position++;
        continue;
      }
      if (char == ' ' || char == '\t' || char == '\n' || char == '\r') break;
      if (char == '(') {
        nested++;
      } else if (char == ')') {
        if (nested == 0) {
          break;
        }
        nested--;
      }
      position++;
    }
    if (bracketed) {
      if (position >= limit || source[position] != '>') return null;
      position++;
    } else if (nested != 0) {
      return null;
    }
    final destination = source.substring(
      rawDestinationStart,
      position - (bracketed ? 1 : 0),
    );
    final whitespace = _skipLinkWhitespace(position, limit);
    if (whitespace == -1) return null;
    position = whitespace;
    if (position < limit && source[position] != ')') {
      final opening = source[position];
      final closing = opening == '('
          ? ')'
          : opening == '"' || opening == "'"
          ? opening
          : null;
      if (closing == null) return null;
      final titleStart = position;
      position++;
      while (position < limit) {
        if (source[position] == '\\' && position + 1 < limit) {
          position += 2;
          continue;
        }
        if (source[position] == closing) break;
        if (opening == '(' && source[position] == '(') return null;
        position++;
      }
      if (position >= limit || source[position] != closing) return null;
      if (RegExp(
        r'\r?\n[ \t]*(?:\r?\n|$)',
      ).hasMatch(source.substring(titleStart, position))) {
        return null;
      }
      position++;
      position = _skipLinkWhitespace(position, limit);
      if (position == -1) return null;
    }
    if (position >= limit || source[position] != ')') return null;
    return _InlineLinkMatch(
      labelEnd: labelEnd,
      sourceEnd: position + 1,
      destination: destination,
    );
  }

  int _skipLinkWhitespace(int position, int limit) {
    var lineEndings = 0;
    while (position < limit) {
      if (source[position] == ' ' || source[position] == '\t') {
        position++;
        continue;
      }
      if (source[position] == '\r' || source[position] == '\n') {
        lineEndings++;
        if (lineEndings > 1) return -1;
        if (source[position] == '\r' &&
            position + 1 < limit &&
            source[position + 1] == '\n') {
          position += 2;
        } else {
          position++;
        }
        continue;
      }
      break;
    }
    return position;
  }

  /// Keeps a replacement inside a link label from accidentally consuming the
  /// label's closing bracket. CommonMark allows nested brackets in link text,
  /// so only unmatched closing brackets need an escape; balanced nested labels
  /// remain authored exactly as written.
  String _normalizeLinkLabel(String value) {
    final output = <String>[];
    final unmatchedOpenings = <int>[];
    var i = 0;
    while (i < value.length) {
      if (value[i] == '\\' &&
          i + 1 < value.length &&
          _isAsciiPunctuation(value[i + 1])) {
        output.add(value.substring(i, i + 2));
        i += 2;
        continue;
      }
      if (value[i] == '`') {
        final run = _backtickRunLengthIn(value, i);
        final end = _codeSpanEndIn(value, i, run);
        if (end != null) {
          output.add(value.substring(i, end));
          i = end;
          continue;
        }
      }
      if (value[i] == '[') {
        unmatchedOpenings.add(output.length);
        output.add('[');
      } else if (value[i] == ']') {
        if (unmatchedOpenings.isNotEmpty) {
          unmatchedOpenings.removeLast();
          output.add(']');
        } else {
          output.add(r'\]');
        }
      } else {
        output.add(value[i]);
      }
      i++;
    }
    for (final index in unmatchedOpenings.reversed) {
      output[index] = r'\[';
    }
    return output.join();
  }

  int _backtickRunLengthIn(String value, int position) {
    var run = 1;
    while (position + run < value.length && value[position + run] == '`') {
      run++;
    }
    return run;
  }

  int? _codeSpanEndIn(String value, int opening, int run) {
    var position = opening + run;
    while (position < value.length) {
      if (value[position] != '`') {
        position++;
        continue;
      }
      final closingRun = _backtickRunLengthIn(value, position);
      if (closingRun == run) return position + run;
      position += closingRun;
    }
    return null;
  }

  String get text => _text.toString();
  void _emit(int from, int to, Set<String> marks) {
    for (var i = from; i < to; i++) {
      _text.write(source[i]);
      starts.add(i);
      ends.add(i + 1);
      styles.add(marks);
    }
  }

  void _emitEscaped(int escapeStart, int characterStart, Set<String> marks) {
    _text.write(source[characterStart]);
    starts.add(escapeStart);
    ends.add(characterStart + 1);
    styles.add(marks);
  }

  /// Emit a CommonMark code span while preserving source boundaries. Code
  /// spans may use any run of backticks, fold line endings to spaces, and
  /// trim one matching edge space when the content is not all spaces.
  void _emitCodeSpan(int from, int to, Set<String> marks) {
    final raw = source.substring(from, to);
    final normalized = raw.replaceAll(RegExp(r'\r\n|[\r\n]'), ' ');
    var first = 0, last = normalized.length;
    if (normalized.length >= 2 &&
        normalized.startsWith(' ') &&
        normalized.endsWith(' ') &&
        normalized
            .substring(1, normalized.length - 1)
            .codeUnits
            .any((unit) => unit != 0x20)) {
      first++;
      last--;
    }
    var visible = 0;
    var sourceIndex = from;
    while (sourceIndex < to && visible < normalized.length) {
      final width =
          source[sourceIndex] == '\r' &&
              sourceIndex + 1 < to &&
              source[sourceIndex + 1] == '\n'
          ? 2
          : 1;
      if (visible >= first && visible < last) {
        _text.write(normalized[visible]);
        starts.add(sourceIndex);
        ends.add((sourceIndex + width).clamp(sourceIndex + 1, to));
        styles.add(marks);
      }
      visible++;
      sourceIndex += width;
    }
  }

  void _parse(int from, int to, Set<String> marks) {
    var i = from;
    while (i < to) {
      if (source.startsWith('<!-- orbit:cite ', i)) {
        final close = source.indexOf('<!-- /orbit:cite -->', i);
        final end = close + '<!-- /orbit:cite -->'.length;
        if (close >= 0 &&
            end <= to &&
            DocumentCitations(source.substring(i, end)).occurrences.length ==
                1) {
          final labelStart = source.indexOf('-->', i) + 3;
          _wrappers.add((i, labelStart, close, end));
          _parse(labelStart, close, marks);
          i = end;
          continue;
        }
      }
      if (source[i] == '\\' &&
          i + 1 < to &&
          _isAsciiPunctuation(source[i + 1])) {
        _emitEscaped(i, i + 1, marks);
        i += 2;
        continue;
      }
      if (source.startsWith('[[', i)) {
        final end = source.indexOf(']]', i + 2);
        if (end >= 0 && end < to) {
          final pipe = source.indexOf('|', i + 2);
          if (pipe < 0 || pipe >= end) _plainWiki.add((i, end + 2));
          _wrappers.add((
            i,
            pipe >= 0 && pipe < end ? pipe + 1 : i + 2,
            end,
            end + 2,
          ));
          final target =
              (pipe < 0
                      ? source.substring(i + 2, end)
                      : source.substring(i + 2, pipe))
                  .trim();
          final rawLabel = (pipe < 0 ? target : source.substring(pipe + 1, end))
              .trim();
          final visibleStart = _text.length;
          _emit(pipe >= 0 && pipe < end ? pipe + 1 : i + 2, end, {
            ...marks,
            'link',
          });
          final visibleEnd = _text.length;
          links.add(
            ProjectedLink(
              sourceStart: i,
              sourceEnd: end + 2,
              visibleStart: visibleStart,
              visibleEnd: visibleEnd,
              target: target,
              label: rawLabel.isEmpty ? target : rawLabel,
              isWiki: true,
            ),
          );
          i = end + 2;
          continue;
        }
      }
      final link = source[i] == '[' && (i == from || source[i - 1] != '!')
          ? _inlineLinkAt(i, to)
          : null;
      if (link != null) {
        final label = source.substring(i + 1, link.labelEnd);
        final dest = MarkdownDocument._decodeLinkDestination(link.destination);
        _wrappers.add((i, i + 1, link.labelEnd, link.sourceEnd));
        final visibleStart = _text.length;
        _parse(i + 1, link.labelEnd, {...marks, 'link'});
        final visibleEnd = _text.length;
        links.add(
          ProjectedLink(
            sourceStart: i,
            sourceEnd: link.sourceEnd,
            visibleStart: visibleStart,
            visibleEnd: visibleEnd,
            target: dest,
            label: label,
            isWiki: false,
          ),
        );
        i = link.sourceEnd;
        continue;
      }
      final reference = source[i] == '[' && (i == from || source[i - 1] != '!')
          ? _referenceLinkAt(i, to)
          : null;
      if (reference != null && reference.end <= to) {
        final label = source.substring(i + 1, reference.textEnd);
        if (label.isNotEmpty) {
          final identifier = source.substring(
            reference.labelStart,
            reference.labelEnd,
          );
          final referenceId = MarkdownDocument._referenceKey(identifier).isEmpty
              ? label
              : identifier;
          final target =
              referenceDefinitions[_referenceKey(referenceId)] ?? referenceId;
          _wrappers.add((i, i + 1, reference.textEnd, reference.end));
          final visibleStart = _text.length;
          _parse(i + 1, reference.textEnd, {...marks, 'link'});
          final visibleEnd = _text.length;
          links.add(
            ProjectedLink(
              sourceStart: i,
              sourceEnd: reference.end,
              visibleStart: visibleStart,
              visibleEnd: visibleEnd,
              target: target,
              label: label,
              isWiki: false,
              isReference: true,
              isResolved: referenceDefinitions.containsKey(
                _referenceKey(referenceId),
              ),
            ),
          );
          i = reference.end;
          continue;
        }
      }
      // A shortcut reference link is only a link when its normalized label
      // has a matching definition in this document. Ordinary bracketed prose
      // stays literal, and image labels are intentionally excluded.
      final shortcut = source[i] == '[' && (i == from || source[i - 1] != '!')
          ? _shortcutReferenceAt(i, to)
          : null;
      if (shortcut != null &&
          shortcut.end <= to &&
          (shortcut.end >= to || source[shortcut.end] != '[')) {
        final label = source.substring(shortcut.start, shortcut.end);
        final key = _referenceKey(label);
        final target = referenceDefinitions[key];
        if (target != null) {
          _wrappers.add((i, i + 1, shortcut.end, shortcut.end + 1));
          final visibleStart = _text.length;
          _parse(i + 1, shortcut.end, {...marks, 'link'});
          final visibleEnd = _text.length;
          links.add(
            ProjectedLink(
              sourceStart: i,
              sourceEnd: shortcut.end + 1,
              visibleStart: visibleStart,
              visibleEnd: visibleEnd,
              target: target,
              label: label,
              isWiki: false,
              isReference: true,
              isResolved: true,
            ),
          );
          i = shortcut.end + 1;
          continue;
        }
      }
      final autolink = source[i] == '<'
          ? _autolinkPattern.matchAsPrefix(source, i)
          : null;
      if (autolink != null && autolink.end <= to) {
        final label = autolink[1]!;
        final target = label.contains('@') && !label.contains(':')
            ? 'mailto:$label'
            : label;
        _wrappers.add((i, i + 1, i + 1 + label.length, autolink.end));
        final visibleStart = _text.length;
        _emit(i + 1, i + 1 + label.length, {...marks, 'link'});
        final visibleEnd = _text.length;
        links.add(
          ProjectedLink(
            sourceStart: i,
            sourceEnd: autolink.end,
            visibleStart: visibleStart,
            visibleEnd: visibleEnd,
            target: target,
            label: label,
            isWiki: false,
          ),
        );
        i = autolink.end;
        continue;
      }
      if (source.startsWith('<u>', i)) {
        final end = source.indexOf('</u>', i + 3);
        if (end > i + 3 && end + 4 <= to) {
          _wrappers.add((i, i + 3, end, end + 4));
          _parse(i + 3, end, {...marks, 'underline'});
          i = end + 4;
          continue;
        }
      }
      if (source.startsWith('<ins>', i)) {
        final end = source.indexOf('</ins>', i + 5);
        if (end > i + 5 && end + 6 <= to) {
          _wrappers.add((i, i + 5, end, end + 6));
          _parse(i + 5, end, {...marks, 'underline'});
          i = end + 6;
          continue;
        }
      }
      if (source.startsWith('<mark>', i)) {
        final end = source.indexOf('</mark>', i + 6);
        if (end > i + 6 && end + 7 <= to) {
          _wrappers.add((i, i + 6, end, end + 7));
          _parse(i + 6, end, {...marks, 'highlight'});
          i = end + 7;
          continue;
        }
      }
      if (source.startsWith('[^', i)) {
        final end = source.indexOf(']', i + 2);
        if (end > i + 2 &&
            end < to &&
            !source.substring(i + 2, end).contains(RegExp(r'[\s\n]'))) {
          _emit(i, end + 1, {...marks, 'footnote'});
          i = end + 1;
          continue;
        }
      }
      // CommonMark code spans may use any run length. Only a balanced run is
      // a code span; an unmatched run stays literal instead of being split
      // into misleading one-character code spans.
      if (source[i] == '`') {
        final run = _backtickRunLength(i, to);
        final closeEnd = _codeSpanEnd(i, to);
        if (closeEnd != null) {
          final contentEnd = closeEnd - run;
          _wrappers.add((i, i + run, contentEnd, contentEnd + run));
          _emitCodeSpan(i + run, contentEnd, {...marks, 'code'});
          i = closeEnd;
          continue;
        }
        // A backtick run is indivisible when it has no matching close. Do
        // not advance one character at a time, or a later single backtick
        // could incorrectly pair with the tail of this unmatched run.
        _emit(i, i + run, marks);
        i += run;
        continue;
      }
      var matched = false;
      for (final (marker, style) in [
        ('***', 'boldItalic'),
        ('___', 'boldItalic'),
        ('**', 'bold'),
        ('__', 'bold'),
        ('==', 'highlight'),
        ('~~', 'strike'),
        ('*', 'italic'),
        ('_', 'italic'),
      ]) {
        if (!source.startsWith(marker, i)) continue;
        if (marker == '_' &&
            i > from &&
            RegExp(r'\w').hasMatch(source[i - 1])) {
          continue;
        }
        var end = source.indexOf(marker, i + marker.length);
        while (end >= 0 && end < to) {
          var slashes = 0;
          for (var j = end - 1; j >= from && source[j] == '\\'; j--) {
            slashes++;
          }
          if (slashes.isEven) break;
          end = source.indexOf(marker, end + marker.length);
        }
        if (end <= i + marker.length || end + marker.length > to) continue;
        _wrappers.add((i, i + marker.length, end, end + marker.length));
        _parse(i + marker.length, end, {
          ...marks,
          if (style == 'boldItalic') ...{'bold', 'italic'} else style,
        });
        i = end + marker.length;
        matched = true;
        break;
      }
      if (!matched) {
        _emit(i, i + 1, marks);
        i++;
      }
    }
  }

  int sourceOffset(int visible, {bool end = false}) {
    if (starts.isEmpty) return 0;
    if (visible <= 0) return starts.first;
    if (visible >= starts.length) return ends.last;
    return end ? ends[visible - 1] : starts[visible];
  }

  int visibleOffset(int raw) {
    var position = 0;
    while (position < ends.length && ends[position] <= raw) {
      position++;
    }
    return position;
  }

  int outsideOffset(int visible) {
    var offset = sourceOffset(visible, end: true);
    for (final (_, _, contentEnd, close) in _wrappers.reversed) {
      if (offset == contentEnd) offset = close;
    }
    return offset;
  }

  ProjectedLink? linkAtVisibleOffset(int offset) {
    for (final link in links) {
      if (offset >= link.visibleStart && offset <= link.visibleEnd) {
        return link;
      }
    }
    return null;
  }

  ProjectedLink? linkAtSourceOffset(int offset) {
    for (final link in links) {
      if (offset >= link.sourceStart && offset <= link.sourceEnd) {
        return link;
      }
    }
    return null;
  }

  /// A balanced source fragment, retaining link targets and nested marks.
  String fragment(int start, int end) {
    if (start == end) return '';
    final tail = InlineProjection(
      edit(text.substring(start), selectionStart: 0, selectionEnd: start),
      referenceDefinitions: referenceDefinitions,
    );
    return tail.edit(
      tail.text.substring(0, end - start),
      selectionStart: end - start,
      selectionEnd: tail.text.length,
    );
  }

  String formatRange(int start, int end, String tag, String closeTag) {
    if (start == end) return source;
    final mark = switch (tag) {
      '**' || '__' => 'bold',
      '*' || '_' => 'italic',
      '~~' => 'strike',
      '==' => 'highlight',
      '<u>' => 'underline',
      '`' => 'code',
      _ => '',
    };
    var middle = fragment(start, end);
    final selected = InlineProjection(
      middle,
      referenceDefinitions: referenceDefinitions,
    );
    final remove =
        mark.isNotEmpty &&
        selected.styles.isNotEmpty &&
        selected.styles.every((s) => s.contains(mark));
    {
      final edits = <(int, int, String)>[];
      for (final (open, innerStart, innerEnd, close) in selected._wrappers) {
        final opening = middle.substring(open, innerStart);
        final closing = middle.substring(innerEnd, close);
        final matches =
            opening == tag && closing == closeTag ||
            mark == 'bold' && (opening == '**' || opening == '__') ||
            mark == 'italic' && (opening == '*' || opening == '_') ||
            mark == 'underline' && (opening == '<u>' || opening == '<ins>') ||
            mark == 'highlight' && (opening == '==' || opening == '<mark>');
        final triple =
            (opening == '***' || opening == '___') &&
            (mark == 'bold' || mark == 'italic');
        if (matches || triple) {
          final replacement = triple
              ? (mark == 'bold'
                    ? opening.substring(0, 1)
                    : opening.substring(0, 2))
              : '';
          edits.add((open, innerStart, replacement));
          edits.add((innerEnd, close, replacement));
        }
      }
      edits.sort((a, b) => b.$1.compareTo(a.$1));
      for (final (a, b, replacement) in edits) {
        middle = middle.replaceRange(a, b, replacement);
      }
    }
    final left = fragment(0, start), right = fragment(end, text.length);
    final markers = remove
        ? ['']
        : switch (mark) {
            'bold' => [tag, tag == '**' ? '__' : '**'],
            'italic' => [tag, tag == '*' ? '_' : '*'],
            _ => [tag],
          };
    for (final marker in markers) {
      final closing = remove
          ? ''
          : marker == tag
          ? closeTag
          : marker;
      final candidate = '$left$marker$middle$closing$right';
      final projection = InlineProjection(
        candidate,
        referenceDefinitions: referenceDefinitions,
      );
      if (projection.text == text &&
          projection.styles
              .skip(start)
              .take(end - start)
              .every((s) => s.contains(mark) != remove)) {
        return candidate;
      }
    }
    // Ambiguous delimiter combinations must never turn formatting into text.
    return source;
  }

  String edit(
    String next, {
    int? selectionStart,
    int? selectionEnd,
    bool outsideFormatting = false,
  }) {
    final old = text;
    var start = 0, end = old.length, nextEnd = next.length;
    while (start < end && start < nextEnd && old[start] == next[start]) {
      start++;
    }
    while (end > start &&
        nextEnd > start &&
        old[end - 1] == next[nextEnd - 1]) {
      end--;
      nextEnd--;
    }
    if (selectionStart != null &&
        selectionEnd != null &&
        selectionStart >= 0 &&
        selectionEnd >= selectionStart &&
        selectionEnd <= old.length) {
      final inserted = next.length - old.length + selectionEnd - selectionStart;
      if (inserted >= 0 &&
          next.startsWith(old.substring(0, selectionStart)) &&
          next.endsWith(old.substring(selectionEnd))) {
        start = selectionStart;
        end = selectionEnd;
        nextEnd = start + inserted;
      }
    }
    if (start == end && start == nextEnd) return source;
    // Whole-block replacement is explicit. Remove no unrelated document blocks.
    if (start == 0 && end == old.length && next.isEmpty) return '';
    var a = sourceOffset(start, end: start == end),
        b = start == end ? a : sourceOffset(end, end: true);
    // Escape-aware offsets already include the entire authored escape pair.
    // Expanding left again would consume the preceding escaped backslash,
    // or a literal backslash inside a code span.
    if (outsideFormatting && start == end) {
      a = outsideOffset(start);
      b = a;
    }
    var insertion = next.substring(start, nextEnd);
    for (final (open, contentStart, contentEnd, _) in _wrappers) {
      if (open >= source.length || source[open] != '[') continue;
      if (a < contentStart || b > contentEnd) continue;
      final content =
          source.substring(contentStart, a) +
          insertion +
          source.substring(b, contentEnd);
      final normalized = _normalizeLinkLabel(content);
      if (normalized != content) {
        return source.replaceRange(contentStart, contentEnd, normalized);
      }
    }
    for (final (open, close) in _plainWiki) {
      if (a >= open + 2 && b <= close - 2 && insertion.isNotEmpty) {
        final target = source.substring(open + 2, close - 2);
        return source.replaceRange(
          open,
          close,
          '[[$target|${target.replaceRange(a - open - 2, b - open - 2, insertion)}]]',
        );
      }
    }
    if (insertion.isEmpty) {
      for (final (open, contentStart, contentEnd, close)
          in _wrappers.reversed) {
        if (a <= contentStart && b >= contentEnd) {
          if (open < a) a = open;
          if (close > b) b = close;
        }
      }
    }
    var prefix = '', suffix = '';
    for (final (open, contentStart, contentEnd, close) in _wrappers) {
      if (b <= open || a >= close) continue;
      if (a >= contentStart && b >= close) {
        suffix = '${source.substring(contentEnd, close)}$suffix';
      }
      if (a <= open && b > contentStart && b <= contentEnd) {
        prefix += source.substring(open, contentStart);
      }
    }
    return source.replaceRange(a, b, '$prefix$insertion$suffix');
  }
}
