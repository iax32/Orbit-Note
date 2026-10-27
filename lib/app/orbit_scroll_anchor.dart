import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Keeps visible text in place when an already-laid-out block above it grows.
/// Explicit scrolling, navigation, resizing and owner changes take precedence.
class OrbitScrollAnchorCoordinator {
  OrbitScrollAnchorCoordinator(this.scroll);
  final ScrollController scroll;
  int _epoch = 0;
  double _delta = 0;
  bool _scheduled = false;
  void reset() {
    _epoch++;
    _scheduled = false;
    _delta = 0;
  }

  void adjust(double delta) {
    if (!scroll.hasClients ||
        scroll.positions.length != 1 ||
        scroll.position.isScrollingNotifier.value) {
      return;
    }
    _delta += delta;
    if (_scheduled) return;
    _scheduled = true;
    final epoch = _epoch, position = scroll.position, offset = scroll.offset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (epoch != _epoch) return;
      final change = _delta;
      _scheduled = false;
      _delta = 0;
      if (!scroll.hasClients ||
          !identical(scroll.position, position) ||
          position.isScrollingNotifier.value ||
          (scroll.offset - offset).abs() > .5) {
        return;
      }
      final target = (offset + change).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((target - scroll.offset).abs() > .5) scroll.jumpTo(target);
    });
  }
}

class OrbitScrollAnchor extends SingleChildRenderObjectWidget {
  const OrbitScrollAnchor({
    super.key,
    required this.coordinator,
    required super.child,
  });
  final OrbitScrollAnchorCoordinator coordinator;
  @override
  RenderObject createRenderObject(BuildContext context) => _Anchor(coordinator);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) => (renderObject as _Anchor).coordinator = coordinator;
}

class _Anchor extends RenderProxyBox {
  _Anchor(this.coordinator);
  OrbitScrollAnchorCoordinator coordinator;
  BoxConstraints? previousConstraints;
  @override
  void performLayout() {
    final oldHeight = hasSize ? size.height : null;
    var above = false;
    final viewport = RenderAbstractViewport.maybeOf(this);
    if (oldHeight != null &&
        previousConstraints == constraints &&
        coordinator.scroll.hasClients &&
        viewport != null) {
      above =
          viewport.getOffsetToReveal(this, 0).offset + oldHeight <=
          coordinator.scroll.offset + .5;
    }
    super.performLayout();
    previousConstraints = constraints;
    if (above && oldHeight != null && (size.height - oldHeight).abs() > .5) {
      coordinator.adjust(size.height - oldHeight);
    }
  }
}
