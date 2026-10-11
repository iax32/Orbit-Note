import 'package:flutter/services.dart';

/// Indent the selected lines without changing text outside the selection.
TextEditingValue indentCode(
  TextEditingValue value, {
  bool outdent = false,
  String unit = '  ',
}) {
  if (!_editable(value) || !['  ', '    ', '\t'].contains(unit)) return value;
  final text = value.text;
  final selection = value.selection;
  final start = text.lastIndexOf(
    '\n',
    selection.start == 0 ? 0 : selection.start - 1,
  );
  final first = selection.start == 0 ? 0 : start + 1;
  final last =
      !selection.isCollapsed &&
          selection.end > first &&
          text[selection.end - 1] == '\n'
      ? selection.end - 1
      : selection.end;
  final offsets = <int>[first];
  for (
    var at = text.indexOf('\n', first);
    at >= 0 && at < last;
    at = text.indexOf('\n', at + 1)
  ) {
    offsets.add(at + 1);
  }
  var next = text;
  var base = selection.baseOffset;
  var extent = selection.extentOffset;
  for (final offset in offsets.reversed) {
    final removed = outdent
        ? (text.startsWith('\t', offset)
              ? 1
              : RegExp(
                      '^ {1,${unit == '\t' ? 4 : unit.length}}',
                    ).firstMatch(text.substring(offset))?.end ??
                    0)
        : 0;
    final inserted = outdent ? '' : unit;
    next = next.replaceRange(offset, offset + removed, inserted);
    int move(int position) => position < offset
        ? position
        : position < offset + removed
        ? offset
        : position + inserted.length - removed;
    base = move(base);
    extent = move(extent);
  }
  return TextEditingValue(
    text: next,
    selection: TextSelection(baseOffset: base, extentOffset: extent),
  );
}

bool _editable(TextEditingValue v) =>
    v.selection.isValid &&
    v.selection.end <= v.text.length &&
    v.composing.isCollapsed;

List<({int start, int contentEnd, int end})> codeLines(String text) {
  final lines = <({int start, int contentEnd, int end})>[];
  var start = 0;
  for (final m in RegExp(r'\r\n|\n|\r').allMatches(text)) {
    lines.add((start: start, contentEnd: m.start, end: m.end));
    start = m.end;
  }
  lines.add((start: start, contentEnd: text.length, end: text.length));
  return lines;
}

(int, int) _selectedLines(
  TextEditingValue v,
  List<({int start, int contentEnd, int end})> lines,
) {
  int at(int offset) => lines.lastIndexWhere((l) => l.start <= offset);
  final first = at(v.selection.start);
  var last = at(v.selection.end);
  if (!v.selection.isCollapsed &&
      last > first &&
      lines[last].start == v.selection.end) {
    last--;
  }
  return (first, last);
}

/// Moves line contents; original line-ending slots and selection direction survive.
TextEditingValue moveCodeLines(TextEditingValue v, {required bool down}) {
  if (!_editable(v)) return v;
  final lines = codeLines(v.text);
  final (first, last) = _selectedLines(v, lines);
  if (down ? last == lines.length - 1 : first == 0) return v;
  final order = List<int>.generate(lines.length, (i) => i);
  final group = order.sublist(first, last + 1);
  order.removeRange(first, last + 1);
  order.insertAll(down ? first + 1 : first - 1, group);
  final result = StringBuffer();
  final starts = <int>[];
  for (var i = 0; i < lines.length; i++) {
    starts.add(result.length);
    final old = lines[order[i]];
    result.write(v.text.substring(old.start, old.contentEnd));
    result.write(v.text.substring(lines[i].contentEnd, lines[i].end));
  }
  int map(int offset) {
    // The final line's start may be the exclusive selection end.
    if (!v.selection.isCollapsed &&
        offset == v.selection.end &&
        offset == lines[last].end &&
        lines[last].end > lines[last].contentEnd) {
      final next = order.indexOf(last) + 1;
      return next < starts.length ? starts[next] : result.length;
    }
    final old = lines.lastIndexWhere((l) => l.start <= offset);
    return starts[order.indexOf(old)] +
        (offset - lines[old].start).clamp(
          0,
          lines[old].contentEnd - lines[old].start,
        );
  }

  return TextEditingValue(
    text: result.toString(),
    selection: TextSelection(
      baseOffset: map(v.selection.baseOffset),
      extentOffset: map(v.selection.extentOffset),
    ),
  );
}

