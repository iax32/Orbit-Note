import 'media_clipboard.dart';
import 'dart:convert';
// ignore: implementation_imports
import 'package:markdown/src/util.dart' as markdown_util;
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

/// Converts the small, portable HTML subset commonly placed on the clipboard
/// by browsers and office editors into Markdown without touching raw HTML that
/// the editor does not understand. The converter is deliberately conservative:
/// unknown tags are removed, but their text remains editable and recoverable.
String htmlToMarkdown(String html) {
  if (html.trim().isEmpty || !RegExp(r'<[a-zA-Z][^>]*>').hasMatch(html)) {
    return html;
  }

  var value = html
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
      .replaceAll(
        RegExp(
          r'<(script|style|noscript)[^>]*>[\s\S]*?</\1>',
          caseSensitive: false,
        ),
        '',
      );

  // Protect code from prose whitespace normalization and subsequent tag passes.
  var marker = '\u0000orbit-code-';
  while (html.contains(marker) || _decodeEntities(html).contains(marker)) {
    marker += '-';
  }
  final protected = <String>[];
  String protect(String text) {
    final token = '$marker${protected.length}\u0000';
    protected.add(text);
    return token;
  }

  String codeText(String text) => _decodeEntities(
    text.replaceAll(RegExp(r'<[^>]+>'), ''),
  ).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  String delimiter(String text, int minimum) {
    var length = minimum;
    for (final run in RegExp(r'`+').allMatches(text)) {
      if (run[0]!.length >= length) length = run[0]!.length + 1;
    }
    return '`' * length;
  }

  value = value.replaceAllMapped(
    RegExp(r'<pre(?:\s[^>]*)?>([\s\S]*?)</pre>', caseSensitive: false),
    (m) {
      var code = codeText(m[1]!);
      if (code.startsWith('\n')) code = code.substring(1);
      final fence = delimiter(code, 3);
      return '\n\n${protect('$fence\n$code${code.endsWith('\n') ? '' : '\n'}$fence')}\n\n';
    },
  );
  value = value.replaceAllMapped(
    RegExp(r'<code(?:\s[^>]*)?>([\s\S]*?)</code>', caseSensitive: false),
    (m) {
      final code = codeText(m[1]!).replaceAll('\n', ' ');
      final fence = delimiter(code, 1);
      final pad =
          code.startsWith('`') ||
              code.endsWith('`') ||
              code.startsWith(' ') &&
                  code.endsWith(' ') &&
                  code.trim().isNotEmpty
          ? ' '
          : '';
      return protect('$fence$pad$code$pad$fence');
    },
  );

  value = value
      .replaceAllMapped(
        RegExp(r'<h([1-6])(?:\s[^>]*)?>', caseSensitive: false),
        (m) => '\n\n${'#' * int.parse(m[1]!)} ',
      )
      .replaceAll(RegExp(r'</h[1-6\s]*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<hr\s*/?>', caseSensitive: false), '\n\n---\n\n')
      .replaceAll(
        RegExp(r'<(strong|b)(?:\s[^>]*)?>', caseSensitive: false),
        '**',
      )
      .replaceAll(RegExp(r'</(strong|b)>', caseSensitive: false), '**')
      .replaceAll(RegExp(r'<(em|i)(?:\s[^>]*)?>', caseSensitive: false), '*')
      .replaceAll(RegExp(r'</(em|i)>', caseSensitive: false), '*')
      .replaceAll(
        RegExp(r'<(del|s|strike)(?:\s[^>]*)?>', caseSensitive: false),
        '~~',
      )
      .replaceAll(RegExp(r'</(del|s|strike)>', caseSensitive: false), '~~')
      .replaceAll(RegExp(r'<(u|ins)(?:\s[^>]*)?>', caseSensitive: false), '<u>')
      .replaceAll(RegExp(r'</(u|ins)>', caseSensitive: false), '</u>')
      .replaceAll(RegExp(r'<code(?:\s[^>]*)?>', caseSensitive: false), '`')
      .replaceAll(RegExp(r'</code>', caseSensitive: false), '`')
      .replaceAll(
        RegExp(r'<blockquote(?:\s[^>]*)?>', caseSensitive: false),
        '\n\n> ',
      )
      .replaceAll(RegExp(r'</blockquote>', caseSensitive: false), '\n\n')
      .replaceAllMapped(
        RegExp(
          r"""<a\s+[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)</a>""",
          caseSensitive: false,
        ),
        (m) => '[${m[2]}](${m[1]})',
      )
      .replaceAllMapped(
        RegExp(
          r"""<img\s+[^>]*src\s*=\s*["']([^"']+)["'][^>]*>""",
          caseSensitive: false,
        ),
        (m) {
          final alt =
              RegExp(
                r"""\balt\s*=\s*["']([^"']*)["']""",
                caseSensitive: false,
              ).firstMatch(m[0]!)?.group(1) ??
              '';
          return '![$alt](${m[1]})';
        },
      );

  // Convert simple HTML tables into pipe tables. Cell tags are handled before
  // stripping the remaining markup so text and links stay intact.
  value = value.replaceAllMapped(
    RegExp(r'<table(?:\s[^>]*)?>\s*([\s\S]*?)</table>', caseSensitive: false),
    (table) => _tableToMarkdown(table[1]!),
  );

  value = value
      .replaceAllMapped(
        // Browser lists commonly wrap each item in a paragraph. Its opening
        // block boundary belongs after the bullet, not on a separate empty item.
        RegExp(
          r'<li(?:\s[^>]*)?>\s*(?:<(?:p|div)(?:\s[^>]*)?>\s*)*',
          caseSensitive: false,
        ),
        (_) => '\n- ',
      )
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</?(ul|ol)(?:\s[^>]*)?>', caseSensitive: false),
        '\n\n',
      )
      .replaceAll(
        RegExp(
          r'</?(p|div|section|article|header|footer|tr)(?:\s[^>]*)?>',
          caseSensitive: false,
        ),
        '\n\n',
      )
      .replaceAll(
        RegExp(r'</?(td|th)(?:\s[^>]*)?>', caseSensitive: false),
        ' | ',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .splitMapJoin(RegExp(r'\n[ \t]+\n'), onMatch: (_) => '\n\n');

  value = _decodeEntities(value)
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAllMapped(RegExp(r'[^\S\n]{2,}'), (m) => ' ')
      .replaceAllMapped(RegExp(r'\n{3,}'), (_) => '\n\n')
      .trim();
  final compact = <String>[];
  for (final line in value.split('\n')) {
    if (line.startsWith('- ') && compact.isNotEmpty && compact.last.isEmpty) {
      if (compact.length > 1 && compact[compact.length - 2].startsWith('- ')) {
        compact.removeLast();
      }
    }
    compact.add(line);
  }
  var result = compact.join('\n');
  for (var i = 0; i < protected.length; i++) {
    result = result.replaceAll('$marker$i\u0000', protected[i]);
  }
  return result;
}

