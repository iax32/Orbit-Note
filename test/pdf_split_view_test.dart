import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'package:pdfrx/pdfrx.dart';
import 'support/pdf_fixture.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pdfiumReady = await initPdfTesting();

  Future<void> settleNative(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 150 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets(
    'PDF renders correctly when opened beside a note in split view',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var isSplit = false;
      late StateSetter setSplitState;

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setSplitState = setState;
                if (!isSplit) {
                  return OrbitPdfReader(
                    key: const ValueKey('primary:pdf:test-pdf'),
                    objectId: 'test-pdf',
                    title: 'Research Paper',
                    loadBytes: () async => researchPdf(),
                    onOpenOriginal: () {},
                    onOpenExternal: (_) {},
                    onReadingState: (_, _) {},
                    onQuote: (_, _) async {},
                    onBookmarks: (_) {},
                  );
                }
                return Row(
                  children: [
                    const Expanded(
                      flex: 500,
                      child: Center(child: Text('Note Content Pane')),
                    ),
                    Expanded(
                      flex: 500,
                      child: OrbitPdfReader(
                        key: const ValueKey('secondary:pdf:test-pdf'),
                        objectId: 'test-pdf',
                        title: 'Research Paper',
                        loadBytes: () async => researchPdf(),
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

      await settleNative(
        tester,
        () => find.byType(PdfViewer).evaluate().isNotEmpty,
      );

      final primaryViewer = tester
          .widget<PdfViewer>(find.byType(PdfViewer))
          .controller!;
      await settleNative(tester, () => primaryViewer.isReady);

      setSplitState(() => isSplit = true);
      await tester.pump();
      await tester.pumpAndSettle();

      await settleNative(
        tester,
        () => find.byType(PdfViewer).evaluate().isNotEmpty,
      );
      final splitViewer = tester
          .widget<PdfViewer>(find.byType(PdfViewer))
          .controller!;
      await settleNative(tester, () => splitViewer.isReady);

      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(splitViewer.currentZoom, greaterThan(0.5));
      expect(splitViewer.currentZoom, lessThan(4.0));
      final visibleRect = splitViewer.value.calcVisibleRect(
        splitViewer.viewSize,
      );
      final pageLayout = splitViewer.layout.pageLayouts.first;
      expect(visibleRect.overlaps(pageLayout), isTrue);
      expect(
        splitViewer.centerPosition.dy,
        greaterThanOrEqualTo(pageLayout.top),
      );
      expect(
        splitViewer.centerPosition.dy,
        lessThanOrEqualTo(pageLayout.bottom + 100),
      );

      tester.view.physicalSize = const Size(700, 600);
      await tester.pump();
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(splitViewer.currentZoom, greaterThan(0.5));
      final afterVisible = splitViewer.value.calcVisibleRect(
        splitViewer.viewSize,
      );
      expect(afterVisible.overlaps(pageLayout), isTrue);
      expect(
        splitViewer.centerPosition.dy,
        greaterThanOrEqualTo(pageLayout.top),
      );
      expect(
        splitViewer.centerPosition.dy,
        lessThanOrEqualTo(pageLayout.bottom + 100),
      );
    },
    skip: !pdfiumReady,
  );
}
