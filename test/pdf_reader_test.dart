import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/domain/research_document.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/domain/wiki_links.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'support/pdf_fixture.dart';
import 'support/capture_ui.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pdfiumReady = await initPdfTesting();
  test(
    'page references resolve renamed IDs and preserve page in rendered links',
    () {
      const reference = ObjectReference('file-id', page: 2);
      final markdown = reference.markdown('Original filename');
      const targets = [NoteLinkTarget(id: 'file-id', title: 'Renamed PDF')];
      final link = parseWikiLinks(markdown).single;
      expect(resolveWikiLink(link, targets).target?.id, 'file-id');
      expect(
        wikiLinksToMarkdown(markdown, targets),
        contains('orbit-object:file-id#page=2'),
      );
      expect(ObjectReference.parse('file-id#page=0').page, isNull);
      expect(ObjectReference.parse('file-id#page=99999999').page, isNull);
      expect(
        reference.quoteMarkdown('Original', 'line one\nline two'),
        startsWith('> line one\n> line two\n\n'),
      );
    },
  );

  Future<void> settleNative(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 150 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      done(),
      isTrue,
      reason: find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .join(' | '),
    );
  }

  testWidgets(
    'real PDF renders, navigates, searches, bookmarks and copies page links',
    (tester) async {
      await prepareCapture(tester);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var clipboard = '';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
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
      var bookmarks = <int>[];
      var page = 1;
      var annotations = <PdfAnnotation>[];
      var rawRegions = <CanvasElement>[];
      var checksum = 'version-one';
      late StateSetter refreshReader;
      var openedAnnotation = '';
      ResearchDocument? createdDocument;
      int? documentPage;
      String? documentQuote;
      var documentSaveSucceeds = true;
      var readOnly = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) {
                refreshReader = update;
                return OrbitPdfReader(
                  objectId: 'paper',
                  title: 'Research',
                  checksum: checksum,
                  readOnly: readOnly,
                  annotations: annotations,
                  onOpenAnnotation: (id) => openedAnnotation = id,
                  onCreateDocument: (document, page, quote) async {
                    createdDocument = document;
                    documentPage = page;
                    documentQuote = quote;
                    return documentSaveSucceeds;
                  },
                  onHighlight: (quote, regions, comment) async {
                    rawRegions = regions;
                    final now = DateTime.utc(2026);
                    update(
                      () => annotations = [
                        PdfAnnotation(
                          UniversalObject(
                            id: 'highlight',
                            workspaceId: 'test',
                            typeId: 'orbit.note',
                            title: 'Highlight',
                            createdAt: now,
                            updatedAt: now,
                            body: comment,
                            properties: {
                              'pdfHighlightVersion': 1,
                              'pdfSource': {
                                'objectId': 'paper',
                                'checksum': checksum,
                                'page': 1,
                                'quote': quote,
                                'regions': regions.map((r) => r.data).toList(),
                              },
                            },
                          ),
                        ),
                      ],
                    );
                    return true;
                  },
                  loadBytes: () async => researchPdf(),
                  onOpenOriginal: () {},
                  onOpenExternal: (_) {},
                  onReadingState: (p, _) => page = p,
                  onQuote: (_, _) async {},
                  bookmarks: bookmarks,
                  onBookmarks: (value) => update(() => bookmarks = value),
                );
              },
            ),
          ),
        ),
      );
      await settleNative(
        tester,
        () =>
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (w) => w is IconButton && w.tooltip == 'Next page',
                  ),
                )
                .onPressed !=
            null,
      );
      await tester.tap(find.byTooltip('Next page'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(page, 2);
      await tester.tap(find.byTooltip('Create document from PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Game design decision'));
      await tester.pumpAndSettle();
      expect(createdDocument, ResearchDocument.design);
      expect(documentPage, 2);
      expect(documentQuote, '');
      await tester.tap(find.byTooltip('Bookmark page'));
      await tester.pump();
      expect(bookmarks, [2]);
      await tester.tap(find.byTooltip('Copy page reference'));
      await tester.pump();
      expect(clipboard, '[[paper#page=2|Research · p. 2]]');
      await tester.tap(find.byTooltip('Find in PDF · Ctrl+F'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Find text in this PDF'),
        'research',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await settleNative(
        tester,
        () => find.text('2 matches').evaluate().isNotEmpty,
      );
      await tester.tap(find.byTooltip('Page thumbnails'));
      await tester.pump();
      expect(find.text('1'), findsWidgets);
      final pdf = tester.widget<PdfViewer>(find.byType(PdfViewer));
      final delegate = pdf.controller!.textSelectionDelegate;
      await tester.runAsync(delegate.selectAllText);
      await tester.pump();
      await tester.tap(find.byTooltip('Create document from PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Playtest finding'));
      await tester.pumpAndSettle();
      expect(createdDocument, ResearchDocument.playtest);
      expect(documentPage, 1);
      expect(documentQuote, isNotEmpty);
      documentSaveSucceeds = false;
      await tester.tap(find.byTooltip('Create document from PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Research note'));
      await tester.pumpAndSettle();
      expect(
        find.text('Document could not be saved. Your PDF is unchanged.'),
        findsOneWidget,
      );
      refreshReader(() => readOnly = true);
      await tester.pump();
      expect(
        tester
            .widget<PopupMenuButton<ResearchDocument>>(
              find.byType(PopupMenuButton<ResearchDocument>),
            )
            .enabled,
        isFalse,
      );
      refreshReader(() => readOnly = false);
      await tester.pump();
      final menu = <ContextMenuButtonItem>[];
      pdf.params.customizeContextMenuItems!(
        PdfViewerContextMenuBuilderParams(
          isTextSelectionEnabled: true,
          anchorA: Offset.zero,
          textSelectionDelegate: delegate,
          dismissContextMenu: () {},
          contextMenuFor: PdfViewerPart.selectedText,
        ),
        menu,
      );
      menu
          .singleWhere((item) => item.label == 'Highlight and comment')
          .onPressed!();
      await settleNative(
        tester,
        () => find.text('Comment on this passage').evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'What would you like to remember?'),
        'Compare both pages.',
      );
      await tester.tap(find.text('Save highlight'));
      await tester.pumpAndSettle();
      await settleNative(tester, () => annotations.isNotEmpty);
      expect(
        rawRegions.every(PdfAnnotation.validRegion),
        isTrue,
        reason: rawRegions.map((r) => r.data).toString(),
      );
      expect(annotations.single.regions, isNotEmpty);
      expect(annotations.single.regions.map((r) => r.data['page']).toSet(), {
        1,
        2,
      });
      expect(annotations.single.object.body, 'Compare both pages.');
      expect(find.text('Highlights · 1'), findsOneWidget);
      final filter = find.widgetWithText(
        TextField,
        'Filter highlights and comments',
      );
      await tester.enterText(filter, 'COMPARE BOTH');
      await tester.pump();
      expect(
        find.byTooltip('Open highlight note and comments'),
        findsOneWidget,
      );
      await tester.enterText(filter, 'unmatched phrase');
      await tester.pump();
      expect(find.byTooltip('Open highlight note and comments'), findsNothing);
      await tester.tap(find.byTooltip('Close highlights'));
      await tester.pump();
      await tester.tap(find.byTooltip('Highlights and comments'));
      await tester.pump();
      expect(find.text('unmatched phrase'), findsOneWidget);
      await tester.enterText(filter, '');
      await tester.pump();
      await captureUi(tester, 'pdf-highlights');
      await tester.tap(find.byTooltip('Open highlight note and comments'));
      expect(openedAnnotation, 'highlight');
      refreshReader(() => checksum = 'replacement');
      await tester.pump();
      expect(
        find.text('PDF version changed · review source before re-anchoring'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
    skip: !pdfiumReady,
  );

  testWidgets(
    'phone visual comfort retains illustrated PDF and offers optional text reading',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: OrbitPdfReader(
              objectId: 'phone',
              title: 'Research',
              loadBytes: () async => researchPdf(illustrated: true),
              onOpenOriginal: () {},
              onOpenExternal: (_) {},
              onReadingState: (_, _) {},
              onQuote: (_, _) async {},
              onBookmarks: (_) {},
            ),
          ),
        ),
      );
      await settleNative(
        tester,
        () => find.byTooltip('Original page').evaluate().isNotEmpty,
      );
      expect(find.byType(SelectableText), findsNothing);
      final viewer = tester
          .widget<PdfViewer>(find.byType(PdfViewer))
          .controller!;
      final fullWidthZoom =
          (viewer.viewSize.width - 16) / viewer.layout.pageLayouts.first.width;
      await settleNative(
        tester,
        () => viewer.currentZoom > fullWidthZoom * 1.02,
      );
      await captureUi(tester, 'pdf-phone-visual');
      await tester.tap(find.byTooltip('Text-only reading'));
      await tester.pump();
      await settleNative(
        tester,
        () => find.byType(SelectableText).evaluate().isNotEmpty,
      );
      expect(find.byTooltip('Original page'), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        contains('Orbit research page one'),
      );
      await tester.tap(find.byTooltip('Larger reading text'));
      await tester.pump();
      expect(find.text('Page 1 · 22 pt'), findsOneWidget);
      await tester.tap(find.byTooltip('Return to visual reading'));
      await tester.pump();
      expect(find.byType(SelectableText), findsNothing);
      await tester.tap(find.byTooltip('Original page'));
      await tester.pump();
      expect(find.byTooltip('Comfort reading'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
    skip: !pdfiumReady,
  );

  testWidgets('corrupt PDF shows a recoverable error without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrbitPdfReader(
            objectId: 'corrupt',
            title: 'Corrupt',
            loadBytes: () async => Uint8List.fromList('invalid PDF'.codeUnits),
            onOpenOriginal: () {},
            onOpenExternal: (_) {},
            onReadingState: (_, _) {},
            onQuote: (_, _) async {},
            onBookmarks: (_) {},
          ),
        ),
      ),
    );
    await settleNative(
      tester,
      () =>
          find
              .text(
                'This PDF could not be opened. Its original bytes are unchanged.',
              )
              .evaluate()
              .isNotEmpty ||
          find.text('Unlock PDF').evaluate().isNotEmpty,
    );
    if (find.text('Unlock PDF').evaluate().isNotEmpty) {
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await settleNative(
      tester,
      () => find
          .text(
            'This PDF could not be opened. Its original bytes are unchanged.',
          )
          .evaluate()
          .isNotEmpty,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, skip: !pdfiumReady);

  testWidgets('missing PDF has retry and external-open fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrbitPdfReader(
            objectId: 'missing',
            title: 'Missing',
            loadBytes: () async => null,
            onOpenOriginal: () {},
            onOpenExternal: (_) {},
            onReadingState: (_, _) {},
            onQuote: (_, _) async {},
            onBookmarks: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Open original externally'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