TextEditingValue duplicateCodeLines(TextEditingValue v) {
  if (!_editable(v)) return v;
  final lines = codeLines(v.text);
  final (first, last) = _selectedLines(v, lines);
  final start = lines[first].start;
  final end = lines[last].end;
  final chunk = v.text.substring(start, end);
  final eol = RegExp(r'\r\n|\n|\r').firstMatch(v.text)?.group(0) ?? '\n';
  final prefix = lines[last].end == lines[last].contentEnd ? eol : '';
  final inserted = prefix + chunk;
  final nextStart = end + prefix.length;
  int map(int offset) => nextStart + offset - start;
  return TextEditingValue(
    text: v.text.replaceRange(end, end, inserted),
    selection: TextSelection(
      baseOffset: map(v.selection.baseOffset),
      extentOffset: map(v.selection.extentOffset),
    ),
  );
}

String? codeLineComment(String language) => switch (language.toLowerCase()) {
  'dart' ||
  'c' ||
  'cpp' ||
  'c++' ||
  'cs' ||
  'c#' ||
  'java' ||
  'javascript' ||
  'js' ||
  'typescript' ||
  'ts' ||
  'rust' ||
  'go' ||
  'swift' ||
  'kotlin' ||
  'php' => '//',
  'python' ||
  'py' ||
  'ruby' ||
  'bash' ||
  'sh' ||
  'powershell' ||
  'yaml' ||
  'yml' => '#',
  'sql' || 'lua' => '--',
  _ => null,
};

bool supportsCodeComments(String language) =>
    codeLineComment(language) != null ||
    ['html', 'xml', 'css', 'scss'].contains(language.toLowerCase());

/// Only explicit line-comment grammars: JSON/plain text remain untouched.
TextEditingValue toggleCodeComments(TextEditingValue v, String language) {
  final marker = codeLineComment(language);
  if (!_editable(v)) return v;
  if (marker == null) {
    final pair = switch (language.toLowerCase()) {
      'html' || 'xml' => ('<!--', '-->'),
      'css' || 'scss' => ('/*', '*/'),
      _ => null,
    };
    if (pair == null) return v;
    final lines = codeLines(v.text);
    final (first, last) = _selectedLines(v, lines);
    final start = lines[first].start;
    final end = lines[last].contentEnd;
    final body = v.text.substring(start, end);
    final leading = RegExp(r'^[ \t]*').firstMatch(body)!.end;
    final core = body.substring(leading);
    String next;
    if (core.startsWith('${pair.$1} ') && core.endsWith(' ${pair.$2}')) {
      final content = core.substring(
        pair.$1.length + 1,
        core.length - pair.$2.length - 1,
      );
      if (content.contains(pair.$1) || content.contains(pair.$2)) {
        throw const FormatException(
          'Nested comment delimiters need manual editing.',
        );
      }
      next = body.substring(0, leading) + content;
    } else {
      if (core.contains(pair.$1) ||
          core.contains(pair.$2) ||
          (pair.$1 == '<!--' && core.contains('--'))) {
        throw const FormatException(
          'Existing comment delimiters need manual editing.',
        );
      }
      next = '${body.substring(0, leading)}${pair.$1} $core ${pair.$2}';
    }
    final text = v.text.replaceRange(start, end, next);
    final reversed = v.selection.baseOffset > v.selection.extentOffset;
    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: reversed ? start + next.length : start,
        extentOffset: reversed ? start : start + next.length,
      ),
    );
  }
  final lines = codeLines(v.text);
  final (first, last) = _selectedLines(v, lines);
  final edits = <(int, int, String)>[];
  final nonblank = lines
      .sublist(first, last + 1)
      .where((l) => v.text.substring(l.start, l.contentEnd).trim().isNotEmpty)
      .toList();
  final remove = nonblank.every(
    (l) =>
        v.text.substring(l.start, l.contentEnd).trimLeft().startsWith(marker),
  );
  for (final l in nonblank) {
    final content = v.text.substring(l.start, l.contentEnd);
    final at = l.start + RegExp(r'^[ \t]*').firstMatch(content)!.end;
    final count = remove
        ? marker.length + (v.text.startsWith(' ', at + marker.length) ? 1 : 0)
        : 0;
    edits.add((at, at + count, remove ? '' : '$marker '));
  }
  var text = v.text;
  var base = v.selection.baseOffset;
  var extent = v.selection.extentOffset;
  for (final (start, end, insert) in edits.reversed) {
    text = text.replaceRange(start, end, insert);
    int map(int p) => p < start
        ? p
        : p < end
        ? start + insert.length
        : p + insert.length - (end - start);
    base = map(base);
    extent = map(extent);
  }
  return TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: base, extentOffset: extent),
  );
}

