import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/edge_scroll.dart';

/// Scrolls the viewport, never the dragged row, and owns no document mutation.
class OrbitDragScroll {
  OrbitDragScroll(this.controller, this.viewport);
  final ScrollController controller;
  final GlobalKey viewport;
  Timer? _timer;
  Offset? _point;
  void update(Offset globalPosition) {
    _point = globalPosition;
    _timer ??= Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _tick() {
    final box = viewport.currentContext?.findRenderObject();
    if (box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        !controller.hasClients ||
        _point == null) {
      stop();
      return;
    }
    final local = box.globalToLocal(_point!);
    if (local.dx < 0 || local.dx > box.size.width) {
      stop();
      return;
    }
    final delta = edgeScrollStep(local.dy, box.size.height);
    if (delta == 0) {
      stop();
      return;
    }
    final next = (controller.offset + delta).clamp(
      controller.position.minScrollExtent,
      controller.position.maxScrollExtent,
    );
    if (next == controller.offset) {
      stop();
      return;
    }
    controller.jumpTo(next);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _point = null;
  }
}
