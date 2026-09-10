import 'package:flutter/material.dart';

/// Represents a distinct editable slot in a mathematical expression.
/// For example, the numerator (top) or denominator (bottom) of a fraction,
/// or a subscript (below) / superscript (above).
class MathSlot {
  MathSlot({
    required this.id,
    required this.label,
    required this.hint,
    required this.value,
    this.isBelow = false,
    this.isAbove = false,
    this.icon,
  }) : controller = TextEditingController(text: value);

  final String id;
  final String label;
  final String hint;
  final String value;
  final bool isBelow;
  final bool isAbove;
  final IconData? icon;
  final TextEditingController controller;

  void dispose() {
    controller.dispose();
  }
}

/// A parsed visual fraction with numerator (top) and denominator (bottom).
class VisualFraction {
  VisualFraction({
    required this.startIndex,
    required this.endIndex,
    required this.numerator,
    required this.denominator,
  });

  final int startIndex;
  final int endIndex;
  String numerator;
  String denominator;

  String toTex() => '\\frac{$numerator}{$denominator}';
}

/// A parsed script element (base with subscript below and/or superscript above).
class VisualScript {
  VisualScript({
    required this.startIndex,
    required this.endIndex,
    required this.base,
    this.subscript,
    this.superscript,
  });

  final int startIndex;
  final int endIndex;
  String base;
  String? subscript;
  String? superscript;

  String toTex() {
    var out = base;
    if (subscript != null) out += '_{$subscript}';
    if (superscript != null) out += '^{$superscript}';
    return out;
  }
}

/// A parsed operator with bounds (e.g. \sum, \int, \lim, \prod)
class VisualBigOp {
  VisualBigOp({
    required this.startIndex,
    required this.endIndex,
    required this.operator,
    this.lowerBound,
    this.upperBound,
  });

  final int startIndex;
  final int endIndex;
  final String operator;
  String? lowerBound;
  String? upperBound;

  String toTex() {
    var out = operator;
    if (lowerBound != null) out += '_{$lowerBound}';
    if (upperBound != null) out += '^{$upperBound}';
    return out;
  }
}

/// Decomposes TeX expressions into interactive visual slots and spacing structures.
class VisualMathModel {
  VisualMathModel(this.source) {
    parse();
  }

  String source;
  final List<VisualFraction> fractions = [];
  final List<VisualScript> scripts = [];
  final List<VisualBigOp> bigOps = [];
  final List<String> equationLines = [];

  /// Finds matching closing brace `}` for `{` at [openIndex], respecting nested braces
  /// and escaped braces `\{`.
  static int findMatchingBrace(String s, int openIndex) {
    if (openIndex >= s.length || s[openIndex] != '{') return -1;
    var depth = 1;
    var i = openIndex + 1;
    while (i < s.length) {
      if (s[i] == '\\') {
        i += 2;
        continue;
      }
      if (s[i] == '{') {
        depth++;
      } else if (s[i] == '}') {
        depth--;
        if (depth == 0) return i;
      }
      i++;
    }
    return -1;
  }

  /// Extracts a TeX argument starting at or after [startIndex].
  /// Returns (content, nextIndex).
  static (String, int)? extractArg(String s, int startIndex) {
    var i = startIndex;
    while (i < s.length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n')) {
      i++;
    }
    if (i >= s.length) return null;
    if (s[i] == '{') {
      final close = findMatchingBrace(s, i);
      if (close != -1) {
        return (s.substring(i + 1, close), close + 1);
      } else {
        return (s.substring(i + 1), s.length);
      }
    }
    // Single macro or character
    if (s[i] == '\\') {
      var end = i + 1;
      while (end < s.length && RegExp(r'[a-zA-Z]').hasMatch(s[end])) {
        end++;
      }
      return (s.substring(i, end), end);
    }
    return (s[i], i + 1);
  }

