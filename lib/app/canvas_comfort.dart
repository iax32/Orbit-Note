/// Device-local drawing chrome. Unknown options survive edits and older builds.
class CanvasComfort {
  const CanvasComfort(this.data);
  final Map<String, dynamic> data;
  bool get largeControls => data['largeControls'] == true;
  bool get softGrid => data['softGrid'] == true;
  bool get locked => data['locked'] == true;
  double get touchSize => largeControls ? 56 : 48;
  double coordinate(String key, double fallback) {
    final value = data[key];
    return value is num && value.isFinite
        ? value.toDouble().clamp(0, 1)
        : fallback;
  }

  double get x => coordinate('x', 1);
  double get y => coordinate('y', 0);
  Map<String, dynamic> withValues(Map<String, dynamic> values) => {
    ...data,
    ...values,
  };
  Map<String, dynamic> get reset => {
    ...data,
    'largeControls': false,
    'softGrid': false,
    'x': 1.0,
    'y': 0.0,
    'locked': false,
  };
}
