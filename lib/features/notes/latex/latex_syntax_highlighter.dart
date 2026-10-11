import 'package:flutter/material.dart';

/// Syntax highlighter and tokenizing controller for raw LaTeX code.
class LatexTextEditingController extends TextEditingController {
  LatexTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Palette calibrated for Orbit Note's calm graphite theme
    final commentStyle = TextStyle(
      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
      fontStyle: FontStyle.italic,
    );
    final commandStyle = TextStyle(
      color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
      fontWeight: FontWeight.w600,
    );
    final envStyle = TextStyle(
      color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
      fontWeight: FontWeight.w600,
    );
    final mathStyle = TextStyle(
      color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
    );
    final bracketStyle = TextStyle(
      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
    );
    final specialStyle = TextStyle(
      color: isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777),
      fontWeight: FontWeight.bold,
    );

    final raw = text;
    if (raw.isEmpty) {
      return TextSpan(style: baseStyle, text: '');
    }

    final spans = <TextSpan>[];
    var index = 0;

    // Regex for LaTeX tokens
    // 1: comment %...
    // 2: display math $$...$$ or \[...\]
    // 3: inline math $...$ or \(...\)
    // 4: begin/end environment \begin{...} / \end{...}
    // 5: command \commandName
    // 6: brackets { } [ ]
    // 7: specials & \\ ^ _
    final tokenRegex = RegExp(
      r'(%.*$)|' // Group 1: comment
      r'(\$\$[\s\S]*?\$\$|\\\[[\s\S]*?\\\])|' // Group 2: display math
      r'(\$[^\$\n]+?\$|\\\(.*?\\\))|' // Group 3: inline math
      r'(\\(?:begin|end)\{[a-zA-Z0-9*]+\})|' // Group 4: environment
      r'(\\[a-zA-Z@]+|\\.)|' // Group 5: command
      r'([\{\}\[\]])|' // Group 6: brackets
      r'([&_^\\])', // Group 7: specials
      multiLine: true,
    );

    final matches = tokenRegex.allMatches(raw);

    for (final m in matches) {
      if (m.start > index) {
        spans.add(
          TextSpan(text: raw.substring(index, m.start), style: baseStyle),
        );
      }

      final matchedText = m.group(0)!;
      TextStyle tokenStyle = baseStyle;

      if (m.group(1) != null) {
        tokenStyle = commentStyle;
      } else if (m.group(2) != null || m.group(3) != null) {
        tokenStyle = mathStyle;
      } else if (m.group(4) != null) {
        tokenStyle = envStyle;
      } else if (m.group(5) != null) {
        tokenStyle = commandStyle;
      } else if (m.group(6) != null) {
        tokenStyle = bracketStyle;
      } else if (m.group(7) != null) {
        tokenStyle = specialStyle;
      }

      spans.add(TextSpan(text: matchedText, style: tokenStyle));

      index = m.end;
    }

    if (index < raw.length) {
      spans.add(TextSpan(text: raw.substring(index), style: baseStyle));
    }

    return TextSpan(style: baseStyle, children: spans);
  }
}

/// Completion suggestion item for LaTeX authoring
class LatexCompletionItem {
  const LatexCompletionItem({
    required this.label,
    required this.insertText,
    required this.detail,
    this.category = 'command',
    this.cursorOffset,
  });

  final String label;
  final String insertText;
  final String detail;
  final String category; // 'command', 'environment', 'symbol', 'label'
  final int? cursorOffset; // offset from end of insertText where cursor lands
}

