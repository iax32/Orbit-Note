import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/domain/note_composition.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/note_composition.dart';
import 'package:orbit_note/features/notes/note_object_surface.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_find_index.dart';
import 'package:orbit_note/features/notes/note_typography.dart';
import 'package:orbit_note/features/notes/replacement_review.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

UniversalObject object(
  String id,
  String type, {
  String title = 'Source',
  Map<String, dynamic> data = const {},
}) => UniversalObject(
  id: id,
  workspaceId: 'test',
  typeId: type,
  title: title,
  data: data,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  Future<(ProviderContainer, WorkspaceController)> controllerFor(
    WorkspaceRepository repo,
  ) async {
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    final controller = container.read(workspaceProvider.notifier);
    await controller.initialize();
    return (container, controller);
  }

  test(
    'drawing creation retains the writing tab and linked placements keep canonical source identity',
    () async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      final (container, controller) = await controllerFor(repo);
      try {
        final note = (await controller.create(
          'orbit.note',
          title: 'Writing',
          body: 'First paragraph\n\nSecond paragraph\n',
        ))!;
        final drawing = (await controller.create(
          'orbit.canvas',
          open: false,
          title: 'Sketch',
        ))!;
        expect(controller.session.activeId, note.id);
        await controller.placeNoteBlock(note.id, 0, drawing.id);
        final board = controller.find(drawing.id)!;
        final card = (board.data['elements'] as List).single as Map;
        expect(card['objectId'], note.id);
        expect(card['referenceTarget'], contains('#'));
        controller.edit(drawing.id, data: {...board.data, 'elements': []});
        await controller.flush(drawing.id);
        expect(controller.find(note.id)!.body, contains('First paragraph'));
        expect(controller.find(note.id)!.isDeleted, false);
      } finally {
        container.dispose();
        await repo.close();
      }
    },
  );
  test(
    'column edit and stacking retain exact mixed-ending bytes and links',
    () {
      final source = NoteColumns.create([
        '**Left**\r\n\n[Source](orbit-object:note-1)\n',
        'Right\r\n',
      ], eol: '\r\n');
      final doc = MarkdownDocument.parse('Before\n\n$source\nAfter\n');
      expect(doc.source, 'Before\n\n$source\nAfter\n');
      final columns = NoteColumns.parse(source)!;
      expect(
        NoteColumns.parse(columns.replace(1, 'New\r\n'))!.parts.first,
        columns.parts.first,
      );
      expect(columns.stacked, contains('[Source](orbit-object:note-1)'));
    },
  );
  test(
    'closing and divider examples inside code fences stay in their column',
    () {
      final source = NoteColumns.create([
        '```html\n${NoteColumns.closing}\n${NoteColumns.divider}\n```\n',
        'Right\n',
      ]);
      expect(NoteColumns.parse(source)!.parts, hasLength(2));
      expect(MarkdownDocument.parse(source).blocks.first.source, source);
    },
  );
  test('unknown, nested, incomplete and oversized columns remain literal', () {
    for (final source in [
      '<!-- orbit:columns v=2 -->\nA\n${NoteColumns.divider}\nB\n${NoteColumns.closing}\n',
      '<!-- orbit:columns v=1 -->\nA\n${NoteColumns.divider}\nB\n',
      '<!-- orbit:columns v=1 -->\n<!-- orbit:columns v=1 -->\nA\n${NoteColumns.divider}\nB\n${NoteColumns.closing}\n',
      '<!-- orbit:columns v=1 -->\n${'A' * 200001}\n${NoteColumns.divider}\nB\n${NoteColumns.closing}\n',
    ]) {
      expect(NoteColumns.parse(source), isNull);
      expect(MarkdownDocument.parse(source).source, source);
    }
    expect(
      () => NoteColumns.create(['```dart\n', 'Right\n']),
      throwsFormatException,
    );
  });
  test('linked object references round-trip and reject injection', () {
    final source = const NoteObjectBlock('task-1', 'A [task]\n').encode();
    expect(NoteObjectBlock.parse(source)!.id, 'task-1');
    expect(NoteObjectBlock.parse(source)!.label, 'A  task');
    expect(MarkdownDocument.parse(source).source, source);
    expect(
      () => const NoteObjectBlock('bad)\n', 'Title').encode(),
      throwsFormatException,
    );
    expect(NoteObjectBlock.parse(source.replaceFirst('v=1', 'v=2')), isNull);
  });
  test(
    'explicit conversion retains link markup and rejects structured content',
    () {
      const source = 'Read [source](orbit-object:note-1)\n\nSecond paragraph\n';
      expect(
        convertProseBlocks(source, 'Checklist'),
        contains('- [ ] Read [source](orbit-object:note-1)'),
      );
      expect(
        convertProseBlocks(source, 'Callout'),
        startsWith('> [!NOTE]\n> Read'),
      );
      expect(
        convertProseBlocks(source, 'Table'),
        contains('| Read [source](orbit-object:note-1) |'),
      );
      expect(
        () => convertProseBlocks('```dart\ncode\n```', 'Checklist'),
        throwsFormatException,
      );
      expect(
        () => convertProseBlocks('<!-- unknown -->', 'Callout'),
        throwsFormatException,
      );
    },
  );
  test(
    'visible replacement spans columns, tables and code without changing layout markers',
    () {
      final source = NoteColumns.create([
        '**cat**\r\n\r\n| Thing |\r\n| --- |\r\n| cat |\r\n',
        '```dart\ncat\n```\n',
      ], eol: '\r\n');
      final index = NoteFindIndex(source, rich: true);
      expect(index.matches('cat'), hasLength(3));
      expect(index.matches('orbit:column'), isEmpty);
      final result = index.replace(index.matches('cat'), 'dog');
      expect(NoteColumns.parse(result), isNotNull);
      expect(result, contains('**dog**\r\n'));
      expect(result, contains('| dog |\r\n'));
      expect(result, contains('```dart\ndog\n```'));
      final objectIndex = NoteFindIndex(
        const NoteObjectBlock('cat', 'cat').encode(),
        rich: true,
      );
      expect(objectIndex.matches('cat'), isEmpty);
      expect(
        () => index.replace(index.matches('cat'), '\n${NoteColumns.closing}\n'),
        throwsFormatException,
      );
    },
  );
  test('mixed divider endings retain exact UTF-16 search offsets', () {
    const source =
        '<!-- orbit:columns v=1 -->\nLeft\r\n<!-- orbit:column -->\r\nRight 😀\n<!-- /orbit:columns -->\n';
    final match = NoteFindIndex(source, rich: true).matches('Right 😀').single;
    expect(match.start, source.indexOf('Right'));
    expect(source.substring(match.start, match.end), 'Right 😀');
  });
  testWidgets('Rich search selects exact text inside the correct column', (
    tester,
  ) async {
    final body = NoteColumns.create(['Left\n', '**Right cat**\n']);
    final key = GlobalKey<RichMarkdownEditorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichMarkdownEditor(
            key: key,
            body: body,
            onChanged: (_) {},
            onUndo: () {},
            onRedo: () {},
            linkTargets: const [],
            linkBindings: const {},
            onOpenLink: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final match = NoteFindIndex(body, rich: true).matches('Right').single;
    key.currentState!.jumpTo(match.start, length: match.end - match.start);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'Right cat',
      ),
    );
    expect(
      field.controller!.selection.textInside(field.controller!.text),
      'Right',
    );
    expect(key.currentState!.currentDocumentSelection.start, match.start);
    expect(key.currentState!.currentDocumentSelection.end, match.end);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'cached Rich embeds refresh after source rename and removal keeps originals',
    (tester) async {
      var body = const NoteObjectBlock('task-1', 'Captured').encode();
      var objects = [object('task-1', 'orbit.task', title: 'Before')];
      late StateSetter refresh;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, update) {
                refresh = update;
                return RichMarkdownEditor(
                  body: body,
                  allObjects: objects,
                  onChanged: (next) => update(() => body = next),
                  onUndo: () {},
                  onRedo: () {},
                  linkTargets: const [],
                  linkBindings: const {},
                  onOpenLink: (_) {},
                  objectBlockBuilder: (block, editable) => NoteObjectSurface(
                    block: block,
                    editable: editable,
                    objects: objects,
                    onOpen: (_) {},
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Before'), findsOneWidget);
      refresh(() => objects = [object('task-1', 'orbit.task', title: 'After')]);
      await tester.pumpAndSettle();
      expect(find.text('After'), findsOneWidget);
      expect(find.text('Before'), findsNothing);
      await tester.tap(find.text('Remove embed'));
      await tester.pumpAndSettle();
      expect(body, '');
      expect(objects.single.id, 'task-1');
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'layout and links survive reopening; failed edits preserve committed bytes',
    () async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final drawing = await repo.create(
        typeId: 'orbit.canvas',
        title: 'Drawing',
        data: {'schemaVersion': 1, 'elements': []},
      );
      final body = NoteColumns.create([
        'Prose\n',
        NoteObjectBlock(drawing.id, drawing.title).encode(),
      ]);
      final note = await repo.create(
        typeId: 'orbit.note',
        title: 'Layout',
        body: body,
        properties: {'unknown': 42},
      );
      await repo.close();
      final reopened = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await reopened.initialize();
      final saved = reopened.objects.singleWhere((o) => o.id == note.id);
      expect(saved.body, body);
      expect(saved.properties['unknown'], 42);
      store.failWrites = true;
      await expectLater(
        reopened.save(saved.copyWith(body: 'Broken')),
        throwsA(anything),
      );
      store.failWrites = false;
      await reopened.close();
      final recovered = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await recovered.initialize();
      expect(recovered.objects.singleWhere((o) => o.id == note.id).body, body);
      expect(
        recovered.objects.singleWhere((o) => o.id == drawing.id).typeId,
        'orbit.canvas',
      );
      await recovered.close();
    },
  );
  testWidgets(
    'editing either column retains its neighbor and stacks losslessly',
    (tester) async {
      var body = NoteColumns.create(['Left\n', 'Right\n']);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, update) => RichMarkdownEditor(
                body: body,
                onChanged: (next) => update(() => body = next),
                onUndo: () {},
                onRedo: () {},
                linkTargets: const [],
                linkBindings: const {},
                onOpenLink: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final right = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'Right',
      );
      await tester.enterText(right, 'Changed right');
      await tester.pumpAndSettle();
      expect(NoteColumns.parse(body)!.parts.first, 'Left\n');
      expect(NoteColumns.parse(body)!.parts.last, 'Changed right\n');
      await tester.tap(find.text('Stack as Markdown'));
      await tester.pumpAndSettle();
      expect(body, 'Left\n\nChanged right\n');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Read columns render prose and linked objects with 200% narrow layouts',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final body = NoteColumns.create([
        '**Left**\n',
        const NoteObjectBlock('task-1', 'Task').encode(),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 900),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: MarkdownBody(
                  data: body,
                  blockSyntaxes: const [NoteCompositionSyntax()],
                  builders: {
                    'orbit-composition': NoteCompositionBuilder(
                      typography: const NoteTypography(),
                      onOpen: (_) {},
                      objectBuilder: (block, _) =>
                          Text('Linked ${block.label}'),
                      blockSyntaxes: const [NoteCompositionSyntax()],
                      builders: {
                        'orbit-composition': NoteCompositionBuilder(
                          typography: const NoteTypography(),
                          onOpen: (_) {},
                          objectBuilder: (block, _) =>
                              Text('Linked ${block.label}'),
                        ),
                      },
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Left', findRichText: true), findsOneWidget);
      expect(find.text('Linked Task'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'missing live objects retain recovery details and sources update by ID',
    (tester) async {
      Future<void> show(List<UniversalObject> objects) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteObjectSurface(
              block: const NoteObjectBlock('task-1', 'Captured title'),
              objects: objects,
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await show([]);
      expect(find.textContaining('Source unavailable'), findsOneWidget);
      expect(find.text('orbit-object:task-1'), findsOneWidget);
      await show([object('task-1', 'orbit.task', title: 'New title')]);
      expect(find.text('New title'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'drawing previews reuse the Canvas painter without editing originals',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteObjectSurface(
              block: const NoteObjectBlock('drawing', 'Drawing'),
              objects: [
                object(
                  'drawing',
                  'orbit.canvas',
                  data: {
                    'schemaVersion': 1,
                    'elements': [
                      {
                        'id': 'rect',
                        'type': 'rectangle',
                        'x': 0,
                        'y': 0,
                        'width': 160,
                        'height': 80,
                      },
                    ],
                  },
                ),
              ],
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open source'), findsOneWidget);
      expect(find.text('Edit drawing'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'replacement review selects individual changes and cancels without edits',
    (tester) async {
      const source = 'cat one\n\ncat two';
      final index = NoteFindIndex(source, rich: true);
      List<NoteFindMatch>? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showReplacementReview(
                    context,
                    index,
                    index.matches('cat'),
                    'dog',
                  );
                },
                child: const Text('Review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply 1 changes'));
      await tester.pumpAndSettle();
      expect(index.replace(selected!, 'dog'), 'cat one\n\ndog two');
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    },
  );
  testWidgets(
    'live tasks write to their canonical owner and drawing edits reject stale data',
    (tester) async {
      late WorkspaceRepository repo;
      late ProviderContainer container;
      late WorkspaceController controller;
      await tester.runAsync(() async {
        repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        controller = container.read(workspaceProvider.notifier);
        await controller.initialize();
      });
      await tester.pumpAndSettle();
      final task = (await tester.runAsync(
        () =>
            controller.create('orbit.task', open: false, title: 'Deliverable'),
      ))!;
      final drawing = (await tester.runAsync(
        () => controller.create('orbit.canvas', open: false, title: 'Sketch'),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteObjectSurface(
              block: NoteObjectBlock(task.id, task.title),
              controller: controller,
              objects: controller.activeObjects,
              editable: true,
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byType(Checkbox));
        await controller.flushAll();
      });
      await tester.pump();
      expect(controller.find(task.id)!.isCompleted, true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteObjectSurface(
              block: NoteObjectBlock(drawing.id, drawing.title),
              controller: controller,
              objects: controller.activeObjects,
              editable: true,
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit drawing'));
      await tester.pumpAndSettle();
      final editor = tester.widget<CanvasEditor>(find.byType(CanvasEditor));
      await tester.runAsync(() async {
        editor.onChanged({
          ...drawing.data,
          'elements': [
            {
              'id': 'first',
              'type': 'text',
              'text': 'Accepted',
              'x': 0,
              'y': 0,
              'width': 120,
              'height': 80,
            },
          ],
        });
        await controller.flushAll();
      });
      expect(
        (controller.find(drawing.id)!.data['elements'] as List).single['text'],
        'Accepted',
      );
      await tester.runAsync(() async {
        controller.edit(
          drawing.id,
          data: {...drawing.data, 'unknown': 'External edit'},
        );
        await controller.flushAll();
      });
      editor.onChanged({...drawing.data, 'elements': []});
      expect(controller.find(drawing.id)!.data['unknown'], 'External edit');
      await tester.pump();
      expect(find.textContaining('changed elsewhere'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await controller.flushAll();
        container.dispose();
        await repo.close();
      });
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('selection conversion is one undoable note change', (
    tester,
  ) async {
    var body = 'First\n\nSecond\n';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, update) => NoteEditor(
              noteId: 'note',
              initialViewState: const {'mode': 'write'},
              title: 'Writing',
              body: body,
              onTitleChanged: (_) {},
              onBodyChanged: (next) => update(() => body = next),
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('note-body'));
    tester.widget<TextField>(field).controller!.selection = TextSelection(
      baseOffset: 0,
      extentOffset: body.length,
    );
    await tester.tap(find.byTooltip('Writing tools'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Convert selection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Convert selection'));
    await tester.pumpAndSettle();
    expect(
      find.text('Convert selected blocks'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .join(' | '),
    );
    await tester.tap(find.text('Checklist').last);
    await tester.pumpAndSettle();
    expect(body, '- [ ] First\n\n- [ ] Second\n');
    await tester.tap(field);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(body, 'First\n\nSecond\n');
    expect(tester.takeException(), isNull);
  });
}
