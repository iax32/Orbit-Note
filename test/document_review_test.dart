import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/document_review.dart';
import 'package:orbit_note/features/notes/document_review_panel.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/document_history.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

String add(
  String source,
  String quote, {
  String id = 'one',
  String? replacement,
}) => DocumentReview.add(
  source,
  id: id,
  start: source.indexOf(quote),
  end: source.indexOf(quote) + quote.length,
  message: 'Explain --> this 😀',
  replacement: replacement,
);

void main() {
  testWidgets('Read hides metadata and opens the exact passage in Rich', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = add('A passage here.', 'passage');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            noteId: 'note',
            title: 'Review',
            body: source,
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
    expect(find.textContaining('orbit:review'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('note-review-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to passage'));
    await tester.pumpAndSettle();
    expect(find.byType(RichMarkdownEditor), findsOneWidget);
    expect(
      tester
          .state<RichMarkdownEditorState>(find.byType(RichMarkdownEditor))
          .currentDocumentSelection,
      const TextSelection(baseOffset: 2, extentOffset: 9),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stale review draft cannot overwrite a newer note', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var body = 'A passage here.';
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return NoteEditor(
                noteId: 'note',
                title: 'Review',
                body: body,
                initialViewState: const {'mode': 'write'},
                onTitleChanged: (_) {},
                onBodyChanged: (v) => body = v,
                linkTargets: const [],
                onOpenObject: (_) {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<TextField>(find.byKey(const ValueKey('note-body')))
        .controller!
        .selection = const TextSelection(
      baseOffset: 2,
      extentOffset: 9,
    );
    await tester.tap(find.byKey(const ValueKey('note-review-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('review-message')),
      'Old draft',
    );
    update(() => body = 'Newer external wording');
    await tester.pump();
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(body, 'Newer external wording');
    expect(
      find.text('The note changed while composing. Select the passage again.'),
      findsOneWidget,
    );
  });
  test(
    'normal repository save/reopen retains annotations and failed saves retain prior source',
    () async {
      final store = MemoryStore();
      final repository = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repository.initialize();
      final source = add('A passage here.', 'passage', replacement: 'word');
      final note = await repository.create(
        typeId: 'orbit.note',
        title: 'Review',
        body: source,
        properties: {
          'future': {'keep': true},
        },
      );
      store.failWrites = true;
      await expectLater(
        repository.save(
          note.copyWith(body: DocumentReview.accept(source, 'one')),
        ),
        throwsA(isA<Exception>()),
      );
      expect(repository.objects.single.body, source);
      store.failWrites = false;
      await repository.close();
      final reopened = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await reopened.initialize();
      final saved = reopened.objects.single;
      expect(saved.body, source);
      expect(saved.properties['future'], {'keep': true});
      expect(documentReviews(saved.body).single.isOpen, isTrue);
      await reopened.save(
        saved.copyWith(body: DocumentReview.accept(saved.body, 'one')),
      );
      await reopened.close();
      final finalRead = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await finalRead.initialize();
      expect(
        documentReviews(finalRead.objects.single.body).single.state,
        'accepted',
      );
      await finalRead.close();
    },
  );

  testWidgets(
    'filters expose resolved comments and suggestions independently',
    (tester) async {
      final comment = DocumentReview.updateState(
        add('One\n\nTwo', 'One'),
        'one',
        'resolved',
      );
      final source = add(comment, 'Two', id: 'two', replacement: 'Three');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentReviewPanel(
              source: source,
              onAction: (_, _) {},
              onJump: (_) {},
              onAdd: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );
      expect(find.text('Comment · resolved'), findsNothing);
      await tester.tap(find.byType(DropdownButton<ReviewFilter>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comments').last);
      await tester.pumpAndSettle();
      expect(find.text('Comment · resolved'), findsOneWidget);
      expect(find.text('Suggested edit · open'), findsNothing);
      await tester.tap(find.byType(DropdownButton<ReviewFilter>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Everything').last);
      await tester.pumpAndSettle();
      expect(find.text('Comment · resolved'), findsOneWidget);
      expect(find.text('Suggested edit · open'), findsOneWidget);
    },
  );

  testWidgets(
    'editor accepts suggestions atomically and undo restores the original',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = add('A passage here.', 'passage', replacement: 'word');
      var body = source;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'note',
              title: 'Review',
              body: source,
              initialViewState: const {'mode': 'write'},
              onTitleChanged: (_) {},
              onBodyChanged: (v) => body = v,
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-review-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(body, startsWith('A word here.'));
      expect(documentReviews(body).single.state, 'accepted');
      await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
      await tester.pumpAndSettle();
      expect(body, source);
      await tester.tap(find.text('Go to passage'));
      await tester.pumpAndSettle();
      final selection = tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')))
          .controller!
          .selection;
      expect(selection, const TextSelection(baseOffset: 2, extentOffset: 9));
    },
  );
  test(
    'portable metadata preserves source, Unicode, line endings and unknown fields',
    () {
      const original = '---\r\nfuture: yes\r\n---\r\n\r\nA 😀 passage.\r\n';
      final source = add(original, '😀 passage');
      final review = documentReviews(source).single;
      expect(review.quote, '😀 passage');
      expect(review.message, 'Explain --> this 😀');
      expect(source, contains(r'\u003e'));
      expect(source, contains('future: yes\r\n'));
      expect(locateReview(source, review).start, original.indexOf('😀'));
      final extended = source.replaceRange(
        review.start,
        review.end,
        ReviewAnnotation.encode({
          ...review.data,
          'future': {'keep': true},
        }, eol: '\r\n'),
      );
      final resolved = DocumentReview.updateState(extended, 'one', 'resolved');
      expect(documentReviews(resolved).single.data['future'], {'keep': true});
      expect(
        DocumentReview.remove(resolved, 'one'),
        isNot(contains('orbit:review')),
      );
      expect(MarkdownDocument.parse(source).source, source);
    },
  );

  test(
    'moves follow explicit anchors; changed, duplicate and ambiguous passages never retarget',
    () {
      final source = add('First\n\nA passage here.\n\nLast', 'passage');
      final review = documentReviews(source).single;
      final moved = source
          .replaceFirst('First\n\n', '')
          .replaceFirst('Last', 'First\n\nLast');
      expect(
        locateReview(moved, documentReviews(moved).single).start,
        moved.indexOf('passage'),
      );
      final changed = source.replaceFirst('passage', 'different');
      expect(locateReview(changed, review).start, isNull);
      expect(
        () => DocumentReview.accept(
          add(
            'A passage here.',
            'passage',
            replacement: 'word',
          ).replaceFirst('passage', 'different'),
          'one',
        ),
        throwsStateError,
      );
      final duplicate = '$source\n${ReviewAnnotation.encode(review.data)}';
      expect(locateReview(duplicate, review).start, isNull);
      expect(() => DocumentReview.remove(duplicate, 'one'), throwsStateError);
      final repeated = add('word word', 'word');
      expect(locateReview(repeated, documentReviews(repeated).single).start, 0);
    },
  );

  test(
    'suggestions replace only their passage and undo restores content and open receipt together',
    () {
      final source = add(
        'Before\r\n\r\nA **rough** draft 😀.\r\n\r\nAfter',
        '**rough**',
        replacement: '**clear**',
      );
      final history = DocumentHistory();
      final accepted = DocumentReview.accept(source, 'one');
      history.record(source, accepted);
      expect(accepted, contains('A **clear** draft 😀.'));
      expect(accepted, startsWith('Before\r\n'));
      expect(documentReviews(accepted).single.state, 'accepted');
      expect(history.undo(accepted), source);
      expect(history.redo(source), accepted);
      expect(() => DocumentReview.accept(accepted, 'one'), throwsStateError);
      expect(
        () => DocumentReview.updateState(accepted, 'one', 'open'),
        throwsArgumentError,
      );
      final deletion = add('Delete this phrase.', 'this ', replacement: '');
      expect(
        DocumentReview.accept(deletion, 'one'),
        startsWith('Delete phrase.'),
      );
    },
  );

  test(
    'reattach is explicit, retains identity and allows corrected suggestions',
    () {
      final source = add(
        'Old text\n\nNew passage',
        'Old',
        replacement: 'Better',
      );
      final changed = source.replaceFirst('Old text', 'Changed text');
      final attached = DocumentReview.reattach(
        changed,
        'one',
        changed.indexOf('New'),
        changed.indexOf('New') + 3,
      );
      expect(documentReviews(attached).single.quote, 'New');
      expect(documentReviews(attached).single.blockId, isNotNull);
      expect(
        DocumentReview.accept(attached, 'one'),
        contains('Better passage'),
      );
      final rejected = DocumentReview.updateState(source, 'one', 'rejected');
      expect(rejected, startsWith('Old text'));
      expect(
        documentReviews(
          DocumentReview.updateState(rejected, 'one', 'open'),
        ).single.isOpen,
        isTrue,
      );
    },
  );

  test(
    'fenced examples, unsupported metadata, setext and multi-block selections stay lossless',
    () {
      final record = documentReviews(add('Text', 'Text')).single;
      final encoded = ReviewAnnotation.encode(record.data);
      expect(documentReviews('```md\n$encoded```\n'), isEmpty);
      expect(
        documentReviews(encoded.replaceFirst('"version":1', '"version":2')),
        isEmpty,
      );
      expect(() => add('```\nText', 'Text'), throwsStateError);
      const setext = 'Heading\r\n=======\r\n\r\nBody';
      final reviewed = add(setext, 'Heading\r\n=======');
      expect(reviewed, startsWith(setext));
      expect(locateReview(reviewed, documentReviews(reviewed).single).start, 0);
      final multi = add('First\n\nSecond\n\nLast', 'First\n\nSecond');
      expect(locateReview(multi, documentReviews(multi).single).start, 0);
    },
  );

  testWidgets(
    'Rich hides recognized records and keeps visible content editable',
    (tester) async {
      final source = add('A passage here.', 'passage');
      String? edited;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichMarkdownEditor(
              body: source,
              onChanged: (v) => edited = v,
              onOpenLink: (_) {},
              onUndo: () {},
              onRedo: () {},
              linkBindings: const {},
              linkTargets: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('orbit:review'), findsNothing);
      final field = find.byType(TextField).first;
      await tester.enterText(field, 'Updated passage here.');
      expect(documentReviews(edited!).single.message, contains('Explain'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review panel filters and disabled unsafe accept scale at narrow widths',
    (tester) async {
      tester.view.physicalSize = const Size(390, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = add(
        'A passage here.',
        'passage',
        replacement: 'word',
      ).replaceFirst('A passage', 'A changed');
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: DocumentReviewPanel(
                source: source,
                onAction: (_, _) {},
                onJump: (_) {},
                onAdd: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Accept'));
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Accept'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editor comment creation saves selected source and review resolve is undoable',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var body = 'A passage here.';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'note',
              title: 'Review',
              body: body,
              initialViewState: const {'mode': 'write'},
              onTitleChanged: (_) {},
              onBodyChanged: (v) => body = v,
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')))
          .controller!;
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 9,
      );
      await tester.tap(find.byKey(const ValueKey('note-review-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comment'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('review-message')),
        'Please explain.',
      );
      await tester.pump();
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      expect(body, contains('orbit:review'));
      expect(documentReviews(body).single.quote, 'passage');
      await tester.tap(find.text('Resolve'));
      await tester.pumpAndSettle();
      expect(documentReviews(body).single.state, 'resolved');
      await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
      await tester.pumpAndSettle();
      expect(documentReviews(body).single.state, 'open');
      expect(tester.takeException(), isNull);
    },
  );
}
