import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'note_find_index.dart';

class ReadSearchRequest {
  const ReadSearchRequest({
    required this.query,
    required this.expectedCount,
    required this.visibleIndices,
    required this.selectedIndex,
    required this.matchCase,
    required this.wholeWord,
    required this.expectedSegments,
  });
  final String query;
  final int expectedCount, selectedIndex;
  final Set<int> visibleIndices;
  final bool matchCase, wholeWord;
  final List<String> expectedSegments;
}

/// A custom renderer's authored text inside a selectable display label.
class ReadSearchText extends InheritedWidget {
  const ReadSearchText({
    super.key,
    required this.text,
    required this.leadingLength,
    this.normalizeQueryLineEndings = false,
    required super.child,
  });
  final String text;
  final int leadingLength;

  /// Fenced code is rendered with LF even when authored source uses CRLF.
  /// Only its query is normalized; selection offsets still use displayed text.
  final bool normalizeQueryLineEndings;
  @override
  bool updateShouldNotify(ReadSearchText oldWidget) =>
      text != oldWidget.text ||
      leadingLength != oldWidget.leadingLength ||
      normalizeQueryLineEndings != oldWidget.normalizeQueryLineEndings;
}

/// Paragraphs that share one source search segment (e.g. a callout body).
class ReadSearchGroup extends StatelessWidget {
  const ReadSearchGroup({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

/// Adds transient search decoration without replacing the Markdown renderer or
/// altering its selectable text, links, custom widgets or stored source.
class ReadSearchOverlay extends StatefulWidget {
  const ReadSearchOverlay({
    super.key,
    required this.child,
    required this.request,
  });
  final Widget child;
  final ReadSearchRequest? request;
  @override
  State<ReadSearchOverlay> createState() => ReadSearchOverlayState();
}

class _Target {
  _Target(this.render, this.selection, this.index);
  final RenderEditable render;
  final TextSelection selection;
  final int index;
}

class ReadSearchOverlayState extends State<ReadSearchOverlay> {
  final _content = GlobalKey();
  final _paint = GlobalKey();
  List<_Target> _targets = [];
  bool _mapped = false, _scheduled = false;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(ReadSearchOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) {
        _collect();
        setState(() {});
      }
    });
  }

