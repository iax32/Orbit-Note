import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';

/// View-only floating chrome. Dragging rebuilds this overlay, never the Canvas
/// scene, camera or editor. Normalized placement stays reachable after resizing.
class CanvasFocusControls extends StatefulWidget {
  const CanvasFocusControls({
    super.key,
    required this.toolbar,
    required this.dock,
    required this.expanded,
    this.initialAnchor = const Offset(1, 0),
    this.initialLocked = false,
    this.onPlacementChanged,
    this.touchSize = 48,
    this.onComfort,
  });
  final double touchSize;
  final VoidCallback? onComfort;
  final Widget toolbar, dock;
  final bool expanded, initialLocked;
  final Offset initialAnchor;
  final void Function(Offset anchor, bool locked)? onPlacementChanged;
  @override
  State<CanvasFocusControls> createState() => _CanvasFocusControlsState();
}

class _CanvasFocusControlsState extends State<CanvasFocusControls> {
  final _body = GlobalKey();
  final _area = GlobalKey();
  late Offset _anchor;
  late bool _locked;
  bool _dragging = false, _hovered = false, _bottom = false;
  Offset _pixelPosition = Offset.zero;
  Size _space = Size.zero;
  @override
  void initState() {
    super.initState();
    final value = widget.initialAnchor;
    _anchor = value.dx.isFinite && value.dy.isFinite
        ? Offset(value.dx.clamp(0, 1), value.dy.clamp(0, 1))
        : const Offset(1, 0);
    _locked = widget.initialLocked;
    _bottom = _anchor.dy > .5;
  }

