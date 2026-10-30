import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Mouse moves immediately; touch/pen must hold before moving an explorer item.
/// Use the actual pointer kind so a tablet mouse and a PC touchscreen both work.
class OrbitScrollSafeDrag<T extends Object> extends Draggable<T> {
  const OrbitScrollSafeDrag({
    super.key,
    required super.data,
    required super.feedback,
    required super.child,
    super.onDragUpdate,
    super.onDragEnd,
    super.onDraggableCanceled,
    super.maxSimultaneousDrags,
  });
  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => _ExplorerDragRecognizer()..onStart = onStart;
}

class _ExplorerDragRecognizer extends ImmediateMultiDragGestureRecognizer {
  final _held = _HeldPointerFactory();
  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      event.kind == PointerDeviceKind.mouse
      ? super.createNewPointerState(event)
      : _held.forEvent(event, gestureSettings);
  @override
  void dispose() {
    super.dispose();
    _held.dispose();
  }
}

/// Reuses Flutter's delayed pointer state, including movement rejection, gesture
/// slop and timer cleanup. The owning recognizer routes all pointer events.
class _HeldPointerFactory extends DelayedMultiDragGestureRecognizer {
  MultiDragPointerState forEvent(
    PointerDownEvent event,
    DeviceGestureSettings? settings,
  ) {
    gestureSettings = settings;
    return super.createNewPointerState(event);
  }
}
