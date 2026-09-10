/// Bounded splice history shared by Source/Rich/structural commands. No persisted
/// alternate format, and changing modes is not a content operation.
class DocumentEdit {
  const DocumentEdit(this.offset, this.before, this.after);
  final int offset;
  final String before, after;
}

class DocumentHistory {
  final _undo = <DocumentEdit>[], _redo = <DocumentEdit>[];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get retainedCharacters => [
    ..._undo,
    ..._redo,
  ].fold(0, (n, e) => n + e.before.length + e.after.length);
  void record(String before, String after) {
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
      ),
    );
    _redo.clear();
    while (_undo.length > 200 ||
        (_undo.length > 1 && retainedCharacters > 4 * 1024 * 1024)) {
      _undo.removeAt(0);
    }
  }

  String undo(String current) {
    if (!canUndo) return current;
    final e = _undo.removeLast();
    _redo.add(e);
    return current.replaceRange(e.offset, e.offset + e.after.length, e.before);
  }

  String redo(String current) {
    if (!canRedo) return current;
    final e = _redo.removeLast();
    _undo.add(e);
    return current.replaceRange(e.offset, e.offset + e.before.length, e.after);
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