  @override
  void didUpdateWidget(covariant CanvasFocusControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.initialAnchor != widget.initialAnchor) {
      final a = widget.initialAnchor;
      _anchor = a.dx.isFinite && a.dy.isFinite
          ? Offset(a.dx.clamp(0, 1), a.dy.clamp(0, 1))
          : const Offset(1, 0);
      _bottom = _anchor.dy > .5;
    }
    if (oldWidget.initialLocked != widget.initialLocked) {
      _locked = widget.initialLocked;
    }
  }

  Offset get _free {
    final size = _body.currentContext?.size ?? Size.zero;
    return Offset(
      math.max(0, _space.width - size.width),
      math.max(0, _space.height - size.height),
    );
  }

  void _remember() => widget.onPlacementChanged?.call(_anchor, _locked);
  void _start(DragStartDetails details) {
    final free = _free;
    final body = _body.currentContext?.findRenderObject();
    final area = _area.currentContext?.findRenderObject();
    _pixelPosition = body is RenderBox && area is RenderBox
        ? body.localToGlobal(Offset.zero, ancestor: area)
        : Offset(free.dx * _anchor.dx, free.dy * _anchor.dy);
    setState(() {
      _anchor = Offset(
        free.dx == 0 ? _anchor.dx : (_pixelPosition.dx / free.dx).clamp(0, 1),
        free.dy == 0 ? _anchor.dy : (_pixelPosition.dy / free.dy).clamp(0, 1),
      );
      _dragging = true;
    });
  }

  void _move(DragUpdateDetails details) {
    final free = _free;
    _pixelPosition = Offset(
      (_pixelPosition.dx + details.delta.dx).clamp(0, free.dx),
      (_pixelPosition.dy + details.delta.dy).clamp(0, free.dy),
    );
    setState(
      () => _anchor = Offset(
        free.dx == 0 ? _anchor.dx : _pixelPosition.dx / free.dx,
        free.dy == 0 ? _anchor.dy : _pixelPosition.dy / free.dy,
      ),
    );
  }

  void _finish() {
    if (!mounted) return;
    final free = _free;
    double snap(double value, double extent) {
      if (extent <= 0) return value;
      if (value * extent <= 24) return 0;
      if ((1 - value) * extent <= 24) return 1;
      return value;
    }

    setState(() {
      _anchor = Offset(snap(_anchor.dx, free.dx), snap(_anchor.dy, free.dy));
      _dragging = false;
      _bottom = _anchor.dy > .5;
    });
    _remember();
  }

  void _position(String value) {
    if (value == 'comfort') {
      widget.onComfort?.call();
      return;
    }
    setState(() {
      switch (value) {
        case 'top-left':
          _anchor = Offset.zero;
        case 'top-right':
          _anchor = const Offset(1, 0);
        case 'bottom-left':
          _anchor = const Offset(0, 1);
        case 'bottom-right':
          _anchor = const Offset(1, 1);
        case 'lock':
          _locked = !_locked;
        case 'reset':
          _anchor = const Offset(1, 0);
          _locked = false;
      }
      _bottom = _anchor.dy > .5;
    });
    _remember();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: LayoutBuilder(
      key: _area,
      builder: (context, constraints) {
        _space = constraints.biggest;
        final colors = Theme.of(context).colorScheme;
        final duration = OrbitMotionScope.duration(
          context,
          OrbitMotion.panel,
          spatial: true,
        );
        final grip = MouseRegion(
          cursor: _locked
              ? SystemMouseCursors.basic
              : _dragging
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onPanStart: _locked ? null : _start,
            onPanUpdate: _locked ? null : _move,
            onPanEnd: _locked ? null : (_) => _finish(),
            onPanCancel: _locked ? null : _finish,
            child: AnimatedContainer(
              duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
              decoration: BoxDecoration(
                color: _dragging
                    ? colors.primaryContainer
                    : _hovered
                    ? colors.surfaceContainerHigh
                    : colors.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _dragging ? colors.primary : colors.outlineVariant,
                ),
              ),
              child: PopupMenuButton<String>(
                key: const ValueKey('canvas-focus-position'),
                tooltip: _locked
                    ? 'Canvas controls position (locked)'
                    : 'Move Canvas controls · tap for positions',
                popUpAnimationStyle: OrbitMotionScope.popupStyle(context),
                onSelected: _position,
                itemBuilder: (_) => [
                  if (widget.onComfort != null)
                    const PopupMenuItem(
                      value: 'comfort',
                      child: Text('Tablet comfort…'),
                    ),
                  const PopupMenuItem(
                    value: 'top-left',
                    child: Text('Top left'),
                  ),
                  const PopupMenuItem(
                    value: 'top-right',
                    child: Text('Top right'),
                  ),
                  const PopupMenuItem(
                    value: 'bottom-left',
                    child: Text('Bottom left'),
                  ),
                  const PopupMenuItem(
                    value: 'bottom-right',
                    child: Text('Bottom right'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'lock',
                    child: Text(_locked ? 'Unlock position' : 'Lock position'),
                  ),
                  const PopupMenuItem(
                    value: 'reset',
                    child: Text('Reset position'),
                  ),
                ],
                child: SizedBox(
                  width: widget.touchSize,
                  height: widget.touchSize,
                  child: Icon(
                    _locked ? Icons.push_pin_outlined : Icons.drag_indicator,
                    size: 19,
                    color: _dragging
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        );
        final compact = Wrap(
          alignment: _anchor.dx < .5 ? WrapAlignment.start : WrapAlignment.end,
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [grip, widget.dock],
        );
        final tools = OrbitDisclosure(
          visible: widget.expanded,
          duration: _dragging ? Duration.zero : OrbitMotion.panel,
          alignment: Alignment(_anchor.dx < .5 ? -1 : 1, _bottom ? 1 : -1),
          child: Padding(
            padding: EdgeInsets.only(
              top: _bottom ? 8 : 0,
              bottom: _bottom ? 0 : 8,
            ),
            child: widget.toolbar,
          ),
        );
        return AnimatedAlign(
          alignment: Alignment(_anchor.dx * 2 - 1, _anchor.dy * 2 - 1),
          duration: _dragging ? Duration.zero : duration,
          curve: OrbitMotion.ease,
          child: RepaintBoundary(
            child: SizedBox(
              key: _body,
              width: widget.expanded
                  ? math.min(1200, constraints.maxWidth)
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: _anchor.dx < .5
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: _bottom ? [compact, tools] : [tools, compact],
              ),
            ),
          ),
        );
      },
    ),
  );
}
