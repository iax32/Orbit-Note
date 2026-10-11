import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/latex/latex_templates.dart';
import 'package:orbit_note/features/notes/latex/rich_latex_editor.dart';
import 'package:orbit_note/features/notes/latex/latex_preview.dart';
import 'package:orbit_note/features/notes/latex/latex_inspector.dart';

void main() {
  testWidgets(
    'NoteEditor in LaTeX format renders visual academic editor and tools',
    (tester) async {
      String currentBody = LatexTemplates.assignment.body;
      String currentFormat = 'latex';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'test-latex-note',
              title: 'Assignment 1',
              body: currentBody,
              documentFormat: currentFormat,
              onTitleChanged: (_) {},
              onBodyChanged: (v) => currentBody = v,
              onDocumentFormatChanged: (fmt) => currentFormat = fmt,
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify format badge is displayed showing LaTeX
      expect(
        find.byKey(const ValueKey('document-format-badge')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('document-format-badge')),
          matching: find.text('LaTeX'),
        ),
        findsOneWidget,
      );

      // Verify LaTeX-specific authoring buttons in header
      expect(find.byTooltip('Math Symbol Palette'), findsOneWidget);
      expect(find.byTooltip('Matrix & Cases Grid Builder'), findsOneWidget);
      expect(
        find.byTooltip('LaTeX Document Settings & Outline'),
        findsOneWidget,
      );
      expect(find.byTooltip('Export as PDF'), findsOneWidget);

      // Verify RichLatexEditor is active in Rich mode (default)
      expect(find.byType(RichLatexEditor), findsOneWidget);

      // Open Math Symbol Palette
      await tester.tap(find.byTooltip('Math Symbol Palette'));
      await tester.pumpAndSettle();

      // Palette search and categories should be visible
      expect(find.byKey(const ValueKey('math-palette-search')), findsOneWidget);
      expect(find.text('Basic'), findsOneWidget);
      expect(find.text('Operators'), findsOneWidget);

      // Close palette
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Toggle LaTeX Inspector / Settings
      await tester.tap(find.byTooltip('LaTeX Document Settings & Outline'));
      await tester.pumpAndSettle();

      expect(find.text('LaTeX Document'), findsOneWidget);
      expect(find.text('Outline'), findsOneWidget);
      expect(find.text('Format'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LatexInspector),
          matching: find.text('Preamble'),
        ),
        findsOneWidget,
      );

      // Switch to Read/Preview mode
      final modeFinder = find.byType(PopupMenuButton<NoteEditorMode>);
      if (modeFinder.evaluate().isNotEmpty) {
        await tester.tap(modeFinder);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Read').last);
      await tester.pumpAndSettle();

      // Verify LatexPreview is rendered in read mode
      expect(find.byType(LatexPreview), findsWidgets);
    },
  );
}
