import 'scene.dart';

/// Replays stored placement order, not invented drawing timestamps. The scene
/// and every unknown field remain untouched. Only the active stroke is sliced.
class CanvasPresentation {
  CanvasPresentation(Iterable<CanvasElement> elements)
    : ids = List.unmodifiable(
        elements.where((e) => !e.hidden && e.renderable).map((e) => e.id),
      );
  final List<String> ids;
  double progressFor(String id, double position) {
    final i = ids.indexOf(id);
    if (i < 0) return 1;
    return ((position.isFinite ? position.clamp(0.0, 1.0) : 1.0) * ids.length -
            i)
        .clamp(0.0, 1.0);
  }

  Map<String, double> at(double position) => {
    for (var i = 0; i < ids.length; i++)
      ids[i]:
          ((position.isFinite ? position.clamp(0.0, 1.0) : 1.0) * ids.length -
                  i)
              .clamp(0.0, 1.0),
  };
}

CanvasElement revealCanvasInk(CanvasElement element, double progress) {
  final raw = element.data['points'];
  if (element.type != 'ink' ||
      raw is! List ||
      raw.isEmpty ||
      !progress.isFinite ||
      progress >= 1) {
    return element;
  }
  final cursor = (raw.length - 1) * progress.clamp(0.0, 1.0);
  final end = cursor.floor(), fraction = cursor - cursor.floor();
  final shown = <dynamic>[...raw.take(end + 1)];
  // Interpolate only the moving tip, using the existing pressure-aware painter.
  // Sparse authored samples should not make presentation jump in large steps.
  if (fraction > 0 &&
      end + 1 < raw.length &&
      raw[end] is Map &&
      raw[end + 1] is Map) {
    final a = raw[end] as Map, b = raw[end + 1] as Map;
    final tip = Map<dynamic, dynamic>.of(b);
    for (final key in ['x', 'y', 'pressure']) {
      final from = a[key], to = b[key];
      if (from is num && from.isFinite && to is num && to.isFinite) {
        tip[key] = from + (to - from) * fraction;
      }
    }
    shown.add(tip);
  }
  return CanvasElement({...element.data, 'points': shown});
}
