import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/rich/dynamic_view_block.dart';
import 'package:orbit_note/features/workspace/collection_kanban_view.dart';
import 'package:orbit_note/features/workspace/collection_table_view.dart';
import 'package:orbit_note/features/workspace/saved_view_host.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'support/memory_store.dart';

class TestFolderStore extends MemoryStore implements WorkspaceFolderStore {
  final folders = <String>['Notes'];
  @override
  Future<List<String>> listFolders() async => List.of(folders);
  @override
  Future<void> createFolder(String path) async {
    if (!folders.contains(path)) {
      folders.add(path);
    }
  }

  @override
  Future<void> deleteFolder(String path) async {
    folders.remove(path);
    folders.removeWhere((f) => f.startsWith('$path/'));
    files.removeWhere((k, _) => k.startsWith('$path/'));
  }

  @override
  Future<void> movePath(
    String source,
    String target,
    Map<String, FileReplacement> replacements,
  ) async {
    final content = files.remove(source);
    if (content != null) {
      files[target] = content;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DynamicViewConfig Format & Saved View Reference (VIEW-07)', () {
    test('parses and serializes format: table and view reference', () {
      const yaml = '''
type: table
format: table
view: view-apollo-42
folder: Projects/Apollo
status: open
limit: 15
title: Apollo Sprint Table
''';
      final config = DynamicViewConfig.fromYaml(yaml);
      expect(config.type, 'table');
      expect(config.format, 'table');
      expect(config.viewId, 'view-apollo-42');
      expect(config.folder, 'Projects/Apollo');
      expect(config.status, 'open');
      expect(config.limit, 15);
      expect(config.title, 'Apollo Sprint Table');

      final serialized = config.toYaml();
      expect(serialized, contains('type: table'));
      expect(serialized, contains('format: table'));
      expect(serialized, contains('view: view-apollo-42'));
      expect(serialized, contains('limit: 15'));

      final md = config.toMarkdown();
      expect(md.startsWith('```orbit-view\n'), isTrue);
      expect(md, contains('format: table'));
      expect(md, contains('view: view-apollo-42'));
    });
  });

