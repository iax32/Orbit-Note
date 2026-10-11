import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'package:orbit_note/platform/ocr_pages.dart';
import 'support/pdf_fixture.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ready = await initPdfTesting();
  testWidgets(
    'real PDF pages are rendered serially into bounded PNGs for local OCR',
    (tester) async {
      var calls = 0;
      const channel = MethodChannel('orbit_note/ocr');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final bytes = call.arguments as Uint8List;
            expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
            expect(bytes.length, lessThan(100 * 1024 * 1024));
            calls++;
            return {'text': 'local page $calls', 'language': 'en', 'lines': []};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final pages = await tester.runAsync(
        () => recognizeAttachment(researchPdf(), true).toList(),
      );
      expect(calls, 2);
      expect(pages!.map((p) => p['total']), [2, 2]);
    },
    skip: !ready,
  );
  testWidgets(
    'reader locates a verified OCR page with regions and clears the transient match',
    (tester) async {
      final bytes = researchPdf();
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: OrbitPdfReader(
              objectId: 'scan',
              title: 'Scanned research',
              loadBytes: () async => bytes,
              initialPage: 2,
              navigationRequest: 1,
              initialSearchChecksum: sha256.convert(bytes).toString(),
              initialRecognizedMatch: true,
              initialSearchRegions: const [
                {'x': .1, 'y': .1, 'width': .5, 'height': .08},
              ],
              initialSearchOffset: 0,
              initialSearchLength: 5,
              onOpenOriginal: () {},
              onOpenExternal: (_) {},
              onReadingState: (_, _) {},
              onQuote: (_, _) async {},
              onBookmarks: (_) {},
            ),
          ),
        ),
      );
      for (
        var i = 0;
        i < 200 && find.text('Global search match · Page 2').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('Global search match · Page 2'), findsOneWidget);
      await tester.tap(find.text('Clear match'));
      await tester.pump();
      expect(find.text('Global search match · Page 2'), findsNothing);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    },
    skip: !ready,
  );
}
