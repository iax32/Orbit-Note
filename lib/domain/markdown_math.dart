import 'package:markdown/markdown.dart' as md;

/// GFM removes one table-quoting slash before inline processing; Orbit's cell
/// grammar also quotes authored slashes. Decode the remaining pairs only inside
/// math spans. Keep surrounding inline parsing deferred so forward references
/// and code spans retain their normal Markdown behavior.
class MathTableSyntax extends md.TableSyntax {
  const MathTableSyntax();

  @override
  md.Node? parse(md.BlockParser parser) {
    final node = super.parse(parser);
    void visit(md.Node? node) {
      if (node is! md.Element) return;
      final children = node.children;
      if (children == null) return;
      if (node.tag == 'td' || node.tag == 'th') {
        for (var i = 0; i < children.length; i++) {
          final child = children[i];
          if (child is! md.UnparsedContent) continue;
          var source = child.textContent;
          for (final match in inlineMathMatches(source).toList().reversed) {
            final tex = match[1]!.replaceAllMapped(RegExp(r'(\\+)\|'), (run) {
              final count = run[1]!.length;
              return count.isEven ? '${'\\' * (count ~/ 2)}|' : run[0]!;
            });
            source = source.replaceRange(match.start, match.end, '\$$tex\$');
          }
          children[i] = md.UnparsedContent(source);
        }
      } else {
        for (final child in children) {
          visit(child);
        }
      }
    }

    visit(node);
    return node;
  }
}

const markdownInlineMathPattern =
    r'(?<!\\)\$(?![$\s])((?:\\.|[^$\\\n])+?)(?<!\s)\$(?!\$)';

/// Match equations outside escaped text and complete inline code spans.
/// Keep source coordinates so an equation edit is a single local splice.
Iterable<Match> inlineMathMatches(String source) sync* {
  final math = RegExp(markdownInlineMathPattern);
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
