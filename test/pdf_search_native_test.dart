import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'package:orbit_note/platform/pdf_text_extraction.dart';
import 'support/pdf_fixture.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ready = await initPdfTesting();
  test(
    'native extraction uses the same text and offsets as rendered PDF ranges',
    () async {
      final bytes = researchPdf();
      final pages = await extractPdfText(bytes).toList();
      expect(pages.map((p) => p.number), [1, 2]);
      expect(pages[1].text, contains('Orbit research page two'));
      final document = await PdfDocument.openData(bytes);
      try {
        for (var i = 0; i < pages.length; i++) {
          final text = await document.pages[i].loadStructuredText();
          expect(text.fullText, pages[i].text);
          final start = pages[i].text.indexOf('research');
          final range = PdfPageTextRange(
            pageText: text,
            start: start,
            end: start + 8,
          );
          expect(range.enumerateFragmentBoundingRects(), isNotEmpty);
        }
      } finally {
        await document.dispose();
      }
    },
    skip: !ready,
  );

  test(
    'native extraction reports corrupt bytes instead of indexing partial text',
    () async {
      await expectLater(
        extractPdfText(researchPdf().sublist(0, 12)).toList(),
        throwsA(isA<Object>()),
      );
    },
    skip: !ready,
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

  for (final stale in [false, true]) {
    testWidgets(
      'reader ${stale ? 'rejects stale source versions' : 'opens verified global match on requested page and can clear it'}',
      (tester) async {
        final bytes = researchPdf();
        final pages = await tester.runAsync(
          () => extractPdfText(bytes).toList(),
        );
        final offset = pages![1].text.indexOf('research');
        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: OrbitPdfReader(
                objectId: 'research',
                title: 'Research.pdf',
                loadBytes: () async => bytes,
                initialPage: 2,
                initialSearchOffset: offset,
                initialSearchLength: 8,
                initialSearchChecksum: stale
                    ? 'obsolete'
                    : sha256.convert(bytes).toString(),
                navigationRequest: 1,
                onOpenOriginal: () {},
                onOpenExternal: (_) {},
                onReadingState: (_, _) {},
                onQuote: (_, _) async {},
                onBookmarks: (_) {},
              ),
            ),
          ),
        );
        await settleNative(tester, () {
          if (stale) {
            return find
                .text(
                  'The PDF changed. Refresh global search before opening this match.',
                )
                .evaluate()
                .isNotEmpty;
          }
          final viewers = find.byType(PdfViewer).evaluate();
          if (viewers.isEmpty) return false;
          final controller = (viewers.single.widget as PdfViewer).controller!;
          return controller.isReady &&
              controller.pageNumber == 2 &&
              find.text('Global search match · Page 2').evaluate().isNotEmpty;
        });
        expect(tester.takeException(), isNull);
        if (!stale) {
          await tester.tap(find.text('Clear match'));
          await tester.pump();
          expect(find.text('Global search match · Page 2'), findsNothing);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(seconds: 1));
      },
      skip: !ready,
    );
  }
  testWidgets(
    'open reader reloads externally replaced bytes and repeat matches keep their page',
    (tester) async {
      var bytes = researchPdf();
      final originalHash = sha256.convert(bytes).toString();
      Widget reader(int request, int page) => MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: OrbitPdfReader(
            objectId: 'same-object',
            title: 'Research.pdf',
            checksum: originalHash,
            loadBytes: () async => bytes,
            initialPage: page,
            initialSearchChecksum: sha256.convert(bytes).toString(),
            initialSearchOffset: 6,
            initialSearchLength: 8,
            navigationRequest: request,
            onOpenOriginal: () {},
            onOpenExternal: (_) {},
            onReadingState: (_, _) {},
            onQuote: (_, _) async {},
            onBookmarks: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(reader(1, 2));
      await settleNative(
        tester,
        () => find.text('Global search match · Page 2').evaluate().isNotEmpty,
      );
      bytes = Uint8List.fromList(
        ascii.encode(ascii.decode(bytes).replaceAll('research', 'analysis')),
      );
      await tester.pumpWidget(reader(2, 1));
      await settleNative(
        tester,
        () => find.text('Global search match · Page 1').evaluate().isNotEmpty,
      );
      final viewer = tester
          .widget<PdfViewer>(find.byType(PdfViewer))
          .controller!;
      final text = await tester.runAsync(
        () => viewer.document.pages[0].loadStructuredText(),
      );
      expect(text!.fullText, contains('analysis'));
      expect(text.fullText, isNot(contains('research')));
      await tester.pumpWidget(reader(3, 2));
      await settleNative(
        tester,
        () => find.text('Global search match · Page 2').evaluate().isNotEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
    skip: !ready,
  );
}
