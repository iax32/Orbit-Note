import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'package:orbit_note/features/pdf/pdf_review_panel.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'pdf_reader_reliability_test.dart'
    show desktop, ready, viewer, waitNative, linkedNote;
import 'support/memory_store.dart';
import 'support/pdf_fixture.dart';

Widget pdfHost(Widget child) => MaterialApp(
  theme: orbitDarkTheme(),
  home: Scaffold(body: child),
);

PdfAnnotation mark(
  String id,
  int page, {
  int count = 1,
  String file = 'paper',
  String checksum = 'v1',
  bool comment = false,
}) => PdfAnnotation(
  UniversalObject(
    id: id,
    workspaceId: 'ws',
    typeId: 'orbit.note',
    title: id,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    body: 'Keep this comment',
    properties: {
      'pdfHighlightVersion': 1,
      'future': {'keep': true},
      'pdfSource': {
        'objectId': file,
        'checksum': checksum,
        'page': page,
        'quote': 'Evidence $id',
        if (comment) 'kind': 'pageComment',
        'regions': [
          for (var i = 0; i < count; i++)
            {
              'id': '$id:$i',
              'type': 'rectangle',
              'page': page,
              'x': .1 + i * .03,
              'y': .2,
              'width': .02,
              'height': .02,
              'color': 0xffeab308,
            },
        ],
      },
    },
  ),
);

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final nativeReady = await initPdfTesting();
  test(
    'large annotation sets expose only the current page and retain immutable geometry',
    () {
      final annotations = [
        for (var i = 0; i < 2000; i++) mark('$i', i % 200 + 1, count: 8),
      ];
      final index = PdfAnnotationIndex(annotations, 'paper', 'v1');
      expect(index.markupForPage(1), hasLength(80));
      expect(index.markupForPage(199), hasLength(80));
      expect(index.markupForPage(999), isEmpty);
      expect(index.hitTest(1, .11, .21)?.object.id, '1800');
      expect(index.hitTest(2, .9, .9), isNull);
      expect(
        index.matches(
          annotations.map((a) => PdfAnnotation(a.object)).toList(),
          'paper',
          'v1',
        ),
        true,
      );
      expect(() => index.markupForPage(1).clear(), throwsUnsupportedError);
      expect(() => annotations.first.regions.clear(), throwsUnsupportedError);
      final updated = PdfAnnotationIndex(
        [...annotations.map((a) => PdfAnnotation(a.object)), mark('added', 1)],
        'paper',
        'v1',
        previous: index,
      );
      expect(updated.markupForPage(1), hasLength(81));
      expect(
        identical(
          updated.markupForPage(1).first.region,
          index.markupForPage(1).first.region,
        ),
        true,
      );
      final changed = PdfAnnotation(
        annotations.first.object.copyWith(
          properties: {
            ...annotations.first.object.properties,
            'pdfSource': {
              ...annotations.first.source,
              'regions': annotations.first.regions
                  .map((r) => {...r.data, 'color': 0xff22c55e})
                  .toList(),
            },
          },
        ),
      );
      final recolored = PdfAnnotationIndex(
        [changed, ...annotations.skip(1)],
        'paper',
        'v1',
        previous: updated,
      );
      expect(recolored.markupForPage(1).first.region.color, 0xff22c55e);
      expect(index.markupForPage(1).first.region.color, 0xffeab308);
    },
  );
  test(
    'page lookup excludes other files, replaced sources and deleted notes; edits replace snapshots',
    () {
      final a = mark('A', 1);
      final items = [
        a,
        mark('other', 1, file: 'another'),
        mark('stale', 1, checksum: 'old'),
        PdfAnnotation(
          mark('trash', 1).object.copyWith(deletedAt: DateTime.utc(2026)),
        ),
        mark('comment', 2, comment: true),
      ];
      final index = PdfAnnotationIndex(items, 'paper', 'v1');
      expect(index.markupForPage(1).map((r) => r.annotation.object.id), ['A']);
      expect(index.commentsForPage(1), isEmpty);
      expect(index.commentsForPage(2).single.object.id, 'comment');
      final changed = PdfAnnotation(a.object.copyWith(body: 'New comment'));
      expect(index.matches([changed, ...items.skip(1)], 'paper', 'v1'), false);
      expect(index.matches(items, 'paper', 'replacement'), false);
      expect(
        PdfAnnotationIndex(items, 'paper', 'replacement').markupForPage(1),
        isEmpty,
      );
    },
  );

  group('revision-checked annotation Trash', () {
    late WorkspaceRepository repo;
    late WorkspaceController c;
    late MemoryStore store;
    late UniversalObject file;
    late PdfAnnotation annotation;
    setUp(() async {
      store = MemoryStore();
      repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
      await repo.initialize();
      c = WorkspaceController()
        ..repository = repo
        ..hasWorkspace = true
        ..loading = false;
      file = await repo.importAttachment(
        name: 'source.pdf',
        bytes: researchPdf(),
      );
      c.mergeRepositoryObjects();
      final note = (await c.createPdfHighlight(
        file.id,
        file.properties['checksum'] as String,
        'Evidence',
        mark('r', 1).regions,
        comment: 'Keep me',
      ))!;
      annotation = PdfAnnotation(note);
    });
    tearDown(() async {
      c.cancelAllTimers();
      await repo.close();
    });
    test(
      'delete and Undo retain one identity, comments and original bytes',
      () async {
        final originalBytes = await repo.readAttachment(
          file.properties['contentRef'] as String,
        );
        c.session.tabs = [annotation.object.id, file.id];
        c.session.activeId = file.id;
        c.session.secondaryId = annotation.object.id;
        final result = await c.deletePdfReview(annotation);
        expect(result, isNotNull, reason: c.error);
        final deleted = result!;
        expect(deleted.object.isDeleted, true);
        expect(c.session.tabs, [file.id]);
        expect(c.session.secondaryId, isNull);
        expect(c.activeObjects.where(PdfAnnotation.isAnnotation), isEmpty);
        expect(deleted.object.body, annotation.object.body);
        expect(deleted.object.properties, annotation.object.properties);
        expect(await c.restorePdfReview(deleted), true);
        expect(
          c.activeObjects.where(PdfAnnotation.isAnnotation).single.id,
          annotation.object.id,
        );
        expect(
          await repo.readAttachment(file.properties['contentRef'] as String),
          originalBytes,
        );
      },
    );
    test('failed delete and restore retain data and can retry', () async {
      store.failWrites = true;
      expect(await c.deletePdfReview(annotation), isNull);
      expect(c.find(annotation.object.id)!.isDeleted, false);
      store.failWrites = false;
      final deleted = (await c.deletePdfReview(annotation))!;
      store.failWrites = true;
      expect(await c.restorePdfReview(deleted), false);
      expect(c.find(annotation.object.id)!.isDeleted, true);
      store.failWrites = false;
      expect(await c.restorePdfReview(deleted), true);
    });
    test(
      'stale dialogs, dirty writing and retained competing drafts prevent deletion',
      () async {
        c.edit(annotation.object.id, body: 'Newer writing');
        expect(
          await c.deletePdfReview(PdfAnnotation(c.find(annotation.object.id)!)),
          isNull,
        );
        await c.flushAll();
        expect(await c.deletePdfReview(annotation), isNull);
        final latest = PdfAnnotation(c.find(annotation.object.id)!);
        c.editorDraftConflicts['pane'] = EditorDraftConflict(
          objectId: latest.object.id,
          title: latest.object.title,
          base: 'base',
          body: 'Other pane',
          workspace: repo.workspaceId,
        );
        expect(await c.deletePdfReview(latest), isNull);
        expect(c.find(latest.object.id)!.body, 'Newer writing');
        c.editorDraftConflicts.clear();
        final deleted = (await c.deletePdfReview(latest))!;
        await repo.save(
          deleted.object.copyWith(body: 'New retained Trash content'),
        );
        await c.refresh();
        expect(await c.restorePdfReview(deleted), false);
        expect(c.find(deleted.object.id)!.body, 'New retained Trash content');
        expect(c.find(deleted.object.id)!.isDeleted, true);
      },
    );
    test(
      'stale-source marks and page comments can be removed without rewriting the source',
      () async {
        final note = (await c.createPdfPageComment(
          file.id,
          file.properties['checksum'] as String,
          2,
          'Diagram comment',
        ))!;
        final source = PdfAnnotation(note);
        expect((await c.deletePdfReview(source))!.isPageComment, true);
        expect(
          await c.changeAttachmentSource(
            file,
            name: 'new.pdf',
            bytes: researchPdf(illustrated: true),
          ),
          true,
        );
        final replacement = c.find(file.id)!.properties['checksum'];
        expect(replacement, isNot(file.properties['checksum']));
        expect(await c.deletePdfReview(annotation), isNotNull);
        expect(c.find(file.id)!.properties['checksum'], replacement);
      },
    );
  });

  test(
    'native delete, restart and restore preserve authored annotation metadata and PDF bytes',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-pdf-markup-');
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      final c = WorkspaceController()..repository = repo;
      try {
        await repo.initialize(path: root.path);
        c.hasWorkspace = true;
        c.loading = false;
        final bytes = researchPdf();
        final file = await repo.importAttachment(
          name: 'source.pdf',
          bytes: bytes,
        );
        c.mergeRepositoryObjects();
        final note = (await c.createPdfHighlight(
          file.id,
          file.properties['checksum'] as String,
          'Keep evidence',
          mark('r', 1).regions,
        ))!;
        c.edit(
          note.id,
          properties: {
            ...note.properties,
            'future': {'keep': true},
            'pdfSource': {...PdfAnnotation(note).source, 'unknownSource': 42},
          },
        );
        await c.flushAll();
        final before = c.find(note.id)!;
        expect(await c.deletePdfReview(PdfAnnotation(before)), isNotNull);
        await repo.close();
        await repo.initialize(path: root.path);
        c.mergeRepositoryObjects();
        final deleted = c.find(note.id)!;
        expect(deleted.isDeleted, true);
        expect(deleted.properties, before.properties);
        expect(await c.restorePdfReview(PdfAnnotation(deleted)), true);
        await repo.close();
        await repo.initialize(path: root.path);
        c.mergeRepositoryObjects();
        expect(c.find(note.id)!.isDeleted, false);
        expect(c.find(note.id)!.body, before.body);
        expect(c.find(note.id)!.properties, before.properties);
        expect(
          await repo.readAttachment(file.properties['contentRef'] as String),
          bytes,
        );
      } finally {
        c.cancelAllTimers();
        await repo.close();
        await root.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'plain highlighting previews while saving, retries failures and keeps viewport stable',
    (tester) async {
      await desktop(tester);
      var gate = Completer<bool>();
      var annotations = <PdfAnnotation>[];
      List<CanvasElement>? selected;
      late StateSetter update;
      await tester.pumpWidget(
        pdfHost(
          StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return OrbitPdfReader(
                objectId: 'paper',
                title: 'Evidence',
                checksum: 'v1',
                annotations: annotations,
                loadBytes: () async => researchPdf(),
                onOpenOriginal: () {},
                onOpenExternal: (_) {},
                onReadingState: (_, _) {},
                onQuote: (_, _) async {},
                onBookmarks: (_) {},
                onHighlight: (quote, regions, comment) async {
                  selected = regions;
                  final saved = await gate.future;
                  if (saved) {
                    update(
                      () => annotations = [
                        PdfAnnotation(
                          linkedNote('new').copyWith(
                            properties: {
                              ...linkedNote('new').properties,
                              'pdfSource': {
                                'objectId': 'paper',
                                'checksum': 'v1',
                                'page': 1,
                                'quote': quote,
                                'regions': regions.map((r) => r.data).toList(),
                              },
                            },
                          ),
                        ),
                      ],
                    );
                  }
                  return saved;
                },
              );
            },
          ),
        ),
      );
      await waitNative(tester, () => ready(tester));
      final pdf = viewer(tester), controller = viewer(tester).controller!;
      final delegate = controller.textSelectionDelegate;
      await tester.runAsync(delegate.selectAllText);
      await tester.pumpAndSettle();
      final height = controller.viewSize.height, zoom = controller.currentZoom;
      final matrix = List<double>.of(controller.value.storage);
      void highlight() {
        final menu = <ContextMenuButtonItem>[];
        viewer(tester).params.customizeContextMenuItems!(
          PdfViewerContextMenuBuilderParams(
            isTextSelectionEnabled: true,
            anchorA: Offset.zero,
            textSelectionDelegate: delegate,
            dismissContextMenu: () {},
            contextMenuFor: PdfViewerPart.selectedText,
          ),
          menu,
        );
        menu.singleWhere((i) => i.label == 'Highlight').onPressed!();
      }

      highlight();
      await waitNative(tester, () => selected != null);
      final count = selected!.where((r) => r.data['page'] == 1).length;
      expect(count, greaterThan(0));
      void paint(Canvas canvas) => viewer(tester).params.pagePaintCallbacks![1](
        canvas,
        const Rect.fromLTWH(0, 0, 400, 300),
        controller.document.pages.first,
      );
      expect(paint, paintsExactlyCountTimes(#drawRRect, count));
      expect(find.textContaining('Highlights ·'), findsNothing);
      gate.complete(false);
      await tester.pumpAndSettle();
      expect(delegate.hasSelectedText, true);
      expect(paint, paintsNothing);
      expect(
        find.textContaining('Highlight could not be saved'),
        findsOneWidget,
      );
      selected = null;
      gate = Completer<bool>();
      highlight();
      await waitNative(tester, () => selected != null);
      gate.complete(true);
      await waitNative(tester, () => !delegate.hasSelectedText);
      await tester.pumpAndSettle();
      expect(identical(viewer(tester).controller, pdf.controller), true);
      expect(controller.viewSize.height, height);
      expect(controller.currentZoom, closeTo(zoom, .0001));
      expect(controller.value.storage, matrix);
      expect(find.textContaining('Highlights ·'), findsNothing);
      expect(paint, paintsExactlyCountTimes(#drawRRect, count));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !nativeReady,
  );

  testWidgets(
    'right-click delete retries safely and Undo restores the same annotation without reloading the PDF',
    (tester) async {
      await desktop(tester);
      final original = PdfAnnotation(linkedNote('A'));
      var annotations = [original];
      var allowDelete = false, restores = 0, loads = 0;
      late StateSetter update;
      await tester.pumpWidget(
        pdfHost(
          StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return OrbitPdfReader(
                objectId: 'paper',
                title: 'Evidence',
                checksum: 'v1',
                annotations: annotations,
                loadBytes: () async {
                  loads++;
                  return researchPdf();
                },
                onOpenOriginal: () {},
                onOpenExternal: (_) {},
                onReadingState: (_, _) {},
                onQuote: (_, _) async {},
                onBookmarks: (_) {},
                onDeleteReview: (a) async {
                  if (!allowDelete) return null;
                  update(() => annotations = []);
                  return PdfAnnotation(
                    a.object.copyWith(deletedAt: DateTime.utc(2026)),
                  );
                },
                onRestoreReview: (a) async {
                  expect(a.object.id, original.object.id);
                  expect(a.object.isDeleted, true);
                  restores++;
                  update(() => annotations = [original]);
                  return true;
                },
              );
            },
          ),
        ),
      );
      await waitNative(tester, () => ready(tester));
      final controller = viewer(tester).controller!,
          height = viewer(tester).controller!.viewSize.height;
      Future<void> openMenu() async {
        final page = controller.layout.pageLayouts.first;
        final point = Offset(
          page.left + page.width * .2,
          page.top + page.height * .3,
        );
        expect(
          viewer(tester).params.onGeneralTap!(
            tester.element(find.byType(PdfViewer)),
            controller,
            PdfViewerGeneralTapHandlerDetails(
              localPosition: controller.documentToLocal(point),
              documentPosition: point,
              type: PdfViewerGeneralTapType.secondaryTap,
              tapOn: PdfViewerPart.nonSelectedText,
            ),
          ),
          true,
        );
        await tester.pumpAndSettle();
      }

      await openMenu();
      await tester.tap(find.text('Delete highlight'));
      await tester.pumpAndSettle();
      expect(annotations, hasLength(1));
      expect(
        find.textContaining('Could not delete this review item'),
        findsOneWidget,
      );
      allowDelete = true;
      await openMenu();
      await tester.tap(find.text('Delete highlight'));
      await tester.pumpAndSettle();
      expect(annotations, isEmpty);
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(restores, 1);
      expect(annotations.single.object.id, 'A');
      expect(loads, 1);
      expect(identical(viewer(tester).controller, controller), true);
      expect(controller.viewSize.height, height);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !nativeReady,
  );

  testWidgets(
    'read-only changes cancel pending menu mutations and markup never consumes selection taps',
    (tester) async {
      await desktop(tester);
      final annotation = PdfAnnotation(linkedNote('A'));
      var readOnly = false, deletes = 0;
      late StateSetter update;
      await tester.pumpWidget(
        pdfHost(
          StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return OrbitPdfReader(
                objectId: 'paper',
                title: 'Evidence',
                checksum: 'v1',
                annotations: [annotation],
                readOnly: readOnly,
                loadBytes: () async => researchPdf(),
                onOpenOriginal: () {},
                onOpenExternal: (_) {},
                onReadingState: (_, _) {},
                onQuote: (_, _) async {},
                onBookmarks: (_) {},
                onDeleteReview: (a) async {
                  deletes++;
                  return PdfAnnotation(
                    a.object.copyWith(deletedAt: DateTime.utc(2026)),
                  );
                },
                onUpdateReview: (_, _, _, _, _) async => true,
              );
            },
          ),
        ),
      );
      await waitNative(tester, () => ready(tester));
      final controller = viewer(tester).controller!;
      final page = controller.layout.pageLayouts.first;
      final point = Offset(
        page.left + page.width * .2,
        page.top + page.height * .3,
      );
      bool tap(PdfViewerGeneralTapType type) =>
          viewer(tester).params.onGeneralTap!(
            tester.element(find.byType(PdfViewer)),
            controller,
            PdfViewerGeneralTapHandlerDetails(
              localPosition: controller.documentToLocal(point),
              documentPosition: point,
              type: type,
              tapOn: PdfViewerPart.nonSelectedText,
            ),
          );
      await tester.runAsync(controller.textSelectionDelegate.selectAllText);
      expect(tap(PdfViewerGeneralTapType.tap), false);
      expect(controller.textSelectionDelegate.hasSelectedText, true);
      await controller.textSelectionDelegate.clearTextSelection();
      expect(tap(PdfViewerGeneralTapType.secondaryTap), true);
      await tester.pumpAndSettle();
      update(() => readOnly = true);
      await tester.pump();
      await tester.tap(find.text('Delete highlight'));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      expect(tap(PdfViewerGeneralTapType.secondaryTap), true);
      await tester.pumpAndSettle();
      expect(find.text('Delete highlight'), findsNothing);
      expect(find.text('Edit color, style and comment'), findsNothing);
      await tester.tap(find.text('Highlight details'));
      await tester.pumpAndSettle();
      expect(find.text('Delete highlight'), findsNothing);
      expect(find.text('Edit review'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !nativeReady,
  );

  testWidgets(
    'cancelled passage comments keep selection and do not report a failed save',
    (tester) async {
      await desktop(tester);
      var saves = 0;
      await tester.pumpWidget(
        pdfHost(
          OrbitPdfReader(
            objectId: 'paper',
            title: 'Evidence',
            checksum: 'v1',
            loadBytes: () async => researchPdf(),
            onOpenOriginal: () {},
            onOpenExternal: (_) {},
            onReadingState: (_, _) {},
            onQuote: (_, _) async {},
            onBookmarks: (_) {},
            onHighlight: (_, _, _) async {
              saves++;
              return true;
            },
          ),
        ),
      );
      await waitNative(tester, () => ready(tester));
      final delegate = viewer(tester).controller!.textSelectionDelegate;
      await tester.runAsync(delegate.selectAllText);
      final menu = <ContextMenuButtonItem>[];
      viewer(tester).params.customizeContextMenuItems!(
        PdfViewerContextMenuBuilderParams(
          isTextSelectionEnabled: true,
          anchorA: Offset.zero,
          textSelectionDelegate: delegate,
          dismissContextMenu: () {},
          contextMenuFor: PdfViewerPart.selectedText,
        ),
        menu,
      );
      menu.singleWhere((i) => i.label == 'Highlight and comment').onPressed!();
      await waitNative(
        tester,
        () => find.text('Comment on this passage').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(delegate.hasSelectedText, true);
      expect(find.textContaining('could not be saved'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !nativeReady,
  );

  testWidgets(
    'late deletion replies cannot offer Undo in a replaced PDF',
    (tester) async {
      await desktop(tester);
      final annotation = PdfAnnotation(linkedNote('A'));
      final gate = Completer<PdfAnnotation?>();
      var source = 'v1';
      late StateSetter update;
      await tester.pumpWidget(
        pdfHost(
          StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return OrbitPdfReader(
                objectId: 'paper',
                title: 'Evidence',
                checksum: source,
                annotations: [annotation],
                loadBytes: () async => researchPdf(),
                onOpenOriginal: () {},
                onOpenExternal: (_) {},
                onReadingState: (_, _) {},
                onQuote: (_, _) async {},
                onBookmarks: (_) {},
                onDeleteReview: (_) => gate.future,
                onRestoreReview: (_) async => true,
              );
            },
          ),
        ),
      );
      await waitNative(tester, () => ready(tester));
      final controller = viewer(tester).controller!;
      final page = controller.layout.pageLayouts.first;
      final point = Offset(
        page.left + page.width * .2,
        page.top + page.height * .3,
      );
      viewer(tester).params.onGeneralTap!(
        tester.element(find.byType(PdfViewer)),
        controller,
        PdfViewerGeneralTapHandlerDetails(
          localPosition: controller.documentToLocal(point),
          documentPosition: point,
          type: PdfViewerGeneralTapType.secondaryTap,
          tapOn: PdfViewerPart.nonSelectedText,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete highlight'));
      await tester.pumpAndSettle();
      update(() => source = 'v2');
      await tester.pump();
      gate.complete(
        PdfAnnotation(
          annotation.object.copyWith(deletedAt: DateTime.utc(2026)),
        ),
      );
      await waitNative(tester, () => ready(tester));
      await tester.pumpAndSettle();
      expect(identical(viewer(tester).controller, controller), false);
      expect(find.text('Undo'), findsNothing);
      expect(find.textContaining('moved to Trash'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !nativeReady,
  );

  testWidgets(
    'narrow review deletion remains accessible for stale sources and catches clipboard failures',
    (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var removed = '';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'unavailable');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: PdfReviewPanel(
                annotations: [mark('A', 1)],
                page: 1,
                checksum: 'replacement',
                onNavigate: (_) {},
                onClose: () {},
                onCopy: (_) {},
                onEdit: (_) {},
                onDelete: (a) async {
                  removed = a.object.id;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final delete = find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            w.tooltip == 'Delete review item · move note to Trash',
      );
      await tester.scrollUntilVisible(
        delete,
        100,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      expect(removed, 'A');
      final copy = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Copy quote text',
      );
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(
        find.text('Clipboard unavailable. Review unchanged.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
