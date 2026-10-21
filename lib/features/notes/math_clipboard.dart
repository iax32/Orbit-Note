// Clipboard-only normalization. Authored documents and literal/code paste never
// pass through this function: Markdown remains the durable editable format.
String normalizePastedMath(String source, {String Function(String)? protect}) {
  String keep(String value) => protect?.call(value) ?? value;
  final out = StringBuffer();
  final fence = RegExp(r' {0,3}(`{3,}|~{3,})([^\r\n]*)');
  final url = RegExp(r'(?:https?://|mailto:)[^\s<>]+');
  final inlineBoundary = RegExp(r'[\r\n$]');
  final nextClosers = <String, int>{};
  bool escaped(int offset) {
    var slashes = 0;
    for (var at = offset - 1; at >= 0 && source[at] == '\\'; at--) {
      slashes++;
    }
    return slashes.isOdd;
  }

  int closingAt(String delimiter, int start) {
    final cached = nextClosers[delimiter];
    if (cached != null && (cached < 0 || cached >= start)) return cached;
    var end = source.indexOf(delimiter, start);
    while (end >= 0 && escaped(end)) {
      end = source.indexOf(delimiter, end + delimiter.length);
    }
    nextClosers[delimiter] = end;
    return end;
  }

  String boundary(int offset, {required bool before}) {
    if (offset == 0 || offset == source.length) return '';
    var breaks = 0;
    var at = before ? offset - 1 : offset;
    while (at >= 0 && at < source.length && breaks < 2) {
      if (source[at] == '\n') {
        breaks++;
      } else if (source[at] != '\r') {
        break;
      }
      at += before ? -1 : 1;
    }
    return '\n' * (2 - breaks);
  }

  var i = 0;
  while (i < source.length) {
    if (i == 0 || source[i - 1] == '\n') {
      final opening = fence.matchAsPrefix(source, i);
      if (opening != null &&
          !(opening[1]!.startsWith('`') && opening[2]!.contains('`'))) {
        final delimiter = opening[1]!;
        final closing = RegExp(
          '^ {0,3}${RegExp.escape(delimiter[0])}{${delimiter.length},}[ \\t]*\\r?\$',
          multiLine: true,
        ).allMatches(source, opening.end).firstOrNull;
        final end = closing?.end ?? source.length;
        out.write(source.substring(i, end));
        i = end;
        continue;
      }
      // Indented code and reference destinations remain literal.
      if (source.startsWith('    ', i) ||
          source.startsWith('\t', i) ||
          RegExp(r' {0,3}\[[^\r\n]+\]:').matchAsPrefix(source, i) != null) {
        final end = source.indexOf('\n', i);
        if (end < 0) {
          out.write(source.substring(i));
          break;
        }
        out.write(source.substring(i, end + 1));
        i = end + 1;
        continue;
      }
    }
    // Link destinations, images and autolinks are authored references, not math.
    if (source.startsWith('](', i)) {
      var end = i + 2, depth = 1;
      while (end < source.length && depth > 0) {
        if (source[end] == '\\') {
          end += 2;
          continue;
        }
        if (source[end] == '(') depth++;
        if (source[end] == ')') depth--;
        end++;
      }
      end = end.clamp(0, source.length);
      out.write(source.substring(i, end));
      i = end;
      continue;
    }
    final link = (source[i] == 'h' || source[i] == 'm')
        ? url.matchAsPrefix(source, i)
        : null;
    if (link != null) {
      out.write(link[0]);
      i = link.end;
      continue;
    }
    if (source[i] == '`' || source[i] == r'$') {
      final char = source[i];
      var run = i + 1;
      while (run < source.length && source[run] == char) {
        run++;
      }
      final delimiter = source.substring(i, run);
      var close = source.indexOf(delimiter, run);
      while (close >= 0 &&
          (char == r'$' && escaped(close) ||
              source[close - 1] == char ||
              close + delimiter.length < source.length &&
                  source[close + delimiter.length] == char)) {
        close = source.indexOf(delimiter, close + delimiter.length);
      }
      final validDollar =
          char != r'$' ||
          delimiter.length == 2 ||
          close > run &&
              !RegExp(r'\s').hasMatch(source[run]) &&
              !RegExp(r'\s').hasMatch(source[close - 1]) &&
              !source.substring(run, close).contains(RegExp(r'[\r\n]'));
      if (close >= 0 && validDollar) {
        out.write(source.substring(i, close + delimiter.length));
        i = close + delimiter.length;
        continue;
      }
      out.write(delimiter);
      i = run;
      continue;
    }
    if (source[i] == '\\') {
      final display = source.startsWith(r'\[', i);
      final inline = source.startsWith(r'\(', i);
      if (display || inline) {
        final closing = display ? r'\]' : r'\)';
        final end = closingAt(closing, i + 2);
        final invalid = inline && end >= 0
            ? inlineBoundary.allMatches(source, i + 2).firstOrNull
            : null;
        if (end >= 0 && (invalid == null || invalid.start >= end)) {
          final tex = source.substring(i + 2, end).trim();
          if (tex.isNotEmpty) {
            out.write(
              display
                  ? '${boundary(i, before: true)}${keep('\$\$\n$tex\n\$\$')}${boundary(end + 2, before: false)}'
                  : keep('\$$tex\$'),
            );
            i = end + 2;
            continue;
          }
        }
      }
      // A literal double backslash must not open math at its second slash.
      final end = (i + 2).clamp(0, source.length);
      out.write(source.substring(i, end));
      i = end;
      continue;
    }
    out.write(source[i++]);
  }
  return out.toString();
}

