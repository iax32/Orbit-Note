import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/pdf/pdf_review_panel.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';

PdfAnnotation annotation(
  String id,
  int page, {
  bool resolved = false,
  bool pageComment = false,
}) => PdfAnnotation(
  UniversalObject(
    id: id,
    workspaceId: 'ws',
    typeId: 'orbit.note',
    title: id,
    body: 'Comment for $id',
    createdAt: DateTime.utc(2026, 1, page),
    updatedAt: DateTime.utc(2026),
    properties: {
      'pdfHighlightVersion': 1,
      'pdfReview': {'version': 1, 'resolved': resolved},
      'pdfSource': {
        'objectId': 'file',
        'checksum': 'v1',
        'page': page,
        'quote': pageComment ? '' : 'Quote $id',
        if (pageComment) 'kind': 'pageComment',
        'regions': [
          {
            'id': 'r',
            'type': 'rectangle',
            'page': page,
            'x': .1,
            'y': .1,
            'width': .2,
            'height': .02,
          },
        ],
      },
    },
  ),
);

void main() {
  testWidgets('review panel filters and summarizes exactly the visible items', (
    tester,
  ) async {
    final a = annotation('A', 1),
        b = annotation('B', 2, resolved: true, pageComment: true);
    var copied = <PdfAnnotation>[];
    var summarized = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: PdfReviewPanel(
            annotations: [b, a],
            page: 2,
            checksum: 'v1',
            onNavigate: (_) {},
            onClose: () {},
            onCopy: (v) => copied = v,
            onSummary: (v) async {
              summarized = v;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Copy filtered review as Markdown'));
    expect(copied.map((a) => a.object.id), ['A', 'B']);
    await tester.tap(find.byTooltip('Review All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolved').last);
    await tester.pumpAndSettle();
    expect(find.text('Quote A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Save filtered review as note',
      ),
    );
    await tester.pumpAndSettle();
    expect(summarized, ['B']);
    await tester.enterText(find.byType(TextField), 'no match');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) =>
                  w is IconButton &&
                  w.tooltip == 'Save filtered review as note',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'review editor saves text, color, style and resolution and retains failed text',
    (tester) async {
      var saved = false;
      var attempts = 0;
      String? body, style;
      int? color;
      bool? resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PdfReviewEditor(
                    annotation: annotation('A', 1),
                    colors: pdfHighlightColors,
                    onSave: (original, b, c, s, r) async {
                      attempts++;
                      body = b;
                      color = c;
                      style = s;
                      resolved = r;
                      return saved;
                    },
                  ),
                ),
                child: const Text('Review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'New comment');
      await tester.tap(find.text('Green'));
      await tester.tap(find.text('underline'));
      await tester.tap(find.text('Resolved'));
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      expect(body, 'New comment');
      expect(color, 0xff22c55e);
      expect(style, 'underline');
      expect(resolved, true);
      expect(find.textContaining('Your draft is kept here'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'New comment',
      );
      saved = true;
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.byType(PdfReviewEditor), findsNothing);
    },
  );

  testWidgets('narrow review panel and stale-source controls stay usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: PdfReviewPanel(
            annotations: [annotation('A', 1)],
            page: 1,
            checksum: 'v2',
            onNavigate: (_) {},
            onClose: () {},
            onCopy: (_) {},
            onEdit: (_) {},
            onOpen: (_) {},
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Edit review item',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('PDF version changed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'review digest quotes multiple lines once and warns about stale source',
    () {
      final a = annotation('A', 1);
      final item = PdfAnnotation(
        a.object.copyWith(
          body: '> one\n> two\n\n[[file#page=1|PDF]]\n\nComment',
          properties: {
            ...a.object.properties,
            'pdfSource': {...a.source, 'quote': 'one\ntwo'},
          },
        ),
      );
      final result = pdfReviewMarkdown('Renamed [PDF]', 'file', [
        item,
      ], checksum: 'new');
      expect(result.split('> one\n> two').length, 2);
      expect(result, contains('[[A|A]]'));
      expect(result, contains('[[file#page=1|Renamed  PDF  · p. 1]]'));
      expect(result, contains('Source version differs'));
    },
  );
}
