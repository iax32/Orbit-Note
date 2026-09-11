import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/platform/pdf_forms.dart';
import 'support/pdf_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('on-page form controls save text and checkbox drafts', (
    tester,
  ) async {
    Pdfrx.cacheDirectoryPath = (await tester.runAsync(
      () async => (await Directory(
        '.local/pdf-test-cache',
      ).create(recursive: true)).absolute.path,
    ))!;
    await tester.runAsync(pdfrxFlutterInitialize);
    var values = <String, dynamic>{};
    Uint8List? filledCopy;
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => OrbitPdfReader(
              objectId: 'form',
              title: 'Form',
              loadBytes: () async => formPdf(),
              onOpenOriginal: () {},
              onOpenExternal: (_) {},
              onReadingState: (_, _) {},
              onQuote: (_, _) async {},
              onBookmarks: (_) {},
              formValues: values,
              onSaveFilledCopy: (bytes) async {
                filledCopy = bytes;
                return true;
              },
              onFormChanged: (key, value) async {
                update(() => values = {...values, key: value});
                return true;
              },
            ),
          ),
        ),
      ),
    );
    Future<void> waitFor(bool Function() ready) async {
      for (var i = 0; i < 150 && !ready(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(ready(), isTrue);
    }

    await waitFor(
      () =>
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Fill PDF forms',
                ),
              )
              .onPressed !=
          null,
    );
    await tester.tap(find.byTooltip('Fill PDF forms'));
    await tester.pump();
    await waitFor(() => find.byTooltip('Approved').evaluate().isNotEmpty);
    await tester.tapAt(tester.getCenter(find.byTooltip('Approved')));
    await tester.pumpAndSettle();
    expect(values['1:1'], true);
    await tester.tapAt(tester.getCenter(find.byTooltip('Name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Player');
    await tester.tap(find.text('Save field'));
    await tester.pumpAndSettle();
    expect(values['1:0'], 'Player');
    await tester.tap(find.text('Save filled copy'));
    await waitFor(() => filledCopy != null);
    await tester.runAsync(() async {
      final saved = await PdfDocument.openData(filledCopy!);
      try {
        final fields = await readPdfFields(saved, 1);
        expect(fields.first.value, 'Player');
        expect(fields.last.value, true);
      } finally {
        await saved.dispose();
      }
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
  test(
    'real AcroForm text and checkbox survive filled-copy encoding',
    () async {
      Pdfrx.cacheDirectoryPath = (await Directory(
        '.local/pdf-test-cache',
      ).create(recursive: true)).absolute.path;
      await pdfrxFlutterInitialize();
      final original = formPdf();
      final document = await PdfDocument.openData(original);
      try {
        final fields = await readPdfFields(document, 1);
        expect(fields.length, 2);
        expect(fields.first.value, 'Original');
        expect(fields.last.value, false);
        final copy = await applyPdfFields(document, {
          fields.first.id: 'Orbit user',
          fields.last.id: true,
        });

        final reopened = await PdfDocument.openData(copy);
        try {
          final saved = await readPdfFields(reopened, 1);
          expect(saved.first.value, 'Orbit user');
          expect(saved.last.value, true);
        } finally {
          await reopened.dispose();
        }
        final untouched = await PdfDocument.openData(original);
        try {
          expect((await readPdfFields(untouched, 1)).first.value, 'Original');
        } finally {
          await untouched.dispose();
        }
      } finally {
        await document.dispose();
      }
    },
  );
}
