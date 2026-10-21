import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../../domain/note_composition.dart';
import 'note_typography.dart';
import 'rich/note_math.dart';
import 'rich/note_highlight.dart';
import 'rich/note_underline.dart';
import 'rich/callout_block.dart';

class NoteColumnsLayout extends StatelessWidget {
  const NoteColumnsLayout({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      if (bounds.maxWidth < children.length * 250 * scale) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 20),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 24),
            Expanded(child: children[i]),
          ],
        ],
      );
    },
  );
}

class NoteCompositionSyntax extends md.BlockSyntax {
  const NoteCompositionSyntax();
  @override
  RegExp get pattern => RegExp(r'^<!-- orbit:(?:columns|object) v=1 -->$');
  List<String>? _lines(md.BlockParser parser) {
    final lines = <String>[parser.current.content];
    final columns = NoteColumns.opening.hasMatch(lines.first);
    final close = columns ? NoteColumns.closing : NoteObjectBlock.closing;
    final fence = NoteLayoutFence();
    var size = lines.first.length;
    for (var i = 1; i < (columns ? 10000 : 3); i++) {
      final line = parser.peek(i);
      if (line == null) break;
      size += line.content.length + 1;
      if (size > 200000) return null;
      lines.add(line.content);
      if (fence.outside(line.content) && line.content == close) {
        final source = '${lines.join('\n')}\n';
        if ((columns
                ? NoteColumns.parse(source)
                : NoteObjectBlock.parse(source)) !=
            null) {
          return lines;
        }
        return null;
      }
    }
    return null;
  }

  @override
  bool canParse(md.BlockParser parser) =>
      pattern.hasMatch(parser.current.content) && _lines(parser) != null;
  @override
  md.Node parse(md.BlockParser parser) {
    final lines = _lines(parser)!;
    for (var i = 0; i < lines.length; i++) {
      parser.advance();
    }
    return md.Element.text('orbit-composition', '${lines.join('\n')}\n');
  }
}

class NoteCompositionBuilder extends MarkdownElementBuilder {
  NoteCompositionBuilder({
    required this.typography,
    required this.onOpen,
    required this.objectBuilder,
    this.imageBuilder,
    this.blockSyntaxes = const [],
    this.builders = const {},
  });
  final NoteTypography typography;
  final ValueChanged<String> onOpen;
  final Widget Function(NoteObjectBlock, bool) objectBuilder;
  final MarkdownImageBuilder? imageBuilder;
  final List<md.BlockSyntax> blockSyntaxes;
  final Map<String, MarkdownElementBuilder> builders;
  @override
  bool isBlockElement() => true;
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final object = NoteObjectBlock.parse(element.textContent);
    if (object != null) return objectBuilder(object, false);
    final columns = NoteColumns.parse(element.textContent);
    if (columns == null) return Text(element.textContent);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: NoteColumnsLayout(
        children: [
          for (final part in columns.parts)
            MarkdownBody(
              data: part,
              selectable: true,
              extensionSet: md.ExtensionSet.gitHubFlavored,
              styleSheet: typography.markdown(Theme.of(context)),
              imageBuilder: imageBuilder,
              inlineSyntaxes: [
                HighlightInlineSyntax(),
                UnderlineInlineSyntax(),
                MathInlineSyntax(),
              ],
              blockSyntaxes: [
                const CalloutBlockSyntax(),
                const MathBlockSyntax(),
                const MathTableSyntax(),
                ...blockSyntaxes,
              ],
              builders: {
                'math': MathElementBuilder(),
                'math-inline': MathElementBuilder(),
                'math-block': MathElementBuilder(display: true),
                'mark': HighlightElementBuilder(),
                'u': UnderlineElementBuilder(),
                'callout': CalloutElementBuilder(
                  typography: typography,
                  onTapLink: (_, href, _) {
                    if (href != null) onOpen(href);
                  },
                  imageBuilder: imageBuilder,
                ),
                ...builders,
              },
              onTapLink: (_, href, _) {
                if (href != null) onOpen(href);
              },
            ),
        ],
      ),
    );
  }
}