/// Autocomplete catalog for LaTeX documents
class LatexAutocomplete {
  static const List<LatexCompletionItem> standardItems = [
    // Environments
    LatexCompletionItem(
      label: r'\begin{equation}',
      insertText: "\\begin{equation}\n  \n\\end{equation}",
      detail: 'Numbered display equation',
      category: 'environment',
      cursorOffset: 16,
    ),
    LatexCompletionItem(
      label: r'\begin{equation*}',
      insertText: "\\begin{equation*}\n  \n\\end{equation*}",
      detail: 'Unnumbered display equation',
      category: 'environment',
      cursorOffset: 17,
    ),
    LatexCompletionItem(
      label: r'\begin{align*}',
      insertText: "\\begin{align*}\n  & = \n\\end{align*}",
      detail: 'Multi-line aligned equations',
      category: 'environment',
      cursorOffset: 15,
    ),
    LatexCompletionItem(
      label: r'\begin{pmatrix}',
      insertText: "\\begin{pmatrix}\n  &  \\\\\n  &  \n\\end{pmatrix}",
      detail: 'Matrix with round parentheses',
      category: 'environment',
      cursorOffset: 17,
    ),
    LatexCompletionItem(
      label: r'\begin{bmatrix}',
      insertText: "\\begin{bmatrix}\n  &  \\\\\n  &  \n\\end{bmatrix}",
      detail: 'Matrix with square brackets',
      category: 'environment',
      cursorOffset: 17,
    ),
    LatexCompletionItem(
      label: r'\begin{cases}',
      insertText:
          "\\begin{cases}\n  & \\text{if } \\\\\n  & \\text{otherwise}\n\\end{cases}",
      detail: 'Piecewise case distinction',
      category: 'environment',
      cursorOffset: 14,
    ),
    LatexCompletionItem(
      label: r'\begin{theorem}',
      insertText: "\\begin{theorem}[]\n  \n\\end{theorem}",
      detail: 'Academic Theorem block',
      category: 'environment',
      cursorOffset: 16,
    ),
    LatexCompletionItem(
      label: r'\begin{proof}',
      insertText: "\\begin{proof}\n  \n\\end{proof}",
      detail: 'Mathematical Proof with QED tombstone',
      category: 'environment',
      cursorOffset: 14,
    ),
    LatexCompletionItem(
      label: r'\begin{definition}',
      insertText: "\\begin{definition}[]\n  \n\\end{definition}",
      detail: 'Formal Definition block',
      category: 'environment',
      cursorOffset: 19,
    ),
    LatexCompletionItem(
      label: r'\begin{lemma}',
      insertText: "\\begin{lemma}[]\n  \n\\end{lemma}",
      detail: 'Lemma block',
      category: 'environment',
      cursorOffset: 14,
    ),
    LatexCompletionItem(
      label: r'\begin{corollary}',
      insertText: "\\begin{corollary}[]\n  \n\\end{corollary}",
      detail: 'Corollary block',
      category: 'environment',
      cursorOffset: 18,
    ),
    LatexCompletionItem(
      label: r'\begin{itemize}',
      insertText: "\\begin{itemize}\n  \\item \n\\end{itemize}",
      detail: 'Bulleted list',
      category: 'environment',
      cursorOffset: 24,
    ),
    LatexCompletionItem(
      label: r'\begin{enumerate}',
      insertText: "\\begin{enumerate}\n  \\item \n\\end{enumerate}",
      detail: 'Numbered list',
      category: 'environment',
      cursorOffset: 26,
    ),

    // Common math commands & builders
    LatexCompletionItem(
      label: r'\frac',
      insertText: r'\frac{}{}',
      detail: 'Fraction: {num}{den}',
      cursorOffset: 3,
    ),
    LatexCompletionItem(
      label: r'\sqrt',
      insertText: r'\sqrt{}',
      detail: 'Square root',
      cursorOffset: 1,
    ),
    LatexCompletionItem(
      label: r'\sum',
      insertText: r'\sum_{}^{}',
      detail: 'Summation with limits',
      cursorOffset: 3,
    ),
    LatexCompletionItem(
      label: r'\prod',
      insertText: r'\prod_{}^{}',
      detail: 'Product with limits',
      cursorOffset: 3,
    ),
    LatexCompletionItem(
      label: r'\int',
      insertText: r'\int_{}^{}',
      detail: 'Definite integral',
      cursorOffset: 3,
    ),
    LatexCompletionItem(
      label: r'\lim',
      insertText: r'\lim_{ \to }',
      detail: 'Limit',
      cursorOffset: 5,
    ),
    LatexCompletionItem(
      label: r'\partial',
      insertText: r'\partial',
      detail: 'Partial derivative symbol ∂',
    ),
    LatexCompletionItem(
      label: r'\infty',
      insertText: r'\infty',
      detail: 'Infinity symbol ∞',
    ),
    LatexCompletionItem(
      label: r'\mathbb{R}',
      insertText: r'\mathbb{R}',
      detail: 'Real numbers ℝ',
    ),
    LatexCompletionItem(
      label: r'\mathbb{C}',
      insertText: r'\mathbb{C}',
      detail: 'Complex numbers ℂ',
    ),
    LatexCompletionItem(
      label: r'\mathbb{N}',
      insertText: r'\mathbb{N}',
      detail: 'Natural numbers ℕ',
    ),
    LatexCompletionItem(
      label: r'\mathbb{Z}',
      insertText: r'\mathbb{Z}',
      detail: 'Integers ℤ',
    ),
    LatexCompletionItem(
      label: r'\mathbf',
      insertText: r'\mathbf{}',
      detail: 'Bold vector / tensor',
      cursorOffset: 1,
    ),
    LatexCompletionItem(
      label: r'\vec',
      insertText: r'\vec{}',
      detail: 'Vector arrow',
      cursorOffset: 1,
    ),
    LatexCompletionItem(
      label: r'\hat',
      insertText: r'\hat{}',
      detail: 'Unit vector / estimator hat',
      cursorOffset: 1,
    ),

    // Greeks
    LatexCompletionItem(
      label: r'\alpha',
      insertText: r'\alpha',
      detail: 'Greek letter α',
    ),
    LatexCompletionItem(
      label: r'\beta',
      insertText: r'\beta',
      detail: 'Greek letter β',
    ),
    LatexCompletionItem(
      label: r'\gamma',
      insertText: r'\gamma',
      detail: 'Greek letter γ',
    ),
    LatexCompletionItem(
      label: r'\delta',
      insertText: r'\delta',
      detail: 'Greek letter δ',
    ),
    LatexCompletionItem(
      label: r'\epsilon',
      insertText: r'\epsilon',
      detail: 'Greek letter ϵ',
    ),
    LatexCompletionItem(
      label: r'\theta',
      insertText: r'\theta',
      detail: 'Greek letter θ',
    ),
    LatexCompletionItem(
      label: r'\lambda',
      insertText: r'\lambda',
      detail: 'Greek letter λ / eigenvalue',
    ),
    LatexCompletionItem(
      label: r'\mu',
      insertText: r'\mu',
      detail: 'Greek letter μ / mean',
    ),
    LatexCompletionItem(
      label: r'\pi',
      insertText: r'\pi',
      detail: 'Greek letter π',
    ),
    LatexCompletionItem(
      label: r'\sigma',
      insertText: r'\sigma',
      detail: 'Greek letter σ / std dev',
    ),
    LatexCompletionItem(
      label: r'\tau',
      insertText: r'\tau',
      detail: 'Greek letter τ',
    ),
    LatexCompletionItem(
      label: r'\phi',
      insertText: r'\phi',
      detail: 'Greek letter ϕ',
    ),
    LatexCompletionItem(
      label: r'\psi',
      insertText: r'\psi',
      detail: 'Greek letter ψ',
    ),
    LatexCompletionItem(
      label: r'\omega',
      insertText: r'\omega',
      detail: 'Greek letter ω',
    ),
    LatexCompletionItem(
      label: r'\Delta',
      insertText: r'\Delta',
      detail: 'Greek capital Delta Δ',
    ),
    LatexCompletionItem(
      label: r'\Sigma',
      insertText: r'\Sigma',
      detail: 'Greek capital Sigma Σ',
    ),
    LatexCompletionItem(
      label: r'\Omega',
      insertText: r'\Omega',
      detail: 'Greek capital Omega Ω',
    ),

    // Logic and sets
    LatexCompletionItem(
      label: r'\in',
      insertText: r'\in',
      detail: 'Element of ∈',
    ),
    LatexCompletionItem(
      label: r'\notin',
      insertText: r'\notin',
      detail: 'Not element of ∉',
    ),
    LatexCompletionItem(
      label: r'\subset',
      insertText: r'\subset',
      detail: 'Subset ⊂',
    ),
    LatexCompletionItem(
      label: r'\subseteq',
      insertText: r'\subseteq',
      detail: 'Subset or equal ⊆',
    ),
    LatexCompletionItem(label: r'\cup', insertText: r'\cup', detail: 'Union ∪'),
    LatexCompletionItem(
      label: r'\cap',
      insertText: r'\cap',
      detail: 'Intersection ∩',
    ),
    LatexCompletionItem(
      label: r'\forall',
      insertText: r'\forall',
      detail: 'For all ∀',
    ),
    LatexCompletionItem(
      label: r'\exists',
      insertText: r'\exists',
      detail: 'There exists ∃',
    ),
    LatexCompletionItem(
      label: r'\implies',
      insertText: r'\implies',
      detail: 'Implies ⟹',
    ),
    LatexCompletionItem(
      label: r'\iff',
      insertText: r'\iff',
      detail: 'If and only if ⟺',
    ),

    // Document structure
    LatexCompletionItem(
      label: r'\section',
      insertText: r'\section{}',
      detail: 'Section heading',
      cursorOffset: 1,
    ),
    LatexCompletionItem(
      label: r'\subsection',
      insertText: r'\subsection{}',
      detail: 'Subsection heading',
      cursorOffset: 1,
    ),
    LatexCompletionItem(
      label: r'\subsubsection',
      insertText: r'\subsubsection{}',
      detail: 'Subsubsection heading',
      cursorOffset: 1,
    ),
    LatexCompletionItem(
      label: r'\label',
      insertText: r'\label{}',
      detail: 'Cross-reference anchor',
      cursorOffset: 1,
    ),
    LatexCompletionItem(
      label: r'\ref',
      insertText: r'\ref{}',
      detail: 'Cross-reference',
      cursorOffset: 1,
    ),
    LatexCompletionItem(
      label: r'\eqref',
      insertText: r'\eqref{}',
      detail: 'Equation reference (1)',
      cursorOffset: 1,
    ),
    LatexCompletionItem(
      label: r'\cite',
      insertText: r'\cite{}',
      detail: 'Citation reference',
      cursorOffset: 1,
    ),
    LatexCompletionItem(
      label: r'\footnote',
      insertText: r'\footnote{}',
      detail: 'Footnote',
      cursorOffset: 1,
    ),
    LatexCompletionItem(
      label: r'\textbf',
      insertText: r'\textbf{}',
      detail: 'Bold text',
      cursorOffset: 1,
    ),
    LatexCompletionItem(
      label: r'\textit',
      insertText: r'\textit{}',
      detail: 'Italic text',
      cursorOffset: 1,
    ),
    LatexCompletionItem(
      label: r'\text',
      insertText: r'\text{}',
      detail: 'Text inside math mode',
      cursorOffset: 1,
    ),
  ];

