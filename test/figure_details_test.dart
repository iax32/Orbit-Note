import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/wiki_links.dart';
import 'package:orbit_note/features/notes/rich/figure_details.dart';
import 'package:orbit_note/features/notes/rich/figure_details_dialog.dart';
import 'package:orbit_note/features/notes/rich/media_section_source.dart';
import 'package:orbit_note/features/notes/rich/media_section.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/features/notes/note_typography.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'gantt_planning_test.dart' as helpers;

void main() {
  testWidgets(
    'long caption and citation labels fit a narrow enlarged-text figure',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final section = MediaSectionSource.parse(
        MediaSectionSource.create('photo.png'),
      )!;
      final source = section.withFigure(
        FigureDetails(
          'A long descriptive caption that explains the image clearly across several lines',
          [
            FigureCitation(
              'A long source label with enough detail to recognize the original evidence document',
              'https://example.com',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(
              ctx,
            ).copyWith(textScaler: const TextScaler.linear(2.5)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownBody(
                data: source,
                blockSyntaxes: const [MediaSectionSyntax()],
                builders: {
                  'orbit-media': MediaSectionBuilder(
                    typography: const NoteTypography(),
                    onTapLink: (_, _, _) {},
                    imageBuilder: (_, _, _) => const SizedBox(height: 100),
                  ),
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ActionChip), findsOneWidget);
    },
  );
  testWidgets(
    'stale caption dialog cannot overwrite an externally changed figure',
    (tester) async {
      final key = GlobalKey<RichMarkdownEditorState>();
      final body = ValueNotifier(MediaSectionSource.create('photo.png'));
      String? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: body,
              builder: (ctx, value, _) => RichMarkdownEditor(
                key: key,
                body: value,
                noteId: 'same-note',
                onChanged: (v) => changed = v,
                onUndo: () {},
                onRedo: () {},
                linkTargets: const [],
                linkBindings: const {},
                onOpenLink: (_) {},
                imageBuilder: (_, _) => const SizedBox(height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Caption and sources'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Old draft caption');
      body.value = MediaSectionSource.create('replacement.png');
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(changed, isNull);
      expect(find.textContaining('This figure changed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      body.dispose();
    },
  );
  test(
    'captions and sources round-trip with escaping and preserve surrounding bytes',
    () {
      final section = MediaSectionSource.parse(
        MediaSectionSource.create(
          'photo.png',
          body: '### Detail\r\n\r\nKeep **this**.\r\n',
          eol: '\r\n',
        ),
      )!;
      final details = FigureDetails('A [figure] with *symbols* \\', [
        const FigureCitation('A [source] \\', 'https://example.com/a?q=1&b=2'),
        const FigureCitation('Local note', 'orbit-object:note-id#heading'),
      ]);
      final saved = MediaSectionSource.parse(section.withFigure(details))!;
      expect(saved.figure!.caption, details.caption);
      expect(
        saved.figure!.citations.first.label,
        details.citations.first.label,
      );
      expect(saved.textBody, section.body);
      expect(
        saved.replaceTextBody('Updated\r\n'),
        contains(details.encode('\r\n')),
      );
      final removed = MediaSectionSource.parse(
        saved.withFigure(FigureDetails('', [])),
      )!;
      expect(removed.figure, isNull);
      expect(removed.body, section.body);
      expect(
        MediaSectionSource.parse(
          saved.configure('right', 260),
        )!.figure!.caption,
        details.caption,
      );
    },
  );
  test(
    'invalid and unknown figure data remains literal without dropping content',
    () {
      for (final body in [
        '<!-- orbit:figure -->\nUnknown: keep\n<!-- /orbit:figure -->\nText\n',
        '<!-- orbit:figure -->\nCaption: unfinished\n',
        '<!-- orbit:figure -->\n- [Bad](<javascript:alert(1)>)\n<!-- /orbit:figure -->\n',
      ]) {
        final section = MediaSectionSource.parse(
          MediaSectionSource.create('photo.png', body: body),
        )!;
        expect(section.figure, isNull);
        expect(section.textBody, contains(body));
      }
      for (final dest in [
        'javascript:alert(1)',
        'data:text/html,x',
        'https://',
        'bad\npath',
        'path with space',
        '<file>',
      ]) {
        expect(
          () => FigureCitation('Source', dest).validate(),
          throwsFormatException,
        );
      }
      expect(
        () => FigureDetails('line\nbreak', []).validate(),
        throwsFormatException,
      );
      expect(
        () => FigureDetails(
          '',
          List.generate(21, (_) => const FigureCitation('Source', 'photo.png')),
        ).validate(),
        throwsFormatException,
      );
    },
  );
  test(
    'caption edits persist in native Markdown without changing identity or custom metadata',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-figure-');
      var pair = await helpers.setup(
        WorkspaceRepository(
          store: helpers.GanttStore(root.path),
          index: MemoryObjectIndex(),
        ),
      );
      try {
        final section = MediaSectionSource.parse(
          MediaSectionSource.create('Attachments/photo.png'),
        )!;
        final source = section.withFigure(
          FigureDetails('A diagram', [
            const FigureCitation('Original', 'Attachments/source.pdf#page=4'),
          ]),
        );
        final note = (await pair.$2.create(
          'orbit.note',
          title: 'Figure',
          body: source,
          properties: {
            'custom': {'keep': true},
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
        final reloaded = pair.$2.find(note.id)!;
        expect(reloaded.body, source);
        expect(reloaded.properties['custom'], {'keep': true});
        expect(
          MediaSectionSource.parse(
            reloaded.body,
          )!.figure!.citations.single.destination,
          'Attachments/source.pdf#page=4',
        );
      } finally {
        pair.$1.dispose();
        await pair.$2.repository.close();
        await root.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'Read captions and source chips open their recorded destinations',
    (tester) async {
      final section = MediaSectionSource.parse(
        MediaSectionSource.create('photo.png'),
      )!;
      final source = section.withFigure(
        FigureDetails('Figure 1', [
          const FigureCitation('Evidence', 'orbit-object:note-id'),
        ]),
      );
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownBody(
              data: source,
              blockSyntaxes: const [MediaSectionSyntax()],
              builders: {
                'orbit-media': MediaSectionBuilder(
                  typography: const NoteTypography(),
                  onTapLink: (_, href, _) => opened = href,
                  imageBuilder: (_, _, _) => const SizedBox(height: 100),
                ),
              },
            ),
          ),
        ),
      );
      expect(find.text('Figure 1'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      await tester.tap(find.text('Evidence'));
      expect(opened, 'orbit-object:note-id');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'figure dialog validates links, keeps cancel inert and fits large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      FigureDetails? result;
      await tester.pumpWidget(
        MaterialApp(
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(
              ctx,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showFigureDetails(
                    ctx,
                    FigureDetails('Original', [
                      const FigureCitation('Bad', 'javascript:x'),
                    ]),
                    const [],
                  );
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Use a source label'), findsOneWidget);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    },
  );
  testWidgets(
    'caption editing uses local note picker and retains editable prose',
    (tester) async {
      String changed = '';
      final key = GlobalKey<RichMarkdownEditorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichMarkdownEditor(
              key: key,
              body: MediaSectionSource.create('photo.png'),
              onChanged: (s) => changed = s,
              onUndo: () {},
              onRedo: () {},
              linkTargets: const [
                NoteLinkTarget(id: 'note-id', title: 'Research source'),
              ],
              linkBindings: const {},
              onOpenLink: (_) {},
              imageBuilder: (_, _) => const SizedBox(height: 100),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Caption and sources'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Figure caption');
      await tester.tap(find.text('Add source'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Link a note'));
      await tester.tap(find.text('Link a note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Research source'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      final saved = MediaSectionSource.parse(changed)!;
      expect(saved.figure!.caption, 'Figure caption');
      expect(
        saved.figure!.citations.single.destination,
        'orbit-object:note-id',
      );
      final field = find
          .byType(TextField)
          .evaluate()
          .firstWhere(
            (e) => (e.widget as TextField).controller!.text == 'Title',
          );
      await tester.enterText(find.byWidget(field.widget), 'New heading');
      await tester.pump();
      expect(
        MediaSectionSource.parse(changed)!.figure!.caption,
        'Figure caption',
      );
      expect(changed, contains('### New heading'));
      expect(tester.takeException(), isNull);
    },
  );
}
