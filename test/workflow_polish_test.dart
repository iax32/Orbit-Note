import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/note_statistics.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/domain/wiki_links.dart';
import 'package:orbit_note/domain/publication_layout.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/notes/paste_feedback.dart';
import 'package:orbit_note/features/notes/orbit_internal_link.dart';
import 'package:orbit_note/features/workspace/note_folder_explorer.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'search_workspace_test.dart' as fixtures;
import 'support/capture_ui.dart';
import 'folder_color_identity_test.dart' as folders;

class _Search extends fixtures.SearchController {
  _Search() {
    repository = WorkspaceRepository(
      store: MemoryStore(),
      index: MemoryObjectIndex(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('explicit PDF cleanup preserves code, paragraphs, lists and equations', () {
    const text =
        'Long line\r\ncontinues here\r\n\r\n- Item\r\n- Other\r\n```cpp\r\na\r\nb\r\n```\r\n\$\$\r\nx\r\ny\r\n\$\$';
    expect(
      cleanPdfParagraphs(text),
      'Long line continues here\n\n- Item\n- Other\n```cpp\na\nb\n```\n\$\$\nx\ny\n\$\$',
    );
    final long = List.filled(20000, 'Sentence on a line').join('\n');
    final watch = Stopwatch()..start();
    expect(cleanPdfParagraphs(long).endsWith('Sentence on a line'), true);
    // ignore: avoid_print
    print('PDF cleanup, 20k lines: ${watch.elapsedMilliseconds} ms');
  });

  test(
    'navigation retains independent visits and invalidates cross-Vault history',
    () async {
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(
            WorkspaceRepository(
              store: MemoryStore(),
              index: MemoryObjectIndex(),
            ),
          ),
        ],
      );
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();
      c.pausePdfIndex(true);
      c.session.autoSnapshotOnClose = false;
      c.session.autoSaveInterval = 10000;
      final a = (await c.create(
        'orbit.note',
        title: 'A',
        body: 'Alpha\n\nBeta',
        open: false,
      ))!;
      final b = (await c.create('orbit.note', title: 'B', open: false))!;
      // Simulate the active tab restored from saved session, without a runtime visit.
      c.session.activeId = a.id;
      c.session.positions = {'primary:${a.id}': 321};
      c.session.noteViews = {
        'primary:${a.id}': {'mode': 'source', 'base': 2, 'extent': 5},
      };
      c.openObject(b.id);
      c.session.positions = {...c.session.positions, 'primary:${a.id}': 999};
      c.navigateBack();
      expect(c.session.activeId, a.id);
      expect(c.session.positions['primary:${a.id}'], 321);
      expect(c.session.noteViews['primary:${a.id}']?['extent'], 5);
      expect(c.locationRequests.containsKey(a.id), false);
      c.navigateForward();
      expect(c.session.activeId, b.id);
      c.openObject(a.id);
      c.requestLocation(
        ObjectReference(a.id, anchorType: 'heading', anchorId: 'Beta'),
      );
      c.openObject(a.id);
      expect(c.canNavigateBack, true);
      c.navigateBack();
      expect(c.session.activeId, a.id);
      expect(c.locationRequests[a.id], null);
      final board = (await c.create(
        'orbit.canvas',
        title: 'Board',
        open: false,
      ))!;
      c.openObject(board.id);
      c.requestLocation(
        ObjectReference(board.id, anchorType: 'element', anchorId: 'shape'),
      );
      c.openObject(board.id);
      c.session.cameras = {
        ...c.session.cameras,
        board.id: {'x': 500.0, 'y': 800.0, 'zoom': 2.0},
      };
      c.navigateBack();
      expect(c.session.cameras[board.id], {'x': 0.0, 'y': 0.0, 'zoom': 1.0});
      await c.closeWorkspace();
      expect(c.canNavigateBack, false);
      expect(c.backHistory, isEmpty);
      c.cancelAllTimers();
      container.dispose();
    },
  );

  test(
    'statistics refresh for edits and publication preserves theme/unknown fields',
    () {
      final a = fixtures.result('a').object;
      expect(noteStatistics(a), startsWith('4 words'));
      final b = a.copyWith(body: List.filled(100000, 'word').join(' '));
      final watch = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        expect(noteStatistics(b), startsWith('100000 words'));
      }
      // ignore: avoid_print
      print(
        '1000 status updates on 100k-word note: ${watch.elapsedMilliseconds} ms',
      );
      final source = PublicationSettings.update('Body', {
        'useEditorTheme': false,
        'future': 'retained',
      }, {});
      final next = PublicationSettings.update(source, {'fontSize': 12}, {});
      expect(
        PublicationSettings.parse(next)!.data['style'],
        containsPair('useEditorTheme', false),
      );
      expect(
        PublicationSettings.parse(next)!.data['style'],
        containsPair('future', 'retained'),
      );
    },
  );

