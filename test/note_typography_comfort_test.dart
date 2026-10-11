import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';

void main() {
  testWidgets(
    'changing font and spacing refreshes cached blocks without losing selection or text',
    (tester) async {
      var family = 'Segoe UI';
      var height = 1.6;
      late StateSetter change;
      var edits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, refresh) {
                change = refresh;
                return RichMarkdownEditor(
                  body:
                      '# Heading\n\nKeep this paragraph.\n\n| A | B |\n|---|---|\n| Cell | Other |\n\n> [!NOTE] Title\n> Callout text\n',
                  fontFamily: family,
                  fontSize: 18,
                  lineHeight: height,
                  onChanged: (_) => edits++,
                  onUndo: () {},
                  onRedo: () {},
                  linkTargets: const [],
                  linkBindings: const {},
                  onOpenLink: (_) {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      TextField field(String text) => tester
          .widgetList<TextField>(find.byType(TextField))
          .firstWhere((f) => f.controller?.text == text);
      final original = field('Keep this paragraph.').controller!;
      original.selection = const TextSelection(baseOffset: 5, extentOffset: 9);
      change(() {
        family = 'Times New Roman';
        height = 1.9;
      });
      await tester.pumpAndSettle();
      final updated = field('Keep this paragraph.');
      expect(updated.style?.fontFamily, 'Times New Roman');
      expect(updated.style?.height, 1.9);
      expect(updated.controller, same(original));
      expect(
        updated.controller!.selection,
        const TextSelection(baseOffset: 5, extentOffset: 9),
      );
      expect(field('Heading').style?.fontWeight, FontWeight.w700);
      for (final text in ['Cell', 'Callout text']) {
        expect(field(text).style?.fontFamily, 'Times New Roman');
        expect(field(text).style?.fontSize, 18);
        expect(field(text).style?.height, 1.9);
      }
      expect(edits, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Read uses the chosen font in all heading levels tables aligned text and callouts',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: NoteEditor(
              noteId: 'typography',
              title: 'A serif document',
              initialViewState: const {'mode': 'read'},
              body:
                  '# One\n\n#### Four\n\n###### Six\n\nParagraph.\n\n<!-- orbit:align=center -->\n## Centered heading\n\n> [!NOTE] Title\n> Serif callout.\n\n| A | B |\n|---|---|\n| Cell | Other |\n',
              fontFamily: 'Times New Roman',
              fontSize: 20,
              lineHeight: 1.9,
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final main = tester.widget<MarkdownBody>(
        find.byKey(const ValueKey('note-preview')),
      );
      for (final style in [
        main.styleSheet!.p,
        main.styleSheet!.h1,
        main.styleSheet!.h4,
        main.styleSheet!.h6,
        main.styleSheet!.tableBody,
      ]) {
        expect(style?.fontFamily, 'Times New Roman');
      }
      expect(main.styleSheet!.p?.fontSize, 20);
      expect(main.styleSheet!.p?.height, 1.9);
      for (final nested in tester.widgetList<MarkdownBody>(
        find.byType(MarkdownBody),
      )) {
        expect(nested.styleSheet!.p?.fontFamily, 'Times New Roman');
        expect(nested.styleSheet!.p?.fontSize, 20);
        expect(nested.styleSheet!.p?.height, 1.9);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'serif text remains usable at high DPI and enlarged accessibility scale',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1200);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(fontFamily: 'Times New Roman'),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: RichMarkdownEditor(
                body:
                    '# Reading\n\nItalics, descenders and accents: *gypq Åé*.\n',
                fontFamily: 'Times New Roman',
                fontSize: 20,
                lineHeight: 1.8,
                onChanged: (_) {},
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
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.last.style?.fontSize, 20);
      expect(fields.last.style?.fontWeight, FontWeight.w400);
      expect(fields.last.style?.letterSpacing, 0);
      expect(
        orbitDarkTheme(
          fontFamily: 'Times New Roman',
        ).textTheme.headlineMedium?.letterSpacing,
        0,
      );
      expect(
        orbitDarkTheme(
          fontFamily: 'Times New Roman',
        ).textTheme.labelLarge?.fontWeight,
        FontWeight.w400,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
