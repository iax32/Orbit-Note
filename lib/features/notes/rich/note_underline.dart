import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Markdown inline syntax for HTML <u>underlined text</u>.
class UnderlineInlineSyntax extends md.InlineSyntax {
  UnderlineInlineSyntax() : super(r'<u>([^<\n]+)</u>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('u', match[1]!));
    return true;
  }
}

/// Markdown inline syntax for HTML <ins>underlined/inserted text</ins>.
class InsInlineSyntax extends md.InlineSyntax {
  InsInlineSyntax() : super(r'<ins>([^<\n]+)</ins>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('u', match[1]!));
    return true;
  }
}

/// Element builder that renders <u> and <ins> elements with underline decoration,
/// preserving existing decorations such as strikethrough if present.
class UnderlineElementBuilder extends MarkdownElementBuilder {
  UnderlineElementBuilder();

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final base = preferredStyle ?? parentStyle ?? const TextStyle();
    final decoration = base.decoration != null
        ? TextDecoration.combine([base.decoration!, TextDecoration.underline])
        : TextDecoration.underline;

    return Text(
      element.textContent,
      style: base.copyWith(decoration: decoration),
    );
  }
}
