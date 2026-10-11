import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/wiki_links.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/read_search_overlay.dart';

void main() {
  late String body;
  Future<void> open(WidgetTester tester, String source) async {
    body = source;
    tester.view.physicalSize = const Size(1100, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => NoteEditor(
              noteId: 'custom-read',
              title: 'Read',
              body: body,
              initialViewState: const {'mode': 'read'},
              onTitleChanged: (_) {},
              onBodyChanged: (v) => update(() => body = v),
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder query() => find.widgetWithText(TextField, 'Find in this note');
  Future<void> search(WidgetTester tester, String term) async {
    await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
    await tester.pumpAndSettle();
    await tester.enterText(query(), term);
    await tester.pumpAndSettle();
  }

  Future<void> openReadWithAttachment(
    WidgetTester tester,
    String source,
    String raw,
    ValueChanged<String> onOpen,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            noteId: 'read-attachment-surface',
            title: 'Read',
            body: source,
            initialViewState: const {'mode': 'read'},
            onTitleChanged: (_) {},
            onBodyChanged: (_) {},
            linkTargets: const [],
            onOpenObject: (_) {},
            imageBuilder: (context, value) => Container(
              key: ValueKey(value),
              width: 120,
              height: 80,
              color: Colors.blue,
            ),
            onOpenAttachment: onOpen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey(raw)), findsOneWidget);
    await tester.tap(find.byKey(ValueKey(raw)));
  }

  ReadSearchOverlayState overlay(WidgetTester tester) =>
      tester.state(find.byType(ReadSearchOverlay));
  testWidgets(
    'authored callout title maps without indexing generated type label',
    (tester) async {
      const source = '> [!MYSTERY] Title target\r\n> plain body\r\n';
      await open(tester, source);
      await search(tester, 'target');
      expect(find.text('1 match'), findsOneWidget);
      expect(overlay(tester).revealSelected(), isTrue);
      final header = tester.widget<SelectableText>(
        find.byKey(const ValueKey('read-callout-title')),
      );
      expect(header.data, endsWith('Title target'));
      await tester.enterText(query(), 'NOTE');
      await tester.pumpAndSettle();
      expect(find.text('0 matches'), findsOneWidget);
      expect(overlay(tester).revealSelected(), isFalse);
      expect(body, source);
    },
  );
  testWidgets('title and multi-paragraph body navigate in source order', (
    tester,
  ) async {
    const source =
        'before target\n\n> [!TIP] Title target\n> first target\n>\n> second target\n\nafter target';
    await open(tester, source);
    await search(tester, 'target');
    expect(find.text('5 matches'), findsOneWidget);
    for (var i = 2; i <= 5; i++) {
      await tester.tap(find.byTooltip('Next match'));
      await tester.pumpAndSettle();
      expect(find.text('($i of 5)'), findsOneWidget);
      expect(overlay(tester).revealSelected(), isTrue);
      await tester.pumpAndSettle();
    }
    expect(tester.widget<TextField>(query()).focusNode!.hasFocus, isTrue);
    expect(body, source);
  });
  testWidgets('metadata-like authored title text remains searchable', (
    tester,
  ) async {
    const source = '> [!NOTE] NOTE target\n> target body\n';
    await open(tester, source);
    await search(tester, 'NOTE');
    expect(find.text('1 match'), findsOneWidget);
    expect(overlay(tester).revealSelected(), isTrue);
    expect(body, source);
  });
  testWidgets('header-only callouts and long titles wrap without overflow', (
    tester,
  ) async {
    final title = '${List.filled(40, 'Long title').join(' ')} target';
    await open(tester, '> [!WARNING] $title\n');
    await search(tester, 'target');
    expect(overlay(tester).revealSelected(), isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('read-callout-title')),
          )
          .data,
      endsWith(title),
    );
  });
  for (final alignment in ['center', 'right']) {
    testWidgets(
      '$alignment aligned heading highlights formatted text and keeps source',
      (tester) async {
        final source =
            '<!-- orbit:align=$alignment -->\n# Heading **target**\n\nplain target';
        await open(tester, source);
        await search(tester, 'target');
        expect(overlay(tester).revealSelected(), isTrue);
        await tester.tap(find.byTooltip('Next match'));
        await tester.pumpAndSettle();
        expect(overlay(tester).revealSelected(), isTrue);
        expect(body, source);
      },
    );
  }
  testWidgets('body markup ambiguity retains conservative fallback', (
    tester,
  ) async {
    const source = '> [!TIP] Title target\n> **target**\n';
    await open(tester, source);
    await search(tester, 'target');
    expect(overlay(tester).revealSelected(), isFalse);
    expect(body, source);
  });

  testWidgets('Read callout links use the note link router', (tester) async {
    String? opened;
    const source =
        '> [!NOTE] Resources\n> [Open docs](https://example.com/docs)\n';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            noteId: 'callout-link',
            title: 'Read',
            body: source,
            initialViewState: const {'mode': 'read'},
            onTitleChanged: (_) {},
            onBodyChanged: (_) {},
            linkTargets: const [],
            onOpenObject: (_) {},
            onOpenExternalLink: (href) => opened = href,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open docs'));
    expect(opened, 'https://example.com/docs');
  });

  testWidgets('Read callout attachments resolve relative to the note', (
    tester,
  ) async {
    String? opened;
    const source =
        '> [!NOTE] Files\n> [Blueprint](../Attachments/blueprint%20final.png)\n';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            noteId: 'callout-attachment',
            title: 'Read',
            body: source,
            initialViewState: const {'mode': 'read'},
            onTitleChanged: (_) {},
            onBodyChanged: (_) {},
            linkTargets: const [],
            onOpenObject: (_) {},
            onOpenAttachment: (href) => opened = href,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blueprint'));
    expect(opened, '../Attachments/blueprint%20final.png');
  });

  testWidgets('Read callout attachment images are previewable and openable', (
    tester,
  ) async {
    String? opened;
    const source =
        '> [!NOTE] Files\n> ![Blueprint](../Attachments/blueprint.png)\n';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            noteId: 'callout-image',
            title: 'Read',
            body: source,
            initialViewState: const {'mode': 'read'},
            onTitleChanged: (_) {},
            onBodyChanged: (_) {},
            linkTargets: const [],
            onOpenObject: (_) {},
            imageBuilder: (context, raw) => Container(
              key: ValueKey(raw),
              width: 120,
              height: 80,
              color: Colors.blue,
            ),
            onOpenAttachment: (href) => opened = href,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final image = find.byKey(const ValueKey('../Attachments/blueprint.png'));
    expect(image, findsOneWidget);
    await tester.tap(image);
    expect(opened, '../Attachments/blueprint.png');
  });

  for (final fixture in <({String name, String source, String raw})>[
    (
      name: 'aligned blocks',
      source:
          '<!-- orbit:align=center -->\n![Aligned](../Attachments/aligned.png)',
      raw: '../Attachments/aligned.png',
    ),
    (
      name: 'tables',
      source: '| Preview |\n| --- |\n| ![Table](../Attachments/table.png) |',
      raw: '../Attachments/table.png',
    ),
    (
      name: 'block quotes',
      source: '> ![Quote](../Attachments/quote.png)',
      raw: '../Attachments/quote.png',
    ),
  ]) {
    testWidgets(
      'Read ${fixture.name} attachment images open through the shared handler',
      (tester) async {
        String? opened;
        await openReadWithAttachment(
          tester,
          fixture.source,
          fixture.raw,
          (href) => opened = href,
        );
        expect(opened, fixture.raw);
      },
    );
  }

  testWidgets('Read footnote images open through the shared handler', (
    tester,
  ) async {
    String? opened;
    await openReadWithAttachment(
      tester,
      'Claim[^1].\n\n[^1]: See ![Source](../Attachments/source.png)',
      '../Attachments/source.png',
      (href) => opened = href,
    );
    expect(opened, '../Attachments/source.png');
  });

  testWidgets('Read math-adjacent images open through the shared handler', (
    tester,
  ) async {
    String? opened;
    await openReadWithAttachment(
      tester,
      r'Inline $x^2$ and ![Figure](../Attachments/figure.png).',
      '../Attachments/figure.png',
      (href) => opened = href,
    );
    expect(opened, '../Attachments/figure.png');
  });

  testWidgets('Read dynamic views render as interactive blocks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            noteId: 'dynamic-read',
            title: 'Read',
            body: '```orbit-view\ntype: files\ntitle: Attachments\n```',
            initialViewState: const {'mode': 'read'},
            onTitleChanged: (_) {},
            onBodyChanged: (_) {},
            linkTargets: const [],
            onOpenObject: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Attachments'), findsOneWidget);
    expect(find.text('No matching items found for this view.'), findsOneWidget);
  });

  testWidgets('Read PDF quote links preserve the target page', (tester) async {
    String? opened;
    const source = '> A cited passage.\n>\n> [[paper#page=7|Paper · p. 7]]';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            noteId: 'pdf-quote-read',
            title: 'Read',
            body: source,
            initialViewState: const {'mode': 'read'},
            onTitleChanged: (_) {},
            onBodyChanged: (_) {},
            linkTargets: const [NoteLinkTarget(id: 'paper', title: 'Paper')],
            onOpenObject: (target) => opened = target,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paper · p. 7'));
    expect(opened, 'paper#page=7');
  });

  testWidgets('Read Canvas wiki-links open their stable object', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            noteId: 'canvas-embed-read',
            title: 'Read',
            body: 'See [[board|Canvas board]].',
            initialViewState: const {'mode': 'read'},
            onTitleChanged: (_) {},
            onBodyChanged: (_) {},
            linkTargets: const [
              NoteLinkTarget(id: 'board', title: 'Canvas board'),
            ],
            onOpenObject: (target) => opened = target,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Canvas board'));
    expect(opened, 'board');
  });
}
