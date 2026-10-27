import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_format_toolbar.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'support/capture_ui.dart';

void main() {
  Finder field(String value) => find.byWidgetPredicate(
    (w) => w is TextField && w.controller?.text == value,
  );
  late String body;
  Future<void> open(
    WidgetTester tester,
    String source, {
    double width = 1600,
  }) async {
    body = source;
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await prepareCapture(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: RepaintBoundary(
            child: StatefulBuilder(
              builder: (context, update) => NoteEditor(
                noteId: 'layout',
                title: 'Research journal',
                body: body,
                onTitleChanged: (_) {},
                onBodyChanged: (v) => update(() => body = v),
                linkTargets: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('alignment preserves Markdown, CRLF and unknown comments exactly', () {
    const source =
        '<!-- keep me -->\r\n\r\n<!-- orbit:align=center -->\r\n## Title\r\n\r\nBody';
    final document = MarkdownDocument.parse(source);
    expect(document.source, source);
    final heading = document.blocks.firstWhere(
      (b) => b.kind == MarkdownBlockKind.heading,
    );
    expect(heading.content, 'Title');
    expect(heading.alignment, 'center');
    expect(
      heading.replaceContent('Edited'),
      '<!-- orbit:align=center -->\r\n## Edited\r\n',
    );
    expect(
      heading.withAlignment('right'),
      '<!-- orbit:align=right -->\r\n## Title\r\n',
    );
    expect(heading.withAlignment('left'), '## Title\r\n');
    const unknown =
        '<!-- orbit:align=unsupported -->\nText\n\n<!-- orbit:align=center -->\n```\ncode\n```';
    expect(MarkdownDocument.parse(unknown).source, unknown);
    expect(
      MarkdownDocument.parse(
        unknown,
      ).blocks.every((b) => b.alignment == 'left'),
      isTrue,
    );
  });

  testWidgets(
    'title headings prose and toolbar share an edge; hover reveals paragraph controls',
    (tester) async {
      await open(
        tester,
        '# A clear place to think\n\nReading, ideas, and the connections between them.',
      );
      final title = tester
          .getTopLeft(find.byKey(const ValueKey('note-title')))
          .dx;
      expect(
        tester.getTopLeft(field('A clear place to think')).dx,
        closeTo(title, 1),
      );
      expect(
        tester
            .getTopLeft(
              field('Reading, ideas, and the connections between them.'),
            )
            .dx,
        closeTo(title, 1),
      );
      final toolbar = find
          .descendant(
            of: find.byType(NoteFormatToolbar),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getTopLeft(toolbar).dx, closeTo(title, 1));
      final prose = field('Reading, ideas, and the connections between them.');
      await tester.tap(prose);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(prose));
      await tester.pump();
      final handle = find.byTooltip('Add block below').last;
      final opacity = find
          .ancestor(of: handle, matching: find.byType(Opacity))
          .first;
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(tester.widget<Opacity>(opacity).opacity, 0);
      await captureUi(tester, 'editor-layout-desktop');
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'alignment edits one block, survives typing, undo and Read mode',
    (tester) async {
      await open(tester, '# Heading\n\nBody');
      await tester.tap(field('Heading'));
      await tester.tap(find.byTooltip('Align center'));
      await tester.pumpAndSettle();
      expect(body, '<!-- orbit:align=center -->\n# Heading\n\nBody');
      expect(
        tester.widget<TextField>(field('Heading')).textAlign,
        TextAlign.center,
      );
      await tester.enterText(field('Heading'), 'Centered heading');
      await tester.pumpAndSettle();
      expect(body, '<!-- orbit:align=center -->\n# Centered heading\n\nBody');
      await tester.tap(find.byTooltip('Align right'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Centered heading')).textAlign,
        TextAlign.right,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Centered heading')).textAlign,
        TextAlign.center,
      );
      await tester.tap(find.text('Read').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('orbit:align'), findsNothing);
      final aligned = find.byWidgetPredicate(
        (w) =>
            w is MarkdownBody && w.styleSheet?.h1Align == WrapAlignment.center,
      );
      expect(aligned, findsOneWidget);
      expect(body.endsWith('\n\nBody'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('justified paragraphs survive edits, undo and Read mode', (
    tester,
  ) async {
    await open(tester, 'A paragraph with **bold** content.\n\nNext paragraph.');
    await tester.tap(field('A paragraph with bold content.'));
    await tester.ensureVisible(find.byTooltip('Justify · Blocksatz'));
    await tester.tap(find.byTooltip('Justify · Blocksatz'));
    await tester.pumpAndSettle();
    expect(body, startsWith('<!-- orbit:align=justify -->'));
    expect(
      tester
          .widget<TextField>(field('A paragraph with bold content.'))
          .textAlign,
      TextAlign.justify,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(body, 'A paragraph with **bold** content.\n\nNext paragraph.');
    await tester.tap(find.byTooltip('Justify · Blocksatz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read').first);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is MarkdownBody &&
            w.styleSheet?.textAlign == WrapAlignment.spaceBetween,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty aligned paragraphs stay editable and Enter carries alignment',
    (tester) async {
      await open(tester, '');
      await tester.tap(field(''));
      await tester.tap(find.byTooltip('Align center'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field('')).textAlign, TextAlign.center);
      await tester.enterText(field(''), 'First');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.enterText(field(''), 'Second');
      await tester.pumpAndSettle();
      expect(
        body,
        '<!-- orbit:align=center -->\nFirst\n\n<!-- orbit:align=center -->\nSecond',
      );
      await tester.tap(find.byTooltip('Align left'));
      await tester.pumpAndSettle();
      expect(body, '<!-- orbit:align=center -->\nFirst\n\nSecond');
      expect(
        tester.widget<TextField>(field('Second')).textAlign,
        TextAlign.left,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Enter before trailing blank lines creates only one empty editing prompt',
    (tester) async {
      await open(tester, '# Heading\n\n');
      await tester.tap(field('Heading'));
      tester.widget<TextField>(field('Heading')).controller!.selection =
          const TextSelection.collapsed(offset: 7);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(field(''), findsOneWidget);
      expect(body, '# Heading\n\n\n\n');
      await tester.enterText(field(''), 'One real paragraph');
      await tester.pumpAndSettle();
      expect(body, '# Heading\n\nOne real paragraph\n\n');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow editor stays within its pane', (tester) async {
    await open(
      tester,
      '# Small screen\n\nThe same calm writing space.',
      width: 390,
    );
    await captureUi(tester, 'editor-layout-narrow');
    expect(tester.takeException(), isNull);
    final fieldRect = tester.getRect(field('Small screen'));
    expect(fieldRect.left, greaterThanOrEqualTo(0));
    expect(fieldRect.right, lessThanOrEqualTo(390));
  });
}
