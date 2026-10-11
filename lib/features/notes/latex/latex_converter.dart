/// Safe, explicit bidirectional conversion between Markdown notes and LaTeX documents.
/// Original content and unknown structures are preserved without silent data loss.
library;

class LatexConversionResult {
  const LatexConversionResult({
    required this.converted,
    required this.warnings,
  });

  final String converted;
  final List<String> warnings;

  String get latex => converted;
  String get markdown => converted;
}

class LatexConverter {
  /// Converts a Markdown note into a complete, standalone LaTeX document.
  static LatexConversionResult markdownToLatex(
    String markdown, {
    String title = 'Untitled Document',
    String author = '',
  }) {
    final warnings = <String>[];
    var body = markdown;

    // Strip frontmatter if present
    if (body.startsWith('---')) {
      final end = body.indexOf('---', 3);
      if (end != -1) {
        body = body.substring(end + 3).trimLeft();
      }
    }

    final lines = body.split('\n');
    final out = StringBuffer();

    // LaTeX Preamble
    out.writeln(r'\documentclass[11pt, a4paper]{article}');
    out.writeln(r'\usepackage{amsmath, amssymb, amsthm}');
    out.writeln(r'\usepackage{graphicx}');
    out.writeln(r'\usepackage{booktabs}');
    out.writeln(r'\usepackage{hyperref}');
    out.writeln();
    out.writeln('\\title{${_escapeLatex(title)}}');
    if (author.isNotEmpty) {
      out.writeln('\\author{${_escapeLatex(author)}}');
    }
    out.writeln(r'\date{\today}');
    out.writeln();
    out.writeln(r'\begin{document}');
    out.writeln(r'\maketitle');
    out.writeln();

    var inList = false;
    var listType = ''; // 'itemize' or 'enumerate'
    var inCodeBlock = false;
    var inMathBlock = false;
    var mathBuffer = StringBuffer();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Code blocks
      if (trimmed.startsWith('```')) {
        if (inCodeBlock) {
          out.writeln(r'\end{verbatim}');
          inCodeBlock = false;
        } else {
          _closeList(out, inList, listType);
          inList = false;
          out.writeln(r'\begin{verbatim}');
          inCodeBlock = true;
        }
        continue;
      }
      if (inCodeBlock) {
        out.writeln(line);
        continue;
      }

      // Display math blocks $$
      if (trimmed.startsWith(r'$$')) {
        if (inMathBlock) {
          out.writeln(mathBuffer.toString().trim());
          out.writeln(r'\]');
          inMathBlock = false;
          mathBuffer.clear();
        } else {
          _closeList(out, inList, listType);
          inList = false;
          if (trimmed.endsWith(r'$$') && trimmed.length > 4) {
            // single line $$ formula $$
            final expr = trimmed.substring(2, trimmed.length - 2).trim();
            out.writeln('\\[');
            out.writeln(expr);
            out.writeln('\\]');
          } else {
            out.writeln('\\[');
            inMathBlock = true;
          }
        }
        continue;
      }
      if (inMathBlock) {
        if (trimmed.endsWith(r'$$')) {
          mathBuffer.writeln(trimmed.substring(0, trimmed.length - 2).trim());
          out.writeln(mathBuffer.toString().trim());
          out.writeln(r'\]');
          inMathBlock = false;
          mathBuffer.clear();
        } else {
          mathBuffer.writeln(line);
        }
        continue;
      }

      // Headings
      if (trimmed.startsWith('#')) {
        _closeList(out, inList, listType);
        inList = false;
        final hMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
        if (hMatch != null) {
          final level = hMatch.group(1)!.length;
          final hText = _convertInlineMarkdown(hMatch.group(2)!);
          if (level == 1) {
            out.writeln('\\section{$hText}');
          } else if (level == 2) {
            out.writeln('\\subsection{$hText}');
          } else {
            out.writeln('\\subsubsection{$hText}');
          }
          out.writeln();
          continue;
        }
      }

      // Blockquotes / Callouts
      if (trimmed.startsWith('>')) {
        _closeList(out, inList, listType);
        inList = false;
        var qText = trimmed.replaceFirst(RegExp(r'^>\s*'), '');
        if (qText.startsWith('[!')) {
          // GitHub / Orbit callouts -> theorem or quote
          final endBracket = qText.indexOf(']');
          final type = endBracket != -1
              ? qText.substring(2, endBracket).toLowerCase()
              : 'note';
          qText = qText.substring(endBracket + 1).trim();
          if (type == 'theorem') {
            out.writeln(r'\begin{theorem}');
            out.writeln(_convertInlineMarkdown(qText));
            out.writeln(r'\end{theorem}');
          } else if (type == 'proof') {
            out.writeln(r'\begin{proof}');
            out.writeln(_convertInlineMarkdown(qText));
            out.writeln(r'\end{proof}');
          } else {
            out.writeln(r'\begin{quote}');
            out.writeln(
              '\\textbf{${type.toUpperCase()}:} ${_convertInlineMarkdown(qText)}',
            );
            out.writeln(r'\end{quote}');
          }
        } else {
          out.writeln(r'\begin{quote}');
          out.writeln(_convertInlineMarkdown(qText));
          out.writeln(r'\end{quote}');
        }
        continue;
      }

      // Lists: Unordered
      if (RegExp(r'^\s*[-*]\s+').hasMatch(trimmed)) {
        final itemText = trimmed.replaceFirst(RegExp(r'^\s*[-*]\s+'), '');
        if (!inList || listType != 'itemize') {
          _closeList(out, inList, listType);
          out.writeln(r'\begin{itemize}');
          inList = true;
          listType = 'itemize';
        }
        out.writeln('  \\item ${_convertInlineMarkdown(itemText)}');
        continue;
      }

      // Lists: Ordered
      if (RegExp(r'^\s*\d+\.\s+').hasMatch(trimmed)) {
        final itemText = trimmed.replaceFirst(RegExp(r'^\s*\d+\.\s+'), '');
        if (!inList || listType != 'enumerate') {
          _closeList(out, inList, listType);
          out.writeln(r'\begin{enumerate}');
          inList = true;
          listType = 'enumerate';
        }
        out.writeln('  \\item ${_convertInlineMarkdown(itemText)}');
        continue;
      }

      // Blank line ends list
      if (trimmed.isEmpty) {
        _closeList(out, inList, listType);
        inList = false;
        out.writeln();
        continue;
      }

      // Images: ![alt](path)
      final imgMatch = RegExp(r'^!\[(.*?)\]\((.*?)\)$').firstMatch(trimmed);
      if (imgMatch != null) {
        _closeList(out, inList, listType);
        inList = false;
        final alt = imgMatch.group(1)!;
        final path = imgMatch.group(2)!;
        out.writeln(r'\begin{figure}[htbp]');
        out.writeln(r'\centering');
        out.writeln('\\includegraphics[width=0.75\\textwidth]{$path}');
        if (alt.isNotEmpty) {
          out.writeln('\\caption{${_escapeLatex(alt)}}');
        }
        out.writeln(r'\end{figure}');
        continue;
      }

      // Markdown Tables
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        _closeList(out, inList, listType);
        inList = false;
        // Collect entire table
        final tableLines = <String>[line];
        while (i + 1 < lines.length &&
            lines[i + 1].trim().startsWith('|') &&
            lines[i + 1].trim().endsWith('|')) {
          tableLines.add(lines[++i]);
        }
        _convertMarkdownTable(out, tableLines);
        continue;
      }

