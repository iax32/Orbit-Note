import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'package:orbit_note/features/pdf/pdf_notes_panel.dart';
import 'support/pdf_fixture.dart';
import 'support/capture_ui.dart';

UniversalObject linkedNote(String id, {String checksum = 'v1'}) =>
    UniversalObject(
      id: id,
      workspaceId: 'ws',
      typeId: 'orbit.note',
      title: 'Research $id',
      body: 'Compare the evidence for $id.',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      properties: {
        'pdfHighlightVersion': 1,
        'pdfSource': {
          'objectId': 'paper',
          'page': 1,
          'checksum': checksum,
          'quote': 'Orbit research',
          'regions': [
            {
              'id': 'r',
              'type': 'rectangle',
              'page': 1,
              'x': .1,
              'y': .28,
              'width': .55,
              'height': .08,
            },
          ],
        },
      },
    );

Future<void> waitNative(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(done(), isTrue);
}

Future<void> desktop(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

bool ready(WidgetTester tester) => find
    .byWidgetPredicate(
      (w) =>
          w is IconButton &&
          w.tooltip == 'Fit page width' &&
          w.onPressed != null,
    )
    .evaluate()
    .isNotEmpty;
PdfViewer viewer(WidgetTester tester) =>
    tester.widget<PdfViewer>(find.byType(PdfViewer));
Widget host(OrbitPdfReader reader) => MaterialApp(
  theme: orbitDarkTheme(),
  home: Scaffold(body: reader),
);
OrbitPdfReader reader({
  Future<Uint8List?> Function()? load,
  int page = 1,
  double? zoom,
  String checksum = 'v1',
  void Function(int, double)? onReading,
  ValueChanged<String>? onOpenNote,
  List<int> bookmarks = const [],
  Map<int, String> bookmarkNames = const {},
}) => OrbitPdfReader(
  objectId: 'paper',
  title: 'Research',
  loadBytes: load ?? () async => researchPdf(),
  checksum: checksum,
  initialPage: page,
  initialZoom: zoom,
  onOpenOriginal: () {},
  onOpenExternal: (_) {},
  onReadingState: onReading ?? (_, _) {},
  onQuote: (_, _) async {},
  onBookmarks: (_) {},
  bookmarks: bookmarks,
  bookmarkNames: bookmarkNames,
  onOpenLinkedNote: onOpenNote,
);

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final nativeReady = await initPdfTesting();

  testWidgets(
    'saved pages render a real preview and open a named bookmark',
    (tester) async {
      await desktop(tester);
      await tester.pumpWidget(
        host(reader(bookmarks: [1, 2], bookmarkNames: {2: 'Evidence'})),
      );
      await waitNative(tester, () => ready(tester));
      await tester.ensureVisible(find.byTooltip('Saved pages'));
      await tester.tap(find.byTooltip('Saved pages'));
      await tester.pump(const Duration(milliseconds: 300));
      await waitNative(
        tester,
        () => find
            .byWidgetPredicate(
              (w) => w is Image && w.semanticLabel == 'Preview of page 1',
            )
            .evaluate()
            .isNotEmpty,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Find a bookmark'),
        'evidence',
      );
      await tester.pump();
      await waitNative(
        tester,
        () => find
            .byWidgetPredicate(
              (w) => w is Image && w.semanticLabel == 'Preview of page 2',
            )
            .evaluate()
            .isNotEmpty,
      );
      expect(find.byTooltip('Rename bookmark on page 2'), findsNothing);
      await tester.tap(find.text('Open page'));
      await tester.pumpAndSettle();
      expect(viewer(tester).controller!.pageNumber, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
    skip: !nativeReady,
  );

  testWidgets(
    'reading tools provide page history, custom zoom and document information',
    (tester) async {
      await desktop(tester);
      await tester.pumpWidget(host(reader()));
      await waitNative(tester, () => ready(tester));
      Future<void> tool(String name) async {
        await tester.ensureVisible(find.byTooltip('Document tools'));
        await tester.tap(find.byTooltip('Document tools'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }

      await tool('Last page');
      expect(viewer(tester).controller!.pageNumber, 2);
      await tool('Previous visited page');
      expect(viewer(tester).controller!.pageNumber, 1);
      await tool('Next visited page');
      expect(viewer(tester).controller!.pageNumber, 2);
      await tool('Document information');
      expect(find.text('Pages: 2'), findsOneWidget);
      expect(find.text('Current page: 2'), findsOneWidget);
      expect(find.textContaining('Page size:'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('PDF outline'));
      await tester.tap(find.byTooltip('PDF outline'));
      await tester.pumpAndSettle();
      expect(find.text('This PDF has no embedded outline.'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('PDF zoom and reading tools'));
      await tester.tap(find.byTooltip('PDF zoom and reading tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom zoom…'));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextField, 'Zoom percentage');
      await tester.enterText(field, '137.5');
      await tester.tap(find.text('Apply zoom'));
      await tester.pumpAndSettle();
      expect(viewer(tester).controller!.currentZoom, closeTo(1.375, .001));
      await tester.pumpWidget(host(reader(checksum: 'v2')));
      await waitNative(tester, () => ready(tester));
      await tester.ensureVisible(find.byTooltip('Document tools'));
      await tester.tap(find.byTooltip('Document tools'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<String>>(
              find.ancestor(
                of: find.text('Previous visited page'),
                matching: find.byType(PopupMenuItem<String>),
              ),
            )
            .enabled,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
    skip: !nativeReady,
  );

  testWidgets(
    'thumbnails support keyboard paging and return focus to reader',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(reader(onOpenNote: (_) {})));
      await waitNative(tester, () => ready(tester));
      await tester.ensureVisible(find.byTooltip('Page thumbnails'));
      await tester.tap(find.byTooltip('Page thumbnails'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(viewer(tester).controller!.pageNumber, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(viewer(tester).controller!.pageNumber, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(viewer(tester).controller!.pageNumber, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(viewer(tester).controller!.pageNumber, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PdfPageView), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'Find text in this PDF'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close PDF search'));
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.ensureVisible(find.byTooltip('Connected notes'));
        await tester.tap(find.byTooltip('Connected notes'));
        await tester.pumpAndSettle();
        final notesField = find.widgetWithText(
          TextField,
          'Find connected notes',
        );
        expect(
          tester.widget<TextField>(notesField).focusNode!.hasFocus,
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(notesField, findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
    skip: !nativeReady,
  );

  testWidgets('connected notes filter and open by keyboard in a short pane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? opened;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: PdfNotesPanel(
            notes: [linkedNote('A'), linkedNote('B')],
            fileId: 'paper',
            checksum: 'v1',
            onOpen: (id) => opened = id,
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.widgetWithText(TextField, 'Find connected notes');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.enterText(field, 'evidence for B');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(opened, 'B');
    opened = null;
    await tester.enterText(field, 'no matching note');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(opened, isNull);
    await tester.tap(field);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'PDF search remains usable at narrow widths and large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(body: reader()),
        ),
      );
      await waitNative(tester, () => ready(tester));
      await tester.ensureVisible(find.byTooltip('Find in PDF · Ctrl+F'));
      await tester.tap(find.byTooltip('Find in PDF · Ctrl+F'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final field = find.widgetWithText(TextField, 'Find text in this PDF');
      expect(tester.getSize(field).width, greaterThan(120));
      await tester.enterText(field, 'Orbit');
      await tester.pump();
      await tester.tap(find.byTooltip('Close PDF search'));
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
    skip: !nativeReady,
  );

  testWidgets('changing page layout preserves current page and zoom', (
    tester,
  ) async {
    await desktop(tester);
    await tester.pumpWidget(host(reader(page: 2, zoom: 1.5)));
    await waitNative(tester, () => ready(tester));
    await tester.pumpAndSettle();
    expect(viewer(tester).controller!.pageNumber, 2);
    await tester.tap(find.byTooltip('Page display mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Single page (horizontal flow)'));
    await tester.pump();
    await waitNative(tester, () => ready(tester));
    await tester.pumpAndSettle();
    expect(viewer(tester).controller!.pageNumber, 2);
    expect(viewer(tester).controller!.currentZoom, closeTo(1.5, .01));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, skip: !nativeReady);

  testWidgets(
    'retry reloads repaired bytes and same-key source replacement reloads the document',
    (tester) async {
      await desktop(tester);
      Uint8List? bytes;
      var loads = 0;
      Future<Uint8List?> load() async {
        loads++;
        return bytes;
      }

      await tester.pumpWidget(host(reader(load: load)));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      bytes = researchPdf();
      await tester.tap(find.text('Retry'));
      await waitNative(tester, () => ready(tester));
      expect(viewer(tester).controller!.pageCount, 2);
      bytes = formPdf();
      await tester.pumpWidget(host(reader(load: load, checksum: 'v2')));
      await waitNative(tester, () => ready(tester));
      expect(viewer(tester).controller!.pageCount, 1);
      expect(loads, 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
    skip: !nativeReady,
  );

  testWidgets(
    'invalid page input normalizes and immediate close retains position',
    (tester) async {
      await desktop(tester);
      var savedPage = 0;
      await tester.pumpWidget(
        host(reader(onReading: (page, _) => savedPage = page)),
      );
      await waitNative(tester, () => ready(tester));
      final pageInput = find.byWidgetPredicate(
        (w) => w is TextField && w.keyboardType == TextInputType.number,
      );
      await tester.enterText(pageInput, '9999');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.widget<TextField>(pageInput).controller!.text, '2');
      await tester.pumpWidget(const SizedBox());
      expect(savedPage, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
    skip: !nativeReady,
  );

  testWidgets(
    'clipboard failure is reported without an unhandled exception',
    (tester) async {
      await desktop(tester);
      await tester.pumpWidget(host(reader()));
      await waitNative(tester, () => ready(tester));
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
      await tester.tap(find.byTooltip('Copy page reference'));
      await tester.pumpAndSettle();
      expect(
        find.text('Clipboard unavailable. Your PDF and notes are unchanged.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
    skip: !nativeReady,
  );

  testWidgets(
    'failed passage comments retain typed text and retry the same selection',
    (tester) async {
      await desktop(tester);
      var saves = 0;
      var savedComment = '';
      final annotations = [PdfAnnotation(linkedNote('A'))];
      await tester.pumpWidget(
        host(
          OrbitPdfReader(
            objectId: 'paper',
            title: 'Research',
            checksum: 'v1',
            annotations: annotations,
            loadBytes: () async => researchPdf(),
            onOpenOriginal: () {},
            onOpenExternal: (_) {},
            onReadingState: (_, _) {},
            onQuote: (_, _) async {},
            onBookmarks: (_) {},
            onHighlight: (quote, regions, comment) async {
              expect(quote, contains('Orbit research'));
              expect(regions, isNotEmpty);
              savedComment = comment;
              return ++saves > 1;
            },
          ),
        ),
      );
      await waitNative(tester, () => ready(tester));
      final pdf = viewer(tester);
      // Existing text highlights must not build hit-test rectangles over the text.
      expect(
        pdf.params.pageOverlaysBuilder!(
          tester.element(find.byType(PdfViewer)),
          const Rect.fromLTWH(0, 0, 400, 300),
          pdf.controller!.document.pages.first,
        ),
        isEmpty,
      );
      final delegate = pdf.controller!.textSelectionDelegate;
      await tester.runAsync(delegate.selectAllText);
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
      menu.singleWhere((m) => m.label == 'Highlight and comment').onPressed!();
      await waitNative(
        tester,
        () => find.text('Comment on this passage').evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'What would you like to remember?'),
        'Keep this thought',
      );
      await tester.tap(find.text('Save highlight'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your comment is kept here'), findsOneWidget);
      expect(find.text('Keep this thought'), findsOneWidget);
      await tester.tap(find.text('Save highlight'));
      await tester.pumpAndSettle();
      expect(saves, 2);
      expect(savedComment, 'Keep this thought');
      expect(find.text('Comment on this passage'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
    skip: !nativeReady,
  );

  testWidgets(
    'connected notes filter content, warn on stale sources and open original identities',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await prepareCapture(tester);
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: RepaintBoundary(
              child: PdfNotesPanel(
                notes: [
                  linkedNote('A'),
                  linkedNote('B', checksum: 'old'),
                ],
                fileId: 'paper',
                checksum: 'v1',
                onOpen: (id) => opened = id,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Source version changed'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Find connected notes'),
        'evidence for B',
      );
      await tester.pumpAndSettle();
      expect(find.text('Research A'), findsNothing);
      await tester.tap(find.text('Research B'));
      expect(opened, 'B');
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'pdf-connected-notes');
    },
  );
}
