import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_note/domain/publication_image.dart';
import 'package:orbit_note/features/notes/export/publication_workspace.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/platform/publication_image_download.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:pdfrx/pdfrx.dart';
import 'support/memory_store.dart';
import 'support/pdf_fixture.dart';

class _Client extends MockClient {
  _Client(super.handler);
  bool closed = false;
  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'publication resolves attachment references independently of note depth',
    () {
      for (final path in [
        'Attachments/hash/chart.png',
        '../Attachments/hash/chart.png',
        '../../../Attachments/hash/chart.png',
        './../../../Attachments/hash/chart.png',
      ]) {
        expect(publicationAttachmentPath(path), 'Attachments/hash/chart.png');
      }
      expect(
        publicationAttachmentPath('../Attachments/hash/figure%201%23.png'),
        'Attachments/hash/figure 1#.png',
      );
      expect(
        publicationAttachmentPath('../Attachments/hash/figure%2520.png'),
        'Attachments/hash/figure%20.png',
      );
      for (final path in [
        'https://example.com/a.png',
        '//server/a.png',
        '/Attachments/a.png',
        '../Notes/private.md',
        'Attachments/../../secret',
        'Attachments/hash/%2e%2e/%2e%2e/secret',
        'Attachments\\a.png',
        'file:///C:/secret.png',
        'data:image/png;base64,AA==',
      ]) {
        expect(publicationAttachmentPath(path), null, reason: path);
      }
    },
  );

  test('HTTPS image download is anonymous and closes the client', () async {
    late _Client client;
    final download = PublicationImageDownload(
      clientFactory: () => client = _Client((r) async {
        expect(r.method, 'GET');
        expect(r.followRedirects, false);
        expect(
          r.headers.keys.any(
            (h) => ['authorization', 'cookie'].contains(h.toLowerCase()),
          ),
          false,
        );
        return http.Response.bytes(
          [1, 2, 3],
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    );
    expect(await download.read(Uri.parse('https://example.com/image.png')), [
      1,
      2,
      3,
    ]);
    expect(client.closed, true);
    download.dispose();
    await expectLater(
      download.read(Uri.parse('https://example.com/image.png')),
      throwsFormatException,
    );
  });

  test(
    'redirects are bounded and never downgrade HTTPS or accept URI credentials',
    () async {
      for (final location in [
        'http://example.com/image.png',
        'https://user:secret@example.com/image.png',
        '/loop',
      ]) {
        var reads = 0;
        final download = PublicationImageDownload(
          clientFactory: () => _Client((_) async {
            reads++;
            return http.Response('', 302, headers: {'location': location});
          }),
        );
        await expectLater(
          download.read(Uri.parse('https://example.com/start')),
          throwsFormatException,
        );
        expect(reads, location == '/loop' ? 4 : 1);
        download.dispose();
      }
    },
  );

  test(
    'rejects errors, HTML and oversized responses without embedding them',
    () async {
      for (final response in [
        http.Response('Sign in', 403),
        http.Response(
          '<html>Sign in</html>',
          200,
          headers: {'content-type': 'text/html'},
        ),
        http.Response.bytes(
          Uint8List(PublicationImageDownload.maxBytes + 1),
          200,
          headers: {
            'content-length': '${PublicationImageDownload.maxBytes + 1}',
          },
        ),
      ]) {
        final download = PublicationImageDownload(
          clientFactory: () => _Client((_) async => response),
        );
        await expectLater(
          download.read(Uri.parse('https://example.com/image.png')),
          throwsFormatException,
        );
        download.dispose();
      }
    },
  );

  test('total deadline closes a stalled image request', () async {
    late _Client client;
    final reply = Completer<http.Response>();
    final download = PublicationImageDownload(
      timeout: const Duration(milliseconds: 30),
      clientFactory: () => client = _Client((_) => reply.future),
    );
    await expectLater(
      download.read(Uri.parse('https://example.com/image.png')),
      throwsA(isA<TimeoutException>()),
    );
    expect(client.closed, true);
    reply.complete(http.Response('', 404));
    download.dispose();
  });

  test(
    'streaming image size limits apply without a declared content length',
    () async {
      final download = PublicationImageDownload(
        clientFactory: () => MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            Stream.fromIterable(
              List.generate(21, (_) => Uint8List(1024 * 1024)),
            ),
            200,
            headers: {'content-type': 'image/png'},
          ),
        ),
      );
      await expectLater(
        download.read(Uri.parse('https://example.com/image.png')),
        throwsFormatException,
      );
      download.dispose();
    },
  );

  test(
    'cancel rejects a late response and permits a new explicit download',
    () async {
      final reply = Completer<http.Response>();
      var calls = 0;
      final download = PublicationImageDownload(
        clientFactory: () => _Client((_) async {
          calls++;
          if (calls == 1) return reply.future;
          return http.Response.bytes(
            [4, 5],
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      final pending = download.read(Uri.parse('https://example.com/image.png'));
      await Future<void>.delayed(Duration.zero);
      download.cancel();
      reply.complete(
        http.Response.bytes(
          [1, 2],
          200,
          headers: {'content-type': 'image/png'},
        ),
      );
      await expectLater(pending, throwsFormatException);
      expect(await download.read(Uri.parse('https://example.com/image.png')), [
        4,
        5,
      ]);
      download.dispose();
    },
  );

  Future<Uint8List> picture() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 300, 120),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 120),
      Paint()..color = Colors.red,
    );
    canvas.drawRect(
      const Rect.fromLTWH(100, 0, 100, 120),
      Paint()..color = Colors.green,
    );
    canvas.drawRect(
      const Rect.fromLTWH(200, 0, 100, 120),
      Paint()..color = Colors.blue,
    );
    final recording = recorder.endRecording();
    final image = await recording.toImage(300, 120);
    try {
      return (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
    } finally {
      image.dispose();
      recording.dispose();
    }
  }

  Future<void> ready(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      if (find.text('Export PDF').evaluate().isNotEmpty &&
          tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Export PDF'),
                  )
                  .onPressed !=
              null) {
        return;
      }
      if (find.text('PDF ready').evaluate().isNotEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty) {
        return;
      }
    }
    fail('Publishing did not become ready.');
  }

  testWidgets('publishing normalizes a local SVG attachment before preview', (
    tester,
  ) async {
    Uint8List? output;
    await tester.pumpWidget(
      MaterialApp(
        home: PublicationWorkspace(
          title: 'SVG diagram',
          source: '![Blueprint](../Attachments/diagram.svg)',
          readImage: (_) async => Uint8List.fromList(
            utf8.encode(
              '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100" fill="blue"/></svg>',
            ),
          ),
          previewBuilder: (bytes) {
            output = bytes;
            return const Text('SVG ready');
          },
        ),
      ),
    );
    await ready(tester);
    expect(find.text('SVG ready'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await initPdfTesting(), true);
      final pdf = await PdfDocument.openData(output!);
      try {
        final text = (await Future.wait(
          pdf.pages.map((p) => p.loadText()),
        )).map((t) => t!.fullText).join();
        expect(text, isNot(contains('[Image:')));
        final rendered = (await pdf.pages.last.render(
          width: 595,
          height: 842,
        ))!;
        final image = await rendered.createImage();
        try {
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final pixels = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          var blue = 0;
          for (var i = 0; i < pixels.length; i += 4) {
            if (pixels[i] < 30 && pixels[i + 1] < 30 && pixels[i + 2] > 200) {
              blue++;
            }
          }
          expect(blue, greaterThan(1000));
        } finally {
          image.dispose();
          rendered.dispose();
        }
      } finally {
        await pdf.dispose();
      }
    });
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'web images require a click, embed in PDF and are reused for style changes',
    (tester) async {
      late Uint8List png;
      await tester.runAsync(() async => png = await picture());
      var downloads = 0;
      Uint8List? pdfBytes;
      final download = PublicationImageDownload(
        clientFactory: () => _Client((_) async {
          downloads++;
          return http.Response.bytes(
            png,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PublicationWorkspace(
            title: 'Images in Markdown PDF',
            source:
                '# Local attachment\n\n![Local](../Attachments/local.png)\n\n# Web image\n\n![Web](https://example.com/chart.png)\n\n![Same web image](https://example.com/chart.png)',
            readImage: (_) async => png,
            imageDownloader: download,
            previewBuilder: (bytes) {
              pdfBytes = bytes;
              return const Text('PDF ready');
            },
          ),
        ),
      );
      await ready(tester);
      expect(downloads, 0);
      await tester.ensureVisible(find.text('Load web images'));
      await tester.tap(find.text('Load web images'));
      await tester.pump(const Duration(milliseconds: 350));
      await ready(tester);
      expect(downloads, 1);
      await tester.runAsync(() async {
        expect(await initPdfTesting(), true);
        final pdf = await PdfDocument.openData(pdfBytes!);
        try {
          final text = (await Future.wait(
            pdf.pages.map((p) => p.loadText()),
          )).map((t) => t!.fullText).join();
          expect(text, isNot(contains('[Image:')));
          final render = (await pdf.pages.last.render(
            width: 595,
            height: 842,
          ))!;
          final image = await render.createImage();
          try {
            final rgba = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            var red = 0, blue = 0;
            for (var i = 0; i < rgba.length; i += 4) {
              if (rgba[i] > 180 && rgba[i + 1] < 100 && rgba[i + 2] < 100) {
                red++;
              }
              if (rgba[i + 2] > 180 && rgba[i] < 100 && rgba[i + 1] < 180) {
                blue++;
              }
            }
            await File('.local/markdown-pdf-images-review.png').writeAsBytes(
              (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!.buffer.asUint8List(),
            );
            await File(
              '.local/markdown-pdf-images-review.pdf',
            ).writeAsBytes(pdfBytes!);
            expect(red, greaterThan(1000));
            expect(blue, greaterThan(1000));
          } finally {
            image.dispose();
            render.dispose();
          }
        } finally {
          await pdf.dispose();
        }
      });
      await tester.ensureVisible(find.text('Letter'));
      await tester.tap(find.text('Letter'));
      await tester.pump(const Duration(milliseconds: 350));
      await ready(tester);
      expect(downloads, 1);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'missing images can be retried without reopening or changing the note',
    (tester) async {
      late Uint8List png;
      await tester.runAsync(() async => png = await picture());
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PublicationWorkspace(
            title: 'Retry local',
            source:
                '![Image](Attachments/image.png)\n\n![Again](Attachments/image.png)',
            readImage: (_) async => ++reads == 1 ? null : png,
            previewBuilder: (_) => const Text('PDF ready'),
          ),
        ),
      );
      await ready(tester);
      expect(reads, 1);
      expect(find.text('0 image(s) embedded in this export.'), findsOneWidget);
      await tester.ensureVisible(find.text('Retry missing images'));
      await tester.tap(find.text('Retry missing images'));
      await tester.pump(const Duration(milliseconds: 350));
      await ready(tester);
      expect(reads, 2);
      expect(find.text('1 image(s) embedded in this export.'), findsOneWidget);
      expect(find.text('Retry missing images'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('web-image controls fit narrow screens with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 850),
            textScaler: TextScaler.linear(2),
          ),
          child: PublicationWorkspace(
            title: 'Remote images',
            source: '![Remote](https://example.com/image.png)',
            previewBuilder: (_) => const Text('PDF ready'),
          ),
        ),
      ),
    );
    await ready(tester);
    await tester.tap(find.text('Document style'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Load web images'));
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Load web images'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Markdown PDF toolbar reads local attachments without a clipboard resolver',
    (tester) async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      late Uint8List png;
      await tester.runAsync(() async => png = await picture());
      final attachment = await repo.importAttachment(
        name: 'figure 1#.png',
        bytes: png,
      );
      final path = attachment.properties['contentRef'] as String;
      final note = await repo.create(
        typeId: 'orbit.note',
        title: 'Local export',
        body:
            '![Local](<../../../${Uri.encodeFull(path).replaceAll('#', '%23')}>)',
      );
      final controller = WorkspaceController()
        ..repository = repo
        ..hasWorkspace = true
        ..loading = false;
      controller.mergeRepositoryObjects();
      try {
        expect(await initPdfTesting(), true);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteEditor(
                noteId: note.id,
                title: note.title,
                body: note.body,
                controller: controller,
                allObjects: repo.objects,
                linkTargets: const [],
                onOpenObject: (_) {},
                onTitleChanged: (_) {},
                onBodyChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Export as PDF'));
        for (var i = 0; i < 100; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump();
          if (find
              .text('1 image(s) embedded in this export.')
              .evaluate()
              .isNotEmpty) {
            break;
          }
        }
        expect(
          find.text('1 image(s) embedded in this export.'),
          findsOneWidget,
        );
        expect(note.body, contains('../../../'));
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
      } finally {
        controller.cancelAllTimers();
        await repo.close();
      }
    },
  );
}
