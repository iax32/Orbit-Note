import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/pdf_search.dart';
import 'package:orbit_note/domain/orbit_search.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'search_workspace_test.dart' as fixture;

class CoverageController extends fixture.SearchController {
  final changes = StreamController<void>.broadcast();
  final entries = <String, PdfIndexEntry>{};
  final valid = <String>{};
  int revision = 0, retries = 0;
  bool paused = false;
  @override
  Stream<void> get pdfIndexChanges => changes.stream;
  @override
  int get pdfIndexRevision => revision;
  @override
  Map<String, PdfIndexEntry> get pdfIndexEntries => entries;
  @override
  bool get pdfIndexPaused => paused;
  @override
  bool isCurrentSearchResult(OrbitSearchResult result) =>
      result.sourceChecksum == null || valid.contains(result.sourceChecksum);
  @override
  void pausePdfIndex(bool value) {
    paused = value;
    changes.add(null);
  }

  @override
  void retryPdfIndex() {
    retries++;
    changes.add(null);
  }
}

void main() {
  Finder mainScroll() => find
      .descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      )
      .first;
  testWidgets(
    'all results paginate; project and folder filters find matches beyond the old cap',
    (tester) async {
      final c = fixture.SearchController()
        ..found = [
          for (var i = 0; i < 125; i++)
            fixture.result(
              'note-$i',
              properties: {
                'project': i == 124 ? 'Study' : 'Other',
                'folder': i == 124 ? 'Papers' : 'Notes',
              },
            ),
        ];
      await fixture.mount(tester, c);
      await fixture.search(tester, 'research');
      expect(find.text('125 results · 1–50'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Next results'),
        400,
        scrollable: mainScroll(),
      );
      await tester.tap(find.text('Next results'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(c.opened!.object.id, 'note-50');
      await tester.scrollUntilVisible(
        find.text('Next results'),
        400,
        scrollable: mainScroll(),
      );
      await tester.tap(find.text('Next results'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(c.opened!.object.id, 'note-100');
      expect(find.text('125 results · 101–125'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Previous results'),
        400,
        scrollable: mainScroll(),
      );
      await tester.tap(find.text('Previous results'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(c.opened!.object.id, 'note-50');
      await tester.tap(find.byTooltip('Filter by project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Study').last);
      await tester.pumpAndSettle();
      expect(find.text('1 results'), findsOneWidget);
      expect(find.text('note-124'), findsOneWidget);
      await tester.tap(find.text('More filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter by folder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Papers').last);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(c.opened!.object.id, 'note-124');
      expect(find.text('Next results'), findsNothing);
    },
  );

  testWidgets(
    'index coverage, pause, failure retry, and OCR details are reachable',
    (tester) async {
      final c = CoverageController();
      addTearDown(c.changes.close);
      c.entries.addAll({
        'pending': const PdfIndexEntry('Indexing', pages: 2, total: 5),
        'bad': const PdfIndexEntry('Failed', detail: 'Unreadable PDF'),
        'scan': const PdfIndexEntry(
          'No text',
          detail: 'Scanned pages need OCR.',
        ),
      });
      await fixture.mount(tester, c);
      expect(
        find.textContaining('1 pending · 1 failed · 1 without text'),
        findsOneWidget,
      );
      await tester.tap(find.text('Pause indexing'));
      await tester.pump();
      expect(c.paused, isTrue);
      await tester.tap(find.text('Resume indexing'));
      await tester.pump();
      expect(c.paused, isFalse);
      await tester.tap(find.text('Retry failed PDFs'));
      expect(c.retries, 1);
      await tester.tap(find.text('Index details'));
      await tester.pumpAndSettle();
      expect(find.text('PDF search coverage'), findsOneWidget);
      expect(find.text('Indexing · 2/5 pages'), findsOneWidget);
      expect(find.textContaining('Scanned pages need OCR'), findsOneWidget);
      expect(find.textContaining('Unreadable PDF'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('PDF search coverage'), findsNothing);
    },
  );

  testWidgets(
    'source invalidation hides stale excerpts and new page matches appear automatically',
    (tester) async {
      final c = CoverageController();
      addTearDown(c.changes.close);
      final pdf = fixture
          .result(
            'pdf',
            title: 'Research.pdf',
            type: 'orbit.file',
            properties: {
              'mimeType': 'application/pdf',
              'contentRef': 'Attachments/a.pdf',
            },
          )
          .object;
      OrbitSearchResult match(String hash, int page) => OrbitSearchResult(
        object: pdf,
        location: ObjectReference(pdf.id, page: page),
        matchKind: 'PDF text',
        matchedText: '$hash research passage',
        score: 60,
        sourceOffset: 1,
        matchLength: 8,
        sourceChecksum: hash,
        sourcePath: 'Attachments/a.pdf',
      );
      c.valid.add('old');
      c.found = [match('old', 1)];
      await fixture.mount(tester, c);
      await fixture.search(tester, 'research');
      expect(find.textContaining('Page 1'), findsOneWidget);
      c.valid.clear();
      c.revision++;
      c.changes.add(null);
      await tester.pump();
      await tester.pump();
      expect(
        find.textContaining('old research passage', findRichText: true),
        findsNothing,
      );
      c.valid.add('new');
      c.found = [match('new', 2)];
      c.revision++;
      c.changes.add(null);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.textContaining('Page 2'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(c.opened!.location.page, 2);
      expect(c.opened!.sourceChecksum, 'new');
    },
  );

  for (final size in [const Size(320, 640), const Size(568, 320)]) {
    testWidgets('PDF coverage dialog and controls fit enlarged text at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = CoverageController();
      addTearDown(c.changes.close);
      c.entries['file'] = const PdfIndexEntry(
        'Failed',
        detail: 'Source changed during verification. Retry indexing.',
      );
      await fixture.mount(tester, c, scale: 2.5);
      await tester.ensureVisible(find.text('Index details'));
      await tester.tap(find.text('Index details'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'background indexing preserves the selected destination when new results rank above it',
    (tester) async {
      final c = CoverageController();
      addTearDown(c.changes.close);
      c.found = [fixture.result('first'), fixture.result('chosen')];
      await fixture.mount(tester, c);
      await fixture.search(tester, 'research');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      c.found = [fixture.result('new'), ...c.found];
      c.revision++;
      c.changes.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(c.opened!.object.id, 'chosen');
    },
  );
}
