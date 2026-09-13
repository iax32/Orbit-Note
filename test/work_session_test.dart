import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/work_session.dart';
import 'package:orbit_note/features/workspace/command_palette.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

import 'support/memory_store.dart';

Future<({WorkspaceController controller, ProviderContainer container})>
_setupTestWorkspace() async {
  final store = MemoryStore();
  final repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
  await repo.initialize();
  final container = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(repo)],
  );
  final c = container.read(workspaceProvider.notifier);
  await c.initialize();
  return (controller: c, container: container);
}

void main() {
  group('WorkSessionRecord Domain Unit Tests (CTX-04, CTX-05, CTX-07, CTX-12)', () {
    test(
      'lifecycle: start, record, pause, paused-actions-not-recorded, resume, end',
      () {
        final t0 = DateTime(2026, 9, 13, 10, 0, 0);
        var record = WorkSessionRecord(
          id: 'session-1',
          title: 'Compiler Study',
          category: 'study',
          startedAt: t0,
        );

        expect(record.isRecordingActive, isTrue);
        expect(record.isPaused, isFalse);
        expect(record.isEnded, isFalse);
        expect(
          record.elapsedActiveDuration(DateTime(2026, 9, 13, 10, 10, 0)),
          const Duration(minutes: 10),
        );

        // Record while active
        record = record.recordOpen('note-1');
        record = record.recordCreate('note-2');
        record = record.recordTaskCompleted('task-1');
        expect(record.notesOpened, contains('note-1'));
        expect(record.notesCreated, contains('note-2'));
        expect(record.tasksCompleted, contains('task-1'));

        // Pause at 10:15
        final tPause = DateTime(2026, 9, 13, 10, 15, 0);
        record = record.pause(tPause);
        expect(record.isPaused, isTrue);
        expect(record.isRecordingActive, isFalse);
        // Elapsed duration stays at 15m while paused at 10:25
        expect(
          record.elapsedActiveDuration(DateTime(2026, 9, 13, 10, 25, 0)),
          const Duration(minutes: 15),
        );

        // CTX-07 Invariant: Paused actions must NOT appear as tracked events
        record = record.recordOpen('note-paused');
        record = record.recordCreate('note-paused-create');
        record = record.recordTaskCompleted('task-paused');
        expect(record.notesOpened, isNot(contains('note-paused')));
        expect(record.notesCreated, isNot(contains('note-paused-create')));
        expect(record.tasksCompleted, isNot(contains('task-paused')));

        // Resume at 10:30 (paused for 15 mins)
        final tResume = DateTime(2026, 9, 13, 10, 30, 0);
        record = record.resume(tResume);
        expect(record.isPaused, isFalse);
        expect(record.isRecordingActive, isTrue);
        expect(record.totalPausedDuration, const Duration(minutes: 15));

        // At 10:45 (45 mins total elapsed, minus 15 mins pause = 30 mins active)
        expect(
          record.elapsedActiveDuration(DateTime(2026, 9, 13, 10, 45, 0)),
          const Duration(minutes: 30),
        );

        // Record after resuming
        record = record.recordOpen('note-3');
        expect(record.notesOpened, contains('note-3'));

        // End at 11:00 with continuation note
        final tEnd = DateTime(2026, 9, 13, 11, 0, 0);
        record = record.end(tEnd, 'Next step is to write parser tests.');
        expect(record.isEnded, isTrue);
        expect(record.isRecordingActive, isFalse);
        // Total active: 60 mins total - 15 mins pause = 45 mins
        expect(record.elapsedActiveDuration(), const Duration(minutes: 45));
        expect(record.continuationNote, 'Next step is to write parser tests.');
      },
    );

    test('toJson and fromJson preserves all metrics and state', () {
      final t0 = DateTime(2026, 9, 13, 14, 0, 0);
      final original = WorkSessionRecord(
        id: 'session-serialize',
        title: 'Reverse Engineering',
        category: 'work',
        startedAt: t0,
        totalPausedDuration: const Duration(minutes: 5),
        notesOpened: ['fn-1', 'struct-2'],
        notesCreated: ['finding-1'],
        tasksCompleted: ['t-1'],
        continuationNote: 'Triage complete.',
      );

      final json = original.toJson();
      final restored = WorkSessionRecord.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.category, original.category);
      expect(restored.totalPausedDuration, original.totalPausedDuration);
      expect(restored.notesOpened, original.notesOpened);
      expect(restored.notesCreated, original.notesCreated);
      expect(restored.tasksCompleted, original.tasksCompleted);
      expect(restored.continuationNote, original.continuationNote);
    });
  });

  group(
    'WorkspaceController Work Session Integration (CTX-04, CTX-05, CTX-06, CTX-11)',
    () {
      test(
        'start, track notes/tasks, pause, resume, and end session',
        () async {
          final env = await _setupTestWorkspace();
          final c = env.controller;

          expect(c.activeWorkSession, isNull);
          expect(c.completedWorkSessions, isEmpty);

          // 1. Start session
          c.startWorkSession(
            title: 'Game Loop Implementation',
            category: 'work',
          );
          expect(c.activeWorkSession, isNotNull);
          expect(c.activeWorkSession!.title, 'Game Loop Implementation');
          expect(c.activeWorkSession!.isRecordingActive, isTrue);

          // 2. Open note -> recorded
          final note1 = (await c.create(
            'orbit.note',
            title: 'Game Engine Architecture',
          ))!;
          expect(c.activeWorkSession!.notesCreated, contains(note1.id));
          expect(c.activeWorkSession!.notesOpened, contains(note1.id));

          // 3. Complete task -> recorded
          final task1 = (await c.create(
            'orbit.task',
            title: 'Implement Delta Time',
          ))!;
          c.edit(
            task1.id,
            properties: {...task1.properties, 'completed': true},
          );
          expect(c.activeWorkSession!.tasksCompleted, contains(task1.id));

          // 4. Pause session
          c.pauseWorkSession();
          expect(c.activeWorkSession!.isPaused, isTrue);
          expect(c.activeWorkSession!.isRecordingActive, isFalse);

          // 5. Actions while paused -> NOT recorded
          final notePaused = (await c.create(
            'orbit.note',
            title: 'Unrelated distraction',
          ))!;
          expect(
            c.activeWorkSession!.notesCreated,
            isNot(contains(notePaused.id)),
          );

          // 6. Resume session
          c.resumeWorkSession();
          expect(c.activeWorkSession!.isPaused, isFalse);
          expect(c.activeWorkSession!.isRecordingActive, isTrue);

          // 7. Update continuation note
          c.setWorkSessionContinuationNote(
            'Engine physics fixed; render loop next.',
          );
          expect(
            c.activeWorkSession!.continuationNote,
            'Engine physics fixed; render loop next.',
          );

          // 8. End session
          final completed = c.endWorkSession();
          expect(completed, isNotNull);
          expect(c.activeWorkSession, isNull);
          expect(c.completedWorkSessions.length, 1);
          expect(
            c.completedWorkSessions.first.title,
            'Game Loop Implementation',
          );
          expect(
            c.completedWorkSessions.first.continuationNote,
            'Engine physics fixed; render loop next.',
          );

          env.container.dispose();
        },
      );
    },
  );

  group('HomeView & CommandPalette Work Session UI Tests (CTX-04, CTX-12)', () {
    testWidgets(
      'HomeView displays focus session card, starts session, pauses, and ends',
      (tester) async {
        final env = await _setupTestWorkspace();
        final c = env.controller;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: env.container,
            child: MaterialApp(
              home: Scaffold(body: HomeView(controller: c)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify idle session section exists
        expect(find.text('FOCUS & WORK SESSIONS'), findsOneWidget);
        expect(find.text('Start Focus Session'), findsOneWidget);

        // Start focus session
        c.startWorkSession(title: 'Algorithm Study', category: 'study');
        await tester.pumpAndSettle();

        // Verify active session view
        expect(find.text('ACTIVE FOCUS'), findsOneWidget);
        expect(find.text('Algorithm Study'), findsOneWidget);
        expect(find.text('STUDY'), findsOneWidget);
        expect(find.text('Pause'), findsOneWidget);
        expect(find.text('End session'), findsOneWidget);

        // Tap Pause
        await tester.tap(find.text('Pause'));
        await tester.pumpAndSettle();

        expect(find.text('PAUSED'), findsOneWidget);
        expect(find.text('Resume'), findsOneWidget);

        // Tap Resume
        await tester.tap(find.text('Resume'));
        await tester.pumpAndSettle();

        expect(find.text('ACTIVE FOCUS'), findsOneWidget);

        // End session
        c.endWorkSession(
          continuationNote: 'Finished dynamic programming chapter.',
        );
        await tester.pumpAndSettle();

        expect(find.text('FOCUS & WORK SESSIONS'), findsOneWidget);
        expect(
          find.textContaining('Finished dynamic programming chapter.'),
          findsOneWidget,
        );

        env.container.dispose();
      },
    );

    testWidgets(
      'CommandPalette provides focus session start/pause/end commands',
      (tester) async {
        final env = await _setupTestWorkspace();
        final c = env.controller;

        // 1. Idle -> Start focus session available
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: env.container,
            child: MaterialApp(
              home: Scaffold(body: CommandPalette(controller: c)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Start focus session'), findsOneWidget);

        // Tap start focus session
        await tester.tap(find.text('Start focus session'));
        await tester.pumpAndSettle();

        expect(c.activeWorkSession, isNotNull);

        // 2. Re-open CommandPalette with active session -> Pause and End available
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: env.container,
            child: MaterialApp(
              home: Scaffold(body: CommandPalette(controller: c)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Pause focus session'), findsOneWidget);
        expect(find.textContaining('End focus session'), findsOneWidget);

        env.container.dispose();
      },
    );
  });
}
