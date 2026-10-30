import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:orbit_note/features/canvas/canvas_live_ink.dart';
import 'package:orbit_note/features/canvas/canvas_scene_viewport.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/pdf/pdf_content_fit.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'pdf_markup_interactions_test.dart' show mark;
import 'pdf_reader_reliability_test.dart'
    show desktop, ready, viewer, waitNative;
import 'support/pdf_fixture.dart';

CanvasElement stroke(
  String id, {
  String style = 'ballpoint',
  int count = 1000,
  double y = 20,
  int color = 0xff33ddaa,
}) => CanvasElement({
  'id': id,
  'type': 'ink',
  'x': 20.0,
  'y': y,
  'width': 800.0,
  'height': 10.0,
  'color': color,
  'penStyle': style,
  'strokeWidth': 3.0,
  'isHighlighter': style == 'highlighter',
  'points': [
    for (var i = 0; i < count; i++)
      {
        'x': i * 800 / count,
        'y': math.sin(i * .03) * 4 + 5,
        'pressure': .2 + (i % 100) / 125,
        'timeMs': i,
        'futureSampleData': 'preserved',
      },
  ],
});

ui.Picture paintScene(
  CanvasScene scene,
  CanvasTextCache text, {
  CanvasInkCache? ink,
  CanvasCamera camera = const CanvasCamera(),
  CanvasElement? preview,
}) {
  final recorder = ui.PictureRecorder();
  OrbitCanvasPainter(
    scene: scene,
    camera: camera,
    selection: {},
    objects: {},
    colors: ColorScheme.fromSeed(seedColor: Colors.purple),
    textCache: text,
    inkCache: ink,
    preview: preview,
    backgroundStyle: 'none',
  ).paint(Canvas(recorder), const Size(1000, 700));
  return recorder.endRecording();
}

