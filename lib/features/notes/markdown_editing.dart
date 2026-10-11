import 'package:flutter/services.dart';

/// Applies syntax to a selection without owning the document or persistence.
abstract final class MarkdownEditing {
  static TextEditingValue? continueList(TextEditingValue value) {
    if (!value.selection.isValid || !value.composing.isCollapsed) return null;
    final caret = value.selection.start;
    final start = caret == 0 ? 0 : value.text.lastIndexOf('\n', caret - 1) + 1;
    final before = value.text.substring(0, start);
    // Do not turn code examples into list operations.
    String? fence;
    for (final line in before.split('\n')) {
      final match = RegExp(r'^ {0,3}(`{3,}|~{3,})').firstMatch(line);
      if (match != null) {
        if (fence == null) {
          fence = match[1]![0];
        } else if (match[1]!.startsWith(fence)) {
          fence = null;
        }
      }
    }
    if (fence != null) return null;
    final lineEnd = value.text.indexOf('\n', caret);
    final line = value.text.substring(
      start,
      lineEnd < 0 ? value.text.length : lineEnd,
    );
    final marker = RegExp(
      r'^( *)([-+*]|\d+[.)]) +(\[[ xX]\] +)?',
    ).firstMatch(line);
    if (marker == null || caret < start + marker.end) return null;
    if (line.substring(marker.end).trim().isEmpty) {
      final exit = start > 0 ? '\n' : '';
      return value.copyWith(
        text: value.text.replaceRange(start, start + marker.end, exit),
        selection: TextSelection.collapsed(offset: start + exit.length),
        composing: TextRange.empty,
      );
    }
    var bullet = marker[2]!;
    final number = RegExp(r'^(\d+)([.)])$').firstMatch(bullet);
    if (number != null) bullet = '${int.parse(number[1]!) + 1}${number[2]}';
    return insert(
      value,
      '\n${marker[1]}$bullet ${marker[3] == null ? '' : '[ ] '}',
    );
  }

  static TextEditingValue? indentList(
    TextEditingValue value, {
    bool outdent = false,
  }) {
    if (!value.selection.isValid || !value.composing.isCollapsed) return null;
    final selection = value.selection;
    final start = selection.start == 0
        ? 0
        : value.text.lastIndexOf('\n', selection.start - 1) + 1;
    var end = value.text.indexOf(
      '\n',
      selection.end == selection.start ? selection.end : selection.end - 1,
    );
    if (end < 0) end = value.text.length;
    final lines = value.text.substring(start, end).split('\n');
    if (!lines.every((line) => RegExp(r'^ *([-+*]|\d+[.)]) ').hasMatch(line))) {
      return null;
    }
    final next = lines
        .map(
          (line) =>
              outdent ? line.replaceFirst(RegExp(r'^ {1,2}'), '') : '  $line',
        )
        .join('\n');
    final delta = next.length - (end - start);
    return value.copyWith(
      text: value.text.replaceRange(start, end, next),
      selection: selection.isCollapsed
          ? TextSelection.collapsed(
              offset: (selection.start + delta).clamp(
                start,
                start + next.length,
              ),
            )
          : TextSelection(baseOffset: start, extentOffset: start + next.length),
      composing: TextRange.empty,
    );
  }

  static TextEditingValue wrap(
    TextEditingValue value,
    String marker, {
    String? closing,
    String placeholder = 'text',
  }) {
    final selection = _selection(value);
    final endMarker = closing ?? marker;
    final selected = selection.textInside(value.text);
    final text = selected.isEmpty ? placeholder : selected;
    final replacement = '$marker$text$endMarker';
    return value.copyWith(
      text: value.text.replaceRange(
        selection.start,
        selection.end,
        replacement,
      ),
      selection: TextSelection(
        baseOffset: selection.start + marker.length,
        extentOffset: selection.start + marker.length + text.length,
      ),
      composing: TextRange.empty,
    );
  }

