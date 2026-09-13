import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';

void main() {
  late String body;
  Map<String, dynamic> state = {};
  Future<void> open(
    WidgetTester tester,
    String source, {
    Map<String, dynamic> initial = const {},
  }) async {
    body = source;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, set) => RichMarkdownEditor(
              body: body,
              initialState: initial,
              onState: (value) => state = value,
              onChanged: (value) => set(() => body = value),
              onUndo: () {},
              onRedo: () {},
              linkTargets: const [],
              linkBindings: const {},
              onOpenLink: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reorder retains leading blanks and unequal paragraph gaps', (
    tester,
  ) async {
    await open(tester, '\n\nFirst\n\n\nSecond\n\nThird\n');
    await tester.tap(find.byIcon(Icons.drag_indicator).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();
    expect(body, '\n\nSecond\n\nFirst\n\n\nThird\n');
  });

  testWidgets('moving after final paragraph retains two editable paragraphs', (
    tester,
  ) async {
    await open(tester, 'First\r\n\r\nLast');
    await tester.tap(find.byIcon(Icons.drag_indicator).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();
    expect(body, 'Last\r\n\r\nFirst\r\n\r\n');
    expect(find.widgetWithText(TextField, 'First'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Last'), findsOneWidget);
  });

  testWidgets(
    'collapsed heading survives title editing and session restoration',
    (tester) async {
      await open(
        tester,
        '## Original\nHidden content\n\n## Other\nVisible content\n',
      );
      await tester.tap(find.byTooltip('Collapse section').first);
      await tester.pumpAndSettle();
      expect(find.text('Hidden content'), findsNothing);
      final heading = find.widgetWithText(TextField, 'Original');
      await tester.enterText(heading, 'Renamed');
      await tester.pumpAndSettle();
      expect(body, startsWith('## Renamed\n'));
      expect(find.text('Hidden content'), findsNothing);
      final editor = tester.state<RichMarkdownEditorState>(
        find.byType(RichMarkdownEditor),
      );
      editor.record();
      final saved = Map<String, dynamic>.from(state);
      final savedBody = body;
      await tester.pumpWidget(const SizedBox());
      await open(tester, savedBody, initial: saved);
      expect(find.text('Hidden content'), findsNothing);
      expect(find.text('Visible content'), findsOneWidget);
      await tester.tap(find.byTooltip('Expand section'));
      await tester.pumpAndSettle();
      expect(find.text('Hidden content'), findsOneWidget);
    },
  );
}
