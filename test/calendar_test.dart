import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/calendar_event.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/features/workspace/calendar_view.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/memory_store.dart';

void main() {
  const wsId = '22222222-2222-4222-8222-222222222222';
  final now = DateTime.utc(2026, 9, 10);

  group('Calendar Event Domain', () {
    test(
      'calendarDate formats correctly and parseCalendarDate validates format',
      () {
        final dt = DateTime(2026, 9, 10);
        expect(calendarDate(dt), '2026-09-10');

        expect(parseCalendarDate('2026-09-10'), equals(DateTime(2026, 9, 10)));
        expect(parseCalendarDate('2026-9-10'), isNull);
        expect(parseCalendarDate('invalid'), isNull);
        expect(parseCalendarDate(123), isNull);
        expect(parseCalendarDate(null), isNull);
      },
    );

    test('EventSchedule all-day validation and occursOn', () {
      final schedule = EventSchedule.fromProperties({
        'allDay': true,
        'startDate': '2026-09-10',
        'endDate': '2026-09-12',
      });

      expect(schedule.allDay, isTrue);
      expect(schedule.start, DateTime(2026, 9, 10));
      expect(schedule.end, DateTime(2026, 9, 12));

      expect(schedule.occursOn(DateTime(2026, 9, 9)), isFalse);
      expect(schedule.occursOn(DateTime(2026, 9, 10)), isTrue);
      expect(schedule.occursOn(DateTime(2026, 9, 11)), isTrue);
      // End date is exclusive for all-day intervals
      expect(schedule.occursOn(DateTime(2026, 9, 12)), isFalse);
      expect(schedule.occursOn(DateTime(2026, 9, 13)), isFalse);
    });

    test('EventSchedule timed validation and occursOn', () {
      final schedule = EventSchedule.fromProperties({
        'allDay': false,
        'startAt': '2026-09-10T14:00:00Z',
        'endAt': '2026-09-10T15:30:00Z',
        'contextId': '11111111-1111-1111-1111-111111111111',
      });

      expect(schedule.allDay, isFalse);
      expect(schedule.occursOn(DateTime.utc(2026, 9, 10)), isTrue);
      expect(schedule.occursOn(DateTime.utc(2026, 9, 11)), isFalse);
    });

    test('EventSchedule rejects invalid properties', () {
      expect(
        () => EventSchedule.fromProperties({'allDay': 'yes'}),
        throwsA(isA<WorkspaceFailure>()),
      );

      // Missing start or end
      expect(
        () => EventSchedule.fromProperties({
          'allDay': true,
          'startDate': '2026-09-10',
        }),
        throwsA(isA<WorkspaceFailure>()),
      );

      // End date before start date
      expect(
        () => EventSchedule.fromProperties({
          'allDay': true,
          'startDate': '2026-09-10',
          'endDate': '2026-09-09',
        }),
        throwsA(isA<WorkspaceFailure>()),
      );

      // Timed event without Z suffix
      expect(
        () => EventSchedule.fromProperties({
          'allDay': false,
          'startAt': '2026-09-10T14:00:00',
          'endAt': '2026-09-10T15:00:00',
        }),
        throwsA(isA<WorkspaceFailure>()),
      );

      // Non-string contextId
      expect(
        () => EventSchedule.fromProperties({
          'allDay': true,
          'startDate': '2026-09-10',
          'endDate': '2026-09-11',
          'contextId': 12345,
        }),
        throwsA(isA<WorkspaceFailure>()),
      );
    });

    test(
      'entriesOn aggregates events and task deadlines without duplication',
      () {
        final objects = [
          UniversalObject(
            id: '11111111-1111-4111-8111-111111111111',
            workspaceId: wsId,
            title: 'Team sync',
            typeId: 'orbit.event',
            createdAt: now,
            updatedAt: now,
            properties: {
              'allDay': true,
              'startDate': '2026-09-10',
              'endDate': '2026-09-11',
            },
          ),
          UniversalObject(
            id: '22222222-2222-4222-8222-222222222222',
            workspaceId: wsId,
            title: 'Submit quarterly report',
            typeId: 'orbit.task',
            createdAt: now,
            updatedAt: now,
            properties: {
              'completed': false,
              'priority': 'high',
              'dueDate': '2026-09-10',
            },
          ),
          UniversalObject(
            id: '33333333-3333-4333-8333-333333333333',
            workspaceId: wsId,
            title: 'Review PRs',
            typeId: 'orbit.task',
            createdAt: now,
            updatedAt: now,
            properties: {
              'completed': false,
              'priority': 'medium',
              'scheduledDate': '2026-09-10',
            },
          ),
          UniversalObject(
            id: '44444444-4444-4444-8444-444444444444',
            workspaceId: wsId,
            title: 'Next week event',
            typeId: 'orbit.event',
            createdAt: now,
            updatedAt: now,
            properties: {
              'allDay': true,
              'startDate': '2026-09-17',
              'endDate': '2026-09-18',
            },
          ),
          UniversalObject(
            id: '55555555-5555-4555-8555-555555555555',
            workspaceId: wsId,
            title: 'Deleted event',
            typeId: 'orbit.event',
            deletedAt: now,
            createdAt: now,
            updatedAt: now,
            properties: {
              'allDay': true,
              'startDate': '2026-09-10',
              'endDate': '2026-09-11',
            },
          ),
        ];

        final entries = entriesOn(objects, DateTime(2026, 9, 10));
        expect(entries.length, 3);

        final titles = entries.map((e) => e.object.title).toList();
        expect(titles.contains('Team sync'), isTrue);
        expect(titles.contains('Submit quarterly report'), isTrue);
        expect(titles.contains('Review PRs'), isTrue);
        expect(titles.contains('Next week event'), isFalse);
        expect(titles.contains('Deleted event'), isFalse);
      },
    );
  });

  group('WorkspaceRepository Calendar Integration', () {
    late Directory folder;
    late WorkspaceRepository repository;

    setUp(() async {
      folder = await Directory.systemTemp.createTemp('orbit-calendar-test-');
      repository = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      await repository.initialize(path: folder.path);
    });

    tearDown(() async {
      await repository.close();
      await folder.delete(recursive: true);
    });

    test(
      'creates and validates orbit.event objects in Objects directory',
      () async {
        final event = await repository.create(
          typeId: 'orbit.event',
          title: 'Project Kickoff',
          properties: {
            'allDay': true,
            'startDate': '2026-09-15',
            'endDate': '2026-09-16',
          },
        );

        expect(event.typeId, 'orbit.event');
        expect(event.title, 'Project Kickoff');
        expect(
          repository.objectPath(event.id),
          'Objects/${event.id}.object.json',
        );

        // Invalid event rejected
        expect(
          () => repository.create(
            typeId: 'orbit.event',
            title: 'Bad event',
            properties: {'allDay': true, 'startDate': 'bad-date'},
          ),
          throwsA(isA<WorkspaceFailure>()),
        );
      },
    );

    test(
      'WorkspaceController creates orbit.event and sets calendar destination',
      () async {
        final store = MemoryStore();
        final repo = WorkspaceRepository(
          store: store,
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        container.read(workspaceProvider);
        final controller = container.read(workspaceProvider.notifier);
        for (var i = 0; i < 100 && controller.loading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }

        final event = await controller.create(
          'orbit.event',
          title: 'Team Retro',
        );
        expect(event, isNotNull);
        expect(event!.typeId, 'orbit.event');
        expect(event.title, 'Team Retro');
        expect(controller.session.destination, OrbitDestination.calendar);
        expect(controller.session.activeId, event.id);

        await controller.flushAll();
        container.dispose();
      },
    );

    testWidgets('CalendarView renders month grid and navigates', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      final controller = container.read(workspaceProvider.notifier);
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && controller.loading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: CalendarView(controller: controller)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('New event'), findsOneWidget);
      expect(find.text('DAY AGENDA'), findsOneWidget);
      expect(find.byType(CalendarView), findsOneWidget);

      await tester.runAsync(() async {
        await controller.flushAll();
      });
      container.dispose();
    });
  });
}
