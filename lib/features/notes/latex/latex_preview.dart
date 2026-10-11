import 'package:flutter/material.dart';
import '../rich/note_math.dart';
import 'latex_document.dart';

/// Renders a formatted academic paper preview from a LaTeX document string.
class LatexPreview extends StatelessWidget {
  const LatexPreview({
    super.key,
    required this.latex,
    required this.contentWidth,
    required this.fontSize,
    this.scrollController,
    this.imageBuilder,
  });

  final String latex;
  final double contentWidth;
  final double fontSize;
  final ScrollController? scrollController;
  final Widget Function(BuildContext, String)? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final doc = LatexDocument.fromLatex(latex);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Academic paper background and text styling
    final paperColor = isDark ? const Color(0xFF1E1F24) : Colors.white;
    final paperBorder = isDark
        ? const Color(0xFF2E313A)
        : const Color(0xFFE2E8F0);

    return Scrollbar(
      controller: scrollController,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: contentWidth),
            decoration: BoxDecoration(
              color: paperColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: paperBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
            child: _LatexDocView(
              doc: doc,
              fontSize: fontSize,
              imageBuilder: imageBuilder,
            ),
          ),
        ),
      ),
    );
  }
}

class _LatexDocView extends StatefulWidget {
  const _LatexDocView({
    required this.doc,
    required this.fontSize,
    this.imageBuilder,
  });

  final LatexDocument doc;
  final double fontSize;
  final Widget Function(BuildContext, String)? imageBuilder;

  @override
  State<_LatexDocView> createState() => _LatexDocViewState();
}

class _LatexDocViewState extends State<_LatexDocView> {
  // Counters for academic numbering
  int _secNum = 0;
  int _subsecNum = 0;
  int _subsubsecNum = 0;
  int _thmNum = 0;
  int _defNum = 0;
  int _eqNum = 0;
  int _figNum = 0;
  int _tabNum = 0;

  @override
  Widget build(BuildContext context) {
    _secNum = 0;
    _subsecNum = 0;
    _subsubsecNum = 0;
    _thmNum = 0;
    _defNum = 0;
    _eqNum = 0;
    _figNum = 0;
    _tabNum = 0;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textStyle = TextStyle(
      fontSize: widget.fontSize,
      height: 1.65,
      fontFamily: 'serif',
      color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
    );

    final widgets = <Widget>[];

    // Document header (Title, Author, Date, Abstract)
    if (widget.doc.title.isNotEmpty || widget.doc.author.isNotEmpty) {
      widgets.add(_buildHeader(context));
      widgets.add(const SizedBox(height: 28));
    }

    if (widget.doc.abstractText.isNotEmpty) {
      widgets.add(_buildAbstract(context, textStyle));
      widgets.add(const SizedBox(height: 28));
    }

    // Render blocks
    for (final block in widget.doc.blocks) {
      final w = _buildBlock(block, textStyle, context);
      if (w != null) {
        widgets.add(w);
        widgets.add(const SizedBox(height: 16));
      }
    }

    if (widgets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'Empty LaTeX Document',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widgets,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        if (widget.doc.title.isNotEmpty)
          Text(
            widget.doc.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.fontSize * 1.75,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        if (widget.doc.author.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            widget.doc.author,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.fontSize * 1.1,
              fontFamily: 'serif',
              color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
            ),
          ),
        ],
        if (widget.doc.date.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            widget.doc.date,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.fontSize * 0.95,
              fontFamily: 'serif',
              fontStyle: FontStyle.italic,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAbstract(BuildContext context, TextStyle textStyle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            'Abstract',
            style: TextStyle(
              fontSize: widget.fontSize * 0.95,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          _renderFormattedText(
            widget.doc.abstractText,
            textStyle.copyWith(fontSize: widget.fontSize * 0.9),
          ),
        ],
      ),
    );
  }

  Widget? _buildBlock(
    LatexBlock block,
    TextStyle textStyle,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (block.type) {
      case LatexBlockType.section:
        _secNum++;
        _subsecNum = 0;
        _subsubsecNum = 0;
        final numPrefix = block.numbered ? '$_secNum. ' : '';
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(
            '$numPrefix${block.rawContent}',
            style: TextStyle(
              fontSize: widget.fontSize * 1.35,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        );

      case LatexBlockType.subsection:
        _subsecNum++;
        _subsubsecNum = 0;
        final numPrefix = block.numbered ? '$_secNum.$_subsecNum ' : '';
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text(
            '$numPrefix${block.rawContent}',
            style: TextStyle(
              fontSize: widget.fontSize * 1.15,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
              color: isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827),
            ),
          ),
        );

      case LatexBlockType.subsubsection:
        _subsubsecNum++;
        final numPrefix = block.numbered
            ? '$_secNum.$_subsecNum.$_subsubsecNum '
            : '';
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(
            '$numPrefix${block.rawContent}',
            style: TextStyle(
              fontSize: widget.fontSize * 1.05,
              fontWeight: FontWeight.w600,
              fontFamily: 'serif',
              color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
            ),
          ),
        );

      case LatexBlockType.paragraph:
        return _renderFormattedText(block.rawContent, textStyle);

