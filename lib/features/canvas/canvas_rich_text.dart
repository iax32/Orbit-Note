import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'canvas_painter.dart';

/// The recognized line formats inside a canvas sticky note or card.
enum CanvasRichLineType {
  heading1,
  heading2,
  heading3,
  checklistUnchecked,
  checklistChecked,
  bullet,
  numbered,
  displayMath,
  codeBlock,
  blockquote,
  paragraph,
  empty,
}

/// A parsed line of rich content.
class CanvasRichLine {
  const CanvasRichLine({
    required this.type,
    required this.rawText,
    required this.contentText,
    required this.lineIndex,
    this.prefix,
  });

  final CanvasRichLineType type;
  final String rawText;
  final String contentText;
  final int lineIndex;
  final String? prefix;
}

/// Rich text layout, painting, and hit testing for Canvas sticky notes and cards.
class CanvasRichText {
  const CanvasRichText._();

  static final RegExp _h1Regex = RegExp(r'^#\s+(.*)$');
  static final RegExp _h2Regex = RegExp(r'^##\s+(.*)$');
  static final RegExp _h3Regex = RegExp(r'^###\s+(.*)$');
  static final RegExp _checkedRegex = RegExp(r'^\s*[-*]?\s*\[[xX]\]\s*(.*)$');
  static final RegExp _uncheckedRegex = RegExp(r'^\s*[-*]?\s*\[ \]\s*(.*)$');
  static final RegExp _bulletRegex = RegExp(r'^\s*[-*]\s+(.*)$');
  static final RegExp _numberedRegex = RegExp(r'^\s*(\d+)\.\s+(.*)$');

