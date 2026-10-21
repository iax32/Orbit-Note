import 'dart:typed_data';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/life_workspace.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

class _PackStore extends MemoryStore {
  int? remaining;
  @override
  Future<void> write(
    String path,
    Uint8List bytes, {
    required String? expectedHash,
  }) async {
    if (path.endsWith('.md') && !path.startsWith('.orbit/')) {
      if (remaining == 0) {
        throw const WorkspaceFailure('Simulated partial pack failure');
      }
      if (remaining != null) remaining = remaining! - 1;
    }
    await super.write(path, bytes, expectedHash: expectedHash);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryStore store;
  late WorkspaceRepository repo;
  late ProviderContainer container;
  late WorkspaceController c;
  Future<void> open() async {
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    for (var i = 0; i < 200 && c.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(c.hasWorkspace, true);
  }

  setUp(() async {
    store = _PackStore();
    await open();
  });
  tearDown(() async {
    store.failWrites = false;
    store.writeGate = null;
    await c.closeWorkspace();
    container.dispose();
  });
  Future<UniversalObject> make(
    LifeKind kind,
    String title, [
    Map<String, dynamic> fields = const {},
  ]) async => (await c.createLife(kind, title, fields: fields))!;
  Future<UniversalObject> workout() async {
    final e = await make(LifeKind.exercise, 'Custom exercise', {
      'equipment': 'My equipment',
    });
    return make(LifeKind.workout, 'Workout', {
      'exerciseIds': [e.id],
      'setsPerExercise': 2,
    });
  }

  test(
    'Life records persist as ordinary Markdown and survive repository reopen',
    () async {
      final goal = await c.createLife(
        LifeKind.goal,
        'My outcome',
        body: '## Why\nMeaningful reason',
        fields: {
          'future': {'keep': true},
        },
      );
      expect(goal!.typeId, 'orbit.note');
      expect(store.files.keys.any((p) => p.endsWith('.md')), true);
      await c.closeWorkspace();
      container.dispose();
      await open();
      expect(c.find(goal.id)!.body, '## Why\nMeaningful reason');
      expect(lifeData(c.find(goal.id)!)['future'], {'keep': true});
    },
  );
  test(
    'unknown metadata survives validated edits and stale edits are rejected',
    () async {
      final goal = await make(LifeKind.goal, 'Goal', {
        'future': {'keep': true},
      });
      expect(await c.saveLife(goal, {'state': 'paused'}), true);
      expect(await c.saveLife(goal, {'state': 'retired'}), false);
      expect(lifeData(c.find(goal.id)!)['state'], 'paused');
      expect(lifeData(c.find(goal.id)!)['future'], {'keep': true});
    },
  );
  test('failed saves leave durable old records and can retry', () async {
    final goal = await make(LifeKind.goal, 'Goal');
    final before = Map.of(store.files);
    store.failWrites = true;
    expect(await c.saveLife(goal, {'state': 'completed'}), false);
    expect(lifeData(c.find(goal.id)!)['state'], 'active');
    expect(store.files, before);
    store.failWrites = false;
    expect(await c.saveLife(c.find(goal.id)!, {'state': 'completed'}), true);
  });
  test('new record write failure never reports successful creation', () async {
    store.failWrites = true;
    expect(
      await c.createLife(LifeKind.journal, 'Failed', body: 'Keep my writing'),
      isNull,
    );
    expect(c.lifeIndex.records, isEmpty);
    store.failWrites = false;
    expect(
      await c.createLife(LifeKind.journal, 'Retry', body: 'Keep my writing'),
      isNotNull,
    );
  });
  test(
    'duplicate clicks coalesce a dated habit record, edits replace its amount',
    () async {
      final habit = await make(LifeKind.habit, 'Read', {
        'target': 10,
        'unit': 'pages',
      });
      final gate = Completer<void>();
      store.writeGate = gate.future;
      final one = c.recordLifeHabit(habit, DateTime(2026, 10, 21), value: 5),
          two = c.recordLifeHabit(habit, DateTime(2026, 10, 21), value: 5);
      gate.complete();
      store.writeGate = null;
      expect((await one)!.id, (await two)!.id);
      expect(c.lifeIndex.of(LifeKind.habitLog), hasLength(1));
      await c.recordLifeHabit(
        c.find(habit.id)!,
        DateTime(2026, 10, 21),
        value: 8,
      );
      expect(c.lifeIndex.habitValue(habit.id, DateTime(2026, 10, 21)), 8);
      await c.recordLifeHabit(
        c.find(habit.id)!,
        DateTime(2026, 10, 21),
        outcome: 'break',
        value: 0,
      );
      expect(c.lifeIndex.habitValue(habit.id, DateTime(2026, 10, 21)), 0);
    },
  );
  test(
    'routine history snapshots ordered steps and separates each day',
    () async {
      final routine = await make(LifeKind.routine, 'Morning', {
        'items': ['First', 'Second'],
      });
      final record = (await c.routineRecord(
        routine,
        DateTime(2026, 10, 20),
        checked: [1],
      ))!;
      await c.saveLife(c.find(routine.id)!, {
        'items': ['New step'],
      });
      expect(lifeData(c.find(record.id)!)['items'], ['First', 'Second']);
      final next = (await c.routineRecord(
        c.find(routine.id)!,
        DateTime(2026, 10, 21),
        checked: [0],
      ))!;
      expect(next.id, isNot(record.id));
      expect(lifeData(next)['items'], ['New step']);
    },
  );
  test('concurrent workout starts create one resumable session', () async {
    final w = await workout();
    final gate = Completer<void>();
    store.writeGate = gate.future;
    final one = c.startLifeWorkout(w), two = c.startLifeWorkout(w);
    gate.complete();
    store.writeGate = null;
    final session = (await one)!;
    expect((await two)!.id, session.id);
    expect(c.lifeIndex.of(LifeKind.session), hasLength(1));
    expect(lifeData(session)['sets'], hasLength(2));
    expect((await c.startLifeWorkout(w))!.id, session.id);
  });
  test(
    'sets are durable, duplicate with fresh identity, and keep explicit units',
    () async {
      final session = (await c.startLifeWorkout(await workout()))!;
      final set = (lifeData(session)['sets'] as List).first as Map;
      expect(
        await c.updateLifeSet(session, set['id'], {
          'weight': 42,
          'reps': 6,
          'completed': true,
        }),
        true,
      );
      var current = c.find(session.id)!;
      expect(
        await c.updateLifeSet(current, set['id'], {}, duplicate: true),
        true,
      );
      current = c.find(session.id)!;
      final sets = lifeData(current)['sets'] as List;
      expect(sets, hasLength(3));
      expect(sets.map((s) => s['id']).toSet(), hasLength(3));
      expect(sets[1]['completed'], false);
      expect(sets[1]['weight'], 42);
      expect(sets[1]['weightUnit'], 'kg');
      expect(await c.updateLifeSet(current, set['id'], {'weight': -2}), false);
    },
  );
  test(
    'rest timer and active session survive reopening and finishing enables another session',
    () async {
      final w = await workout(),
          session = (await c.startLifeWorkout(await workout()))!;
      expect(await c.restLifeSession(session, 90), true);
      final deadline = lifeData(c.find(session.id)!)['restUntil'];
      await c.closeWorkspace();
      container.dispose();
      await open();
      expect(lifeData(c.find(session.id)!)['restUntil'], deadline);
      expect(await c.finishLifeSession(c.find(session.id)!), true);
      expect(lifeData(c.find(session.id)!)['finishedAt'], isNotNull);
      final next = (await c.startLifeWorkout(c.find(w.id)!))!;
      expect(next.id, isNot(session.id));
    },
  );
  test('empty workouts refuse to create unusable sessions', () async {
    final w = await make(LifeKind.workout, 'Empty');
    expect(await c.startLifeWorkout(w), isNull);
    expect(c.lifeIndex.of(LifeKind.session), isEmpty);
  });
  test(
    'program scheduling rotates workouts and is idempotent on retry',
    () async {
      final a = await workout(), b = await workout();
      final program = await make(LifeKind.program, 'Plan', {
        'workoutIds': [a.id, b.id],
        'weekCount': 2,
        'weekdays': [1, 3, 5],
        'minutes': 45,
      });
      expect(await c.scheduleLifeProgram(program, DateTime(2026, 10, 19)), 6);
      expect(
        await c.scheduleLifeProgram(
          c.find(program.id)!,
          DateTime(2026, 10, 19),
        ),
        6,
      );
      final events = c.activeObjects
          .where((o) => o.typeId == 'orbit.event')
          .toList();
      expect(events, hasLength(6));
      expect(
        events
            .map((o) => o.properties['lifeSourceId'])
            .where((id) => id == a.id),
        hasLength(3),
      );
      expect(
        events.every(
          (o) =>
              DateTime.parse(
                o.properties['endAt'],
              ).difference(DateTime.parse(o.properties['startAt'])).inMinutes ==
              45,
        ),
        true,
      );
    },
  );
  test('concurrent schedule requests create only one calendar event', () async {
    final source = await make(LifeKind.life, 'Appointment');
    final results = await Future.wait([
      c.scheduleLife(source, DateTime(2026, 10, 25)),
      c.scheduleLife(source, DateTime(2026, 10, 25)),
    ]);
    expect(results[0]!.id, results[1]!.id);
    expect(
      c.activeObjects.where((o) => o.typeId == 'orbit.event'),
      hasLength(1),
    );
  });
  test(
    'actions and milestones are real tasks with normal completion progress',
    () async {
      final goal = await make(LifeKind.goal, 'Ship');
      final task = (await c.lifeAction(
        goal,
        'First step',
        dueDate: '2026-10-22',
        milestone: true,
      ))!;
      expect(task.typeId, 'orbit.task');
      expect(task.properties['ganttMilestone'], true);
      expect(c.lifeIndex.progress(goal), 0);
      expect(await c.completePlannedTask(task), true);
      expect(c.lifeIndex.progress(goal), 1);
      expect(
        await c.lifeAction(goal, 'Bad milestone', milestone: true),
        isNull,
      );
    },
  );
  test('skill ancestors cannot create a cycle', () async {
    final a = await make(LifeKind.skill, 'A'),
        b = await make(LifeKind.skill, 'B');
    expect(await c.saveLife(b, {'parentId': a.id}), true);
    expect(await c.saveLife(c.find(a.id)!, {'parentId': b.id}), false);
  });
  test(
    'period review contains real linked dated evidence and never overwrites authored review',
    () async {
      final journal = await make(LifeKind.journal, 'Today', {
        'date': '2026-10-21',
      });
      final review = (await c.createLifeReview(
        'week',
        DateTime(2026, 10, 21),
      ))!;
      expect(review.body, contains(journal.id));
      expect(review.body, contains('missing tracking is unknown'));
      await c.saveLife(review, {}, body: 'My authored conclusions');
      final again = (await c.createLifeReview('week', DateTime(2026, 10, 21)))!;
      expect(again.id, review.id);
      expect(again.body, 'My authored conclusions');
      expect(await c.createLifeReview('bad', DateTime.now()), isNull);
    },
  );
  test(
    'personal note templates retain body and custom portable settings',
    () async {
      final source = (await c.create(
        'orbit.note',
        title: 'Original',
        body: 'My reusable writing',
        properties: {
          'custom': {'keep': true},
        },
      ))!;
      final template = (await c.savePersonalTemplate(source, 'Mine'))!,
          copy = (await c.usePersonalTemplate(
            (c.personalTemplates).single,
            'Copy',
          ))!;
      expect(template.id, isNot(source.id));
      expect(copy.body, source.body);
      expect(copy.properties['custom'], {'keep': true});
      expect(copy.properties['templateSourceId'], template.id);
      expect(source.body, 'My reusable writing');
    },
  );
  test(
    'saved Canvas layouts clone placements, preserve live references and opaque data',
    () async {
      final goal = await make(LifeKind.goal, 'Live goal'),
          board = (await c.createLifeBoard('Board', []));
      expect(board, isNull);
      final original = (await c.createLifeBoard('Board', [goal.id]))!;
      final template = (await c.savePersonalTemplate(original, 'My layout'))!,
          one = (await c.usePersonalTemplate(c.find(template.id)!, 'One'))!,
          two = (await c.usePersonalTemplate(c.find(template.id)!, 'Two'))!;
      expect(one.data['elements'][0]['objectId'], goal.id);
      expect(
        one.data['elements'][0]['id'],
        isNot(two.data['elements'][0]['id']),
      );
      await c.trash(one.id);
      expect(c.find(goal.id)!.isDeleted, false);
    },
  );
  test(
    'routine log edits and goal edits use recoverable planning undo',
    () async {
      final goal = await make(LifeKind.goal, 'Goal');
      expect(await c.saveLife(goal, {'state': 'paused'}), true);
      expect(c.canUndoPlanning, true);
      expect(await c.undoPlanning(), true);
      expect(lifeData(c.find(goal.id)!)['state'], 'active');
    },
  );
  for (final pack in [
    'foundations',
    'training',
    'learning',
    'home',
    'outdoors',
  ]) {
    test(
      '$pack content pack creates linked editable records and retries without duplicates',
      () async {
        final first = await c.installLifePack(
          pack,
          'My plan',
          requestId: 'request',
          exercises: ['Exercise one', 'Exercise two'],
        );
        expect(first.complete, true, reason: first.error);
        expect(first.ids.length, greaterThanOrEqualTo(3));
        final count = c.activeObjects.length;
        final second = await c.installLifePack(
          pack,
          'My plan',
          requestId: 'request',
          exercises: ['Exercise one', 'Exercise two'],
        );
        expect(second.boardId, first.boardId);
        expect(second.ids, first.ids);
        expect(c.activeObjects.length, count);
        final board = c.find(first.boardId!)!;
        expect(
          (board.data['elements'] as List).map((e) => e['objectId']).toSet(),
          first.ids.toSet(),
        );
        expect(c.lifeIndex.of(LifeKind.session), isEmpty);
      },
    );
  }
  test(
    'partial pack failure exposes saved records and stable retry completes the same workspace',
    () async {
      (store as _PackStore).remaining = 2;
      final partial = await c.installLifePack(
        'foundations',
        'My week',
        requestId: 'partial',
      );
      expect(partial.complete, false);
      expect(partial.ids, hasLength(2));
      expect(partial.error, contains('failure'));
      (store as _PackStore).remaining = null;
      final result = await c.installLifePack(
        'foundations',
        'My week',
        requestId: 'partial',
      );
      expect(result.complete, true);
      expect(result.ids.take(2), partial.ids);
      expect(c.lifeIndex.of(LifeKind.goal), hasLength(1));
      expect(
        c.activeObjects.where((o) => o.typeId == 'orbit.canvas'),
        hasLength(1),
      );
    },
  );
  test(
    'session-only operations cannot mutate unrelated records or invalid rest durations',
    () async {
      final goal = await make(LifeKind.goal, 'Goal');
      expect(await c.finishLifeSession(goal), false);
      expect(await c.restLifeSession(goal, 60), false);
      final session = (await c.startLifeWorkout(await workout()))!;
      expect(await c.restLifeSession(session, -1), false);
      expect(await c.restLifeSession(session, 99999), false);
      final exercise = await make(LifeKind.exercise, 'Extra');
      expect(await c.appendLifeSet(session, exercise), true);
      expect(lifeData(c.find(session.id)!)['sets'], hasLength(3));
    },
  );
  test('dated habit identity cannot be reassigned to another date', () async {
    final habit = await make(LifeKind.habit, 'Habit');
    final log = (await c.recordLifeHabit(habit, DateTime(2026, 10, 21)))!;
    expect(await c.saveLife(log, {'date': '2026-10-22'}), false);
    expect(lifeData(c.find(log.id)!)['date'], '2026-10-21');
  });
  test(
    'removed exercise links stay explicit while unrelated writing remains editable',
    () async {
      final w = await workout();
      final id = lifeIds(lifeData(w), 'exerciseIds').single;
      await c.trash(id);
      expect(await c.saveLife(w, {}, body: 'Still useful'), true);
      expect(lifeIds(lifeData(c.find(w.id)!), 'exerciseIds'), [id]);
    },
  );
}
