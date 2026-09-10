import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';

void main() {
  testWidgets(
    'displays word count, character count, and estimated reading time',
    (tester) async {
      String body =
          'Orbit Note is an exceptional knowledge operating system with local-first storage.';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => NoteEditor(
                noteId: 'stats-test',
                title: 'Stats Test',
                body: body,
                onTitleChanged: (_) {},
                onBodyChanged: (v) => setState(() => body = v),
                linkTargets: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final stats = find.byKey(const ValueKey('document-stats'));
      expect(stats, findsOneWidget);
      final text = tester.widget<Text>(stats).data!;
      expect(text, contains('11 words'));
      expect(text, contains('characters'));
      expect(text, contains('~1 min read'));
    },
  );
}