String _tableToMarkdown(String source) {
  final rows = <List<String>>[];
  for (final row in RegExp(
    r'<tr(?:\s[^>]*)?>([\s\S]*?)</tr>',
    caseSensitive: false,
  ).allMatches(source)) {
    final cells =
        RegExp(r'<t[hd](?:\s[^>]*)?>([\s\S]*?)</t[hd]>', caseSensitive: false)
            .allMatches(row[1]!)
            .map((m) => htmlToMarkdown(m[1]!).replaceAll('|', '\\|').trim())
            .toList();
    if (cells.isNotEmpty) rows.add(cells);
  }
  if (rows.isEmpty) return source;
  final width = rows.fold<int>(0, (n, row) => n > row.length ? n : row.length);
  for (final row in rows) {
    row.addAll(List.filled(width - row.length, ''));
  }
  final lines = <String>[
    '| ${rows.first.join(' | ')} |',
    '| ${List.filled(width, '---').join(' | ')} |',
  ];
  lines.addAll(rows.skip(1).map((row) => '| ${row.join(' | ')} |'));
  return '\n\n${lines.join('\n')}\n\n';
}

String _decodeEntities(String value) =>
    markdown_util.decodeHtmlCharacters(value).replaceAll('\u00a0', ' ');

/// Reads rich clipboard data when available, with a plain-text fallback.
/// `text/html` is optional on Linux/Windows and can fail independently of
/// `text/plain`, so each format is isolated and never blocks ordinary paste.
Future<String?> readClipboardHtml({String? plainText}) async {
  for (final read in <Future<String?> Function()>[
    () async => (await Clipboard.getData('text/html'))?.text,
    () => Pasteboard.html,
  ]) {
    try {
      final raw = await read();
      final value = raw == null ? null : clipboardHtmlFragment(raw);
      // Flutter's Windows provider can return plain text for unsupported MIME
      // types. Never interpret authored literal HTML as a separate rich format.
      if (value != null &&
          value != plainText &&
          RegExp(r'<[a-zA-Z][^>]*>').hasMatch(value)) {
        return value;
      }
    } catch (_) {
      /* An optional format must not block plain paste. */
    }
  }
  return null;
}

/// CF_HTML offsets count UTF-8 bytes, not Dart's UTF-16 character positions.
String clipboardHtmlFragment(String value) {
  if (!RegExp(r'^\s*Version:\s*\d', caseSensitive: false).hasMatch(value)) {
    return value;
  }
  final bytes = utf8.encode(value);
  int? offset(String key) => int.tryParse(
    RegExp(
          '^$key:[ \\t]*([0-9]+)',
          multiLine: true,
        ).firstMatch(value)?.group(1) ??
        '',
  );
  for (final pair in [
    ('StartFragment', 'EndFragment'),
    ('StartHTML', 'EndHTML'),
  ]) {
    final start = offset(pair.$1), end = offset(pair.$2);
    if (start != null &&
        end != null &&
        start >= 0 &&
        end >= start &&
        end <= bytes.length) {
      try {
        return utf8.decode(bytes.sublist(start, end));
      } on FormatException {
        /* Try marker fallback. */
      }
    }
  }
  const startMarker = '<!--StartFragment-->', endMarker = '<!--EndFragment-->';
  final start = value.indexOf(startMarker), end = value.indexOf(endMarker);
  if (start >= 0 && end >= start + startMarker.length) {
    return value.substring(start + startMarker.length, end);
  }
  final tag = value.indexOf('<');
  return tag < 0 ? '' : value.substring(tag).replaceAll(RegExp(r'\x00+$'), '');
}

Future<String?> readMarkdownClipboard({
  bool preferHtml = true,
  bool interpretOrbitData = true,
}) async {
  String? plain;
  try {
    plain = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    final canvas = interpretOrbitData && plain != null
        ? canvasClipboardMarkdown(plain)
        : null;
    if (canvas != null) return canvas;
  } catch (_) {}
  if (preferHtml) {
    final html = await readClipboardHtml(plainText: plain);
    if (html != null) {
      try {
        return htmlToMarkdown(html);
      } catch (_) {
        return plain;
      }
    }
  }
  return plain;
}
