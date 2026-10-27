import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'support/pdf_fixture.dart';
import 'pdf_reader_reliability_test.dart' as reader_fixture;

class Token extends PdfPageRenderCancellationToken {
  bool canceled = false;
  @override
  void cancel() => canceled = true;
  @override
  bool get isCanceled => canceled;
}

class Document extends Fake implements PdfDocument {
  Document(int count) {
    pages = List.generate(count, (i) => Page(this, i + 1));
  }
  @override
  late List<PdfPage> pages;
  @override
  String get sourceName => 'synthetic-${identityHashCode(this)}';
  @override
  bool get isEncrypted => false;
  @override
  PdfPermissions? get permissions => null;
  @override
  Stream<PdfDocumentEvent> get events => updates.stream;
  final updates = StreamController<PdfDocumentEvent>.broadcast();
  int progressiveLoads = 0;
  @override
  Future<void> loadPagesProgressively<T>({
    PdfPageLoadingCallback<T>? onPageLoadProgress,
    T? data,
    Duration loadUnitDuration = const Duration(milliseconds: 250),
  }) async {
    progressiveLoads++;
  }

  @override
  Future<List<PdfOutlineNode>> loadOutline() async => [];
  final started = <int>[];
  bool disposed = false;
  @override
  Future<void> dispose() async {
    disposed = true;
    await updates.close();
  }
}

class Page extends Fake implements PdfPage {
  Page(this.document, this.pageNumber);
  @override
  final Document document;
  @override
  final int pageNumber;
  @override
  double get width => 400;
  @override
  double get height => 600;
  bool loaded = true;
  @override
  bool get isLoaded => loaded;
  @override
  PdfPageRotation get rotation => PdfPageRotation.none;
  @override
  PdfPageRenderCancellationToken createCancellationToken() => Token();
  @override
  Future<PdfPageRawText?> loadText() async => null;
  @override
  Future<List<PdfLink>> loadLinks({
    bool compact = false,
    bool enableAutoLinkDetection = true,
  }) async => [];
  int renders = 0, failures = 0;
  Completer<void>? gate;
  @override
  Future<PdfImage?> render({
    int x = 0,
    int y = 0,
    int? width,
    int? height,
    double? fullWidth,
    double? fullHeight,
    int? backgroundColor,
    PdfPageRotation? rotationOverride,
    PdfAnnotationRenderingMode annotationRenderingMode =
        PdfAnnotationRenderingMode.annotationAndForms,
    int flags = PdfPageRenderFlags.none,
    PdfPageRenderCancellationToken? cancellationToken,
  }) async {
    renders++;
    document.started.add(pageNumber);
    await gate?.future;
    if (cancellationToken?.isCanceled == true) return null;
    if (failures > 0) {
      failures--;
      throw StateError('Synthetic renderer failure');
    }
    final w = width ?? fullWidth!.toInt(), h = height ?? fullHeight!.toInt();
    final pixels = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 255);
    for (var y = 20; y < 40 && y < h; y++) {
      for (var x = 20; x < w - 20; x++) {
        final i = (y * w + x) * 4;
        pixels[i] = pixels[i + 1] = pixels[i + 2] = 20;
      }
    }
    return PdfImage.createFromBgraData(pixels, width: w, height: h);
  }
}

class DelayedRef extends PdfDocumentRef {
  DelayedRef(this.gate)
    : super(key: PdfDocumentRefKey('delayed-${identityHashCode(gate)}'));
  final Completer<PdfDocument> gate;
  @override
  Future<PdfDocument> loadDocument(
    PdfDocumentLoaderProgressCallback callback,
  ) => gate.future;
  @override
  PdfPasswordProvider? get passwordProvider => null;
  @override
  bool get firstAttemptByEmptyPassword => true;
}

