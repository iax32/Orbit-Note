import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/canvas_svg.dart';
import 'package:orbit_note/canvas/diagram_reference.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/uml.dart';
import 'package:orbit_note/domain/note_composition.dart';
import 'package:orbit_note/domain/object_connections.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/canvas/diagram_note_dialog.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_object_surface.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/memory_store.dart';

Map<String, dynamic> boardData() {
  var id = 0;
  return {
    'schemaVersion': 1,
    'future': {'keep': true},
    'elements': umlExample(
      () => 'item-${id++}',
      const CanvasPoint(40, 40),
    ).map((e) => e.data).toList(),
  };
}

UniversalObject board({Map<String, dynamic>? data}) => UniversalObject(
  id: 'board',
  workspaceId: 'vault',
  typeId: 'orbit.canvas',
  title: 'Domain model',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  data: data ?? boardData(),
);

Future<(ProviderContainer, WorkspaceController, MemoryStore)> memory() async {
  final store = MemoryStore();
  final repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
  final container = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(repo)],
  );
  container.read(workspaceProvider);
  final c = container.read(workspaceProvider.notifier);
  for (var i = 0; c.loading && i < 200; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  return (container, c, store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'precise diagram reference round-trips arbitrary IDs and stays an ordinary Markdown block',
    () {
      final ids = ['node,(one)', 'ä "two"', 'emoji-🛰'];
      final markdown = diagramMarkdown(
        'board',
        'A [model]\n',
        ids,
        eol: '\r\n',
      );
      expect(markdown, isNot(contains('![')));
      expect(markdown, isNot(contains('```')));
      final block = NoteObjectBlock.parse(markdown)!;
      expect(diagramElementIds(block.reference), ids);
      expect(block.reference, isA<ObjectReference>());
      expect(block.label, 'A  model');
      expect(MarkdownDocument.parse(markdown).source, markdown);
      expect(MarkdownDocument.parse(markdown).blocks, hasLength(1));
      expect(
        diagramElementIds(
          const ObjectReference(
            'board',
            anchorType: 'elements',
            anchorId: 'not json',
          ),
        ),
        isNull,
      );
      expect(() => diagramReference('board', []), throwsFormatException);
      expect(
        diagramElementIds(
          const ObjectReference(
            'board',
            anchorType: 'elements',
            anchorId: '["a","a"]',
          ),
        ),
        isNull,
      );
    },
  );

  test(
    'selection includes internal relationships and follows changes without unrelated content',
    () {
      final source = CanvasScene.fromJson(boardData());
      expect(umlExportSelection(source, ['item-4']).toSet(), {
        'item-0',
        'item-1',
      });
      final subset = ResolvedCanvasDiagram(source, ['item-0', 'item-1']);
      expect(subset.scene.elements.map((e) => e.id).toSet(), {
        'item-0',
        'item-1',
        'item-4',
      });
      source.put(
        source['item-0']!
            .copy({'text': 'Renamed'})
            .translated(const CanvasPoint(120, 80)),
      );
      source.put(
        CanvasElement({
          'id': 'new-edge',
          'type': 'connector',
          'startId': 'item-0',
          'endId': 'item-1',
          ...UmlRelationship.dependency.style,
        }),
      );
      final changed = ResolvedCanvasDiagram(source, ['item-0', 'item-1']);
      expect(changed.scene['item-0']!.text, 'Renamed');
      expect(changed.scene['new-edge'], isNotNull);
      expect(changed.scene['item-2'], isNull);
      source.remove('item-1');
      final missing = ResolvedCanvasDiagram(source, ['item-0', 'item-1']);
      expect(missing.unavailable, 1);
      expect(missing.scene.elements.map((e) => e.id), ['item-0']);
    },
  );

  test(
    'Orbit class palette is theme-aware and SVG has no fixed navy treatment',
    () {
      final scene = CanvasScene.fromJson(boardData());
      for (final bg in [0xff14131a, 0xfff6f4ed, 0xff173631]) {
        final palette = UmlPalette(bg);
        final contrast = OrbitContrast.ratio(
          Color(palette.text),
          Color(palette.body),
        );
        expect(contrast, greaterThan(4.5));
        final svg = canvasToSvg(scene, backgroundColor: bg);
        expect(svg, contains('rx="8"'));
        expect(svg, isNot(contains('#1c293d')));
        expect(svg, contains('name: String'));
      }
    },
  );

  test(
    'controller exports new notes and safely appends to existing notes',
    () async {
      final (container, c, _) = await memory();
      addTearDown(() {
        c.cancelAllTimers();
        container.dispose();
      });
      final source = (await c.create(
        'orbit.canvas',
        title: 'Source',
        data: boardData(),
        properties: {'folder': 'University', 'future': 42},
      ))!;
      final created = await c.exportCanvasDiagramToNote(source, [
        'item-0',
        'item-1',
      ], title: 'Patient model');
      expect(created, isNotNull);
      expect(created!.properties['folder'], 'University');
      expect(
        diagramElementIds(NoteObjectBlock.parse(created.body)!.reference),
        ['item-0', 'item-1'],
      );
      final before = (await c.create(
        'orbit.note',
        body: 'Authored\r\ntext',
        properties: {
          'future': {'keep': true},
        },
      ))!;
      final added = await c.exportCanvasDiagramToNote(source, [
        'item-0',
      ], expectedNote: before);
      expect(added!.body, startsWith('Authored\r\ntext\r\n\r\n'));
      expect(added.properties['future'], {'keep': true});
      expect(c.find(source.id)!.data, source.data);
      final links = ObjectConnectionResolver().resolve(c.activeObjects);
      expect(
        links.any(
          (e) =>
              e.source.id == added.id &&
              e.target.id == source.id &&
              e.target.anchorType == 'elements',
        ),
        true,
      );
    },
  );

  test(
    'failed note writes retry one append; stale source or note cannot be overwritten',
    () async {
      final (container, c, store) = await memory();
      addTearDown(() {
        store.failWrites = false;
        c.cancelAllTimers();
        container.dispose();
      });
      final source = (await c.create('orbit.canvas', data: boardData()))!;
      final note = (await c.create('orbit.note', body: 'Keep'))!;
      store.failWrites = true;
      expect(
        await c.exportCanvasDiagramToNote(source, [
          'item-0',
        ], expectedNote: note),
        isNull,
      );
      expect(c.find(note.id)!.body, contains('orbit:object'));
      store.failWrites = false;
      final saved = await c.exportCanvasDiagramToNote(source, [
        'item-0',
      ], expectedNote: note);
      expect(saved, isNotNull);
      expect('orbit:object v=1'.allMatches(saved!.body), hasLength(1));
      c.edit(note.id, body: 'Newer draft');
      expect(
        await c.exportCanvasDiagramToNote(source, [
          'item-0',
        ], expectedNote: note),
        isNull,
      );
      expect(c.find(note.id)!.body, 'Newer draft');
      c.edit(source.id, data: {'schemaVersion': 1, 'elements': []});
      expect(await c.exportCanvasDiagramToNote(source, ['item-0']), isNull);
      await c.flushAll();
    },
  );

  test(
    'native restart retains the linked selection and original Canvas metadata',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-diagram-note-');
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: root.path);
        final source = await repo.create(
          typeId: 'orbit.canvas',
          title: 'Model',
          data: boardData(),
        );
        final body = diagramMarkdown(source.id, 'Diagram', [
          'item-0',
          'item-1',
        ]);
        final note = await repo.create(
          typeId: 'orbit.note',
          title: 'Design',
          body: body,
          properties: {'future': 42},
        );
        await repo.close();
        await repo.initialize(path: root.path);
        final saved = repo.objects.singleWhere((o) => o.id == note.id);
        expect(saved.body, body);
        expect(saved.properties['future'], 42);
        final savedSource = repo.objects.singleWhere((o) => o.id == source.id);
        expect(savedSource.data, source.data);
        expect(
          ResolvedCanvasDiagram(
            CanvasScene.fromJson(savedSource.data),
            diagramElementIds(NoteObjectBlock.parse(saved.body)!.reference)!,
          ).scene.elements,
          hasLength(3),
        );
      } finally {
        await repo.close();
        await root.delete(recursive: true);
      }
    },
  );

  Future<void> desktop(
    WidgetTester tester, {
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final rich in [true, false]) {
    testWidgets(
      '${rich ? 'Rich' : 'Read'} draws a live selection, opens precise source and retains it on removal',
      (tester) async {
        await desktop(tester);
        var source = board();
        var body = diagramMarkdown(source.id, 'Class diagram', [
          'item-0',
          'item-1',
        ]);
        late StateSetter update;
        String? opened;
        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return NoteEditor(
                    noteId: 'note',
                    title: 'Design',
                    body: body,
                    allObjects: [source],
                    linkTargets: const [],
                    initialViewState: {'mode': rich ? 'rich' : 'read'},
                    onTitleChanged: (_) {},
                    onBodyChanged: (v) => setState(() => body = v),
                    onOpenObject: (v) => opened = v,
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        OrbitCanvasPainter painter() =>
            tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('note-diagram-vector')),
                    )
                    .painter!
                as OrbitCanvasPainter;
        expect(painter().scene.elements, hasLength(3));
        expect(painter().scene['item-2'], isNull);
        final changed = CanvasScene.fromJson(source.data)
          ..put(
            CanvasScene.fromJson(
              source.data,
            )['item-0']!.copy({'text': 'Changed live'}),
          );
        update(() => source = source.copyWith(data: changed.toJson()));
        await tester.pumpAndSettle();
        expect(painter().scene['item-0']!.text, 'Changed live');
        await tester.ensureVisible(find.text('Open Canvas'));
        await tester.tap(find.text('Open Canvas'));
        await tester.pumpAndSettle();
        expect(diagramElementIds(ObjectReference.parse(opened!)), [
          'item-0',
          'item-1',
        ]);
        if (rich) {
          await tester.ensureVisible(find.text('Remove embed'));
          await tester.tap(find.text('Remove embed'));
          await tester.pumpAndSettle();
          expect(body, '');
        }
        expect(source.typeId, 'orbit.canvas');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'missing or hidden selection reports incomplete coverage without showing another class',
    (tester) async {
      await desktop(tester);
      final scene = CanvasScene.fromJson(boardData())..remove('item-0');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NoteObjectSurface(
                block: NoteObjectBlock.parse(
                  diagramMarkdown('board', 'Selection', ['item-0']),
                )!,
                objects: [board(data: scene.toJson())],
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('1 referenced diagram items'), findsOneWidget);
      expect(find.byKey(const ValueKey('note-diagram-vector')), findsNothing);
      expect(find.text('Patient'), findsNothing);
    },
  );

  testWidgets(
    'diagram preview supports expansion and narrow 2x text without overflow',
    (tester) async {
      await desktop(tester, size: const Size(390, 800));
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: NoteObjectSurface(
                block: NoteObjectBlock.parse(
                  diagramMarkdown('board', 'A long diagram title', [
                    'item-0',
                    'item-1',
                    'item-2',
                    'item-3',
                  ]),
                )!,
                objects: [board()],
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Expand'));
      await tester.tap(find.text('Expand'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close diagram preview'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
    },
  );

  testWidgets(
    'Canvas copies a real diagram block and source selection can be restored',
    (tester) async {
      await desktop(tester);
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board',
              data: boardData(),
              onChanged: (_) {},
              objects: const [],
              onOpenObject: (_) {},
              focusElementIds: const ['item-0', 'item-1'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Shapes and diagrams'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Copy live diagram for Markdown'));
      await tester.tap(find.text('Copy live diagram for Markdown'));
      await tester.pumpAndSettle();
      final block = NoteObjectBlock.parse(clipboard!)!;
      expect(diagramElementIds(block.reference), ['item-0', 'item-1']);
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<OrbitCanvasPainter>()
          .first;
      expect(painter.selection, {'item-0', 'item-1'});
    },
  );

  testWidgets('export dialog creates a real saved Markdown note', (
    tester,
  ) async {
    await desktop(tester);
    final fixture = await tester.runAsync(memory);
    final (container, c, store) = fixture!;
    final source = (await tester.runAsync(
      () =>
          c.create('orbit.canvas', title: 'Diagram source', data: boardData()),
    ))!;
    String? created;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => created = await showDiagramNoteDialog(
                  context,
                  c,
                  source,
                  ['item-0', 'item-1'],
                ),
                child: const Text('Export'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Diagram title'),
      'My model',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Create note'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(created, isNotNull);
    expect(c.find(created!)!.title, 'My model');
    expect(NoteObjectBlock.parse(c.find(created!)!.body), isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.failWrites = false;
    c.cancelAllTimers();
    container.dispose();
  });
}
