/// Bounded splice history shared by Source/Rich/structural commands. No persisted
/// alternate format, and changing modes is not a content operation.
class DocumentEdit {
  const DocumentEdit(
    this.offset,
    this.before,
    this.after, {
    this.beforeSelection,
    this.afterSelection,
  });
  final int offset;
  final String before, after;
  final (int, int)? beforeSelection, afterSelection;
}

class DocumentHistory {
  final _undo = <DocumentEdit>[], _redo = <DocumentEdit>[];
  // One shared immutable current-source reference, not one full copy per edit.
  String? _expectedCurrent;
  (int, int)? lastSelection;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get retainedCharacters => [
    ..._undo,
    ..._redo,
  ].fold(0, (n, e) => n + e.before.length + e.after.length);
  void record(
    String before,
    String after, {
    (int, int)? beforeSelection,
    (int, int)? afterSelection,
  }) {
    if (_expectedCurrent != null && _expectedCurrent != before) clear();
    if (before == after) return;
    var start = 0, end = before.length, nextEnd = after.length;
    while (start < end && start < nextEnd && before[start] == after[start]) {
      start++;
    }
    while (end > start &&
        nextEnd > start &&
        before[end - 1] == after[nextEnd - 1]) {
      end--;
      nextEnd--;
    }
    _undo.add(
      DocumentEdit(
        start,
        before.substring(start, end),
        after.substring(start, nextEnd),
        beforeSelection: beforeSelection,
        afterSelection: afterSelection,
      ),
    );
    _redo.clear();
    _expectedCurrent = after;
    lastSelection = null;
    while (_undo.length > 200 ||
        (_undo.length > 1 && retainedCharacters > 4 * 1024 * 1024)) {
      _undo.removeAt(0);
    }
  }

  String undo(String current) {
    if (!canUndo) return current;
    if (!_canReplay(current, _undo.last, undo: true)) return current;
    final e = _undo.removeLast();
    _redo.add(e);
    lastSelection = e.beforeSelection;
    return _expectedCurrent = current.replaceRange(
      e.offset,
      e.offset + e.after.length,
      e.before,
    );
  }

  String redo(String current) {
    if (!canRedo) return current;
    if (!_canReplay(current, _redo.last, undo: false)) return current;
    final e = _redo.removeLast();
    _undo.add(e);
    lastSelection = e.afterSelection;
    return _expectedCurrent = current.replaceRange(
      e.offset,
      e.offset + e.before.length,
      e.after,
    );
  }

  bool _canReplay(String current, DocumentEdit edit, {required bool undo}) {
    final expected = undo ? edit.after : edit.before;
    if (_expectedCurrent != current ||
        edit.offset < 0 ||
        edit.offset + expected.length > current.length ||
        !current.startsWith(expected, edit.offset)) {
      clear();
      return false;
    }
    return true;
  }

  void clear() {
    _undo.clear();
    _redo.clear();
    _expectedCurrent = null;
    lastSelection = null;
  }
}
