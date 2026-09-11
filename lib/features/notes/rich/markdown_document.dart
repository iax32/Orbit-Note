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
  });
  String source;
  final MarkdownBlockKind kind;
  final String prefix, suffix, language;
  final int level;
  final bool? checked;
  String get content =>
      source.substring(prefix.length, source.length - suffix.length);
  String replaceContent(String value) => '$prefix$value$suffix';
}

class MarkdownDocument {
  MarkdownDocument(this.blocks);
  final List<MarkdownBlock> blocks;
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

  static MarkdownDocument parse(String source) {
    final lines = RegExp(
      r'[^\n]*\n|[^\n]+$',
    ).allMatches(source).map((m) => m[0]!).toList();
    if (lines.isEmpty) {
      return MarkdownDocument([MarkdownBlock('', MarkdownBlockKind.text)]);
    }
    String text(int i) => lines[i].replaceFirst(RegExp(r'\r?\n$'), '');
    String ending(int i) => lines[i].substring(text(i).length);
    final blocks = <MarkdownBlock>[];
    var i = 0;
    while (i < lines.length) {
      final line = text(i), eol = ending(i);
      if (line.trim().isEmpty) {
        blocks.add(MarkdownBlock(lines[i++], MarkdownBlockKind.blank));
        continue;
      }
      // Frontmatter, HTML, reference definitions and unfamiliar extensions stay
      // literal. They never pass through a lossy Markdown renderer/serializer.
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
      final fence = RegExp(r'^ {0,3}(`{3,}|~{3,})([^\r\n]*)$').firstMatch(line);
      if (fence != null) {
        var end = i + 1;
        final closing = RegExp(
          '^ {0,3}${RegExp.escape(fence[1]![0])}{${fence[1]!.length},} *\$',
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
        r'^( {0,3}#{1,6} +)(.*?)( +#+ *)?$',
      ).firstMatch(line);
      if (heading != null) {
        blocks.add(
          MarkdownBlock(
            lines[i++],
            MarkdownBlockKind.heading,
            prefix: heading[1]!,
            suffix: '${heading[3] ?? ''}$eol',
            level: '#'.allMatches(heading[1]!).length,
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
            suffix: '$eol${lines[i + 1]}',
            level: text(i + 1).trim().startsWith('=') ? 1 : 2,
          ),
        );
        i += 2;
        continue;
      }
      final list = RegExp(
        r'^( *)([-+*]|\d+[.)]) +(\[([ xX])\] +)?',
      ).firstMatch(line);
      if (list != null) {
        blocks.add(
          MarkdownBlock(
            lines[i++],
            MarkdownBlockKind.list,
            prefix: list[0]!,
            suffix: eol,
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
      if (line.startsWith('> ')) {
        blocks.add(
          MarkdownBlock(
            lines[i++],
            MarkdownBlockKind.quote,
            prefix: '> ',
            suffix: eol,
          ),
        );
        continue;
      }
      if (RegExp(r'^\s*(?:<|\[.*\]:|\{\{|:::|\t| {4})').hasMatch(line)) {
        blocks.add(MarkdownBlock(lines[i++], MarkdownBlockKind.raw));
        continue;
      }
      // Soft-wrapped prose is one editable paragraph. Leave boundary syntax alone.
      var end = i + 1;
      while (end < lines.length &&
          text(end).trim().isNotEmpty &&
          !RegExp(
            r'^\s*(?:#|>|[-+*] |\d+[.)] |`|~|\$|\||!\[|<|\[.*\]:|:::|\{\{)',
          ).hasMatch(text(end)) &&
          !(end + 1 < lines.length &&
              (MarkdownTable.isSeparator(text(end + 1)) ||
                  RegExp(r'^ {0,3}(=+|-+) *$').hasMatch(text(end + 1))))) {
        end++;
      }
      blocks.add(
        MarkdownBlock(
          lines.sublist(i, end).join(),
          MarkdownBlockKind.text,
          suffix: ending(end - 1),
        ),
      );
      i = end;
    }
    if (blocks.last.kind == MarkdownBlockKind.blank) {
      blocks.add(MarkdownBlock('', MarkdownBlockKind.text));
    }
    return MarkdownDocument(blocks);
  }
}

class MarkdownTable {
  MarkdownTable(
    this.rows,
    this.alignments, {
    this.eol = '\n',
    this.trailing = true,
  });
  final List<List<String>> rows;
  final List<String> alignments;
  final String eol;
  final bool trailing;
  int get columns => alignments.length;
  static List<String> cells(String line) {
    var value = line.trim();
    if (value.startsWith('|')) value = value.substring(1);
    if (value.endsWith('|') && !value.endsWith(r'\|')) {
      value = value.substring(0, value.length - 1);
    }
    final cells = <String>[];
    var start = 0;
    var ticks = false;
    for (var i = 0; i < value.length; i++) {
      if (value[i] == '\\') {
        i++;
        continue;
      }
      if (value[i] == '`') ticks = !ticks;
      if (value[i] == '|' && !ticks) {
        cells.add(value.substring(start, i).trim());
        start = i + 1;
      }
    }
    cells.add(value.substring(start).trim());
    return cells;
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
    );
  }

  String encode() =>
      [
        rows.first,
        alignments,
        ...rows.skip(1),
      ].map((r) => '| ${r.join(' | ')} |').join(eol) +
      (trailing ? eol : '');
  static String cellText(String value) => value
      .replaceAll(RegExp(r'\r?\n'), '<br>')
      .replaceAllMapped(RegExp(r'(?<!\\)\|'), (_) => r'\|');
}

/// A visible inline projection with a source boundary for every UTF-16 position.
/// Edits splice only the selected range, retaining untouched delimiters/links.
class InlineProjection {
  InlineProjection(this.source) {
    _parse(0, source.length, const {});
  }
  final String source;
  final _text = StringBuffer();
  final List<int> starts = [], ends = [];
  final List<Set<String>> styles = [];
  final _wrappers = <(int, int, int, int)>[];
  final _plainWiki = <(int, int)>[];
  static final _linkPattern = RegExp(
    r'\[([^\]\n]+)\]\((?:<[^>\n]+>|[^)\n]+)\)',
  );
  String get text => _text.toString();
  void _emit(int from, int to, Set<String> marks) {
    for (var i = from; i < to; i++) {
      _text.write(source[i]);
      starts.add(i);
      ends.add(i + 1);
      styles.add(marks);
    }
  }

  void _parse(int from, int to, Set<String> marks) {
    var i = from;
    while (i < to) {
      if (source[i] == '\\' && i + 1 < to) {
        _emit(i + 1, i + 2, marks);
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
          _emit(pipe >= 0 && pipe < end ? pipe + 1 : i + 2, end, {
            ...marks,
            'link',
          });
          i = end + 2;
          continue;
        }
      }
      final link = source[i] == '['
          ? _linkPattern.matchAsPrefix(source, i)
          : null;
      if (link != null && link.end <= to) {
        _wrappers.add((i, i + 1, i + 1 + link[1]!.length, i + link[0]!.length));
        _parse(i + 1, i + 1 + link[1]!.length, {...marks, 'link'});
        i += link[0]!.length;
        continue;
      }
      var matched = false;
      for (final (marker, style) in [
        ('***', 'boldItalic'),
        ('___', 'boldItalic'),
        ('**', 'bold'),
        ('__', 'bold'),
        ('~~', 'strike'),
        ('*', 'italic'),
        ('_', 'italic'),
        ('`', 'code'),
      ]) {
        if (!source.startsWith(marker, i)) continue;
        if (marker == '_' &&
            i > from &&
            RegExp(r'\w').hasMatch(source[i - 1])) {
          continue;
        }
        final end = source.indexOf(marker, i + marker.length);
        if (end <= i + marker.length || end + marker.length > to) continue;
        _wrappers.add((i, i + marker.length, end, end + marker.length));
        if (style == 'code') {
          _emit(i + marker.length, end, {...marks, style});
        } else {
          _parse(i + marker.length, end, {
            ...marks,
            if (style == 'boldItalic') ...{'bold', 'italic'} else style,
          });
        }
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
    if (outsideFormatting && start == end) {
      a = outsideOffset(start);
      b = a;
    }
    var insertion = next.substring(start, nextEnd);
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