  /// Converts common LaTeX mathematical constructs into clean Unicode symbols and formatting.
  static String formatMathToUnicode(String tex) {
    if (tex.trim().isEmpty) return '';
    var s = tex.trim();

    // Strip out display math delimiters if passed in
    if (s.startsWith(r'$$') && s.endsWith(r'$$') && s.length >= 4) {
      s = s.substring(2, s.length - 2).trim();
    } else if (s.startsWith(r'$') && s.endsWith(r'$') && s.length >= 2) {
      s = s.substring(1, s.length - 1).trim();
    }

    // Bounded readable matrix previews; authored TeX remains on the card.
    // Keep unsupported/nested environments on the existing source fallback.
    s = s.replaceAllMapped(
      RegExp(
        r'\\begin\{(pmatrix|bmatrix|matrix|array)\}(\{[rcl|]+\})?([\s\S]*?)\\end\{\1\}',
      ),
      (m) {
        final array = m[1] == 'array';
        if (array && m[2] == null) return m[0]!;
        final body = array ? m[3]! : '${m[2] ?? ''}${m[3]}';
        if (body.length > (array ? 65536 : 4096) || body.contains(r'\begin')) {
          return m[0]!;
        }
        final rows = body
            .split(r'\\')
            .map(
              (row) => row
                  .split('&')
                  .map((cell) => formatMathToUnicode(cell.trim()))
                  .toList(),
            )
            .toList();
        if (rows.isEmpty ||
            rows.length > (array ? 102 : 6) ||
            rows.first.isEmpty ||
            rows.first.length > 6 ||
            rows.any(
              (row) =>
                  row.length != rows.first.length ||
                  row.any((cell) => cell.isEmpty || cell.length > 200),
            )) {
          return m[0]!;
        }
        final widths = List.generate(
          rows.first.length,
          (c) => rows.map((row) => row[c].length).reduce(math.max),
        );
        String rowText(int r) => List.generate(
          widths.length,
          (c) => rows[r][c].padLeft(widths[c]),
        ).join('  ');
        final round = m[1] == 'pmatrix';
        if (rows.length == 1) {
          return '${round ? '(' : '['} ${rowText(0)} ${round ? ')' : ']'}';
        }
        return List.generate(rows.length, (r) {
          final left = r == 0
              ? (round ? '⎛' : '⎡')
              : r == rows.length - 1
              ? (round ? '⎝' : '⎣')
              : (round ? '⎜' : '⎢');
          final right = r == 0
              ? (round ? '⎞' : '⎤')
              : r == rows.length - 1
              ? (round ? '⎠' : '⎦')
              : (round ? '⎟' : '⎥');
          return '$left ${rowText(r)} $right';
        }).join('\n');
      },
    );

    s = s.replaceAllMapped(
      RegExp(r'\\begin\{(aligned|gathered)\}([\s\S]*?)\\end\{\1\}'),
      (m) {
        if (m[2]!.length > 4096 || m[2]!.contains(r'\begin')) return m[0]!;
        return m[2]!.replaceAll('&', '').replaceAll(r'\\', '\n');
      },
    );

    // Replace text formatting wrappers: \text{...}, \mathrm{...}, \mathbf{...}, etc.
    s = s.replaceAllMapped(
      RegExp(
        r'\\(?:text|mathrm|mathbf|mathit|textbf|textrm|operatorname)\{([^}]*)\}',
      ),
      (m) => m.group(1)!,
    );

    // Theorem and proof environments
    s = s.replaceAllMapped(
      RegExp(
        r'\\begin\{(theorem|lemma|definition|proposition|corollary|example)\}(?:\[([^\]]*)\])?',
        caseSensitive: false,
      ),
      (m) {
        final env = m.group(1)!.toLowerCase();
        final name = env[0].toUpperCase() + env.substring(1);
        final opt = m.group(2);
        return opt != null && opt.isNotEmpty ? '[$name ($opt)] ' : '[$name] ';
      },
    );
    s = s.replaceAll(
      RegExp(
        r'\\end\{(theorem|lemma|definition|proposition|corollary|example)\}',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceAll(
      RegExp(r'\\begin\{proof\}', caseSensitive: false),
      '[Proof] ',
    );
    s = s.replaceAll(RegExp(r'\\end\{proof\}', caseSensitive: false), ' ∎');
    s = s.replaceAll(r'\qed', '∎');
    s = s.replaceAll(r'\mathbb{R}', 'ℝ');
    s = s.replaceAll(r'\mathbb{C}', 'ℂ');
    s = s.replaceAll(r'\mathbb{N}', 'ℕ');
    s = s.replaceAll(r'\mathbb{Z}', 'ℤ');
    s = s.replaceAll(r'\mathbb{Q}', 'ℚ');

    // Common fractions: \frac{a}{b}
    while (s.contains(r'\frac')) {
      final fracMatch = RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}').firstMatch(s);
      if (fracMatch == null) break;
      final num = fracMatch.group(1)!.trim();
      final den = fracMatch.group(2)!.trim();
      final replacement = _formatFraction(num, den);
      s = s.replaceRange(fracMatch.start, fracMatch.end, replacement);
    }

    // Square roots: \sqrt[n]{x} and \sqrt{x}
    s = s.replaceAllMapped(RegExp(r'\\sqrt\[([^\]]+)\]\{([^}]+)\}'), (m) {
      final n = _toSuperscript(m.group(1)!);
      return '$n√(${m.group(2)!})';
    });
    s = s.replaceAllMapped(
      RegExp(r'\\sqrt\{([^}]+)\}'),
      (m) => '√(${m.group(1)!})',
    );

    // Greek letters (lowercase)
    const greekLower = {
      r'\alpha': 'α',
      r'\beta': 'β',
      r'\gamma': 'γ',
      r'\delta': 'δ',
      r'\epsilon': 'ε',
      r'\varepsilon': 'ε',
      r'\zeta': 'ζ',
      r'\eta': 'η',
      r'\theta': 'θ',
      r'\vartheta': 'ϑ',
      r'\iota': 'ι',
      r'\kappa': 'κ',
      r'\lambda': 'λ',
      r'\mu': 'μ',
      r'\nu': 'ν',
      r'\xi': 'ξ',
      r'\pi': 'π',
      r'\varpi': 'ϖ',
      r'\rho': 'ρ',
      r'\varrho': 'ϱ',
      r'\sigma': 'σ',
      r'\varsigma': 'ς',
      r'\tau': 'τ',
      r'\upsilon': 'υ',
      r'\phi': 'φ',
      r'\varphi': 'ϕ',
      r'\chi': 'χ',
      r'\psi': 'ψ',
      r'\omega': 'ω',
    };
    greekLower.forEach((k, v) => s = s.replaceAll(k, v));

    // Greek letters (uppercase)
    const greekUpper = {
      r'\Gamma': 'Γ',
      r'\Delta': 'Δ',
      r'\Theta': 'Θ',
      r'\Lambda': 'Λ',
      r'\Xi': 'Ξ',
      r'\Pi': 'Π',
      r'\Sigma': 'Σ',
      r'\Upsilon': 'Υ',
      r'\Phi': 'Φ',
      r'\Psi': 'Ψ',
      r'\Omega': 'Ω',
    };
    greekUpper.forEach((k, v) => s = s.replaceAll(k, v));

    // Mathematical symbols & operators
    const mathSymbols = {
      r'\times': '×',
      r'\div': '÷',
      r'\cdot': '·',
      r'\pm': '±',
      r'\mp': '∓',
      r'\neq': '≠',
      r'\ne': '≠',
      r'\leq': '≤',
      r'\le': '≤',
      r'\geq': '≥',
      r'\ge': '≥',
      r'\approx': '≈',
      r'\equiv': '≡',
      r'\sim': '∼',
      r'\propto': '∝',
      r'\infty': '∞',
      r'\partial': '∂',
      r'\nabla': '∇',
      r'\hbar': 'ℏ',
      r'\sum': '∑',
      r'\prod': '∏',
      r'\int': '∫',
      r'\iint': '∬',
      r'\iiint': '∭',
      r'\oint': '∮',
      r'\in': '∈',
      r'\notin': '∉',
      r'\subset': '⊂',
      r'\subseteq': '⊆',
      r'\supset': '⊃',
      r'\supseteq': '⊇',
      r'\cup': '∪',
      r'\cap': '∩',
      r'\setminus': '∖',
      r'\forall': '∀',
      r'\exists': '∃',
      r'\nexists': '∄',
      r'\emptyset': '∅',
      r'\neg': '¬',
      r'\lor': '∨',
      r'\land': '∧',
      r'\leftarrow': '←',
      r'\rightarrow': '→',
      r'\to': '→',
      r'\Leftarrow': '⇐',
      r'\Rightarrow': '⇒',
      r'\implies': '⇒',
      r'\iff': '⇔',
      r'\leftrightarrow': '↔',
      r'\Leftrightarrow': '⇔',
      r'\circ': '∘',
      r'\bullet': '•',
      r'\star': '⋆',
      r'\angle': '∠',
      r'\perp': '⊥',
    };
    mathSymbols.forEach((k, v) => s = s.replaceAll(k, v));

    // Functions
    const funcs = [
      r'\sin',
      r'\cos',
      r'\tan',
      r'\csc',
      r'\sec',
      r'\cot',
      r'\arcsin',
      r'\arccos',
      r'\arctan',
      r'\sinh',
      r'\cosh',
      r'\tanh',
      r'\ln',
      r'\log',
      r'\exp',
      r'\det',
      r'\dim',
      r'\ker',
      r'\lim',
    ];
    for (final f in funcs) {
      s = s.replaceAll(f, f.substring(1));
    }

    // Subscripts: _{...} or _x
    s = s.replaceAllMapped(
      RegExp(r'_\{([^{}]+)\}'),
      (m) => _toSubscript(m.group(1)!),
    );
    s = s.replaceAllMapped(
      RegExp(r'_([0-9a-zA-Z\+\-\=])'),
      (m) => _toSubscript(m.group(1)!),
    );

    // Superscripts: ^{...} or ^x
    s = s.replaceAllMapped(
      RegExp(r'\^\{([^{}]+)\}'),
      (m) => _toSuperscript(m.group(1)!),
    );
    s = s.replaceAllMapped(
      RegExp(r'\^([0-9a-zA-Z\+\-\=])'),
      (m) => _toSuperscript(m.group(1)!),
    );

    // Clean up LaTeX spacing and delimiters
    s = s.replaceAll(r'\left(', '(').replaceAll(r'\right)', ')');
    s = s.replaceAll(r'\left[', '[').replaceAll(r'\right]', ']');
    s = s.replaceAll(r'\left\{', '{').replaceAll(r'\right\}', '}');
    s = s.replaceAll(r'\left.', '').replaceAll(r'\right.', '');
    s = s.replaceAll(r'\left|', '|').replaceAll(r'\right|', '|');
    s = s
        .replaceAll(r'\,', ' ')
        .replaceAll(r'\;', ' ')
        .replaceAll(r'\quad', '  ');
    s = s.replaceAll(r'\\', ' ');

    // Strip stray unescaped backslashes before words
    s = s.replaceAllMapped(RegExp(r'\\([a-zA-Z]+)'), (m) => m.group(1)!);

    return s;
  }

  static String _formatFraction(String num, String den) {
    if (num == '1' && den == '2') return '½';
    if (num == '1' && den == '4') return '¼';
    if (num == '3' && den == '4') return '¾';
    if (num == '1' && den == '3') return '⅓';
    if (num == '2' && den == '3') return '⅔';
    if (num == '1' && den == '5') return '⅕';
    if (num.length <= 3 &&
        den.length <= 3 &&
        !num.contains(' ') &&
        !den.contains(' ')) {
      return '$num / $den';
    }
    return '($num) / ($den)';
  }

  static String _toSuperscript(String input) {
    const map = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
      '+': '⁺',
      '-': '⁻',
      '=': '⁼',
      '(': '⁽',
      ')': '⁾',
      'n': 'ⁿ',
      'i': 'ⁱ',
      'x': 'ˣ',
      'y': 'ʸ',
      'z': 'ᶻ',
      'a': 'ᵃ',
      'b': 'ᵇ',
      'c': 'ᶜ',
      'd': 'ᵈ',
      'e': 'ᵉ',
      'k': 'ᵏ',
      'm': 'ᵐ',
      'p': 'ᵖ',
      'r': 'ʳ',
      's': 'ˢ',
      't': 'ᵗ',
    };
    final sb = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  static String _toSubscript(String input) {
    const map = {
      '0': '₀',
      '1': '₁',
      '2': '₂',
      '3': '₃',
      '4': '₄',
      '5': '₅',
      '6': '₆',
      '7': '₇',
      '8': '₈',
      '9': '₉',
      '+': '₊',
      '-': '₋',
      '=': '₌',
      '(': '₍',
      ')': '₎',
      'a': 'ₐ',
      'e': 'ₑ',
      'h': 'ₕ',
      'i': 'ᵢ',
      'j': 'ⱼ',
      'k': 'ₖ',
      'l': 'ₗ',
      'm': 'ₘ',
      'n': 'ₙ',
      'o': 'ₒ',
      'p': 'ₚ',
      'r': 'ᵣ',
      's': 'ₛ',
      't': 'ₜ',
      'u': 'ᵤ',
      'v': 'ᵥ',
      'x': 'ₓ',
    };
    final sb = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  /// Formats inline math notation (`$formula$`) in [text] to mathematical Unicode.
  static String formatInlineMath(String text) {
    if (!text.contains(r'$')) return text;
    return text.replaceAllMapped(
      RegExp(r'(?<!\\)\$(?!\$)(.+?)(?<!\\)\$'),
      (match) => formatMathToUnicode(match.group(1)!),
    );
  }

  /// Parse a single line of text into a [CanvasRichLine].
  static CanvasRichLine parseLine(String rawLine, int lineIndex) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) {
      return CanvasRichLine(
        type: CanvasRichLineType.empty,
        rawText: rawLine,
        contentText: '',
        lineIndex: lineIndex,
      );
    }

    // Check single-line display math: $$...$$
    if (trimmed.startsWith(r'$$') &&
        trimmed.endsWith(r'$$') &&
        trimmed.length >= 4) {
      final mathContent = trimmed.substring(2, trimmed.length - 2).trim();
      return CanvasRichLine(
        type: CanvasRichLineType.displayMath,
        rawText: rawLine,
        contentText: formatMathToUnicode(mathContent),
        lineIndex: lineIndex,
      );
    }

    // Check blockquote: > quote
    if (trimmed.startsWith('> ') || trimmed == '>') {
      final quoteContent = trimmed.length > 2
          ? trimmed.substring(2).trim()
          : '';
      return CanvasRichLine(
        type: CanvasRichLineType.blockquote,
        rawText: rawLine,
        contentText: formatInlineMath(quoteContent),
        lineIndex: lineIndex,
      );
    }

    final h3 = _h3Regex.firstMatch(rawLine);
    if (h3 != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.heading3,
        rawText: rawLine,
        contentText: formatInlineMath(h3.group(1)!),
        lineIndex: lineIndex,
      );
    }