Future<List<int>> pixels(ui.Picture picture) async {
  final image = await picture.toImage(1000, 700);
  try {
    return (await image.toByteData())!.buffer.asUint8List().toList();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

class _Token extends PdfPageRenderCancellationToken {
  bool canceled = false;
  @override
  void cancel() => canceled = true;
  @override
  bool get isCanceled => canceled;
}

class _Document extends Fake implements PdfDocument {}

class _Page extends Fake implements PdfPage {
  _Page(this.document, this.pageNumber);
  @override
  final PdfDocument document;
  @override
  final int pageNumber;
  @override
  double get width => 612;
  @override
  double get height => 792;
  @override
  PdfPageRotation get rotation => PdfPageRotation.none;
  @override
  PdfPageRenderCancellationToken createCancellationToken() => _Token();
}

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final nativeReady = await initPdfTesting();

  test('100000 retained ink samples reuse vectors over 60 camera changes', () {
    final scene = CanvasScene.fromJson({
      'schemaVersion': 1,
      'elements': [
        for (var i = 0; i < 100; i++) stroke('$i', y: i * 6.0 + 5).data,
      ],
    });
    final original = scene.toJson();
    final text = CanvasTextCache(), ink = CanvasInkCache();
    addTearDown(text.dispose);
    addTearDown(ink.dispose);
    int record(CanvasInkCache? cache) {
      final watch = Stopwatch()..start();
      for (var i = 0; i < 60; i++) {
        paintScene(
          scene,
          text,
          ink: cache,
          camera: CanvasCamera(x: i * .1, zoom: 1 + i * .0001),
        ).dispose();
      }
      return watch.elapsedMicroseconds;
    }

    final cold = record(null), retained = record(ink);
    expect(ink.recordingCount, 100);
    expect(ink.retainedSamples, 100000);
    expect(scene.toJson(), original);
    debugPrint(
      'Ink 100000 samples, 60 cameras: cold=$cold us retained=$retained us',
    );
  });

  testWidgets(
    'all pen styles retain pixels through caching, edits, undo and zoom',
    (tester) async {
      final text = CanvasTextCache(), ink = CanvasInkCache();
      addTearDown(text.dispose);
      addTearDown(ink.dispose);
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          for (final (i, style) in [
            'ballpoint',
            'pencil',
            'brush',
            'calligraphy',
            'fountain',
            'marker',
            'highlighter',
          ].indexed)
            stroke('$i', style: style, y: i * 70.0 + 10, count: 200).data,
        ],
      });
      final history = CanvasHistory(scene);
      await tester.runAsync(() async {
        for (var pass = 0; pass < 5; pass++) {
          if (pass == 1) {
            history.put(scene['0']!.copy({'color': 0xffbb77ff}));
            history.commit();
          }
          if (pass == 2) history.undo();
          if (pass == 3) history.redo();
          final camera = CanvasCamera(x: pass * 3.0, zoom: 1 + pass * .1);
          expect(
            await pixels(paintScene(scene, text, ink: ink, camera: camera)),
            await pixels(paintScene(scene, text, camera: camera)),
          );
        }
      });
      expect(ink.recordingCount, 8); // Seven originals and one edited snapshot.
    },
  );

  test(
    'ink caches evict native pictures and bypass oversized or transient strokes',
    () {
      final text = CanvasTextCache(),
          ink = CanvasInkCache(maxEntries: 2, maxSamples: 20);
      addTearDown(text.dispose);
      addTearDown(ink.dispose);
      final scene = CanvasScene.fromJson({'schemaVersion': 1, 'elements': []});
      for (var i = 0; i < 20; i++) {
        scene.put(stroke('$i', count: 10));
        paintScene(scene, text, ink: ink).dispose();
        expect(ink.entryCount, lessThanOrEqualTo(2));
        expect(ink.retainedSamples, lessThanOrEqualTo(20));
        scene.remove('$i');
      }
      final before = ink.recordingCount;
      paintScene(scene, text, ink: ink, preview: stroke('preview')).dispose();
      scene.put(stroke('huge', count: 21));
      paintScene(scene, text, ink: ink).dispose();
      expect(ink.recordingCount, before);
      ink.dispose();
      expect(ink.entryCount, 0);
      expect(ink.retainedSamples, 0);
    },
  );

  test(
    'malformed imported pressure and non-map samples cannot crash any nib',
    () {
      final text = CanvasTextCache();
      addTearDown(text.dispose);
      for (final style in [
        'ballpoint',
        'pencil',
        'brush',
        'calligraphy',
        'fountain',
        'marker',
      ]) {
        final points = <dynamic>[
          null,
          'unknown',
          for (final (i, pressure) in [
            'invalid',
            double.nan,
            double.infinity,
            double.negativeInfinity,
            -100,
            100,
            null,
            .5,
          ].indexed)
            {'x': i * 30.0, 'y': 10.0, 'pressure': pressure},
        ];
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            stroke(style, style: style).copy({'points': points}).data,
          ],
        });
        expect(() => paintScene(scene, text).dispose(), returnsNormally);
        expect(points[0], isNull);
        expect(points[1], 'unknown');
        expect((points[3] as Map)['pressure'], isNaN);
      }
    },
  );

  testWidgets(
    'batched pen input keeps release endpoint, ignores another pointer cancel, and undoes once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var data = <String, dynamic>{'schemaVersion': 1, 'elements': []};
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'pen',
              data: data,
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (next) {
                data = next;
                saves++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Draw and erase'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pen (P)'));
      await tester.pumpAndSettle();
      final surface = find
          .byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
          )
          .first;
      final origin = tester.getTopLeft(find.byType(CanvasSceneViewport));
      await tester.sendEventToBinding(
        const PointerDownEvent(
          pointer: 11,
          kind: PointerDeviceKind.stylus,
          position: Offset(200, 300),
          pressure: .6,
        ),
      );
      await tester.pump();
      final live = find.byType(CanvasLiveInkLayer);
      final firstPreview = tester.widget<CanvasLiveInkLayer>(live).stroke()!;
      final initialPreviewCount = (firstPreview.data['points'] as List).length;
      final savedScenePainter = tester.widget<CustomPaint>(surface).painter;
      // Two palm contacts must not cancel a captured stylus.
      for (final pointer in [98, 99]) {
        await tester.sendEventToBinding(
          PointerDownEvent(
            pointer: pointer,
            kind: PointerDeviceKind.touch,
            position: const Offset(800, 500),
          ),
        );
      }
      for (var i = 1; i <= 1000; i++) {
        await tester.sendEventToBinding(
          PointerMoveEvent(
            pointer: 11,
            kind: PointerDeviceKind.stylus,
            position: Offset(200 + i * .5, 300 + i % 2),
            pressure: .6,
            timeStamp: Duration(milliseconds: i),
          ),
        );
      }
      await tester.sendEventToBinding(
        const PointerCancelEvent(
          pointer: 99,
          kind: PointerDeviceKind.touch,
          position: Offset(800, 500),
        ),
      );
      expect(saves, 0);
      expect(initialPreviewCount, 1);
      // Live previews deliberately borrow gesture-owned samples. Only the
      // committed stroke freezes them; copying each preview causes input lag.
      expect((firstPreview.data['points'] as List).length, 1001);
      await tester.pump();
      expect(
        identical(
          tester.widget<CustomPaint>(surface).painter,
          savedScenePainter,
        ),
        true,
        reason: 'Live pen samples must not rebuild the saved-scene painter',
      );
      await tester.sendEventToBinding(
        const PointerUpEvent(
          pointer: 11,
          kind: PointerDeviceKind.stylus,
          position: Offset(750, 310),
          pressure: 0,
          timeStamp: Duration(milliseconds: 1100),
        ),
      );
      await tester.pumpAndSettle();
      expect(saves, 1);
      final saved = (data['elements'] as List).single as Map;
      final points = saved['points'] as List;
      expect(points, hasLength(1002));
      expect((saved['x'] as num) + points.last['x'], 750 - origin.dx);
      expect((saved['y'] as num) + points.last['y'], 310 - origin.dy);
      expect(points.last['pressure'], .6);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(data['elements'], isEmpty);
    },
  );

  test(
    'dense PDF hit testing matches paint order at edges, overlaps and invalid coordinates',
    () {
      final annotations = [
        for (var i = 0; i < 10000; i++)
          PdfAnnotation(
            mark('$i', i % 2 + 1).object.copyWith(
              properties: {
                ...mark('$i', i % 2 + 1).object.properties,
                'pdfSource': {
                  ...mark('$i', i % 2 + 1).source,
                  'regions': [
                    {
                      'id': '$i',
                      'type': 'rectangle',
                      'page': i % 2 + 1,
                      'x': (i % 10) * .09,
                      'y': (i % 100) * .009,
                      'width': .1,
                      'height': .04,
                    },
                  ],
                },
              },
            ),
          ),
      ];
      final watch = Stopwatch()..start();
      final index = PdfAnnotationIndex(annotations, 'paper', 'v1');
      final buildUs = watch.elapsedMicroseconds;
      final random = math.Random(42);
      for (var i = 0; i < 1000; i++) {
        final x = random.nextDouble(), y = random.nextDouble();
        final page = i % 2 + 1;
        PdfAnnotation? expected;
        for (final entry in index.markupForPage(page).reversed) {
          final r = entry.region;
          if (x >= r.x &&
              x <= r.x + r.width &&
              y >= r.y &&
              y <= r.y + r.height) {
            expected = entry.annotation;
            break;
          }
        }
        expect(index.hitTest(page, x, y)?.object.id, expected?.object.id);
      }
      for (final bad in [double.nan, double.infinity, -1.0, 1.1]) {
        expect(index.hitTest(1, bad, .2), isNull);
        expect(index.hitTest(1, .2, bad), isNull);
      }
      debugPrint(
        'PDF 10000 highlights: index=$buildUs us; 1000 checked hits=${watch.elapsedMilliseconds} ms (includes brute-force oracle)',
      );
    },
  );

  testWidgets(
    'recognized strokes commit, release capture and remain individually undoable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var data = <String, dynamic>{'schemaVersion': 1, 'elements': []};
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'recognized',
              data: data,
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (next) {
                data = next;
                saves++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Draw and erase'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pen (P)'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pump();
      for (var n = 0; n < 2; n++) {
        final start = Offset(200 + n * 300, 300);
        final gesture = await tester.startGesture(
          start,
          kind: PointerDeviceKind.stylus,
        );
        for (var i = 1; i <= 20; i++) {
          await gesture.moveTo(start + Offset(i * 7.0, 0));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(saves, n + 1);
        final elements = data['elements'] as List;
        expect(elements, hasLength(n + 1));
        expect(elements.last['type'], isNot('ink'));
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(data['elements'], hasLength(1));
      final canceled = await tester.startGesture(
        const Offset(300, 450),
        kind: PointerDeviceKind.stylus,
      );
      await canceled.moveTo(const Offset(500, 500));
      await canceled.cancel();
      await tester.pumpAndSettle();
      expect(data['elements'], hasLength(1));
    },
  );

  testWidgets(
    'first stylus stroke works from select and inverted erasing restores the pen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var data = <String, dynamic>{'schemaVersion': 1, 'elements': []};
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'stylus',
              data: data,
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (next) => data = next,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = await tester.startGesture(
        const Offset(300, 300),
        kind: PointerDeviceKind.stylus,
      );
      await first.moveTo(const Offset(500, 300));
      await first.up();
      await tester.pumpAndSettle();
      expect(data['elements'], hasLength(1));
      final eraser = await tester.startGesture(
        const Offset(400, 300),
        kind: PointerDeviceKind.invertedStylus,
      );
      await eraser.up();
      await tester.pumpAndSettle();
      expect(data['elements'], isEmpty);
      final next = await tester.startGesture(
        const Offset(300, 350),
        kind: PointerDeviceKind.stylus,
      );
      await next.moveTo(const Offset(500, 350));
      await next.up();
      await tester.pumpAndSettle();
      expect(data['elements'], hasLength(1));
      expect((data['elements'] as List).single['type'], 'ink');
    },
  );

  test(
    'comfort cache deduplicates work, separates documents and applies LRU bounds',
    () async {
      final doc = _Document(), other = _Document();
      var calls = 0;
      final cache = PdfContentWidthCache(
        capacity: 2,
        measure: (_, _) async {
          calls++;
          return const Rect.fromLTWH(.1, 0, .8, 1);
        },
      );
      addTearDown(cache.dispose);
      final a = cache.measure(_Page(doc, 1));
      final b = cache.measure(_Page(doc, 1));
      expect(identical(a, b), true);
      await Future.wait([a, b]);
      expect(calls, 1);
      await cache.measure(_Page(doc, 2));
      await cache.measure(
        _Page(doc, 1),
      ); // Refresh LRU; page 2 should leave next.
      await cache.measure(_Page(doc, 3));
      expect(cache.cachedPages, 2);
      await cache.measure(_Page(doc, 1));
      expect(calls, 3);
      await cache.measure(_Page(doc, 2));
      expect(calls, 4);
      await cache.measure(_Page(other, 2));
      expect(calls, 5);
      cache.clear();
      expect(cache.cachedPages, 0);
      await cache.measure(_Page(other, 2));
      expect(calls, 6);
    },
  );

  test(
    'comfort measurement supersedes 200 rapid requests and retries failures',
    () async {
      final document = _Document();
      final jobs = <Completer<Rect>>[],
          tokens = <PdfPageRenderCancellationToken>[];
      final started = <int>[];
      final cache = PdfContentWidthCache(
        capacity: 2,
        measure: (page, token) {
          started.add(page.pageNumber);
          tokens.add(token);
          final job = Completer<Rect>();
          jobs.add(job);
          return job.future;
        },
      );
      addTearDown(cache.dispose);
      final requests = [
        for (var i = 1; i <= 200; i++) cache.measure(_Page(document, i)),
      ];
      expect(started, [1]);
      expect(tokens.single.isCanceled, true);
      jobs.first.complete(const Rect.fromLTWH(.1, 0, .8, 1));
      await Future<void>.delayed(Duration.zero);
      expect(started, [1, 200]);
      jobs.last.complete(const Rect.fromLTWH(.2, 0, .6, 1));
      final results = await Future.wait(requests);
      expect(results.take(199), everyElement(isNull));
      expect(results.last, const Rect.fromLTWH(.2, 0, .6, 1));
      expect(cache.cachedPages, 1);
      expect(await cache.measure(_Page(document, 200)), results.last);
      final failure = cache.measure(_Page(document, 201));
      final assertion = expectLater(failure, throwsStateError);
      jobs.last.completeError(StateError('transient renderer failure'));
      await assertion;
      final retry = cache.measure(_Page(document, 201));
      jobs.last.complete(const Rect.fromLTWH(0, 0, 1, 1));
      await retry;
      expect(started, [1, 200, 201, 201]);
      final pending = cache.measure(_Page(document, 202));
      cache.dispose();
      jobs.last.completeError(StateError('retired native page'));
      expect(await pending, isNull);
      expect(cache.cachedPages, 0);
      expect(await cache.measure(_Page(document, 203)), isNull);
    },
  );

  test(
    'native 300-page PDF renders, extracts distant text and bounds content cache',
    () async {
      final watch = Stopwatch()..start();
      final doc = await PdfDocument.openData(largeResearchPdf());
      final cache = PdfContentWidthCache(capacity: 4);
      try {
        expect(doc.pages, hasLength(300));
        for (final p in [1, 150, 300, 75, 225, 10]) {
          expect(
            (await doc.pages[p - 1].loadText())!.fullText,
            contains('Orbit page $p line 39'),
          );
          expect(await cache.measure(doc.pages[p - 1]), isNotNull);
          expect(cache.cachedPages, lessThanOrEqualTo(4));
        }
        debugPrint(
          'Native PDFium: 300 pages, 6 distant text/raster measurements=${watch.elapsedMilliseconds} ms',
        );
      } finally {
        cache.dispose();
        await doc.dispose();
      }
    },
    skip: !nativeReady,
  );

  testWidgets(
    'native long PDF keeps the latest rapid page destination and closes safely',
    (tester) async {
      await desktop(tester);
      final bytes = largeResearchPdf();
      final positions = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: OrbitPdfReader(
              objectId: 'paper',
              title: 'Large research',
              checksum: 'v1',
              loadBytes: () async => bytes,
              annotations: [
                for (var p = 1; p <= 300; p++)
                  for (var i = 0; i < 10; i++) mark('$p:$i', p, count: 8),
              ],
              onOpenOriginal: () {},
              onOpenExternal: (_) {},
              onReadingState: (p, _) => positions.add(p),
              onQuote: (_, _) async {},
              onBookmarks: (_) {},
            ),
          ),
        ),
      );
      await waitNative(tester, () => ready(tester));
      for (final p in [150, 299, 50, 300]) {
        await viewer(
          tester,
        ).controller!.goToPage(pageNumber: p, duration: Duration.zero);
        await tester.pump();
      }
      await waitNative(
        tester,
        () => viewer(tester).controller!.pageNumber == 300,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(positions.last, 300);
      expect(tester.takeException(), isNull);
    },
    skip: !nativeReady,
  );
}