TextEditingValue wrapCodeSelection(
  TextEditingValue v,
  String open,
  String close,
) {
  if (!_editable(v)) return v;
  final s = v.selection;
  final text = v.text.replaceRange(
    s.start,
    s.end,
    '$open${v.text.substring(s.start, s.end)}$close',
  );
  return TextEditingValue(
    text: text,
    selection: TextSelection(
      baseOffset: s.baseOffset + open.length,
      extentOffset: s.extentOffset + open.length,
    ),
  );
}

TextEditingValue deleteCodeLines(TextEditingValue v) {
  if (!_editable(v)) return v;
  final lines = codeLines(v.text);
  final (first, last) = _selectedLines(v, lines);
  var start = lines[first].start;
  final end = lines[last].end;
  if (last == lines.length - 1 && first > 0) {
    start = lines[first - 1].contentEnd;
  }
  final text = v.text.replaceRange(start, end, '');
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: start),
  );
}

/// Explicit whole-draft cleanup; never runs automatically on save.
TextEditingValue trimCodeWhitespace(TextEditingValue v) {
  if (!_editable(v)) return v;
  var text = v.text;
  var base = v.selection.baseOffset, extent = v.selection.extentOffset;
  for (final line in codeLines(v.text).reversed) {
    final tail = RegExp(
      r'[ \t]+$',
    ).firstMatch(v.text.substring(line.start, line.contentEnd));
    if (tail == null) continue;
    final start = line.start + tail.start, end = line.contentEnd;
    text = text.replaceRange(start, end, '');
    int map(int p) => p <= start
        ? p
        : p <= end
        ? start
        : p - (end - start);
    base = map(base);
    extent = map(extent);
  }
  return TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: base, extentOffset: extent),
  );
}

int codeLineAt(List<({int start, int contentEnd, int end})> lines, int offset) {
  var low = 0, high = lines.length - 1;
  while (low < high) {
    final middle = (low + high + 1) ~/ 2;
    if (lines[middle].start <= offset) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  return low;
}

TextEditingValue newlineCode(TextEditingValue v, {String unit = '  '}) {
  if (!_editable(v)) return v;
  final at = v.selection.start;
  final line = codeLines(v.text).lastWhere((l) => l.start <= at);
  final before = v.text.substring(line.start, at);
  final indent = RegExp(r'^[ \t]*').firstMatch(before)!.group(0)!;
  final eol = RegExp(r'\r\n|\n|\r').firstMatch(v.text)?.group(0) ?? '\n';
  final open = before.trimRight().endsWith('{');
  final paired = open && v.text.substring(v.selection.end).startsWith('}');
  final insert = '$eol$indent${open ? unit : ''}${paired ? '$eol$indent' : ''}';
  return TextEditingValue(
    text: v.text.replaceRange(at, v.selection.end, insert),
    selection: TextSelection.collapsed(
      offset: at + eol.length + indent.length + (open ? unit.length : 0),
    ),
  );
}