  testWidgets('PDF paste choice cancels safely and restores original focus', (
    t,
  ) async {
    const pdf = PdfQuoteDragData(
      objectId: 'pdf',
      title: 'Lecture',
      page: 4,
      text: 'First\nsecond',
    );
    rememberPdfCopy(pdf);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') return {'text': pdf.text};
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    String? result;
    var cancelled = false;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    late BuildContext editorContext;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              editorContext = context;
              return TextField(focusNode: focus);
            },
          ),
        ),
      ),
    );
    focus.requestFocus();
    await t.pump();
    final pending = readEditorClipboard(editorContext, preferHtml: false)
        .then((v) => result = v)
        .onError<EditorPasteCancelled>((_, _) {
          cancelled = true;
          return null;
        });
    await t.pumpAndSettle();
    expect(find.text('Paste PDF text'), findsOneWidget);
    await t.tap(find.text('Cleaned paragraphs'));
    await t.pumpAndSettle();
    await pending;
    expect(result, 'First second');
    expect(focus.hasFocus, true);
    final cancel = readEditorClipboard(editorContext, preferHtml: false)
        .onError<EditorPasteCancelled>((_, _) {
          cancelled = true;
          return null;
        });
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    await cancel;
    expect(cancelled, true);
    expect(focus.hasFocus, true);
  });

  testWidgets('feedback actions cannot undo a later edit', (t) async {
    var current = true, undos = 0, plains = 0;
    late BuildContext context;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const Text('Editor');
            },
          ),
        ),
      ),
    );
    showPasteFeedback(
      context,
      '![a](x)\n![b](y)',
      isCurrent: () => current,
      undo: () => undos++,
      pastePlain: () => plains++,
    );
    await t.pumpAndSettle();
    expect(find.text('Pasted 2 images'), findsOneWidget);
    current = false;
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(undos, 0);
    current = true;
    showPasteFeedback(
      context,
      'text',
      isCurrent: () => current,
      undo: () => undos++,
      pastePlain: () => plains++,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Paste as plain text'));
    await t.pumpAndSettle();
    expect(plains, 1);
  });

  testWidgets(
    'folder drop Undo restores notes and metadata-backed Canvas owners',
    (t) async {
      late ProviderContainer container;
      late WorkspaceController c;
      final ids = <String>[];
      await t.runAsync(() async {
        container = ProviderContainer(
          overrides: [
            repositoryProvider.overrideWithValue(
              WorkspaceRepository(
                store: folders.TestFolderStore(),
                index: MemoryObjectIndex(),
              ),
            ),
          ],
        );
        c = container.read(workspaceProvider.notifier);
        await c.initialize();
        c.pausePdfIndex(true);
        c.session.autoSnapshotOnClose = false;
        c.session.autoSaveInterval = 10000;
        await c.repository.createFolder('Notes/A');
        await c.repository.createFolder('Notes/B');
        for (final type in ['orbit.note', 'orbit.canvas']) {
          ids.add(
            (await c.create(
              type,
              title: type,
              properties: {'folder': 'Notes/A'},
              open: false,
            ))!.id,
          );
        }
      });
      addTearDown(() {
        c.cancelAllTimers();
        container.dispose();
      });
      Future<void> waitFor(String id, String folder) async {
        await t.runAsync(() async {
          for (
            var i = 0;
            i < 100 && (c.loading || c.repository.objectFolder(id) != folder);
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });
        await t.pumpAndSettle();
        expect(c.error, null);
        expect(c.repository.objectFolder(id), folder);
      }

      for (final id in ids) {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteFolderExplorer(
                controller: c,
                notes: c.activeObjects
                    .where((o) => o.typeId == 'orbit.note')
                    .toList(),
                visibleObjects: c.activeObjects,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final drop = t.widget<DragTarget<({String path, String? noteId})>>(
          find
              .ancestor(
                of: find.byTooltip('Move to Notes/B'),
                matching: find.byWidgetPredicate(
                  (w) => w is DragTarget<({String path, String? noteId})>,
                ),
              )
              .first,
        );
        final details = DragTargetDetails<({String path, String? noteId})>(
          data: (path: c.repository.objectPath(id)!, noteId: id),
          offset: Offset.zero,
        );
        expect(drop.onWillAcceptWithDetails!(details), true);
        await t.runAsync(() async {
          drop.onAcceptWithDetails!(details);
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await waitFor(id, 'Notes/B');
        await t.runAsync(() => t.tap(find.text('Undo')));
        await waitFor(id, 'Notes/A');
        await t.pump(const Duration(milliseconds: 500));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      // Drain native-zone callbacks before the messenger's animation is disposed.
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), null);
    },
  );

  testWidgets('search returns with query and results after leaving the view', (
    t,
  ) async {
    final c = _Search()
      ..found = List.generate(70, (i) => fixtures.result('Note $i'));
    await fixtures.mount(t, c);
    await fixtures.search(t, 'research');
    expect(find.textContaining('Note 0'), findsWidgets);
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    await t.pump();
    await fixtures.mount(t, c);
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'research',
    );
    expect(find.textContaining('Note 0'), findsWidgets);
    expect(t.takeException(), null);
  });

  testWidgets(
    'missing canonical reference never previews a different same-title note',
    (t) async {
      final other = fixtures.result('other', title: 'Shared title').object;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrbitPeekCard(
              href: 'orbit-object:missing',
              label: 'Shared title',
              allObjects: [other],
              linkTargets: const [
                NoteLinkTarget(id: 'other', title: 'Shared title'),
              ],
              onOpen: (_) {},
              onOpenInNewTab: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );
      expect(find.textContaining('Source unavailable.'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.textContaining('A useful research passage'), findsNothing);
    },
  );

  testWidgets('board tools survive remount without editing the scene', (
    t,
  ) async {
    t.view.physicalSize = const Size(1200, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    Map<String, dynamic>? camera = {
      'x': 0.0,
      'y': 0.0,
      'zoom': 1.0,
      'drawingTools': {
        'tool': 'pen',
        'penStyle': 'pencil',
        'penWidth': 2.0,
        'eraserRadius': 24.0,
        'color': 0xffffffff,
      },
    };
    var writes = 0;
    final data = {'schemaVersion': 1, 'elements': <Map<String, dynamic>>[]};
    Future<void> mount() => t.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: CanvasEditor(
            canvasId: 'board',
            data: data,
            camera: camera,
            objects: const [],
            onOpenObject: (_) {},
            onChanged: (_) => writes++,
            onCameraChanged: (v) => camera = v,
          ),
        ),
      ),
    );
    await mount();
    await t.pumpAndSettle();
    expect(find.byTooltip('Pen style (pencil)'), findsOneWidget);
    await t.tap(find.byTooltip('Draw and erase'));
    await t.pumpAndSettle();
    await t.tap(find.text('Erase strokes (E)'));
    await t.pumpAndSettle();
    expect((camera!['drawingTools'] as Map)['tool'], 'eraser');
    await t.pumpWidget(const SizedBox());
    camera = SessionState.fromJson(
      SessionState(cameras: {'board': camera!}).toJson(),
    ).cameras['board'];
    await mount();
    await t.pumpAndSettle();
    expect(find.byTooltip('Eraser radius (24px)'), findsOneWidget);
    expect(writes, 0);
    expect(
      t
          .widget<CustomPaint>(
            find
                .byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
                )
                .first,
          )
          .painter,
      isA<OrbitCanvasPainter>(),
    );
  });

  testWidgets(
    'hover traces one connection without mutating or rerouting the diagram',
    (t) async {
      t.view.physicalSize = const Size(1200, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var writes = 0;
      final elements = [
        {
          'id': 'a',
          'type': 'rectangle',
          'x': 20.0,
          'y': 30.0,
          'width': 100.0,
          'height': 80.0,
          'text': 'Source',
        },
        {
          'id': 'b',
          'type': 'rectangle',
          'x': 360.0,
          'y': 30.0,
          'width': 100.0,
          'height': 80.0,
          'text': 'Target',
        },
        {
          'id': 'edge',
          'type': 'connector',
          'startId': 'a',
          'endId': 'b',
          'startAnchor': 'right',
          'endAnchor': 'left',
          'routing': 'straight',
          'x': 120.0,
          'y': 70.0,
          'width': 240.0,
          'height': 1.0,
          'startX': 120.0,
          'startY': 70.0,
          'endX': 360.0,
          'endY': 70.0,
          'startMultiplicity': '1',
          'endMultiplicity': '0..*',
        },
      ];
      await prepareCapture(t);
      await t.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'trace',
              data: {'schemaVersion': 1, 'elements': elements},
              objects: const [],
              camera: const {'x': 0.0, 'y': 0.0, 'zoom': 1.0},
              onOpenObject: (_) {},
              onChanged: (_) => writes++,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final surface = find
          .byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
          )
          .first;
      final origin = t.getTopLeft(surface);
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: origin + const Offset(220, 70));
      await mouse.moveTo(origin + const Offset(221, 70));
      await t.pump();
      final painter =
          t.widget<CustomPaint>(surface).painter as OrbitCanvasPainter;
      expect(painter.tracedConnectorId, 'edge');
      final revision = painter.scene.revision;
      final watch = Stopwatch()..start();
      for (var i = 0; i < 30; i++) {
        await mouse.moveTo(origin + Offset(200 + i.toDouble(), 70));
        await t.pump();
      }
      // ignore: avoid_print
      print('30 tracing frames: ${watch.elapsedMilliseconds} ms');
      expect(painter.scene.revision, revision);
      expect(writes, 0);
      await captureUi(t, 'workflow-connection-trace');
      await mouse.removePointer();
      await t.pumpAndSettle();
      expect(
        (t.widget<CustomPaint>(surface).painter as OrbitCanvasPainter)
            .tracedConnectorId,
        null,
      );
    },
  );

  testWidgets('long-press reference preview fits narrow enlarged layouts', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final note = fixtures.result('a', title: 'Reference').object;
    await prepareCapture(t);
    await t.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('preview-capture'),
        child: MaterialApp(
          theme: orbitDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: OrbitInternalLink(
                text: 'Preview',
                href: 'orbit-object:a',
                onOpen: (_) {},
                allObjects: [note],
              ),
            ),
          ),
        ),
      ),
    );
    await t.longPress(find.text('Preview'));
    await t.pumpAndSettle();
    expect(find.text('Live source'), findsOneWidget);
    expect(t.takeException(), null);
    await captureUi(
      t,
      'workflow-reference-preview',
      target: find.byKey(const ValueKey('preview-capture')),
    );
  });
}