/// Replaces complete browser math wrappers with a protected TeX token. Matching
/// balanced tags rather than a non-greedy span regex avoids duplicate KaTeX
/// MathML/visual output and leaves partial or unsupported fragments recoverable.
String protectClipboardMath(
  String html,
  String Function(String) protect,
  String Function(String) decode,
) {
  final tags = RegExp(
    r'''<!--[\s\S]*?-->|</?([\w:-]+)\b(?:[^>"']|"[^"]*"|'[^']*')*>''',
    caseSensitive: false,
  );
  final stack = <({String tag, int start, bool candidate, bool display})>[];
  final replacements = <({int start, int end, String text})>[];
  const voidTags = {
    'br',
    'img',
    'hr',
    'input',
    'meta',
    'link',
    'wbr',
    'source',
  };
  final attributes = RegExp(
    r'''(?:^|\s)([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))''',
  );
  String? attribute(String tag, String name) {
    for (final match in attributes.allMatches(tag)) {
      if (match[1]!.toLowerCase() == name) {
        return match.groups([2, 3, 4]).whereType<String>().firstOrNull;
      }
    }
    return null;
  }

  for (final token in tags.allMatches(html)) {
    final tag = token[1]?.toLowerCase();
    if (tag == null || voidTags.contains(tag)) continue;
    final raw = token[0]!;
    if (!raw.startsWith('</')) {
      if (raw.endsWith('/>')) continue;
      final classes = (attribute(raw, 'class') ?? '').split(RegExp(r'\s+'));
      final type = attribute(raw, 'type') ?? '';
      final display =
          classes.contains('katex-display') ||
          attribute(raw, 'display') == 'block' ||
          attribute(raw, 'display') == 'true' ||
          type.contains('mode=display');
      final candidate =
          classes.contains('katex') ||
          classes.contains('katex-display') ||
          tag == 'math' ||
          tag == 'mjx-container' ||
          tag == 'annotation' &&
              const {
                'application/x-tex',
                'application/x-latex',
              }.contains(attribute(raw, 'encoding')?.toLowerCase()) ||
          tag == 'script' && type.startsWith('math/tex') ||
          attribute(raw, 'data-latex') != null;
      stack.add((
        tag: tag,
        start: token.start,
        candidate: candidate,
        display: display,
      ));
      continue;
    }
    final index = stack.lastIndexWhere((entry) => entry.tag == tag);
    if (index < 0) continue;
    final entry = stack[index];
    stack.removeRange(index, stack.length);
    if (!entry.candidate) continue;
    final fragment = html.substring(entry.start, token.end);
    final opening = tags.matchAsPrefix(fragment)![0]!;
    String? tex = attribute(opening, 'data-latex');
    if (tag == 'script' || tag == 'annotation') {
      tex = html.substring(entry.start + opening.length, token.start);
    }
    if (tex == null) {
      final sources = <String>[];
      for (final annotation in RegExp(
        r'<annotation(?=\s|>)([^>]*)>([\s\S]*?)</annotation\s*>',
        caseSensitive: false,
      ).allMatches(fragment)) {
        final encoding = attribute(annotation[0]!, 'encoding')?.toLowerCase();
        if (encoding == 'application/x-tex' ||
            encoding == 'application/x-latex') {
          sources.add(annotation[2]!);
        }
      }
      // A wrapper containing independent equations is not one formula. Keep
      // its already recovered children instead of discarding all but the first.
      if (sources.length == 1) tex = sources.single;
    }
    if (tex == null || tex.trim().isEmpty) continue;
    // An outer display wrapper supersedes its nested inline/math representation.
    replacements.removeWhere((replacement) => replacement.start >= entry.start);
    tex = decode(tex).trim();
    final inCell = stack.any(
      (ancestor) => ancestor.tag == 'td' || ancestor.tag == 'th',
    );
    final inItem = stack.any((ancestor) => ancestor.tag == 'li');
    if (inCell || inItem) {
      tex = tex.replaceAll(RegExp(r'\r\n|\r|\n'), ' ');
      if (inCell) {
        // Use the existing Markdown table cell grammar: one quoting slash,
        // plus two for each authored slash. A TeX norm (\|) must not become
        // an absolute-value delimiter (|) when the table decodes its cells.
        tex = tex.replaceAllMapped(
          RegExp(r'(\\*)\|'),
          (match) => '${'\\' * (match[1]!.length * 2 + 1)}|',
        );
      }
    }
    final display =
        !inCell &&
        !inItem &&
        (entry.display || tex.contains(RegExp(r'[\r\n]')));
    replacements.add((
      start: entry.start,
      end: token.end,
      text: display
          ? '\n\n${protect('\$\$\n$tex\n\$\$')}\n\n'
          : protect('\$$tex\$'),
    ));
  }
  var result = html;
  for (final replacement in replacements.reversed) {
    result = result.replaceRange(
      replacement.start,
      replacement.end,
      replacement.text,
    );
  }
  return result;
}