  /// Calculates 1-indexed line and column for the given text offset.
  static ({int line, int column}) lineAndColumnOf(String text, int offset) {
    if (offset <= 0 || text.isEmpty) return (line: 1, column: 1);
    final clamped = offset.clamp(0, text.length);
    var line = 1;
    var lastLineStart = 0;
    for (var i = 0; i < clamped; i++) {
      if (text.codeUnitAt(i) == 10) {
        line++;
        lastLineStart = i + 1;
      }
    }
    final column = clamped - lastLineStart + 1;
    return (line: line, column: column);
  }

  /// Returns total number of lines in [text] (at least 1).
  static int totalLinesOf(String text) {
    if (text.isEmpty) return 1;
    var count = 1;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 10) count++;
    }
    return count;
  }

  /// Calculates text offset for 1-indexed [targetLine] and optional [targetColumn].
  static int offsetOfLine(String text, int targetLine, [int targetColumn = 1]) {
    if (text.isEmpty) return 0;
    final line = targetLine < 1 ? 1 : targetLine;
    var curLine = 1;
    var lineStart = 0;
    while (curLine < line && lineStart < text.length) {
      final nextNewline = text.indexOf('\n', lineStart);
      if (nextNewline < 0) break;
      curLine++;
      lineStart = nextNewline + 1;
    }
    final nextNewline = text.indexOf('\n', lineStart);
    final lineEnd = nextNewline < 0 ? text.length : nextNewline;
    final lineLength = lineEnd - lineStart;
    final col = targetColumn < 1 ? 1 : targetColumn;
    final colOffset = (col - 1).clamp(0, lineLength);
    return (lineStart + colOffset).clamp(0, text.length);
  }

  /// Wraps the current selection with [open] and [close] delimiters, keeping
  /// the selection around the inner text.
  static TextEditingValue wrapSelection(
    TextEditingValue value,
    String open,
    String close,
  ) {
    final selection = _selection(value);
    final selected = selection.textInside(value.text);
    final replacement = '$open$selected$close';
    return value.copyWith(
      text: value.text.replaceRange(
        selection.start,
        selection.end,
        replacement,
      ),
      selection: TextSelection(
        baseOffset: selection.start + open.length,
        extentOffset: selection.start + open.length + selected.length,
      ),
      composing: TextRange.empty,
    );
  }

  /// Auto-pairs delimiters at caret, positioning the cursor between them.
  static TextEditingValue autoPair(
    TextEditingValue value,
    String open,
    String close,
  ) {
    final selection = _selection(value);
    final replacement = '$open$close';
    return value.copyWith(
      text: value.text.replaceRange(
        selection.start,
        selection.end,
        replacement,
      ),
      selection: TextSelection.collapsed(offset: selection.start + open.length),
      composing: TextRange.empty,
    );
  }

  /// If caret is between an empty pair of brackets/quotes, backspacing deletes both.
  static TextEditingValue? handleBackspacePair(TextEditingValue value) {
    if (!value.selection.isValid || !value.selection.isCollapsed) return null;
    final offset = value.selection.start;
    if (offset <= 0 || offset >= value.text.length) return null;
    final prev = value.text[offset - 1];
    final next = value.text[offset];
    const pairs = {
      '(': ')',
      '[': ']',
      '{': '}',
      '"': '"',
      "'": "'",
      '`': '`',
      r'$': r'$',
      '*': '*',
      '_': '_',
      '~': '~',
    };
    if (pairs[prev] == next) {
      return value.copyWith(
        text: value.text.replaceRange(offset - 1, offset + 1, ''),
        selection: TextSelection.collapsed(offset: offset - 1),
        composing: TextRange.empty,
      );
    }
    return null;
  }

  static const Map<String, String> autoPairs = {
    '(': ')',
    '[': ']',
    '{': '}',
    '"': '"',
    "'": "'",
    '`': '`',
    r'$': r'$',
  };

  static const Map<String, String> wrapPairs = {
    '(': ')',
    '[': ']',
    '{': '}',
    '"': '"',
    "'": "'",
    '`': '`',
    r'$': r'$',
    '*': '*',
    '_': '_',
    '~': '~',
  };

  /// Handles bracket/quote/delimiter typing: wraps if selection active,
  /// steps over if closing bracket is already at caret, or auto-pairs if collapsed.
  static TextEditingValue? handleAutoWrapOrPair(
    TextEditingValue value,
    String char,
  ) {
    if (!value.selection.isValid || !value.composing.isCollapsed) return null;

    // 1. Text is selected: wrap selection
    if (!value.selection.isCollapsed) {
      if (wrapPairs.containsKey(char)) {
        return wrapSelection(value, char, wrapPairs[char]!);
      }
      if (char == ')' || char == ']' || char == '}') {
        final open = wrapPairs.entries.firstWhere((e) => e.value == char).key;
        return wrapSelection(value, open, char);
      }
      return null;
    }

    // 2. Selection is collapsed: check step-over or auto-pair
    final offset = value.selection.start;

    // Step-over when typing matching closing character right before it
    if (offset < value.text.length && value.text[offset] == char) {
      if (char == ')' ||
          char == ']' ||
          char == '}' ||
          char == '"' ||
          char == "'" ||
          char == '`' ||
          char == r'$') {
        return value.copyWith(
          selection: TextSelection.collapsed(offset: offset + 1),
          composing: TextRange.empty,
        );
      }
    }

    // Auto-pair
    if (autoPairs.containsKey(char)) {
      // Do not auto-pair single quotes if preceded by a letter (e.g. apostrophe in don't)
      if (char == "'") {
        if (offset > 0 && RegExp(r'[\w]').hasMatch(value.text[offset - 1])) {
          return null;
        }
      }
      // For quotes and backticks, do not auto-pair if followed by a word character
      if (char == '"' || char == "'" || char == '`') {
        if (offset < value.text.length) {
          final nextChar = value.text[offset];
          if (RegExp(r'[\w]').hasMatch(nextChar)) return null;
        }
        if (offset > 0 && RegExp(r'[\w]').hasMatch(value.text[offset - 1])) {
          return null;
        }
      }
      return autoPair(value, char, autoPairs[char]!);
    }

    return null;
  }

  /// Moves the current line or selection up or down.
  static TextEditingValue? moveLine(
    TextEditingValue value, {
    required bool up,
  }) {
    if (value.text.isEmpty || !value.selection.isValid) return null;
    final text = value.text;
    final sel = value.selection;
    final startOffset = sel.start;
    final lineStart = startOffset == 0
        ? 0
        : text.lastIndexOf('\n', startOffset - 1) + 1;
    var effectiveEnd = sel.end;
    if (effectiveEnd > startOffset && text[effectiveEnd - 1] == '\n') {
      effectiveEnd--;
    }
    final nextNewline = text.indexOf('\n', effectiveEnd);
    final lineEnd = nextNewline < 0 ? text.length : nextNewline;
    final selectedBlock = text.substring(lineStart, lineEnd);

    if (up) {
      if (lineStart == 0) return null; // Already at top line
      final prevLineEnd = lineStart - 1;
      final prevLineStart = prevLineEnd == 0
          ? 0
          : text.lastIndexOf('\n', prevLineEnd - 1) + 1;
      final prevBlock = text.substring(prevLineStart, prevLineEnd);
      final replacement = '$selectedBlock\n$prevBlock';
      final newText = text.replaceRange(prevLineStart, lineEnd, replacement);
      final delta = prevLineStart - lineStart;
      return value.copyWith(
        text: newText,
        selection: TextSelection(
          baseOffset: (sel.baseOffset + delta).clamp(0, newText.length),
          extentOffset: (sel.extentOffset + delta).clamp(0, newText.length),
        ),
        composing: TextRange.empty,
      );
    } else {
      if (lineEnd >= text.length) return null; // Already at bottom line
      final nextLineStart = lineEnd + 1;
      final afterNextNewline = text.indexOf('\n', nextLineStart);
      final nextLineEnd = afterNextNewline < 0 ? text.length : afterNextNewline;
      final nextBlock = text.substring(nextLineStart, nextLineEnd);
      final replacement = '$nextBlock\n$selectedBlock';
      final newText = text.replaceRange(lineStart, nextLineEnd, replacement);
      final delta = nextBlock.length + 1;
      return value.copyWith(
        text: newText,
        selection: TextSelection(
          baseOffset: (sel.baseOffset + delta).clamp(0, newText.length),
          extentOffset: (sel.extentOffset + delta).clamp(0, newText.length),
        ),
        composing: TextRange.empty,
      );
    }
  }

  /// Duplicates the current line or selection downwards.
  static TextEditingValue? duplicateLine(TextEditingValue value) {
    if (!value.selection.isValid) return null;
    if (value.text.isEmpty) {
      return value.copyWith(
        text: '\n',
        selection: const TextSelection.collapsed(offset: 1),
        composing: TextRange.empty,
      );
    }
    final text = value.text;
    final sel = value.selection;
    final startOffset = sel.start;
    final lineStart = startOffset == 0
        ? 0
        : text.lastIndexOf('\n', startOffset - 1) + 1;
    var effectiveEnd = sel.end;
    if (effectiveEnd > startOffset && text[effectiveEnd - 1] == '\n') {
      effectiveEnd--;
    }
    final nextNewline = text.indexOf('\n', effectiveEnd);
    final lineEnd = nextNewline < 0 ? text.length : nextNewline;
    final block = text.substring(lineStart, lineEnd);
    final newText = text.replaceRange(lineEnd, lineEnd, '\n$block');
    final delta = block.length + 1;
    return value.copyWith(
      text: newText,
      selection: TextSelection(
        baseOffset: (sel.baseOffset + delta).clamp(0, newText.length),
        extentOffset: (sel.extentOffset + delta).clamp(0, newText.length),
      ),
      composing: TextRange.empty,
    );
  }

  static TextEditingValue prefixLines(TextEditingValue value, String prefix) {
    final selection = _selection(value);
    final lineStart = selection.start == 0
        ? 0
        : value.text.lastIndexOf('\n', selection.start - 1) + 1;
    var effectiveEnd = selection.end;
    if (effectiveEnd > selection.start &&
        value.text[effectiveEnd - 1] == '\n') {
      effectiveEnd--;
    }
    final nextLine = value.text.indexOf('\n', effectiveEnd);
    final lineEnd = nextLine < 0 ? value.text.length : nextLine;
    final lines = value.text.substring(lineStart, lineEnd).split('\n');
    final remove = lines.every((line) => line.startsWith(prefix));
    final replacement = lines
        .map((line) => remove ? line.substring(prefix.length) : '$prefix$line')
        .join('\n');
    return value.copyWith(
      text: value.text.replaceRange(lineStart, lineEnd, replacement),
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + replacement.length,
      ),
      composing: TextRange.empty,
    );
  }

  static TextEditingValue insert(TextEditingValue value, String content) {
    final selection = _selection(value);
    return value.copyWith(
      text: value.text.replaceRange(selection.start, selection.end, content),
      selection: TextSelection.collapsed(
        offset: selection.start + content.length,
      ),
      composing: TextRange.empty,
    );
  }

  /// Inserts a numbered footnote reference [^n] at current selection and appends
  /// the corresponding footnote definition [^n]: at the end of the text.
  static TextEditingValue insertFootnote(TextEditingValue value) {
    final matches = RegExp(r'\[\^(\d+)\]').allMatches(value.text);
    int maxIndex = 0;
    for (final m in matches) {
      final parsed = int.tryParse(m.group(1) ?? '0') ?? 0;
      if (parsed > maxIndex) maxIndex = parsed;
    }
    final nextIndex = maxIndex + 1;
    final marker = '[^$nextIndex]';

    final sel = _selection(value);
    final caret = sel.start;
    final before = value.text.substring(0, caret);
    final after = value.text.substring(sel.end);

    final textWithMarker = '$before$marker$after';
    final hasTrailingNewline = textWithMarker.endsWith('\n');
    final needsDoubleNewline = !textWithMarker.endsWith('\n\n');
    final prefix = textWithMarker.isEmpty
        ? ''
        : (needsDoubleNewline ? (hasTrailingNewline ? '\n' : '\n\n') : '');
    final defPrompt = '$prefix[^$nextIndex]: ';

    final fullText = '$textWithMarker$defPrompt';
    return TextEditingValue(
      text: fullText,
      selection: TextSelection.collapsed(offset: fullText.length),
      composing: TextRange.empty,
    );
  }

  static TextSelection _selection(TextEditingValue value) =>
      value.selection.isValid && value.selection.end <= value.text.length
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);
}
