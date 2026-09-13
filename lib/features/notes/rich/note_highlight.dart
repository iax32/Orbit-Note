import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Markdown inline syntax for ==highlighted text==.
class HighlightInlineSyntax extends md.InlineSyntax {
  HighlightInlineSyntax() : super(r'==([^=\n]+)==');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('mark', match[1]!));
    return true;
  }
}

/// Markdown inline syntax for HTML <mark>highlighted text</mark>.
class MarkTagInlineSyntax extends md.InlineSyntax {
  MarkTagInlineSyntax() : super(r'<mark>([^<\n]+)</mark>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('mark', match[1]!));
    return true;
  }
}

/// Element builder that renders <mark> and ==text== with warm yellow highlights.
class HighlightElementBuilder extends MarkdownElementBuilder {
  HighlightElementBuilder();

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? const Color(0xFFEAB308).withValues(alpha: 0.35)
        : const Color(0xFFFEF08A);
    final fg = isDark ? const Color(0xFFFDE047) : const Color(0xFF713F12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        element.textContent,
        style: (preferredStyle ?? parentStyle ?? const TextStyle()).copyWith(
          color: fg,
          backgroundColor: Colors.transparent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