      case LatexBlockType.equation:
        _eqNum++;
        final isNumbered =
            block.environment != 'equation*' && block.environment != 'align*';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: NoteMath(block.rawContent, display: true),
                  ),
                ),
              ),
              if (isNumbered)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    '($_eqNum)',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: widget.fontSize * 0.9,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
            ],
          ),
        );

      case LatexBlockType.aligned:
        _eqNum++;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: NoteMath(
                      '\\begin{aligned}${block.rawContent}\\end{aligned}',
                      display: true,
                    ),
                  ),
                ),
              ),
              if (block.environment != 'align*')
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    '($_eqNum)',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: widget.fontSize * 0.9,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
            ],
          ),
        );

      case LatexBlockType.theorem:
        final env = block.environment.toLowerCase();
        final isThmOrLemma =
            env.contains('theorem') ||
            env.contains('lemma') ||
            env.contains('prop') ||
            env.contains('cor');
        if (isThmOrLemma) {
          _thmNum++;
        } else {
          _defNum++;
        }
        final count = isThmOrLemma ? _thmNum : _defNum;
        final capitalizedEnv = env.isNotEmpty
            ? '${env[0].toUpperCase()}${env.substring(1)}'
            : 'Theorem';
        final headerTitle = block.options.isNotEmpty
            ? '$capitalizedEnv $count (${block.options})'
            : '$capitalizedEnv $count';

        final cardBorder = isThmOrLemma
            ? const Color(0xFF8B7CF6) // Orbit Violet
            : const Color(0xFF10B981); // Emerald
        final cardBg = isDark
            ? (isThmOrLemma ? const Color(0xFF1E1B2E) : const Color(0xFF142420))
            : (isThmOrLemma
                  ? const Color(0xFFF5F3FF)
                  : const Color(0xFFECFDF5));

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(color: cardBorder, width: 4),
              top: BorderSide(color: cardBorder.withValues(alpha: 0.2)),
              right: BorderSide(color: cardBorder.withValues(alpha: 0.2)),
              bottom: BorderSide(color: cardBorder.withValues(alpha: 0.2)),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                headerTitle,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.bold,
                  fontSize: widget.fontSize * 1.05,
                  color: cardBorder,
                ),
              ),
              const SizedBox(height: 8),
              _renderFormattedText(
                block.rawContent,
                textStyle.copyWith(
                  fontStyle: isThmOrLemma ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        );

      case LatexBlockType.proof:
        final title = block.options.isNotEmpty
            ? 'Proof (${block.options}).'
            : 'Proof.';
        final proofBorder = isDark
            ? const Color(0xFF4B5563)
            : const Color(0xFFD1D5DB);
        return Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: proofBorder, width: 3)),
          ),
          padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.fontSize,
                  color: isDark
                      ? const Color(0xFFE5E7EB)
                      : const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              _renderFormattedText(block.rawContent, textStyle),
              const SizedBox(height: 6),
              // Halmos tombstone Q.E.D. symbol
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '□',
                  style: TextStyle(
                    fontSize: widget.fontSize * 1.2,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
          ),
        );

      case LatexBlockType.table:
        _tabNum++;
        return _buildTableBlock(block, context);

      case LatexBlockType.figure:
        _figNum++;
        return _buildFigureBlock(block, context);

      case LatexBlockType.list:
        return _buildListBlock(block, textStyle);

      case LatexBlockType.pageBreak:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              Expanded(child: Divider(color: theme.dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Page Break',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(child: Divider(color: theme.dividerColor)),
            ],
          ),
        );

      case LatexBlockType.comment:
      case LatexBlockType.preamble:
      case LatexBlockType.title:
        return null;

      case LatexBlockType.raw:
        if (block.rawContent.trim().isEmpty) return null;
        return _renderFormattedText(block.rawContent, textStyle);
    }
  }

  Widget _buildTableBlock(LatexBlock block, BuildContext context) {
    final rows = block.rawContent
        .split(r'\\')
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty && !r.startsWith(r'\hline'))
        .toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);

    final grid = rows
        .map((r) => r.split('&').map((c) => c.trim()).toList())
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: borderColor, width: 1),
              children: [
                for (var r = 0; r < grid.length; r++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: r == 0
                          ? (isDark
                                ? const Color(0xFF262A35)
                                : const Color(0xFFF3F4F6))
                          : null,
                    ),
                    children: [
                      for (final cell in grid[r])
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            cell,
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: widget.fontSize * 0.95,
                              fontWeight: r == 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (block.caption != null && block.caption!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Table $_tabNum: ${block.caption}',
              style: TextStyle(
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                fontSize: widget.fontSize * 0.9,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFigureBlock(LatexBlock block, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imagePath = block.imagePath ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          if (imagePath.isNotEmpty && widget.imageBuilder != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: widget.imageBuilder!(context, imagePath),
            )
          else if (imagePath.isNotEmpty)
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF23252E)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image_outlined, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      imagePath,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (block.caption != null && block.caption!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Figure $_figNum: ${block.caption}',
              style: TextStyle(
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                fontSize: widget.fontSize * 0.9,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListBlock(LatexBlock block, TextStyle textStyle) {
    final isEnumerate = block.environment == 'enumerate';
    final items = block.rawContent
        .split(RegExp(r'\\item\b'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      isEnumerate ? '${i + 1}.' : '•',
                      style: textStyle.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(child: _renderFormattedText(items[i], textStyle)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Parses inline math $...$ and basic text formatting like \textbf, \textit
  Widget _renderFormattedText(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final mathRegex = RegExp(
      r'\$([^\$]+)\$|\\textbf\{([^}]+)\}|\\textit\{([^}]+)\}',
    );

    var lastIndex = 0;
    for (final match in mathRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      if (match.group(1) != null) {
        // Inline math
        final mathStr = match.group(1)!;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: NoteMath(mathStr, display: false),
            ),
          ),
        );
      } else if (match.group(2) != null) {
        // \textbf
        spans.add(
          TextSpan(
            text: match.group(2)!,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (match.group(3) != null) {
        // \textit
        spans.add(
          TextSpan(
            text: match.group(3)!,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return Text.rich(TextSpan(children: spans));
  }
}
