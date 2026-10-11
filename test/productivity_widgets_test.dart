import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/smart_view_query.dart';
import 'package:orbit_note/features/notes/rich/dynamic_view_block.dart';
import 'package:orbit_note/features/workspace/productivity_hub.dart';
import 'package:orbit_note/features/workspace/smart_view_surface.dart';
import 'package:orbit_note/features/workspace/task_planning_panel.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  late ProviderContainer container;
  late WorkspaceController c;
  Future<void> initialize(WidgetTester tester) async {
    await tester.runAsync(() async {
      container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(
            WorkspaceRepository(
              store: MemoryStore(),
              index: MemoryObjectIndex(),
            ),
          ),
        ],
      );
      container.read(workspaceProvider);
      c = container.read(workspaceProvider.notifier);
      await c.initialize();
    });
    addTearDown(container.dispose);
  }

  Future<void> pump(
    WidgetTester tester,
    Widget Function(BuildContext) content, {
    double scale = 1,
    Size size = const Size(1000, 800),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(
              ctx,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Consumer(
              builder: (ctx, ref, _) {
                ref.watch(workspaceProvider);
                return content(ctx);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester,
    Future<void> Function(BuildContext) dialog, {
    double scale = 1,
    Size size = const Size(1000, 800),
  }) async {
    await pump(
      tester,
      (ctx) =>
          TextButton(onPressed: () => dialog(ctx), child: const Text('Open')),
      scale: scale,
      size: size,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'visual query builder cancels without mutation and saves a shared definition',
    (tester) async {
      await initialize(tester);
      final note = (await tester.runAsync(
        () => c.create('orbit.note', title: 'Needle'),
      ))!;
      final view = (await tester.runAsync(
        () => c.create(
          'orbit.view',
          title: 'Sources',
          properties: {
            'smartQuery': SmartViewQuery.empty(),
            'viewType': 'table',
          },
        ),
      ))!;
      await open(tester, (ctx) => showSmartQueryBuilder(ctx, c, view));
      await tester.tap(find.text('Add filter'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Value'),
        'Needle',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        (c.find(view.id)!.properties['smartQuery'] as Map)['rules'],
        isEmpty,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add filter'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Value'),
        'Needle',
      );
      await tester.tap(find.text('Apply filters'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(c.queryViewObjects(c.find(view.id)!).map((o) => o.id), [note.id]);
      expect(find.text('Apply filters'), findsNothing);
    },
  );

  testWidgets(
    'table builds only visible rows and edits canonical typed properties',
    (tester) async {
      await initialize(tester);
      await tester.runAsync(() async {
        for (var i = 0; i < 120; i++) {
          await c.create(
            'orbit.note',
            title: 'Item ${i.toString().padLeft(3, '0')}',
            properties: {'ects': 5},
          );
        }
      });
      final view = (await tester.runAsync(
        () => c.create(
          'orbit.view',
          title: 'Courses',
          properties: {
            'viewType': 'table',
            'smartQuery': {
              ...SmartViewQuery.empty(),
              'sort': 'title',
              'descending': false,
              'columns': ['title', 'ects'],
            },
          },
        ),
      ))!;
      await pump(tester, (_) => SmartViewSurface(controller: c, view: view));
      expect(find.text('Item 000'), findsOneWidget);
      expect(find.text('Item 119'), findsNothing);
      await tester.tap(find.text('5').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '7');
      await tester.tap(find.text('Save'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        c
            .ofType('orbit.note')
            .firstWhere((o) => o.title == 'Item 000')
            .properties['ects'],
        7,
      );
      expect(find.text('7'), findsOneWidget);
    },
  );

  testWidgets(
    'board exposes empty status destinations and moves the original task with undo',
    (tester) async {
      await initialize(tester);
      final task = (await tester.runAsync(
        () => c.create(
          'orbit.task',
          title: 'Ship',
          properties: {'status': 'todo'},
        ),
      ))!;
      final view = (await tester.runAsync(
        () => c.create(
          'orbit.view',
          title: 'Plan',
          properties: {
            'viewType': 'board',
            'smartQuery': {
              ...SmartViewQuery.empty(),
              'rules': [
                {'field': 'typeId', 'op': 'equals', 'value': 'orbit.task'},
              ],
            },
          },
        ),
      ))!;
      await pump(tester, (_) => SmartViewSurface(controller: c, view: view));
      expect(find.text('done · 0'), findsOneWidget);
      await tester.dragFrom(
        tester.getCenter(find.text('Ship')),
        const Offset(560, 10),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(c.find(task.id)!.isCompleted, true);
      expect(c.ofType('orbit.task').length, 1);
      final undo = c.undoPlanning();
      await tester.pumpAndSettle();
      expect(await undo, true);
      await tester.pumpAndSettle();
      expect(c.find(task.id)!.isCompleted, false);
    },
  );

  testWidgets(
    'note embed inherits shared ordering and reflects canonical title changes',
    (tester) async {
      await initialize(tester);
      final a = (await tester.runAsync(
        () => c.create('orbit.note', title: 'Alpha'),
      ))!;
      await tester.runAsync(() => c.create('orbit.note', title: 'Zulu'));
      final view = (await tester.runAsync(
        () => c.create(
          'orbit.view',
          title: 'Shared',
          properties: {
            'smartQuery': {
              ...SmartViewQuery.empty(),
              'sort': 'title',
              'descending': false,
            },
          },
        ),
      ))!;
      await pump(
        tester,
        (_) => ListView(
          children: [
            DynamicViewBlock(
              source: DynamicViewConfig(
                type: 'table',
                viewId: view.id,
              ).toYaml(),
              onChanged: (_) {},
            ),
          ],
        ),
      );
      expect(
        tester.getTopLeft(find.text('Alpha')).dy,
        lessThan(tester.getTopLeft(find.text('Zulu')).dy),
      );
      c.edit(a.id, title: 'Beta');
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'reschedule preview cancel is inert; Move changes only the selected field',
    (tester) async {
      await initialize(tester);
      final task = (await tester.runAsync(
        () => c.create(
          'orbit.task',
          title: 'Lab',
          properties: {'dueDate': '2026-10-10', 'scheduledDate': '2026-10-09'},
        ),
      ))!;
      await open(
        tester,
        (ctx) => previewCalendarMove(
          ctx,
          c,
          CalendarDragData(task, 'dueDate'),
          DateTime(2026, 10, 15),
        ),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.find(task.id)!.properties['dueDate'], '2026-10-10');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(c.find(task.id)!.properties['dueDate'], '2026-10-15');
      expect(c.find(task.id)!.properties['scheduledDate'], '2026-10-09');
    },
  );

  for (final (size, scale) in [
    (const Size(320, 640), 2.5),
    (const Size(568, 320), 1.0),
  ]) {
    testWidgets(
      'productivity dialogs and dashboard fit $size at scale $scale',
      (tester) async {
        await initialize(tester);
        final task = (await tester.runAsync(
          () => c.create(
            'orbit.task',
            title: 'A long research planning task',
            properties: {'dueDate': '2026-10-10'},
          ),
        ))!;
        await tester.runAsync(
          () => c.saveContext(name: 'Research workspace with a long name'),
        );
        await open(
          tester,
          (ctx) => showSpaceManager(ctx, c),
          size: size,
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await open(
          tester,
          (ctx) => showDashboardEditor(ctx, c),
          size: size,
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await open(
          tester,
          (ctx) => showTaskPlanningDialog(ctx, c, task),
          size: size,
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        final view = (await tester.runAsync(
          () => c.create(
            'orbit.view',
            title: 'Research sources',
            properties: {
              'smartQuery': SmartViewQuery.empty(),
              'viewType': 'table',
            },
          ),
        ))!;
        await open(
          tester,
          (ctx) => showSmartQueryBuilder(ctx, c, view),
          size: size,
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await pump(
          tester,
          (_) => SmartViewSurface(controller: c, view: view),
          size: size,
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        c.updateSession(
          (s) => s.dashboard = {
            'version': 1,
            'widgets': [
              {'id': 't', 'kind': 'tasks', 'span': 3},
            ],
          },
        );
        await tester.pumpAndSettle();
        await pump(
          tester,
          (_) => ListView(children: [ProductivityDashboard(controller: c)]),
          size: size,
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        c.cancelAllTimers();
      },
    );
  }
}
