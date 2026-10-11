import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/gantt_planning.dart';
import 'package:orbit_note/domain/working_calendar.dart';
import 'package:orbit_note/features/workspace/gantt_view.dart';
import 'package:orbit_note/features/workspace/working_calendar_dialog.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'gantt_planning_test.dart' as helpers;
import 'support/memory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('work weeks, holidays and extra shifts calculate both directions', () {
    final cal = WorkingCalendar({
      ...WorkingCalendar.standard(),
      'exceptions': {
        '2026-10-12': {'working': false, 'label': 'Holiday'},
        '2026-10-17': {'working': true, 'label': 'Extra shift'},
      },
    });
    expect(cal.label(DateTime.utc(2026, 10, 12)), 'Holiday');
    expect(workingRange(DateTime(2026, 10, 10), 2, cal), {
      'scheduledDate': '2026-10-13',
      'scheduledEndDate': '2026-10-14',
    });
    expect(workingRange(DateTime(2026, 10, 18), 2, cal, backwards: true), {
      'scheduledDate': '2026-10-16',
      'scheduledEndDate': '2026-10-17',
    });
    expect(cal.count(DateTime(2026, 10, 9), DateTime(2026, 10, 18)), 6);
    final alternative = WorkingCalendar({
      'version': 1,
      'weekdays': [7, 1, 2, 3, 4],
    });
    expect(alternative.next(DateTime(2026, 10, 9)), DateTime.utc(2026, 10, 11));
  });
  test('civil dates preserve effort across leap days and clock changes', () {
    final cal = WorkingCalendar(WorkingCalendar.standard());
    expect(cal.count(DateTime(2026, 3, 27), DateTime(2026, 3, 30)), 2);
    expect(cal.count(DateTime(2026, 10, 23), DateTime(2026, 10, 26)), 2);
    expect(
      workingRange(DateTime(2028, 2, 28), 3, cal)['scheduledEndDate'],
      '2028-03-01',
    );
    expect(workingRange(DateTime(2026, 10, 10), 10, cal, milestone: true), {
      'scheduledDate': '2026-10-12',
      'scheduledEndDate': '2026-10-12',
    });
  });
  test('unsupported definitions and excessive ranges fail visibly', () {
    for (final data in [
      {
        'version': 2,
        'weekdays': [1],
      },
      {'version': 1, 'weekdays': []},
      {
        'version': 1,
        'weekdays': [1, 1],
      },
      {
        'version': 1,
        'weekdays': [8],
      },
      {
        'version': 1,
        'weekdays': [1.0],
      },
      {
        ...WorkingCalendar.standard(),
        'exceptions': {
          '2026-02-30': {'working': false},
        },
      },
      {
        ...WorkingCalendar.standard(),
        'exceptions': {
          '2026-10-10': {'working': 'false'},
        },
      },
    ]) {
      expect(() => WorkingCalendar(data), throwsFormatException);
    }
    final cal = WorkingCalendar(WorkingCalendar.standard());
    expect(
      () => cal.count(DateTime(2026), DateTime(2025)),
      throwsFormatException,
    );
    expect(() => cal.boundary(DateTime(2026), 3661), throwsFormatException);
    expect(() => resolveWorkingCalendar('missing', {}), throwsFormatException);
  });
  test(
    'moves, calendar edits, stale saves, failures and undo retain task intent',
    () async {
      final store = FolderMemoryStore();
      final (container, c) = await helpers.setup(
        WorkspaceRepository(store: store, index: MemoryObjectIndex()),
      );
      try {
        final cal = (await c.saveWorkingCalendar(
          title: 'Studio',
          definition: WorkingCalendar.standard(),
        ))!;
        final task = (await c.create(
          'orbit.task',
          title: 'Build',
          properties: {
            'scheduledDate': '2026-10-09',
            'scheduledEndDate': '2026-10-12',
            'workCalendarId': cal.id,
            'workDurationDays': 2,
            'dueDate': '2026-10-30',
          },
        ))!;
        final move = workingMove(
          task,
          DateTime(2026, 10, 10),
          c.planningObjects,
        );
        expect(move['scheduledDate'], '2026-10-12');
        expect(move['scheduledEndDate'], '2026-10-13');
        expect(move.containsKey('dueDate'), false);
        expect(
          await c.saveWorkingSchedule(task, move, expectedCalendar: cal),
          true,
        );
        expect(c.find(task.id)!.properties['dueDate'], '2026-10-30');
        expect(await c.undoPlanning(), true);
        expect(c.find(task.id)!.properties['scheduledDate'], '2026-10-09');
        final updated = (await c.saveWorkingCalendar(
          previous: cal,
          title: 'Studio',
          definition: {
            ...WorkingCalendar.standard(),
            'exceptions': {
              '2026-10-12': {'working': false},
            },
          },
        ))!;
        final current = c.find(task.id)!;
        expect(current.properties['scheduledEndDate'], '2026-10-12');
        expect(
          workingWarnings(GanttTask(current), c.planningObjects),
          contains('Range no longer matches the saved working effort'),
        );
        expect(
          await c.saveWorkingSchedule(current, move, expectedCalendar: cal),
          false,
        );
        store.failWrites = true;
        expect(
          await c.saveWorkingSchedule(
            current,
            workingMove(current, DateTime(2026, 10, 13), c.planningObjects),
            expectedCalendar: updated,
          ),
          false,
        );
        expect(c.find(task.id)!.properties['scheduledDate'], '2026-10-09');
        store.failWrites = false;
        expect(
          await c.configureTask(current, {
            'scheduledDate': '2026-10-10',
            'scheduledEndDate': '2026-10-11',
          }),
          false,
        );
        expect(
          await c.configureTask(current, {
            'workCalendarId': null,
            'workDurationDays': null,
          }),
          true,
        );
        expect(
          workingMove(
            c.find(task.id)!,
            DateTime(2026, 10, 10),
            c.planningObjects,
          )['scheduledEndDate'],
          '2026-10-13',
        );
      } finally {
        container.dispose();
      }
    },
  );
  test(
    'shared bindings and unknown calendar data survive native restart',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-work-calendar-',
      );
      var pair = await helpers.setup(
        WorkspaceRepository(
          store: helpers.GanttStore(root.path),
          index: MemoryObjectIndex(),
        ),
      );
      try {
        final c = pair.$2;
        final cal = (await c.saveWorkingCalendar(
          title: 'Team',
          definition: {
            ...WorkingCalendar.standard(),
            'future': {'keep': true},
            'exceptions': {
              '2026-10-12': {
                'working': false,
                'label': 'Break',
                'unknown': [1, 2],
              },
            },
          },
        ))!;
        final task = (await c.create(
          'orbit.task',
          title: 'Work',
          properties: {
            'workCalendarId': cal.id,
            'workDurationDays': 2,
            'scheduledDate': '2026-10-13',
            'scheduledEndDate': '2026-10-14',
          },
        ))!;
        final views = [
          for (var i = 0; i < 2; i++)
            (await c.create(
              'orbit.view',
              title: 'Timeline $i',
              properties: {'viewType': 'gantt', 'ganttVersion': 1},
            ))!,
        ];
        for (final view in views) {
          expect(await c.assignGanttCalendar(view, cal.id), true);
        }
        pair.$1.dispose();
        await c.repository.close();
        pair = await helpers.setup(
          WorkspaceRepository(
            store: helpers.GanttStore(root.path),
            index: MemoryObjectIndex(),
          ),
        );
        expect(
          pair.$2.find(cal.id)!.properties['workingCalendar'],
          cal.properties['workingCalendar'],
        );
        expect(pair.$2.find(task.id)!.properties['workCalendarId'], cal.id);
        for (final view in views) {
          expect(pair.$2.find(view.id)!.properties['workCalendarId'], cal.id);
        }
      } finally {
        pair.$1.dispose();
        await pair.$2.repository.close();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'missing calendar blocks scheduling but permits unrelated task edits',
    () async {
      final (container, c) = await helpers.setup(
        WorkspaceRepository(
          store: FolderMemoryStore(),
          index: MemoryObjectIndex(),
        ),
      );
      try {
        final task = (await c.create(
          'orbit.task',
          title: 'Imported',
          properties: {
            'workCalendarId': 'missing',
            'scheduledDate': '2026-10-09',
            'completed': false,
          },
        ))!;
        expect(
          await c.configureTask(task, {'scheduledDate': '2026-10-12'}),
          false,
        );
        expect(await c.configureTask(task, {'completed': true}), true);
        expect(c.find(task.id)!.properties['workCalendarId'], 'missing');
        expect(
          workingWarnings(GanttTask(c.find(task.id)!), c.planningObjects),
          isNotEmpty,
        );
      } finally {
        container.dispose();
      }
    },
  );
  testWidgets(
    'schedule controls calculate and persist a reviewed working range',
    (tester) async {
      final pair = (await tester.runAsync(
        () => helpers.setup(
          WorkspaceRepository(
            store: FolderMemoryStore(),
            index: MemoryObjectIndex(),
          ),
        ),
      ))!;
      final c = pair.$2;
      final cal = (await tester.runAsync(
        () => c.saveWorkingCalendar(
          title: 'Week',
          definition: WorkingCalendar.standard(),
        ),
      ))!;
      final task = (await tester.runAsync(
        () => c.create(
          'orbit.task',
          title: 'Build',
          properties: {
            'scheduledDate': '2026-10-09',
            'scheduledEndDate': '2026-10-12',
            'dueDate': '2026-10-20',
          },
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showGanttScheduleDialog(
                  context,
                  c,
                  task,
                  defaultCalendarId: cal.id,
                ),
                child: const Text('Schedule'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Plan back from deadline'));
      await tester.tap(find.text('Plan back from deadline'));
      await tester.pumpAndSettle();
      final dates = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((f) => f.controller!.text)
          .toList();
      expect(dates, containsAll(['2026-10-19', '2026-10-20']));
      await tester.ensureVisible(find.text('Save schedule'));
      await tester.runAsync(() => tester.tap(find.text('Save schedule')));
      await tester.pumpAndSettle();
      expect(c.find(task.id)!.properties['workCalendarId'], cal.id);
      expect(c.find(task.id)!.properties['workDurationDays'], 2);
      expect(c.find(task.id)!.properties['scheduledDate'], '2026-10-19');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      pair.$1.dispose();
    },
  );
  testWidgets(
    'calendar editor and schedule remain usable at narrow large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pair = (await tester.runAsync(
        () => helpers.setup(
          WorkspaceRepository(
            store: FolderMemoryStore(),
            index: MemoryObjectIndex(),
          ),
        ),
      ))!;
      final c = pair.$2;
      final task = (await tester.runAsync(
        () => c.create(
          'orbit.task',
          title: 'Work',
          properties: {'scheduledDate': '2026-10-09', 'dueDate': '2026-10-20'},
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.5)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => showWorkingCalendarEditor(context, c),
                    child: const Text('Calendar'),
                  ),
                  TextButton(
                    onPressed: () => showGanttScheduleDialog(context, c, task),
                    child: const Text('Schedule'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.workingCalendars, isEmpty);
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.find(task.id)!.properties['scheduledDate'], '2026-10-09');
      await tester.pumpWidget(const SizedBox());
      pair.$1.dispose();
    },
  );
}
