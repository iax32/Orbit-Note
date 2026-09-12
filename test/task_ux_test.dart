import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/calendar_event.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late WorkspaceController controller;
  setUp(() async {
    final repo = WorkspaceRepository(
      store: MemoryStore(),
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
  group('Friendly due date formatting', () {
    test('formats today, tomorrow, and yesterday accurately', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 14, 30);
      final tomorrow = today.add(const Duration(days: 1));
      final yesterday = today.subtract(const Duration(days: 1));

      expect(formatFriendlyDueDate(today), 'Today');
      expect(formatFriendlyDueDate(tomorrow), 'Tomorrow');
      expect(formatFriendlyDueDate(yesterday), 'Yesterday');
    });

    test('formats distant dates with month and day', () {
      final distant = DateTime(2027, 4, 15);
      expect(formatFriendlyDueDate(distant), 'Apr 15, 2027');
    });

    test('detects overdue dates correctly', () {
      final now = DateTime.now();
      final past = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 2));
      final future = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 2));

      // Incomplete task in past is overdue
      expect(isDueDateOverdue(past, isCompleted: false), isTrue);
      // Completed task in past is NOT overdue
      expect(isDueDateOverdue(past, isCompleted: true), isFalse);
      // Incomplete task in future is NOT overdue
      expect(isDueDateOverdue(future, isCompleted: false), isFalse);
    });
  });

  group('TaskRow widget interactions', () {
    testWidgets(
      'renders title, animated checkbox, priority chip, and handles tap',
      (tester) async {
        var toggled = false;
        UniversalObject task = UniversalObject(
          workspaceId: 'test',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          id: 'task-1',
          typeId: 'orbit.task',
          title: 'Review PR #42',
          properties: {
            'completed': false,
            'priority': 'high',
            'dueDate': '2027-05-20',
          },
        );

        controller.objects = [task];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TaskRow(
                object: task,
                controller: controller,
                onCompleted: (_) => toggled = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Review PR #42'), findsOneWidget);
        expect(find.text('HIGH'), findsOneWidget);
        expect(find.text('May 20, 2027'), findsOneWidget);

        // Tap completion checkbox
        final checkboxFinder = find.byType(Checkbox);
        await tester.runAsync(() async {
          await tester.tap(checkboxFinder);
          await controller.flushAll();
        });
        await tester.pump();
        expect(toggled, isTrue);
      },
    );

    testWidgets(
      'completed task displays with strikethrough and muted styling',
      (tester) async {
        UniversalObject task = UniversalObject(
          workspaceId: 'test',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          id: 'task-done',
          typeId: 'orbit.task',
          title: 'Finished item',
          properties: {'completed': true, 'priority': 'low'},
        );

        controller.objects = [task];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TaskRow(
                object: task,
                controller: controller,
                onCompleted: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Finished item'), findsOneWidget);
        expect(
          DefaultTextStyle.of(
            tester.element(find.text('Finished item')),
          ).style.decoration,
          TextDecoration.lineThrough,
        );
      },
    );
  });

  group('TasksView saved views and filtering', () {
    testWidgets('displays view tabs (To Do, Today, Upcoming, Done, Board)', (
      tester,
    ) async {
      final tasks = [
        UniversalObject(
          workspaceId: 'test',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          id: 't1',
          typeId: 'orbit.task',
          title: 'Active task 1',
          properties: {'completed': false},
        ),
        UniversalObject(
          workspaceId: 'test',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          id: 't2',
          typeId: 'orbit.task',
          title: 'Completed task 2',
          properties: {'completed': true},
        ),
      ];

      controller.objects = tasks;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TasksView(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('To Do'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Board'), findsOneWidget);

      // Default is 'To Do' view: shows active task 1, does NOT show completed task 2
      expect(find.text('Active task 1'), findsOneWidget);
      expect(find.text('Completed task 2'), findsNothing);

      // Switch to 'Done' view tab
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Completed task 2'), findsOneWidget);
      expect(find.text('Active task 1'), findsNothing);
    });

    testWidgets('inline + New task row triggers sequential creation', (
      tester,
    ) async {
      controller.objects = [];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TasksView(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Tap + New task
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();

      // Enter task title and submit
      final inputFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.focusNode?.hasFocus == true,
      );
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'Buy milk');
      await tester.runAsync(
        () => tester.testTextInput.receiveAction(TextInputAction.done),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() => controller.flushAll());
      expect(
        controller.ofType('orbit.task').any((o) => o.title == 'Buy milk'),
        isTrue,
      );
    });

    testWidgets('switching to Board view displays Kanban columns', (
      tester,
    ) async {
      final tasks = [
        UniversalObject(
          workspaceId: 'test',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          id: 't1',
          typeId: 'orbit.task',
          title: 'Plan release',
          properties: {'completed': false, 'priority': 'high'},
        ),
        UniversalObject(
          workspaceId: 'test',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          id: 't2',
          typeId: 'orbit.task',
          title: 'Code review',
          properties: {'completed': true},
        ),
      ];

      controller.objects = tasks;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TasksView(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();

      expect(find.text('To Do'), findsWidgets);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Done'), findsWidgets);
      expect(find.text('Plan release'), findsOneWidget);
      expect(find.text('Code review'), findsOneWidget);
    });
  });
}
