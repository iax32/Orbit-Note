import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'markdown_document.dart';
import 'note_highlight.dart';
import 'note_underline.dart';
import 'note_math.dart';
import '../note_typography.dart';
import '../read_attachment_preview.dart';

/// A portable comment decorates exactly one paragraph or heading. Other readers
/// can ignore the comment while retaining ordinary, editable Markdown content.
class AlignmentBlockSyntax extends md.BlockSyntax {
  const AlignmentBlockSyntax();
  @override
  RegExp get pattern =>
      RegExp(r'^<!-- orbit:align=(left|center|right|justify) -->$');

  MarkdownBlock? _next(md.BlockParser parser) {
    final lines = <String>[];
    for (var i = 1; ; i++) {
      final line = parser.peek(i);
      if (line == null || line.content.trim().isEmpty) break;
      lines.add(line.content);
    }
    if (lines.isEmpty) return null;
    final block = MarkdownDocument.parse('${lines.join('\n')}\n').blocks.first;
    return block.canAlign ? block : null;
  }

  @override
  bool canParse(md.BlockParser parser) =>
      pattern.hasMatch(parser.current.content) && _next(parser) != null;

  @override
  md.Node parse(md.BlockParser parser) {
    final alignment = pattern.firstMatch(parser.current.content)![1]!;
    final block = _next(parser)!;
    parser.advance();
    for (var i = 0; i < '\n'.allMatches(block.source).length; i++) {
      parser.advance();
    }
    return md.Element.text('orbit-aligned', block.source)
      ..attributes['alignment'] = alignment;
  }
}

class AlignmentElementBuilder extends MarkdownElementBuilder {
  AlignmentElementBuilder({
    required this.fontSize,
    required this.onTapLink,
    this.fontFamily,
    this.lineHeight = 1.6,
    this.linkBuilder,
    this.imageBuilder,
    this.onOpenAttachment,
  });
  final double fontSize;
  final String? fontFamily;
  final double lineHeight;
  final void Function(String, String?, String) onTapLink;
  final MarkdownElementBuilder? linkBuilder;
  final Widget Function(Uri, String?, String?)? imageBuilder;
  final ValueChanged<String>? onOpenAttachment;
  @override
  bool isBlockElement() => true;
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final align = switch (element.attributes['alignment']) {
      'center' => WrapAlignment.center,
      'right' => WrapAlignment.end,
      'justify' => WrapAlignment.spaceBetween,
      _ => WrapAlignment.start,
    };
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: MarkdownBody(
        data: element.textContent,
        selectable: true,
        onTapLink: onTapLink,
        imageBuilder: (uri, title, alt) => ReadAttachmentPreview(
          uri: uri,
          description: alt ?? title,
          onOpen: onOpenAttachment,
          child:
              imageBuilder?.call(uri, title, alt) ??
              Text(alt ?? title ?? uri.toString()),
        ),
        blockSyntaxes: const [MathTableSyntax()],
        inlineSyntaxes: [
          HighlightInlineSyntax(),
          MarkTagInlineSyntax(),
          UnderlineInlineSyntax(),
          InsInlineSyntax(),
          MathInlineSyntax(),
        ],
        builders: {
          'a': ?linkBuilder,
          'mark': HighlightElementBuilder(),
          'u': UnderlineElementBuilder(),
          'ins': UnderlineElementBuilder(),
          'math-inline': MathElementBuilder(),
        },
        styleSheet:
            NoteTypography(
                  fontFamily: fontFamily,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                )
                .markdown(theme)
                .copyWith(
                  textAlign: align,
                  h1Align: align,
                  h2Align: align,
                  h3Align: align,
                  h4Align: align,
                  h5Align: align,
                  h6Align: align,
                ),
      ),
    );
  }
}
