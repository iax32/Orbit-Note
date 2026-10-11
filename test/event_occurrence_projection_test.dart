import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/calendar_event.dart';
import 'package:orbit_note/domain/calendar_planning.dart';
import 'package:orbit_note/domain/event_recurrence.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/calendar_planning_workspace.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

Map<String, dynamic> series() => {
  'allDay': true,
  'startDate': '2026-01-31',
  'endDate': '2026-02-01',
  'eventRecurrence': {
    'version': 1,
    'frequency': 'weekly',
    'interval': 1,
    'anchorDate': '2026-01-31',
    'processed': 0,
    'paused': false,
    'overlap': 'earlier',
    'count': 5,
  },
};
UniversalObject event(Map<String, dynamic> p) => UniversalObject(
  id: 'event',
  workspaceId: 'test',
  typeId: 'orbit.event',
  title: 'Lecture',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  properties: p,
);
List<EventOccurrence> project(
  UniversalObject e, {
  DateTime? from,
  DateTime? until,
}) => projectEventRange(
  [e],
  from ?? DateTime(2026, 1, 1),
  until ?? DateTime(2026, 3, 1),
).objects.whereType<EventOccurrence>().toList();
void main() {
  test(
    'future window has distinct stable occurrence keys and one source UUID',
    () {
      final e = event(series()), objects = project(event(series()));
      expect(objects.map((o) => o.occurrenceKey), [
        'occurrence:0',
        'occurrence:1',
        'occurrence:2',
        'occurrence:3',
        'occurrence:4',
      ]);
      expect(objects.map((o) => o.id).toSet(), {'event'});
      expect(
        entriesOn(
          objects,
          DateTime(2026, 2, 7),
        ).single.object.properties['startDate'],
        '2026-02-07',
      );
      final advanced = e.copyWith(
        properties: advanceEventOccurrence(e, 'completed', DateTime.utc(2026)),
      );
      expect(project(advanced).first.occurrenceKey, 'occurrence:1');
      expect(project(advanced).first.properties['startDate'], '2026-02-07');
      expect(
        () => validateEventRecurrence(objects.first),
        throwsFormatException,
      );
    },
  );
  test(
    'individual moves cross windows and cancellation leaves cadence intact',
    () {
      final e = event({
        ...series(),
        'eventOccurrenceOverrides': {
          'version': 1,
          'items': {
            'occurrence:1': {
              'status': 'rescheduled',
              'allDay': true,
              'startDate': '2026-01-20',
              'endDate': '2026-01-21',
            },
            'occurrence:2': {'status': 'cancelled'},
          },
        },
      });
      final january = project(e, until: DateTime(2026, 2));
      expect(january.map((o) => o.occurrenceKey), contains('occurrence:1'));
      expect(
        project(e).map((o) => o.occurrenceKey),
        isNot(contains('occurrence:2')),
      );
      expect(project(e).last.properties['startDate'], '2026-02-28');
      final recorded = advanceEventOccurrence(
        e.copyWith(
          properties: advanceEventOccurrence(
            e,
            'completed',
            DateTime.utc(2026),
          ),
        ),
        'completed',
        DateTime.utc(2026),
      );
      expect(recorded['startDate'], '2026-02-14');
      expect(
        (recorded['eventOccurrenceHistory'] as List).last['startDate'],
        '2026-01-20',
      );
      expect(
        () => advanceEventOccurrence(
          e.copyWith(properties: recorded),
          'completed',
          DateTime.utc(2026),
        ),
        throwsFormatException,
      );
      expect(
        advanceEventOccurrence(
          e.copyWith(properties: recorded),
          'skipped',
          DateTime.utc(2026),
        )['startDate'],
        '2026-02-21',
      );
    },
  );
  test(
    'pause/end/invalid overrides and bounded coverage never silently expand',
    () {
      final paused = event({
        ...series(),
        'eventRecurrence': {
          ...series()['eventRecurrence'] as Map,
          'paused': true,
        },
      });
      expect(project(paused).length, 1);
      final ended = event({
        ...series(),
        'eventRecurrence': {
          ...series()['eventRecurrence'] as Map,
          'until': '2026-02-08',
        },
      });
      expect(project(ended).length, 2);
      expect(
        () => resolveEventOccurrence(ended, 'occurrence:2'),
        throwsFormatException,
      );
      expect(
        projectEventRange(
          [event(series())],
          DateTime(2026),
          DateTime(2026, 3),
          limit: 2,
        ).issues,
        isNotEmpty,
      );
      final unsupported = event({
        ...series(),
        'eventOccurrenceOverrides': {'version': 99},
      });
      expect(
        projectEventRange(
          [unsupported],
          DateTime(2026),
          DateTime(2026, 3),
        ).issues,
        isNotEmpty,
      );
      expect(unsupported.properties['eventOccurrenceOverrides'], {
        'version': 99,
      });
    },
  );
  test('calendar snapshots respect the current occurrence change', () {
    final cancelled = event({
      ...series(),
      'eventOccurrenceOverrides': {
        'version': 1,
        'items': {
          'occurrence:0': {'status': 'cancelled'},
        },
      },
    });
    expect(exportCalendarIcs([cancelled]), isNot(contains('BEGIN:VEVENT')));
    final moved = event({
      ...series(),
      'eventOccurrenceOverrides': {
        'version': 1,
        'items': {
          'occurrence:0': {
            'status': 'rescheduled',
            'allDay': true,
            'startDate': '2026-02-02',
            'endDate': '2026-02-03',
          },
        },
      },
    });
    expect(exportCalendarIcs([moved]), contains('DTSTART;VALUE=DATE:20260202'));
    expect(exportCalendarIcs([moved]), contains('UID:event@orbit-note'));
  });
  test('cancelled final occurrence stays hidden after recording skipped', () {
    final e = event({
      ...series(),
      'eventRecurrence': {...series()['eventRecurrence'] as Map, 'count': 1},
      'eventOccurrenceOverrides': {
        'version': 1,
        'items': {
          'occurrence:0': {'status': 'cancelled'},
        },
      },
    });
    final done = e.copyWith(
      properties: advanceEventOccurrence(e, 'skipped', DateTime.utc(2026)),
    );
    expect((done.properties['eventRecurrence'] as Map)['finished'], true);
    expect(project(done), isEmpty);
    expect(exportCalendarIcs([done]), isNot(contains('BEGIN:VEVENT')));
  });
  test(
    'timed occurrences feed lanes and conflicts include overlapping same-series dates',
    () {
      final base = DateTime(2026, 1, 31, 9).toUtc();
      final e = event({
        ...series(),
        'allDay': false,
        'startAt': base.toIso8601String(),
        'endAt': base.add(const Duration(hours: 1)).toIso8601String(),
      });
      final rows = project(e);
      expect(
        calendarTimeSlots(rows, DateTime(2026, 2, 7)).single.object,
        rows[1],
      );
      final moved = EventOccurrence(e, 'occurrence:2', {
        'allDay': false,
        'startAt': rows[1].properties['startAt'],
        'endAt': rows[1].properties['endAt'],
      });
      expect(calendarConflicts(rows[1], [rows[1], moved]), [moved]);
    },
  );
  group('occurrence commands', () {
    late MemoryStore store;
    late ProviderContainer container;
    late WorkspaceController c;
    setUp(() async {
      store = MemoryStore();
      container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(
            WorkspaceRepository(store: store, index: MemoryObjectIndex()),
          ),
        ],
      );
      container.read(workspaceProvider);
      c = container.read(workspaceProvider.notifier);
      while (c.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    });
    tearDown(() async {
      await c.closeWorkspace();
      container.dispose();
    });
    Future<UniversalObject> create() async {
      final e = await c.repository.create(
        typeId: 'orbit.event',
        title: 'Lecture',
        properties: series(),
      );
      c.mergeRepositoryObjects();
      return e;
    }

    test(
      'cancel, restore, guarded undo and failures operate on original event',
      () async {
        final e = await create();
        expect(
          await c.changeEventOccurrence(e, 'occurrence:1', cancel: true),
          true,
        );
        expect(project(c.find(e.id)!).length, 4);
        expect(await c.undoPlanning(), true);
        expect(project(c.find(e.id)!).length, 5);
        store.failWrites = true;
        expect(
          await c.changeEventOccurrence(
            c.find(e.id)!,
            'occurrence:1',
            cancel: true,
          ),
          false,
        );
        expect(project(c.find(e.id)!).length, 5);
        store.failWrites = false;
        expect(
          await c.changeEventOccurrence(
            c.find(e.id)!,
            'occurrence:1',
            cancel: true,
          ),
          true,
        );
        expect(
          await c.changeEventOccurrence(e, 'occurrence:2', cancel: true),
          false,
        );
        expect(
          await c.changeEventOccurrence(
            c.find(e.id)!,
            'occurrence:1',
            restore: true,
          ),
          true,
        );
        expect(project(c.find(e.id)!).length, 5);
        expect(
          await c.changeEventOccurrence(
            c.find(e.id)!,
            'occurrence:8',
            cancel: true,
          ),
          false,
        );
      },
    );
    test(
      'reschedule survives advancing cadence and records actual dates',
      () async {
        final e = await create();
        expect(
          await c.changeEventOccurrence(
            e,
            'occurrence:1',
            dates: {
              'allDay': true,
              'startDate': '2026-02-10',
              'endDate': '2026-02-11',
            },
          ),
          true,
        );
        expect(c.find(e.id)!.properties['startDate'], '2026-01-31');
        expect(await c.recordEventOccurrence(c.find(e.id)!, 'completed'), true);
        expect(
          project(c.find(e.id)!).first.properties['startDate'],
          '2026-02-10',
        );
        expect(await c.recordEventOccurrence(c.find(e.id)!, 'completed'), true);
        final now = c.find(e.id)!;
        expect(now.properties['startDate'], '2026-02-14');
        expect(
          (now.properties['eventOccurrenceHistory'] as List).last['startDate'],
          '2026-02-10',
        );
        expect(
          await c.configureEventRepeat(now, {
            ...now.properties['eventRecurrence'] as Map,
            'processed': 0,
            'anchorDate': '2025-01-01',
          }),
          true,
        );
        expect(
          (c.find(e.id)!.properties['eventRecurrence'] as Map)['processed'],
          2,
        );
        expect(
          (c.find(e.id)!.properties['eventRecurrence'] as Map)['anchorDate'],
          '2026-01-31',
        );
      },
    );
    testWidgets('future calendar occurrence opens individual cancel control', (
      tester,
    ) async {
      final e = (await tester.runAsync(create))!;
      await tester.runAsync(
        () => c.rememberCalendarPlanning({
          'version': 1,
          'mode': 'Agenda',
          'date': '2026-02-07',
          'kind': 'events',
          'search': '',
          'completed': false,
        }),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: CalendarPlanningWorkspace(controller: c)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lecture').first);
      await tester.tap(find.text('Lecture').first);
      await tester.pumpAndSettle();
      expect(find.text('occurrence:1 · recurring event'), findsOneWidget);
      await tester.ensureVisible(find.text('Change this occurrence'));
      await tester.tap(find.text('Change this occurrence'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel occurrence'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Cancel occurrence'));
      });
      await tester.pumpAndSettle();
      expect(
        ((c.find(e.id)!.properties['eventOccurrenceOverrides'] as Map)['items']
            as Map)['occurrence:1']['status'],
        'cancelled',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
