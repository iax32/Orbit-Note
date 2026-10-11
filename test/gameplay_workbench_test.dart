import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/gameplay_workbench.dart';
import 'package:orbit_note/domain/gameplay_release.dart';
import 'package:orbit_note/features/workspace/gameplay_release_workspace.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/features/workspace/gameplay_workbench.dart';
import 'support/memory_store.dart';

class GameplayNativeStore extends NativeWorkspaceStore {
  GameplayNativeStore(this.root);
  final String root;
  @override
  Future<void> initialize({String? path}) =>
      super.initialize(path: path ?? root);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GameplayCodeReference code({
    String path = 'src/player.cpp',
    String? revision,
    String excerpt = 'jump();',
  }) => GameplayCodeReference(
    repository: 'Local checkout',
    path: path,
    revision: revision ?? 'a' * 40,
    startLine: 10,
    endLine: 12,
    excerpt: excerpt,
    branch: 'main',
  );
  Future<(ProviderContainer, WorkspaceController)> open(
    WorkspaceRepository repo,
  ) async {
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    final c = container.read(workspaceProvider.notifier);
    while (c.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    return (container, c);
  }

  WorkspaceRepository memory(MemoryStore store) =>
      WorkspaceRepository(store: store, index: MemoryObjectIndex());

  test(
    'checklist coverage excludes code examples and never passes empty plans',
    () {
      expect(
        gameplayChecklist(
          '- [x] Done\r\n- [ ] Pending\n```md\n- [x] Example\n```\n',
        ),
        (1, 2),
      );
      expect(gameplayChecklist('No coverage'), (0, 0));
    },
  );

  test(
    'build comparison retains history and never borrows a pass from another build',
    () async {
      final (container, c) = await open(memory(MemoryStore()));
      try {
        final m = (await c.createMechanicDesignDoc(
          folder: 'Notes',
          title: 'Jump',
        ))!;
        final p = (await c.createGameplayRecord(
          mechanicId: m.id,
          kind: 'playtest',
          title: 'Finding',
          build: 'A',
          expected: 'Jump',
          observed: 'Missed',
        ))!;
        final t = (await c.createTaskFromFinding(
          finding: 'Fix',
          sourceNoteId: p.id,
        ))!;
        final a = (await c.createGameplayRecord(
          mechanicId: m.id,
          kind: 'verification',
          title: 'A pass',
          build: 'A',
          expected: 'Jump',
          observed: 'Passed',
          taskId: t.id,
          outcome: 'passed',
        ))!;
        expect(
          gameplayTaskReview(c.gameplayRelated(m.id), t, 'A'),
          'Verified · task open',
        );
        expect(
          gameplayTaskReview(c.gameplayRelated(m.id), t, 'B'),
          'Awaiting retest',
        );
        await c.createGameplayRecord(
          mechanicId: m.id,
          kind: 'verification',
          title: 'B fails',
          build: 'B',
          expected: 'Jump',
          observed: 'Missed',
          taskId: t.id,
          outcome: 'failed',
        );
        expect(
          gameplayTaskReview(c.gameplayRelated(m.id), t, 'B'),
          'Failed fix',
        );
        expect(
          gameplayVerification(c.gameplayRelated(m.id), t.id, 'A')!.id,
          a.id,
        );
        expect(c.find(t.id)!.isCompleted, false);
      } finally {
        await c.closeWorkspace();
        container.dispose();
      }
    },
  );

  test(
    'plans and independent runs recover with unknown metadata and reject stale or incomplete passes',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-release-');
      final (container, c) = await open(
        WorkspaceRepository(
          store: GameplayNativeStore(root.path),
          index: MemoryObjectIndex(),
        ),
      );
      String? runId, planId;
      try {
        final m = (await c.createMechanicDesignDoc(
          folder: 'Notes',
          title: 'Jump',
        ))!;
        final plan = (await c.createGameplayTestPlan(
          mechanicId: m.id,
          title: 'Controls',
          checklist: '- [x] Input\r\n- [ ] Reconnect',
        ))!;
        planId = plan.id;
        c.edit(
          plan.id,
          properties: {
            ...plan.properties,
            'futureProperty': {'retained': true},
          },
        );
        await c.flush(plan.id);
        expect(await c.startGameplayTestRun(plan, 'A'), isNull);
        final current = c.find(plan.id)!;
        final run = (await c.startGameplayTestRun(current, 'A'))!;
        runId = run.id;
        expect(run.body, startsWith('- [ ] Input\r\n- [ ] Reconnect'));
        expect(run.properties['futureProperty'], {'retained': true});
        expect(await c.setGameplayTestOutcome(run, 'passed'), false);
        c.edit(run.id, body: run.body.replaceAll('- [ ]', '- [x]'));
        expect(await c.setGameplayTestOutcome(run, 'passed'), false);
        expect(await c.setGameplayTestOutcome(c.find(run.id)!, 'passed'), true);
        expect(gameplayRunPassed(c.find(run.id)!), true);
        expect(gameplayPlanCovered(current, c.find(run.id)), true);
        expect(
          gameplayPlanCovered(
            current.copyWith(revision: current.revision + 1),
            c.find(run.id),
          ),
          false,
        );
        final second = (await c.startGameplayTestRun(current, 'B'))!;
        expect(gameplayRunPassed(second), false);
        expect(c.find(plan.id)!.body, current.body);
        expect(await c.startGameplayTestRun(current, ''), isNull);
        await c.closeWorkspace();
      } finally {
        container.dispose();
      }
      final (reopened, restored) = await open(
        WorkspaceRepository(
          store: GameplayNativeStore(root.path),
          index: MemoryObjectIndex(),
        ),
      );
      try {
        expect(gameplayRunPassed(restored.find(runId)!), true);
        expect(restored.find(runId)!.properties['testPlanId'], planId);
        expect(restored.find(planId)!.body, contains('- [ ] Reconnect'));
      } finally {
        await restored.closeWorkspace();
        reopened.dispose();
        await root.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'release workspace fits narrow enlarged text and shows unknown coverage',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (container, c) = (await tester.runAsync(
        () => open(memory(MemoryStore())),
      ))!;
      final m = (await tester.runAsync(
        () => c.createMechanicDesignDoc(folder: 'Notes', title: 'Jump'),
      ))!;
      addTearDown(() {
        c.cancelAllTimers();
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: GameplayReleaseWorkspace(
                controller: c,
                mechanicIds: [m.id],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Playtest & Release'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Choose a release build to see readiness and regressions.'),
        200,
      );
      expect(
        find.text('Choose a release build to see readiness and regressions.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('Save test plan'), 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'release commands retain recoverable edits on save failure and reject unsupported plans',
    () async {
      final store = MemoryStore();
      final (container, c) = await open(memory(store));
      try {
        final m = (await c.createMechanicDesignDoc(
          folder: 'Notes',
          title: 'Jump',
        ))!;
        expect(
          await c.createGameplayTestPlan(
            mechanicId: m.id,
            title: 'Empty',
            checklist: '```\n- [ ] Example\n```',
          ),
          isNull,
        );
        final plan = (await c.createGameplayTestPlan(
          mechanicId: m.id,
          title: 'Checks',
          checklist: '- [ ] Jump',
        ))!;
        final run = (await c.startGameplayTestRun(plan, 'build'))!;
        store.failWrites = true;
        expect(await c.setGameplayTestOutcome(run, 'failed'), false);
        expect(c.find(run.id)!.properties['testOutcome'], 'failed');
        expect(c.dirty, contains(run.id));
        store.failWrites = false;
        await c.flush(run.id);
        expect(c.dirty, isNot(contains(run.id)));
        c.edit(
          plan.id,
          properties: {...plan.properties, 'gameplayVersion': 99},
        );
        await c.flush(plan.id);
        expect(await c.startGameplayTestRun(c.find(plan.id)!, 'next'), isNull);
        expect(c.find(plan.id)!.properties['gameplayVersion'], 99);
      } finally {
        store.failWrites = false;
        await c.closeWorkspace();
        container.dispose();
      }
    },
  );

  test(
    'code references distinguish moving branches, reject traversal and retain exact fenced excerpts',
    () {
      code().validate();
      code(revision: 'b' * 64).validate();
      for (final revision in ['main', 'a123456', 'z' * 40]) {
        expect(
          () => code(revision: revision).validate(),
          throwsFormatException,
        );
      }
      for (final path in [
        '../secret',
        '/etc/file',
        r'C:\code',
        'src/../file',
        'src//file',
      ]) {
        expect(() => code(path: path).validate(), throwsFormatException);
      }
      const excerpt = '```\r\nUnicode 😀\n`value`';
      expect(code(excerpt: excerpt).markdown, contains('````\n$excerpt\n````'));
      expect(code().toJson()['branch'], 'main');
    },
  );

  test(
    'mechanic, code, build playtest, fix and verification survive native restart',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-gameplay-');
      final (container, c) = await open(
        WorkspaceRepository(
          store: GameplayNativeStore(root.path),
          index: MemoryObjectIndex(),
        ),
      );
      final mechanic = (await c.createMechanicDesignDoc(
        folder: 'Notes',
        title: 'Jump',
        project: 'Forest',
      ))!;
      final screenshot = (await c.create('orbit.file', title: 'Screenshot'))!;
      final source = (await c.createGameplayRecord(
        mechanicId: mechanic.id,
        kind: 'code',
        title: 'Jump implementation',
        code: code(),
      ))!;
      final playtest = (await c.createGameplayRecord(
        mechanicId: mechanic.id,
        kind: 'playtest',
        title: 'Late jump',
        build: '0.3-win',
        expected: 'Jump after ledge',
        observed: 'No jump',
        resources: [screenshot.id, source.id],
      ))!;
      final task = (await c.createTaskFromFinding(
        finding: 'Add coyote time',
        sourceNoteId: playtest.id,
      ))!;
      expect(task.properties['mechanicId'], mechanic.id);
      expect(task.properties['build'], '0.3-win');
      for (final outcome in ['failed', 'passed']) {
        expect(
          await c.createGameplayRecord(
            mechanicId: mechanic.id,
            kind: 'verification',
            title: 'Retest $outcome',
            taskId: task.id,
            build: '0.4-win',
            expected: 'Jump after ledge',
            observed: 'Recorded result',
            outcome: outcome,
            resources: [source.id],
          ),
          isNotNull,
        );
      }
      expect(c.find(task.id)!.isCompleted, false);
      expect(c.find(playtest.id)!.body, contains(task.id));
      c.edit(
        mechanic.id,
        properties: {
          ...c.find(mechanic.id)!.properties,
          'unknownFutureField': {'keep': true},
        },
      );
      await c.flush(mechanic.id);
      expect(
        await c.linkGameplayResource(c.find(mechanic.id)!, screenshot.id),
        true,
      );
      c.openObject(source.id);
      c.session.positions[source.id] = 27;
      expect(await c.saveGameplayResume(mechanic.id, 'Retest jumping'), true);
      await c.closeWorkspace();
      container.dispose();
      final (againContainer, again) = await open(
        WorkspaceRepository(
          store: GameplayNativeStore(root.path),
          index: MemoryObjectIndex(),
        ),
      );
      try {
        expect(again.gameplayRelated(mechanic.id).length, 6);
        expect(
          again.find(source.id)!.properties['codeReference'],
          code().toJson(),
        );
        expect(again.find(source.id)!.body, contains('jump();'));
        expect(again.find(mechanic.id)!.properties['unknownFutureField'], {
          'keep': true,
        });
        expect(
          again.gameplayResume(mechanic.id)?['gameplayNextStep'],
          'Retest jumping',
        );
        expect(await again.resumeGameplay(mechanic.id), true);
        expect(again.session.positions[source.id], 27);
        expect(
          await again.linkGameplayResource(
            again.find(mechanic.id)!,
            screenshot.id,
            remove: true,
          ),
          true,
        );
        expect(again.find(screenshot.id)!.isDeleted, false);
      } finally {
        await again.closeWorkspace();
        againContainer.dispose();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'invalid and interrupted records do not report success or overwrite changed sources',
    () async {
      final store = MemoryStore();
      final (container, c) = await open(memory(store));
      try {
        final m = (await c.createMechanicDesignDoc(
          folder: 'Notes',
          title: 'Jump',
        ))!;
        expect(
          await c.createGameplayRecord(
            mechanicId: m.id,
            kind: 'playtest',
            title: 'Test',
          ),
          isNull,
        );
        expect(
          await c.createGameplayRecord(
            mechanicId: m.id,
            kind: 'verification',
            title: 'Test',
            taskId: 'missing',
            build: '1',
            expected: 'A',
            observed: 'B',
            outcome: 'passed',
          ),
          isNull,
        );
        final gate = Completer<void>();
        store.writeGate = gate.future;
        c.edit(m.id, body: 'First edit');
        final pending = c.createGameplayRecord(
          mechanicId: m.id,
          kind: 'code',
          title: 'Evidence',
          code: code(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        c.edit(m.id, body: 'Newer edit');
        gate.complete();
        store.writeGate = null;
        expect(await pending, isNull);
        expect(c.find(m.id)!.body, 'Newer edit');
        await c.flushAll();
        store.failWrites = true;
        expect(
          await c.createGameplayRecord(
            mechanicId: m.id,
            kind: 'code',
            title: 'Failed evidence',
            code: code(),
          ),
          isNull,
        );
        store.failWrites = false;
        c.edit(
          m.id,
          properties: {...c.find(m.id)!.properties, 'gameplayVersion': 99},
        );
        await c.flush(m.id);
        expect(
          await c.createGameplayRecord(
            mechanicId: m.id,
            kind: 'code',
            title: 'Unsupported',
            code: code(),
          ),
          isNull,
        );
        expect(c.find(m.id)!.properties['gameplayVersion'], 99);
      } finally {
        store.failWrites = false;
        await c.closeWorkspace();
        container.dispose();
      }
    },
  );

  test(
    'resume resets changed positions, skips missing sources and preserves unrelated tabs',
    () async {
      final (container, c) = await open(memory(MemoryStore()));
      try {
        final m = (await c.createMechanicDesignDoc(
          folder: 'Notes',
          title: 'Jump',
        ))!;
        final source = (await c.createGameplayRecord(
          mechanicId: m.id,
          kind: 'code',
          title: 'Code',
          code: code(),
        ))!;
        final board = (await c.create('orbit.canvas', title: 'Diagram'))!;
        await c.linkGameplayResource(c.find(m.id)!, board.id);
        c.openObject(m.id);
        c.openObject(source.id);
        c.openObject(board.id);
        c.session.positions[source.id] = 33;
        c.session.cameras[board.id] = {'x': 10, 'y': 20, 'zoom': 2};
        expect(await c.saveGameplayResume(m.id, 'Next'), true);
        c.edit(source.id, body: 'Edited evidence');
        await c.flush(source.id);
        final other = (await c.create('orbit.note', title: 'Unrelated'))!;
        c.session.positions[other.id] = 99;
        c.session.cameras.clear();
        expect(await c.resumeGameplay(m.id), true);
        expect(c.session.positions.containsKey(source.id), false);
        expect(c.session.positions[other.id], 99);
        expect(c.session.tabs, contains(other.id));
        expect(c.session.cameras[board.id]!['zoom'], 2);
      } finally {
        await c.closeWorkspace();
        container.dispose();
      }
    },
  );

  testWidgets(
    'playtest form creates a linked build record and rejects a stale specification',
    (tester) async {
      final (container, c) = (await tester.runAsync(
        () => open(memory(MemoryStore())),
      ))!;
      final m = (await tester.runAsync(
        () => c.createMechanicDesignDoc(
          folder: 'Notes',
          title: 'Jump',
          project: 'Forest',
        ),
      ))!;
      addTearDown(() async {
        c.cancelAllTimers();
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GameplayWorkbench(
              controller: c,
              project: 'Forest',
              folder: 'Notes',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Jump'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record playtest'));
      await tester.pumpAndSettle();
      for (final e in {
        'title': 'Ledge jump',
        'build': 'build-7',
        'expected': 'Jump succeeds',
        'observed': 'Jump missed',
      }.entries) {
        await tester.enterText(
          find.byKey(ValueKey('gameplay-${e.key}')),
          e.value,
        );
      }
      await tester.tap(find.text('Save record'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(c.gameplayRelated(m.id).single.properties['build'], 'build-7');
      await tester.ensureVisible(find.text('Record playtest'));
      await tester.tap(find.text('Record playtest'));
      await tester.pumpAndSettle();
      c.edit(m.id, body: 'New specification');
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(
        find.text('The mechanic changed. Close and reopen this form.'),
        findsOneWidget,
      );
      expect(c.gameplayRelated(m.id).length, 1);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'workbench and code form remain usable at narrow width and 200% text',
    (tester) async {
      final (container, c) = (await tester.runAsync(
        () => open(memory(MemoryStore())),
      ))!;
      final m = (await tester.runAsync(
        () => c.createMechanicDesignDoc(
          folder: 'Notes',
          title: 'Jump',
          project: 'Forest',
        ),
      ))!;
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() async {
        await tester.runAsync(() => c.closeWorkspace());
        container.dispose();
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: GameplayWorkbench(
                controller: c,
                project: 'Forest',
                folder: 'Notes',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, m.title));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Attach code reference'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attach code reference'));
      await tester.pumpAndSettle();
      expect(find.text('Full Git commit hash'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );
}
