import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_outline.dart';
import 'package:orbit_note/domain/wiki_links.dart';

void main() {
  test('outline keeps source offsets and excludes code headings', () {
    const body = '# First\n```dart\n# Hidden\n```\nSecond\n------\n## Third';
    final outline = noteOutline(body);
    expect(outline.map((h) => h.title), ['First', 'Second', 'Third']);
    expect(outline[1].offset, body.indexOf('Second'));
  });
  test(
    'stable links preserve labels and do not rewrite ambiguous/code links',
    () {
      const targets = [
        NoteLinkTarget(id: 'id-a', title: 'Alpha'),
        NoteLinkTarget(id: 'id-b', title: 'Duplicate'),
        NoteLinkTarget(id: 'id-c', title: 'Duplicate'),
      ];
      expect(
        stabilizeWikiLinks(
          '[[Alpha|Readable]] `[[Alpha]]` [[Duplicate]]',
          targets,
        ),
        '[[id-a|Readable]] `[[Alpha]]` [[Duplicate]]',
      );
      expect(
        resolveWikiLink(parseWikiLinks('[[id-a|Readable]]').single, const [
          NoteLinkTarget(id: 'id-a', title: 'Renamed'),
        ]).target!.title,
        'Renamed',
      );
    },
  );
  testWidgets('replace all is literal and outline selects a heading', (
    tester,
  ) async {
    var body = '# Topic\nApple apple a.b';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            initialViewState: const {'mode': 'write'},
            noteId: 'one',
            title: 'One',
            body: body,
            onTitleChanged: (_) {},
            onBodyChanged: (v) => body = v,
            linkTargets: const [],
            onOpenObject: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Note outline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Topic'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')))
          .controller!
          .selection
          .baseOffset,
      0,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Find in this note'),
      'apple',
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-replacement')),
      r'$fruit',
    );
    await tester.tap(find.text('Replace all'));
    await tester.pump();
    expect(body, '# Topic\n\$fruit \$fruit a.b');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'pane restores mode, preview offset and clamped caret independently',
    (tester) async {
      Map<String, dynamic>? state;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'one',
              title: 'One',
              body: 'Short',
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
              initialViewState: const {
                'mode': 'read',
                'base': 999,
                'extent': 999,
                'previewScroll': 80,
              },
              onViewStateChanged: (v) => state = v,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('note-preview')), findsOneWidget);
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('note-body')))
            .controller!
            .selection
            .baseOffset,
        5,
      );
      expect(state!['mode'], 'write');
      expect(tester.takeException(), isNull);
    },
  );
}
