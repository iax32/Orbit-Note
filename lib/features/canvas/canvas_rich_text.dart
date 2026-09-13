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

    final h3 = _h3Regex.firstMatch(rawLine);
    if (h3 != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.heading3,
        rawText: rawLine,
        contentText: h3.group(1)!,
        lineIndex: lineIndex,
      );
    }

    final h2 = _h2Regex.firstMatch(rawLine);
    if (h2 != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.heading2,
        rawText: rawLine,
        contentText: h2.group(1)!,
        lineIndex: lineIndex,
      );
    }

    final h1 = _h1Regex.firstMatch(rawLine);
    if (h1 != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.heading1,
        rawText: rawLine,
        contentText: h1.group(1)!,
        lineIndex: lineIndex,
      );
    }

    final checked = _checkedRegex.firstMatch(rawLine);
    if (checked != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.checklistChecked,
        rawText: rawLine,
        contentText: checked.group(1)!,
        lineIndex: lineIndex,
      );
    }

    final unchecked = _uncheckedRegex.firstMatch(rawLine);
    if (unchecked != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.checklistUnchecked,
        rawText: rawLine,
        contentText: unchecked.group(1)!,
        lineIndex: lineIndex,
      );
    }

    final bullet = _bulletRegex.firstMatch(rawLine);
    if (bullet != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.bullet,
        rawText: rawLine,
        contentText: bullet.group(1)!,
        lineIndex: lineIndex,
      );
    }

    final num = _numberedRegex.firstMatch(rawLine);
    if (num != null) {
      return CanvasRichLine(
        type: CanvasRichLineType.numbered,
        rawText: rawLine,
        contentText: num.group(2)!,
        prefix: '${num.group(1)}.',
        lineIndex: lineIndex,
      );
    }

    return CanvasRichLine(
      type: CanvasRichLineType.paragraph,
      rawText: rawLine,
      contentText: rawLine,
      lineIndex: lineIndex,
    );
  }

  /// Parses all lines in [text].
  static List<CanvasRichLine> parseLines(String text) {
    final rawLines = text.split('\n');
    return List<CanvasRichLine>.generate(
      rawLines.length,
      (i) => parseLine(rawLines[i], i),
      growable: false,
    );
  }

  /// Whether [text] contains any rich markdown formatting (headings, checklists, lists).
  static bool hasRichFormatting(String text) {
    return text.contains('#') ||
        text.contains('[ ]') ||
        text.contains('[x]') ||
        text.contains('[X]') ||
        text.split('\n').any((l) {
          final t = l.trimLeft();
          return t.startsWith('- ') ||
              t.startsWith('* ') ||
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
  }) {
    if (bounds.width <= 0 || bounds.height <= 0 || text.isEmpty) return;

    final lines = parseLines(text);
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
            fontFamily: 'Segoe UI',
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
            fontFamily: 'Segoe UI',
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
            fontFamily: 'Segoe UI',
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
            fontFamily: 'Segoe UI',
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
            fontFamily: 'Segoe UI',
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
            fontFamily: 'Segoe UI',
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
            fontFamily: 'Segoe UI',
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
            fontFamily: 'Segoe UI',
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

        case CanvasRichLineType.paragraph:
          final style = TextStyle(
            fontFamily: 'Segoe UI',
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
  }) {
    if (bounds.width <= 0 || bounds.height <= 0 || text.isEmpty) return null;

    final lines = parseLines(text);
    const itemGap = 4.0;
    var currentY = bounds.top;

    for (final line in lines) {
      if (currentY >= bounds.bottom) break;

      switch (line.type) {
        case CanvasRichLineType.heading1:
          currentY += 4.0;
          final style = TextStyle(
            fontFamily: 'Segoe UI',
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
            fontFamily: 'Segoe UI',
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
            fontFamily: 'Segoe UI',
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
            fontFamily: 'Segoe UI',
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
            fontFamily: 'Segoe UI',
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
            fontFamily: 'Segoe UI',
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

        case CanvasRichLineType.paragraph:
          final style = TextStyle(
            fontFamily: 'Segoe UI',
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
