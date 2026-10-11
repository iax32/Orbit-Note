import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/document_footnotes.dart';
import 'package:orbit_note/domain/writing_structure.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_format_toolbar.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

Finder field(String text) =>
    find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);
void main() {
  testWidgets('heading dialog cannot edit another note with identical source', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var owner = 'first';
    var edits = 0;
    late StateSetter refresh;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, update) {
              refresh = update;
              return NoteEditor(
                noteId: owner,
                title: owner,
                body: '# Heading\n\nBody',
                initialViewState: const {'outlineOnly': true},
                onTitleChanged: (_) {},
                onBodyChanged: (_) => edits++,
                linkTargets: const [],
                onOpenObject: (_) {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Section actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit heading'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Heading'), 'Changed');
    refresh(() => owner = 'second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(edits, 0);
    expect(find.text('Heading'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'continuous math selection survives Source and Rich mode changes',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const original = r'Before $x+1$ after.';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'n',
              title: 'Math writing',
              body: original,
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit paragraph continuously'));
      await tester.pumpAndSettle();
      await tester.tap(field(original));
      tester.widget<TextField>(field(original)).controller!.selection =
          const TextSelection(baseOffset: 17, extentOffset: 2);
      await tester.pump();
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('note-body')))
            .controller!
            .selection,
        const TextSelection(baseOffset: 17, extentOffset: 2),
      );
      await tester.tap(find.text('Rich'));
      await tester.pumpAndSettle();
      expect(field(original), findsOneWidget);
      expect(
        tester.widget<TextField>(field(original)).controller!.selection,
        const TextSelection(baseOffset: 17, extentOffset: 2),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('typing styles reach an existing trailing empty paragraph', (
    tester,
  ) async {
    var body = 'Start\n\n';
    final key = GlobalKey<RichMarkdownEditorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichMarkdownEditor(
            key: key,
            body: body,
            onChanged: (v) => body = v,
            onUndo: () {},
            onRedo: () {},
            linkTargets: const [],
            linkBindings: const {},
            onOpenLink: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(field('Start'));
    tester.widget<TextField>(field('Start')).controller!.selection =
        const TextSelection.collapsed(offset: 5);
    await key.currentState!.format(NoteFormatAction.bold);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Next',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await tester.pumpAndSettle();
    expect(body, contains('**Next**'));
    expect(tester.takeException(), isNull);
  });
  test(
    'writing changes survive reopen and failed saves retain durable source',
    () async {
      final store = MemoryStore();
      final repository = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repository.initialize();
      const original =
          '# A ^a\r\n\r\nText[^f]\r\n\r\n[^f]: Old\r\n\r\n# B\r\n\r\nOther\r\n';
      final saved = await repository.create(
        typeId: 'orbit.note',
        title: 'Writing',
        body: original,
        properties: {
          'unknown': {'retained': true},
        },
      );
      final renamed = DocumentFootnotes(
        original,
      ).save('f', 'New\nDefinition', renamedId: 'new');
      final next = moveWritingSection(
        renamed,
        writingSections(renamed).first,
        renamed.length,
      );
      store.failWrites = true;
      await expectLater(
        repository.save(saved.copyWith(body: next)),
        throwsA(isA<Exception>()),
      );
      expect(repository.objects.single.body, original);
      store.failWrites = false;
      await repository.save(saved.copyWith(body: next));
      await repository.close();
      final reopened = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await reopened.initialize();
      expect(reopened.objects.single.body, next);
      expect(reopened.objects.single.properties['unknown'], {'retained': true});
      await reopened.close();
    },
  );
  testWidgets(
    'typing-format switches continue across Enter without empty delimiters',
    (tester) async {
      var body = 'Start';
      final key = GlobalKey<RichMarkdownEditorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichMarkdownEditor(
              key: key,
              body: body,
              onChanged: (v) => body = v,
              onUndo: () {},
              onRedo: () {},
              linkTargets: const [],
              linkBindings: const {},
              onOpenLink: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(field('Start'));
      final controller = tester.widget<TextField>(field('Start')).controller!;
      controller.selection = const TextSelection.collapsed(offset: 5);
      await key.currentState!.format(NoteFormatAction.italic);
      await key.currentState!.format(NoteFormatAction.highlight);
      expect(body, 'Start');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Start more',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );
      await tester.pumpAndSettle();
      expect(body, contains('=='));
      expect(body, contains('*'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(body, isNot(contains('====')));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Next',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      await tester.pumpAndSettle();
      expect(body, contains('==*Next*=='));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('click footnote marker edits its definition and supports undo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const original = 'Text[^a]\n\n[^a]: Original\n';
    var body = original;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            noteId: 'n',
            title: 'Writing',
            body: original,
            onTitleChanged: (_) {},
            onBodyChanged: (v) => body = v,
            linkTargets: const [],
            onOpenObject: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editable = find.descendant(
      of: field('Text[^a]'),
      matching: find.byType(EditableText),
    );
    final render = tester.state<EditableTextState>(editable).renderEditable;
    final rect = render
        .getBoxesForSelection(
          const TextSelection(baseOffset: 5, extentOffset: 6),
        )
        .single
        .toRect();
    await tester.tapAt(render.localToGlobal(rect.center));
    await tester.pumpAndSettle();
    expect(find.text('Footnote'), findsOneWidget);
    await tester.enterText(field('a'), 'renamed');
    await tester.enterText(field('Original'), 'New\nMultiline');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(body, 'Text[^renamed]\n\n[^renamed]: New\n    Multiline\n');
    await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
    await tester.pumpAndSettle();
    expect(body, original);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Source and Split selections return to Rich with reversed endpoints',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const original = '**First**\n\nSecond';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'n',
              title: 'Writing',
              body: original,
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')))
          .controller!;
      controller.selection = const TextSelection(
        baseOffset: 17,
        extentOffset: 2,
      );
      await tester.tap(find.text('Split'));
      await tester.pumpAndSettle();
      expect(
        controller.selection,
        const TextSelection(baseOffset: 17, extentOffset: 2),
      );
      await tester.tap(find.text('Rich'));
      await tester.pumpAndSettle();
      final state = tester.state<RichMarkdownEditorState>(
        find.byType(RichMarkdownEditor),
      );
      expect(
        state.currentDocumentSelection,
        const TextSelection(baseOffset: 17, extentOffset: 2),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
