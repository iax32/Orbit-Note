import 'package:flutter/material.dart';

/// A visual projection of supported text formatting. Edits splice visible
/// characters, retaining the surrounding TeX commands and unknown source.
class LatexProseController extends TextEditingController {
  LatexProseController(String source) : _projection = _ProseProjection(source) {
    super.value = TextEditingValue(text: _projection.text);
  }
  _ProseProjection _projection;
  final Set<String> typingStyles = {};
  String get source => _projection.source;

  bool isStyleActive(String command) {
    if (!selection.isValid || selection.isCollapsed) {
      return typingStyles.contains(command);
    }
    return _projection.ranges
        .sublist(selection.start, selection.end)
        .every((range) => range.styles.contains(command));
  }

  void setSource(String source) {
    if (source == this.source) return;
    _projection = _ProseProjection(source);
    super.value = TextEditingValue(
      text: _projection.text,
      selection: TextSelection.collapsed(
        offset: selection.extentOffset.clamp(0, _projection.text.length),
      ),
    );
  }

  @override
  set value(TextEditingValue next) {
    if (next.text != text) {
      var start = 0;
      while (start < text.length &&
          start < next.text.length &&
          text[start] == next.text[start]) {
        start++;
      }
      var oldEnd = text.length, newEnd = next.text.length;
      while (oldEnd > start &&
          newEnd > start &&
          text[oldEnd - 1] == next.text[newEnd - 1]) {
        oldEnd--;
        newEnd--;
      }
      var inserted = _escape(next.text.substring(start, newEnd));
      for (final style in typingStyles) {
        inserted = '\\$style{$inserted}';
      }
      final ranges = _projection.ranges;
      var result = source;
      final insertion = start < ranges.length
          ? ranges[start].start
          : ranges.isEmpty
          ? source.length
          : ranges.last.end;
      // Delete visible characters individually so a selection crossing styled
      // runs cannot delete one brace and leave the document unbalanced.
      for (var i = oldEnd - 1; i >= start; i--) {
        result = result.replaceRange(ranges[i].start, ranges[i].end, '');
      }
      result = result.replaceRange(insertion, insertion, inserted);
      _projection = _ProseProjection(result);
    }
    super.value = next;
  }

  void format(String command) {
    final selected = selection;
    if (!selected.isValid || selected.isCollapsed) {
      typingStyles.contains(command)
          ? typingStyles.remove(command)
          : typingStyles.add(command);
      notifyListeners();
      return;
    }
    var result = source;
    final from = _projection.ranges[selected.start].start;
    final to = _projection.ranges[selected.end - 1].end;
    final wrapper = '\\$command{';
    if (from >= wrapper.length &&
        source.substring(from - wrapper.length, from) == wrapper &&
        to < source.length &&
        source[to] == '}') {
      result = source
          .replaceRange(to, to + 1, '')
          .replaceRange(from - wrapper.length, from, '');
      _projection = _ProseProjection(result);
      notifyListeners();
      return;
    }
    // Each contiguous source run is wrapped separately to preserve nesting.
    var end = selected.end;
    while (end > selected.start) {
      var start = end - 1;
      while (start > selected.start &&
          _projection.ranges[start - 1].end ==
              _projection.ranges[start].start) {
        start--;
      }
      final from = _projection.ranges[start].start;
      final to = _projection.ranges[end - 1].end;
      result = result.replaceRange(
        from,
        to,
        '\\$command{${source.substring(from, to)}}',
      );
      end = start;
    }
    _projection = _ProseProjection(result);
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_projection.text != text) return TextSpan(text: text, style: style);
    TextStyle styleAt(int i) => TextStyle(
      fontWeight: _projection.ranges[i].styles.contains('textbf')
          ? FontWeight.w700
          : null,
      fontStyle:
          _projection.ranges[i].styles.any((s) => s == 'textit' || s == 'emph')
          ? FontStyle.italic
          : null,
      decoration:
          _projection.ranges[i].styles.contains('underline') ||
              (withComposing &&
                  value.composing.isValid &&
                  !value.composing.isCollapsed &&
                  i >= value.composing.start &&
                  i < value.composing.end)
          ? TextDecoration.underline
          : null,
    );
    final spans = <TextSpan>[];
    var start = 0;
    while (start < text.length) {
      final currentStyle = styleAt(start);
      var end = start + 1;
      while (end < text.length && styleAt(end) == currentStyle) {
        end++;
      }
      spans.add(
        TextSpan(text: text.substring(start, end), style: currentStyle),
      );
      start = end;
    }
    return TextSpan(style: style, children: spans);
  }

  static String _escape(String text) => text
      .split('')
      .map(
        (c) => switch (c) {
          '\\' => r'\textbackslash{}',
          '&' || '%' || '\$' || '#' || '_' || '{' || '}' => '\\$c',
          '~' => r'\textasciitilde{}',
          '^' => r'\textasciicircum{}',
          _ => c,
        },
      )
      .join();
}

class _VisibleCharacter {
  const _VisibleCharacter(this.start, this.end, this.styles);
  final int start, end;
  final Set<String> styles;
}

class _ProseProjection {
  _ProseProjection(this.source) {
    _parse(0, source.length, {});
  }
  final String source;
  final _text = StringBuffer();
  final ranges = <_VisibleCharacter>[];
  String get text => _text.toString();

  void _parse(int start, int end, Set<String> styles) {
    var i = start;
    while (i < end) {
      final format = RegExp(
        r'\\(textbf|textit|emph|underline)\{',
      ).matchAsPrefix(source, i);
      if (format != null) {
        var depth = 1, close = format.end;
        while (close < end && depth > 0) {
          if (source[close] == '\\') {
            close += 2;
            continue;
          }
          if (source[close] == '{') depth++;
          if (source[close] == '}') depth--;
          close++;
        }
        if (depth == 0) {
          _parse(format.end, close - 1, {...styles, format.group(1)!});
          i = close;
          continue;
        }
      }
      String? displayed;
      var length = 1;
      for (final entry in const {
        r'\textbackslash{}': '\\',
        r'\textasciitilde{}': '~',
        r'\textasciicircum{}': '^',
        r'\&': '&',
        r'\%': '%',
        r'\$': '\$',
        r'\#': '#',
        r'\_': '_',
        r'\{': '{',
        r'\}': '}',
      }.entries) {
        if (source.startsWith(entry.key, i)) {
          displayed = entry.value;
          length = entry.key.length;
          break;
        }
      }
      _text.write(displayed ?? source[i]);
      ranges.add(_VisibleCharacter(i, i + length, styles));
      i += length;
    }
  }
}
