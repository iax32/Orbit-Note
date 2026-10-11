import 'spell_grammar_engine.dart';

/// Walks the engine's sorted, non-overlapping issues while constructing spans.
/// Repeated/forward positions cost O(characters + issues), rather than searching
/// from the first issue for every character. A backward query restarts safely.
class TextIssueCursor {
  TextIssueCursor(this.issues);
  final List<TextIssue> issues;
  int _index = 0;
  int _lastOffset = -1;

  TextIssue? at(int offset) {
    if (offset < _lastOffset) _index = 0;
    _lastOffset = offset;
    while (_index < issues.length && issues[_index].end <= offset) {
      _index++;
    }
    if (_index < issues.length && issues[_index].start <= offset) {
      return issues[_index];
    }
    return null;
  }
}
