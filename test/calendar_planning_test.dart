import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/calendar_event.dart';
import 'package:orbit_note/domain/calendar_planning.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/calendar_planning_workspace.dart';
import 'package:orbit_note/features/workspace/calendar_plan_editor.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'package:orbit_note/infrastructure/storage/object_codec.dart';

void main() {
  final day = DateTime(2026, 10, 12);
  UniversalObject event(String id, int start, int end) => UniversalObject(
    id: id,
    workspaceId: 'test',
    typeId: 'orbit.event',
    title: id,
    createdAt: day,
    updatedAt: day,
    properties: {
      'allDay': false,
      'startAt': DateTime(
        day.year,
        day.month,
        day.day,
        start,
      ).toUtc().toIso8601String(),
      'endAt': DateTime(
        day.year,
        day.month,
        day.day,
        end,
      ).toUtc().toIso8601String(),
    },
  );
  test(
    'conflicts use exclusive ends and lanes preserve overlapping events',
    () {
      final a = event('a', 9, 11),
          b = event('b', 10, 12),
          c = event('c', 12, 13);
      expect(calendarConflicts(a, [a, b, c]).map((o) => o.id), ['b']);
      expect(calendarConflicts(c, [a, b, c]), isEmpty);
      final slots = calendarTimeSlots([c, b, a], day);
      expect(slots.map((s) => s.object.id), ['a', 'b', 'c']);
      expect(slots[0].lanes, 2);
      expect(slots[1].lane, 1);
      expect(slots[2].lanes, 1);
    },
  );
  test(
    'overnight time grid clips to civil days and ignores invalid/all-day events',
    () {
      final a = event('overnight', 23, 26),
          allDay = event('all', 1, 2).copyWith(
            properties: {
              'allDay': true,
              'startDate': calendarDate(day),
              'endDate': '2026-10-13',
            },
          );
      expect(calendarTimeSlots([a, allDay], day).single.endMinute, 1440);
      expect(
        calendarTimeSlots([a], DateTime(2026, 10, 13)).single.startMinute,
        0,
      );
      expect(
        calendarTimeSlots([a], DateTime(2026, 10, 13)).single.endMinute,
        120,
      );
    },
  );
  test(
    'ICS keeps identity, UTC/exclusive dates, escaping and Unicode-safe folding',
    () {
      final title = List.filled(70, '🐈').join();
      final a = event(
        'stable',
        9,
        10,
      ).copyWith(title: title, body: 'line;comma,\ntext\\end');
      final task = UniversalObject(
        id: 'task',
        workspaceId: 'test',
        typeId: 'orbit.task',
        title: 'task',
        createdAt: day,
        updatedAt: day,
        properties: {'dueDate': '2026-10-12', 'scheduledDate': '2026-10-13'},
      );
      final out = exportCalendarIcs([a, task], now: DateTime.utc(2026, 10, 9));
      expect(out, contains('UID:stable@orbit-note'));
      expect(out, contains('BEGIN:VTODO'));
      expect(out, contains('X-ORBIT-SCHEDULED-DATE:20261013'));
      expect(out, contains(r'line\;comma\,\ntext\\end'));
      for (final line in out.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      expect(out.replaceAll('\r\n ', ''), contains('SUMMARY:$title'));
    },
  );

  group('Planning commands', () {
    late MemoryStore store;
    late WorkspaceController c;
    late ProviderContainer container;
    Future<void> open() async {
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
    }

    Future<UniversalObject?> assignment({
      UniversalObject? original,
      List<String> resources = const [],
      String due = '2026-10-20',
    }) => c.saveCalendarPlan(
      original: original,
      title: 'Sheet 4',
      body: 'Show the proof',
      kind: 'assignment',
      course: 'Math',
      dates: {'dueDate': due, 'scheduledDate': '2026-10-15'},
      estimateMinutes: 120,
      resources: resources,
    );
    setUp(() async {
      store = MemoryStore();
      await open();
    });
    tearDown(() async {
      await c.closeWorkspace();
      container.dispose();
    });
    test(
      'unknown plan fields survive edits, future plans stay editable outside the planning command',
      () async {
        final task = (await assignment())!;
        var updated = await c.repository.save(
          task.copyWith(
            properties: {
              ...task.properties,
              'calendarPlan': {
                ...task.properties['calendarPlan'] as Map,
                'futureField': {'keep': true},
              },
            },
          ),
        );
        c.mergeRepositoryObjects();
        updated = (await assignment(original: updated, due: '2026-10-21'))!;
        expect((updated.properties['calendarPlan'] as Map)['futureField'], {
          'keep': true,
        });
        final path = c.repository.objectPath(task.id)!;
        store.files[path] = Uint8List.fromList(
          utf8.encode(
            ObjectCodec().encode(
              updated.copyWith(
                properties: {
                  ...updated.properties,
                  'calendarPlan': {
                    ...updated.properties['calendarPlan'] as Map,
                    'version': 99,
                  },
                },
              ),
            ),
          ),
        );
        await c.closeWorkspace();
        container.dispose();
        await open();
        final future = c.find(task.id)!;
        expect(await assignment(original: future), isNull);
        c.edit(task.id, title: 'Retained');
        await c.flush(task.id);
        expect(
          (c.find(task.id)!.properties['calendarPlan'] as Map)['version'],
          99,
        );
        expect(
          (c.find(task.id)!.properties['calendarPlan'] as Map)['futureField'],
          {'keep': true},
        );
      },
    );
    test(
      'creating twice during a staged write refuses the duplicate and Vault closure waits',
      () async {
        final gate = Completer<void>();
        store.writeGate = gate.future;
        final pending = assignment();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(await assignment(), isNull);
        var closed = false;
        final closing = c.closeWorkspace().then((_) => closed = true);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(closed, false);
        gate.complete();
        expect(await pending, isNotNull);
        await closing;
        container.dispose();
        await open();
        expect(
          c.objects.where((o) => calendarPlanKind(o) == 'assignment'),
          hasLength(1),
        );
      },
    );
    test(
      'assignment and resource backlinks survive restart with no derived index',
      () async {
        final note = (await c.create(
          'orbit.note',
          title: 'Lecture',
          properties: {'course': 'Math'},
        ))!;
        final task = (await assignment(resources: [note.id]))!;
        expect(task.typeId, 'orbit.task');
        expect(task.properties['dueDate'], '2026-10-20');
        expect(c.backlinks(note.id).map((o) => o.id), contains(task.id));
        expect(
          c.linkedMentions(note.id).map((m) => m.source.id),
          contains(task.id),
        );
        await c.closeWorkspace();
        container.dispose();
        await open();
        expect(calendarResources(c.find(task.id)!), [note.id]);
        expect(c.find(task.id)!.body, 'Show the proof');
      },
    );
    test(
      'editing deadline is undoable and stale edits cannot overwrite newer work',
      () async {
        final task = (await assignment())!;
        final changed = (await assignment(original: task, due: '2026-10-22'))!;
        expect(changed.id, task.id);
        expect(
          changed.properties['scheduledDate'],
          task.properties['scheduledDate'],
        );
        expect(await assignment(original: task), isNull);
        expect(await c.undoPlanning(), true);
        expect(c.find(task.id)!.properties['dueDate'], '2026-10-20');
      },
    );
    test(
      'write failure, invalid dates, missing resources and unsupported data reject cleanly',
      () async {
        store.failWrites = true;
        expect(await assignment(), isNull);
        store.failWrites = false;
        expect(await assignment(due: '2026-02-30'), isNull);
        expect(await assignment(resources: ['missing']), isNull);
        final task = (await assignment())!;
        final future = await c.repository.save(
          task.copyWith(properties: {...task.properties, 'calendarPlan': null}),
        );
        c.mergeRepositoryObjects();
        expect(
          await c.saveCalendarPlan(
            original: future,
            title: 'Bad',
            body: '',
            kind: 'assignment',
            course: 'Math',
            dates: {'dueDate': '2026-10-20', 'unrelated': 'inject'},
          ),
          isNull,
        );
        expect(c.find(task.id)!.title, 'Sheet 4');
      },
    );
    test(
      'exam and linked study session use event identity with actual overlap warnings',
      () async {
        final exam = (await c.saveCalendarPlan(
          title: 'Exam',
          body: 'Bring ID',
          kind: 'exam',
          course: 'Math',
          dates: event('x', 9, 10).properties,
        ))!;
        final study = (await c.saveCalendarPlan(
          title: 'Prepare',
          body: '',
          kind: 'study',
          course: 'Math',
          resources: [exam.id],
          dates: event('x', 9, 11).properties,
        ))!;
        expect(calendarPlanKind(exam), 'exam');
        expect(calendarConflicts(exam, c.objects).single.id, study.id);
        expect(c.backlinks(exam.id).single.id, study.id);
      },
    );
    test(
      'course/kind/search/completion filters work before display and undated tasks remain visible',
      () async {
        final task = (await assignment())!;
        await c.create(
          'orbit.task',
          title: 'Unscheduled',
          properties: {'course': 'Math'},
        );
        await c.create(
          'orbit.task',
          title: 'Done',
          properties: {'course': 'Math', 'completed': true},
        );
        await c.create(
          'orbit.task',
          title: 'Other',
          properties: {'course': 'Physics'},
        );
        expect(filterCalendarObjects(c.objects, course: 'Math'), hasLength(2));
        expect(
          filterCalendarObjects(
            c.objects,
            course: 'Math',
            kind: 'assignment',
            search: 'proof',
          ).single.id,
          task.id,
        );
        expect(
          filterCalendarObjects(c.objects, course: 'Math', showCompleted: true),
          hasLength(3),
        );
      },
    );
    test(
      'remembered view preserves unknown settings, survives restart and rejects future versions',
      () async {
        final view = {
          'version': 1,
          'mode': 'Week',
          'date': '2026-10-12',
          'course': 'Math',
          'kind': 'exam',
          'search': 'proof',
          'completed': false,
        };
        c.session.noteViews = {
          'calendarPlanning': {'version': 1, 'futureKey': 42},
        };
        expect(await c.rememberCalendarPlanning(view), true);
        await c.closeWorkspace();
        container.dispose();
        await open();
        expect(c.session.noteViews['calendarPlanning']!['futureKey'], 42);
        c.session.noteViews = {
          'calendarPlanning': {'version': 99},
        };
        expect(await c.rememberCalendarPlanning(view), false);
        expect(c.session.noteViews['calendarPlanning']!['version'], 99);
      },
    );
    testWidgets(
      'narrow large-text planning workspace has accessible modes and filters',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: CalendarPlanningWorkspace(controller: c),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Week'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Week'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('00:00'), findsOneWidget);
        await tester.ensureVisible(find.text('Unscheduled'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unscheduled'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'planning editor exposes course, effort, resource and date controls',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showCalendarPlanEditor(
                    context,
                    c,
                    kind: 'exam',
                    course: 'Math',
                    day: day,
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        expect(find.text('Course / subject'), findsOneWidget);
        expect(find.text('Estimated effort (minutes)'), findsOneWidget);
        expect(find.text('Link a resource'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
