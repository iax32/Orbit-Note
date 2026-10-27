import 'dart:convert';

import '../domain/object_reference.dart';
import '../domain/note_composition.dart';
import 'connectors.dart';
import 'scene.dart';
import 'uml.dart';

/// Explicit selection by placement identity; relationships remain live between
/// these nodes. Unrelated board content is never included as a fallback.
List<String>? diagramElementIds(ObjectReference reference) {
  if (reference.anchorType != 'elements') return null;
  try {
    final value = jsonDecode(reference.anchorId ?? '');
    if (value is! List ||
        value.isEmpty ||
        value.length > 1000 ||
        value.any((e) => e is! String || e.isEmpty || e.length > 200) ||
        value.toSet().length != value.length) {
      return null;
    }
    return List<String>.unmodifiable(value.cast<String>());
  } on FormatException {
    return null;
  }
}

ObjectReference diagramReference(String canvasId, Iterable<String> ids) {
  final ref = ObjectReference(
    canvasId,
    anchorType: 'elements',
    anchorId: jsonEncode(ids.toSet().toList()),
  );
  if (diagramElementIds(ref) == null) {
    throw const FormatException('Choose between 1 and 1,000 diagram items.');
  }
  return ref;
}

List<String> umlExportSelection(CanvasScene scene, Iterable<String> selection) {
  final selected = selection.toSet();
  final result = <String>{};
  for (final e in scene.elementsInOrder) {
    if (e.hidden || !e.renderable) continue;
    if (isUmlClass(e) && (selected.isEmpty || selected.contains(e.id))) {
      result.add(e.id);
    }
    if (selected.contains(e.id) && isConnectorElement(e)) {
      for (final id in [e.startId, e.endId]) {
        final node = id == null ? null : scene[id];
        if (node != null && isUmlClass(node) && !node.hidden) {
          result.add(node.id);
        }
      }
    }
  }
  return List.unmodifiable(result);
}

/// General technical diagrams retain the same explicit placement references.
/// Object cards and attachments require their own live-object blocks.
List<String> diagramExportSelection(
  CanvasScene scene,
  Iterable<String> selection,
) {
  final selected = selection.toSet(), result = <String>{};
  bool node(CanvasElement e) =>
      !e.hidden &&
      e.renderable &&
      (!isConnectorElement(e) || e.startId == null && e.endId == null) &&
      [
        'rectangle',
        'ellipse',
        'diamond',
        'text',
        'line',
        'arrow',
        'connector',
        'ink',
        'frame',
        'section',
      ].contains(e.type);
  for (final e in scene.elementsInOrder) {
    if (node(e) && (selected.isEmpty || selected.contains(e.id))) {
      result.add(e.id);
    }
    if (selected.contains(e.id) && isConnectorElement(e)) {
      for (final target in [e.startId, e.endId]) {
        final e = target == null ? null : scene[target];
        if (e != null && node(e)) result.add(e.id);
      }
    }
  }
  return List.unmodifiable(result);
}

String diagramMarkdown(
  String canvasId,
  String label,
  Iterable<String> ids, {
  String eol = '\n',
}) {
  final reference = diagramReference(canvasId, ids);
  return NoteObjectBlock(
    canvasId,
    label,
    fragment: reference.fragment,
  ).encode(eol: eol);
}

class ResolvedCanvasDiagram {
  ResolvedCanvasDiagram(CanvasScene source, List<String> ids) {
    final selected = ids.toSet();
    final nodes = source.elementsInOrder
        .where((e) => selected.contains(e.id) && !e.hidden && e.renderable)
        .toList();
    final present = nodes.map((e) => e.id).toSet();
    unavailable = ids.where((id) => !present.contains(id)).length;
    scene = CanvasScene.fromJson({
      'schemaVersion': 1,
      'elements': [
        for (final e in nodes) e.data,
        for (final e in source.elementsInOrder)
          if (!present.contains(e.id) &&
              !e.hidden &&
              e.renderable &&
              isConnectorElement(e) &&
              present.contains(e.startId) &&
              present.contains(e.endId))
            e.data,
      ],
    });
  }
  late final CanvasScene scene;
  late final int unavailable;
}
