import 'package:flutter/material.dart';

/// Bionic Speed Reading engine for academic research, deep study, and rapid reading.
/// Fixates the reader's eye on the initial characters of words to increase reading velocity
/// by 20-30% while reducing cognitive fatigue (STUDY-02, EDT-08).
class BionicReading {
  const BionicReading._();

  /// Computes how many initial characters to emphasize based on word length.
  static int fixationLength(int wordLength) {
    if (wordLength <= 0) return 0;
    if (wordLength <= 3) return 1;
    if (wordLength <= 6) return 2;
    if (wordLength <= 9) return 3;
    return 4;
  }

  /// Transforms [text] into markdown with bolded fixation prefixes on prose words.
  /// Skips code blocks, URLs, and LaTeX math equations.
  static String toBionicMarkdown(String text) {
    if (text.trim().isEmpty) return text;

    final lines = text.split('\n');
    final buffer = StringBuffer();
    bool inCodeFence = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Code fences
      if (line.trim().startsWith('```')) {
        inCodeFence = !inCodeFence;
        buffer.writeln(line);
        continue;
      }
      if (inCodeFence) {
        buffer.writeln(line);
        continue;
      }

      // LaTeX display math
      if (line.trim().startsWith(r'$$') && line.trim().endsWith(r'$$')) {
        buffer.writeln(line);
        continue;
      }

      buffer.writeln(_convertLineToBionic(line));
    }

    final result = buffer.toString();
    // Trim trailing newline if original didn't have one
    return text.endsWith('\n')
        ? result
        : result.substring(0, result.length - 1);
  }

  static String _convertLineToBionic(String line) {
    // Preserve URLs, code spans, wiki-links, and math expressions untouched
    final tokenRegex = RegExp(
      r'(https?:\/\/[^\s]+|`[^`]+`|\$\$[^\$]+\$\$|\$[^\$]+\$|\[\[[^\]]+\]\])|([A-Za-z0-9]+)|([^A-Za-z0-9\s]+|\s+)',
    );

    return tokenRegex.allMatches(line).map((match) {
      final preserved = match.group(1);
      if (preserved != null) return preserved;

      final word = match.group(2);
      if (word != null) {
        final fixLen = fixationLength(word.length);
        if (fixLen <= 0 || fixLen >= word.length) {
          return '**$word**';
        }
        final head = word.substring(0, fixLen);
        final tail = word.substring(fixLen);
        return '**$head**$tail';
      }

      return match.group(3) ?? '';
    }).join();
  }

  /// Builds a [TextSpan] list from [text] with the anchor characters styled bold.
  static List<InlineSpan> buildBionicSpans(
    String text, {
    TextStyle? style,
    FontWeight boldWeight = FontWeight.bold,
  }) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'([A-Za-z0-9]+)|([^A-Za-z0-9]+)');

    for (final match in regex.allMatches(text)) {
      final word = match.group(1);
      final other = match.group(2);

      if (other != null) {
        spans.add(TextSpan(text: other, style: style));
      } else if (word != null) {
        final fixLen = fixationLength(word.length);
        if (fixLen <= 0) {
          spans.add(TextSpan(text: word, style: style));
        } else if (fixLen >= word.length) {
          spans.add(
            TextSpan(
              text: word,
              style: (style ?? const TextStyle()).copyWith(
                fontWeight: boldWeight,
              ),
            ),
          );
        } else {
          final head = word.substring(0, fixLen);
          final tail = word.substring(fixLen);
          spans.add(
            TextSpan(
              text: head,
              style: (style ?? const TextStyle()).copyWith(
                fontWeight: boldWeight,
              ),
            ),
          );
          spans.add(TextSpan(text: tail, style: style));
        }
      }
    }
    return spans;
  }
}