  /// Find completion suggestions based on current document text and cursor position
  static List<LatexCompletionItem> getSuggestions({
    required String text,
    required int cursorPosition,
  }) {
    if (cursorPosition <= 0 || text.isEmpty) return [];

    final safePos = cursorPosition.clamp(0, text.length);
    final textBeforeCursor = text.substring(0, safePos);

    // 1. Check if user is typing a \ref{...} or \eqref{...}
    final refMatch = RegExp(
      r'\\(?:eq)?ref\{([a-zA-Z0-9_:-]*)$',
    ).firstMatch(textBeforeCursor);
    if (refMatch != null) {
      final refQuery = refMatch.group(1)!.toLowerCase();
      // Extract all \label{...} from the document
      final labelRegex = RegExp(r'\\label\{([^}]+)\}');
      final labels = labelRegex
          .allMatches(text)
          .map((m) => m.group(1)!)
          .toSet();
      return labels
          .where((l) => l.toLowerCase().contains(refQuery))
          .map(
            (l) => LatexCompletionItem(
              label: l,
              insertText: l,
              detail: 'Document label',
              category: 'label',
            ),
          )
          .toList();
    }

    // 2. Check if user is typing \begin{...}
    final beginMatch = RegExp(
      r'\\begin\{([a-zA-Z0-9*]*)$',
    ).firstMatch(textBeforeCursor);
    if (beginMatch != null) {
      final envQuery = beginMatch.group(1)!.toLowerCase();
      return standardItems
          .where(
            (item) =>
                item.category == 'environment' &&
                item.label.toLowerCase().contains(envQuery),
          )
          .toList();
    }

    // 3. Command or environment starting with \
    final match = RegExp(r'\\([a-zA-Z0-9*]*)$').firstMatch(textBeforeCursor);
    if (match == null) return [];

    final query = match.group(0)!; // e.g. "\eq" or "\" or "\be"
    final queryWithoutBackslash = match.group(1)!;

    // Standard command / environment matches
    return standardItems.where((item) {
      if (item.label.startsWith(query)) return true;
      if (item.label.startsWith('\\$queryWithoutBackslash')) return true;
      return false;
    }).toList();
  }
}
