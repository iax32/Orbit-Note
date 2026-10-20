import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/document_history.dart';

typedef Draft = ({String id, String body, bool readOnly});

Future<ValueNotifier<Draft>> fixture(
  WidgetTester t, {
  String body = 'alpha beta',
}) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1;
  final draft = ValueNotifier<Draft>((id: 'one', body: body, readOnly: false));
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: draft,
          builder: (_, value, _) => NoteEditor(
            noteId: value.id,
            title: 'Note',
            body: value.body,
            viewOnly: value.readOnly,
            initialViewState: const {'mode': 'write'},
            onBodyChanged: (body) => draft.value = (
              id: value.id,
              body: body,
              readOnly: value.readOnly,
            ),
            onTitleChanged: (_) {},
            linkTargets: const [],
            onOpenObject: (_) {},
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    draft.dispose();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  return draft;
}

Future<void> command(WidgetTester t, LogicalKeyboardKey key) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyEvent(key);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await t.pumpAndSettle();
}

void main() {
  for (final replacement in [false, true]) {
    testWidgets(
      'undo in ${replacement ? 'replacement' : 'find'} input cannot undo document edits',
      (t) async {
        final draft = await fixture(t);
        await t.enterText(
          find.byKey(const ValueKey('note-body')),
          'alpha beta changed',
        );
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Find in note · Ctrl+F'));
        await t.pumpAndSettle();
        final field = replacement
            ? find.byKey(const ValueKey('note-replacement'))
            : find.widgetWithText(TextField, 'Find in this note');
        await t.tap(field);
        await t.pump(const Duration(milliseconds: 600));
        await t.enterText(field, 'alpha');
        await t.pump(const Duration(milliseconds: 600));
        await command(t, LogicalKeyboardKey.keyZ);
        expect(draft.value.body, 'alpha beta changed');
        expect(t.widget<TextField>(field).controller!.text, '');
        await command(t, LogicalKeyboardKey.keyY);
        expect(t.widget<TextField>(field).controller!.text, 'alpha');
        expect(draft.value.body, 'alpha beta changed');
      },
    );
  }

  testWidgets('reused editor cannot undo into the previous note', (t) async {
    final draft = await fixture(t, body: 'First original');
    await t.enterText(find.byKey(const ValueKey('note-body')), 'First edited');
    await t.pumpAndSettle();
    draft.value = (id: 'two', body: 'Second original', readOnly: false);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('note-body')));
    await command(t, LogicalKeyboardKey.keyZ);
    expect(draft.value.id, 'two');
    expect(draft.value.body, 'Second original');
  });

  testWidgets(
    'retained replacement callback cannot mutate a newly read-only editor',
    (t) async {
      final draft = await fixture(t);
      await t.tap(find.byTooltip('Find in note · Ctrl+F'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'Find in this note'),
        'alpha',
      );
      await t.enterText(
        find.byKey(const ValueKey('note-replacement')),
        'changed',
      );
      await t.pumpAndSettle();
      final old = t.widget<TextButton>(
        find.widgetWithText(TextButton, 'Replace'),
      );
      draft.value = (id: 'one', body: draft.value.body, readOnly: true);
      await t.pumpAndSettle();
      old.onPressed!();
      await t.pumpAndSettle();
      expect(draft.value.body, 'alpha beta');
    },
  );

  test('stale history replay cannot overwrite a changed splice', () {
    final history = DocumentHistory();
    history.record('Hello world', 'Hello revised world');
    expect(history.undo('Hello unrelated world'), 'Hello unrelated world');
  });

  test('shortened history source cannot throw during undo', () {
    final history = DocumentHistory();
    history.record('prefix long source', 'prefix changed long source');
    expect(() => history.undo('x'), returnsNormally);
    expect(history.redo('x'), 'x');
  });

  testWidgets(
    'undo and redo restore reversed source selection and inserted caret',
    (t) async {
      final draft = await fixture(t, body: '😀 alpha beta\r\nnext');
      final body = find.byKey(const ValueKey('note-body'));
      final field = t.widget<TextField>(body);
      field.controller!.selection = const TextSelection(
        baseOffset: 8,
        extentOffset: 3,
      );
      field.controller!.value = const TextEditingValue(
        text: '😀 changed beta\r\nnext',
        selection: TextSelection.collapsed(offset: 10),
      );
      field.onChanged!('😀 changed beta\r\nnext');
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Undo · Ctrl+Z'));
      await t.pumpAndSettle();
      expect(draft.value.body, '😀 alpha beta\r\nnext');
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 8, extentOffset: 3),
      );
      await t.tap(find.byTooltip('Redo · Ctrl+Shift+Z'));
      await t.pumpAndSettle();
      expect(draft.value.body, '😀 changed beta\r\nnext');
      expect(
        field.controller!.selection,
        const TextSelection.collapsed(offset: 10),
      );
    },
  );

  testWidgets('a retained undo action cannot change a viewer-only document', (
    t,
  ) async {
    final draft = await fixture(t);
    await t.enterText(find.byKey(const ValueKey('note-body')), 'edited');
    await t.pumpAndSettle();
    final undo = t.widget<IconButton>(
      find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Undo · Ctrl+Z',
      ),
    );
    draft.value = (id: 'one', body: 'edited', readOnly: true);
    await t.pumpAndSettle();
    undo.onPressed!();
    await t.pumpAndSettle();
    expect(draft.value.body, 'edited');
    expect(draft.value.readOnly, isTrue);
  });

  testWidgets(
    'external source updates invalidate previous undo and redo chains',
    (t) async {
      final draft = await fixture(t);
      await t.enterText(find.byKey(const ValueKey('note-body')), 'edited');
      await t.pumpAndSettle();
      draft.value = (id: 'one', body: 'External current', readOnly: false);
      await t.pumpAndSettle();
      expect(
        t
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Undo · Ctrl+Z',
              ),
            )
            .onPressed,
        isNull,
      );
      await t.tap(find.byKey(const ValueKey('note-body')));
      await command(t, LogicalKeyboardKey.keyZ);
      expect(draft.value.body, 'External current');
    },
  );

  testWidgets(
    'changing identity with identical text still retires the old history',
    (t) async {
      final draft = await fixture(t);
      await t.enterText(find.byKey(const ValueKey('note-body')), 'same body');
      await t.pumpAndSettle();
      draft.value = (id: 'two', body: 'same body', readOnly: false);
      await t.pumpAndSettle();
      expect(
        t
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Undo · Ctrl+Z',
              ),
            )
            .onPressed,
        isNull,
      );
      await t.enterText(
        find.byKey(const ValueKey('note-body')),
        'new owner edit',
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Undo · Ctrl+Z'));
      await t.pumpAndSettle();
      expect(draft.value.body, 'same body');
      expect(draft.value.id, 'two');
    },
  );

  testWidgets(
    'replacement review cancellation leaves source and history intact',
    (t) async {
      final draft = await fixture(t, body: '**alpha** [alpha](alpha)\r\n');
      await t.tap(find.byTooltip('Find in note · Ctrl+F'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'Find in this note'),
        'alpha',
      );
      await t.enterText(find.byKey(const ValueKey('note-replacement')), 'beta');
      await t.pumpAndSettle();
      await t.tap(find.text('Replace all'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(draft.value.body, '**alpha** [alpha](alpha)\r\n');
      expect(
        t
            .widget<IconButton>(
              find.byKey(const ValueKey('note-document-undo')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'a replacement review refuses changed source instead of overwriting it',
    (t) async {
      final draft = await fixture(t);
      await t.tap(find.byTooltip('Find in note · Ctrl+F'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'Find in this note'),
        'alpha',
      );
      await t.enterText(find.byKey(const ValueKey('note-replacement')), 'beta');
      await t.pumpAndSettle();
      await t.tap(find.text('Replace all'));
      await t.pumpAndSettle();
      draft.value = (id: 'one', body: 'Newer alpha evidence', readOnly: false);
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Apply '));
      await t.pumpAndSettle();
      expect(draft.value.body, 'Newer alpha evidence');
      expect(
        find.text('The note changed. Reopen the writing tool before applying.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'large replacement review pages results and applies one undoable command',
    (t) async {
      final original = List.generate(1000, (i) => 'alpha $i 😀\r\n').join();
      final draft = await fixture(t, body: original);
      await t.tap(find.byTooltip('Find in note · Ctrl+F'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'Find in this note'),
        'alpha',
      );
      await t.enterText(find.byKey(const ValueKey('note-replacement')), 'beta');
      await t.pumpAndSettle();
      await t.tap(find.text('Replace all'));
      await t.pumpAndSettle();
      expect(
        find.byType(CheckboxListTile).evaluate().length,
        lessThanOrEqualTo(30),
      );
      expect(find.text('Page 1 of 34'), findsOneWidget);
      await t.tap(find.textContaining('Apply 1000'));
      await t.pumpAndSettle();
      expect(draft.value.body, original.replaceAll('alpha', 'beta'));
      await t.tap(find.byKey(const ValueKey('note-document-undo')));
      await t.pumpAndSettle();
      expect(draft.value.body, original);
      await t.tap(find.byKey(const ValueKey('note-document-redo')));
      await t.pumpAndSettle();
      expect(draft.value.body, original.replaceAll('alpha', 'beta'));
    },
  );

  testWidgets(
    'selection replacement keeps expanding matches inside its original scope',
    (t) async {
      const original =
          'outside alpha\r\nalpha one\r\nalpha two\r\noutside alpha';
      final draft = await fixture(t, body: original);
      final field = t.widget<TextField>(
        find.byKey(const ValueKey('note-body')),
      );
      field.controller!.selection = TextSelection(
        baseOffset: original.indexOf('alpha one'),
        extentOffset: original.lastIndexOf('\r\noutside'),
      );
      await t.tap(find.byTooltip('Find in note · Ctrl+F'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'Find in this note'),
        'alpha',
      );
      await t.enterText(
        find.byKey(const ValueKey('note-replacement')),
        'a much longer word',
      );
      await t.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await t.tap(find.text('Replace'));
        await t.pumpAndSettle();
      }
      expect(
        draft.value.body,
        'outside alpha\r\na much longer word one\r\na much longer word two\r\noutside alpha',
      );
      expect(find.text('0 matches'), findsOneWidget);
    },
  );
}
