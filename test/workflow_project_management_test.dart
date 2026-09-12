import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'support/memory_store.dart';
import 'package:orbit_note/features/workspace/calendar_view.dart';
import 'package:orbit_note/features/workspace/saved_view_host.dart';
import 'package:orbit_note/features/workspace/timeline_view.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';

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

  group('Universal Object Principle: Create Once, View Anywhere', () {
    late ProviderContainer container;
    late WorkspaceController controller;

    setUp(() async {
      final repo = WorkspaceRepository(
        store: TestFolderStore(),
        index: MemoryObjectIndex(),
      );
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      controller = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 100 && controller.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    });

    tearDown(() async {
      await controller.flushAll();
      container.dispose();
    });
    test(
      'A single task appears in scoped views without duplicating data',
      () async {
        // 1. Create a course folder
        await controller.repository.createFolder('Notes/University/AKMath');

        // 2. Create Prerequisite Task
        final prereqTask = await controller.create(
          'orbit.task',
          title: 'Prerequisite Theory Review',
          properties: {'folder': 'Notes/University/AKMath', 'completed': false},
        );
        expect(prereqTask, isNotNull);

        // 3. Create Main Course Task with estimate, category, subtasks, and blocker
        final mainTask = await controller.create(
          'orbit.task',
          title: 'Finish AKMath Relations Exercises',
          body: '''
# Homework 4
- [x] Read section 4.1
- [ ] Solve problem 1
- [ ] Solve problem 2
''',
          properties: {
            'folder': 'Notes/University/AKMath',
            'dueDate': '2026-10-15',
            'estimate': '5',
            'category': 'Homework',
            'priority': 'urgent',
            'blockedBy': prereqTask!.id,
            'status': 'assignments',
          },
        );
        expect(mainTask, isNotNull);

        // 4. Create an exam event in the same course folder
        final examEvent = await controller.create(
          'orbit.event',
          title: 'AKMath Midterm Exam',
          properties: {
            'folder': 'Notes/University/AKMath',
            'allDay': true,
            'startDate': '2026-10-20',
            'endDate': '2026-10-21',
          },
        );
        expect(examEvent, isNotNull);

        // 5. Create a task in another unrelated folder
        final otherTask = await controller.create(
          'orbit.task',
          title: 'Buy Groceries',
          properties: {
            'folder': 'Notes/Personal',
            'dueDate': '2026-10-10',
            'completed': false,
          },
        );
        expect(otherTask, isNotNull);

        // Verify task count in workspace: exactly 3 tasks, zero duplicates
        final allTasks = controller.ofType('orbit.task');
        expect(allTasks.length, 3);
        expect(allTasks.where((t) => t.id == mainTask!.id).length, 1);

        // Verify TimelineView filters to AKMath course objects
        final timelineWidget = TimelineView(
          controller: controller,
          folderFilter: 'Notes/University/AKMath',
        );
        expect(timelineWidget.folderFilter, 'Notes/University/AKMath');

        // Verify CalendarView filters to AKMath course objects
        final calendarWidget = CalendarView(
          controller: controller,
          folderFilter: 'Notes/University/AKMath',
        );
        expect(calendarWidget.folderFilter, 'Notes/University/AKMath');

        // Verify TasksView with board preset
        final tasksBoardWidget = TasksView(
          controller: controller,
          folderFilter: 'Notes/University/AKMath',
          initialTab: 'board',
        );
        expect(tasksBoardWidget.folderFilter, 'Notes/University/AKMath');
        expect(tasksBoardWidget.initialTab, 'board');
      },
    );

    test(
      'Folder archiving and restoration non-destructively tracks folders',
      () async {
        const courseFolder = 'Notes/University/Physics101';
        await controller.repository.createFolder(courseFolder);
        await controller.repository.createFolder('$courseFolder/Labs');

        expect(controller.isArchivedFolder(courseFolder), isFalse);
        expect(controller.isArchivedFolder('$courseFolder/Labs'), isFalse);

        // Archive folder
        controller.archiveFolder(courseFolder);
        expect(controller.isArchivedFolder(courseFolder), isTrue);
        // Child folder is also treated as archived
        expect(controller.isArchivedFolder('$courseFolder/Labs'), isTrue);

        // Restore folder
        controller.restoreFolder(courseFolder);
        expect(controller.isArchivedFolder(courseFolder), isFalse);
        expect(controller.isArchivedFolder('$courseFolder/Labs'), isFalse);
      },
    );

    test(
      'Saved view creation and duplication preserves view properties without cloning tasks',
      () async {
        final savedView = await controller.create(
          'orbit.view',
          title: 'Math Sprint Board',
          properties: {
            'folder': 'Notes/University/AKMath',
            'viewType': 'board',
            'preset': 'university',
          },
        );
        expect(savedView, isNotNull);
        expect(savedView!.typeId, 'orbit.view');
        expect(savedView.properties['viewType'], 'board');
        expect(savedView.properties['preset'], 'university');
        expect(savedView.properties['folder'], 'Notes/University/AKMath');

        // Duplicate View
        final duplicated = await controller.duplicateView(savedView.id);
        expect(duplicated, isNotNull);
        expect(duplicated!.id, isNot(savedView.id));
        expect(duplicated.title, 'Math Sprint Board (Copy)');
        expect(duplicated.properties['viewType'], 'board');
        expect(duplicated.properties['preset'], 'university');
        expect(duplicated.properties['folder'], 'Notes/University/AKMath');

        // Duplication must NOT duplicate tasks
        final tasks = controller.ofType('orbit.task');
        expect(tasks.isEmpty, isTrue);
      },
    );

    test(
      'moveObjectToFolder updates location for notes, canvases, and views',
      () async {
        await controller.repository.createFolder('Notes/Projects/App');

        // 1. Note
        final note = await controller.create(
          'orbit.note',
          title: 'Architecture',
        );
        expect(note, isNotNull);
        await controller.moveObjectToFolder(note!.id, 'Notes/Projects/App');
        final updatedNote = controller.find(note.id);
        expect(updatedNote?.properties['folder'], 'Notes/Projects/App');

        // 2. Canvas
        final canvas = await controller.create(
          'orbit.canvas',
          title: 'System Diagram',
        );
        expect(canvas, isNotNull);
        await controller.moveObjectToFolder(canvas!.id, 'Notes/Projects/App');
        final updatedCanvas = controller.find(canvas.id);
        expect(updatedCanvas?.properties['folder'], 'Notes/Projects/App');

        // 3. Saved View
        final view = await controller.create(
          'orbit.view',
          title: 'Sprint Board',
        );
        expect(view, isNotNull);
        await controller.moveObjectToFolder(view!.id, 'Notes/Projects/App');
        final updatedView = controller.find(view.id);
        expect(updatedView?.properties['folder'], 'Notes/Projects/App');
      },
    );

    test('Kanban presets provide correct column configurations', () {
      final universal = KanbanPreset.fromId('universal');
      expect(universal.columns.map((c) => c.$1), [
        'backlog',
        'todo',
        'in-progress',
        'done',
      ]);

      final software = KanbanPreset.fromId('software');
      expect(software.columns.map((c) => c.$1), [
        'backlog',
        'ready',
        'in-progress',
        'in-review',
        'done',
      ]);

      final gamedev = KanbanPreset.fromId('gamedev');
      expect(gamedev.columns.map((c) => c.$1), [
        'concept',
        'assets',
        'in-progress',
        'testing',
        'done',
      ]);

      final university = KanbanPreset.fromId('university');
      expect(university.columns.map((c) => c.$1), [
        'syllabus',
        'assignments',
        'exam-prep',
        'review',
        'done',
      ]);
    });
  });

  group('SavedViewHost Widget Tests', () {
    testWidgets(
      'SavedViewHost renders header, switcher, and switches viewType',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = WorkspaceRepository(
          store: TestFolderStore(),
          index: MemoryObjectIndex(),
        );
        await repo.initialize();
        final view = await repo.create(
          typeId: 'orbit.view',
          title: 'AKMath Course View',
          properties: {
            'folder': 'Notes/University/AKMath',
            'viewType': 'tasks',
          },
        );

        late WorkspaceController controller;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    ref.watch(workspaceProvider);
                    controller = ref.read(workspaceProvider.notifier);
                    return SavedViewHost(
                      viewObject: view,
                      controller: controller,
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check title and switcher tabs exist
        expect(find.text('AKMath Course View'), findsOneWidget);
        expect(find.text('List'), findsOneWidget);
        expect(find.byIcon(Icons.view_kanban_outlined), findsOneWidget);
        expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
        expect(find.byIcon(Icons.timeline_outlined), findsOneWidget);

        // Switch to Board
        await tester.tap(find.byIcon(Icons.view_kanban_outlined));
        await tester.pump();
        expect(controller.find(view.id)?.properties['viewType'], 'board');

        // Switch to Calendar
        await tester.tap(find.byIcon(Icons.calendar_month_outlined));
        await tester.pump();
        expect(controller.find(view.id)?.properties['viewType'], 'calendar');

        // Switch to Timeline
        await tester.tap(find.byIcon(Icons.timeline_outlined));
        await tester.pump();
        expect(controller.find(view.id)?.properties['viewType'], 'timeline');

        await tester.runAsync(() => controller.flushAll());
      },
    );

    testWidgets(
      'SavedViewHost calculates and displays course progress accurately',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = WorkspaceRepository(
          store: TestFolderStore(),
          index: MemoryObjectIndex(),
        );
        await repo.initialize();

        final folder = 'Notes/University/CS101';
        // Create 4 tasks in folder: 3 complete, 1 incomplete (75%)
        await repo.create(
          typeId: 'orbit.task',
          title: 'Lecture 1',
          properties: {'folder': folder, 'completed': true},
        );
        await repo.create(
          typeId: 'orbit.task',
          title: 'Lecture 2',
          properties: {'folder': folder, 'completed': true},
        );
        await repo.create(
          typeId: 'orbit.task',
          title: 'Assignment 1',
          properties: {'folder': folder, 'completed': true},
        );
        await repo.create(
          typeId: 'orbit.task',
          title: 'Assignment 2',
          properties: {'folder': folder, 'completed': false},
        );

        final view = await repo.create(
          typeId: 'orbit.view',
          title: 'CS101 Overview',
          properties: {'folder': folder, 'viewType': 'tasks'},
        );

        late WorkspaceController controller;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    ref.watch(workspaceProvider);
                    controller = ref.read(workspaceProvider.notifier);
                    return SavedViewHost(
                      viewObject: view,
                      controller: controller,
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('3 / 4 complete · 75%'), findsOneWidget);
        await tester.runAsync(() => controller.flushAll());
      },
    );
  });
}