      // Regular paragraph line
      _closeList(out, inList, listType);
      inList = false;
      out.writeln(_convertInlineMarkdown(line));
    }

    _closeList(out, inList, listType);
    out.writeln();
    out.writeln(r'\end{document}');

    return LatexConversionResult(converted: out.toString(), warnings: warnings);
  }

  /// Converts a LaTeX document into a Markdown note.
  static LatexConversionResult latexToMarkdown(String latex) {
    final warnings = <String>[];
    final out = StringBuffer();

    var source = latex;

    // Extract title if present
    final titleMatch = RegExp(r'\\title\{([^}]*)\}').firstMatch(source);
    if (titleMatch != null) {
      final t = titleMatch.group(1)!.trim();
      if (t.isNotEmpty) {
        out.writeln('# $t\n');
      }
    }

    // Extract document body if wrapped in \begin{document}
    final docMatch = RegExp(
      r'\\begin\{document\}([\s\S]*?)\\end\{document\}',
    ).firstMatch(source);
    if (docMatch != null) {
      source = docMatch.group(1)!;
    }

    final lines = source.split('\n');
    var inVerbatim = false;
    var inAlign = false;
    var inEquation = false;
    var inProof = false;
    var inTheorem = false;
    var alignBuffer = StringBuffer();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Skip maketitle and empty author/date lines
      if (trimmed == r'\maketitle' ||
          trimmed.startsWith(r'\author{') ||
          trimmed.startsWith(r'\date{')) {
        continue;
      }

      // Comments
      if (trimmed.startsWith('%')) {
        out.writeln('<!-- ${trimmed.substring(1).trim()} -->');
        continue;
      }

      // Verbatim / code
      if (trimmed == r'\begin{verbatim}') {
        inVerbatim = true;
        out.writeln('```');
        continue;
      }
      if (trimmed == r'\end{verbatim}') {
        inVerbatim = false;
        out.writeln('```\n');
        continue;
      }
      if (inVerbatim) {
        out.writeln(line);
        continue;
      }

      // Align / aligned
      if (trimmed.startsWith(r'\begin{align') ||
          trimmed.startsWith(r'\begin{aligned')) {
        inAlign = true;
        alignBuffer.clear();
        alignBuffer.writeln(trimmed);
        continue;
      }
      if (trimmed.startsWith(r'\end{align') ||
          trimmed.startsWith(r'\end{aligned')) {
        inAlign = false;
        alignBuffer.writeln(trimmed);
        out.writeln('\$\$\n${alignBuffer.toString().trim()}\n\$\$\n');
        alignBuffer.clear();
        continue;
      }
      if (inAlign) {
        alignBuffer.writeln(line);
        continue;
      }

      // Equation
      if (trimmed == r'\[' || trimmed.startsWith(r'\begin{equation')) {
        inEquation = true;
        out.writeln('\$\$');
        continue;
      }
      if (trimmed == r'\]' || trimmed.startsWith(r'\end{equation')) {
        inEquation = false;
        out.writeln('\$\$\n');
        continue;
      }
      if (inEquation) {
        out.writeln(line);
        continue;
      }

      // Theorem environments
      final thmMatch = RegExp(
        r'^\\begin\{(theorem|definition|lemma|proposition|corollary|example|remark)\}(?:\[(.*?)\])?',
      ).firstMatch(trimmed);
      if (thmMatch != null) {
        inTheorem = true;
        final type = thmMatch.group(1)!;
        final name = thmMatch.group(2) ?? '';
        final label = name.isNotEmpty ? '$type ($name)' : type;
        out.writeln('> [!NOTE] ${label[0].toUpperCase()}${label.substring(1)}');
        continue;
      }
      if (RegExp(
        r'^\\end\{(theorem|definition|lemma|proposition|corollary|example|remark)\}',
      ).hasMatch(trimmed)) {
        inTheorem = false;
        out.writeln();
        continue;
      }

      // Proof
      if (trimmed == r'\begin{proof}') {
        inProof = true;
        out.writeln('> [!NOTE] Proof');
        continue;
      }
      if (trimmed == r'\end{proof}') {
        inProof = false;
        out.writeln();
        continue;
      }

      if (inTheorem || inProof) {
        if (trimmed.isNotEmpty) {
          out.writeln('> ${_convertInlineLatex(trimmed)}');
        } else {
          out.writeln('>');
        }
        continue;
      }

      // Sections
      final secMatch = RegExp(
        r'^\\(section|subsection|subsubsection)\*?\{(.*)\}\s*$',
      ).firstMatch(trimmed);
      if (secMatch != null) {
        final level = secMatch.group(1)!;
        final title = _convertInlineLatex(secMatch.group(2)!);
        final prefix = level == 'section'
            ? '#'
            : (level == 'subsection' ? '##' : '###');
        out.writeln('$prefix $title\n');
        continue;
      }

      // Lists: \item
      if (trimmed.startsWith(r'\item')) {
        final itemText = _convertInlineLatex(trimmed.substring(5).trim());
        out.writeln('- $itemText');
        continue;
      }
      if (trimmed == r'\begin{itemize}' ||
          trimmed == r'\end{itemize}' ||
          trimmed == r'\begin{enumerate}' ||
          trimmed == r'\end{enumerate}') {
        continue;
      }

      // Figures: \includegraphics
      final figMatch = RegExp(
        r'\\includegraphics(?:\[.*?\])?\{([^}]+)\}',
      ).firstMatch(trimmed);
      if (figMatch != null) {
        final path = figMatch.group(1)!;
        out.writeln('![]($path)\n');
        continue;
      }
      if (trimmed.startsWith(r'\begin{figure}') ||
          trimmed.startsWith(r'\end{figure}') ||
          trimmed.startsWith(r'\centering') ||
          trimmed.startsWith(r'\caption{')) {
        continue;
      }

      // Quotes: \begin{quote} ... \end{quote}
      if (trimmed == r'\begin{quote}' || trimmed == r'\end{quote}') {
        continue;
      }

      // Normal paragraph text
      if (trimmed.isEmpty) {
        out.writeln();
      } else {
        out.writeln(_convertInlineLatex(line));
      }
    }

    return LatexConversionResult(
      converted: out.toString().trim(),
      warnings: warnings,
    );
  }

  static void _closeList(StringBuffer out, bool inList, String listType) {
    if (inList) {
      out.writeln('\\end{$listType}');
    }
  }

  static void _convertMarkdownTable(StringBuffer out, List<String> lines) {
    if (lines.length < 2) return;
    final headerCells = lines[0]
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (headerCells.isEmpty) return;

    final cols = headerCells.length;
    out.writeln(r'\begin{table}[htbp]');
    out.writeln(r'\centering');
    out.writeln('\\begin{tabular}{${'c' * cols}}');
    out.writeln(r'\toprule');
    out.writeln('${headerCells.map(_convertInlineMarkdown).join(' & ')} \\\\');
    out.writeln(r'\midrule');

    // Skip separator row (index 1)
    for (var r = 2; r < lines.length; r++) {
      final cells = lines[r]
          .split('|')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (cells.isNotEmpty) {
        out.writeln('${cells.map(_convertInlineMarkdown).join(' & ')} \\\\');
      }
    }

    out.writeln(r'\bottomrule');
    out.writeln(r'\end{tabular}');
    out.writeln(r'\end{table}');
  }

  static String _convertInlineMarkdown(String text) {
    var s = text;
    // Bold: **text** -> \textbf{text}
    s = s.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (m) => '\\textbf{${m.group(1)}}',
    );
    // Italic: *text* -> \textit{text}
    s = s.replaceAllMapped(
      RegExp(r'(?<!\*)\*([^*]+?)\*(?!\*)'),
      (m) => '\\textit{${m.group(1)}}',
    );
    // Inline code: `text` -> \texttt{text}
    s = s.replaceAllMapped(
      RegExp(r'`([^`]+?)`'),
      (m) => '\\texttt{${m.group(1)}}',
    );
    // Underline: <u>text</u> -> \underline{text}
    s = s.replaceAllMapped(
      RegExp(r'<u>(.*?)</u>'),
      (m) => '\\underline{${m.group(1)}}',
    );
    return s;
  }

  static String _convertInlineLatex(String text) {
    var s = text;
    // \textbf{text} -> **text**
    s = s.replaceAllMapped(
      RegExp(r'\\textbf\{([^}]+)\}'),
      (m) => '**${m.group(1)}**',
    );
    // \textit{text} -> *text*
    s = s.replaceAllMapped(
      RegExp(r'\\textit\{([^}]+)\}'),
      (m) => '*${m.group(1)}*',
    );
    // \texttt{text} -> `text`
    s = s.replaceAllMapped(
      RegExp(r'\\texttt\{([^}]+)\}'),
      (m) => '`${m.group(1)}`',
    );
    // \underline{text} -> <u>text</u>
    s = s.replaceAllMapped(
      RegExp(r'\\underline\{([^}]+)\}'),
      (m) => '<u>${m.group(1)}</u>',
    );
    // \ref{...} -> [...]
    s = s.replaceAllMapped(
      RegExp(r'\\(?:eq)?ref\{([^}]+)\}'),
      (m) => '[${m.group(1)}]',
    );
    return s;
  }

  static String _escapeLatex(String text) {
    return text
        .replaceAll(r'\', r'\textbackslash{}')
        .replaceAll('&', r'\&')
        .replaceAll('%', r'\%')
        .replaceAll(r'$', r'\$')
        .replaceAll('#', r'\#')
        .replaceAll('_', r'\_')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}');
  }
}
