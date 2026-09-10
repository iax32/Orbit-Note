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

  static TextSelection _selection(TextEditingValue value) =>
      value.selection.isValid && value.selection.end <= value.text.length
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);
}
