import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/platform/pdf_annotations.dart';
import 'package:orbit_note/platform/pdf_forms.dart';
import 'support/pdf_fixture.dart';

PdfAnnotation review(
  Uint8List bytes,
  String style, {
  int page = 1,
  bool comment = false,
  bool resolved = false,
}) => PdfAnnotation(
  UniversalObject(
    id: '$style-$page',
    workspaceId: 'ws',
    typeId: 'orbit.note',
    title: style,
    body: 'Review café α — $style',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    properties: {
      'pdfHighlightVersion': 1,
      'pdfReview': {'version': 1, 'resolved': resolved},
      'pdfSource': {
        'objectId': 'file',
        'checksum': sha256.convert(bytes).toString(),
        'page': page,
        if (comment) 'kind': 'pageComment',
        'regions': [
          {
            'id': 'r',
            'type': 'rectangle',
            'page': page,
            'x': .1,
            'y': .28,
            'width': .65,
            'height': .075,
            'style': style,
            'color': 0xffeab308,
          },
        ],
      },
    },
  ),
);

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ready = await initPdfTesting();
  testWidgets('reader prevents duplicate exports and retries a failed save', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = researchPdf();
    final item = review(source, 'highlight');
    var calls = 0;
    final gate = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrbitPdfReader(
            objectId: 'file',
            title: 'Research',
            checksum: sha256.convert(source).toString(),
            annotations: [item],
            loadBytes: () async => source,
            onOpenOriginal: () {},
            onOpenExternal: (_) {},
            onReadingState: (_, _) {},
            onQuote: (_, _) async {},
            onBookmarks: (_) {},
            onSaveAnnotatedCopy: (bytes, items) async {
              calls++;
              expect(items.single.object, same(item.object));
              expect(bytes.length, greaterThan(source.length));
              return calls == 1 ? gate.future : true;
            },
          ),
        ),
      ),
    );
    Future<void> waitFor(bool Function() done) async {
      for (var i = 0; i < 150 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(done(), isTrue);
    }

    await tester.tap(find.byTooltip('Highlights and comments'));
    await waitFor(
      () => find
          .byTooltip('Save filtered review as annotated PDF')
          .evaluate()
          .isNotEmpty,
    );
    // The review is mounted before its disclosure finishes expanding.
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save filtered review as annotated PDF'));
    await waitFor(() => calls == 1);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Saving annotated PDF…',
            ),
          )
          .onPressed,
      isNull,
    );
    gate.complete(false);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not save the annotated copy.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Save filtered review as annotated PDF'));
    await waitFor(() => calls == 2);
    await tester.pumpAndSettle();
    expect(
      find.text('Annotated copy saved as a separate PDF in this Vault.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, skip: !ready);
  test(
    'export rejects stale bytes, foreign notes, unsupported regions and empty review',
    () async {
      final bytes = researchPdf();
      final item = review(bytes, 'highlight');
      final hash = sha256.convert(bytes).toString();
      await expectLater(
        exportPdfAnnotations(bytes, 'file', 'old', [item]),
        throwsStateError,
      );
      await expectLater(
        exportPdfAnnotations(bytes, 'other', hash, [item]),
        throwsStateError,
      );
      await expectLater(
        exportPdfAnnotations(bytes, 'file', hash, []),
        throwsStateError,
      );
      await expectLater(
        exportPdfAnnotations(bytes, 'file', hash, [
          review(bytes, 'future-style'),
        ]),
        throwsStateError,
      );
    },
  );

  test(
    'native export retains source and produces all standard review types',
    () async {
      final source = researchPdf(illustrated: true);
      final hash = sha256.convert(source).toString();
      final exported = await exportPdfAnnotations(source, 'file', hash, [
        review(source, 'highlight'),
        review(source, 'underline'),
        review(source, 'strikeout', page: 2),
        review(source, 'highlight', page: 2, comment: true, resolved: true),
      ]);
      expect(sha256.convert(source).toString(), hash);
      final original = await PdfDocument.openData(source);
      final copy = await PdfDocument.openData(exported);
      try {
        expect(copy.pages.length, original.pages.length);
        for (var i = 0; i < copy.pages.length; i++) {
          expect(
            (await copy.pages[i].loadText())!.fullText,
            (await original.pages[i].loadText())!.fullText,
          );
        }
        final output = await Directory(
          '.local/pdf-export-qa',
        ).create(recursive: true);
        await File('${output.path}/original.pdf').writeAsBytes(source);
        await File('${output.path}/annotated.pdf').writeAsBytes(exported);
      } finally {
        await original.dispose();
        await copy.dispose();
      }
    },
    skip: !ready,
  );

  test(
    'export rejects missing pages and preserves existing form values',
    () async {
      final source = formPdf();
      final hash = sha256.convert(source).toString();
      await expectLater(
        exportPdfAnnotations(source, 'file', hash, [
          review(source, 'highlight', page: 3),
        ]),
        throwsA(
          predicate((error) => error.toString().contains('missing PDF page')),
        ),
      );
      final exported = await exportPdfAnnotations(source, 'file', hash, [
        review(source, 'underline'),
      ]);
      final copy = await PdfDocument.openData(exported);
      try {
        final fields = await readPdfFields(copy, 1);
        expect(fields.first.value, 'Original');
        expect(fields.last.value, false);
      } finally {
        await copy.dispose();
      }
    },
    skip: !ready,
  );

  test(
    'rotation and nonzero crop origin export into PDF page coordinates',
    () async {
      // Rebuild xref offsets after changing the generated page dictionary.
      final raw = ascii.decode(researchPdf());
      final objects = RegExp(r'\d+ 0 obj\n([\s\S]*?)\nendobj')
          .allMatches(raw)
          .map(
            (m) => m[1]!.replaceAll(
              '/MediaBox [0 0 400 300]',
              '/MediaBox [0 0 400 300] /CropBox [20 30 380 270] /Rotate 90',
            ),
          )
          .toList();
      final pdf = StringBuffer('%PDF-1.4\n');
      final offsets = <int>[0];
      for (var i = 0; i < objects.length; i++) {
        offsets.add(pdf.length);
        pdf.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
      }
      final xref = pdf.length;
      pdf.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
      for (final offset in offsets.skip(1)) {
        pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
      }
      pdf.write(
        'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
      );
      final source = Uint8List.fromList(ascii.encode(pdf.toString()));
      final exported = await exportPdfAnnotations(
        source,
        'file',
        sha256.convert(source).toString(),
        [review(source, 'highlight')],
      );
      final output = await Directory(
        '.local/pdf-export-qa',
      ).create(recursive: true);
      await File('${output.path}/rotated.pdf').writeAsBytes(exported);
    },
    skip: !ready,
  );
}
