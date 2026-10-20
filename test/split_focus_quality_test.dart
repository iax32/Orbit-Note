import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/workspace/workspace_shell.dart';
import 'package:orbit_note/features/workspace/orbit_tab_strip.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

Future<(WorkspaceController, UniversalObject, UniversalObject, UniversalObject)>
fixture(WidgetTester t, {bool readOnlySecondary = false}) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1;
  final container = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(
        WorkspaceRepository(store: MemoryStore(), index: MemoryObjectIndex()),
      ),
    ],
  );
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WorkspaceShell()),
    ),
  );
  await t.pumpAndSettle();
  final c = container.read(workspaceProvider.notifier);
  c.pausePdfIndex(true);
  c.cancelAllTimers();
  c.session.defaultNoteMode = 'write';
  c.session.sidebarVisible = false;
  c.session.inspectorVisible = false;
  c.session.autoSnapshotOnClose = false;
  final a = (await c.create(
    'orbit.note',
    title: 'Alpha',
    body: List.generate(400, (i) => 'Alpha paragraph $i.').join('\n\n'),
  ))!;
  final b = (await c.create(
    'orbit.note',
    title: 'Beta',
    body: List.generate(400, (i) => 'Beta paragraph $i.').join('\n\n'),
  ))!;
  final d = (await c.create('orbit.note', title: 'Gamma', body: 'Gamma text'))!;
  if (readOnlySecondary) {
    c.objects = [
      for (final o in c.objects)
        if (o.id != b.id)
          o
        else
          UniversalObject(
            id: o.id,
            workspaceId: o.workspaceId,
            typeId: o.typeId,
            title: o.title,
            body: o.body,
            createdAt: o.createdAt,
            updatedAt: o.updatedAt,
            schemaVersion: 2,
          ),
    ];
  }
  c.openObject(a.id);
  c.openObject(b.id, secondary: true);
  await t.pumpAndSettle();
  c.cancelAllTimers();
  addTearDown(() async {
    c.cancelAllTimers();
    await t.pumpWidget(const SizedBox());
    container.dispose();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  return (c, a, b, d);
}

Future<void> shortcut(
  WidgetTester t,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await t.sendKeyEvent(key);
  if (shift) await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'narrowing a split makes close shortcut target its visible primary pane',
    (t) async {
      final (c, a, b, _) = await fixture(t);
      await t.tap(find.byKey(const ValueKey('note-body')).last);
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(700, 1000);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-body')), findsOneWidget);
      await shortcut(t, LogicalKeyboardKey.keyW);
      expect(c.session.tabs, isNot(contains(a.id)));
      expect(c.session.tabs, contains(b.id));
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'clicking a read-only secondary pane makes close shortcut close that pane',
    (t) async {
      final (c, a, b, _) = await fixture(t, readOnlySecondary: true);
      expect(c.find(b.id)!.isReadOnly, isTrue);
      await t.tap(
        find.text(
          'Read-only: this format requires a newer compatible version.',
        ),
      );
      await t.pumpAndSettle();
      await shortcut(t, LogicalKeyboardKey.keyW);
      expect(c.session.activeId, a.id);
      expect(c.session.tabs, contains(a.id));
      expect(c.session.secondaryId, isNull);
      expect(c.find(b.id)!.body, startsWith('Beta paragraph'));
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'tab cycling skips stale and deleted entries in both directions',
    (t) async {
      final (c, a, b, d) = await fixture(t);
      await c.trash(b.id);
      c.session.tabs = [a.id, 'missing', b.id, d.id];
      c.session.activeId = a.id;
      c.cycleTab();
      expect(c.session.activeId, d.id);
      c.cycleTab(reverse: true);
      expect(c.session.activeId, a.id);
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'switching primary tab leaves secondary scroll and selection intact',
    (t) async {
      final (c, _, b, d) = await fixture(t);
      final secondary = t.widget<TextField>(
        find.byKey(const ValueKey('note-body')).last,
      );
      secondary.controller!.selection = const TextSelection(
        baseOffset: 70,
        extentOffset: 90,
      );
      secondary.scrollController!.jumpTo(600);
      await t.pumpAndSettle();
      final offset = secondary.scrollController!.offset;
      c.openObject(d.id);
      await t.pumpAndSettle();
      final after = t.widget<TextField>(
        find.byKey(const ValueKey('note-body')).last,
      );
      expect(c.session.secondaryId, b.id);
      expect(
        after.controller!.selection,
        const TextSelection(baseOffset: 70, extentOffset: 90),
      );
      expect(after.scrollController!.offset, offset);
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'canceling quick switcher returns focus and selection to the secondary editor',
    (t) async {
      final (c, _, _, _) = await fixture(t);
      final body = find.byKey(const ValueKey('note-body')).last;
      await t.tap(body);
      final field = t.widget<TextField>(body);
      field.controller!.selection = const TextSelection(
        baseOffset: 20,
        extentOffset: 35,
      );
      await shortcut(t, LogicalKeyboardKey.keyO);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(field.focusNode!.hasFocus, isTrue);
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 20, extentOffset: 35),
      );
      expect(t.takeException(), isNull);
      c.cancelAllTimers();
    },
  );

  testWidgets('hidden secondary cannot receive Ctrl+Tab after narrowing', (
    t,
  ) async {
    final (c, a, b, _) = await fixture(t);
    await t.tap(find.byKey(const ValueKey('note-body')).last);
    t.view.physicalSize = const Size(700, 1000);
    await t.pumpAndSettle();
    await shortcut(t, LogicalKeyboardKey.tab);
    expect(c.session.activeId, isNot(a.id));
    expect(c.session.secondaryId, b.id);
    c.cancelAllTimers();
  });

  testWidgets(
    'read-only secondary receives tab cycling without replacing primary',
    (t) async {
      final (c, a, b, _) = await fixture(t, readOnlySecondary: true);
      await t.tap(
        find.text(
          'Read-only: this format requires a newer compatible version.',
        ),
      );
      await t.pumpAndSettle();
      await shortcut(t, LogicalKeyboardKey.tab);
      expect(c.session.activeId, a.id);
      expect(c.session.secondaryId, isNot(b.id));
      expect(t.takeException(), isNull);
      c.cancelAllTimers();
    },
  );

  testWidgets('secondary close leaves the primary view of the same note open', (
    t,
  ) async {
    final (c, a, _, _) = await fixture(t);
    c.openObject(a.id, secondary: true);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('note-body')).last);
    await shortcut(t, LogicalKeyboardKey.keyW);
    expect(c.session.secondaryId, isNull);
    expect(c.session.activeId, a.id);
    expect(c.session.tabs, contains(a.id));
    expect(c.find(a.id)!.isDeleted, isFalse);
    c.cancelAllTimers();
  });

  testWidgets('rapid tab changes preserve the other long document view', (
    t,
  ) async {
    final (c, a, b, d) = await fixture(t);
    final secondary = t.widget<TextField>(
      find.byKey(const ValueKey('note-body')).last,
    );
    secondary.controller!.selection = const TextSelection(
      baseOffset: 90,
      extentOffset: 60,
    );
    secondary.scrollController!.jumpTo(900);
    await t.pumpAndSettle();
    final position = secondary.scrollController!.offset;
    for (var i = 0; i < 16; i++) {
      c.openObject(i.isEven ? d.id : a.id);
      await t.pump(const Duration(milliseconds: 16));
    }
    await t.pumpAndSettle();
    final after = t.widget<TextField>(
      find.byKey(const ValueKey('note-body')).last,
    );
    expect(
      after.controller!.selection,
      const TextSelection(baseOffset: 90, extentOffset: 60),
    );
    expect(after.scrollController!.offset, position);
    expect(c.session.secondaryId, b.id);
    expect(c.find(b.id)!.body, b.body);
    expect(t.takeException(), isNull);
    c.cancelAllTimers();
  });

  testWidgets('Rich editor regains its focused field after a modal cancels', (
    t,
  ) async {
    final (c, _, b, _) = await fixture(t);
    c.session.noteViews['secondary:${b.id}'] = {'mode': 'rich'};
    // Recreate just this view through the existing view reset serial.
    c.studyResumeSerial++;
    c.notify();
    await t.pumpAndSettle();
    final note = find.byWidgetPredicate(
      (w) => w is NoteEditor && w.noteId == b.id,
    );
    final fields = find.descendant(
      of: note,
      matching: find.byType(EditableText),
    );
    final body = fields
        .evaluate()
        .where(
          (e) => (e.widget as EditableText).controller.text.startsWith(
            'Beta paragraph',
          ),
        )
        .first;
    final field = body.widget as EditableText;
    field.focusNode.requestFocus();
    field.controller.selection = const TextSelection(
      baseOffset: 2,
      extentOffset: 8,
    );
    await t.pumpAndSettle();
    await shortcut(t, LogicalKeyboardKey.keyO);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(field.focusNode.hasFocus, isTrue);
    expect(
      field.controller.selection,
      const TextSelection(baseOffset: 2, extentOffset: 8),
    );
    expect(t.takeException(), isNull);
    c.cancelAllTimers();
  });

  testWidgets(
    'secondary cycling excludes the unsupported second view of a Canvas',
    (t) async {
      final (c, a, b, _) = await fixture(t);
      final board = (await c.create('orbit.canvas', title: 'Board'))!;
      c.session.tabs = [b.id, board.id, a.id];
      c.session.activeId = board.id;
      c.session.secondaryId = b.id;
      c.cycleTab(secondary: true);
      expect(c.session.secondaryId, a.id);
      expect(c.session.activeId, board.id);
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'activating a primary tab moves typing focus out of the secondary editor',
    (t) async {
      final (c, _, _, d) = await fixture(t);
      await t.tap(find.byKey(const ValueKey('note-body')).last);
      await t.tap(find.byKey(ValueKey(d.id)));
      await t.pumpAndSettle();
      final primary = t.widget<TextField>(
        find.byKey(const ValueKey('note-body')).first,
      );
      final secondary = t.widget<TextField>(
        find.byKey(const ValueKey('note-body')).last,
      );
      expect(c.session.activeId, d.id);
      expect(primary.focusNode!.hasFocus, isTrue);
      expect(secondary.focusNode!.hasFocus, isFalse);
      expect(secondary.controller!.text, startsWith('Beta paragraph'));
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'closing a split returns typing focus to primary without changing its selection',
    (t) async {
      final (c, _, _, _) = await fixture(t);
      final primary = t.widget<TextField>(
        find.byKey(const ValueKey('note-body')).first,
      );
      await t.tap(find.byKey(const ValueKey('note-body')).first);
      primary.controller!.selection = const TextSelection(
        baseOffset: 40,
        extentOffset: 25,
      );
      await t.tap(find.byKey(const ValueKey('note-body')).last);
      await shortcut(t, LogicalKeyboardKey.keyW);
      final field = t.widget<TextField>(
        find.byKey(const ValueKey('note-body')),
      );
      expect(field.focusNode!.hasFocus, isTrue);
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 40, extentOffset: 25),
      );
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'secondary Ctrl+Tab restores typing focus in the new secondary document',
    (t) async {
      final (c, a, _, d) = await fixture(t);
      await t.tap(find.byKey(const ValueKey('note-body')).last);
      await shortcut(t, LogicalKeyboardKey.tab);
      expect(c.session.activeId, a.id);
      expect(c.session.secondaryId, d.id);
      final field = t.widget<TextField>(
        find.byKey(const ValueKey('note-body')).last,
      );
      expect(field.focusNode!.hasFocus, isTrue);
      expect(field.controller!.text, 'Gamma text');
      c.cancelAllTimers();
    },
  );

  testWidgets('primary Rich tab activation focuses its current text block', (
    t,
  ) async {
    final (c, _, _, d) = await fixture(t);
    c.session.noteViews['primary:${d.id}'] = {'mode': 'rich'};
    await t.tap(find.byKey(const ValueKey('note-body')).last);
    await t.tap(find.byKey(ValueKey(d.id)));
    await t.pumpAndSettle();
    final note = find.byWidgetPredicate(
      (w) => w is NoteEditor && w.noteId == d.id,
    );
    final fields = find.descendant(
      of: note,
      matching: find.byType(EditableText),
    );
    final body =
        fields
                .evaluate()
                .where(
                  (e) =>
                      (e.widget as EditableText).controller.text ==
                      'Gamma text',
                )
                .single
                .widget
            as EditableText;
    expect(body.focusNode.hasFocus, isTrue);
    expect(c.find(d.id)!.body, 'Gamma text');
    expect(t.takeException(), isNull);
    c.cancelAllTimers();
  });

  testWidgets(
    'pending pane activation cannot steal focus from a newly opened dialog',
    (t) async {
      final (c, _, _, d) = await fixture(t);
      final strip = t.widget<OrbitTabStrip>(find.byType(OrbitTabStrip));
      strip.onActivate(d.id);
      final context = t.element(find.byType(WorkspaceShell));
      final done = showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Temporary dialog'),
          content: const TextField(
            autofocus: true,
            key: ValueKey('temporary-dialog-input'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close temporary dialog'),
            ),
          ],
        ),
      );
      await t.pumpAndSettle();
      final editable = find.descendant(
        of: find.byKey(const ValueKey('temporary-dialog-input')),
        matching: find.byType(EditableText),
      );
      expect(t.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
      await t.tap(find.text('Close temporary dialog'));
      await t.pumpAndSettle();
      await done;
      expect(t.takeException(), isNull);
      c.cancelAllTimers();
    },
  );

  testWidgets('LaTeX Rich tab activation restores an editor focus node', (
    t,
  ) async {
    final (c, _, _, d) = await fixture(t);
    c.updateProperty(d.id, 'documentFormat', 'latex');
    c.edit(
      d.id,
      body:
          r'\documentclass{article}'
          '\n'
          r'\begin{document}'
          '\nA paragraph.\n'
          r'\end{document}',
    );
    c.session.noteViews['primary:${d.id}'] = {'mode': 'rich'};
    await t.tap(find.byKey(const ValueKey('note-body')).last);
    await t.tap(find.byKey(ValueKey(d.id)));
    await t.pumpAndSettle();
    final note = find.byWidgetPredicate(
      (w) => w is NoteEditor && w.noteId == d.id,
    );
    final fields = find.descendant(
      of: note,
      matching: find.byType(EditableText),
    );
    expect(
      fields.evaluate().where(
        (e) => (e.widget as EditableText).focusNode.hasFocus,
      ),
      hasLength(1),
    );
    expect(c.find(d.id)!.body, contains('A paragraph.'));
    expect(t.takeException(), isNull);
    c.cancelAllTimers();
  });

  testWidgets(
    'primary cycling can activate a Canvas retained in the secondary slot',
    (t) async {
      final (c, a, _, _) = await fixture(t);
      final board = (await c.create('orbit.canvas', title: 'Retained board'))!;
      c.session.tabs = [a.id, board.id];
      c.session.activeId = a.id;
      c.session.secondaryId = board.id;
      c.cycleTab();
      expect(c.session.activeId, board.id);
      expect(c.find(board.id)!.isDeleted, isFalse);
      c.cancelAllTimers();
    },
  );
}
