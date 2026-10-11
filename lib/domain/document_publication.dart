import 'package:markdown/markdown.dart' as md;
import 'document_footnotes.dart';
import 'document_citations.dart';
import 'linked_section.dart';
import 'universal_object.dart';
import 'writing_structure.dart';
import 'document_review.dart';
import 'package:yaml/yaml.dart';

/// An immutable presentation snapshot. Never serializes back to owning Markdown.
class PublicationStyle {
  const PublicationStyle({
    this.letter = false,
    this.margin = 54,
    this.fontSize = 11,
    this.serif = false,
    this.numberHeadings = false,
    this.titlePage = false,
    this.contents = true,
    this.pageNumbers = true,
    this.author = '',
    this.header = '',
  });
  final bool letter, serif, numberHeadings, titlePage, contents, pageNumbers;
  final double margin, fontSize;
  final String author, header;
  double get width => letter ? 612 : 595.28;
  double get height => letter ? 792 : 841.89;
  void validate() {
    if (!margin.isFinite ||
        margin < 24 ||
        margin > 90 ||
        !fontSize.isFinite ||
        fontSize < 9 ||
        fontSize > 18 ||
        author.length > 500 ||
        header.length > 500) {
      throw const FormatException('Invalid publishing settings.');
    }
  }
}

class PublicationHeading {
  const PublicationHeading(this.id, this.text, this.level);
  final String id, text;
  final int level;
}

class PublicationDocument {
  PublicationDocument._(
    this.title,
    this.source,
    this.nodes,
    this.footnotes,
    this.headings,
    this.warnings,
    this.style,
  );
  final String title, source;
  final List<md.Node> nodes;
  final Map<String, String> footnotes;
  final List<PublicationHeading> headings;
  final List<String> warnings;
  final PublicationStyle style;
  static PublicationDocument parse(
    String title,
    String source,
    PublicationStyle style, {
    List<UniversalObject> objects = const [],
    String ownerId = '',
  }) {
    style.validate();
    if (source.length > 2000000) {
      throw const FormatException(
        'Publishing limit is 2 million characters. Export sections separately.',
      );
    }
    final warnings = <String>[];
    if (source.contains('<!-- orbit:columns v=1 -->')) {
      warnings.add(
        'Columns use a stacked print layout. Their Markdown content is retained.',
      );
    }
    if (source.contains('<!-- orbit:object v=1 -->')) {
      warnings.add(
        'Linked objects export as source links; drawing previews, live task controls and collection membership remain in the workspace.',
      );
    }
    if (source.contains('<!-- orbit:media ')) {
      warnings.add(
        'Image-and-text sections use a stacked print layout; captions and source labels remain visible.',
      );
    }
    final frontmatter = RegExp(
      r'^---\r?\n[\s\S]*?\r?\n(?:---|\.\.\.)(?:\r?\n|$)',
    ).firstMatch(source);
    if (frontmatter != null) {
      try {
        final yaml = frontmatter[0]!
            .replaceFirst(RegExp(r'^---\r?\n'), '')
            .replaceFirst(RegExp(r'\r?\n(?:---|\.\.\.)(?:\r?\n|$)$'), '');
        if (loadYaml(yaml) is YamlMap) {
          source = source.substring(frontmatter.end);
          warnings.add(
            'Frontmatter properties are omitted from presentation exports; the original note retains them.',
          );
        }
      } catch (_) {
        /* Unknown frontmatter remains literal and recoverable. */
      }
    }
    final literal = writingLiteralRanges(source);
    final edits = <({int start, int end, String text})>[];
    for (final match in RegExp(
      r'^<!-- orbit:section .*-->\r?$',
      multiLine: true,
    ).allMatches(source)) {
      if (literal.any((r) => match.start > r.$1 && match.start < r.$2)) {
        continue;
      }
      final close = source.indexOf(LinkedSection.closing, match.end);
      if (close < 0) continue;
      final end = close + LinkedSection.closing.length;
      final link = LinkedSection.parse(source.substring(match.start, end));
      if (link == null) continue;
      final resolved = resolveLinkedSection(link, objects, {ownerId});
      if (resolved.warning != null) {
        warnings.add('Linked section: ${resolved.warning}');
      }
      edits.add((
        start: match.start,
        end: end,
        text: snapshotLinkedSection(link, objects, {ownerId}),
      ));
    }
    for (final edit in edits.reversed) {
      source = source.replaceRange(edit.start, edit.end, edit.text);
      if (source.length > 2000000) {
        throw const FormatException(
          'Expanded linked sections exceed the publishing size limit.',
        );
      }
    }
    final citations = DocumentCitations(source);
    warnings.addAll(citations.warnings);
    source = citations.publication();
    final notes = DocumentFootnotes(source);
    final definitions = <String, String>{};
    for (final definition in notes.definitions) {
      if (definitions.containsKey(definition.id)) {
        warnings.add(
          'Duplicate footnote ${definition.id}; the first definition is used.',
        );
      } else {
        definitions[definition.id] = definition.text;
      }
    }
    final used = notes.references.map((r) => r.id).toSet();
    for (final id in used) {
      if (!definitions.containsKey(id)) {
        warnings.add('Missing footnote definition: $id');
      }
    }
    // Remove definitions by exact source range; references in code remain literal.
    for (final definition in notes.definitions.reversed) {
      source = source.replaceRange(definition.start, definition.end, '');
    }
    final protected = writingLiteralRanges(source);
    for (final line in RegExp(
      r'[^\n]*\n|[^\n]+$',
    ).allMatches(source).toList().reversed) {
      if (protected.any((r) => line.start > r.$1 && line.start < r.$2)) {
        continue;
      }
      final value = line[0]!.trimRight();
      if (ReviewAnnotation.parse(value) != null ||
          RegExp(
            r'^<!-- (?:/?orbit:media(?: (?:left|right) width=(?:160|200|260))?|/?orbit:figure|orbit:align=(?:left|center|right)|orbit:columns v=1|orbit:column|/orbit:columns|orbit:object v=1|/orbit:object) -->$',
          ).hasMatch(value)) {
        source = source.replaceRange(line.start, line.end, '');
      }
    }
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
      blockSyntaxes: [_PageBreak(), _DisplayMath()],
      inlineSyntaxes: [_Footnote(), _InlineMath()],
    );
    final nodes = document.parseLines(source.split(RegExp(r'\r\n|\n|\r')));
    if (nodes.any((n) => n is md.Text && n.text.contains('<'))) {
      warnings.add(
        'Raw HTML and unsupported extension blocks are retained as literal text; scripts and widgets do not run.',
      );
    }
    final headings = <PublicationHeading>[];
    final counts = List<int>.filled(6, 0);
    void visit(md.Node node) {
      if (node is! md.Element) return;
      final level = int.tryParse(node.tag.replaceFirst('h', ''));
      if (RegExp(r'^h[1-6]$').hasMatch(node.tag) && level != null) {
        counts[level - 1]++;
        for (var i = level; i < 6; i++) {
          counts[i] = 0;
        }
        final prefix = style.numberHeadings
            ? '${counts.take(level).where((n) => n != 0).join('.')}. '
            : '';
        node.children!.insert(0, md.Text(prefix));
        final id = 'heading-${headings.length + 1}';
        node.attributes['id'] = id;
        headings.add(PublicationHeading(id, node.textContent, level));
      }
      for (final child in node.children ?? <md.Node>[]) {
        visit(child);
      }
    }

