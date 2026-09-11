import 'dart:math' as math;

import 'geometry.dart';

const canvasElementTypes = {
  'card',
  'image',
  'text',
  'sticky',
  'rectangle',
  'ellipse',
  'diamond',
  'arrow',
  'line',
  'ink',
  'frame',
  'column',
  'link',
};

class CanvasElement {
  CanvasElement(Map<String, dynamic> data) : data = Map.unmodifiable(data);
  final Map<String, dynamic> data;
  String get id => data['id'] is String ? data['id'] as String : '';
  String get type => data['type'] is String ? data['type'] as String : '';
  String get text => data['text'] is String ? data['text'] as String : '';
  String get url => data['url'] is String ? data['url'] as String : '';
  String? get objectId =>
      data['objectId'] is String ? data['objectId'] as String : null;
  double get x => finiteNumber(data['x'], 0);
  double get y => finiteNumber(data['y'], 0);
  double get width => finiteNumber(data['width'], 200).clamp(0, 1000000);
  double get height => finiteNumber(data['height'], 120).clamp(0, 1000000);
  bool get locked => data['locked'] == true;
  bool get hidden => data['hidden'] == true;
  int get color => data['color'] is int ? data['color'] as int : 0xff8b7cf6;
  double get strokeWidth => finiteNumber(data['strokeWidth'], 3).clamp(.1, 100);
  bool get renderable =>
      id.isNotEmpty &&
      canvasElementTypes.contains(type) &&
      [data['x'], data['y']].every((v) => v is num && v.isFinite) &&
      [
        data['width'],
        data['height'],
      ].every((v) => v == null || v is num && v.isFinite && v >= 0);
  CanvasBounds get bounds => CanvasBounds(x, y, width, height);
  late final List<CanvasPoint> points = data['points'] is List
      ? (data['points'] as List)
            .whereType<Map>()
            .map(
              (p) =>
                  CanvasPoint(finiteNumber(p['x'], 0), finiteNumber(p['y'], 0)),
            )
            .toList()
      : const [];

  CanvasElement copy(Map<String, dynamic> patch) =>
      CanvasElement({...data, ...patch});
  CanvasElement translated(CanvasPoint delta) =>
      copy({'x': x + delta.x, 'y': y + delta.y});

  bool hit(CanvasPoint point, {double tolerance = 5}) {
    if (!bounds.inflate(tolerance).contains(point)) return false;
    final local = point - CanvasPoint(x, y);
    if (type == 'column') {
      return local.y <= 44;
    }
    if (type == 'ellipse') {
      final rx = math.max(width / 2, 1), ry = math.max(height / 2, 1);
      return math.pow((local.x - rx) / (rx + tolerance), 2) +
              math.pow((local.y - ry) / (ry + tolerance), 2) <=
          1;
    }
    if (type == 'ink' || type == 'arrow' || type == 'line') {
      final samples = type == 'ink'
          ? points
          : [
              CanvasPoint(
                data['reverseX'] == true ? width : 0,
                data['reverseY'] == true ? height : 0,
              ),
              CanvasPoint(
                data['reverseX'] == true ? 0 : width,
                data['reverseY'] == true ? 0 : height,
              ),
            ];
      if (samples.length == 1) {
        return (samples.first - local).length <= tolerance + strokeWidth;
      }
      for (var i = 1; i < samples.length; i++) {
        if (_distanceToSegment(local, samples[i - 1], samples[i]) <=
            tolerance + strokeWidth / 2) {
          return true;
        }
      }
      return false;
    }
    return true;
  }
}

double _distanceToSegment(CanvasPoint p, CanvasPoint a, CanvasPoint b) {
  final ab = b - a;
  final lengthSquared = ab.x * ab.x + ab.y * ab.y;
  if (lengthSquared == 0) return (p - a).length;
  final ap = p - a;
  final t = ((ap.x * ab.x + ap.y * ab.y) / lengthSquared)
      .clamp(0, 1)
      .toDouble();
  return (p - (a + ab * t)).length;
}

/// Unknown root and element fields survive edits. Future schemas are read-only.
class CanvasScene {
  CanvasScene.fromJson(Map<String, dynamic> value) : _root = Map.of(value) {
    final items = value['elements'];
    if (items is List) {
      _nextOrder = items.length;
      for (var i = 0; i < items.length; i++) {
        final raw = items[i];
        if (raw is Map && raw.keys.every((key) => key is String)) {
          final element = CanvasElement(Map<String, dynamic>.from(raw));
          if (element.id.isNotEmpty && !_elements.containsKey(element.id)) {
            _elements[element.id] = element;
            _order[element.id] = i;
            if (element.renderable && !element.hidden) {
              index.put(
                element.id,
                element.bounds.inflate(element.strokeWidth),
              );
            }
          } else {
            _opaque.add(raw);
          }
        } else {
          _opaque.add(raw);
        }
      }
    }
  }

