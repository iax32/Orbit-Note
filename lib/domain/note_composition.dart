/// Readable Markdown layout extensions. Unsupported or incomplete structures
/// stay literal; layouts never own copies of linked workspace objects.
class NoteLayoutFence {
  String? _fence;
  bool get open => _fence != null;
  bool outside(String line) {
    final fence = _fence;
    if (fence != null) {
      if (RegExp(
        '^ {0,3}${RegExp.escape(fence[0])}{${fence.length},}[ \\t]*\$',
      ).hasMatch(line)) {
        _fence = null;
      }
      return false;
    }
    _fence = RegExp(r'^ {0,3}(`{3,}|~{3,})').firstMatch(line)?[1];
    return _fence == null;
  }
}

class NoteColumns {
  const NoteColumns(this.parts, this.eol, this.offsets);
  final List<String> parts;
  final String eol;
  final List<int> offsets;
  static final opening = RegExp(r'^<!-- orbit:columns v=1 -->$');
  static const divider = '<!-- orbit:column -->';
  static const closing = '<!-- /orbit:columns -->';
  static int? endLine(List<String> lines, int start) {
    final fence = NoteLayoutFence();
    var size = lines[start].length;
    for (
      var end = start + 1;
      end < lines.length && end < start + 10000;
      end++
    ) {
      size += lines[end].length;
      if (size > 200000) return null;
      final line = lines[end].replaceFirst(RegExp(r'\r?\n$'), '');
      if (!fence.outside(line)) continue;
      if (opening.hasMatch(line)) return null;
      if (line == closing) return end;
    }
    return null;
  }

  static NoteColumns? parse(String source) {
    if (source.length > 200000) return null;
    final lines = source.split('\n');
    String clean(String s) =>
        s.endsWith('\r') ? s.substring(0, s.length - 1) : s;
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    if (lines.length < 4 ||
        lines.length > 10000 ||
        !opening.hasMatch(clean(lines.first)) ||
        clean(lines.last) != closing) {
      return null;
    }
    final parts = <String>[];
    var position = lines.first.length + 1;
    final offsets = <int>[position];
    final body = StringBuffer();
    final fence = NoteLayoutFence();
    for (var i = 1; i < lines.length - 1; i++) {
      position += lines[i].length + 1;
      final line = clean(lines[i]);
      if (fence.outside(line)) {
        if (opening.hasMatch(line) || line == closing) return null;
        if (line == divider) {
          parts.add(body.toString());
          offsets.add(position);
          body.clear();
          continue;
        }
      }
      body.write('${lines[i]}\n');
    }
    if (fence.open) return null;
    parts.add(body.toString());
    if (parts.length < 2 || parts.length > 3) return null;
    return NoteColumns(
      parts,
      lines.first.endsWith('\r') ? '\r\n' : '\n',
      offsets,
    );
  }

  static String create(List<String> parts, {String eol = '\n'}) {
    final body = parts
        .map((p) => p.endsWith('\n') ? p : '$p$eol')
        .join('$divider$eol');
    final result = '<!-- orbit:columns v=1 -->$eol$body$closing$eol';
    if (parse(result) == null) {
      throw const FormatException(
        'Use two or three columns without nested layout markers or unfinished code fences.',
      );
    }
    return result;
  }

  String replace(int index, String value) {
    final next = List<String>.of(parts)..[index] = value;
    return create(next, eol: eol);
  }

  String get stacked => parts.join(eol);
}

class NoteObjectBlock {
  const NoteObjectBlock(this.id, this.label);
  final String id, label;
  static final opening = RegExp(r'^<!-- orbit:object v=1 -->$');
  static const closing = '<!-- /orbit:object -->';
  static NoteObjectBlock? parse(String source) {
    final m = RegExp(
      r'^<!-- orbit:object v=1 -->\r?\n\[([^\]\r\n]*)\]\(orbit-object:([A-Za-z0-9_-]{1,100})\)\r?\n<!-- /orbit:object -->(?:\r?\n)?$',
    ).firstMatch(source);
    return m == null ? null : NoteObjectBlock(m[2]!, m[1]!);
  }

  String encode({String eol = '\n'}) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(id)) {
      throw const FormatException('Invalid object reference.');
    }
    final title = label.replaceAll(RegExp(r'[\[\]\r\n]'), ' ').trim();
    return '<!-- orbit:object v=1 -->$eol[${title.isEmpty ? 'Linked object' : title}](orbit-object:$id)$eol$closing$eol';
  }
}

/// Explicit conversion of complete prose/list blocks; inline link markup is
/// retained. Structured/unknown blocks must be edited through their own tools.
String convertProseBlocks(String source, String kind) {
  final eol = source.contains('\r\n') ? '\r\n' : '\n';
  final lines = source.split(RegExp(r'\r?\n'));
  if (lines.any(
    (l) => RegExp(r'^\s*(?:<!--|```|~~~|\|\s*|\$\$|---\s*$)').hasMatch(l),
  )) {
    throw const FormatException(
      'Select ordinary paragraphs or list items, without structured blocks.',
    );
  }
  if (kind == 'Table') {
    if (source.contains('|')) {
      throw const FormatException(
        'This selection contains pipe characters or labelled wiki links. Use the table editor to preserve them.',
      );
    }
    final rows = source.trim().split(RegExp(r'\r?\n\s*\r?\n'));
    final escaped = rows.map(
      (p) => p.replaceAll('|', r'\|').replaceAll(RegExp(r'\r?\n'), '<br>'),
    );
    return '| Content |$eol| --- |$eol${escaped.map((p) => '| $p |').join(eol)}$eol';
  }
  final body = lines
      .map((line) {
        if (line.trim().isEmpty) return kind == 'Callout' ? '>' : '';
        final plain = line.replaceFirst(
          RegExp(r'^\s*(?:[-*+]\s+(?:\[[ xX]\]\s+)?|\d+[.)]\s+|>\s*)'),
          '',
        );
        return switch (kind) {
          'Checklist' => '- [ ] $plain',
          'Callout' => '> $plain',
          'Paragraphs' => plain,
          _ => throw const FormatException('Unsupported conversion.'),
        };
      })
      .join(eol);
  return kind == 'Callout' ? '> [!NOTE]$eol$body' : body;
}
