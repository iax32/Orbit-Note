import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:orbit_note/domain/wiki_links.dart';
import 'package:orbit_note/features/notes/note_editor.dart';

void main() {
  Future<void> editor(
    WidgetTester tester, {
    String body = 'A quiet place to think.',
    ValueChanged<String>? onBodyChanged,
    ValueChanged<String>? onOpenObject,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            initialViewState: const {'mode': 'write'},
            noteId: 'note-1',
            title: 'A new idea',
            body: body,
            onTitleChanged: (_) {},
            onBodyChanged: onBodyChanged ?? (_) {},
            linkTargets: const [
              NoteLinkTarget(id: 'note-2', title: 'Design decisions'),
            ],
            onOpenObject: onOpenObject ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('typing and toolbar formatting report real Markdown changes', (
    tester,
  ) async {
    var body = '';
    await editor(tester, onBodyChanged: (value) => body = value);
    final field = find.byKey(const ValueKey('note-body'));
    await tester.enterText(field, 'An idea');
    expect(body, 'An idea');
    final textField = tester.widget<TextField>(field);
    textField.controller!.selection = const TextSelection(
      baseOffset: 3,
      extentOffset: 7,
    );
    await tester.tap(find.byTooltip('Bold · Ctrl+B'));
    await tester.pump();
    expect(body, 'An **idea**');
    expect(tester.takeException(), isNull);
  });

  testWidgets('parent autosave rebuild preserves the caret and text', (
    tester,
  ) async {
    const body = 'Keep the writing cursor.';
    await editor(tester, body: body);
    final field = find.byKey(const ValueKey('note-body'));
    final controller = tester.widget<TextField>(field).controller!;
    controller.selection = const TextSelection.collapsed(offset: 7);
    await editor(tester, body: body);
    expect(tester.widget<TextField>(field).controller!.selection.baseOffset, 7);
    expect(tester.widget<TextField>(field).controller!.text, body);
  });

  testWidgets('reading preview opens resolved IDs and labels missing links', (
    tester,
  ) async {
    String? opened;
    await editor(
      tester,
      body: 'Read [[note-2|Design]] and [[Missing]].',
      onOpenObject: (id) => opened = id,
    );
    await tester.tap(find.text('Read').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-preview')), findsOneWidget);
    final preview = tester.widget<MarkdownBody>(
      find.byKey(const ValueKey('note-preview')),
    );
    expect(preview.data, contains('Missing · missing'));
    // Markdown exposes its callback; exercising it avoids a pixel-dependent span hit.
    preview.onTapLink!('Design', 'orbit-object:note-2', '');
    expect(opened, 'note-2');
  });

  testWidgets('link chooser inserts stable identity with a readable label', (
    tester,
  ) async {
    var body = '';
    await editor(tester, body: '', onBodyChanged: (value) => body = value);
    await tester.tap(find.byTooltip('Object link · Ctrl+K'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Design decisions'));
    await tester.pumpAndSettle();
    expect(body, '[[note-2|Design decisions]]');
  });

  testWidgets('local find selects matching document text', (tester) async {
    await editor(tester, body: 'First thought. Second thought.');
    await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
    await tester.pump();
    final field = find.widgetWithText(TextField, 'Find in this note');
    await tester.enterText(field, 'thought');
    await tester.pump();
    expect(find.text('2 matches'), findsOneWidget);
    final controller = tester
        .widget<TextField>(find.byKey(const ValueKey('note-body')))
        .controller!;
    expect(controller.selection.textInside(controller.text), 'thought');
  });

  testWidgets('keyboard bold operates on selected text', (tester) async {
    var body = '';
    await editor(
      tester,
      body: 'Selected',
      onBodyChanged: (value) => body = value,
    );
    final field = find.byKey(const ValueKey('note-body'));
    await tester.tap(field);
    tester.widget<TextField>(field).controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 8,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(body, '**Selected**');
  });
}
