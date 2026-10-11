import 'document_anchors.dart';
import 'linked_section.dart';

class WritingSection {
  const WritingSection(
    this.title,
    this.level,
    this.start,
    this.end,
    this.headingEnd,
    this.key,
  );
  final String title, key;
  final int level, start, end, headingEnd;
}

/// Derived view ranges; no hidden document model or invented durable identities.
List<WritingSection> writingSections(String source) {
  final literal = [...writingLiteralRanges(source), ...codeSpanRanges(source)];
  final fragments = documentFragments(source)
      .where(
        (f) =>
            f.heading != null &&
            !literal.any((r) => f.start >= r.$1 && f.start < r.$2) &&
            !f.text.startsWith('---\n') &&
            !f.text.startsWith('---\r\n'),
      )
      .toList();
  final result = <WritingSection>[];
  for (var i = 0; i < fragments.length; i++) {
    final f = fragments[i];
    final match = RegExp(r'^ {0,3}(#{1,6})\s').firstMatch(f.text);
    final level =
        match?.group(1)?.length ??
        (RegExp(r'\r?\n {0,3}=').hasMatch(f.text) ? 1 : 2);
    var end = source.length;
    for (var j = i + 1; j < fragments.length; j++) {
      final next = fragments[j];
      final m = RegExp(r'^ {0,3}(#{1,6})\s').firstMatch(next.text);
      final l =
          m?.group(1)?.length ??
          (RegExp(r'\r?\n {0,3}=').hasMatch(next.text) ? 1 : 2);
      if (l <= level) {
        end = next.start;
        break;
      }
    }
    result.add(
      WritingSection(
        f.heading!,
        level,
        f.start,
        end,
        f.end,
        f.blockId == null ? 'heading:${f.heading}' : 'block:${f.blockId}',
      ),
    );
  }
  return result;
}

/// Ranges that cannot contain writing headings or footnote syntax. Offsets stay
/// in the authored source, including CRLF and UTF-16 surrogate pairs.
List<(int, int)> writingLiteralRanges(
  String source, {
  bool requireClosed = false,
}) {
  final ranges = <(int, int)>[];
  final lines = RegExp(r'[^\n]*\n|[^\n]+$').allMatches(source).toList();
  final spans = codeSpanRanges(source);
  var frontmatter = source.startsWith('---\n') || source.startsWith('---\r\n');
  String? fence, html;
  var literalStart = 0;
  var comment = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i], value = line[0]!;
    if (frontmatter) {
      if (i > 0 && (value.trimRight() == '---' || value.trimRight() == '...')) {
        ranges.add((0, line.end));
        frontmatter = false;
      }
      continue;
    }
    if (comment) {
      final close = value.indexOf('-->');
      if (close >= 0) {
        ranges.add((literalStart, line.start + close + 3));
        comment = false;
      }
      continue;
    }
    if (html != null) {
      final close = RegExp(
        '</$html\\s*>',
        caseSensitive: false,
      ).firstMatch(value);
      if (close != null) {
        ranges.add((literalStart, line.start + close.end));
        html = null;
      }
      continue;
    }
    final marker = RegExp(r'^ {0,3}(\x60{3,}|~{3,})(.*)').firstMatch(value);
    if (fence != null) {
      if (marker != null &&
          marker[1]!.startsWith(fence[0]) &&
          marker[1]!.length >= fence.length &&
          marker[2]!.trim().isEmpty) {
        ranges.add((literalStart, line.end));
        fence = null;
      }
      continue;
    }
    if (marker != null &&
        !(marker[1]!.startsWith('\x60') && marker[2]!.contains('\x60'))) {
      fence = marker[1];
      literalStart = line.start;
      continue;
    }
    for (final open in RegExp(
      r'<!--|<(pre|script|style|textarea)\b[^>]*>',
      caseSensitive: false,
    ).allMatches(value)) {
      final at = line.start + open.start;
      if (ranges.any((r) => at >= r.$1 && at < r.$2) ||
          spans.any((r) => at >= r.$1 && at < r.$2)) {
        continue;
      }
      final tag = open[1];
      final close = tag == null ? value.indexOf('-->', open.end) : -1;
      final htmlClose = tag == null
          ? null
          : RegExp(
              '</$tag\\s*>',
              caseSensitive: false,
            ).firstMatch(value.substring(open.end));
      if (tag == null && close >= 0) {
        ranges.add((at, line.start + close + 3));
      } else if (htmlClose != null) {
        ranges.add((at, line.start + open.end + htmlClose.end));
      } else {
        literalStart = at;
        comment = tag == null;
        html = tag;
        break;
      }
    }
  }
  if (requireClosed &&
      (frontmatter || comment || html != null || fence != null)) {
    throw StateError(
      'Close the literal block, comment or frontmatter before adding content.',
    );
  }
  if (frontmatter) ranges.add((0, source.length));
  if (comment || html != null || fence != null) {
    ranges.add((literalStart, source.length));
  }
  for (final use in sectionUses(source)) {
    ranges.add((use.start, use.end));
  }
  return ranges;
}

