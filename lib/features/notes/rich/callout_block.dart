import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../app/orbit_theme.dart';
import 'note_highlight.dart';
import 'note_underline.dart';
import 'note_math.dart';

enum CalloutType {
  definition(
    name: 'DEFINITION',
    label: 'Definition',
    icon: Icons.menu_book_outlined,
    color: Color(0xFF8B7CF6),
  ),
  theorem(
    name: 'THEOREM',
    label: 'Theorem',
    icon: Icons.school_outlined,
    color: Color(0xFF8B7CF6),
  ),
  lemma(
    name: 'LEMMA',
    label: 'Lemma',
    icon: Icons.account_tree_outlined,
    color: Color(0xFF6F7FEA),
  ),
  proposition(
    name: 'PROPOSITION',
    label: 'Proposition',
    icon: Icons.lightbulb_outline,
    color: Color(0xFF6F7FEA),
  ),
  proof(
    name: 'PROOF',
    label: 'Proof',
    icon: Icons.fact_check_outlined,
    color: Color(0xFF65C6A3),
  ),
  example(
    name: 'EXAMPLE',
    label: 'Example',
    icon: Icons.science_outlined,
    color: Color(0xFFD8B56A),
  ),
  remark(
    name: 'REMARK',
    label: 'Remark',
    icon: Icons.chat_bubble_outline,
    color: Color(0xFFB6B2C2),
  ),
  corollary(
    name: 'COROLLARY',
    label: 'Corollary',
    icon: Icons.subdirectory_arrow_right,
    color: Color(0xFF6F7FEA),
  ),
  counterexample(
    name: 'COUNTEREXAMPLE',
    label: 'Counterexample',
    icon: Icons.cancel_outlined,
    color: Color(0xFFE57582),
  ),
  question(
    name: 'QUESTION',
    label: 'Question',
    icon: Icons.help_outline,
    color: Color(0xFF38BDF8),
  ),
  note(
    name: 'NOTE',
    label: 'Note',
    icon: Icons.info_outline,
    color: Color(0xFF0284C7),
  ),
  tip(
    name: 'TIP',
    label: 'Tip',
    icon: Icons.lightbulb_outline,
    color: Color(0xFF10B981),
  ),
  important(
    name: 'IMPORTANT',
    label: 'Important',
    icon: Icons.priority_high_rounded,
    color: Color(0xFFA855F7),
  ),
  warning(
    name: 'WARNING',
    label: 'Warning',
    icon: Icons.warning_amber_rounded,
    color: Color(0xFFF59E0B),
  ),
  caution(
    name: 'CAUTION',
    label: 'Caution',
    icon: Icons.report_problem_outlined,
    color: Color(0xFFE57582),
  );

