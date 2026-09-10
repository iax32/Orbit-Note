import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/markdown_editing.dart';

void main() {
  test(
    'formatting keeps selected Unicode content and selects inside markers',
    () {
      const value = TextEditingValue(
        text: 'Write café today',
        selection: TextSelection(baseOffset: 6, extentOffset: 10),
      );
      final edited = MarkdownEditing.wrap(value, '**');
      expect(edited.text, 'Write **café** today');
      expect(edited.selection.textInside(edited.text), 'café');
    },
  );

  test('empty selection inserts editable placeholder', () {
    final edited = MarkdownEditing.wrap(
      const TextEditingValue(
        text: 'Hello ',
        selection: TextSelection.collapsed(offset: 6),
      ),
      '*',
    );
    expect(edited.text, 'Hello *text*');
    expect(edited.selection.textInside(edited.text), 'text');
  });

  test('line formatting toggles selected lines without touching next line', () {
    const value = TextEditingValue(
      text: 'alpha\nbeta\ngamma',
      selection: TextSelection(baseOffset: 0, extentOffset: 11),
    );
    final edited = MarkdownEditing.prefixLines(value, '- ');
    expect(edited.text, '- alpha\n- beta\ngamma');
    expect(MarkdownEditing.prefixLines(edited, '- ').text, value.text);
  });

  test('invalid selection safely appends and preserves original content', () {
    final edited = MarkdownEditing.insert(
      const TextEditingValue(text: 'Keep me'),
      '\n[[id|Link]]',
    );
    expect(edited.text, 'Keep me\n[[id|Link]]');
  });

  test('formatting at beginning of first line is safe', () {
    const value = TextEditingValue(
      text: 'First',
      selection: TextSelection.collapsed(offset: 0),
    );
    expect(MarkdownEditing.prefixLines(value, '## ').text, '## First');
  });
}
