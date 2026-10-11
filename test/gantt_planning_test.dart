import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/gantt_planning.dart';
import 'package:orbit_note/domain/calendar_event.dart';
import 'package:orbit_note/domain/smart_view_query.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/gantt_view.dart';
import 'package:orbit_note/features/notes/rich/dynamic_view_block.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/memory_store.dart';

UniversalObject task(String id, Map<String, dynamic> properties) =>
    UniversalObject(
      id: id,
      workspaceId: 'vault',
      typeId: 'orbit.task',
      title: id,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      properties: properties,
    );

class GanttStore extends NativeWorkspaceStore {
  GanttStore(this.root);
  final String root;
  @override
  Future<void> initialize({String? path}) =>
      super.initialize(path: path ?? root);
}

Future<(ProviderContainer, WorkspaceController)> setup(
  WorkspaceRepository repo,
) async {
  final container = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(repo)],
  );
  final c = container.read(workspaceProvider.notifier);
  for (var i = 0; i < 300 && c.loading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(c.loading, false);
  return (container, c);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'calendar-day moves preserve duration across clock changes and deadlines',
    () {
      final original = task('work', {
        'scheduledDate': '2026-03-28',
        'scheduledEndDate': '2026-03-30',
        'dueDate': '2026-04-05',
      });
      final plan = GanttTask(original);
      expect(plan.duration, 3);
      final changes = plan.shiftedTo(DateTime(2026, 10, 24));
      expect(changes, {
        'scheduledDate': '2026-10-24',
        'scheduledEndDate': '2026-10-26',
      });
      expect(changes.containsKey('dueDate'), false);
      expect(
        GanttTask(task('deadline', {'dueDate': '2026-05-01'})).valid,
        false,
      );
    },
  );
  test('dependency suggestions need explicit live blocker ranges', () {
    final a = task('a', {
      'scheduledDate': '2026-10-01',
      'scheduledEndDate': '2026-10-04',
    });
    final b = task('b', {
      'scheduledDate': '2026-10-03',
      'blockedBy': ['a'],
      'dueDate': '2026-10-02',
    });
    final plan = GanttTask(b);
    expect(plan.afterBlockers({'a': a}), DateTime.utc(2026, 10, 5));
    expect(
      plan.warnings({'a': a}),
      contains('Starts before blocker finishes: a'),
    );
    expect(plan.warnings({'a': a}), contains('Finishes after deadline'));
    expect(plan.afterBlockers({}), isNull);
    expect(
      plan.warnings({}).singleWhere((s) => s.startsWith('Missing')),
      contains('a'),
    );
    expect(
      plan.afterBlockers({
        'a': a.copyWith(properties: {'completed': true}),
      }),
      isNull,
    );
    expect(
      plan.warnings({'a': a.copyWith(properties: {})}),
      contains('Unscheduled blocker: a'),
    );
  });
  test(
    'invalid legacy ranges remain visible; scheduling rejects invalid dates',
    () {
      for (final p in [
        {'scheduledDate': '2026-02-30'},
        {'scheduledEndDate': '2026-01-01'},
        {'scheduledDate': '2026-02-02', 'scheduledEndDate': '2026-02-01'},
        {'scheduledDate': '2026-02-01', 'scheduledEndDate': 'bad'},
        {
          'scheduledDate': '2026-02-01',
          'scheduledEndDate': '2026-02-02',
          'ganttMilestone': true,
        },
      ]) {
        expect(GanttTask(task('bad', p)).valid, false);
        expect(GanttTask(task('bad', p)).warnings({}), isNotEmpty);
        expect(() => validateGanttSchedule(p), throwsFormatException);
      }
      expect(
        () => validateGanttSchedule({
          'scheduledDate': '2026-02-01',
          'ganttMilestone': true,
        }),
        returnsNormally,
      );
    },
  );
  test(
    'imported cycles stay visible and never produce scheduling suggestions',
    () {
      final a = task('a', {
        'blockedBy': ['b'],
        'scheduledDate': '2026-10-01',
      });
      final b = task('b', {
        'blockedBy': ['a'],
        'scheduledDate': '2026-10-02',
      });
      expect(
        GanttTask(a).warnings({'a': a, 'b': b}),
        contains('Dependency cycle needs review'),
      );
      expect(GanttTask(a).afterBlockers({'a': a, 'b': b}), isNull);
    },
  );
  test(
    'date commands reject stale edits, cycles and invalid ranges; undo protects newer work',
    () async {
      final store = FolderMemoryStore();
      final (container, c) = await setup(
        WorkspaceRepository(store: store, index: MemoryObjectIndex()),
      );
      try {
        final a = (await c.create(
          'orbit.task',
          title: 'A',
          properties: {
            'scheduledDate': '2026-10-01',
            'scheduledEndDate': '2026-10-03',
            'dueDate': '2026-10-20',
            'custom': {'unknown': true},
          },
        ))!;
        final b = (await c.create('orbit.task', title: 'B'))!;
        expect(
          await c.configureTask(a, {
            'blockedBy': [b.id],
          }),
          true,
        );
        expect(
          await c.configureTask(b, {
            'blockedBy': [a.id],
          }),
          false,
        );
        expect(
          await c.configureTask(c.find(a.id)!, {
            'scheduledEndDate': '2026-09-30',
          }),
          false,
        );
        expect(
          await c.rescheduleObject(c.find(a.id)!, DateTime(2026, 10, 10)),
          true,
        );
        expect(c.find(a.id)!.properties['scheduledEndDate'], '2026-10-12');
        expect(c.find(a.id)!.properties['dueDate'], '2026-10-20');
        expect(c.find(a.id)!.properties['custom'], {'unknown': true});
        expect(await c.undoPlanning(), true);
        expect(c.find(a.id)!.properties['scheduledDate'], '2026-10-01');
        expect(
          await c.configureTask(a, {'scheduledDate': '2026-10-02'}),
          false,
        );
        expect(
          await c.rescheduleObject(c.find(a.id)!, DateTime(2026, 10, 11)),
          true,
        );
        c.edit(a.id, title: 'Newer title');
        expect(await c.undoPlanning(), false);
        await c.flush(a.id);
        expect(c.find(a.id)!.title, 'Newer title');
        final before = c.find(a.id)!;
        store.failWrites = true;
        expect(
          await c.configureTask(before, {'scheduledEndDate': '2026-10-15'}),
          false,
        );
        expect(
          c.find(a.id)!.properties['scheduledEndDate'],
          before.properties['scheduledEndDate'],
        );
        store.failWrites = false;
      } finally {
        container.dispose();
        await c.repository.close();
      }
    },
  );
  test(
    'native restart retains saved scope, ranges, relations and unknown data',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-gantt-');
      String id = '', viewId = '', blockerId = '';
      var pair = await setup(
        WorkspaceRepository(
          store: GanttStore(root.path),
          index: MemoryObjectIndex(),
        ),
      );
      try {
        final c = pair.$2;
        final blocker = (await c.create(
          'orbit.task',
          title: 'Blocker',
          properties: {'project': 'demo'},
        ))!;
        blockerId = blocker.id;
        final a = (await c.create(
          'orbit.task',
          title: 'Work',
          properties: {
            'project': 'demo',
            'unknown': {
              'nested': [1, 2],
            },
          },
        ))!;
        id = a.id;
        expect(
          await c.configureTask(a, {
            'scheduledDate': '2026-10-01',
            'scheduledEndDate': '2026-10-06',
            'blockedBy': [blocker.id],
          }),
          true,
        );
        viewId = (await c.create(
          'orbit.view',
          title: 'Gantt',
          properties: {
            'viewType': 'gantt',
            'ganttVersion': 1,
            'scope': 'demo',
            'ganttDays': 56,
            'future': {'preserved': true},
          },
        ))!.id;
        pair.$1.dispose();
        await c.repository.close();
        pair = await setup(
          WorkspaceRepository(
            store: GanttStore(root.path),
            index: MemoryObjectIndex(),
          ),
        );
        expect(pair.$2.find(id)!.properties['scheduledEndDate'], '2026-10-06');
        expect(pair.$2.find(id)!.properties['blockedBy'], [blockerId]);
        expect(pair.$2.find(id)!.properties['unknown'], {
          'nested': [1, 2],
        });
        expect(pair.$2.find(viewId)!.properties['future'], {'preserved': true});
        expect(pair.$2.find(viewId)!.properties['scope'], 'demo');
      } finally {
        pair.$1.dispose();
        await pair.$2.repository.close();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'assignment editing cannot invert a Gantt range; unrelated legacy metadata remains editable',
    () async {
      final (container, c) = await setup(
        WorkspaceRepository(
          store: FolderMemoryStore(),
          index: MemoryObjectIndex(),
        ),
      );
      try {
        final a = (await c.create(
          'orbit.task',
          title: 'Assignment',
          properties: {
            'scheduledDate': '2026-10-01',
            'scheduledEndDate': '2026-10-03',
            'dueDate': '2026-10-20',
          },
        ))!;
        final saved = await c.saveCalendarPlan(
          original: a,
          title: 'Assignment',
          body: '',
          kind: 'assignment',
          course: 'course',
          dates: {'scheduledDate': '2026-10-10', 'dueDate': '2026-10-20'},
        );
        expect(saved, isNull);
        expect(c.find(a.id)!.properties['scheduledDate'], '2026-10-01');
        final legacy = (await c.create(
          'orbit.task',
          title: 'Imported',
          properties: {
            'scheduledDate': '2026-10-01',
            'scheduledEndDate': 'unsupported',
            'dueDate': '2026-10-20',
            'unknown': 42,
          },
        ))!;
        final repairedTitle = await c.saveCalendarPlan(
          original: legacy,
          title: 'Renamed',
          body: '',
          kind: 'assignment',
          course: 'course',
          dates: {'scheduledDate': '2026-10-01', 'dueDate': '2026-10-21'},
        );
        expect(repairedTitle, isNotNull);
        expect(repairedTitle!.properties['scheduledEndDate'], 'unsupported');
        expect(repairedTitle.properties['unknown'], 42);
      } finally {
        container.dispose();
        await c.repository.close();
      }
    },
  );
  testWidgets('Gantt and scheduling form fit narrow panes with large text', (
    tester,
  ) async {
    final pair = (await tester.runAsync(
      () => setup(
        WorkspaceRepository(
          store: FolderMemoryStore(),
          index: MemoryObjectIndex(),
        ),
      ),
    ))!;
    final (container, c) = pair;
    final t = (await tester.runAsync(
      () => c.create(
        'orbit.task',
        title: 'A long project task with a meaningful title',
        properties: {
          'scheduledDate': '2026-10-01',
          'scheduledEndDate': '2026-10-02',
        },
      ),
    ))!;
    final view = (await tester.runAsync(
      () => c.create(
        'orbit.view',
        title: 'Project Gantt',
        properties: {'viewType': 'gantt', 'ganttDays': 28.0},
      ),
    ))!;
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget app(Widget child) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, body) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2.5)),
          child: body!,
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpWidget(app(GanttView(controller: c, view: view)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final ctx = tester.element(find.byType(GanttView));
    showGanttScheduleDialog(ctx, c, t);
    await tester.pumpAndSettle();
    expect(find.text('Save schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      app(
        DynamicViewBlock(
          source: 'view: ${view.id}',
          onChanged: (_) {},
          controller: c,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GanttView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets(
    'scoped views and Smart filters share task identity; dragging previews without saving',
    (tester) async {
      final pair = (await tester.runAsync(
        () => setup(
          WorkspaceRepository(
            store: FolderMemoryStore(),
            index: MemoryObjectIndex(),
          ),
        ),
      ))!;
      final (container, c) = pair;
      final today = calendarDate(DateTime.now());
      final a = (await tester.runAsync(
        () => c.create(
          'orbit.task',
          title: 'Included work',
          properties: {
            'scheduledDate': today,
            'project': 'demo',
            'folder': 'Notes/Project',
          },
        ),
      ))!;
      await tester.runAsync(
        () => c.create(
          'orbit.task',
          title: 'Other project',
          properties: {'project': 'other', 'folder': 'Notes/Project'},
        ),
      );
      await tester.runAsync(
        () => c.create(
          'orbit.task',
          title: 'Other folder',
          properties: {'project': 'demo', 'folder': 'Notes/Elsewhere'},
        ),
      );
      final view = (await tester.runAsync(
        () => c.create(
          'orbit.view',
          title: 'Scoped',
          properties: {
            'viewType': 'gantt',
            'scope': 'demo',
            'folder': 'Notes/Project',
          },
        ),
      ))!;
      Widget app(UniversalObject v) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: GanttView(controller: c, view: v),
          ),
        ),
      );
      await tester.pumpWidget(app(view));
      await tester.pumpAndSettle();
      expect(find.text('Included work'), findsOneWidget);
      expect(find.text('Other project'), findsNothing);
      expect(find.text('Other folder'), findsNothing);
      await tester.drag(find.text('1d'), const Offset(72, 0));
      await tester.pumpAndSettle();
      expect(find.text('Save schedule'), findsOneWidget);
      expect(c.find(a.id)!.properties['scheduledDate'], today);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.find(a.id)!.properties['scheduledDate'], today);
      final query = SmartViewQuery.empty()
        ..['rules'] = [
          {'field': 'title', 'op': 'contains', 'value': 'Other folder'},
        ];
      c.edit(view.id, properties: {'viewType': 'gantt', 'smartQuery': query});
      await tester.pumpAndSettle();
      expect(find.text('Other folder'), findsOneWidget);
      expect(find.text('Included work'), findsNothing);
      c.edit(
        view.id,
        properties: {
          'viewType': 'gantt',
          'ganttVersion': 99,
          'unknown': 'preserved',
        },
      );
      await tester.pumpAndSettle();
      expect(
        find.text('This Gantt definition is unsupported and preserved.'),
        findsOneWidget,
      );
      expect(c.find(view.id)!.properties['unknown'], 'preserved');
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