  const CalloutType({
    required this.name,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String name;
  final String label;
  final IconData icon;
  final Color color;

  static CalloutType fromString(String raw) {
    final upper = raw.trim().toUpperCase();
    for (final type in CalloutType.values) {
      if (type.name == upper) return type;
    }
    return CalloutType.note;
  }
}

/// Parsed callout components.
class ParsedCallout {
  const ParsedCallout({
    required this.type,
    required this.title,
    required this.body,
  });

  final CalloutType type;
  final String title;
  final String body;

  static final _calloutRegex = RegExp(r'^>\s*\[!([a-zA-Z]+)\][ \t]*(.*)$');

  static bool isCallout(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return false;
    return _calloutRegex.hasMatch(lines.first.trim());
  }

  static ParsedCallout parse(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) {
      return const ParsedCallout(type: CalloutType.note, title: '', body: '');
    }

    final match = _calloutRegex.firstMatch(lines.first.trim());
    final type = match != null
        ? CalloutType.fromString(match.group(1)!)
        : CalloutType.note;
    final title = match != null ? match.group(2)!.trim() : '';

    final bodyLines = <String>[];
    for (var i = 1; i < lines.length; i++) {
      var l = lines[i];
      if (l.startsWith('> ')) {
        bodyLines.add(l.substring(2));
      } else if (l.startsWith('>')) {
        bodyLines.add(l.substring(1));
      } else {
        bodyLines.add(l);
      }
    }

    return ParsedCallout(
      type: type,
      title: title,
      body: bodyLines.join('\n').trim(),
    );
  }

  String get headerDisplay {
    if (title.isEmpty) return type.label;
    final lowerTitle = title.toLowerCase();
    final lowerLabel = type.label.toLowerCase();
    if (lowerTitle.startsWith(lowerLabel)) {
      return title;
    }
    final startsWithNumber = RegExp(r'^[0-9]+(\.[0-9]+)*').hasMatch(title);
    if (startsWithNumber) {
      return '${type.label} $title';
    }
    return '${type.label}: $title';
  }

  String toMarkdown() {
    final titlePart = title.isNotEmpty ? ' $title' : '';
    final header = '> [!${type.name}]$titlePart';
    if (body.isEmpty) return '$header\n';
    final lines = body.split('\n');
    final formattedBody = lines.map((l) => '> $l').join('\n');
    return '$header\n$formattedBody\n';
  }
}

/// A modern, interactive Callout / Admonition block (EDT-12).
/// Compatible with standard GitHub and Obsidian syntax (> [!NOTE], etc.).
class CalloutBlock extends StatefulWidget {
  const CalloutBlock({
    super.key,
    required this.source,
    required this.onChanged,
  });

  final String source;
  final ValueChanged<String> onChanged;

  @override
  State<CalloutBlock> createState() => _CalloutBlockState();
}

class _CalloutBlockState extends State<CalloutBlock> {
  late ParsedCallout _parsed;
  late final TextEditingController _bodyCtrl;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _parsed = ParsedCallout.parse(widget.source);
    _bodyCtrl = TextEditingController(text: _parsed.body);
  }

  @override
  void didUpdateWidget(covariant CalloutBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source && !_focus.hasFocus) {
      _parsed = ParsedCallout.parse(widget.source);
      if (_bodyCtrl.text != _parsed.body) {
        _bodyCtrl.text = _parsed.body;
      }
    }
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _updateType(CalloutType newType) {
    _parsed = ParsedCallout(
      type: newType,
      title: _parsed.title,
      body: _bodyCtrl.text,
    );
    widget.onChanged(_parsed.toMarkdown());
    setState(() {});
  }

  void _onBodyChanged(String newBody) {
    _parsed = ParsedCallout(
      type: _parsed.type,
      title: _parsed.title,
      body: newBody,
    );
    widget.onChanged(_parsed.toMarkdown());
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final type = _parsed.type;
    final effectiveColor = type.color;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: effectiveColor),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with Icon, Type Badge, and Quick Switcher
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: effectiveColor.withValues(alpha: 0.08),
                    child: Row(
                      children: [
                        Icon(type.icon, size: 16, color: effectiveColor),
                        const SizedBox(width: 8),
                        Text(
                          _parsed.headerDisplay,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: effectiveColor,
                          ),
                        ),
                        const Spacer(),
                        PopupMenuButton<CalloutType>(
                          tooltip: 'Change callout type',
                          icon: Icon(
                            Icons.swap_horiz,
                            size: 16,
                            color: colors.subtle,
                          ),
                          padding: EdgeInsets.zero,
                          itemBuilder: (_) => [
                            for (final t in CalloutType.values)
                              PopupMenuItem(
                                value: t,
                                child: Row(
                                  children: [
                                    Icon(t.icon, size: 16, color: t.color),
                                    const SizedBox(width: 8),
                                    Text(t.label),
                                  ],
                                ),
                              ),
                          ],
                          onSelected: _updateType,
                        ),
                      ],
                    ),
                  ),

                  // Editable Callout Content
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: _bodyCtrl,
                      focusNode: _focus,
                      maxLines: null,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.text,
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Type callout contents...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        fillColor: Colors.transparent,
                      ),
                      onChanged: _onBodyChanged,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Markdown block syntax for standard GitHub and Obsidian callouts:
