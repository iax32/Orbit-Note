import 'dart:math' as math;

import 'connectors.dart';
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
  'connector',
  'ink',
  'frame',
  'column',
  'link',
  'section',
  'swatch',
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
  String? get startId =>
      data['startId'] is String ? data['startId'] as String : null;
  String? get endId => data['endId'] is String ? data['endId'] as String : null;
  String get strokeStyle =>
      data['strokeStyle'] is String ? data['strokeStyle'] as String : 'solid';
  String get startMarker =>
      data['startMarker'] is String ? data['startMarker'] as String : 'none';
  String get endMarker => data['endMarker'] is String
      ? data['endMarker'] as String
      : (type == 'arrow' || type == 'connector' ? 'arrow' : 'none');
  String get routing =>
      data['routing'] is String ? data['routing'] as String : 'straight';
  String get startAnchor =>
      data['startAnchor'] is String ? data['startAnchor'] as String : 'auto';
  String get endAnchor =>
      data['endAnchor'] is String ? data['endAnchor'] as String : 'auto';
  String? get groupId =>
      data['groupId'] is String && (data['groupId'] as String).isNotEmpty
      ? data['groupId'] as String
      : null;
  bool get hasEndpoints =>
      isConnectorElement(this) &&
      [
        data['startX'],
        data['startY'],
        data['endX'],
        data['endY'],
      ].every((v) => v is num && v.isFinite);
  double get x => hasEndpoints
      ? math.min(finiteNumber(data['startX'], 0), finiteNumber(data['endX'], 0))
      : finiteNumber(data['x'], 0);
  double get y => hasEndpoints
      ? math.min(finiteNumber(data['startY'], 0), finiteNumber(data['endY'], 0))
      : finiteNumber(data['y'], 0);
  double get width => hasEndpoints
      ? (finiteNumber(data['endX'], 0) - finiteNumber(data['startX'], 0)).abs()
      : finiteNumber(data['width'], 200).clamp(0, 1000000);
  double get height => hasEndpoints
      ? (finiteNumber(data['endY'], 0) - finiteNumber(data['startY'], 0)).abs()
      : finiteNumber(data['height'], 120).clamp(0, 1000000);
  bool get locked => data['locked'] == true;
  bool get hidden => data['hidden'] == true;
  int get color => data['color'] is int ? data['color'] as int : 0xff8b7cf6;
  double get strokeWidth => finiteNumber(data['strokeWidth'], 3).clamp(.1, 100);
  bool get renderable =>
      id.isNotEmpty &&
      canvasElementTypes.contains(type) &&
      (hasEndpoints ||
          type == 'connector' ||
          ([data['x'], data['y']].every((v) => v is num && v.isFinite) &&
              [
                data['width'],
                data['height'],
              ].every((v) => v == null || v is num && v.isFinite && v >= 0)));
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

  CanvasElement copy(Map<String, dynamic> patch) {
    if (isConnectorElement(this) &&
        !patch.keys.any(
          (k) => const {'startX', 'startY', 'endX', 'endY'}.contains(k),
        ) &&
        patch.keys.any(
          (k) => const {'x', 'y', 'width', 'height'}.contains(k),
        )) {
      final nx = finiteNumber(patch['x'], x), ny = finiteNumber(patch['y'], y);
      final sx = width == 0 ? 1.0 : finiteNumber(patch['width'], width) / width;
      final sy = height == 0
          ? 1.0
          : finiteNumber(patch['height'], height) / height;
      CanvasPoint transform(CanvasPoint point) =>
          CanvasPoint(nx + (point.x - x) * sx, ny + (point.y - y) * sy);
      return CanvasElement({
        ...data,
        ...patch,
        ...connectorEndpointData(
          transform(storedConnectorStart(this)),
          transform(storedConnectorEnd(this)),
        ),
      });
    }
    return CanvasElement({...data, ...patch});
  }

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
    if (type == 'ink' ||
        type == 'arrow' ||
        type == 'line' ||
        type == 'connector') {
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
        if (distanceToSegment(local, samples[i - 1], samples[i]) <=
            tolerance + strokeWidth / 2) {
          return true;
        }
      }
      return false;
    }
    return true;
  }
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
          } else {
            _opaque.add(raw);
          }
        } else {
          _opaque.add(raw);
        }
      }
      for (final element in _elements.values) {
        if (element.renderable && !element.hidden) {
          index.put(
            element.id,
            _effectiveBounds(element).inflate(element.strokeWidth),
          );
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

  CanvasBounds _effectiveBounds(CanvasElement element) {
    if ((element.type == 'connector' ||
            element.type == 'arrow' ||
            element.type == 'line') &&
        (element.startId != null || element.endId != null)) {
      final startElem = element.startId != null
          ? _elements[element.startId]
          : null;
      final endElem = element.endId != null ? _elements[element.endId] : null;
      if (startElem != null && endElem != null) {
        return resolveConnectorEndpoints(element, this).bounds.inflate(16);
      } else if (startElem != null) {
        return startElem.bounds.union(element.bounds).inflate(16);
      } else if (endElem != null) {
        return endElem.bounds.union(element.bounds).inflate(16);
      }
    }
    return element.bounds;
  }

  List<CanvasElement> query(CanvasBounds bounds) {
    final result = index.query(bounds).map((id) => _elements[id]!).toList();
    result.sort((a, b) => _order[a.id]!.compareTo(_order[b.id]!));
    return result;
  }

  CanvasElement? hit(
    CanvasPoint point, {
    double tolerance = 5,
    bool includeLocked = false,
  }) {
    for (final element in query(
      CanvasBounds(point.x, point.y, 0, 0).inflate(tolerance),
    ).reversed) {
      if ((includeLocked || !element.locked) &&
          _elementHit(element, point, tolerance: tolerance)) {
        return element;
      }
    }
    return null;
  }

  bool _elementHit(
    CanvasElement element,
    CanvasPoint point, {
    double tolerance = 5,
  }) {
    if (element.type == 'connector' ||
        element.type == 'arrow' ||
        element.type == 'line') {
      return hitTestConnector(element, this, point, tolerance: tolerance);
    }
    return element.hit(point, tolerance: tolerance);
  }

  void put(CanvasElement element) {
    if (readOnly || !element.renderable) return;
    revision++;
    _order.putIfAbsent(element.id, () => _nextOrder++);
    _elements[element.id] = element;
    index.remove(element.id);
    if (!element.hidden) {
      index.put(
        element.id,
        _effectiveBounds(element).inflate(element.strokeWidth),
      );
    }
    // Update spatial index for any connectors attached to this element
    for (final conn in _elements.values) {
      if ((conn.type == 'connector' ||
              conn.type == 'arrow' ||
              conn.type == 'line') &&
          (conn.startId == element.id || conn.endId == element.id) &&
          !conn.hidden) {
        index.remove(conn.id);
        index.put(conn.id, _effectiveBounds(conn).inflate(conn.strokeWidth));
      }
    }
  }

  void remove(String id) {
    if (readOnly) return;
    revision++;
    _elements.remove(id);
    _order.remove(id);
    index.remove(id);
    for (final conn in _elements.values) {
      if ((conn.type == 'connector' ||
              conn.type == 'arrow' ||
              conn.type == 'line') &&
          (conn.startId == id || conn.endId == id) &&
          !conn.hidden) {
        index.remove(conn.id);
        index.put(conn.id, _effectiveBounds(conn).inflate(conn.strokeWidth));
      }
    }
  }

  CanvasBounds? get contentBounds {
    CanvasBounds? result;
    for (final element in elements.where((e) => e.renderable && !e.hidden)) {
      final eb = _effectiveBounds(element);
      result = result?.union(eb) ?? eb;
    }
    return result;
  }

  int? orderOf(String id) => _order[id];

  List<CanvasElement> get elementsInOrder {
    final list = _elements.values.toList();
    list.sort((a, b) => _order[a.id]!.compareTo(_order[b.id]!));
    return list;
  }

  void bringToFront(String id) {
    if (readOnly || !_elements.containsKey(id)) return;
    revision++;
    _order[id] = ++_nextOrder;
  }

  void sendToBack(String id) {
    if (readOnly || !_elements.containsKey(id)) return;
    revision++;
    final minOrder = _order.values.fold<int>(0, math.min);
    _order[id] = minOrder - 1;
  }

  void bringForward(String id) {
    if (readOnly || !_elements.containsKey(id)) return;
    final currentOrder = _order[id]!;
    String? nextId;
    int? nextOrder;
    for (final entry in _order.entries) {
      if (entry.key != id && entry.value > currentOrder) {
        if (nextOrder == null || entry.value < nextOrder) {
          nextOrder = entry.value;
          nextId = entry.key;
        }
      }
    }
    if (nextId != null && nextOrder != null) {
      revision++;
      _order[id] = nextOrder;
      _order[nextId] = currentOrder;
    }
  }

  void sendBackward(String id) {
    if (readOnly || !_elements.containsKey(id)) return;
    final currentOrder = _order[id]!;
    String? prevId;
    int? prevOrder;
    for (final entry in _order.entries) {
      if (entry.key != id && entry.value < currentOrder) {
        if (prevOrder == null || entry.value > prevOrder) {
          prevOrder = entry.value;
          prevId = entry.key;
        }
      }
    }
    if (prevId != null && prevOrder != null) {
      revision++;
      _order[id] = prevOrder;
      _order[prevId] = currentOrder;
    }
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

  void reorder(Iterable<String> ids, void Function() mutate) {
    if (scene.readOnly) return;
    begin();
    for (final id in ids) {
      _before!.putIfAbsent(id, () => _state(id));
    }
    for (final id in scene._elements.keys) {
      _before!.putIfAbsent(id, () => _state(id));
    }
    mutate();
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