  group('CollectionTableView (VIEW-01, VIEW-03, VIEW-06)', () {
    late TestFolderStore store;
    late WorkspaceRepository repo;
    late ProviderContainer container;
    late WorkspaceController controller;

    setUp(() async {
      store = TestFolderStore();
      repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      controller = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 100 && controller.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    });

    tearDown(() {
      controller.cancelAllTimers();
      container.dispose();
    });

    testWidgets(
      'renders smart collection items matching folder/scope with customizable columns and sorting',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        late UniversalObject note1;
        late UniversalObject task1;
        late UniversalObject viewObj;

        await tester.runAsync(() async {
          // Seed notes and tasks in "Projects/Apollo"
          note1 = (await controller.create(
            'orbit.note',
            title: 'Apollo Architecture Spec',
            body: '# Apollo Spec\nThis markdown body must NEVER be altered.',
            properties: {
              'folder': 'Projects/Apollo',
              'status': 'in-progress',
              'priority': 'high',
              'tags': ['space', 'systems'],
            },
          ))!;

          task1 = (await controller.create(
            'orbit.task',
            title: 'Build Propulsion Engine',
            properties: {
              'folder': 'Projects/Apollo',
              'status': 'todo',
              'priority': 'urgent',
              'completed': false,
              'tags': ['hardware'],
            },
          ))!;

          // Seed unrelated note outside folder
          await controller.create(
            'orbit.note',
            title: 'Shopping List',
            properties: {'folder': 'Personal'},
          );

          // Create saved view object
          viewObj = (await controller.create(
            'orbit.view',
            title: 'Apollo Active Items',
            properties: {'viewType': 'table', 'folder': 'Projects/Apollo'},
          ))!;
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CollectionTableView(
                controller: controller,
                viewObject: viewObj,
                folderFilter: 'Projects/Apollo',
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify smart query badge and matching items
        expect(
          find.textContaining('Smart Query (2 · Projects/Apollo)'),
          findsOneWidget,
        );
        expect(find.text('Apollo Architecture Spec'), findsOneWidget);
        expect(find.text('Build Propulsion Engine'), findsOneWidget);
        expect(find.text('Shopping List'), findsNothing);

        // Verify column headers
        expect(find.text('TITLE / NAME'), findsOneWidget);
        expect(find.text('STATUS'), findsOneWidget);
        expect(find.text('PRIORITY'), findsOneWidget);

        // Test sorting: tap TITLE header to sort ascending
        await tester.tap(find.text('TITLE / NAME'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

        // Tap TITLE header again to sort descending
        await tester.tap(find.text('TITLE / NAME'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

        // Test inline property edit: toggle task checkbox to 'done'
        final taskCheckbox = find.byType(Checkbox).first;
        expect(taskCheckbox, findsOneWidget);
        await tester.tap(taskCheckbox);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Verify task updated in controller
        final updatedTask = controller.find(task1.id);
        expect(updatedTask?.properties['status'], 'done');
        expect(updatedTask?.isCompleted, isTrue);

        // Verify Note 1 Markdown body is 100% UNTOUCHED (VIEW-06)
        final checkedNote = controller.find(note1.id);
        expect(
          checkedNote?.body,
          '# Apollo Spec\nThis markdown body must NEVER be altered.',
        );

        controller.cancelAllTimers();
      },
    );

    testWidgets('respects manual collection membership (VIEW-01)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late UniversalObject itemA;
      late UniversalObject itemB;
      late UniversalObject manualViewObj;

      await tester.runAsync(() async {
        itemA = (await controller.create(
          'orbit.note',
          title: 'Curated Alpha',
        ))!;
        itemB = (await controller.create('orbit.task', title: 'Curated Beta'))!;
        await controller.create('orbit.note', title: 'Uncurated Gamma');

        manualViewObj = (await controller.create(
          'orbit.view',
          title: 'My Curated Collection',
          properties: {
            'viewType': 'table',
            'manual': true,
            'memberIds': [itemA.id, itemB.id],
          },
        ))!;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollectionTableView(
              controller: controller,
              viewObject: manualViewObj,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Manual Collection (2)'), findsOneWidget);
      expect(find.text('Curated Alpha'), findsOneWidget);
      expect(find.text('Curated Beta'), findsOneWidget);
      expect(find.text('Uncurated Gamma'), findsNothing);
    });
  });

  group('CollectionKanbanView (VIEW-02, VIEW-04, VIEW-06)', () {
    late TestFolderStore store;
    late WorkspaceRepository repo;
    late ProviderContainer container;
    late WorkspaceController controller;

    setUp(() async {
      store = TestFolderStore();
      repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      controller = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 100 && controller.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    });

    tearDown(() {
      controller.cancelAllTimers();
      container.dispose();
    });

    testWidgets(
      'groups objects by status, priority and project with drag target property updates without Markdown alteration',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 850);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        late UniversalObject noteA;
        late UniversalObject kanbanViewObj;

        await tester.runAsync(() async {
          noteA = (await controller.create(
            'orbit.note',
            title: 'Research Propulsion',
            body: '# Important Markdown Content\nDo not overwrite.',
            properties: {
              'status': 'backlog',
              'priority': 'high',
              'project': 'Apollo',
            },
          ))!;

          await controller.create(
            'orbit.task',
            title: 'Assemble Thruster',
            properties: {
              'status': 'in-progress',
              'priority': 'urgent',
              'project': 'Apollo',
              'completed': false,
            },
          );

          kanbanViewObj = (await controller.create(
            'orbit.view',
            title: 'Apollo Board',
            properties: {
              'viewType': 'board',
              'groupBy': 'status',
              'preset': 'universal',
            },
          ))!;
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CollectionKanbanView(
                controller: controller,
                viewObject: kanbanViewObj,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify kanban columns exist
        expect(find.text('Backlog'), findsOneWidget);
        expect(find.text('To Do'), findsOneWidget);
        expect(find.text('In Progress'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('No Status'), findsOneWidget);

        // Verify cards are placed in respective columns
        expect(find.text('Research Propulsion'), findsOneWidget);
        expect(find.text('Assemble Thruster'), findsOneWidget);

        // Simulate drag-and-drop: drag 'Research Propulsion' from backlog to done
        final doneTarget = find.ancestor(
          of: find.text('Done'),
          matching: find.byType(DragTarget<String>),
        );
        expect(doneTarget, findsOneWidget);

        final dragTargetWidget = tester.widget<DragTarget<String>>(doneTarget);
        dragTargetWidget.onAcceptWithDetails?.call(
          DragTargetDetails<String>(data: noteA.id, offset: Offset.zero),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Verify property updated on noteA
        final updatedNote = controller.find(noteA.id);
        expect(updatedNote?.properties['status'], 'done');
        // Crucially, body is preserved!
        expect(
          updatedNote?.body,
          '# Important Markdown Content\nDo not overwrite.',
        );

        controller.cancelAllTimers();
      },
    );

    testWidgets(
      'groups objects by priority when configured (VIEW-02, VIEW-04)',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 850);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        late UniversalObject taskB;
        late UniversalObject kanbanViewObj;

        await tester.runAsync(() async {
          taskB = (await controller.create(
            'orbit.task',
            title: 'Assemble Thruster',
            properties: {
              'status': 'in-progress',
              'priority': 'low',
              'completed': false,
            },
          ))!;

          kanbanViewObj = (await controller.create(
            'orbit.view',
            title: 'Priority Board',
            properties: {'viewType': 'board', 'groupBy': 'priority'},
          ))!;
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CollectionKanbanView(
                controller: controller,
                viewObject: kanbanViewObj,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify priority columns appear
        expect(find.text('🔴 Urgent'), findsOneWidget);
        expect(find.text('🟠 High'), findsOneWidget);
        expect(find.text('🔵 Medium'), findsOneWidget);
        expect(find.text('⚪ Low'), findsOneWidget);
        expect(find.text('No Priority'), findsOneWidget);

        // Drag 'Assemble Thruster' to '🔴 Urgent'
        final urgentTarget = find.ancestor(
          of: find.text('🔴 Urgent'),
          matching: find.byType(DragTarget<String>),
        );
        final urgentDragTarget = tester.widget<DragTarget<String>>(
          urgentTarget,
        );
        urgentDragTarget.onAcceptWithDetails?.call(
          DragTargetDetails<String>(data: taskB.id, offset: Offset.zero),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final updatedTask = controller.find(taskB.id);
        expect(updatedTask?.properties['priority'], 'urgent');

        controller.cancelAllTimers();
      },
    );
  });

  group('SavedViewHost Multi-View Tabs (VIEW-02, VIEW-06)', () {
    late TestFolderStore store;
    late WorkspaceRepository repo;
    late ProviderContainer container;
    late WorkspaceController controller;

    setUp(() async {
      store = TestFolderStore();
      repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      controller = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 100 && controller.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    });

    tearDown(() {
      controller.cancelAllTimers();
      container.dispose();
    });

    testWidgets('SavedViewHost toggles between List, Board, and Table tabs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late UniversalObject viewObj;
      await tester.runAsync(() async {
        viewObj = (await controller.create(
          'orbit.view',
          title: 'Project Overview',
          properties: {'viewType': 'tasks'},
        ))!;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavedViewHost(viewObject: viewObj, controller: controller),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify tabs exist
      expect(find.text('List'), findsWidgets);
      expect(find.text('Board'), findsWidgets);
      expect(find.text('Table'), findsWidgets);

      // Tap 'Table' tab
      await tester.tap(find.text('Table').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify CollectionTableView is active
      expect(find.byType(CollectionTableView), findsOneWidget);
      expect(controller.find(viewObj.id)?.properties['viewType'], 'table');

      // Tap 'Board' tab
      await tester.tap(find.text('Board').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify CollectionKanbanView is active
      expect(find.byType(CollectionKanbanView), findsOneWidget);
      expect(controller.find(viewObj.id)?.properties['viewType'], 'board');

      controller.cancelAllTimers();
    });
  });

  group('DynamicViewBlock Embedded Table (VIEW-07)', () {
    late TestFolderStore store;
    late WorkspaceRepository repo;
    late ProviderContainer container;
    late WorkspaceController controller;

    setUp(() async {
      store = TestFolderStore();
      repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      controller = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 100 && controller.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    });

    tearDown(() {
      controller.cancelAllTimers();
      container.dispose();
    });

    testWidgets(
      'DynamicViewBlock with format: table renders table headers and items',
      (tester) async {
        await tester.runAsync(() async {
          await controller.create(
            'orbit.task',
            title: 'Complete Spec Review',
            properties: {'status': 'in-progress', 'completed': false},
          );
        });

        const markdownSource = '''
```orbit-view
type: tasks
format: table
limit: 5
```
''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DynamicViewBlock(
                source: markdownSource,
                controller: controller,
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify table layout rendered
        expect(find.text('TITLE'), findsOneWidget);
        expect(find.text('STATUS / TYPE'), findsOneWidget);
        expect(find.text('UPDATED'), findsOneWidget);
        expect(find.text('Complete Spec Review'), findsOneWidget);

        controller.cancelAllTimers();
      },
    );
  });
}
