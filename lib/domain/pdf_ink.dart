import '../canvas/scene.dart';
import 'universal_object.dart';
import 'json_values.dart';

/// Editable, source-bound vectors. Coordinates use the displayed PDF page's
/// units (including its intrinsic rotation), never screen pixels.
class PdfInkDocument {
  PdfInkDocument._(this.data, this.checksum, this.editable, this.elements);
  static final _documents = Expando<PdfInkDocument>();
  static final _strokes = Expando<CanvasElement>();
  static const maxStrokes = 20000,
      maxSamples = 100000,
      maxTotalSamples = 2000000;
  final Map<String, dynamic> data;
  final String checksum;
  final bool editable;
  final List<CanvasElement> elements;
  late final Map<int, List<CanvasElement>> pages = _pages();
  late final int sampleCount = elements.fold(
    0,
    (n, e) => n + (e.data['points'] as List).length,
  );

  factory PdfInkDocument.read(Object? raw, String checksum) {
    if (raw == null) {
      return PdfInkDocument._(
        const {},
        checksum,
        checksum.isNotEmpty,
        const [],
      );
    }
    if (raw is! Map<String, dynamic>) {
      return PdfInkDocument._(const {}, checksum, false, const []);
    }
    // A caller-owned unmodifiable view can still alias mutable samples.
    // Repository snapshots are already owned; detach other inputs once.
    if (!isImmutableObjectData(raw)) raw = immutableObjectData(raw);
    final cached = _documents[raw];
    if (cached != null && cached.checksum == checksum) return cached;
    final items = raw['elements'];
    var valid =
        raw['version'] == 1 &&
        raw['checksum'] == checksum &&
        checksum.isNotEmpty &&
        items is List &&
        items.length <= maxStrokes;
    final elements = <CanvasElement>[];
    final ids = <String>{};
    var count = 0;
    if (valid) {
      for (final item in items) {
        final stroke = validateStroke(item);
        if (stroke == null || !ids.add(stroke.id)) {
          valid = false;
          break;
        }
        count += (stroke.data['points'] as List).length;
        if (count > maxTotalSamples) {
          valid = false;
          break;
        }
        elements.add(stroke);
      }
    }
    // Never silently export/edit a partial interpretation of future/bad data.
    final result = PdfInkDocument._(
      raw,
      checksum,
      valid,
      List.unmodifiable(valid ? elements : <CanvasElement>[]),
    );
    if (isImmutableObjectData(raw)) _documents[raw] = result;
    return result;
  }

  Map<int, List<CanvasElement>> _pages() {
    final result = <int, List<CanvasElement>>{};
    for (final element in elements) {
      (result[element.data['page'] as int] ??= []).add(element);
    }
    return result;
  }

  static CanvasElement? validateStroke(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final cached = _strokes[raw];
    if (cached != null) return cached;
    bool number(Object? n, double min, double max) =>
        n is num && n.isFinite && n >= min && n <= max;
    final points = raw['points'];
    if (raw['id'] is! String ||
        (raw['id'] as String).isEmpty ||
        (raw['id'] as String).length > 200 ||
        raw['type'] != 'ink' ||
        raw['page'] is! int ||
        !number(raw['page'], 1, 1000000) ||
        !number(raw['pageWidth'], .1, 1000000) ||
        !number(raw['pageHeight'], .1, 1000000) ||
        !number(raw['x'], 0, (raw['pageWidth'] as num).toDouble()) ||
        !number(raw['y'], 0, (raw['pageHeight'] as num).toDouble()) ||
        !number(raw['width'], 0, 1000000) ||
        !number(raw['height'], 0, 1000000) ||
        !number(raw['strokeWidth'], .1, 100) ||
        raw['color'] is! int ||
        !const ['ballpoint', 'highlighter'].contains(raw['penStyle']) ||
        (raw['isHighlighter'] != (raw['penStyle'] == 'highlighter')) ||
        points is! List ||
        points.isEmpty ||
        points.length > maxSamples) {
      return null;
    }
    final x = (raw['x'] as num).toDouble(), y = (raw['y'] as num).toDouble();
    final width = (raw['pageWidth'] as num).toDouble();
    final height = (raw['pageHeight'] as num).toDouble();
    for (final p in points) {
      if (p is! Map ||
          !number(p['x'], 0, width - x + .001) ||
          !number(p['y'], 0, height - y + .001) ||
          !number(p['pressure'], 0, 1) ||
          !number(p['timeMs'], 0, 1000000000000)) {
        return null;
      }
      if ((p['x'] as num) > (raw['width'] as num) + .001 ||
          (p['y'] as num) > (raw['height'] as num) + .001) {
        return null;
      }
    }
    final element = CanvasElement(raw);
    if (isImmutableObjectData(raw)) _strokes[raw] = element;
    return element;
  }

  /// Apply only touched IDs to the latest document. Disjoint edits survive;
  /// removal/undo never overwrites a newer version of the same stroke.
  Map<String, dynamic>? apply(PdfInkDelta delta) {
    if (!editable || delta.isEmpty) return null;
    final byId = {for (final e in elements) e.id: e};
    final touched = <String>{};
    for (final e in delta.remove) {
      final current = byId[e.id];
      if (!touched.add(e.id) ||
          current == null ||
          !jsonValuesEqual(current.data, e.data)) {
        return null;
      }
      byId.remove(e.id);
    }
    final added = <String>{};
    for (final e in delta.add) {
      if (!added.add(e.id) ||
          byId.containsKey(e.id) ||
          validateStroke(e.data) == null) {
        return null;
      }
      byId[e.id] = e;
    }
    final insertions = <String, List<CanvasElement>>{};
    for (final entry in delta.insertBefore.entries) {
      if (!added.contains(entry.key) ||
          added.contains(entry.value) ||
          !byId.containsKey(entry.value)) {
        return null;
      }
    }
    for (final e in delta.add) {
      final anchor = delta.insertBefore[e.id];
      if (anchor != null) (insertions[anchor] ??= []).add(e);
    }
    final ordered = <CanvasElement>[];
    for (final e in byId.values) {
      ordered.addAll(insertions[e.id] ?? const []);
      if (!delta.insertBefore.containsKey(e.id)) ordered.add(e);
    }
    if (byId.length > maxStrokes) return null;
    final count =
        sampleCount -
        delta.remove.fold(0, (n, e) => n + (e.data['points'] as List).length) +
        delta.add.fold(0, (n, e) => n + (e.data['points'] as List).length);
    if (count > maxTotalSamples) return null;
    return immutableObjectData({
      ...data,
      'version': 1,
      'checksum': checksum,
      'elements': [for (final e in ordered) e.data],
    });
  }
}

class PdfInkDelta {
  const PdfInkDelta({
    this.add = const [],
    this.remove = const [],
    this.insertBefore = const {},
  });
  final List<CanvasElement> add, remove;
  final Map<String, String> insertBefore;
  bool get isEmpty => add.isEmpty && remove.isEmpty;
}
