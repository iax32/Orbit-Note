import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/domain/pdf_ink.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/pdf/pdf_ink_session.dart';
import 'package:orbit_note/features/pdf/pdf_ink_surface.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'package:orbit_note/features/canvas/canvas_live_ink.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/platform/pdf_annotations.dart';
import 'support/memory_store.dart';
import 'support/pdf_fixture.dart';
import 'support/capture_ui.dart';

CanvasElement stroke(
  String id, {
  int page = 1,
  double width = 400,
  double height = 300,
  bool highlighter = false,
  int count = 3,
}) => CanvasElement(
  immutableObjectData({
    'id': id,
    'type': 'ink',
    'page': page,
    'pageWidth': width,
    'pageHeight': height,
    'x': 30.0,
    'y': 40.0,
    'width': mathWidth(count),
    'height': 20.0,
    'color': 0xff2563eb,
    'strokeWidth': 4.0,
    'penStyle': highlighter ? 'highlighter' : 'ballpoint',
    'isHighlighter': highlighter,
    'custom': {'retained': true},
    'points': [
      for (var i = 0; i < count; i++)
        {
          'x': i * mathWidth(count) / (count - 1),
          'y': i.isEven ? 0.0 : 20.0,
          'pressure': i == 0 ? .2 : .8,
          'timeMs': i,
        },
    ],
  }),
);
double mathWidth(int count) => count == 3 ? 100 : 200;

