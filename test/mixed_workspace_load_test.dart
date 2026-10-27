import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'pdf_markup_interactions_test.dart' show mark;
import 'pdf_reader_reliability_test.dart' show waitNative, ready;
import 'support/pdf_fixture.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = await initPdfTesting();
  testWidgets(
    'long note, 10000 Canvas items and annotated 300-page PDF coexist through edits and navigation',
    (tester) async {
      tester.view.physicalSize = const Size(2400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var body = List.generate(
        2000,
        (i) => 'Paragraph $i with **bold** and café 😀.\n\n',
      ).join();
      final board = <String, dynamic>{
        'schemaVersion': 1,
        'future-board-field': true,
        'elements': [
          for (var i = 0; i < 10000; i++)
            {
              'id': 'shape-$i',
              'type': 'rectangle',
              'x': (i % 100) * 180.0,
              'y': (i ~/ 100) * 120.0,
              'width': 120.0,
              'height': 80.0,
              'text': 'Reference $i',
            },
        ],
      };
      final originalBoard = jsonEncode(board);
      final bytes = largeResearchPdf();
      var annotations = <PdfAnnotation>[
        for (var p = 1; p <= 300; p++)
          for (var i = 0; i < 10; i++) mark('$p:$i', p),
      ];
      var loads = 0, boardWrites = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) {
                update = set;
                return Row(
                  children: [
                    Expanded(
                      child: NoteEditor(
                        noteId: 'long',
                        title: 'Long research',
                        body: body,
                        onTitleChanged: (_) {},
                        onBodyChanged: (v) => set(() => body = v),
                        spellCheckEnabled: false,
                        linkTargets: const [],
                        onOpenObject: (_) {},
                      ),
                    ),
                    Expanded(
                      child: CanvasEditor(
                        canvasId: 'board',
                        data: board,
                        camera: const {'x': 0.0, 'y': 0.0, 'zoom': 1.0},
                        onChanged: (_) => boardWrites++,
                        objects: const [],
                        onOpenObject: (_) {},
                      ),
                    ),
                    Expanded(
                      child: OrbitPdfReader(
                        objectId: 'paper',
                        title: 'Research',
                        checksum: 'v1',
                        loadBytes: () async {
                          loads++;
                          return bytes;
                        },
                        annotations: annotations,
                        onOpenOriginal: () {},
                        onOpenExternal: (_) {},
                        onReadingState: (_, _) {},
                        onQuote: (_, _) async {},
                        onBookmarks: (_) {},
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await waitNative(tester, () => ready(tester));
      expect(loads, 1);
      final paragraph = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.controller?.text.startsWith('Paragraph 0 ') ?? false),
      );
      expect(paragraph, findsOneWidget);
      await tester.enterText(paragraph, 'Edited first paragraph café 😀.');
      await tester.pump();
      expect(body, startsWith('Edited first paragraph café 😀.'));
      expect(body, contains('Paragraph 1999'));
      expect(find.byType(TextField).evaluate().length, lessThan(200));
      for (final page in [150, 300, 1, 299]) {
        final controller = tester
            .widget<PdfViewer>(find.byType(PdfViewer))
            .controller!;
        await controller.goToPage(pageNumber: page, duration: Duration.zero);
        await tester.pump();
        final canvas = find.descendant(
          of: find.byType(CanvasEditor),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
          ),
        );
        GestureBinding.instance.handlePointerEvent(
          PointerScrollEvent(
            position: tester.getCenter(canvas),
            scrollDelta: const Offset(0, 80),
          ),
        );
        update(
          () => annotations = [...annotations.skip(1), mark('new-$page', page)],
        );
        await tester.pump();
        expect(loads, 1);
        expect(tester.takeException(), isNull);
      }
      await waitNative(
        tester,
        () =>
            tester
                .widget<PdfViewer>(find.byType(PdfViewer))
                .controller!
                .pageNumber ==
            299,
      );
      expect(boardWrites, 0);
      expect(jsonEncode(board), originalBoard);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    skip: !native,
  );
}
