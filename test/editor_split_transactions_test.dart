import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'split_focus_quality_test.dart' as fixtures;

void main() {
  testWidgets(
    'undoing a conflicting pane draft never overwrites the winning shared note',
    (t) async {
      final (c, a, _, _) = await fixtures.fixture(t);
      c.openObject(a.id, secondary: true);
      await t.pumpAndSettle();
      final fields = find.byKey(const ValueKey('note-body'));
      final left = t.widget<TextField>(fields.first),
          right = t.widget<TextField>(fields.last);
      left.controller!.text = 'left accepted';
      left.onChanged!('left accepted');
      right.controller!.text = 'right retained';
      right.onChanged!('right retained');
      await t.pumpAndSettle();
      expect(c.find(a.id)!.body, 'left accepted');
      final rightUndo = find
          .byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == 'Undo · Ctrl+Z',
          )
          .last;
      t.widget<IconButton>(rightUndo).onPressed!();
      await t.pumpAndSettle();
      expect(c.find(a.id)!.body, 'left accepted');
      expect(c.editorDraftConflicts['secondary:${a.id}']!.body, a.body);
      expect(t.widget<TextField>(fields.last).controller!.text, a.body);
      expect(t.takeException(), isNull);
      c.cancelAllTimers();
    },
  );

  testWidgets('composition in one pane cannot block the other pane history', (
    t,
  ) async {
    final (c, a, b, _) = await fixtures.fixture(t);
    final fields = find.byKey(const ValueKey('note-body'));
    final left = t.widget<TextField>(fields.first),
        right = t.widget<TextField>(fields.last);
    await t.tap(fields.last);
    right.controller!.value = const TextEditingValue(
      text: 'Beta composing',
      selection: TextSelection.collapsed(offset: 4),
      composing: TextRange(start: 0, end: 4),
    );
    right.onChanged!('Beta composing');
    left.controller!.text = 'left first';
    left.onChanged!('left first');
    left.controller!.text = 'left second';
    left.onChanged!('left second');
    await t.pumpAndSettle();
    final undo = t.widget<IconButton>(
      find
          .byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == 'Undo · Ctrl+Z',
          )
          .first,
    );
    undo.onPressed!();
    await t.pumpAndSettle();
    expect(c.find(a.id)!.body, 'left first');
    expect(c.find(b.id)!.body, 'Beta composing');
    expect(
      right.controller!.value.composing,
      const TextRange(start: 0, end: 4),
    );
    expect(t.takeException(), isNull);
    c.cancelAllTimers();
  });
}
