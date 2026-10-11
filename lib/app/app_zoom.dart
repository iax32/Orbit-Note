import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const appZoomSteps = [.75, .9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0];

double nextAppZoom(double current, int direction) {
  final candidates = direction > 0
      ? appZoomSteps.where((v) => v > current + .001)
      : appZoomSteps.reversed.where((v) => v < current - .001);
  return candidates.isEmpty ? current : candidates.first;
}

/// Composes text zoom with OS accessibility scaling. Geometry uses OrbitDensity
/// tokens in the theme, preserving the actual viewport and native hit testing.
class AppZoom extends StatefulWidget {
  const AppZoom({
    super.key,
    required this.zoom,
    required this.onChanged,
    required this.child,
  });
  final double zoom;
  final ValueChanged<double> onChanged;
  final Widget child;

  @override
  State<AppZoom> createState() => _AppZoomState();
}

class _AppZoomState extends State<AppZoom> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_key);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_key);
    super.dispose();
  }

  KeyEventResult _key(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if ((event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        (!keyboard.isControlPressed && !keyboard.isMetaPressed) ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    double? value;
    if ([
      LogicalKeyboardKey.equal,
      LogicalKeyboardKey.add,
      LogicalKeyboardKey.numpadAdd,
    ].contains(key)) {
      value = nextAppZoom(widget.zoom, 1);
    } else if ([
      LogicalKeyboardKey.minus,
      LogicalKeyboardKey.numpadSubtract,
    ].contains(key)) {
      value = nextAppZoom(widget.zoom, -1);
    } else if ([
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.numpad0,
    ].contains(key)) {
      value = 1;
    }
    if (value == null) return KeyEventResult.ignored;
    if (value != widget.zoom) widget.onChanged(value);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final zoom = widget.zoom.isFinite ? widget.zoom.clamp(.75, 2.0) : 1.0;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: _ZoomTextScaler(media.textScaler, zoom)),
      child: widget.child,
    );
  }
}

class _ZoomTextScaler extends TextScaler {
  const _ZoomTextScaler(this.base, this.zoom);
  final TextScaler base;
  final double zoom;
  @override
  double scale(double fontSize) => base.scale(fontSize) * zoom;
  @override
  double get textScaleFactor => scale(14) / 14;
  @override
  bool operator ==(Object other) =>
      other is _ZoomTextScaler && other.base == base && other.zoom == zoom;
  @override
  int get hashCode => Object.hash(base, zoom);
}
