/// Structural comparison without allocating serialized copies of entire scenes.
bool jsonValuesEqual(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every(
          (key) => b.containsKey(key) && jsonValuesEqual(a[key], b[key]),
        );
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonValuesEqual(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// One comparison memo for immutable portable-object snapshots. Rewrapping an
/// authoritative frozen map for UI metadata must not rescan every ink sample.
/// Callers with mutable nested data should continue using jsonValuesEqual.
class ImmutableJsonEqualityCache {
  Map<String, dynamic>? _input, _target;
  bool _result = false;
  void clear() {
    _input = null;
    _target = null;
    _result = false;
  }

  bool matches(Map<String, dynamic> input, Map<String, dynamic> target) {
    if (identical(input, target)) return true;
    if (identical(_target, target) && _shallowSame(input, _input)) {
      return _result;
    }
    _result = jsonValuesEqual(input, target);
    _input = Map.unmodifiable(input);
    _target = target;
    return _result;
  }

  static bool _shallowSame(Map<String, dynamic> a, Map<String, dynamic>? b) {
    if (b == null || a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      final value = entry.value, other = b[entry.key];
      if (value is Map || value is List) {
        if (!identical(value, other)) return false;
      } else if (value != other) {
        return false;
      }
    }
    return true;
  }
}
