import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';

void main() {
  testWidgets('large Rich notes lazily build blocks and recover exact jumps', (
    tester,
  ) async {
    final body = List.generate(
      360,
      (index) => 'Paragraph $index remains editable.\n\n',
    ).join();
    var current = body;
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => NoteEditor(
              noteId: 'virtual-note',
              title: 'Virtualized note',
              body: current,
              onTitleChanged: (_) {},
              onBodyChanged: (value) => update(() => current = value),
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Paragraph 0 remains editable.'), findsOneWidget);
    expect(find.text('Paragraph 359 remains editable.'), findsNothing);

    final editor = tester.state<RichMarkdownEditorState>(
      find.byType(RichMarkdownEditor),
    );
    editor.jumpTo(body.indexOf('Paragraph 300'));
    await tester.pumpAndSettle();
    expect(find.text('Paragraph 300 remains editable.'), findsOneWidget);
  });
}