/// > [!NOTE]
/// > Content
class CalloutBlockSyntax extends md.BlockSyntax {
  const CalloutBlockSyntax();

  static final _calloutHeaderPattern = RegExp(
    r'^\s*>\s*\[!([a-zA-Z]+)\][ \t]*(.*)$',
  );

  @override
  RegExp get pattern => RegExp(r'^\s*>\s*\[![a-zA-Z]+\]');

  @override
  bool canParse(md.BlockParser parser) {
    return _calloutHeaderPattern.hasMatch(parser.current.content);
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final match = _calloutHeaderPattern.firstMatch(parser.current.content)!;
    final typeStr = match.group(1)!;
    final title = match.group(2)!.trim();
    parser.advance();

    final bodyLines = <String>[];
    final quotePrefix = RegExp(r'^\s*>\s?');
    while (!parser.isDone) {
      final line = parser.current.content;
      if (_calloutHeaderPattern.hasMatch(line)) {
        break;
      }
      if (quotePrefix.hasMatch(line)) {
        bodyLines.add(line.replaceFirst(quotePrefix, ''));
        parser.advance();
      } else if (line.trim().isEmpty) {
        var lookahead = 1;
        var hasMoreQuote = false;
        while (true) {
          final ahead = parser.peek(lookahead);
          if (ahead == null) break;
          if (ahead.content.trim().isEmpty) {
            lookahead++;
          } else {
            if (_calloutHeaderPattern.hasMatch(ahead.content)) {
              hasMoreQuote = false;
            } else {
              hasMoreQuote = quotePrefix.hasMatch(ahead.content);
            }
            break;
          }
        }
        if (hasMoreQuote) {
          bodyLines.add('');
          parser.advance();
        } else {
          break;
        }
      } else {
        break;
      }
    }

    final element = md.Element('callout', [
      md.Element.text('callout-body', bodyLines.join('\n').trim()),
    ]);
    element.attributes['type'] = typeStr;
    element.attributes['title'] = title;
    return element;
  }
}

/// Element builder that renders callout boxes with colored side bar,
/// prominent icon, bold colored header, and rich markdown body.
class CalloutElementBuilder extends MarkdownElementBuilder {
  CalloutElementBuilder();

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final typeStr = element.attributes['type'] ?? 'NOTE';
    final title = element.attributes['title'] ?? '';
    final type = CalloutType.fromString(typeStr);
    final body = element.children?.isNotEmpty == true
        ? element.children!.first.textContent
        : '';

    final colors = OrbitColors.of(context);
    final effectiveColor = type.color;
    final headerDisplay = title.isNotEmpty
        ? (title.toLowerCase().startsWith(type.name.toLowerCase()) ||
                  title.toLowerCase().startsWith(type.label.toLowerCase())
              ? title
              : '${type.name}: $title')
        : type.name;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: effectiveColor),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    color: effectiveColor.withValues(alpha: 0.08),
                    child: Row(
                      children: [
                        Icon(type.icon, size: 16, color: effectiveColor),
                        const SizedBox(width: 8),
                        Text(
                          headerDisplay,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: effectiveColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: MarkdownBody(
                        data: body,
                        selectable: true,
                        inlineSyntaxes: [
                          HighlightInlineSyntax(),
                          MarkTagInlineSyntax(),
                          UnderlineInlineSyntax(),
                          InsInlineSyntax(),
                          MathInlineSyntax(),
                        ],
                        builders: {
                          'mark': HighlightElementBuilder(),
                          'u': UnderlineElementBuilder(),
                          'ins': UnderlineElementBuilder(),
                          'math-inline': MathElementBuilder(),
                        },
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(
                              Theme.of(context),
                            ).copyWith(
                              p: TextStyle(
                                fontSize: 14,
                                color: colors.text,
                                height: 1.55,
                              ),
                              code: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
