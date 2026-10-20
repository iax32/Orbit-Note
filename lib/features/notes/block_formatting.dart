import 'rich/markdown_document.dart';

const noteBlockFormats = [
  'Paragraph',
  'Heading 1',
  'Heading 2',
  'Heading 3',
  'Heading 4',
  'Heading 5',
  'Heading 6',
  'Bullet list',
  'Numbered list',
  'Checklist',
  'Quote',
  'Note callout',
  'BTW block',
  'Tip callout',
  'Warning callout',
];

/// Explicit formatting of supported whole blocks, never renderer serialization.
String formatNoteBlocks(String source, String format) {
  if (!noteBlockFormats.contains(format)) {
    throw const FormatException('Unsupported block format.');
  }
  final doc = MarkdownDocument.parse(source);
  final eol = source.contains('\r\n') ? '\r\n' : '\n';
  final calloutType = switch (format) {
    'Note callout' => 'NOTE',
    'BTW block' => 'BTW',
    'Tip callout' => 'TIP',
    'Warning callout' => 'WARNING',
    _ => null,
  };
  if (source.trim().isEmpty) {
    if (calloutType != null) return '> [!$calloutType]$eol> $eol';
    if (format == 'Paragraph') return source;
    final prefix = switch (format) {
      'Bullet list' => '- ',
      'Numbered list' => '1. ',
      'Checklist' => '- [ ] ',
      'Quote' => '> ',
      _ => '${'#' * int.parse(format.split(' ').last)} ',
    };
    return '$prefix${source.endsWith('\n') ? eol : ''}';
  }
  var number = 0;
  final lines = <String>[];
  for (final block in doc.blocks) {
    if (block.kind == MarkdownBlockKind.blank) {
      lines.add(block.source);
      continue;
    }
    if (![
          MarkdownBlockKind.text,
          MarkdownBlockKind.heading,
          MarkdownBlockKind.list,
          MarkdownBlockKind.quote,
        ].contains(block.kind) ||
        block.alignmentPrefix.isNotEmpty) {
      throw const FormatException(
        'Format prose, headings or simple list items. Tables, media, code and other structured blocks keep their own tools.',
      );
    }
    if (block.kind == MarkdownBlockKind.list && block.level > 0 ||
        block.kind == MarkdownBlockKind.quote &&
            block.content.startsWith('>')) {
      throw const FormatException(
        'Format one list level or quote level at a time to preserve its structure.',
      );
    }
    final anchor =
        RegExp(
          r' \^[A-Za-z0-9][A-Za-z0-9_-]*[ \t]*',
        ).firstMatch(block.suffix)?.group(0) ??
        RegExp(r' \^[A-Za-z0-9][A-Za-z0-9_-]*[ \t]*$')
            .firstMatch(block.source.replaceFirst(RegExp(r'\r?\n$'), ''))
            ?.group(0) ??
        '';
    var content = block.content;
    // A quote anchor is part of its content; other projections keep it in suffix.
    if (anchor.isNotEmpty && content.endsWith(anchor)) {
      content = content.substring(0, content.length - anchor.length);
    }
    final fragments = content.split(RegExp(r'\r?\n'));
    if (format.startsWith('Heading ') && fragments.length > 1) {
      throw const FormatException(
        'A heading needs one line. Select individual paragraphs or list items.',
      );
    }
    for (var i = 0; i < fragments.length; i++) {
      final text = fragments[i];
      final last = i == fragments.length - 1;
      final suffix =
          '${last ? anchor : ''}${last && !block.source.endsWith('\n') ? '' : eol}';
      final prefix = switch (format) {
        'Paragraph' => '',
        'Bullet list' => '- ',
        'Numbered list' => '${++number}. ',
        'Checklist' => '- [${block.checked == true ? 'x' : ' '}] ',
        'Quote' => '> ',
        _ =>
          calloutType != null
              ? '> '
              : '${'#' * int.parse(format.split(' ').last)} ',
      };
      lines.add('$prefix$text$suffix');
    }
  }
  final body = lines.join();
  // Quote blank separators so a converted multi-paragraph callout stays one block.
  if (calloutType == null) return body;
  final bodyLines = body.split(RegExp(r'\r?\n'));
  return '> [!$calloutType]$eol${[for (var i = 0; i < bodyLines.length; i++) bodyLines[i].isEmpty && i < bodyLines.length - 1 ? '>' : bodyLines[i]].join(eol)}';
}
