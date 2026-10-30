import 'package:flutter/foundation.dart';
import '../../canvas/scene.dart';
import '../../canvas/geometry.dart';
import '../../domain/pdf_ink.dart';
import '../../domain/json_values.dart';

enum PdfInkTool { pen, highlighter, eraser }

/// Gesture-sized shared-engine history; persisted commands touch stroke IDs,
/// not a stale copy of the PDF object or another pane's drawings.
class PdfInkSession extends ChangeNotifier {
  PdfInkSession(Object? data, String checksum, this.save, this.readOnly)
    : document = PdfInkDocument.read(data, checksum) {
    history = CanvasHistory(
      CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [for (final e in document.elements) e.data],
      }),
    );
  }
  PdfInkDocument document;
  late CanvasHistory history;
  bool Function(PdfInkDelta)? save;
  bool readOnly;
  bool drawing = false, fingerDrawing = false;
  PdfInkTool tool = PdfInkTool.pen;
  int color = 0xff2563eb;
  double width = 2.5;
  bool get canEdit => !readOnly && save != null && document.editable;
  bool get canUndo => canEdit && history.canUndo;
  bool get canRedo => canEdit && history.canRedo;
  String? error;
  PdfInkDelta? rejected;
  String? _rejectedChecksum;
  final _pageScenes = <int, CanvasScene>{};
  Iterable<CanvasElement> get recoveryStrokes =>
      document.checksum == _rejectedChecksum
      ? rejected?.add ?? const []
      : const [];
  List<CanvasElement> query(int page, CanvasBounds bounds) {
    final scene =
        _pageScenes.remove(page) ??
        CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            for (final e in document.pages[page] ?? <CanvasElement>[]) e.data,
          ],
        });
    _pageScenes[page] = scene;
    while (_pageScenes.length > 16) {
      _pageScenes.remove(_pageScenes.keys.first);
    }
    // Highlighter width is at least 16 even when the nominal nib is smaller.
    return scene.query(bounds.inflate(32));
  }

  void _indexDelta(PdfInkDelta delta) {
    if (delta.insertBefore.isNotEmpty) {
      for (final e in delta.add) {
        _pageScenes.remove(e.data['page']);
      }
    }
    for (final e in delta.remove) {
      _pageScenes[e.data['page']]?.remove(e.id);
    }
    for (final e in delta.add) {
      _pageScenes[e.data['page']]?.put(e);
    }
  }

  int generation = 0;

  void configure(void Function() change) {
    change();
    generation++;
    notifyListeners();
  }

  void update(
    Object? data,
    String checksum,
    bool Function(PdfInkDelta)? callback,
    bool locked, {
    bool reset = false,
  }) {
    save = callback;
    final next = PdfInkDocument.read(data, checksum);
    if (!reset &&
        identical(next.data, document.data) &&
        next.checksum == document.checksum &&
        locked == readOnly) {
      return;
    }
    // Locally acknowledged edits have identical frozen stroke maps. Reuse the
    // history across parent rebuilds, source metadata saves and disjoint edits.
    final sameSource =
        !reset && next.checksum == document.checksum && next.editable;
    final nextById = {for (final e in next.elements) e.id: e};
    final conflicting =
        sameSource &&
        (next.elements.length < document.elements.length ||
            !listEquals(
              document.elements.map((e) => e.id).toList(),
              next.elements
                  .take(document.elements.length)
                  .map((e) => e.id)
                  .toList(),
            ) ||
            document.elements.any((e) {
              final current = nextById[e.id];
              return current == null ||
                  !identical(current.data, e.data) &&
                      !jsonValuesEqual(current.data, e.data);
            }));
    if (!sameSource || conflicting) {
      _pageScenes.clear();
    } else {
      for (final entry in _pageScenes.entries) {
        final scene = entry.value;
        for (final e in scene.elements.toList()) {
          if (nextById[e.id]?.data['page'] != entry.key) scene.remove(e.id);
        }
        for (final e in next.elements) {
          if (e.data['page'] == entry.key &&
              !identical(scene[e.id]?.data, e.data)) {
            scene.put(e);
          }
        }
      }
    }
    if (sameSource && !conflicting) {
      final ids = {for (final e in next.elements) e.id};
      for (final e in history.scene.elements.toList()) {
        if (!ids.contains(e.id)) history.scene.remove(e.id);
      }
      for (final e in next.elements) {
        final old = history.scene[e.id];
        if (old == null || !identical(old.data, e.data)) history.scene.put(e);
      }
    } else {
      history = CanvasHistory(
        CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [for (final e in next.elements) e.data],
        }),
      );
    }
    if (!sameSource || locked != readOnly) generation++;
    document = next;
    readOnly = locked;
    if (!canEdit) drawing = false;
    notifyListeners();
  }

  bool commit(PdfInkDelta delta) {
    if (!canEdit) return false;
    final next = document.apply(delta);
    if (next == null || save!(delta) != true) {
      rejected = delta;
      _rejectedChecksum = document.checksum;
      error = 'Drawing changed or could not be saved. Please retry.';
      notifyListeners();
      return false;
    }
    for (final e in delta.remove) {
      history.remove(e.id);
    }
    for (final e in delta.add) {
      history.put(e);
    }
    history.commit();
    _indexDelta(delta);
    document = PdfInkDocument.read(next, document.checksum);
    rejected = null;
    error = null;
    notifyListeners();
    return true;
  }

  void retry() {
    final delta = rejected;
    if (delta != null && document.checksum == _rejectedChecksum) commit(delta);
  }

  void discardRejected() {
    rejected = null;
    error = null;
    notifyListeners();
  }

  void undo() => _restore(false);
  void redo() => _restore(true);
  void _restore(bool redo) {
    if (!canEdit || (redo ? !canRedo : !canUndo)) return;
    final before = {for (final e in history.scene.elementsInOrder) e.id: e};
    if (!(redo ? history.redo() : history.undo())) return;
    final orderedAfter = history.scene.elementsInOrder;
    final after = {for (final e in orderedAfter) e.id: e};
    final additions = [
      for (final e in orderedAfter)
        if (before[e.id] == null ||
            !jsonValuesEqual(before[e.id]!.data, e.data))
          e,
    ];
    final addedIds = additions.map((e) => e.id).toSet();
    final positions = <String, String>{};
    String? anchor;
    for (final e in orderedAfter.reversed) {
      if (addedIds.contains(e.id)) {
        if (anchor != null) positions[e.id] = anchor;
      } else {
        anchor = e.id;
      }
    }
    final delta = PdfInkDelta(
      remove: [
        for (final e in before.values)
          if (after[e.id] == null ||
              !jsonValuesEqual(after[e.id]!.data, e.data))
            e,
      ],
      add: additions,
      insertBefore: positions,
    );
    final next = document.apply(delta);
    if (next == null || save!(delta) != true) {
      redo ? history.undo() : history.redo();
      error = 'This stroke changed in another pane. Undo was kept safely.';
    } else {
      document = PdfInkDocument.read(next, document.checksum);
      _indexDelta(delta);
      error = null;
    }
    generation++;
    notifyListeners();
  }
}