  void parse() {
    fractions.clear();
    scripts.clear();
    bigOps.clear();
    equationLines.clear();

    // Multiline equations split by \\
    final rawLines = source.split(RegExp(r'\\\\'));
    for (final line in rawLines) {
      equationLines.add(line.trim());
    }

    var i = 0;
    while (i < source.length) {
      // Check \frac
      if (source.startsWith(r'\frac', i)) {
        final start = i;
        final arg1 = extractArg(source, i + 5);
        if (arg1 != null) {
          final arg2 = extractArg(source, arg1.$2);
          if (arg2 != null) {
            fractions.add(
              VisualFraction(
                startIndex: start,
                endIndex: arg2.$2,
                numerator: arg1.$1,
                denominator: arg2.$1,
              ),
            );
            i += 5;
            continue;
          }
        }
      }

      // Check big operators: \sum, \int, \lim, \prod, \bigcup, etc.
      // LaTeX macro names end before non-letters like '_' or '^'.
      final opMatch = RegExp(
        r'\\(sum|int|lim|prod|coprod|bigcup|bigcap)(?![a-zA-Z])',
      ).matchAsPrefix(source, i);
      if (opMatch != null) {
        final op = opMatch.group(0)!;
        final start = i;
        var cur = i + op.length;
        String? lower;
        String? upper;

        // check for subscript or superscript
        while (cur < source.length) {
          if (cur < source.length && source[cur] == '_') {
            final arg = extractArg(source, cur + 1);
            if (arg != null) {
              lower = arg.$1;
              cur = arg.$2;
              continue;
            }
          } else if (cur < source.length && source[cur] == '^') {
            final arg = extractArg(source, cur + 1);
            if (arg != null) {
              upper = arg.$1;
              cur = arg.$2;
              continue;
            }
          }
          break;
        }

        if (lower != null || upper != null) {
          bigOps.add(
            VisualBigOp(
              startIndex: start,
              endIndex: cur,
              operator: op,
              lowerBound: lower,
              upperBound: upper,
            ),
          );
          i = cur;
          continue;
        }
      }

      // Check scripts: e.g. x_{i} or x_1 or x^{2}
      // Matches identifier or macro followed by _ or ^
      final scriptMatch = RegExp(
        r'([a-zA-Z0-9]+|\\[a-zA-Z]+)(?=[_^])',
      ).matchAsPrefix(source, i);
      if (scriptMatch != null &&
          opMatch == null &&
          !source.startsWith(r'\frac', i)) {
        final base = scriptMatch.group(1)!;
        final start = i;
        var cur = i + base.length;
        String? sub;
        String? sup;

        while (cur < source.length) {
          if (cur < source.length && source[cur] == '_') {
            final arg = extractArg(source, cur + 1);
            if (arg != null) {
              sub = arg.$1;
              cur = arg.$2;
              continue;
            }
          } else if (cur < source.length && source[cur] == '^') {
            final arg = extractArg(source, cur + 1);
            if (arg != null) {
              sup = arg.$1;
              cur = arg.$2;
              continue;
            }
          }
          break;
        }

        if (sub != null || sup != null) {
          scripts.add(
            VisualScript(
              startIndex: start,
              endIndex: cur,
              base: base,
              subscript: sub,
              superscript: sup,
            ),
          );
          i = cur;
          continue;
        }
      }

      i++;
    }
  }

  bool get hasFractions => fractions.isNotEmpty;
  bool get hasScripts => scripts.isNotEmpty;
  bool get hasBigOps => bigOps.isNotEmpty;
  bool get hasMultipleLines => equationLines.length > 1;

  /// Update the denominator ("the number below it") of a specific fraction.
  String updateFractionDenominator(int index, String newDenom) {
    if (index < 0 || index >= fractions.length) return source;
    final frac = fractions[index];
    final before = source.substring(0, frac.startIndex);
    final after = source.substring(frac.endIndex);
    frac.denominator = newDenom;
    source = '$before${frac.toTex()}$after';
    parse();
    return source;
  }

  /// Update the numerator (top) of a specific fraction.
  String updateFractionNumerator(int index, String newNum) {
    if (index < 0 || index >= fractions.length) return source;
    final frac = fractions[index];
    final before = source.substring(0, frac.startIndex);
    final after = source.substring(frac.endIndex);
    frac.numerator = newNum;
    source = '$before${frac.toTex()}$after';
    parse();
    return source;
  }

  /// Update the subscript ("number below it") of a script expression.
  String updateScriptSubscript(int index, String newSub) {
    if (index < 0 || index >= scripts.length) return source;
    final sc = scripts[index];
    final before = source.substring(0, sc.startIndex);
    final after = source.substring(sc.endIndex);
    sc.subscript = newSub;
    source = '$before${sc.toTex()}$after';
    parse();
    return source;
  }

  /// Update lower bound ("number below it") of an operator like \sum or \int or \lim.
  String updateBigOpLowerBound(int index, String newLower) {
    if (index < 0 || index >= bigOps.length) return source;
    final op = bigOps[index];
    final before = source.substring(0, op.startIndex);
    final after = source.substring(op.endIndex);
    op.lowerBound = newLower;
    source = '$before${op.toTex()}$after';
    parse();
    return source;
  }

  /// Add spacing between equations or terms (e.g. \quad, \qquad, \;)
  String addSpacing({String spaceToken = r'\quad '}) {
    var trimmed = source.trimRight();
    if (trimmed.isEmpty) {
      source = spaceToken;
    } else {
      source = '$trimmed $spaceToken';
    }
    parse();
    return source;
  }

  /// Add a line break (\\) to separate equations into rows or add vertical space.
  String addLineBreak() {
    var trimmed = source.trimRight();
    if (trimmed.isEmpty) {
      source = r'\\ ';
    } else {
      source = '$trimmed \\\\\n';
    }
    parse();
    return source;
  }

  /// Wraps current equation in a fraction or appends a new fraction structure.
  String insertFraction({String? num, String? den}) {
    final top = num ?? (source.isNotEmpty ? source.trim() : r'\square');
    final bottom = den ?? r'\square';
    if (source.isNotEmpty && num == null) {
      source = r'\frac{' + top + r'}{' + bottom + r'}';
    } else {
      final sep = source.isNotEmpty ? ' ' : '';
      source = '$source$sep\\frac{$top}{$bottom}';
    }
    parse();
    return source;
  }

  /// Appends or wraps subscript ("number below it").
  String insertSubscript(String sub) {
    final sep = source.isNotEmpty ? '' : r'\square';
    source = '$source${sep}_{$sub}';
    parse();
    return source;
  }

  /// Appends or wraps superscript.
  String insertSuperscript(String sup) {
    final sep = source.isNotEmpty ? '' : r'\square';
    source = '$source$sep^{$sup}';
    parse();
    return source;
  }
}