  void _collect() {
    final request = widget.request;
    _targets = [];
    _mapped = false;
    if (request == null || request.query.isEmpty) return;
    final renderedSegments = <String>[];
    void collectField(Element element, List<String>? group) {
      final render = ((element as StatefulElement).state as EditableTextState)
          .renderEditable;
      final displayed = render.text?.toPlainText() ?? '';
      final authored = element.findAncestorWidgetOfExactType<ReadSearchText>();
      final text = authored?.text ?? displayed;
      final leading = authored?.leadingLength ?? 0;
      if (leading < 0 ||
          leading + text.length > displayed.length ||
          displayed.substring(leading, leading + text.length) != text) {
        return;
      }
      group?.add(text);
      for (final match in NoteFindIndex(text, rich: false).matches(
        authored?.normalizeQueryLineEndings == true
            ? request.query.replaceAll('\r\n', '\n')
            : request.query,
        matchCase: request.matchCase,
        wholeWord: request.wholeWord,
      )) {
        _targets.add(
          _Target(
            render,
            TextSelection(
              baseOffset: leading + match.start,
              extentOffset: leading + match.end,
            ),
            _targets.length,
          ),
        );
        renderedSegments.add(text);
      }
    }

    void visit(Element element) {
      if (element.widget is ReadSearchGroup) {
        final first = renderedSegments.length;
        final parts = <String>[];
        void groupVisit(Element child) {
          if (child is StatefulElement && child.state is EditableTextState) {
            collectField(child, parts);
          } else {
            child.visitChildren(groupVisit);
          }
        }

        element.visitChildren(groupVisit);
        final context = parts.join('\n\n');
        for (var i = first; i < renderedSegments.length; i++) {
          renderedSegments[i] = context;
        }
        return;
      }
      // Markdown's selectable paragraphs/cells and read-only code fields share
      // RenderEditable. Button labels, language badges and math glyphs do not.
      if (element is StatefulElement && element.state is EditableTextState) {
        collectField(element, null);
        return;
      }
      element.visitChildren(visit);
    }

    _content.currentContext?.visitChildElements(visit);
    // A mismatch can mean a custom renderer hides/reinterprets source. Never
    // highlight or navigate to an unrelated occurrence by guessing its ordinal.
    final normalizedSegments = Map<String, String>.identity();
    String normalized(String value) => normalizedSegments.putIfAbsent(
      value,
      () => value.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
    final verifiedSegments = <(String, String), bool>{};
    _mapped =
        _targets.isNotEmpty &&
        request.visibleIndices.isNotEmpty &&
        _targets.length == request.expectedCount &&
        request.expectedSegments.length == _targets.length;
    if (_mapped) {
      for (var i = 0; i < renderedSegments.length; i++) {
        if (!verifiedSegments.putIfAbsent(
          (renderedSegments[i], request.expectedSegments[i]),
          () =>
              normalized(renderedSegments[i]) ==
              normalized(request.expectedSegments[i]),
        )) {
          _mapped = false;
          break;
        }
      }
    }
    _revision++;
  }

  bool revealSelected() {
    _collect();
    final request = widget.request;
    if (!_mapped ||
        request == null ||
        request.selectedIndex < 0 ||
        request.selectedIndex >= _targets.length ||
        !request.visibleIndices.contains(request.selectedIndex)) {
      return false;
    }
    final target = _targets[request.selectedIndex];
    if (!target.render.attached) return false;
    final boxes = target.render.getBoxesForSelection(target.selection);
    if (boxes.isEmpty) return false;
    target.render.showOnScreen(
      rect: boxes.first.toRect(),
      duration: Duration.zero,
    );
    setState(() {});
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        // Inner horizontal code scrolling changes box positions, not matching.
        if (_mapped && mounted) setState(() => _revision++);
        return false;
      },
      child: CustomPaint(
        key: _paint,
        foregroundPainter: _mapped && request != null
            ? _SearchPainter(
                targets: _targets,
                request: request,
                anchor: _paint,
                color: Theme.of(context).colorScheme.primary,
                revision: _revision,
              )
            : null,
        child: KeyedSubtree(key: _content, child: widget.child),
      ),
    );
  }
}

class _SearchPainter extends CustomPainter {
  _SearchPainter({
    required this.targets,
    required this.request,
    required this.anchor,
    required this.color,
    required this.revision,
  });
  final List<_Target> targets;
  final ReadSearchRequest request;
  final GlobalKey anchor;
  final Color color;
  final int revision;
  @override
  void paint(Canvas canvas, Size size) {
    final overlay = anchor.currentContext?.findRenderObject();
    if (overlay is! RenderBox || !overlay.hasSize) return;
    for (final target in targets) {
      if (!request.visibleIndices.contains(target.index) ||
          !target.render.attached) {
        continue;
      }
      final active = target.index == request.selectedIndex;
      final paint = Paint()
        ..color = color.withValues(alpha: active ? .28 : .13);
      for (final box in target.render.getBoxesForSelection(target.selection)) {
        final local = box.toRect();
        var rect = Rect.fromPoints(
          overlay.globalToLocal(target.render.localToGlobal(local.topLeft)),
          overlay.globalToLocal(target.render.localToGlobal(local.bottomRight)),
        );
        RenderObject? parent = target.render.parent;
        while (parent != null && parent != overlay) {
          if ((parent is RenderAbstractViewport || parent is RenderClipRect) &&
              parent is RenderBox &&
              parent.hasSize) {
            rect = rect.intersect(
              Rect.fromPoints(
                overlay.globalToLocal(parent.localToGlobal(Offset.zero)),
                overlay.globalToLocal(
                  parent.localToGlobal(parent.size.bottomRight(Offset.zero)),
                ),
              ),
            );
          }
          parent = parent.parent;
        }
        if (rect.isEmpty) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
        if (active) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            Paint()
              ..color = color.withValues(alpha: .8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SearchPainter oldDelegate) =>
      oldDelegate.revision != revision ||
      oldDelegate.request != request ||
      oldDelegate.color != color;
}