Future<void> settle(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 160 && !done(); i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await t.pump(const Duration(milliseconds: 25));
  }
  expect(done(), isTrue);
}

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = await initPdfTesting();
  testWidgets('switching and closing PDF cancels long delayed page loading', (
    t,
  ) async {
    final a = Document(1), b = Document(1), controller = PdfViewerController();
    Widget host(Document document) => MaterialApp(
      home: PdfViewer(
        PdfDocumentRefDirect(document),
        controller: controller,
        params: const PdfViewerParams(
          behaviorControlParams: PdfViewerBehaviorControlParams(
            trailingPageLoadingDelay: Duration(hours: 1),
          ),
        ),
      ),
    );
    await t.pumpWidget(host(a));
    await settle(
      t,
      () => controller.isReady && identical(controller.document, a),
    );
    await t.pumpWidget(host(b));
    await settle(
      t,
      () => controller.isReady && identical(controller.document, b),
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 200));
    expect(a.progressiveLoads, 0);
    expect(b.progressiveLoads, 0);
    expect(t.takeException(), isNull);
    if (!a.disposed) await a.dispose();
    if (!b.disposed) await b.dispose();
  });
  test(
    'late load disposes a retired document but direct loads remain usable',
    () async {
      final gate = Completer<PdfDocument>(),
          ref = DelayedRef(Completer<PdfDocument>());
      final retired = DelayedRef(gate).resolveListenable();
      void listener() {}
      retired.addListener(listener);
      final load = retired.load();
      await Future<void>.delayed(Duration.zero);
      retired.removeListener(listener);
      final doc = Document(1);
      gate.complete(doc);
      await load;
      expect(doc.disposed, isTrue);
      expect(retired.document, isNull);
      final direct = Document(1);
      ref.gate.complete(direct);
      await ref.resolveListenable().load();
      expect(ref.resolveListenable().document, same(direct));
      expect(direct.disposed, isFalse);
      ref.resolveListenable().addListener(listener);
      ref.resolveListenable().removeListener(listener);
    },
  );
  testWidgets(
    'page retry keeps the native document, reading position and text selection',
    (t) async {
      await reader_fixture.desktop(t);
      await t.pumpWidget(reader_fixture.host(reader_fixture.reader(page: 2)));
      await reader_fixture.waitNative(t, () => reader_fixture.ready(t));
      final widget = reader_fixture.viewer(t),
          controller = reader_fixture.viewer(t).controller!;
      final document = controller.document;
      await t.runAsync(() => controller.textSelectionDelegate.selectAllText());
      final selected = await t.runAsync(
        () => controller.textSelectionDelegate.getSelectedText(),
      );
      expect(selected, contains('Orbit research'));
      final page = controller.pageNumber, zoom = controller.currentZoom;
      widget.params.onPageRenderCompleted!(
        page!,
        StateError('Synthetic page failure'),
      );
      await t.pump();
      expect(
        find.byKey(const ValueKey('pdf-retry-page-render')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('pdf-retry-page-render')));
      await t.pump();
      await settle(
        t,
        () => find
            .byKey(const ValueKey('pdf-retry-page-render'))
            .evaluate()
            .isEmpty,
      );
      expect(controller.document, same(document));
      expect(controller.pageNumber, page);
      expect(controller.currentZoom, zoom);
      expect(
        await t.runAsync(
          () => controller.textSelectionDelegate.getSelectedText(),
        ),
        selected,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
    skip: !native,
  );

  for (final budget in [100 * 1024 * 1024, 1024]) {
    testWidgets('scroll back restores page images with memory budget $budget', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      await t.binding.setSurfaceSize(const Size(520, 700));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final doc = Document(12), controller = PdfViewerController();
      final completed = <int>{};
      await t.pumpWidget(
        MaterialApp(
          home: PdfViewer(
            PdfDocumentRefDirect(doc),
            controller: controller,
            params: PdfViewerParams(
              maxImageBytesCachedOnMemory: budget,
              getPageRenderingScale: (_, _, _, _) => 2,
              onPageRenderCompleted: (page, error) {
                if (error == null) completed.add(page);
              },
            ),
          ),
        ),
      );
      await settle(t, () => controller.isReady && completed.contains(1));
      final first = (doc.pages.first as Page).renders;
      for (final number in [6, 12, 2, 10, 1]) {
        await controller.goToPage(pageNumber: number, duration: Duration.zero);
        await settle(t, () => completed.contains(number));
        await t.pump(const Duration(milliseconds: 100));
      }
      await settle(t, () => controller.pageNumber == 1);
      // Successful previews can stay warm under budget, and evicted pages re-render.
      if (budget > 1024) {
        expect((doc.pages.first as Page).renders, first);
      } else {
        await settle(t, () => (doc.pages.first as Page).renders > first);
        expect((doc.pages.first as Page).renders, greaterThan(first));
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    }, skip: !native);
  }

  for (final placeholder in [true, false]) {
    testWidgets(
      'page replacement retires ${placeholder ? 'unloaded placeholders' : 'in-flight decodes'}',
      (t) async {
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetDevicePixelRatio);
        await t.binding.setSurfaceSize(const Size(520, 700));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final doc = Document(1), controller = PdfViewerController();
        final old = doc.pages.first as Page;
        old.loaded = !placeholder;
        if (!placeholder) old.gate = Completer<void>();
        var completed = 0;
        await t.pumpWidget(
          MaterialApp(
            home: PdfViewer(
              PdfDocumentRefDirect(doc),
              controller: controller,
              params: PdfViewerParams(
                getPageRenderingScale: (_, _, _, _) => 2,
                onPageRenderCompleted: (p, e) {
                  if (e == null) completed++;
                },
              ),
            ),
          ),
        );
        await settle(t, () => controller.isReady);
        if (placeholder) {
          await t.pump(const Duration(milliseconds: 100));
          expect(old.renders, 0);
        } else {
          await settle(t, () => old.renders == 1);
        }
        final next = Page(doc, 1);
        doc.pages = [next];
        doc.updates.add(
          PdfDocumentPageStatusChangedEvent(
            doc,
            changes: {1: PdfPageStatusChange.modified(page: next)},
          ),
        );
        await t.pump();
        old.gate?.complete();
        await settle(t, () => completed == 1);
        expect(next.renders, 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      },
      skip: !native,
    );
  }
  testWidgets('current-page previews start before speculative neighbours', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetDevicePixelRatio);
    await t.binding.setSurfaceSize(const Size(520, 700));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final doc = Document(20), controller = PdfViewerController();
    await t.pumpWidget(
      MaterialApp(
        home: PdfViewer(
          PdfDocumentRefDirect(doc),
          controller: controller,
          initialPageNumber: 10,
          params: PdfViewerParams(getPageRenderingScale: (_, _, _, _) => 2),
        ),
      ),
    );
    await settle(t, () => doc.started.isNotEmpty);
    expect(doc.started.first, 10);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }, skip: !native);

  testWidgets(
    'high-DPI repeated paints coalesce pending full and partial renders',
    (t) async {
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.resetDevicePixelRatio);
      await t.binding.setSurfaceSize(const Size(520, 700));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final doc = Document(1), controller = PdfViewerController();
      final page = doc.pages.first as Page;
      page.gate = Completer<void>();
      await t.pumpWidget(
        MaterialApp(
          home: PdfViewer(
            PdfDocumentRefDirect(doc),
            controller: controller,
            params: PdfViewerParams(getPageRenderingScale: (_, _, _, _) => 2),
          ),
        ),
      );
      await settle(t, () => page.renders == 1);
      for (var i = 0; i < 30; i++) {
        controller.invalidate();
        await t.pump(const Duration(milliseconds: 10));
      }
      expect(page.renders, 1);
      page.gate!.complete();
      await settle(t, () => page.renders == 2);
      for (var i = 0; i < 30; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        controller.invalidate();
        await t.pump(const Duration(milliseconds: 10));
      }
      expect(page.renders, 2);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
    skip: !native,
  );

  testWidgets(
    'preview work coalesces and terminal failures retry without reopening',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      await t.binding.setSurfaceSize(const Size(520, 700));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final doc = Document(1), controller = PdfViewerController();
      final page = doc.pages.first as Page;
      page.gate = Completer<void>();
      Object? error;
      var succeeded = false;
      await t.pumpWidget(
        MaterialApp(
          home: PdfViewer(
            PdfDocumentRefDirect(doc),
            controller: controller,
            params: PdfViewerParams(
              getPageRenderingScale: (_, _, _, _) => 2,
              onPageRenderCompleted: (p, e) {
                error = e;
                if (e == null) succeeded = true;
              },
            ),
          ),
        ),
      );
      await settle(t, () => page.renders == 1);
      for (var i = 0; i < 30; i++) {
        controller.invalidate();
        await t.pump(const Duration(milliseconds: 10));
      }
      expect(page.renders, 1);
      page.failures = 3;
      page.gate!.complete();
      await settle(t, () => error != null);
      expect(page.renders, 3);
      expect(succeeded, isFalse);
      final zoom = controller.currentZoom;
      controller.retryPageRendering(1);
      await settle(t, () => succeeded);
      expect(page.renders, 4);
      expect(controller.currentZoom, zoom);
      expect(controller.document, same(doc));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
    skip: !native,
  );
}
