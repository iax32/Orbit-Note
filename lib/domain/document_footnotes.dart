import 'writing_structure.dart';

class FootnoteDefinition {
  const FootnoteDefinition(this.id, this.start, this.end, this.text);
  final String id, text;
  final int start, end;
}

class FootnoteReference {
  const FootnoteReference(this.id, this.start, this.end);
  final String id;
  final int start, end;
}

class DocumentFootnotes {
  DocumentFootnotes(this.source) {
    _scan();
  }
  final String source;
  final definitions = <FootnoteDefinition>[];
  final references = <FootnoteReference>[];
  void _scan() {
    final lines = RegExp(r'[^\n]*\n|[^\n]+$').allMatches(source).toList();
    final literal = writingLiteralRanges(source);
    final code = codeSpanRanges(source);
    String? fence;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i][0]!;
      if (literal.any((r) => lines[i].start >= r.$1 && lines[i].start < r.$2)) {
        continue;
      }
      final marker = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)').firstMatch(line);
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
      if (fence != null ||
          line.startsWith('<!--') ||
          line.startsWith('    ') ||
          line.startsWith('\t')) {
        continue;
      }
      final definition = RegExp(
        r'^ {0,3}\[\^([^\]\s]+)\]:[ \t]*(.*)\r?\n?$',
      ).firstMatch(line);
      if (definition != null) {
        var end = i;
        final body = <String>[definition[2]!.trimRight()];
        while (end + 1 < lines.length) {
          final next = lines[end + 1][0]!;
          if (next.startsWith('    ') || next.startsWith('\t')) {
            body.add(
              next
                  .replaceFirst(RegExp(r'^(?: {4}|\t)'), '')
                  .replaceFirst(RegExp(r'\r?\n$'), ''),
            );
            end++;
          } else if (next.trim().isEmpty &&
              end + 2 < lines.length &&
              RegExp(r'^(?: {4}|\t)').hasMatch(lines[end + 2][0]!)) {
            body.add('');
            end++;
          } else {
            break;
          }
        }
        definitions.add(
          FootnoteDefinition(
            definition[1]!,
            lines[i].start,
            lines[end].end,
            body.join('\n'),
          ),
        );
        for (var k = i; k <= end; k++) {
          final value = lines[k][0]!;
          final skip = k == i ? value.indexOf(':') + 1 : 0;
          _addReferences(value, lines[k].start, code, skip: skip);
        }
        i = end;
        continue;
      }
      _addReferences(line, lines[i].start, code);
    }
  }

  void _addReferences(
    String line,
    int offset,
    List<(int, int)> code, {
    int skip = 0,
  }) {
    for (final m in RegExp(r'\[\^([^\]\s]+)\]').allMatches(line)) {
      if (m.start < skip) continue;
      var escapes = 0;
      for (var at = m.start - 1; at >= 0 && line[at] == '\\'; at--) {
        escapes++;
      }
      if (escapes.isOdd ||
          code.any((c) => offset + m.start >= c.$1 && offset + m.end <= c.$2)) {
        continue;
      }
      references.add(
        FootnoteReference(m[1]!, offset + m.start, offset + m.end),
      );
    }
  }

  Set<String> get ids => {
    ...references.map((r) => r.id),
    ...definitions.map((d) => d.id),
  };
  String save(String id, String text, {String? renamedId}) {
    final nextId = renamedId ?? id;
    if (!RegExp(r'^[^\[\]\s:]+$').hasMatch(nextId) ||
        nextId.length > 100 ||
        text.length > 100000) {
      throw ArgumentError(
        'Use a short identifier without spaces/brackets and a definition up to 100,000 characters.',
      );
    }
    final found = definitions.where((d) => d.id == id).toList();
    if (found.length > 1) {
      throw StateError('Duplicate definitions need repair in Source.');
    }
    if (nextId != id && ids.contains(nextId)) {
      throw StateError('That footnote identifier already exists.');
    }
    final eol = source.contains('\r\n') ? '\r\n' : '\n';
    if (nextId != id) {
      final ownReferences = DocumentFootnotes(
        text,
      ).references.where((r) => r.id == id).toList();
      for (final r in ownReferences.reversed) {
        text = text.replaceRange(r.start, r.end, '[^$nextId]');
      }
    }
    final parts = text.replaceAll('\r\n', '\n').split('\n');
    final encoded =
        '[^$nextId]: ${parts.first}$eol${parts.skip(1).map((l) => '    $l$eol').join()}';
    final edits = <({int start, int end, String value})>[];
    if (found.isNotEmpty) {
      edits.add((
        start: found.single.start,
        end: found.single.end,
        value: encoded,
      ));
    } else {
      validateWritingAppend(source);
      edits.add((
        start: source.length,
        end: source.length,
        value: '$eol$eol$encoded',
      ));
    }
    if (nextId != id) {
      for (final r in references.where((r) => r.id == id)) {
        if (found.isNotEmpty &&
            r.start >= found.single.start &&
            r.end <= found.single.end) {
          continue;
        }
        edits.add((start: r.start, end: r.end, value: '[^$nextId]'));
      }
    }
    edits.sort((a, b) => b.start.compareTo(a.start));
    var result = source;
    for (final e in edits) {
      result = result.replaceRange(e.start, e.end, e.value);
    }
    return result;
  }
}
