import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/media_section_source.dart';
import 'package:orbit_note/features/notes/rich/media_section.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/features/notes/note_typography.dart';
import 'package:orbit_note/features/notes/note_format_toolbar.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'gantt_planning_test.dart' as helpers;

void main() {
  testWidgets(
    'existing image conversion retains alt/title and can unwrap again',
    (tester) async {
      const image = '![A useful diagram](<photo.png> "Original caption")';
      String changed = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichMarkdownEditor(
              body: '$image\n',
              onChanged: (v) => changed = v,
              onUndo: () {},
              onRedo: () {},
              linkTargets: const [],
              linkBindings: const {},
              onOpenLink: (_) {},
              imageBuilder: (_, _) => const SizedBox(width: 200, height: 100),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Add text beside image'));
      await tester.pumpAndSettle();
      expect(MediaSectionSource.parse(changed)!.imageMarkdown, image);
      await tester.tap(find.text('Stack as Markdown'));
      await tester.pumpAndSettle();
      expect(changed, startsWith(image));
      expect(changed, contains('### Title'));
      expect(changed, isNot(contains('orbit:media')));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('delayed image picking cannot overwrite a newer document edit', (
    tester,
  ) async {
    final pending = Completer<String?>();
    final key = GlobalKey<RichMarkdownEditorState>();
    String changed = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichMarkdownEditor(
            key: key,
            body: 'Draft\n',
            onChanged: (v) => changed = v,
            onUndo: () {},
            onRedo: () {},
            linkTargets: const [],
            linkBindings: const {},
            onOpenLink: (_) {},
            onInsertAttachment: () => pending.future,
          ),
        ),
      ),
    );
    final insertion = key.currentState!.command('Image and text');
    final field = find
        .byType(TextField)
        .evaluate()
        .firstWhere((e) => (e.widget as TextField).controller!.text == 'Draft');
    await tester.enterText(find.byWidget(field.widget), 'Newer draft');
    await tester.pump();
    pending.complete('![Image](<photo.png>)');
    await insertion;
    await tester.pumpAndSettle();
    expect(changed, contains('Newer draft'));
    expect(changed, isNot(contains('orbit:media')));
    expect(tester.takeException(), isNull);
  });
  test('media sections preserve ordinary Markdown and mixed source endings', () {
    final source =
        'Before\r\n\r\n${MediaSectionSource.create('Attachments/photo one.png', body: '### Example\n\n- Detail\n', eol: '\r\n')}\nAfter\n';
    final doc = MarkdownDocument.parse(source);
    expect(doc.source, source);
    expect(
      doc.blocks.where((b) => b.kind == MarkdownBlockKind.media),
      hasLength(1),
    );
    final section = MediaSectionSource.parse(
      doc.blocks.firstWhere((b) => b.kind == MarkdownBlockKind.media).source,
    )!;
    expect(section.image, 'Attachments/photo one.png');
    expect(section.body, contains('- Detail\r\n'));
    final moved = MediaSectionSource.parse(section.configure('right', 260))!;
    expect(moved.body, section.body);
    expect(moved.side, 'right');
    expect(moved.width, 260);
  });
  test(
    'unknown, malformed and unfinished markers remain lossless literal source',
    () {
      for (final source in [
        '<!-- orbit:media left width=999 -->\n![Image](<photo.png>)\nText\n<!-- /orbit:media -->\n',
        '<!-- orbit:media left width=200 -->\n![Image](<photo.png>)\nText\n',
        '<!-- orbit:media left width=200 -->\nNot an image\n<!-- /orbit:media -->\n',
      ]) {
        final doc = MarkdownDocument.parse(source);
        expect(doc.source, source);
        expect(doc.blocks.any((b) => b.kind == MarkdownBlockKind.media), false);
      }
    },
  );
  test(
    'layout closing comments inside fenced code do not terminate sections',
    () {
      final source = MediaSectionSource.create(
        'photo.png',
        body: '```html\n<!-- /orbit:media -->\n```\n\n- After code\n',
      );
      final doc = MarkdownDocument.parse(source);
      expect(doc.source, source);
      final section = MediaSectionSource.parse(doc.blocks.first.source)!;
      expect(section.body, contains('- After code'));
      expect(section.body, contains('<!-- /orbit:media -->'));
    },
  );
  test(
    'Markdown section bytes persist through native save and restart',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-media-');
      var pair = await helpers.setup(
        WorkspaceRepository(
          store: helpers.GanttStore(root.path),
          index: MemoryObjectIndex(),
        ),
      );
      try {
        final source = MediaSectionSource.create(
          'Attachments/photo.png',
          body: '### Research\n\n- **Evidence**\n',
        );
        final note = (await pair.$2.create(
          'orbit.note',
          title: 'Media',
          body: source,
          properties: {
            'unknown': {'keep': true},
          },
        ))!;
        pair.$1.dispose();
        await pair.$2.repository.close();
        pair = await helpers.setup(
          WorkspaceRepository(
            store: helpers.GanttStore(root.path),
            index: MemoryObjectIndex(),
          ),
        );
        expect(pair.$2.find(note.id)!.body, source);
        expect(pair.$2.find(note.id)!.properties['unknown'], {'keep': true});
      } finally {
        pair.$1.dispose();
        await pair.$2.repository.close();
        await root.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'Read mode renders adjacent images and rich Markdown, opens original',
    (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownBody(
              data: MediaSectionSource.create('photo.png'),
              blockSyntaxes: const [MediaSectionSyntax()],
              builders: {
                'orbit-media': MediaSectionBuilder(
                  typography: const NoteTypography(),
                  onTapLink: (_, href, _) => opened = href,
                  imageBuilder: (_, _, _) =>
                      const SizedBox(height: 140, child: Text('Picture')),
                ),
              },
            ),
          ),
        ),
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Add a detail'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Title')).dx,
        greaterThan(tester.getTopLeft(find.text('Picture')).dx),
      );
      await tester.tap(find.text('Picture'));
      expect(opened, 'photo.png');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'narrow large text stacks the image and editable text without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey<RichMarkdownEditorState>();
      String changed = '';
      await tester.pumpWidget(
        MaterialApp(
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(
              ctx,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: RichMarkdownEditor(
              key: key,
              body: MediaSectionSource.create('photo.png'),
              onChanged: (v) => changed = v,
              onUndo: () {},
              onRedo: () {},
              linkTargets: const [],
              linkBindings: const {},
              onOpenLink: (_) {},
              imageBuilder: (_, _) =>
                  const SizedBox(height: 140, child: Text('Picture')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final fields = find.byType(TextField);
      final title = find
          .byType(TextField)
          .evaluate()
          .firstWhere(
            (e) => (e.widget as TextField).controller!.text == 'Title',
          );
      expect(
        tester.getTopLeft(find.byWidget(title.widget)).dy,
        greaterThan(tester.getBottomLeft(find.text('Picture')).dy),
      );
      await tester.enterText(find.byWidget(title.widget), 'Updated title');
      await tester.pump();
      expect(changed, contains('### Updated title'));
      expect(MediaSectionSource.parse(changed), isNotNull);
      expect(fields, findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('insert command and toolbar formatting edit the embedded text', (
    tester,
  ) async {
    final key = GlobalKey<RichMarkdownEditorState>();
    String changed = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichMarkdownEditor(
            key: key,
            body: '',
            onChanged: (v) => changed = v,
            onUndo: () {},
            onRedo: () {},
            linkTargets: const [],
            linkBindings: const {},
            onOpenLink: (_) {},
            onInsertAttachment: () async => '![Photo](<photo.png>)',
            imageBuilder: (_, _) => const SizedBox(height: 100),
          ),
        ),
      ),
    );
    await key.currentState!.command('Image and text');
    await tester.pumpAndSettle();
    expect(MediaSectionSource.parse(changed), isNotNull);
    final field = find
        .byType(TextField)
        .evaluate()
        .firstWhere((e) => (e.widget as TextField).controller!.text == 'Title');
    final controller = (field.widget as TextField).controller!;
    await tester.tap(find.byWidget(field.widget));
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    await key.currentState!.format(NoteFormatAction.bold);
    await tester.pump();
    expect(changed, contains('**Title**'));
    expect(MediaSectionSource.parse(changed), isNotNull);
    expect(tester.takeException(), isNull);
  });
}