Uint8List rotatedPdf() {
  final objects = RegExp(r'\d+ 0 obj\n([\s\S]*?)\nendobj')
      .allMatches(ascii.decode(researchPdf()))
      .map(
        (m) => m[1]!.replaceAll(
          '/MediaBox [0 0 400 300]',
          '/MediaBox [0 0 400 300] /CropBox [20 30 380 270] /Rotate 90',
        ),
      )
      .toList();
  final pdf = StringBuffer('%PDF-1.4\n'), offsets = <int>[0];
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
  return Uint8List.fromList(ascii.encode(pdf.toString()));
}

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ready = await initPdfTesting();
  test(
    'PDF ink validation preserves unknown fields and rejects stale/partial data',
    () {
      final a = stroke('a'), b = stroke('b');
      final empty = PdfInkDocument.read(null, 'hash');
      final raw = empty.apply(PdfInkDelta(add: [a]))!;
      final doc = PdfInkDocument.read(raw, 'hash');
      expect(PdfInkDocument.read(raw, 'hash'), same(doc));
      expect(doc.elements.single.data, same(a.data));
      expect(doc.apply(PdfInkDelta(add: [a])), isNull);
      expect(doc.apply(PdfInkDelta(remove: [b])), isNull);
      final withExtra = immutableObjectData({
        ...raw,
        'future': {'retain': 42},
      });
      final appended = PdfInkDocument.read(
        withExtra,
        'hash',
      ).apply(PdfInkDelta(add: [b]))!;
      expect(appended['future'], {'retain': 42});
      expect(PdfInkDocument.read(appended, 'hash').elements.length, 2);
      expect(PdfInkDocument.read(appended, 'old').editable, false);
      final future = immutableObjectData({...raw, 'version': 2});
      expect(PdfInkDocument.read(future, 'hash').data, same(future));
      expect(PdfInkDocument.read(future, 'hash').editable, false);
      for (final bad in [
        {...a.data, 'page': 0},
        {
          ...a.data,
          'points': [
            {'x': double.nan, 'y': 0, 'pressure': 1, 'timeMs': 1},
          ],
        },
        {
          ...a.data,
          'points': [
            {'x': 900, 'y': 0, 'pressure': 1, 'timeMs': 1},
          ],
        },
        {...a.data, 'penStyle': 'future'},
      ]) {
        expect(PdfInkDocument.validateStroke(bad), isNull);
      }
      expect(
        PdfInkDocument.read({
          ...raw,
          'elements': [a.data, a.data],
        }, 'hash').editable,
        false,
      );
    },
  );

  test(
    'shared history keeps disjoint edits and protects remote same-stroke edits',
    () {
      Object? saved;
      bool save(PdfInkDelta d) {
        final next = PdfInkDocument.read(saved, 'hash').apply(d);
        if (next == null) return false;
        saved = next;
        return true;
      }

      final session = PdfInkSession(null, 'hash', save, false);
      addTearDown(session.dispose);
      final a = stroke('a'), b = stroke('b');
      expect(session.commit(PdfInkDelta(add: [a])), true);
      session.update(saved, 'hash', save, false);
      expect(session.canUndo, true);
      saved = PdfInkDocument.read(saved, 'hash').apply(PdfInkDelta(add: [b]));
      session.update(saved, 'hash', save, false);
      session.undo();
      expect(session.document.elements.map((e) => e.id), ['b']);
      session.redo();
      expect(session.document.elements.length, 2);
      final changed = CanvasElement(
        immutableObjectData({...a.data, 'color': 0xffef4444}),
      );
      saved = PdfInkDocument.read(
        saved,
        'hash',
      ).apply(PdfInkDelta(remove: [a], add: [changed]));
      session.update(saved, 'hash', save, false);
      expect(session.canUndo, false);
      session.update(saved, 'hash', save, true);
      expect(session.commit(PdfInkDelta(add: [stroke('c')])), false);
      session.update(saved, 'other', save, false);
      expect(session.canEdit, false);
    },
  );

  test(
    'eraser undo restores transparent stroke order and resets history for a different file',
    () {
      final session = PdfInkSession(null, 'hash', (_) => true, false);
      addTearDown(session.dispose);
      final a = stroke('a', highlighter: true),
          b = stroke('b'),
          c = stroke('c', highlighter: true);
      session.commit(PdfInkDelta(add: [a, b, c]));
      session.query(1, const CanvasBounds(0, 0, 400, 300));
      session.commit(PdfInkDelta(remove: [a, b]));
      session.undo();
      expect(session.document.elements.map((e) => e.id), ['a', 'b', 'c']);
      expect(
        session.query(1, const CanvasBounds(0, 0, 400, 300)).map((e) => e.id),
        ['a', 'b', 'c'],
      );
      session.redo();
      expect(session.document.elements.map((e) => e.id), ['c']);
      session.update(
        session.document.data,
        'hash',
        (_) => true,
        false,
        reset: true,
      );
      expect(session.canUndo, false);
    },
  );

  test(
    'ink hit testing follows actual samples rather than stroke bounding boxes',
    () {
      final e = stroke('a');
      expect(pdfInkHit(e, const Offset(80, 60), 2), true);
      expect(pdfInkHit(e, const Offset(80, 40), 1), false);
      expect(pdfInkHit(e, const Offset(500, 500), 20), false);
      expect(
        pdfInkSweepHit(e, const Offset(80, 0), const Offset(80, 100), 1),
        true,
      );
    },
  );

  test(
    'rejected drawings remain visible and retry without duplicate history',
    () {
      var accept = false;
      final session = PdfInkSession(null, 'hash', (_) => accept, false);
      addTearDown(session.dispose);
      final a = stroke('retry');
      expect(session.commit(PdfInkDelta(add: [a])), false);
      expect(session.document.elements, isEmpty);
      expect(session.recoveryStrokes.single.data, same(a.data));
      accept = true;
      session.retry();
      expect(session.rejected, isNull);
      expect(session.document.elements.single.id, 'retry');
      session.undo();
      expect(session.document.elements, isEmpty);
      expect(session.canUndo, false);
    },
  );

  test(
    'dense-page spatial queries and incremental erasing preserve paint order',
    () {
      final elements = [
        for (var i = 0; i < 10000; i++)
          CanvasElement(
            immutableObjectData({
              ...stroke('dense-$i').data,
              'pageWidth': 10000.0,
              'pageHeight': 10000.0,
              'x': (i % 100) * 100.0,
              'y': (i ~/ 100) * 100.0,
              'width': 10.0,
              'height': 10.0,
              'points': [
                {'x': 0.0, 'y': 0.0, 'pressure': .5, 'timeMs': 0},
                {'x': 10.0, 'y': 10.0, 'pressure': .7, 'timeMs': 1},
              ],
            }),
          ),
      ];
      final raw = immutableObjectData({
        'version': 1,
        'checksum': 'hash',
        'elements': [for (final e in elements) e.data],
      });
      final session = PdfInkSession(raw, 'hash', (_) => true, false);
      addTearDown(session.dispose);
      session.query(1, const CanvasBounds(100, 100, 20, 20));
      final watch = Stopwatch()..start();
      var hits = 0;
      for (var i = 0; i < 2000; i++) {
        hits += session
            .query(1, CanvasBounds((i % 90) * 100.0, (i % 90) * 100.0, 20, 20))
            .length;
      }
      watch.stop();
      expect(hits, 2000);
      expect(session.commit(PdfInkDelta(remove: [elements[101]])), true);
      expect(session.query(1, const CanvasBounds(100, 100, 20, 20)), isEmpty);
      session.undo();
      expect(
        session.query(1, const CanvasBounds(100, 100, 20, 20)).single.id,
        'dense-101',
      );
      // ignore: avoid_print
      print(
        'PDF 10,000-stroke page: 2,000 visible queries ${watch.elapsedMicroseconds} us',
      );
    },
  );

  test(
    '20,000 page lookup visits only visible rows including two-page spreads',
    () {
      final rects = [
        for (var i = 0; i < 20000; i++)
          Rect.fromLTWH((i % 2) * 410, (i ~/ 2) * 320, 400, 300),
      ];
      final layout = PdfPageLayout(
        pageLayouts: rects,
        documentSize: const Size(820, 3200000),
      );
      final index = PdfInkPageIndex();
      expect(
        index.visible(layout, const Rect.fromLTWH(0, 100 * 320, 820, 300)),
        [200, 201],
      );
      final watch = Stopwatch()..start();
      var visits = 0;
      for (var i = 0; i < 10000; i++) {
        visits += index
            .visible(layout, Rect.fromLTWH(0, (i % 9000) * 320, 820, 300))
            .length;
      }
      watch.stop();
      expect(visits, 20000);
      // Diagnostic only: release-device frame latency is measured separately.
      // ignore: avoid_print
      print(
        'PDF 20,000-page index: 10,000 camera queries ${watch.elapsedMicroseconds} us, $visits visible pages',
      );
    },
  );

  test(
    'drawing persists, preserves original attachment, rejects stale source and reports save failures',
    () async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      final c = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 200 && c.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      addTearDown(() async {
        store.failWrites = false;
        await c.flushAll();
        container.dispose();
      });
      final bytes = researchPdf();
      final file = await repo.importAttachment(
        name: 'Drawing.pdf',
        bytes: bytes,
      );
      await c.refresh();
      final checksum = file.properties['checksum'] as String;
      c.edit(
        file.id,
        data: {
          'future': {'preserve': 'yes'},
        },
      );
      expect(
        c.applyPdfInkCommand(
          file.id,
          checksum,
          PdfInkDelta(add: [stroke('a')]),
        ),
        true,
      );
      expect(c.find(file.id)!.data['future'], {'preserve': 'yes'});
      await c.flush(file.id);
      expect(c.dirty.contains(file.id), false);
      await c.refresh();
      expect(
        PdfInkDocument.read(
          c.find(file.id)!.data['pdfInk'],
          checksum,
        ).elements.single.id,
        'a',
      );
      expect(
        c.applyPdfInkCommand(file.id, 'stale', PdfInkDelta(add: [stroke('b')])),
        false,
      );
      final savedFile = c.find(file.id)!;
      final exported = await exportPdfAnnotations(
        bytes,
        file.id,
        checksum,
        [],
        ink: [stroke('a')],
      );
      expect(await c.saveAnnotatedPdfCopy(savedFile, [], exported), true);
      expect(c.find(file.id)!.properties['checksum'], checksum);
      store.failWrites = true;
      expect(
        c.applyPdfInkCommand(
          file.id,
          checksum,
          PdfInkDelta(add: [stroke('b')]),
        ),
        true,
      );
      await c.flush(file.id);
      expect(c.dirty.contains(file.id), true);
      expect(
        PdfInkDocument.read(
          c.find(file.id)!.data['pdfInk'],
          checksum,
        ).elements.length,
        2,
      );
      store.failWrites = false;
    },
    skip: !ready,
  );

  test(
    'Vault lookup index owns assigned lists and updates with replacements',
    () async {
      final store = MemoryStore();
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(
            WorkspaceRepository(store: store, index: MemoryObjectIndex()),
          ),
        ],
      );
      container.read(workspaceProvider);
      final c = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 200 && c.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      addTearDown(container.dispose);
      final now = DateTime.utc(2026);
      final list = [
        for (var i = 0; i < 20000; i++)
          UniversalObject(
            id: 'object-$i',
            workspaceId: 'test',
            typeId: 'orbit.note',
            title: '$i',
            createdAt: now,
            updatedAt: now,
          ),
      ];
      c.objects = list;
      list.clear();
      expect(c.objects.length, 20000);
      final indexed = Stopwatch()..start();
      var found = 0;
      for (var i = 0; i < 5000; i++) {
        if (c.find('object-${19999 - i}') != null) found++;
      }
      indexed.stop();
      expect(found, 5000);
      final linear = Stopwatch()..start();
      found = 0;
      for (var i = 0; i < 5000; i++) {
        if (c.objects.where((o) => o.id == 'object-${19999 - i}').firstOrNull !=
            null) {
          found++;
        }
      }
      linear.stop();
      expect(found, 5000);
      // ignore: avoid_print
      print(
        'Vault 20,000 objects / 5,000 lookups: indexed ${indexed.elapsedMicroseconds} us vs scan ${linear.elapsedMicroseconds} us',
      );
      expect(indexed.elapsedMicroseconds, lessThan(linear.elapsedMicroseconds));
      final first = c.objects.first;
      c.objects = [first, first.copyWith(title: 'Duplicate')];
      expect(c.find(first.id), same(first));
      c.objects = [first.copyWith(title: 'Replaced')];
      expect(c.find(first.id)!.title, 'Replaced');
      c.objects = [];
      expect(c.find(first.id), isNull);
    },
  );

  test(
    'native ink-only vector export retains colors, pressure and original text',
    () async {
      final bytes = researchPdf();
      final checksum = sha256.convert(bytes).toString();
      final exported = await exportPdfAnnotations(
        bytes,
        'file',
        checksum,
        [],
        ink: [stroke('a'), stroke('b', page: 2, highlighter: true)],
      );
      expect(sha256.convert(bytes).toString(), checksum);
      final doc = await PdfDocument.openData(exported);
      try {
        expect(
          (await doc.pages[0].loadText())!.fullText,
          contains('Orbit research page one'),
        );
        final image = (await doc.pages[0].render(
          fullWidth: 800,
          fullHeight: 600,
        ))!;
        try {
          final rgba = image.pixels;
          var blue = 0;
          for (var i = 0; i < rgba.length; i += 4) {
            if (rgba[i] > 160 && rgba[i + 2] < 100) blue++;
          }
          expect(
            blue,
            greaterThan(100),
            reason: 'Exported blue ink must render visibly',
          );
          final uiImage = await image.createImage();
          try {
            final png = await uiImage.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('.local/pdf-ink-qa').create(recursive: true);
            await File(
              '.local/pdf-ink-qa/exported-ink.png',
            ).writeAsBytes(png!.buffer.asUint8List());
          } finally {
            uiImage.dispose();
          }
        } finally {
          image.dispose();
        }
        final out = await Directory(
          '.local/pdf-ink-qa',
        ).create(recursive: true);
        await File('${out.path}/ink.pdf').writeAsBytes(exported);
      } finally {
        await doc.dispose();
      }
      await expectLater(
        exportPdfAnnotations(
          bytes,
          'file',
          checksum,
          [],
          ink: [stroke('wrong', width: 500)],
        ),
        throwsA(predicate((e) => e.toString().contains('geometry differs'))),
      );
    },
    skip: !ready,
  );

  test(
    'ink export respects intrinsic rotation, crop, smooth nibs, dots and transparency',
    () async {
      final bytes = rotatedPdf(),
          checksum = sha256.convert(rotatedPdf()).toString();
      final original = await PdfDocument.openData(bytes);
      late final double w, h;
      try {
        w = original.pages[0].width;
        h = original.pages[0].height;
      } finally {
        await original.dispose();
      }
      final base = stroke('rotated', width: w, height: h);
      final smooth = CanvasElement(
        immutableObjectData({
          ...base.data,
          'id': 'smooth',
          'y': 130.0,
          'points': [
            for (final p in base.inkSamples!) {...p, 'pressure': 1.0},
          ],
        }),
      );
      final dot = CanvasElement(
        immutableObjectData({
          ...base.data,
          'id': 'dot',
          'x': 180.0,
          'width': 0.0,
          'height': 0.0,
          'points': [
            {'x': 0.0, 'y': 0.0, 'pressure': .6, 'timeMs': 0},
          ],
        }),
      );
      final marker = CanvasElement(
        immutableObjectData({
          ...base.data,
          'id': 'marker',
          'page': 2,
          'penStyle': 'highlighter',
          'isHighlighter': true,
          'color': 0xffeab308,
        }),
      );
      final exported = await exportPdfAnnotations(
        bytes,
        'file',
        checksum,
        [],
        ink: [base, smooth, dot, marker],
      );
      final doc = await PdfDocument.openData(exported);
      try {
        for (var i = 0; i < 2; i++) {
          final raster = (await doc.pages[i].render(
            fullWidth: w * 3,
            fullHeight: h * 3,
          ))!;
          try {
            // Blue/yellow marks must remain at their canonical displayed-page
            // position, independent of PDF page rotation and crop origin.
            final pixels = raster.pixels;
            final x = (30 * 3).round(),
                y = (40 * 3).round(),
                offset = (y * raster.width + x) * 4;
            if (i == 0) {
              expect(pixels[offset], greaterThan(150));
              expect(pixels[offset + 2], lessThan(150));
            } else {
              expect(pixels[offset + 2], greaterThan(200));
              expect(pixels[offset], inInclusiveRange(80, 230));
            }
          } finally {
            raster.dispose();
          }
        }
      } finally {
        await doc.dispose();
      }
    },
    skip: !ready,
  );

  testWidgets(
    'PDF pen batches pressure input, ignores palms and leaves source widget stable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final viewer = PdfViewerController();
      Object? saved;
      var saves = 0, builds = 0, rasters = 0;
      final session = PdfInkSession(null, 'hash', (delta) {
        saved = PdfInkDocument.read(saved, 'hash').apply(delta);
        saves++;
        return saved != null;
      }, false);
      session.drawing = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfInkSurface(
              viewer: viewer,
              session: session,
              child: Builder(
                builder: (context) {
                  builds++;
                  return PdfViewer.data(
                    researchPdf(),
                    sourceName: 'ink-test',
                    controller: viewer,
                    params: PdfViewerParams(
                      textSelectionParams: const PdfTextSelectionParams(
                        enabled: false,
                      ),
                      onPageRenderCompleted: (_, _) => rasters++,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 150 && !viewer.isReady; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(viewer.isReady, true);
      await tester.pumpAndSettle();
      final baseBuilds = builds;
      Offset point(double x, double y) => viewer.documentToGlobal(
        viewer.layout.pageLayouts[0].topLeft + Offset(x, y),
      )!;
      final origin = point(40, 40);
      await tester.sendEventToBinding(
        PointerDownEvent(
          pointer: 1,
          kind: PointerDeviceKind.stylus,
          position: origin,
          pressure: .3,
        ),
      );
      await tester.pump();
      for (final p in [90, 91]) {
        await tester.sendEventToBinding(
          PointerDownEvent(
            pointer: p,
            kind: PointerDeviceKind.touch,
            position: origin + const Offset(100, 40),
          ),
        );
      }
      final beforeRasters = rasters;
      final watch = Stopwatch()..start();
      for (var i = 1; i <= 1500; i++) {
        await tester.sendEventToBinding(
          PointerMoveEvent(
            pointer: 1,
            kind: PointerDeviceKind.stylus,
            position: origin + Offset(i * .1, (i % 5).toDouble()),
            pressure: i.isEven ? .3 : .7,
            timeStamp: Duration(milliseconds: i),
          ),
        );
        if (i % 100 == 0) await tester.pump();
      }
      watch.stop();
      expect(saves, 0);
      expect(builds, baseBuilds);
      expect(rasters - beforeRasters, lessThan(3));
      await tester.sendEventToBinding(
        PointerCancelEvent(
          pointer: 91,
          kind: PointerDeviceKind.touch,
          position: origin,
        ),
      );
      expect(
        tester
            .widget<CanvasLiveInkLayer>(find.byType(CanvasLiveInkLayer))
            .stroke(),
        isNotNull,
      );
      await tester.sendEventToBinding(
        PointerUpEvent(
          pointer: 1,
          kind: PointerDeviceKind.stylus,
          position: origin + const Offset(155, 0),
          timeStamp: const Duration(milliseconds: 1502),
        ),
      );
      await tester.sendEventToBinding(
        PointerUpEvent(
          pointer: 90,
          kind: PointerDeviceKind.touch,
          position: origin,
        ),
      );
      await tester.pump();
      expect(saves, 1);
      final committed = session.document.elements.single;
      expect(committed.inkSamples!.last['pressure'], .3);
      expect(committed.inkSamples!.length, greaterThan(1400));
      session.undo();
      expect(session.document.elements, isEmpty);
      session.redo();
      expect(session.document.elements.length, 1);
      session.configure(() => session.tool = PdfInkTool.eraser);
      await tester.sendEventToBinding(
        PointerDownEvent(
          pointer: 2,
          kind: PointerDeviceKind.stylus,
          position: origin,
        ),
      );
      await tester.sendEventToBinding(
        PointerUpEvent(
          pointer: 2,
          kind: PointerDeviceKind.stylus,
          position: origin,
        ),
      );
      await tester.pump();
      expect(session.document.elements, isEmpty);
      session.undo();
      expect(session.document.elements.length, 1);
      session.configure(() => session.drawing = true);
      final beforePan = viewer.visibleRect;
      final pan = await tester.startGesture(
        const Offset(500, 500),
        kind: PointerDeviceKind.touch,
      );
      await pan.moveBy(const Offset(0, -100));
      await tester.pump();
      await pan.moveBy(const Offset(0, -80));
      await pan.up();
      await tester.pumpAndSettle();
      expect(viewer.visibleRect.top, greaterThan(beforePan.top));
      expect(session.document.elements.length, 1);
      session.configure(() {
        session.drawing = true;
        session.tool = PdfInkTool.pen;
      });
      final dot = viewer.documentToGlobal(
        viewer.layout.pageLayouts[1].topLeft + const Offset(80, 80),
      )!;
      await tester.sendEventToBinding(
        PointerDownEvent(
          pointer: 7,
          kind: PointerDeviceKind.stylus,
          position: dot,
        ),
      );
      await tester.sendEventToBinding(
        PointerCancelEvent(
          pointer: 7,
          kind: PointerDeviceKind.stylus,
          position: dot,
        ),
      );
      await tester.pump();
      expect(session.document.elements.length, 1);
      // ignore: avoid_print
      print(
        'PDF active pressure: 1,500 samples + 15 live frames ${watch.elapsedMilliseconds} ms; source builds ${builds - baseBuilds}',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      session.dispose();
    },
    skip: !ready,
  );

  testWidgets(
    'reader exposes drawing and keeps saved strokes through read/zoom mode',
    (tester) async {
      final bytes = researchPdf(),
          hash = sha256.convert(researchPdf()).toString();
      await prepareCapture(tester);
      await tester.binding.setSurfaceSize(const Size(820, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const captureKey = ValueKey('pdf-ink-reader-capture');
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: OrbitPdfReader(
                objectId: 'pdf',
                title: 'Draw',
                checksum: hash,
                inkData: PdfInkDocument.read(
                  null,
                  hash,
                ).apply(PdfInkDelta(add: [stroke('shown')])),
                onInkChanged: (_) => true,
                loadBytes: () async => bytes,
                onOpenOriginal: () {},
                onOpenExternal: (_) {},
                onReadingState: (_, _) {},
                onQuote: (_, _) async {},
                onBookmarks: (_) {},
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 150; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
        final b = tester.widget<TextButton>(
          find.byKey(const ValueKey('pdf-draw-toggle')),
        );
        if (b.onPressed != null) break;
      }
      await tester.tap(find.byKey(const ValueKey('pdf-draw-toggle')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('PDF pen'), findsOneWidget);
      expect(
        tester
            .widget<PdfViewer>(find.byType(PdfViewer))
            .params
            .textSelectionParams!
            .enabled,
        false,
      );
      expect(find.byTooltip('Erase whole stroke'), findsOneWidget);
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 25));
      }
      await captureUi(tester, 'pdf-ink-tablet', target: find.byKey(captureKey));
      await tester.tap(find.byKey(const ValueKey('pdf-draw-toggle')));
      await tester.pump();
      expect(
        tester
            .widget<PdfViewer>(find.byType(PdfViewer))
            .params
            .textSelectionParams!
            .enabled,
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
    skip: !ready,
  );
}
