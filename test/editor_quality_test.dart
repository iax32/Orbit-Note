import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/domain/document_footnotes.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/app/orbit_draft_guard.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/pdf/pdf_review_panel.dart';
import 'package:orbit_note/features/notes/export/publication_workspace.dart';
import 'package:orbit_note/features/notes/article_publishing_dialog.dart';
import 'package:orbit_note/features/notes/export/publication_export.dart';
import 'package:orbit_note/features/notes/writing_workspace.dart';
import 'support/capture_ui.dart';
import 'support/memory_store.dart';

Widget host(Widget child, {double scale = 1}) => RepaintBoundary(
  child: MaterialApp(
    theme: orbitDarkTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  ),
);

Future<void> openDialog(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    host(
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showDialog<void>(context: context, builder: (_) => child),
          child: const Text('Open'),
        ),
      ),
      scale: scale,
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> size(WidgetTester tester, Size value) async {
  tester.view.physicalSize = value;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> pagesReady(WidgetTester tester) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    if (find.text('Prepared pages').evaluate().isNotEmpty) return;
  }
  fail('Publication preview did not finish.');
}

void main() {
  for (final transition in [
    'controller replaced',
    'Vault reopened',
    'note trashed',
  ]) {
    testWidgets(
      'article apply rejects $transition even when note ID and source match',
      (tester) async {
        await size(tester, const Size(1280, 1000));
        late final WorkspaceRepository repo, secondRepo;
        late final WorkspaceController first, second;
        late final UniversalObject note;
        await tester.runAsync(() async {
          final store = MemoryStore();
          repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
          await repo.initialize();
          first = WorkspaceController()
            ..repository = repo
            ..hasWorkspace = true
            ..loading = false;
          note = (await first.create(
            'orbit.note',
            title: 'Article',
            body: 'Body',
            open: false,
          ))!;
          await first.flushAll();
          secondRepo = WorkspaceRepository(
            store: MemoryStore()..files.addAll(store.files),
            index: MemoryObjectIndex(),
          );
          await secondRepo.initialize();
          expect(secondRepo.workspaceId, repo.workspaceId);
          second = WorkspaceController()
            ..repository = secondRepo
            ..hasWorkspace = true
            ..loading = false;
          second.mergeRepositoryObjects();
        });
        addTearDown(() async {
          first.cancelAllTimers();
          second.cancelAllTimers();
          await repo.close();
          await secondRepo.close();
        });
        var current = first, writes = 0;
        late StateSetter refresh;
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (_, update) {
                refresh = update;
                return NoteEditor(
                  noteId: note.id,
                  title: note.title,
                  body: note.body,
                  controller: current,
                  onTitleChanged: (_) {},
                  onBodyChanged: (_) => writes++,
                  linkTargets: const [],
                  onOpenObject: (_) {},
                  initialViewState: const {'mode': 'write'},
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Writing tools'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Article publishing'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('article-title')),
          'Retained article draft',
        );
        if (transition == 'controller replaced') {
          refresh(() => current = second);
        }
        if (transition == 'Vault reopened') {
          await tester.runAsync(() async {
            await first.closeWorkspace();
            await first.initialize();
          });
          expect(first.find(note.id)?.body, note.body);
          refresh(() {});
        }
        if (transition == 'note trashed') {
          expect(await tester.runAsync(() => first.trash(note.id)), true);
        }
        await tester.pump();
        await tester.tap(find.text('Apply to note'));
        await tester.pumpAndSettle();
        expect(writes, 0);
        expect(find.text('Retained article draft'), findsOneWidget);
        expect(current.find(note.id)?.body, note.body);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Keep editing'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('print settings track exact changes and saved baseline', (
    tester,
  ) async {
    await size(tester, const Size(1280, 1000));
    String? saved;
    await openDialog(
      tester,
      PublicationWorkspace(
        title: 'Title',
        source: 'Body',
        previewBuilder: (_) => const Text('Prepared pages'),
        onApply: (_, next) {
          saved = next;
          return true;
        },
      ),
    );
    await pagesReady(tester);
    await tester.tap(find.text('Letter'));
    await tester.pump(const Duration(milliseconds: 350));
    await pagesReady(tester);
    await tester.tap(find.byTooltip('Close publishing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save settings to note'));
    await tester.pumpAndSettle();
    expect(saved, contains('orbit:publication'));
    await tester.tap(find.byTooltip('Close publishing'));
    await tester.pumpAndSettle();
    expect(find.byType(PublicationWorkspace), findsNothing);
  });
  testWidgets(
    'unchanged forms close immediately, dirty barrier/cancel retain a draft',
    (tester) async {
      await openDialog(
        tester,
        const ArticlePublishingDialog(source: 'Body', title: 'Title'),
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(ArticlePublishingDialog), findsNothing);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('article-title')),
        'Draft',
      );
      await tester.pump();
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.text('Discard unapplied changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.byType(ArticlePublishingDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('successful apply establishes a clean form baseline', (
    tester,
  ) async {
    String? saved;
    await openDialog(
      tester,
      ArticlePublishingDialog(
        source: 'Body',
        title: 'Title',
        onApply: (_, next) {
          saved = next;
          return true;
        },
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('article-title')),
      'Applied title',
    );
    await tester.tap(find.text('Apply to note'));
    await tester.pumpAndSettle();
    expect(saved, contains('Applied title'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ArticlePublishingDialog), findsNothing);
    expect(find.text('Keep editing'), findsNothing);
  });

  testWidgets(
    'failed article apply retains edited fields and discard protection',
    (tester) async {
      await openDialog(
        tester,
        ArticlePublishingDialog(
          source: 'Body',
          title: 'Title',
          onApply: (_, _) => false,
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('article-title')),
        'Retained draft',
      );
      await tester.tap(find.text('Apply to note'));
      await tester.pumpAndSettle();
      expect(find.text('Retained draft'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Keep editing'), findsOneWidget);
    },
  );

  testWidgets(
    'busy review cannot close or submit twice and failed save keeps the draft',
    (tester) async {
      final result = Completer<bool>();
      var attempts = 0;
      final note = UniversalObject(
        id: 'a',
        workspaceId: 'v',
        typeId: 'orbit.note',
        title: 'Review',
        body: 'Original',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        properties: const {
          'pdfSource': {
            'objectId': 'pdf',
            'page': 1,
            'quote': 'Selected passage',
          },
        },
      );
      await openDialog(
        tester,
        PdfReviewEditor(
          annotation: PdfAnnotation(note),
          colors: const {'Blue': 0xff5599cc},
          onSave: (_, _, _, _, _) {
            attempts++;
            return result.future;
          },
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'Important edited comment',
      );
      await tester.tap(find.text('Save review'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(2, 2));
      await tester.pump();
      expect(find.byType(PdfReviewEditor), findsOneWidget);
      expect(find.text('Keep editing'), findsNothing);
      expect(attempts, 1);
      result.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Important edited comment'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Keep editing'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Important edited comment'), findsOneWidget);
    },
  );

  for (final change in [
    'read-only',
    'other note',
    'format',
    'external edit',
    'editor closed',
  ]) {
    testWidgets(
      'open footnote tool rejects $change transitions without losing its draft',
      (tester) async {
        await size(tester, const Size(1280, 1000));
        var viewOnly = false, owner = 'a', format = 'markdown', writes = 0;
        var closed = false;
        var source = 'Text[^a]\n\n[^a]: Original\n';
        late StateSetter refresh;
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (_, update) {
                refresh = update;
                if (closed) return const Text('Editor closed');
                return NoteEditor(
                  noteId: owner,
                  title: 'Note',
                  body: source,
                  viewOnly: viewOnly,
                  documentFormat: format,
                  onTitleChanged: (_) {},
                  onBodyChanged: (_) => writes++,
                  linkTargets: const [],
                  onOpenObject: (_) {},
                  initialViewState: const {'mode': 'write'},
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Writing tools'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manage footnotes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit footnote'));
        await tester.pumpAndSettle();
        final definition = find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == 'Original',
        );
        await tester.enterText(definition, 'Keep this draft');
        refresh(() {
          if (change == 'read-only') viewOnly = true;
          if (change == 'other note') owner = 'b';
          if (change == 'format') format = 'latex';
          if (change == 'editor closed') closed = true;
          if (change == 'external edit') {
            source = 'Text[^a]\n\n[^a]: Updated elsewhere\n';
          }
        });
        await tester.pump();
        if (closed) {
          tester.view.physicalSize = const Size(1240, 900);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(writes, 0);
        expect(find.text('Keep this draft'), findsOneWidget);
        expect(find.textContaining('Your draft is retained'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('footnote rename collision keeps text and permits correction', (
    tester,
  ) async {
    const source = 'Text[^a] [^b]\n\n[^a]: First\n\n[^b]: Second\n';
    final model = DocumentFootnotes(source);
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showFootnoteDraft(
              context,
              'a',
              'First',
              validate: (id, text) => model.save('a', text, renamedId: id),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'b');
    await tester.enterText(find.byType(TextField).last, 'Retained definition');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(find.text('Retained definition'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'new');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Footnote'), findsNothing);
  });

  testWidgets(
    'publication export failure keeps pages and blocks dismissal during transfer',
    (tester) async {
      await size(tester, const Size(1280, 1000));
      final gate = Completer<void>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('plugins.flutter.io/file_selector');
      messenger.setMockMethodCallHandler(channel, (_) async {
        await gate.future;
        throw PlatformException(
          code: 'write-failed',
          message: 'Synthetic disk failure',
        );
      });
      const pigeon =
          'dev.flutter.pigeon.file_selector_windows.FileSelectorApi.showSaveDialog';
      messenger.setMockMessageHandler(pigeon, (_) async {
        await gate.future;
        return const StandardMessageCodec().encodeMessage([
          'write-failed',
          'Synthetic disk failure',
          null,
        ]);
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMessageHandler(pigeon, null);
      });
      await openDialog(
        tester,
        PublicationWorkspace(
          title: 'Title',
          source: '# Title\n\nBody',
          previewBuilder: (_) => const Text('Prepared pages'),
        ),
      );
      await pagesReady(tester);
      await tester.tap(find.text('Export HTML'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(2, 2));
      await tester.pump();
      expect(find.byType(PublicationWorkspace), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Prepared pages'), findsOneWidget);
      expect(
        find.textContaining('preview and settings are retained'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large-text footnote draft and discard dialog fit narrow screens',
    (tester) async {
      await size(tester, const Size(320, 640));
      await prepareCapture(tester);
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showFootnoteDraft(
                context,
                'a',
                'Long definition that can wrap across lines',
              ),
              child: const Text('Open'),
            ),
          ),
          scale: 2,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'invalid label');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'editor-quality-footnote-large');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Keep editing'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'editor-quality-discard-large');
    },
  );

  testWidgets('draft guard rechecks busy state while confirmation is open', (
    tester,
  ) async {
    var busy = false;
    late StateSetter refresh;
    await openDialog(
      tester,
      StatefulBuilder(
        builder: (_, update) {
          refresh = update;
          return OrbitDraftGuard(
            dirty: true,
            busy: busy,
            builder: (_, close) => AlertDialog(
              title: const Text('Draft'),
              actions: [
                TextButton(onPressed: close, child: const Text('Close')),
              ],
            ),
          );
        },
      ),
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    refresh(() => busy = true);
    await tester.pump();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('Draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('article settings keep unapplied edits when Escape closes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const ArticlePublishingDialog(
                  source: 'Article body',
                  title: 'Title',
                  objects: [],
                  ownerId: 'n',
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('article-title')),
      'Draft title',
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Keep editing'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Draft title'), findsOneWidget);
  });

  testWidgets('invalid footnote stays editable instead of closing its draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFootnoteDraft(context, 'a', 'Definition'),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'invalid label');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('invalid label'), findsOneWidget);
    expect(find.textContaining('without spaces'), findsOneWidget);
  });

  test(
    'HTML retains code languages, table alignment and valid title anchors',
    () {
      final document = PublicationDocument.parse(
        'Title',
        '# Title\n\nText  \nnext\n\n---\n\n```cpp\nint main() {}\n```\n\n| A | B |\n| :--- | ---: |\n| left | right |',
        const PublicationStyle(),
      );
      final html = PublicationExport(document).html();
      expect(html, contains('class="language-cpp"'));
      expect(html, contains('text-align:right'));
      expect(html, isNot(contains('</hr>')));
      expect(html, isNot(contains('</br>')));
      expect(RegExp(r'<h1\b').allMatches(html).length, 1);
      expect(
        html,
        contains('<h1 id="${document.headings.first.id}">Title</h1>'),
      );
      expect(html, contains('href="#${document.headings.first.id}"'));
    },
  );
  test(
    'HTML title normalization keeps chapter headings and CMS anchor navigation',
    () {
      final document = PublicationDocument.parse(
        'Title',
        '# Title\n\n[Back to title](#heading-1)\n\n# Chapter',
        const PublicationStyle(),
      );
      final fragment = PublicationExport(document).html(articleFragment: true);
      expect(fragment, contains('<article id="heading-1">'));
      expect(fragment, contains('href="#heading-1"'));
      expect(fragment, contains('>Chapter</h1>'));
      expect(fragment, isNot(contains('>Title</h1>')));
      final different = PublicationExport(
        PublicationDocument.parse(
          'Book',
          '# Chapter\n\nBody',
          const PublicationStyle(),
        ),
      ).html();
      expect(different, contains('>Book</h1>'));
      expect(different, contains('>Chapter</h1>'));
    },
  );
}