    for (final node in nodes) {
      visit(node);
    }
    return PublicationDocument._(
      title,
      source,
      List.unmodifiable(nodes),
      Map.unmodifiable({
        for (final id in used)
          if (definitions.containsKey(id)) id: definitions[id]!,
      }),
      List.unmodifiable(headings),
      List.unmodifiable(warnings),
      style,
    );
  }
}

class _PageBreak extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\s*<!-- orbit:pagebreak -->\s*$');
  @override
  md.Node parse(md.BlockParser parser) {
    parser.advance();
    return md.Element.empty('pagebreak');
  }
}

class _DisplayMath extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\s*\$\$(.*)$');
  @override
  md.Node parse(md.BlockParser parser) {
    final first = parser.current.content.trim();
    parser.advance();
    if (first.length > 4 && first.endsWith(r'$$')) {
      return md.Element.text('math', first.substring(2, first.length - 2));
    }
    final lines = <String>[];
    while (!parser.isDone && parser.current.content.trim() != r'$$') {
      lines.add(parser.current.content);
      parser.advance();
    }
    if (parser.isDone) {
      return md.Element.text('p', [first, ...lines].join('\n'));
    }
    parser.advance();
    return md.Element.text('math', lines.join('\n'));
  }
}

class _InlineMath extends md.InlineSyntax {
  _InlineMath()
    : super(r'(?<!\\)\$(?![$\s])((?:\\.|[^$\\\n])+?)(?<!\s)\$(?!\$)');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math-inline', match[1]!));
    return true;
  }
}

class _Footnote extends md.InlineSyntax {
  _Footnote() : super(r'\[\^([^\]\s]+)\]');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('footnote', match[1]!);
    element.attributes['id'] = match[1]!;
    parser.addNode(element);
    return true;
  }
}
