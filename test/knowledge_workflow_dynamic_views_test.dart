import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/notes/rich/dynamic_view_block.dart';
import 'package:orbit_note/features/notes/rich/snapshot_block.dart';
import 'package:orbit_note/features/workspace/project_dashboard_view.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  group('DynamicViewConfig & SnapshotConfig Parsing and Serialization', () {
    test(
      'DynamicViewConfig parses YAML attributes and serializes correctly',
      () {
        const yaml = '''
type: tasks
status: completed
project: Orbit
folder: Work/Notes
period: 2026-W38
sort: title
limit: 7
title: Finished Sprint Tasks
''';
        final config = DynamicViewConfig.fromYaml(yaml);
        expect(config.type, 'tasks');
        expect(config.status, 'completed');
        expect(config.project, 'Orbit');
        expect(config.folder, 'Work/Notes');
        expect(config.period, '2026-W38');
        expect(config.sort, 'title');
        expect(config.limit, 7);
        expect(config.title, 'Finished Sprint Tasks');

        final serializedYaml = config.toYaml();
        expect(serializedYaml, contains('type: tasks'));
        expect(serializedYaml, contains('status: completed'));
        expect(serializedYaml, contains('project: Orbit'));
        expect(serializedYaml, contains('limit: 7'));

        final md = config.toMarkdown();
        expect(md.startsWith('```orbit-view\n'), isTrue);
        expect(md.endsWith('\n```'), isTrue);
      },
    );

    test(
      'DynamicViewConfig defaults gracefully for empty or unknown content',
      () {
        final config = DynamicViewConfig.fromYaml('');
        expect(config.type, 'tasks');
        expect(config.status, 'all');
        expect(config.limit, 10);
        expect(config.title, isNull);
      },
    );

    test('SnapshotConfig parses frozen items and formats to markdown', () {
      const yaml = '''
type: tasks
frozenAt: 2026-09-16T10:00:00.000Z
title: Week 38 Completed
items:
  - id: t1
    title: Fix build warning
    type: orbit.task
    isCompleted: true
    subtitle: Done today
  - id: t2
    title: Release app
    type: orbit.task
    isCompleted: false
''';
      final config = SnapshotConfig.fromYaml(yaml);
      expect(config.type, 'tasks');
      expect(config.title, 'Week 38 Completed');
      expect(config.frozenAtDateTime.year, 2026);
      expect(config.items.length, 2);
      expect(config.items[0].id, 't1');
      expect(config.items[0].title, 'Fix build warning');
      expect(config.items[0].isCompleted, isTrue);
      expect(config.items[0].subtitle, 'Done today');
      expect(config.items[1].isCompleted, isFalse);

      final md = config.toMarkdown();
      expect(md.startsWith('```orbit-snapshot\n'), isTrue);
      expect(md, contains('frozenAt:'));
      expect(md, contains('Fix build warning'));
    });
  });

  group('WorkspaceController Knowledge Workflow Methods', () {
    late MemoryStore store;
    late WorkspaceRepository repo;
    late ProviderContainer container;
    late WorkspaceController controller;

    setUp(() async {
      store = MemoryStore();
      repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      controller = container.read(workspaceProvider.notifier);
      await controller.initialize();
    });

    tearDown(() async {
      container.dispose();
    });

    test(
      'unresolvedWikiLinks detects missing targets and updates when target note is created',
      () async {
        final note1 = await controller.create(
          'orbit.note',
          title: 'Alpha Note',
          body:
              'Here is a reference to [[Unknown Concept]] and [[Second Missing]].',
        );
        final note2 = await controller.create(
          'orbit.note',
          title: 'Beta Note',
          body: 'Another link to [[Unknown Concept]].',
        );

        final unresolved = controller.unresolvedWikiLinks();
        expect(unresolved.containsKey('Unknown Concept'), isTrue);
        expect(unresolved['Unknown Concept']!.length, 2);
        expect(
          unresolved['Unknown Concept']!.map((o) => o.id),
          containsAll([note1!.id, note2!.id]),
        );
        expect(unresolved.containsKey('Second Missing'), isTrue);
        expect(unresolved['Second Missing']!.length, 1);

        // Resolve 'Unknown Concept' by creating a note with that title
        await controller.create(
          'orbit.note',
          title: 'Unknown Concept',
          body: 'Now I exist!',
        );
        final unresolvedAfter = controller.unresolvedWikiLinks();
        expect(unresolvedAfter.containsKey('Unknown Concept'), isFalse);
        expect(unresolvedAfter.containsKey('Second Missing'), isTrue);
      },
    );

    test(
      'quickCapture creates inbox items and processInboxItem organizes them',
      () async {
        final noteItem = await controller.quickCapture('Buy groceries tonight');
        expect(noteItem, isNotNull);
        expect(noteItem!.typeId, 'orbit.note');
        expect(noteItem.title, 'Buy groceries tonight');
        expect(noteItem.properties['inbox'], isTrue);

        final taskItem = await controller.quickCapture(
          'Design mockups',
          asTask: true,
        );
        expect(taskItem, isNotNull);
        expect(taskItem!.typeId, 'orbit.task');
        expect(taskItem.title, 'Design mockups');
        expect(taskItem.properties['inbox'], isTrue);

        expect(controller.inboxObjects.length, 2);

        // Process note item: assign project and folder
        await controller.processInboxItem(
          noteItem.id,
          project: 'Personal',
          folder: 'Notes/Home',
        );
        final updatedNote = controller.find(noteItem.id);
        expect(updatedNote!.properties['inbox'], isNull);
        expect(updatedNote.properties['project'], 'Personal');
        expect(updatedNote.properties['folder'], 'Notes/Home');
        expect(controller.inboxObjects.length, 1);

        // Convert remaining item or archive
        await controller.processInboxItem(taskItem.id, archive: true);
        final updatedTask = controller.find(taskItem.id);
        expect(updatedTask!.properties['inbox'], isNull);
        expect(updatedTask.properties['status'], 'archived');
        expect(controller.inboxObjects.isEmpty, isTrue);
      },
    );

    test(
      'temporal helpers query notes and tasks within date boundaries',
      () async {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = DateTime(
          now.year,
          now.month,
          now.day,
          23,
          59,
          59,
          999,
        );

        final note = await controller.create(
          'orbit.note',
          title: 'Today Note',
          properties: {'project': 'Apollo'},
        );
        final task = await controller.create(
          'orbit.task',
          title: 'Completed Task',
          properties: {
            'status': 'completed',
            'completed': true,
            'completedAt': DateTime.now().toIso8601String(),
            'project': 'Apollo',
          },
        );
        final openTask = await controller.create(
          'orbit.task',
          title: 'Open Loop',
          properties: {'status': 'open', 'project': 'Apollo'},
        );

        final notes = controller.notesCreatedBetween(todayStart, todayEnd);
        expect(notes.map((n) => n.id), contains(note!.id));

        final completed = controller.tasksCompletedBetween(
          todayStart,
          todayEnd,
        );
        expect(completed.map((t) => t.id), contains(task!.id));

        final unfinished = controller.tasksUnfinishedBetween(
          todayStart,
          todayEnd,
        );
        expect(unfinished.map((t) => t.id), contains(openTask!.id));

        final projects = controller.projectsActiveBetween(todayStart, todayEnd);
        expect(projects, contains('Apollo'));
      },
    );

    test(
      'openTodayNote creates daily note with date title and embedded dynamic view',
      () async {
        final date = DateTime(2026, 9, 16);
        final dailyNote = await controller.openTodayNote(date: date);
        expect(dailyNote, isNotNull);
        expect(dailyNote!.title, '2026-09-16');
        expect(dailyNote.properties['dailyDate'], '2026-09-16');
        expect(dailyNote.body, contains('```orbit-view'));
        expect(dailyNote.body, contains('type: tasks'));

        // Reopening returns the same note
        final reopened = await controller.openTodayNote(date: date);
        expect(reopened!.id, dailyNote.id);
      },
    );

    test(
      'openReviewNote creates periodic review note and opens existing if available',
      () async {
        final reviewNote = await controller.openReviewNote(
          periodName: '2026-W38',
          title: 'Weekly Review - 2026-W38',
          initialBody: '# Weekly Review\n\n```orbit-view\ntype: tasks\n```',
        );
        expect(reviewNote, isNotNull);
        expect(reviewNote!.title, 'Weekly Review - 2026-W38');
        expect(reviewNote.properties['reviewPeriod'], '2026-W38');

        // Calling again returns existing review note
        final existing = await controller.openReviewNote(
          periodName: '2026-W38',
          title: 'Weekly Review - 2026-W38',
          initialBody: 'Different body',
        );
        expect(existing!.id, reviewNote.id);
        expect(existing.body, contains('Weekly Review'));
      },
    );
  });

  group('Dynamic Views & Snapshots UI Widgets', () {
    testWidgets(
      'DynamicViewBlock renders tasks and toggles completion directly',
      (tester) async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );

        String? updatedMarkdown;
        const yaml = 'type: tasks\nstatus: all\n';

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    final c = ref.watch(workspaceProvider.notifier);
                    return DynamicViewBlock(
                      source: yaml,
                      controller: c,
                      onChanged: (newText) => updatedMarkdown = newText,
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DynamicViewBlock)),
        );
        final c = container.read(workspaceProvider.notifier);

        final task = await c.create(
          'orbit.task',
          title: 'Live Task Item',
          properties: {'status': 'open'},
        );
        await tester.pumpAndSettle();

        expect(find.text('Live Task Item'), findsOneWidget);
        final checkboxFinder = find.byType(Checkbox);
        expect(checkboxFinder, findsOneWidget);

        // Check the task
        await tester.tap(checkboxFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await c.flushAll();

        final updatedTask = c.find(task!.id);
        expect(updatedTask!.isCompleted, isTrue);

        // Tap Freeze as Snapshot button
        final freezeBtn = find.byIcon(Icons.lock_clock_outlined);
        expect(freezeBtn, findsOneWidget);
        await tester.tap(freezeBtn);
        await tester.pump();
        expect(updatedMarkdown, isNotNull);
        expect(updatedMarkdown, contains('```orbit-snapshot'));
      },
    );

    testWidgets(
      'SnapshotBlock renders static items and allows restoring live view',
      (tester) async {
        const yaml = '''
type: tasks
frozenAt: 2026-09-16T12:00:00.000Z
title: Frozen Sprint
items:
  - text: Fixed Bug #42
    completed: true
''';
        String? restoredMarkdown;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SnapshotBlock(
                source: yaml,
                onChanged: (newText) => restoredMarkdown = newText,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Frozen Sprint'), findsOneWidget);
        expect(find.text('Fixed Bug #42'), findsOneWidget);
        expect(find.textContaining('Frozen ·'), findsOneWidget);

        // Tap Restore
        final restoreBtn = find.text('Restore Live View');
        expect(restoreBtn, findsOneWidget);
        await tester.tap(restoreBtn);
        await tester.pump();
        expect(restoredMarkdown, isNotNull);
        expect(restoredMarkdown, contains('```orbit-view'));
      },
    );

    testWidgets('ProjectDashboardView renders metrics, tasks and notes', (
      tester,
    ) async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final c = ref.watch(workspaceProvider.notifier);
                  return ProjectDashboardView(
                    controller: c,
                    projectName: 'MissionX',
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProjectDashboardView)),
      );
      final c = container.read(workspaceProvider.notifier);

      await c.create(
        'orbit.task',
        title: 'Project Task 1',
        properties: {'project': 'MissionX', 'status': 'open'},
      );
      await c.create(
        'orbit.note',
        title: 'Mission Briefing',
        properties: {'project': 'MissionX'},
      );
      await c.flushAll();
      await tester.pumpAndSettle();

      expect(find.text('MissionX'), findsOneWidget);
      expect(find.text('Project Task 1'), findsWidgets);
      expect(find.text('Mission Briefing'), findsWidgets);
      expect(find.text('0 / 1 completed (0%)'), findsOneWidget);
    });

    testWidgets('HomeView renders temporal navigation bar and quick capture', (
      tester,
    ) async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final c = ref.watch(workspaceProvider.notifier);
                  return HomeView(controller: c);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigation bar and zoom options are present
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('Quarter'), findsOneWidget);
      expect(find.text('Year'), findsOneWidget);

      // Quick capture input
      final captureInput = find.byType(TextField);
      expect(captureInput, findsOneWidget);

      // Switch to Week zoom
      await tester.tap(find.text('Week'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Metric tiles for periodic review
      expect(find.text('Notes Created'), findsOneWidget);
      expect(find.text('Tasks Completed'), findsOneWidget);
      expect(find.text('Unfinished Tasks'), findsOneWidget);
      expect(find.text('Active Projects'), findsOneWidget);
      expect(find.text('Weekly Review Note'), findsWidgets);
    });
  });
}