/// Exact-length delimiters; backslashes inside a code span remain literal.
List<(int, int)> codeSpanRanges(String source) {
  final runs = RegExp(r'`+').allMatches(source).toList();
  final ranges = <(int, int)>[];
  for (var i = 0; i < runs.length; i++) {
    final start = runs[i];
    var escapes = 0;
    for (var at = start.start - 1; at >= 0 && source[at] == '\\'; at--) {
      escapes++;
    }
    if (escapes.isOdd) continue;
    for (var j = i + 1; j < runs.length; j++) {
      if (runs[j][0]!.length == start[0]!.length) {
        if (!source
            .substring(start.end, runs[j].start)
            .contains(RegExp(r'\r?\n[ \t]*\r?\n'))) {
          ranges.add((start.start, runs[j].end));
          i = j;
        }
        break;
      }
    }
  }
  return ranges;
}

WritingSection? resolveWritingSection(String source, String? key) {
  if (key == null) return null;
  final matches = writingSections(source).where((s) => s.key == key).toList();
  return matches.length == 1 ? matches.single : null;
}

String moveWritingSection(
  String source,
  WritingSection section,
  int destination,
) {
  if (destination < 0 ||
      destination > source.length ||
      destination > section.start && destination < section.end) {
    throw StateError('A section cannot be moved inside itself.');
  }
  if (destination == section.start || destination == section.end) return source;
  final chunk = source.substring(section.start, section.end);
  final rest = source.replaceRange(section.start, section.end, '');
  final at = destination > section.end
      ? destination - (section.end - section.start)
      : destination;
  final eol = source.contains('\r\n') ? '\r\n' : '\n';
  final left = rest.substring(0, at), right = rest.substring(at);
  return '$left${left.isNotEmpty && !left.endsWith('\n') ? eol : ''}$chunk${right.isNotEmpty && !chunk.endsWith('\n') ? eol : ''}$right';
}

String renameWritingSection(
  String source,
  WritingSection section,
  String title,
  int level,
) {
  if (title.trim().isEmpty ||
      title.contains(RegExp(r'[\r\n]')) ||
      level < 1 ||
      level > 6) {
    throw ArgumentError('Enter a one-line heading and level 1–6.');
  }
  final text = source.substring(section.start, section.headingEnd);
  final eol = text.contains('\r\n') ? '\r\n' : '\n';
  final anchor =
      RegExp(
        r'[ \t]+\^[A-Za-z0-9][A-Za-z0-9_-]*(?=\r?\n|$)',
      ).firstMatch(text)?.group(0) ??
      '';
  return source.replaceRange(
    section.start,
    section.headingEnd,
    '${'#' * level} ${title.trim()}$anchor${text.endsWith('\n') ? eol : ''}',
  );
}

class SectionUse {
  const SectionUse(this.start, this.end, this.link);
  final int start, end;
  final LinkedSection link;
}

/// Reject footer insertion inside an unfinished literal code block.
void validateWritingAppend(String source) {
  writingLiteralRanges(source, requireClosed: true);
}

List<SectionUse> sectionUses(String source) {
  final lines = RegExp(r'[^\n]*\n|[^\n]+$').allMatches(source).toList();
  final result = <SectionUse>[];
  String? fence;
  final values = lines.map((l) => l[0]!).toList();
  for (var i = 0; i < lines.length; i++) {
    final value = lines[i][0]!;
    final marker = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)').firstMatch(value);
    if (marker != null) {
      if (fence == null) {
        fence = marker[1];
      } else if (marker[1]!.startsWith(fence[0]) &&
          marker[1]!.length >= fence.length &&
          marker[2]!.trim().isEmpty) {
        fence = null;
      }
      continue;
    }
    if (fence != null || !value.startsWith('<!-- orbit:section ')) continue;
    final end = LinkedSection.endLine(values, i);
    if (end == null) continue;
    final parsed = LinkedSection.parse(
      source.substring(lines[i].start, lines[end].end),
    );
    if (parsed != null) {
      result.add(SectionUse(lines[i].start, lines[end].end, parsed));
      i = end;
    }
  }
  return result;
}
