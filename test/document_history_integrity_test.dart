import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/document_history.dart';

void main() {
  test('undo validates unchanged content outside the edited splice too', () {
    final h = DocumentHistory()..record('abc ONE tail', 'abc TWO tail');
    expect(h.undo('abc TWO changed'), 'abc TWO changed');
    expect(h.canUndo, isFalse);
    expect(h.canRedo, isFalse);
  });
  test('redo cannot replay onto an externally changed document', () {
    final h = DocumentHistory()..record('one', 'two');
    expect(h.undo('two'), 'one');
    expect(h.redo('other'), 'other');
    expect(h.canUndo, isFalse);
    expect(h.canRedo, isFalse);
  });
  test('a discontinuous edit starts a new safe history chain', () {
    final h = DocumentHistory()..record('old', 'old change');
    h.record('new owner', 'new owner change');
    expect(h.undo('new owner change'), 'new owner');
    expect(h.canUndo, isFalse);
    expect(h.redo('new owner'), 'new owner change');
  });
  test('backwards UTF-16 selections travel with their document edits', () {
    final h = DocumentHistory();
    const before = '😀 word\r\nnext', after = '😀 replaced\r\nnext';
    h.record(before, after, beforeSelection: (7, 3), afterSelection: (11, 11));
    expect(h.undo(after), before);
    expect(h.lastSelection, (7, 3));
    expect(h.redo(before), after);
    expect(h.lastSelection, (11, 11));
  });
  test('surrogate and mixed newline splices round trip exactly', () {
    const samples = [
      '😀a\r\nb\nc',
      '😁a\r\nb\nc',
      '😁a\nb\rc',
      'é\u0301😺\r\n',
    ];
    final h = DocumentHistory();
    for (var i = 1; i < samples.length; i++) {
      h.record(samples[i - 1], samples[i]);
    }
    var text = samples.last;
    for (var i = samples.length - 2; i >= 0; i--) {
      text = h.undo(text);
      expect(text, samples[i]);
    }
    for (var i = 1; i < samples.length; i++) {
      text = h.redo(text);
      expect(text, samples[i]);
    }
  });
  test(
    'retention count remains bounded through 1000 edits and full replay',
    () {
      final h = DocumentHistory();
      var text = '';
      for (var i = 0; i < 1000; i++) {
        h.record(text, '${text}x');
        text += 'x';
      }
      var undone = 0;
      while (h.canUndo) {
        text = h.undo(text);
        undone++;
      }
      expect(undone, 200);
      expect(text.length, 800);
      while (h.canRedo) {
        text = h.redo(text);
      }
      expect(text.length, 1000);
      expect(h.retainedCharacters, 200);
    },
  );
  test('large edit retention trims splices without breaking their chain', () {
    final a = List.filled(300000, 'a').join(),
        b = List.filled(300000, 'b').join();
    final h = DocumentHistory();
    var text = a;
    for (var i = 0; i < 30; i++) {
      final next = i.isEven ? b : a;
      h.record(text, next);
      text = next;
    }
    expect(h.retainedCharacters, lessThanOrEqualTo(4 * 1024 * 1024));
    var count = 0;
    while (h.canUndo) {
      text = h.undo(text);
      expect(text == a || text == b, isTrue);
      count++;
    }
    expect(count, greaterThan(0));
    expect(count, lessThan(30));
  });
  test(
    'no-op records after external changes cannot leave stale undo available',
    () {
      final h = DocumentHistory()..record('a', 'b');
      h.record('external', 'external');
      expect(h.canUndo, isFalse);
      expect(h.canRedo, isFalse);
      expect(h.undo('external'), 'external');
    },
  );
}