    final h2 = _h2Regex.firstMatch(rawLine);
    if (h2 != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.heading2,
        rawText: rawLine,
        contentText: formatInlineMath(h2.group(1)!),
        lineIndex: lineIndex,
      );
    }

    final h1 = _h1Regex.firstMatch(rawLine);
    if (h1 != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.heading1,
        rawText: rawLine,
        contentText: formatInlineMath(h1.group(1)!),
        lineIndex: lineIndex,
      );
    }

    final checked = _checkedRegex.firstMatch(rawLine);
    if (checked != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.checklistChecked,
        rawText: rawLine,
        contentText: formatInlineMath(checked.group(1)!),
        lineIndex: lineIndex,
      );
    }

    final unchecked = _uncheckedRegex.firstMatch(rawLine);
    if (unchecked != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.checklistUnchecked,
        rawText: rawLine,
        contentText: formatInlineMath(unchecked.group(1)!),
        lineIndex: lineIndex,
      );
    }

    final bullet = _bulletRegex.firstMatch(rawLine);
    if (bullet != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.bullet,
        rawText: rawLine,
        contentText: formatInlineMath(bullet.group(1)!),
        lineIndex: lineIndex,
      );
    }

    final num = _numberedRegex.firstMatch(rawLine);
    if (num != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.numbered,
        rawText: rawLine,
        contentText: formatInlineMath(num.group(2)!),
        prefix: '${num.group(1)}.',
        lineIndex: lineIndex,
      );
    }

    return CanvasRichLine(
      type: CanvasRichLineType.paragraph,
      rawText: rawLine,
      contentText: formatInlineMath(rawLine),
      lineIndex: lineIndex,
    );
  }

  /// Parses all lines in [text], handling multi-line math and code blocks.
  static List<CanvasRichLine> parseLines(String text) {
    final rawLines = text.split('\n');
    final result = <CanvasRichLine>[];
    var inCodeBlock = false;
    var inMathBlock = false;
    final mathLines = <String>[];
    var mathStartIndex = 0;

    for (var i = 0; i < rawLines.length; i++) {
      final raw = rawLines[i];
      final trimmed = raw.trim();

      // Check code block fences
      if (trimmed.startsWith('```')) {
        if (inCodeBlock) {
          inCodeBlock = false;
          continue;
        } else {
          inCodeBlock = true;
          continue;
        }
      }
      if (inCodeBlock) {
        result.add(
          CanvasRichLine(
            type: CanvasRichLineType.codeBlock,
            rawText: raw,
            contentText: raw,
            lineIndex: i,
          ),
        );
        continue;
      }

      // Check multi-line display math fences: $$
      if (trimmed == r'$$') {
        if (inMathBlock) {
          inMathBlock = false;
          final combined = mathLines.join(' ');
          result.add(
            CanvasRichLine(
              type: CanvasRichLineType.displayMath,
              rawText: '\$\$\n${mathLines.join('\n')}\n\$\$',
              contentText: formatMathToUnicode(combined),
              lineIndex: mathStartIndex,
            ),
          );
          mathLines.clear();
          continue;
        } else {
          inMathBlock = true;
          mathStartIndex = i;
          mathLines.clear();
          continue;
        }
      }

      if (inMathBlock) {
        mathLines.add(trimmed);
        continue;
      }

      result.add(parseLine(raw, i));
    }

    if (inMathBlock && mathLines.isNotEmpty) {
      result.add(
        CanvasRichLine(
          type: CanvasRichLineType.displayMath,
          rawText: mathLines.join('\n'),
          contentText: formatMathToUnicode(mathLines.join(' ')),
          lineIndex: mathStartIndex,
        ),
      );
    }

    return result;
  }

  /// Whether [text] contains any rich markdown formatting (headings, checklists, lists, math, code).
  static bool hasRichFormatting(String text) {
    return text.contains('#') ||
        text.contains('[ ]') ||
        text.contains('[x]') ||
        text.contains('[X]') ||
        text.contains(r'$$') ||
        text.contains(r'$') ||
        text.contains('```') ||
        text.contains('> ') ||
        text.split('\n').any((l) {
          final t = l.trimLeft();
          return t.startsWith('- ') ||
              t.startsWith('* ') ||
              t.startsWith('> ') ||
              RegExp(r'^\d+\.\s').hasMatch(t);
        });
  }

  /// Draws rich formatted content on [canvas] within [bounds].
  static void draw({
    required Canvas canvas,
    required String text,
    required Rect bounds,
    required Color accent,
    required ColorScheme colors,
    required CanvasTextCache textCache,
    double defaultFontSize = 15.0,
    int? maxLines,
    String fontFamily = 'Segoe UI',
  }) {
    if (bounds.width <= 0 || bounds.height <= 0 || text.isEmpty) return;

    final lines = textCache.richLines(text);
    const boxSize = 14.0;
    const boxRadius = 3.5;
    const itemGap = 4.0;

    canvas.save();
    canvas.clipRect(bounds);

    var currentY = bounds.top;
    var linesRendered = 0;

    for (final line in lines) {
      if (currentY >= bounds.bottom) break;
      if (maxLines != null && linesRendered >= maxLines) break;

      switch (line.type) {
        case CanvasRichLineType.heading1:
          currentY += 4.0;
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: 18.5,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
            height: 1.3,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            bounds.width,
            null,
          );
          painter.paint(canvas, Offset(bounds.left, currentY));
          currentY += painter.height + 4.0;
          linesRendered++;

        case CanvasRichLineType.heading2:
          currentY += 3.0;
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
            height: 1.3,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            bounds.width,
            null,
          );
          painter.paint(canvas, Offset(bounds.left, currentY));
          currentY += painter.height + 3.0;
          linesRendered++;

        case CanvasRichLineType.heading3:
          currentY += 2.0;
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: 15.0,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
            height: 1.3,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            bounds.width,
            null,
          );
          painter.paint(canvas, Offset(bounds.left, currentY));
          currentY += painter.height + 3.0;
          linesRendered++;

        case CanvasRichLineType.checklistUnchecked:
          final textLeft = bounds.left + 22.0;
          final textWidth = math.max(1.0, bounds.width - 22.0);
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: defaultFontSize,
            color: colors.onSurface,
            height: 1.35,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            textWidth,
            null,
          );
          final lineHeight = painter.height;
          final boxY = currentY + math.max(0, (20.0 - boxSize) / 2);

          // Draw checkbox outline
          final boxRect = Rect.fromLTWH(bounds.left, boxY, boxSize, boxSize);
          final rrect = RRect.fromRectAndRadius(
            boxRect,
            const Radius.circular(boxRadius),
          );
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = colors.surface.withValues(alpha: 0.45)
              ..style = PaintingStyle.fill,
          );
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = colors.outline.withValues(alpha: 0.75)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );

          painter.paint(canvas, Offset(textLeft, currentY));
          currentY += lineHeight + itemGap;
          linesRendered++;

        case CanvasRichLineType.checklistChecked:
          final textLeft = bounds.left + 22.0;
          final textWidth = math.max(1.0, bounds.width - 22.0);
          final mutedColor = colors.onSurfaceVariant.withValues(alpha: 0.65);
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: defaultFontSize,
            color: mutedColor,
            decoration: TextDecoration.lineThrough,
            decorationColor: mutedColor,
            height: 1.35,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            textWidth,
            null,
          );
          final lineHeight = painter.height;
          final boxY = currentY + math.max(0, (20.0 - boxSize) / 2);

          // Draw filled checkbox with checkmark
          final boxRect = Rect.fromLTWH(bounds.left, boxY, boxSize, boxSize);
          final rrect = RRect.fromRectAndRadius(
            boxRect,
            const Radius.circular(boxRadius),
          );
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = accent
              ..style = PaintingStyle.fill,
          );

          // Checkmark path
          final checkPath = Path()
            ..moveTo(bounds.left + 3.2, boxY + 7.0)
            ..lineTo(bounds.left + 5.8, boxY + 9.8)
            ..lineTo(bounds.left + 10.8, boxY + 3.8);
          canvas.drawPath(
            checkPath,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round,
          );

          painter.paint(canvas, Offset(textLeft, currentY));
          currentY += lineHeight + itemGap;
          linesRendered++;

        case CanvasRichLineType.bullet:
          final textLeft = bounds.left + 16.0;
          final textWidth = math.max(1.0, bounds.width - 16.0);
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: defaultFontSize,
            color: colors.onSurface,
            height: 1.35,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            textWidth,
            null,
          );

          // Draw bullet circle
          canvas.drawCircle(
            Offset(bounds.left + 6.0, currentY + 10.0),
            2.2,
            Paint()..color = accent,
          );

          painter.paint(canvas, Offset(textLeft, currentY));
          currentY += painter.height + itemGap;
          linesRendered++;

        case CanvasRichLineType.numbered:
          final prefixWidth = 22.0;
          final textLeft = bounds.left + prefixWidth;
          final textWidth = math.max(1.0, bounds.width - prefixWidth);

          final prefixStyle = TextStyle(
            fontFamily: fontFamily,
            fontSize: defaultFontSize,
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            height: 1.35,
          );
          final prefixPainter = textCache.layout(
            line.prefix ?? '',
            prefixStyle,
            prefixWidth,
            1,
          );
          prefixPainter.paint(canvas, Offset(bounds.left, currentY));

          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: defaultFontSize,
            color: colors.onSurface,
            height: 1.35,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            textWidth,
            null,
          );
          painter.paint(canvas, Offset(textLeft, currentY));
          currentY += painter.height + itemGap;
          linesRendered++;

        case CanvasRichLineType.displayMath:
          currentY += 4.0;
          final mathStyle = TextStyle(
            fontFamily:
                line.contentText.contains('⎛') || line.contentText.contains('⎡')
                ? 'Consolas'
                : fontFamily,
            fontSize: defaultFontSize + 1.5,
            fontStyle: FontStyle.italic,
            color: colors.onSurface,
            height: 1.35,
          );
          final mathPainter = textCache.layout(
            line.contentText,
            mathStyle,
            math.max(1.0, bounds.width - 24.0),
            null,
          );
          final boxHeight = mathPainter.height + 12.0;
          final mathBoxRect = Rect.fromLTWH(
            bounds.left,
            currentY,
            bounds.width,
            boxHeight,
          );

          // Calm graphite surface container
          final rrect = RRect.fromRectAndRadius(
            mathBoxRect,
            const Radius.circular(6.0),
          );
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = colors.surfaceContainerHighest.withValues(alpha: 0.35)
              ..style = PaintingStyle.fill,
          );
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = colors.outlineVariant.withValues(alpha: 0.25)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );

          // Subtle left formula indicator
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTWH(bounds.left, currentY, 3.0, boxHeight),
              topLeft: const Radius.circular(6.0),
              bottomLeft: const Radius.circular(6.0),
            ),
            Paint()..color = accent.withValues(alpha: 0.8),
          );

          // Center formula text in the box
          final textX = bounds.left + (bounds.width - mathPainter.width) / 2;
          final textY = currentY + (boxHeight - mathPainter.height) / 2;
          mathPainter.paint(canvas, Offset(textX, textY));
          currentY += boxHeight + itemGap + 2.0;
          linesRendered++;

        case CanvasRichLineType.codeBlock:
          currentY += 2.0;
          final codeStyle = TextStyle(
            fontFamily: 'Consolas',
            fontSize: math.max(10.0, defaultFontSize - 1.5),
            color: colors.onSurface,
            height: 1.35,
          );
          final codePainter = textCache.layout(
            line.contentText,
            codeStyle,
            math.max(1.0, bounds.width - 16.0),
            null,
          );
          final boxHeight = codePainter.height + 8.0;
          final codeBoxRect = Rect.fromLTWH(
            bounds.left,
            currentY,
            bounds.width,
            boxHeight,
          );
          final codeRRect = RRect.fromRectAndRadius(
            codeBoxRect,
            const Radius.circular(4.0),
          );
          canvas.drawRRect(
            codeRRect,
            Paint()
              ..color = colors.surfaceContainerHighest.withValues(alpha: 0.40)
              ..style = PaintingStyle.fill,
          );
          codePainter.paint(canvas, Offset(bounds.left + 8.0, currentY + 4.0));
          currentY += boxHeight + itemGap;
          linesRendered++;

        case CanvasRichLineType.blockquote:
          currentY += 2.0;
          final textLeft = bounds.left + 14.0;
          final textWidth = math.max(1.0, bounds.width - 14.0);
          final quoteStyle = TextStyle(
            fontFamily: fontFamily,
            fontSize: defaultFontSize,
            fontStyle: FontStyle.italic,
            color: colors.onSurfaceVariant,
            height: 1.35,
          );
          final quotePainter = textCache.layout(
            line.contentText,
            quoteStyle,
            textWidth,
            null,
          );
          canvas.drawLine(
            Offset(bounds.left + 3.0, currentY + 2.0),
            Offset(bounds.left + 3.0, currentY + quotePainter.height - 2.0),
            Paint()
              ..color = colors.outlineVariant
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round,
          );
          quotePainter.paint(canvas, Offset(textLeft, currentY));
          currentY += quotePainter.height + itemGap;
          linesRendered++;

        case CanvasRichLineType.paragraph:
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: defaultFontSize,
            color: colors.onSurface,
            height: 1.35,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            bounds.width,
            null,
          );
          painter.paint(canvas, Offset(bounds.left, currentY));
          currentY += painter.height + itemGap;
          linesRendered++;

        case CanvasRichLineType.empty:
          currentY += 10.0;
          linesRendered++;
      }
    }

    canvas.restore();
  }

  /// Returns the 0-indexed line number in [text] if [clickOffset] hit a checkbox,
  /// or null if the click was not on a checkbox.
  static int? hitTestCheckbox({
    required String text,
    required Rect bounds,
    required Offset clickOffset,
    required CanvasTextCache textCache,
    double defaultFontSize = 15.0,
    String fontFamily = 'Segoe UI',
  }) {
    if (bounds.width <= 0 || bounds.height <= 0 || text.isEmpty) return null;

    final lines = textCache.richLines(text);
    const itemGap = 4.0;
    var currentY = bounds.top;

    for (final line in lines) {
      if (currentY >= bounds.bottom) break;

      switch (line.type) {
        case CanvasRichLineType.heading1:
          currentY += 4.0;
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: 18.5,
            fontWeight: FontWeight.bold,
            height: 1.3,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            bounds.width,
            null,
          );
          currentY += painter.height + 4.0;

        case CanvasRichLineType.heading2:
          currentY += 3.0;
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            height: 1.3,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            bounds.width,
            null,
          );
          currentY += painter.height + 3.0;

        case CanvasRichLineType.heading3:
          currentY += 2.0;
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: 15.0,
            fontWeight: FontWeight.w600,
            height: 1.3,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            bounds.width,
            null,
          );
          currentY += painter.height + 3.0;

        case CanvasRichLineType.checklistUnchecked:
        case CanvasRichLineType.checklistChecked:
          final textWidth = math.max(1.0, bounds.width - 22.0);
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: defaultFontSize,
            height: 1.35,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            textWidth,
            null,
          );
          final lineHeight = painter.height;

          // Checkbox hit box: generous area around the 14px box
          final hitRect = Rect.fromLTWH(
            bounds.left - 4.0,
            currentY - 2.0,
            28.0,
            math.max(22.0, lineHeight + 4.0),
          );

          if (hitRect.contains(clickOffset)) {
            return line.lineIndex;
          }
          currentY += lineHeight + itemGap;

        case CanvasRichLineType.bullet:
          final textWidth = math.max(1.0, bounds.width - 16.0);
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: defaultFontSize,
            height: 1.35,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            textWidth,
            null,
          );
          currentY += painter.height + itemGap;

        case CanvasRichLineType.numbered:
          final textWidth = math.max(1.0, bounds.width - 22.0);
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: defaultFontSize,
            height: 1.35,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            textWidth,
            null,
          );
          currentY += painter.height + itemGap;

        case CanvasRichLineType.displayMath:
          currentY += 4.0;
          final mathStyle = TextStyle(
            fontFamily:
                line.contentText.contains('⎛') || line.contentText.contains('⎡')
                ? 'Consolas'
                : fontFamily,
            fontSize: defaultFontSize + 1.5,
            fontStyle: FontStyle.italic,
            height: 1.35,
          );
          final mathPainter = textCache.layout(
            line.contentText,
            mathStyle,
            math.max(1.0, bounds.width - 24.0),
            null,
          );
          final boxHeight = mathPainter.height + 12.0;
          currentY += boxHeight + itemGap + 2.0;

        case CanvasRichLineType.codeBlock:
          currentY += 2.0;
          final codeStyle = TextStyle(
            fontFamily: 'Consolas',
            fontSize: math.max(10.0, defaultFontSize - 1.5),
            height: 1.35,
          );
          final codePainter = textCache.layout(
            line.contentText,
            codeStyle,
            math.max(1.0, bounds.width - 16.0),
            null,
          );
          currentY += codePainter.height + 8.0 + itemGap;

        case CanvasRichLineType.blockquote:
          currentY += 2.0;
          final textWidth = math.max(1.0, bounds.width - 14.0);
          final quoteStyle = TextStyle(
            fontFamily: fontFamily,
            fontSize: defaultFontSize,
            fontStyle: FontStyle.italic,
            height: 1.35,
          );
          final quotePainter = textCache.layout(
            line.contentText,
            quoteStyle,
            textWidth,
            null,
          );
          currentY += quotePainter.height + itemGap;

        case CanvasRichLineType.paragraph:
          final style = TextStyle(
            fontFamily: fontFamily,
            fontSize: defaultFontSize,
            height: 1.35,
          );
          final painter = textCache.layout(
            line.contentText,
            style,
            bounds.width,
            null,
          );
          currentY += painter.height + itemGap;

        case CanvasRichLineType.empty:
          currentY += 10.0;
      }
    }

    return null;
  }

  /// Toggles the checklist state on line [lineIndex] in [text].
  ///
  /// Converts `[ ]` to `[x]` and `[x]` / `[X]` to `[ ]`, preserving leading indentation and bullets.
  static String toggleLine(String text, int lineIndex) {
    final lines = text.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return text;

    final targetLine = lines[lineIndex];

    // Check if unchecked: replace [ ] with [x]
    final uncheckedMatch = RegExp(
      r'^(\s*[-*]?\s*\[) ([\]].*)$',
    ).firstMatch(targetLine);
    if (uncheckedMatch != null) {
      lines[lineIndex] =
          '${uncheckedMatch.group(1)}x${uncheckedMatch.group(2)}';
      return lines.join('\n');
    }

    // Check if checked: replace [x] or [X] with [ ]
    final checkedMatch = RegExp(
      r'^(\s*[-*]?\s*\[)[xX]([\]].*)$',
    ).firstMatch(targetLine);
    if (checkedMatch != null) {
      lines[lineIndex] = '${checkedMatch.group(1)} ${checkedMatch.group(2)}';
      return lines.join('\n');
    }

    return text;
  }

  /// Handles smart Enter continuation when typing in a multiline text editor.
  ///
  /// If the current line is an empty list item (e.g. `- [ ]`), pressing Enter clears the prefix.
  /// If the current line is an active list item, pressing Enter auto-prefixes the next line.
  /// Returns null if normal Enter behavior should proceed.
  static ({String text, TextSelection selection})? handleSmartEnter(
    String text,
    TextSelection selection,
  ) {
    if (!selection.isValid || !selection.isCollapsed) return null;

    final offset = selection.baseOffset.clamp(0, text.length);
    final lastNewline = offset <= 0 ? -1 : text.lastIndexOf('\n', offset - 1);
    final lineStart = lastNewline == -1 ? 0 : lastNewline + 1;
    final nextNewline = text.indexOf('\n', offset);
    final lineEnd = nextNewline == -1 ? text.length : nextNewline;
    final currentLine = text.substring(lineStart, lineEnd);

    // Case 1: Empty checklist item -> clear prefix
    if (RegExp(r'^\s*[-*]?\s*\[[ xX]\]\s*$').hasMatch(currentLine)) {
      final before = text.substring(0, lineStart);
      final after = text.substring(lineEnd);
      final newText = '$before$after';
      return (
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    // Case 2: Empty bullet item -> clear prefix
    if (RegExp(r'^\s*[-*]\s*$').hasMatch(currentLine)) {
      final before = text.substring(0, lineStart);
      final after = text.substring(lineEnd);
      final newText = '$before$after';
      return (
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    // Case 3: Checklist line -> auto-prefix next line with unchecked box
    final checkMatch = RegExp(
      r'^(\s*[-*]?\s*\[)[ xX](\]\s+)',
    ).firstMatch(currentLine);
    if (checkMatch != null) {
      final prefix = '${checkMatch.group(1)} ${checkMatch.group(2)}';
      final before = text.substring(0, offset);
      final after = text.substring(offset);
      final newText = '$before\n$prefix$after';
      return (
        text: newText,
        selection: TextSelection.collapsed(offset: offset + 1 + prefix.length),
      );
    }

    // Case 4: Bullet line -> auto-prefix next line with bullet
    final bulletMatch = RegExp(r'^(\s*[-*]\s+)').firstMatch(currentLine);
    if (bulletMatch != null) {
      final prefix = bulletMatch.group(1)!;
      final before = text.substring(0, offset);
      final after = text.substring(offset);
      final newText = '$before\n$prefix$after';
      return (
        text: newText,
        selection: TextSelection.collapsed(offset: offset + 1 + prefix.length),
      );
    }

    return null;
  }

  /// Toggles or applies [prefix] (e.g. `- [ ] `, `# `, `## `, `### `, `- `) to the current line.
  static ({String text, TextSelection selection}) toggleLinePrefix(
    String text,
    TextSelection selection,
    String prefix,
  ) {
    final rawOffset = selection.isValid ? selection.baseOffset : text.length;
    final offset = rawOffset.clamp(0, text.length);
    final lastNewline = offset <= 0 ? -1 : text.lastIndexOf('\n', offset - 1);
    final lineStart = lastNewline == -1 ? 0 : lastNewline + 1;
    final nextNewline = text.indexOf('\n', offset);
    final lineEnd = nextNewline == -1 ? text.length : nextNewline;
    final currentLine = text.substring(lineStart, lineEnd);

    String newLine;
    int cursorDelta = 0;

    if (prefix == '- [ ] ') {
      // Toggle checklist: if already checklist, remove it; else add it
      final checkMatch = RegExp(
        r'^\s*[-*]?\s*\[[ xX]\]\s*(.*)$',
      ).firstMatch(currentLine);
      if (checkMatch != null) {
        newLine = checkMatch.group(1)!;
        cursorDelta = -(currentLine.length - newLine.length);
      } else {
        final cleaned = currentLine.replaceFirst(
          RegExp(r'^(#{1,3}\s+|[-*]\s+)'),
          '',
        );
        newLine = '- [ ] $cleaned';
        cursorDelta = newLine.length - currentLine.length;
      }
    } else if (prefix.startsWith('#')) {
      // Toggle heading
      final targetPrefix = prefix.trim();
      final headingMatch = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(currentLine);
      if (headingMatch != null && headingMatch.group(1) == targetPrefix) {
        // Same heading: remove it
        newLine = headingMatch.group(2)!;
        cursorDelta = -(currentLine.length - newLine.length);
      } else if (headingMatch != null) {
        // Different heading level: replace
        newLine = '$prefix${headingMatch.group(2)!}';
        cursorDelta = newLine.length - currentLine.length;
      } else {
        final cleaned = currentLine.replaceFirst(
          RegExp(r'^\s*[-*]?\s*(\[[ xX]\]\s+)?'),
          '',
        );
        newLine = '$prefix$cleaned';
        cursorDelta = newLine.length - currentLine.length;
      }
    } else if (prefix == '- ') {
      // Toggle bullet
      final bulletMatch = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(currentLine);
      if (bulletMatch != null && !currentLine.contains('[')) {
        newLine = bulletMatch.group(1)!;
        cursorDelta = -(currentLine.length - newLine.length);
      } else {
        final cleaned = currentLine.replaceFirst(
          RegExp(r'^(#{1,3}\s+|[-*]?\s*\[[ xX]\]\s*)'),
          '',
        );
        newLine = '- $cleaned';
        cursorDelta = newLine.length - currentLine.length;
      }
    } else {
      newLine = '$prefix$currentLine';
      cursorDelta = prefix.length;
    }

    final before = text.substring(0, lineStart);
    final after = text.substring(lineEnd);
    final updatedText = '$before$newLine$after';
    final newOffset = (offset + cursorDelta).clamp(0, updatedText.length);

    return (
      text: updatedText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}
