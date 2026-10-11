import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';

UniversalObject _makeObj({
  required String id,
  required String title,
  String body = '',
  Map<String, dynamic> properties = const {},
}) {
  final now = DateTime.now();
  return UniversalObject(
    id: id,
    workspaceId: 'ws-test',
    typeId: 'orbit.note',
    title: title,
    body: body,
    createdAt: now,
    updatedAt: now,
    properties: properties,
  );
}

void main() {
  group('PdfAnnotation Bounds and Styling', () {
    test(
      'boundsForPage returns correct union for multiple fragments on same page',
      () {
        final annotation = PdfAnnotation(
          _makeObj(
            id: 'anno-1',
            title: 'Highlight 1',
            body: 'Interesting discovery',
            properties: {
              'pdfHighlightVersion': 1,
              'pdfSource': {
                'objectId': 'pdf-1',
                'page': 2,
                'checksum': 'chk-123',
                'quote': 'First fragment and second fragment',
                'regions': [
                  {
                    'id': 'r1',
                    'type': 'rectangle',
                    'page': 2,
                    'x': 0.1,
                    'y': 0.2,
                    'width': 0.3,
                    'height': 0.05,
                    'color': 0xff3b82f6,
                    'style': 'underline',
                  },
                  {
                    'id': 'r2',
                    'type': 'rectangle',
                    'page': 2,
                    'x': 0.2,
                    'y': 0.26,
                    'width': 0.4,
                    'height': 0.04,
                    'color': 0xff3b82f6,
                    'style': 'underline',
                  },
                  {
                    'id': 'r3',
                    'type': 'rectangle',
                    'page': 3,
                    'x': 0.5,
                    'y': 0.5,
                    'width': 0.2,
                    'height': 0.1,
                  },
                ],
              },
            },
          ),
        );

        final boundsPage2 = annotation.boundsForPage(2);
        expect(boundsPage2, isNotNull);
        expect(boundsPage2!.left, closeTo(0.1, 0.001));
        expect(boundsPage2.top, closeTo(0.2, 0.001));
        expect(boundsPage2.width, closeTo(0.5, 0.001));
        expect(boundsPage2.height, closeTo(0.1, 0.001));

        expect(annotation.boundsForPage(1), isNull);

        final boundsPage3 = annotation.boundsForPage(3);
        expect(boundsPage3, isNotNull);
        expect(boundsPage3!.left, closeTo(0.5, 0.001));
        expect(boundsPage3.top, closeTo(0.5, 0.001));
        expect(boundsPage3.width, closeTo(0.2, 0.001));
        expect(boundsPage3.height, closeTo(0.1, 0.001));
      },
    );

    test('extracts custom color and style with safe defaults', () {
      final customAnnotation = PdfAnnotation(
        _makeObj(
          id: 'anno-custom',
          title: 'Custom Style',
          properties: {
            'pdfHighlightVersion': 1,
            'pdfSource': {
              'regions': [
                {
                  'id': 'r1',
                  'type': 'rectangle',
                  'page': 1,
                  'x': 0.1,
                  'y': 0.1,
                  'width': 0.2,
                  'height': 0.05,
                  'color': 0xffef4444,
                  'style': 'strikeout',
                },
              ],
            },
          },
        ),
      );

      expect(customAnnotation.color, 0xffef4444);
      expect(customAnnotation.style, 'strikeout');

      final defaultAnnotation = PdfAnnotation(
        _makeObj(
          id: 'anno-default',
          title: 'Default Style',
          properties: {
            'pdfHighlightVersion': 1,
            'pdfSource': {
              'regions': [
                {
                  'id': 'r1',
                  'type': 'rectangle',
                  'page': 1,
                  'x': 0.1,
                  'y': 0.1,
                  'width': 0.2,
                  'height': 0.05,
                },
              ],
            },
          },
        ),
      );

      expect(defaultAnnotation.color, 0xff8b7cf6);
      expect(defaultAnnotation.style, 'highlight');
    });

    test('summaryMarkdown produces clean quotes and page citations', () {
      final annotation = PdfAnnotation(
        _makeObj(
          id: 'anno-quote',
          title: 'Key Finding',
          body: 'Remember to verify this in section 4.',
          properties: {
            'pdfHighlightVersion': 1,
            'pdfSource': {
              'objectId': 'stable-pdf',
              'page': 7,
              'quote':
                  'Decentralized state synchronization ensures offline resilience.',
            },
          },
        ),
      );

      final markdown = annotation.summaryMarkdown('Architecture Guide.pdf');
      expect(
        markdown,
        contains(
          '> Decentralized state synchronization ensures offline resilience.',
        ),
      );
      expect(
        markdown,
        contains('[[stable-pdf#page=7|Architecture Guide.pdf · p. 7]]'),
      );
      expect(markdown, contains('Remember to verify this in section 4.'));
    });

    test('summaryMarkdown handles quote-only without redundant body', () {
      const text = 'Direct quote without additional notes.';
      final annotation = PdfAnnotation(
        _makeObj(
          id: 'anno-quote-only',
          title: 'Highlight',
          body: text,
          properties: {
            'pdfHighlightVersion': 1,
            'pdfSource': {'page': 12, 'quote': text},
          },
        ),
      );

      final markdown = annotation.summaryMarkdown('Paper.pdf');
      expect(markdown, contains('> Direct quote without additional notes.'));
      expect(markdown, contains('[[Paper.pdf#page=12|Paper.pdf · p. 12]]'));
      expect(markdown.split(text).length, 2);
    });
  });

  group('PDF Palette and Page Mode Enums', () {
    test('pdfHighlightColors has expected 5 color options', () {
      expect(pdfHighlightColors.length, 5);
      expect(pdfHighlightColors['Yellow'], 0xffeab308);
      expect(pdfHighlightColors['Green'], 0xff22c55e);
      expect(pdfHighlightColors['Blue'], 0xff3b82f6);
      expect(pdfHighlightColors['Purple'], 0xff8b7cf6);
      expect(pdfHighlightColors['Coral'], 0xffef4444);
    });

    test('PdfPageMode defines continuous, single, and twoPage', () {
      expect(PdfPageMode.values, [
        PdfPageMode.continuous,
        PdfPageMode.single,
        PdfPageMode.twoPage,
      ]);
    });
  });

  group('NoteEditor PDF Source Banner', () {
    testWidgets(
      'renders PDF source banner and triggers onOpenPdfSource callback',
      (tester) async {
        String? openedId;
        int? openedPage;
        final pdfSource = {
          'objectId': 'pdf-doc-123',
          'title': 'Quantum Computing Foundations.pdf',
          'page': 42,
          'quote': 'Superposition enables parallel state evaluation.',
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteEditor(
                noteId: 'note-with-pdf',
                title: 'Superposition Notes',
                body: 'Here are my reading notes.',
                onTitleChanged: (_) {},
                onBodyChanged: (_) {},
                linkTargets: const [],
                onOpenObject: (_) {},
                pdfSource: pdfSource,
                onOpenPdfSource: (id, page) {
                  openedId = id;
                  openedPage = page;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('pdf-source-banner')), findsOneWidget);
        expect(
          find.textContaining(
            'PDF Source: Quantum Computing Foundations.pdf · Page 42',
          ),
          findsOneWidget,
        );
        expect(find.text('View in PDF'), findsOneWidget);

        await tester.tap(find.text('View in PDF'));
        await tester.pumpAndSettle();

        expect(openedId, 'pdf-doc-123');
        expect(openedPage, 42);
      },
    );

    testWidgets('does not render banner when pdfSource is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'standard-note',
              title: 'Standard Note',
              body: 'Just a normal note.',
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
              pdfSource: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pdf-source-banner')), findsNothing);
      expect(find.text('View in PDF'), findsNothing);
    });
  });
}
