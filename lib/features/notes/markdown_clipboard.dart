import 'media_clipboard.dart';
import 'package:flutter/services.dart';

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

  // Preserve preformatted code before normal block handling.
  value = value.replaceAllMapped(
    RegExp(
      r'<pre(?:\s[^>]*)?>\s*(?:<code(?:\s[^>]*)?>)?([\s\S]*?)(?:</code>)?\s*</pre>',
      caseSensitive: false,
    ),
    (m) => '\n\n```\n${_decodeEntities(m[1]!)}\n```\n\n',
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
        RegExp(r'<li(?:\s[^>]*)?>', caseSensitive: false),
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
  return compact.join('\n');
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

String _decodeEntities(String value) => value
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAllMapped(RegExp(r'&#x([0-9a-f]+);', caseSensitive: false), (m) {
      final code = int.tryParse(m[1]!, radix: 16);
      return code == null ? m[0]! : String.fromCharCode(code);
    })
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m[1]!);
      return code == null ? m[0]! : String.fromCharCode(code);
    });

/// Reads rich clipboard data when available, with a plain-text fallback.
/// `text/html` is optional on Linux/Windows and can fail independently of
/// `text/plain`, so each format is isolated and never blocks ordinary paste.
Future<String?> readMarkdownClipboard({bool preferHtml = true}) async {
  try {
    final plain = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    final canvas = plain == null ? null : canvasClipboardMarkdown(plain);
    if (canvas != null) return canvas;
  } catch (_) {}
  if (preferHtml) {
    try {
      final html = await Clipboard.getData('text/html');
      final value = html?.text;
      if (value != null && RegExp(r'<[a-zA-Z][^>]*>').hasMatch(value)) {
        return htmlToMarkdown(value);
      }
    } catch (_) {
      // Some clipboard providers reject formats they do not expose.
    }
  }
  try {
    return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  } catch (_) {
    return null;
  }
}
