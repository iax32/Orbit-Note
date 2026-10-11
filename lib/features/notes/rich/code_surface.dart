import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'code_editing.dart';

/// One native text field with a viewport-sized, wrap-aware line-number gutter.
/// The gutter reads rendered caret positions rather than estimating row heights.
class CodeSurface extends StatefulWidget {
  const CodeSurface({
    super.key,
    required this.controller,
    required this.focus,
    required this.fieldKey,
    required this.lines,
    required this.wrap,
    required this.onChanged,
    this.readOnly = false,
    this.autofocus = false,
    this.numbers = true,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final Key fieldKey;
  final List<({int start, int contentEnd, int end})> lines;
  final bool wrap, readOnly, autofocus, numbers;
  final ValueChanged<String> onChanged;
  @override
  State<CodeSurface> createState() => _CodeSurfaceState();
}

class _CodeSurfaceState extends State<CodeSurface> {
  final host = GlobalKey();
  final gutter = GlobalKey();
  final vertical = ScrollController();
  final horizontal = ScrollController();
  Listenable get repaint =>
      Listenable.merge([widget.controller, vertical, horizontal]);
  bool revealScheduled = false;
  String? measuredSource;
  int longest = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(revealCaret);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(revealCaret);
    vertical.dispose();
    horizontal.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CodeSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(revealCaret);
      widget.controller.addListener(revealCaret);
    }
    if (oldWidget.wrap != widget.wrap) revealCaret();
  }

  void revealCaret() {
    if (revealScheduled) return;
    revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      revealScheduled = false;
      if (!mounted ||
          !widget.focus.hasFocus ||
          !widget.controller.selection.isValid) {
        return;
      }
      editableState()?.bringIntoView(widget.controller.selection.extent);
    });
  }

  EditableTextState? editableState() {
    EditableTextState? result;
    void visit(Element element) {
      if (element is StatefulElement && element.state is EditableTextState) {
        result = element.state as EditableTextState;
      } else {
        element.visitChildElements(visit);
      }
    }

    host.currentContext?.visitChildElements(visit);
    return result;
  }

  RenderEditable? render() {
    final result = editableState()?.renderEditable;
    return result?.hasSize == true ? result : null;
  }

  Offset origin() {
    final box = gutter.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero)
        : Offset.zero;
  }

  void selectLine(TapDownDetails details) {
    final editable = render();
    if (editable == null) return;
    final localY = editable.globalToLocal(details.globalPosition).dy;
    final offset = editable
        .getPositionForPoint(editable.localToGlobal(Offset(0, localY)))
        .offset;
    final line = widget.lines[codeLineAt(widget.lines, offset)];
    widget.controller.selection = TextSelection(
      baseOffset: line.start,
      extentOffset: line.end,
    );
    widget.focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (measuredSource != widget.controller.text) {
      measuredSource = widget.controller.text;
      longest = widget.lines.fold<int>(
        0,
        (n, l) => math.max(n, l.contentEnd - l.start),
      );
    }
    final scale = MediaQuery.textScalerOf(context);
    final theme = Theme.of(context);
    final digits = widget.lines.length.toString().length;
    final gutterWidth = widget.numbers
        ? scale.scale(10) * math.max(digits, 2) + 18
        : 0.0;
    return Row(
      children: [
        if (widget.numbers)
          SizedBox(
            width: gutterWidth,
            child: GestureDetector(
              key: gutter,
              behavior: HitTestBehavior.opaque,
              onTapDown: selectLine,
              child: Semantics(
                label: 'Code line numbers. Tap a number to select its line.',
                child: CustomPaint(
                  painter: _LineNumbers(
                    render,
                    origin,
                    widget.controller,
                    widget.lines,
                    theme.colorScheme,
                    scale,
                    repaint,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, area) {
              Widget field(double width) => SizedBox(
                key: host,
                width: width,
                height: area.maxHeight,
                child: TextField(
                  key: widget.fieldKey,
                  controller: widget.controller,
                  focusNode: widget.focus,
                  scrollController: vertical,
                  autofocus: widget.autofocus,
                  readOnly: widget.readOnly,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.6,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: widget.onChanged,
                ),
              );
              if (widget.wrap) return field(area.maxWidth);
              return SingleChildScrollView(
                controller: horizontal,
                scrollDirection: Axis.horizontal,
                child: field(
                  math.max(
                    area.maxWidth,
                    math.min(100000, longest * scale.scale(9) + 40),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LineNumbers extends CustomPainter {
  _LineNumbers(
    this.render,
    this.origin,
    this.controller,
    this.lines,
    this.colors,
    this.scaler,
    Listenable repaint,
  ) : super(repaint: repaint);
  final RenderEditable? Function() render;
  final Offset Function() origin;
  final TextEditingController controller;
  final List<({int start, int contentEnd, int end})> lines;
  final ColorScheme colors;
  final TextScaler scaler;
  @override
  void paint(Canvas canvas, Size size) {
    final editable = render();
    if (editable == null) return;
    final top = editable
        .getPositionForPoint(editable.localToGlobal(Offset.zero))
        .offset;
    final bottom = editable
        .getPositionForPoint(
          editable.localToGlobal(Offset(0, editable.size.height)),
        )
        .offset;
    final first = math.max(0, codeLineAt(lines, top) - 1);
    final last = math.min(lines.length - 1, codeLineAt(lines, bottom) + 1);
    final active = controller.selection.isValid
        ? codeLineAt(lines, controller.selection.extentOffset)
        : -1;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = first; i <= last; i++) {
      final caret = editable.getLocalRectForCaret(
        TextPosition(offset: lines[i].start),
      );
      final y = editable.localToGlobal(caret.topLeft).dy - origin().dy;
      if (y + caret.height < 0 || y > size.height) continue;
      if (i == active) {
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width - 5, caret.height),
          Paint()..color = colors.primary.withValues(alpha: .12),
        );
        canvas.drawRect(
          Rect.fromLTWH(0, y, 2, caret.height),
          Paint()..color = colors.primary,
        );
      }
      painter.text = TextSpan(
        text: '${i + 1}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: i == active ? colors.primary : colors.onSurfaceVariant,
          fontWeight: i == active ? FontWeight.w600 : FontWeight.normal,
        ),
      );
      painter.layout();
      painter.paint(
        canvas,
        Offset(
          size.width - painter.width - 10,
          y + (caret.height - painter.height) / 2,
        ),
      );
    }
    canvas.restore();
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _LineNumbers old) => true;
}
