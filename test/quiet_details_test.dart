import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_scroll_anchor.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/equal_spacing.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/features/canvas/canvas_images.dart';
import 'package:orbit_note/features/notes/rich/rich_table_editor.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'pdf_markup_interactions_test.dart' as markup;
import 'pdf_reader_reliability_test.dart' as pdf;
import 'support/pdf_fixture.dart';
import 'canvas_transfer_quality_test.dart' as canvas;
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/domain/orbit_search.dart';
import 'search_workspace_test.dart' as search;

class _RefreshedSearch extends search.SearchController {
  int revision = 0;
  final changes = StreamController<void>.broadcast();
  @override
  int get pdfIndexRevision => revision;
  @override
  Stream<void> get pdfIndexChanges => changes.stream;
  @override
  bool isCurrentSearchResult(OrbitSearchResult result) =>
      result.object.id != 'chosen' ||
      result.object.updatedAt.day == (revision == 0 ? 1 : 2);
}

void main() {
  testWidgets(
    'search refresh retains a renamed result when offsets and ordering change',
    (t) async {
      final c = _RefreshedSearch();
      c.found = [search.result('chosen')];
      await search.mount(t, c);
      await search.search(t, 'research');
      final next = search.result('chosen', title: 'Renamed result', day: 2);
      final other = search.result('other');
      c.found = [
        OrbitSearchResult(
          object: other.object,
          location: other.location,
          matchKind: other.matchKind,
          matchedText: other.matchedText,
          score: 100,
        ),
        OrbitSearchResult(
          object: next.object,
          location: next.location,
          matchKind: next.matchKind,
          matchedText: next.matchedText,
          sourceOffset: 200,
          score: 60,
        ),
      ];
      c.revision++;
      c.changes.add(null);
      await t.pump();
      await t.pump(const Duration(milliseconds: 260));
      await t.pump(const Duration(milliseconds: 200));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(c.opened?.object.id, 'chosen');
      await t.pumpWidget(const SizedBox());
      await c.changes.close();
    },
  );

  testWidgets(
    'inactive Canvas activates without drawing or dragging; wheel input still works',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1200, 850));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final active = ValueNotifier(false);
      var writes = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: active,
              builder: (_, enabled, _) => CanvasEditor(
                canvasId: 'activation',
                data: canvas.board([canvas.rectangle('shape')]),
                objects: const [],
                interactionActive: enabled,
                onActivate: () => active.value = true,
                onOpenObject: (_) {},
                onChanged: (_) => writes++,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      var pointer = await t.startGesture(
        canvas.at(t, const CanvasPoint(90, 90)),
      );
      await pointer.moveBy(const Offset(70, 30));
      await pointer.up();
      await t.pumpAndSettle();
      expect(active.value, true);
      expect(writes, 0);
      expect(canvas.painter(t).scene['shape']!.x, 40);
      pointer = await t.startGesture(canvas.at(t, const CanvasPoint(90, 90)));
      await pointer.moveBy(const Offset(70, 30));
      await pointer.up();
      await t.pumpAndSettle();
      expect(writes, 1);
      active.value = false;
      await t.pump();
      final previous = canvas.painter(t).camera.y;
      await t.sendEventToBinding(
        PointerScrollEvent(
          position: t.getCenter(canvas.surface),
          scrollDelta: const Offset(0, 50),
        ),
      );
      await t.pumpAndSettle();
      expect(active.value, true);
      expect(canvas.painter(t).camera.y, isNot(previous));
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpWidget(const SizedBox());
      active.dispose();
    },
  );
  test(
    'equal-spacing guides choose aligned immediate neighbors without distant false matches',
    () {
      final equal = equalCanvasSpacing(
        const CanvasBounds(201, 0, 100, 80),
        const [
          CanvasBounds(0, 0, 100, 80),
          CanvasBounds(400, 0, 100, 80),
          CanvasBounds(300, 900, 100, 80),
        ],
        vertical: false,
        tolerance: 6,
      )!;
      expect(equal.delta, -1);
      expect(equal.gap, 100);
      expect(
        equalCanvasSpacing(
          const CanvasBounds(250, 0, 100, 80),
          const [CanvasBounds(0, 0, 100, 80), CanvasBounds(400, 0, 100, 80)],
          vertical: false,
          tolerance: 6,
        ),
        isNull,
      );
    },
  );

  test(
    'dense PDF hits include nearby thin marks and deduplicate multi-region overlaps',
    () {
      final marks = [
        for (var i = 0; i < 600; i++) markup.mark('m-$i', 1, count: 2),
      ];
      final index = PdfAnnotationIndex(marks, 'paper', 'v1');
      expect(index.hitTests(1, .11, .21).length, 600);
      expect(index.hitTests(1, .11, .224, toleranceY: .006).length, 600);
      expect(index.hitTests(1, .11, .25, toleranceY: .006), isEmpty);
      expect(index.hitTest(1, .11, .21)!.object.id, 'm-599');
      final watch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        index.hitTests(1, .11, .224, toleranceY: .006);
      }
      // ignore: avoid_print
      print(
        '600 overlapping PDF marks, 100 hit queries: ${watch.elapsedMilliseconds} ms (test CPU)',
      );
    },
  );

  testWidgets(
    'growing content above the viewport retains its visible paragraph',
    (t) async {
      final scroll = ScrollController();
      final anchor = OrbitScrollAnchorCoordinator(scroll);
      final height = ValueNotifier(100.0), target = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: height,
                    builder: (_, h, _) => OrbitScrollAnchor(
                      coordinator: anchor,
                      child: SizedBox(height: h),
                    ),
                  ),
                  const SizedBox(height: 400),
                  Text('Reading here', key: target),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      scroll.jumpTo(450);
      await t.pump();
      final before = t.getTopLeft(find.byKey(target));
      height.value = 240;
      await t.pump();
      await t.pump();
      expect(t.getTopLeft(find.byKey(target)).dy, closeTo(before.dy, .5));
      anchor.adjust(50);
      scroll.jumpTo(700);
      await t.pump();
      expect(scroll.offset, 700);
      anchor.reset();
      await t.pumpWidget(const SizedBox());
      scroll.dispose();
      height.dispose();
      expect(t.takeException(), isNull);
    },
  );

  test(
    'closed tab group survives restart with order, views and selection; deleted objects are skipped',
    () async {
      final store = MemoryStore();
      ProviderContainer setup() => ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(
            WorkspaceRepository(store: store, index: MemoryObjectIndex()),
          ),
        ],
      );
      var container = setup();
      var c = container.read(workspaceProvider.notifier);
      await c.initialize();
      final notes = [
        for (var i = 0; i < 4; i++)
          await c.repository.create(typeId: 'orbit.note', title: 'Tab $i'),
      ];
      c.mergeRepositoryObjects();
      for (final n in notes) {
        c.openObject(n.id);
      }
      c.session.tabs = notes.map((n) => n.id).toList();
      c.session.positions['primary:${notes[1].id}'] = 321;
      c.session.noteViews['primary:${notes[1].id}'] = {
        'mode': 'rich',
        'rich': {'base': 3, 'extent': 9},
      };
      c.closeTabsToTheRight(notes.first.id);
      expect(c.closedTabGroups.length, 1);
      await c.saveSession();
      container.dispose();
      container = setup();
      c = container.read(workspaceProvider.notifier);
      await c.initialize();
      expect(c.reopenClosedTabGroup(), true);
      expect(c.session.tabs, notes.map((n) => n.id));
      expect(c.session.positions['primary:${notes[1].id}'], 321);
      expect(c.session.noteViews['primary:${notes[1].id}']!['rich'], {
        'base': 3,
        'extent': 9,
      });
      c.closeOtherTabs(notes.first.id);
      await c.trash(notes[2].id);
      expect(c.reopenClosedTabGroup(), true);
      expect(c.session.tabs, isNot(contains(notes[2].id)));
      c.session = SessionState.fromJson({
        ...c.session.toJson(),
        'closedTabGroups': {'version': 99, 'future': true},
      });
      c.closeOtherTabs(notes.first.id);
      expect(c.session.extra['closedTabGroups'], {
        'version': 99,
        'future': true,
      });
      container.dispose();
    },
  );

  testWidgets(
    'table copies multiline cells as TSV plus HTML, and explicit Markdown keeps headers',
    (t) async {
      var plain = '', html = '';
      final messenger = t.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('orbit_note/clipboard'),
        (call) async {
          plain = (call.arguments as Map)['plainText'] as String;
          html = (call.arguments as Map)['html'] as String;
          return true;
        },
      );
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          plain = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel('orbit_note/clipboard'),
          null,
        );
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final key = GlobalKey<RichTableEditorState>();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTableEditor(
              key: key,
              source: '| Name |\n| --- |\n| first<br>second |\n',
              onChanged: (_) {},
              onUndo: () {},
              onRedo: () {},
            ),
          ),
        ),
      );
      key.currentState!.row = 1;
      await key.currentState!.copySelection();
      expect(plain, '"first\nsecond"');
      expect(html, contains('first<br>second'));
      await key.currentState!.copySelectionAsMarkdown();
      expect(plain, '| Name |\n| --- |\n| first<br>second |');
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed image cache is retryable without changing the document', (
    t,
  ) async {
    var attempts = 0;
    final cache = CanvasImageCache(
      loader: (_) async {
        attempts++;
        return null;
      },
      onChanged: () {},
    );
    cache.updateVisible(['Attachments/missing.png']);
    await t.pump();
    expect(cache.failedReferences, contains('Attachments/missing.png'));
    cache.invalidate('Attachments/missing.png');
    await t.pump();
    expect(attempts, 2);
    cache.dispose();
  });

  testWidgets(
    'touch targets select a thin Canvas connector without enlarging its visual',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1200, 850));
      addTearDown(() => t.binding.setSurfaceSize(null));
      var writes = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'touch',
              data: canvas.board([
                {
                  'id': 'thin',
                  'type': 'line',
                  'x': 40.0,
                  'y': 100.0,
                  'width': 200.0,
                  'height': 0.0,
                  'strokeWidth': 1.0,
                },
              ]),
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (_) => writes++,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final point = canvas.at(t, const CanvasPoint(120, 115));
      final pointer = await t.startGesture(
        point,
        kind: PointerDeviceKind.touch,
      );
      await pointer.up();
      await t.pump();
      expect(canvas.painter(t).selection, contains('thin'));
      expect(writes, 0);
      expect(canvas.painter(t).scene['thin']!.data['strokeWidth'], 1.0);
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'PDF options persist through callback and overlapping marks open a chooser',
    (t) async {
      await pdf.desktop(t);
      await t.runAsync(() async {
        expect(await initPdfTesting(), true);
      });
      Map<String, dynamic> saved = {};
      Widget reader({Map<String, dynamic> options = const {}}) =>
          markup.pdfHost(
            OrbitPdfReader(
              objectId: 'paper',
              title: 'Paper',
              checksum: 'v1',
              loadBytes: () async => researchPdf(),
              onOpenOriginal: () {},
              onOpenExternal: (_) {},
              onReadingState: (_, _) {},
              onQuote: (_, _) async {},
              onBookmarks: (_) {},
              initialViewOptions: options,
              onViewOptions: (v) => saved = v,
              annotations: [markup.mark('a', 1), markup.mark('b', 1)],
            ),
          );
      await t.pumpWidget(
        reader(options: {'paperTone': 'future-tone', 'futureOption': true}),
      );
      await pdf.waitNative(t, () => pdf.ready(t));
      await t.tap(find.byTooltip('Hide review markup'));
      await t.pump();
      expect(saved['showMarkup'], false);
      expect(saved.containsKey('paperTone'), false);
      expect(saved.containsKey('futureOption'), false);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(reader(options: saved));
      await pdf.waitNative(t, () => pdf.ready(t));
      expect(find.byTooltip('Show review markup'), findsOneWidget);
      await t.tap(find.byTooltip('Show review markup'));
      await t.pump();
      final v = pdf.viewer(t),
          layout = pdf.viewer(t).controller!.layout.pageLayouts.first;
      final position = Offset(
        layout.left + layout.width * .11,
        layout.top + layout.height * .21,
      );
      final global = v.controller!.documentToGlobal(position)!;
      await t.tapAt(global);
      await t.pumpAndSettle();
      expect(find.text('Choose a marking'), findsOneWidget);
      expect(find.text('Evidence a'), findsOneWidget);
      expect(find.text('Evidence b'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
    },
  );
}
