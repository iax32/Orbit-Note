import 'markdown_document.dart';

/// Source coordinates for the plain text shown by table/callout editing fields.
/// Unlike inline prose, these fields expose Markdown delimiters literally.
class StructuredTextProjection {
  StructuredTextProjection._(this.source, this.cell, this.eol);
  final String source;
  final bool cell;
  final String eol;
  final _text = StringBuffer();
  final starts = <int>[], ends = <int>[];
  String get text => _text.toString();
  void _emit(String value, int a, int b) {
    _text.write(value);
    starts.add(a);
    ends.add(b);
  }

  factory StructuredTextProjection.cell(String source) {
    final result = StructuredTextProjection._(source, true, '\n');
    var i = 0;
    while (i < source.length) {
      if (source[i] == '\\') {
        var end = i;
        while (end < source.length && source[end] == '\\') {
          end++;
        }
        if (end < source.length && source[end] == '|' && (end - i).isOdd) {
          while (i + 1 < end) {
            result._emit('\\', i, i + 2);
            i += 2;
          }
          result._emit('|', i, end + 1);
          i = end + 1;
          continue;
        }
        while (i < end) {
          result._emit(source[i], i, i + 1);
          i++;
        }
        continue;
      }
      result._emit(source[i], i, i + 1);
      i++;
    }
    return result;
  }

  factory StructuredTextProjection.calloutBody(String source, {String? eol}) {
    final result = StructuredTextProjection._(
      source,
      false,
      eol ?? (source.contains('\r\n') ? '\r\n' : '\n'),
    );
    final lines = RegExp(r'[^\n]*\n|[^\n]+$').allMatches(source).toList();
    int contentStart(RegExpMatch line) {
      final raw = line[0]!;
      return line.start +
          (raw.startsWith('> ')
              ? 2
              : raw.startsWith('>')
              ? 1
              : 0);
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final raw = line[0]!.replaceFirst(RegExp(r'\r?\n$'), '');
      final end = line.start + raw.length;
      for (var j = contentStart(line); j < end; j++) {
        result._emit(source[j], j, j + 1);
      }
      if (i + 1 < lines.length) {
        result._emit('\n', end, contentStart(lines[i + 1]));
      }
    }
    return result;
  }

  int sourceOffset(int visible, {bool end = false}) {
    if (starts.isEmpty) return source.length;
    if (visible <= 0) return starts.first;
    if (visible >= starts.length) return ends.last;
    return end ? ends[visible - 1] : starts[visible];
  }

  int visibleOffset(int raw) {
    var low = 0, high = ends.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (ends[mid] <= raw) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  String edit(String next) {
    final old = text;
    if (next == old) return source;
    if (cell) return MarkdownTable.cellText(next);
    if (starts.isEmpty) {
      return '> ${next.replaceAll(RegExp(r'\r\n|[\r\n]'), '$eol> ')}$eol';
    }
    var a = 0, b = old.length, end = next.length;
    while (a < b && a < end && old[a] == next[a]) {
      a++;
    }
    while (b > a && end > a && old[b - 1] == next[end - 1]) {
      b--;
      end--;
    }
    final inserted = next
        .substring(a, end)
        .replaceAll(RegExp(r'\r\n|[\r\n]'), '$eol> ');
    if (a == b &&
        a < old.length &&
        (a == 0 || old[a - 1] == '\n') &&
        inserted.endsWith('$eol> ')) {
      // Insert complete lines before the existing line's quote prefix; keep the
      // original prefix attached to its original text.
      final raw = sourceOffset(a);
      final lineStart = raw == 0 ? 0 : source.lastIndexOf('\n', raw - 1) + 1;
      final lines = '> ${inserted.substring(0, inserted.length - 2)}';
      return _keepQuoted(source.replaceRange(lineStart, lineStart, lines));
    }
    return _keepQuoted(
      source.replaceRange(
        sourceOffset(a),
        sourceOffset(b, end: true),
        inserted,
      ),
    );
  }

  String _keepQuoted(String value) =>
      value.replaceAllMapped(RegExp(r'^[^\r\n]+', multiLine: true), (m) {
        final line = m[0]!;
        // An authored unquoted blank can become text or join another line.
        // Quote newly nonempty lines so they remain owned by the callout.
        return line.startsWith('>') || line.trim().isEmpty ? line : '> $line';
      });
}

class CalloutSourceParts {
  CalloutSourceParts(this.source) {
    final first = RegExp(r'[^\n]*\n|[^\n]+$').firstMatch(source);
    headerEnd = first?.end ?? 0;
    final header = first?[0]?.replaceFirst(RegExp(r'\r?\n$'), '') ?? '';
    final match = RegExp(
      r'^>\s*\[!([a-zA-Z]+)\][ \t]*(.*)$',
    ).firstMatch(header);
    typeStart = match == null ? 0 : header.indexOf('[!') + 2;
    typeEnd = typeStart + (match?[1]?.length ?? 0);
    final title = match?[2] ?? '';
    titleStart = (match?.end ?? 0) - title.trimLeft().length;
    titleEnd = ((match?.end ?? 0) - title.length + title.trimRight().length)
        .clamp(titleStart, header.length);
    body = StructuredTextProjection.calloutBody(
      source.substring(headerEnd),
      eol: source.contains('\r\n') ? '\r\n' : '\n',
    );
  }
  final String source;
  late final int headerEnd, typeStart, typeEnd, titleStart, titleEnd;
  late final StructuredTextProjection body;
  String editBody(String next) {
    if (next == body.text) return source;
    final header = source.substring(0, headerEnd);
    final separator = header.endsWith('\n') ? '' : body.eol;
    return '$header$separator${body.edit(next)}';
  }
}
