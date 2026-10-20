import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/domain/pdf_review_batch.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'package:orbit_note/features/pdf/pdf_review_panel.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/memory_store.dart';
import 'support/pdf_fixture.dart';
import 'support/capture_ui.dart';
import 'pdf_reader_reliability_test.dart'
    show desktop, ready, waitNative, linkedNote;

List<CanvasElement> region() => [
  CanvasElement({
    'id': 'r',
    'type': 'rectangle',
    'page': 1,
    'x': .1,
    'y': .1,
    'width': .2,
    'height': .03,
    'color': 0xffeab308,
    'style': 'highlight',
  }),
];

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final nativeReady = await initPdfTesting();
  late MemoryStore store;
  late WorkspaceRepository repo;
  late WorkspaceController c;
  late UniversalObject source;
  late List<PdfAnnotation> marks;
  setUp(() async {
    store = MemoryStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    await repo.initialize();
    c = WorkspaceController()
      ..repository = repo
      ..hasWorkspace = true
      ..loading = false;
    source = await repo.importAttachment(
      name: 'Evidence.pdf',
      bytes: researchPdf(),
    );
    c.mergeRepositoryObjects();
    marks = [];
    for (var i = 0; i < 3; i++) {
      final note = (await c.createPdfHighlight(
        source.id,
        source.properties['checksum'] as String,
        'Passage $i',
        region(),
        comment: 'Authored comment $i',
      ))!;
      marks.add(PdfAnnotation(note));
    }
  });
  tearDown(() async {
    store.failWrites = false;
    store.writeGate = null;
    await c.flushAll();
    c.cancelAllTimers();
    await repo.close();
  });
  List<PdfAnnotation> latest() =>
      marks.map((a) => PdfAnnotation(c.find(a.object.id)!)).toList();

  test(
    'bulk resolve, color and style preserve note bodies, source anchors and unknown fields',
    () async {
      c.edit(
        marks.first.object.id,
        properties: {
          ...marks.first.object.properties,
          'future': {'keep': 42},
        },
      );
      await c.flushAll();
      marks = latest();
      final receipt = await c.changePdfReviews(
        source,
        marks,
        PdfReviewBatchAction.resolve,
      );
      expect(receipt.changes, hasLength(3));
      expect(receipt.failures, isEmpty);
      expect(latest().every((a) => a.resolved), true);
      for (var i = 0; i < 3; i++) {
        expect(latest()[i].object.body, marks[i].object.body);
        expect(latest()[i].source, marks[i].source);
      }
      final colored = await c.changePdfReviews(
        source,
        latest(),
        PdfReviewBatchAction.color,
        color: 0xff22c55e,
      );
      expect(colored.changes, hasLength(3));
      expect(
        latest().every((a) => a.color == 0xff22c55e && a.style == 'highlight'),
        true,
      );
      final styled = await c.changePdfReviews(
        source,
        latest(),
        PdfReviewBatchAction.underline,
      );
      expect(styled.changes, hasLength(3));
      expect(
        latest().every((a) => a.style == 'underline' && a.color == 0xff22c55e),
        true,
      );
      expect(latest().first.object.properties['future'], {'keep': 42});
      final undone = await c.undoPdfReviewBatch(styled);
      expect(undone.changes, hasLength(3));
      expect(latest().every((a) => a.style == 'highlight'), true);
      expect(
        await repo.readAttachment(source.properties['contentRef'] as String),
        researchPdf(),
      );
    },
  );

  test(
    'batch Trash and Undo restore exact identities and exclude later edits',
    () async {
      final result = await c.changePdfReviews(
        source,
        marks,
        PdfReviewBatchAction.trash,
      );
      expect(result.changes, hasLength(3));
      expect(c.activeObjects.where(PdfAnnotation.isAnnotation), isEmpty);
      final changed = result.changes.first.after;
      await repo.save(changed.copyWith(body: 'Newer Trash content'));
      c.mergeRepositoryObjects();
      final undo = await c.undoPdfReviewBatch(result);
      expect(undo.changes, hasLength(2));
      expect(undo.failures.keys, [changed.id]);
      expect(c.find(changed.id)!.isDeleted, true);
      expect(c.find(changed.id)!.body, 'Newer Trash content');
      for (final a in marks.skip(1)) {
        expect(c.find(a.object.id)!.body, a.object.body);
        expect(c.find(a.object.id)!.isDeleted, false);
      }
    },
  );

  test(
    'cancellation stops between commits and Undo covers only the completed prefix',
    () async {
      var stop = false;
      final result = await c.changePdfReviews(
        source,
        marks,
        PdfReviewBatchAction.resolve,
        isCancelled: () => stop,
        onProgress: (done, _) => stop = done == 1,
      );
      expect(result.cancelled, true);
      expect(result.changes, hasLength(1));
      expect(result.requested, 3);
      expect(latest().where((a) => a.resolved), hasLength(1));
      expect((await c.undoPdfReviewBatch(result)).changes, hasLength(1));
      expect(latest().every((a) => !a.resolved), true);
    },
  );

  test(
    'partial failure preserves committed notes, failed originals and busy recovery',
    () async {
      final result = await c.changePdfReviews(
        source,
        marks,
        PdfReviewBatchAction.resolve,
        onProgress: (done, _) => store.failWrites = done >= 1,
      );
      expect(result.changes, hasLength(1));
      expect(result.failures, hasLength(2));
      expect(c.dirty, isEmpty);
      store.failWrites = false;
      final retry = await c.changePdfReviews(
        source,
        latest(),
        PdfReviewBatchAction.resolve,
      );
      expect(retry.changes, hasLength(2));
      expect(retry.unchanged, 1);
      expect((await c.undoPdfReviewBatch(retry)).changes, hasLength(2));
    },
  );

  test(
    'stale source, dirty draft, future review metadata and page comments have explicit outcomes',
    () async {
      final comment = (await c.createPdfPageComment(
        source.id,
        source.properties['checksum'] as String,
        1,
        'Page note',
      ))!;
      final result = await c.changePdfReviews(source, [
        PdfAnnotation(comment),
      ], PdfReviewBatchAction.strikeout);
      expect(result.changes, isEmpty);
      expect(result.failures, hasLength(1));
      c.edit(marks.first.object.id, body: 'Unsaved writing');
      final dirty = await c.changePdfReviews(source, [
        PdfAnnotation(c.find(marks.first.object.id)!),
      ], PdfReviewBatchAction.resolve);
      expect(dirty.failures, hasLength(1));
      expect(c.find(marks.first.object.id)!.body, 'Unsaved writing');
      await c.flushAll();
      marks = latest();
      await c.changeAttachmentSource(
        source,
        name: 'Replacement.pdf',
        bytes: researchPdf(illustrated: true),
      );
      expect(
        (await c.changePdfReviews(
          source,
          marks,
          PdfReviewBatchAction.resolve,
        )).failures,
        hasLength(3),
      );
      expect(
        (await c.changePdfReviews(
          c.find(source.id)!,
          marks,
          PdfReviewBatchAction.trash,
        )).changes,
        hasLength(3),
      );
    },
  );

  test(
    'a concurrent batch is refused while the first write is pending',
    () async {
      final gate = Completer<void>();
      store.writeGate = gate.future;
      final pending = c.changePdfReviews(
        source,
        marks,
        PdfReviewBatchAction.resolve,
      );
      final second = await c.changePdfReviews(
        source,
        marks,
        PdfReviewBatchAction.trash,
      );
      expect(second.changes, isEmpty);
      expect(second.failures, hasLength(3));
      gate.complete();
      store.writeGate = null;
      expect((await pending).changes, hasLength(3));
    },
  );

  test('batch commands and original PDF survive native restart', () async {
    final root = await Directory.systemTemp.createTemp(
      'orbit-review-workspace-',
    );
    final native = WorkspaceRepository(
      store: NativeWorkspaceStore(),
      index: MemoryObjectIndex(),
    );
    final controller = WorkspaceController()
      ..repository = native
      ..hasWorkspace = true
      ..loading = false;
    try {
      await native.initialize(path: root.path);
      final pdf = await native.importAttachment(
        name: 'Original.pdf',
        bytes: researchPdf(),
      );
      controller.mergeRepositoryObjects();
      final note = (await controller.createPdfHighlight(
        pdf.id,
        pdf.properties['checksum'] as String,
        'Keep evidence',
        region(),
      ))!;
      final changed = await controller.changePdfReviews(
        pdf,
        [PdfAnnotation(note)],
        PdfReviewBatchAction.color,
        color: 0xff22c55e,
      );
      expect(changed.changes, hasLength(1));
      controller.cancelAllTimers();
      await native.close();
      await native.initialize(path: root.path);
      controller.mergeRepositoryObjects();
      expect(PdfAnnotation(controller.find(note.id)!).color, 0xff22c55e);
      expect(controller.find(note.id)!.body, note.body);
      expect(
        await native.readAttachment(pdf.properties['contentRef'] as String),
        researchPdf(),
      );
    } finally {
      controller.cancelAllTimers();
      await native.close();
      await root.delete(recursive: true);
    }
  });

  List<PdfAnnotation> samples(int count) => [
    for (var i = 0; i < count; i++)
      PdfAnnotation(linkedNote('item-$i').copyWith(title: 'Item $i')),
  ];
  Widget host(Widget child, {double scale = 1}) => MaterialApp(
    theme: orbitDarkTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  );

  test(
    'unknown review versions and invalid colors are retained; duplicate selections commit once',
    () async {
      final future = PdfAnnotation(
        marks.first.object.copyWith(
          properties: {
            ...marks.first.object.properties,
            'pdfReview': {'version': 2, 'future': 42},
          },
        ),
      );
      expect(changedPdfReview(future, PdfReviewBatchAction.resolve), isNull);
      expect(
        changedPdfReview(marks.first, PdfReviewBatchAction.color, color: -1),
        isNull,
      );
      final result = await c.changePdfReviews(source, [
        marks.first,
        marks.first,
      ], PdfReviewBatchAction.resolve);
      expect(result.requested, 1);
      expect(result.changes, hasLength(1));
      final undo = await c.undoPdfReviewBatch(result, isCancelled: () => true);
      expect(undo.cancelled, true);
      expect(undo.changes, isEmpty);
      expect(latest().first.resolved, true);
      expect((await c.undoPdfReviewBatch(result)).changes, hasLength(1));
    },
  );

  test(
    'review board references the same source and notes; board deletion preserves evidence',
    () async {
      final beforeCount = c.objects.length;
      final board = await c.createPdfReviewBoard(source, [
        marks[1],
        marks[0],
        marks[1],
      ]);
      expect(board, isNotNull);
      expect(c.objects.length, beforeCount + 1);
      final scene = CanvasScene.fromJson(board!.data);
      expect(scene.elements, hasLength(3));
      expect(scene.elements.map((e) => e.objectId).toSet(), {
        source.id,
        marks[0].object.id,
        marks[1].object.id,
      });
      expect(scene.elements.every((e) => !e.data.containsKey('quote')), true);
      expect(board.properties['sourcePdfId'], source.id);
      expect(await c.trash(board.id), true);
      expect(c.find(source.id)!.isDeleted, false);
      expect(c.activeObjects.where(PdfAnnotation.isAnnotation), hasLength(3));
      c.edit(marks[0].object.id, body: 'Newer evidence');
      expect(await c.createPdfReviewBoard(source, [marks[0]]), isNull);
      await c.flushAll();
    },
  );

  testWidgets(
    'keyboard range selection exports only selected items and filters clear hidden selection',
    (tester) async {
      await desktop(tester);
      List<PdfAnnotation>? copied;
      final navigated = <String>[];
      await tester.pumpWidget(
        host(
          PdfReviewPanel(
            annotations: samples(4),
            page: 1,
            checksum: 'v1',
            expanded: true,
            onNavigate: (a) => navigated.add(a.object.id),
            onClose: () {},
            onCopy: (a) => copied = a,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip(
          'Focus review items · arrows, Shift+arrows, Space, Ctrl+A, Delete',
        ),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);
      await tester.tap(find.byTooltip('Copy selected review as Markdown'));
      expect(copied!.map((a) => a.object.id), ['item-0', 'item-1', 'item-2']);
      expect(navigated, ['item-0', 'item-1', 'item-2']);
      await tester.enterText(find.byType(TextField), 'Item 3');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Copy selected review as Markdown'), findsNothing);
      await tester.tap(find.byTooltip('Copy filtered review as Markdown'));
      expect(copied!.single.object.id, 'item-3');
    },
  );

  testWidgets(
    'pagination does not limit selected export to the rendered page',
    (tester) async {
      await desktop(tester);
      List<PdfAnnotation>? copied;
      await tester.pumpWidget(
        host(
          PdfReviewPanel(
            annotations: samples(120),
            page: 1,
            checksum: 'v1',
            expanded: true,
            onNavigate: (_) {},
            onClose: () {},
            onCopy: (a) => copied = a,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all filtered'));
      await tester.pumpAndSettle();
      expect(find.text('120 selected'), findsOneWidget);
      await tester.tap(find.byTooltip('Copy selected review as Markdown'));
      expect(copied, hasLength(120));
      await tester.tap(find.text('Next results'));
      await tester.pumpAndSettle();
      expect(find.text('Results 51–100 of 120'), findsOneWidget);
    },
  );

  testWidgets(
    'bulk action feedback, cancellation and Undo remain reachable with enlarged text',
    (tester) async {
      await prepareCapture(tester);
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final items = samples(2);
      var calls = 0;
      var restored = false;
      await tester.pumpWidget(
        host(
          PdfReviewPanel(
            annotations: items,
            page: 1,
            checksum: 'v1',
            expanded: true,
            onNavigate: (_) {},
            onClose: () {},
            onCopy: (_) {},
            onBatch:
                (selected, action, {color, isCancelled, onProgress}) async {
                  calls++;
                  onProgress?.call(1, 2);
                  return PdfReviewBatchResult(
                    workspaceId: 'ws',
                    fileId: 'paper',
                    action: action,
                    changes: [
                      PdfReviewChange(
                        items[0].object,
                        items[0].object.copyWith(revision: 2),
                      ),
                    ],
                    requested: 2,
                    failures: {'item-1': 'Retained newer edit'},
                  );
                },
            onUndoBatch: (result, {isCancelled, onProgress}) async {
              restored = true;
              return PdfReviewBatchResult(
                workspaceId: 'ws',
                fileId: 'paper',
                action: result.action,
                changes: result.changes,
              );
            },
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await captureUi(tester, 'pdf-review-workspace-large-text');
      await tester.ensureVisible(find.text('Select all filtered'));
      await tester.tap(find.text('Select all filtered'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byTooltip('Change selected review items'),
      );
      await tester.tap(find.byTooltip('Change selected review items'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark resolved'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('1 saved'), findsOneWidget);
      await tester.ensureVisible(find.text('Undo batch (1)'));
      await tester.tap(find.text('Undo batch (1)'));
      await tester.pumpAndSettle();
      expect(restored, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reader expansion reuses selection and review state without duplicating keys',
    (tester) async {
      await desktop(tester);
      await tester.pumpWidget(
        host(
          OrbitPdfReader(
            objectId: 'paper',
            title: 'Evidence',
            checksum: 'v1',
            annotations: samples(4),
            loadBytes: () async => researchPdf(),
            onOpenOriginal: () {},
            onOpenExternal: (_) {},
            onReadingState: (_, _) {},
            onQuote: (_, _) async {},
            onBookmarks: (_) {},
          ),
        ),
      );
      await waitNative(tester, () => ready(tester));
      await tester.tap(find.byTooltip('Highlights and comments'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Select all filtered'));
      await tester.tap(find.text('Select all filtered'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Expand review workspace'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Expand review workspace'));
      await tester.pumpAndSettle();
      expect(find.text('4 selected'), findsOneWidget);
      expect(find.byType(PdfReviewPanel), findsOneWidget);
      await tester.tap(find.byTooltip('Collapse review workspace'));
      await tester.pumpAndSettle();
      expect(find.text('4 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: !nativeReady,
  );
}