  final Map<String, dynamic> _root;
  final Map<String, CanvasElement> _elements = {};
  final Map<String, int> _order = {};
  int _nextOrder = 0;
  int revision = 0;
  final List<dynamic> _opaque = [];
  final CanvasSpatialIndex index = CanvasSpatialIndex();
  bool get readOnly =>
      (_root['schemaVersion'] != null && _root['schemaVersion'] != 1) ||
      (_root['elements'] != null && _root['elements'] is! List);
  Iterable<CanvasElement> get elements => _elements.values;
  CanvasElement? operator [](String id) => _elements[id];
  int get length => _elements.length;

  List<CanvasElement> query(CanvasBounds bounds) {
    final result = index.query(bounds).map((id) => _elements[id]!).toList();
    result.sort((a, b) => _order[a.id]!.compareTo(_order[b.id]!));
    return result;
  }

  CanvasElement? hit(CanvasPoint point, {double tolerance = 5}) {
    for (final element in query(
      CanvasBounds(point.x, point.y, 0, 0).inflate(tolerance),
    ).reversed) {
      if (!element.locked && element.hit(point, tolerance: tolerance)) {
        return element;
      }
    }
    return null;
  }

  void put(CanvasElement element) {
    if (readOnly || !element.renderable) return;
    revision++;
    _order.putIfAbsent(element.id, () => _nextOrder++);
    _elements[element.id] = element;
    index.remove(element.id);
    if (!element.hidden) {
      index.put(element.id, element.bounds.inflate(element.strokeWidth));
    }
  }

  void remove(String id) {
    if (readOnly) return;
    revision++;
    _elements.remove(id);
    _order.remove(id);
    index.remove(id);
  }

  CanvasBounds? get contentBounds {
    CanvasBounds? result;
    for (final element in elements.where((e) => e.renderable && !e.hidden)) {
      result = result?.union(element.bounds) ?? element.bounds;
    }
    return result;
  }

  Map<String, dynamic> toJson() => readOnly
      ? Map.of(_root)
      : {
          ..._root,
          'schemaVersion': 1,
          'elements': [
            ...(_elements.values.toList()
                  ..sort((a, b) => _order[a.id]!.compareTo(_order[b.id]!)))
                .map((e) => Map<String, dynamic>.of(e.data)),
            ..._opaque,
          ],
        };
}

typedef _ElementState = ({CanvasElement? element, int? order});
typedef _SceneDelta = ({
  Map<String, _ElementState> before,
  Map<String, _ElementState> after,
});

/// Coalesces touched elements into one reversible delta per gesture. Unrelated
/// elements, spatial index entries and opaque data are never copied for undo.
class CanvasHistory {
  CanvasHistory(this.scene);
  final CanvasScene scene;
  final List<_SceneDelta> _undo = [];
  final List<_SceneDelta> _redo = [];
  Map<String, _ElementState>? _before;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get inCommand => _before != null;
  int get retainedElementStates => [
    ..._undo,
    ..._redo,
  ].fold(0, (sum, delta) => sum + delta.before.length + delta.after.length);

  _ElementState _state(String id) =>
      (element: scene[id], order: scene._order[id]);
  void begin() {
    if (_before != null || scene.readOnly) return;
    _before = {};
  }

  void put(CanvasElement element) {
    if (scene.readOnly || !element.renderable) return;
    begin();
    _before!.putIfAbsent(element.id, () => _state(element.id));
    scene.put(element);
  }

  void remove(String id) {
    if (scene.readOnly || scene[id] == null) return;
    begin();
    _before!.putIfAbsent(id, () => _state(id));
    scene.remove(id);
  }

  bool commit() {
    final before = _before;
    _before = null;
    if (before == null || before.isEmpty) return false;
    _undo.add((
      before: before,
      after: {for (final id in before.keys) id: _state(id)},
    ));
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
    return true;
  }

  void _apply(Map<String, _ElementState> states) {
    for (final entry in states.entries) {
      final element = entry.value.element;
      if (element == null) {
        scene.remove(entry.key);
      } else {
        scene.put(element);
        if (entry.value.order != null) {
          scene._order[entry.key] = entry.value.order!;
        }
      }
    }
  }

  void cancel() {
    final before = _before;
    _before = null;
    if (before != null) _apply(before);
  }

  bool undo() {
    cancel();
    if (_undo.isEmpty) return false;
    final delta = _undo.removeLast();
    _apply(delta.before);
    _redo.add(delta);
    return true;
  }

  bool redo() {
    cancel();
    if (_redo.isEmpty) return false;
    final delta = _redo.removeLast();
    _apply(delta.after);
    _undo.add(delta);
    return true;
  }
}
