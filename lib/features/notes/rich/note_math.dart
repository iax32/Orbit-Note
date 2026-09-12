import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'equation_editor.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

const _inlineMathPattern =
    r'(?<!\\)\$(?![$\s])((?:\\.|[^$\\\n])+?)(?<!\s)\$(?!\$)';

/// Match equations outside escaped text and complete inline code spans.
/// Keep source coordinates so an equation edit is a single local splice.
Iterable<Match> inlineMathMatches(String source) sync* {
  final math = RegExp(_inlineMathPattern);
  var i = 0;
  while (i < source.length) {
    if (source[i] == '\\') {
      i += 2;
      continue;
    }
    if (source[i] == '`') {
      var end = i + 1;
      while (end < source.length && source[end] == '`') {
        end++;
      }
      final delimiter = source.substring(i, end);
      var close = source.indexOf(delimiter, end);
      while (close >= 0 &&
          ((close > 0 && source[close - 1] == '`') ||
              (close + delimiter.length < source.length &&
                  source[close + delimiter.length] == '`'))) {
        close = source.indexOf(delimiter, close + delimiter.length);
      }
      i = close < 0 ? end : close + delimiter.length;
      continue;
    }
    if (source.startsWith(r'$$', i)) {
      i += 2;
      continue;
    }
    final match = math.matchAsPrefix(source, i);
    if (match != null) {
      yield match;
      i = match.end;
    } else {
      i++;
    }
  }
}

class NoteMath extends StatelessWidget {
  const NoteMath(this.source, {super.key, this.display = false, this.onEdit});
  final String source;
  final bool display;
  final ValueChanged<String>? onEdit;
  Future<void> edit(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => EquationEditor(source: source, display: display),
    );
    if (result != null && context.mounted) onEdit?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final content = Math.tex(
      source,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      textStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: display ? 21 : 17,
      ),
      onErrorFallback: (_) => Tooltip(
        message: 'Invalid or unsupported LaTeX. The source is preserved.',
        child: Text(
          source,
          style: TextStyle(
            fontFamily: 'monospace',
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
    return onEdit == null
        ? content
        : Tooltip(
            message: 'Click to edit equation · Right-click to copy LaTeX',
            child: InkWell(
              onTap: () => edit(context),
              onSecondaryTap: () {
                Clipboard.setData(ClipboardData(text: source));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('LaTeX copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(padding: const EdgeInsets.all(5), child: content),
            ),
          );
  }
}

class MathInlineSyntax extends md.InlineSyntax {
  MathInlineSyntax() : super(_inlineMathPattern);
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math-inline', match[1]!));
    return true;
  }
}

class MathBlockSyntax extends md.BlockSyntax {
  const MathBlockSyntax();
  @override
  RegExp get pattern => RegExp(r'^\s*\$\$(?:.*\$\$)?\s*$');
  @override
  md.Node parse(md.BlockParser parser) {
    final opening = parser.current.content.trim();
    if (opening.length > 4) {
      parser.advance();
      return md.Element.text(
        'math-block',
        opening.substring(2, opening.length - 2),
      );
    }
    parser.advance();
    final lines = <String>[];
    while (!parser.isDone && !pattern.hasMatch(parser.current.content)) {
      lines.add(parser.current.content);
      parser.advance();
    }
    if (parser.isDone) {
      return md.Element.text('p', ['\$\$', ...lines].join('\n'));
    }
    parser.advance();
    return md.Element.text('math-block', lines.join('\n'));
  }
}

class MathElementBuilder extends MarkdownElementBuilder {
  MathElementBuilder({this.display = false});
  final bool display;
  @override
  bool isBlockElement() => display;
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: NoteMath(element.textContent, display: display),
      );
}
