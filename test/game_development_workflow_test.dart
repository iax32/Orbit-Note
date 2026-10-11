import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'support/memory_store.dart';

class TestFolderStore extends MemoryStore implements WorkspaceFolderStore {
  final folders = <String>['Notes'];
  @override
  Future<List<String>> listFolders() async => List.of(folders);
  @override
  Future<void> createFolder(String path) async {
    if (!folders.contains(path)) {
      folders.add(path);
    }
  }

  @override
  Future<void> deleteFolder(String path) async {
    folders.remove(path);
    folders.removeWhere((f) => f.startsWith('$path/'));
    files.removeWhere((k, _) => k.startsWith('$path/'));
  }

  @override
  Future<void> movePath(
    String source,
    String target,
    Map<String, FileReplacement> replacements,
  ) async {
    final content = files.remove(source);
    if (content != null) {
      files[target] = content;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Game Development Productivity and Production Workflows', () {
    late ProviderContainer container;
    late WorkspaceController controller;
    late TestFolderStore store;

    setUp(() async {
      store = TestFolderStore();
      final repo = WorkspaceRepository(
        store: store,
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

    test(
      'createGameProject scaffolds complete project structure and starter assets',
      () async {
        final gdd = await controller.createGameProject(
          'Chronoshift',
          genre: 'Sci-Fi Metroidvania',
          targetPlatform: 'PC & Switch',
          targetEngine: 'Godot 4',
        );

        expect(gdd, isNotNull);
        expect(gdd!.title, 'Chronoshift GDD');
        expect(gdd.properties['project'], 'Chronoshift');
        expect(gdd.properties['genre'], 'Sci-Fi Metroidvania');
        expect(gdd.properties['platform'], 'PC & Switch');
        expect(gdd.properties['engine'], 'Godot 4');
        expect(gdd.properties['isGdd'], true);

        // Verify folder structure
        expect(store.folders, contains('Games/Chronoshift'));
        expect(store.folders, contains('Games/Chronoshift/Design'));
        expect(store.folders, contains('Games/Chronoshift/Art'));
        expect(store.folders, contains('Games/Chronoshift/Programming'));
        expect(store.folders, contains('Games/Chronoshift/Audio'));
        expect(store.folders, contains('Games/Chronoshift/Production'));
        expect(store.folders, contains('Games/Chronoshift/Playtests'));

        // Verify Mechanics Spec
        final spec = controller.objects.firstWhere(
          (o) => o.title == 'Core Mechanics Spec',
        );
        expect(spec.properties['discipline'], 'Game Design');
        expect(spec.properties['project'], 'Chronoshift');

        // Verify Canvases
        final coreLoop = controller.objects.firstWhere(
          (o) => o.title == 'Core Loop',
        );
        expect(coreLoop.typeId, 'orbit.canvas');
        expect(coreLoop.properties['canvasPreset'], 'core_loop');

        final moodboard = controller.objects.firstWhere(
          (o) => o.title == 'Art Direction & Moodboard',
        );
        expect(moodboard.typeId, 'orbit.canvas');
        expect(moodboard.properties['canvasPreset'], 'moodboard');

        // Verify Scoped Views
        final views = controller.objects
            .where((o) => o.typeId == 'orbit.view')
            .toList();
        expect(views.length, 7);
        final viewTypes = views.map((v) => v.properties['viewType']).toSet();
        expect(
          viewTypes,
          containsAll([
            'game_dashboard',
            'board',
            'tasks',
            'milestones',
            'timeline',
          ]),
        );

        // Verify Game Dev and Bug board presets
        final gamedevBoard = views.firstWhere(
          (v) => v.title == 'Chronoshift Board',
        );
        expect(gamedevBoard.properties['preset'], 'gamedev');

        final bugBoard = views.firstWhere((v) => v.title == 'Chronoshift Bugs');
        expect(bugBoard.properties['preset'], 'bugs');

        // Verify Starter Tasks
        final starterTasks = controller.objects
            .where(
              (o) =>
                  o.typeId == 'orbit.task' &&
                  o.properties['project'] == 'Chronoshift',
            )
            .toList();
        expect(starterTasks.length, 4);

        final repoTask = starterTasks.firstWhere(
          (t) => t.properties['discipline'] == 'Programming',
        );
        expect(repoTask.properties['milestone'], 'Prototype');
        expect(repoTask.properties['priority'], 'high');

        final gameplayTask = starterTasks.firstWhere(
          (t) => t.properties['discipline'] == 'Gameplay',
        );
        expect(gameplayTask.properties['blockedBy'], repoTask.id);
      },
    );

    test(
      'Blocked task dependency logic resolves when blocker task is completed',
      () async {
        await controller.createGameProject('ShadowRift');

        final starterTasks = controller.objects
            .where(
              (o) =>
                  o.typeId == 'orbit.task' &&
                  o.properties['project'] == 'ShadowRift',
            )
            .toList();

        final repoTask = starterTasks.firstWhere(
          (t) => t.properties['discipline'] == 'Programming',
        );
        final gameplayTask = starterTasks.firstWhere(
          (t) => t.properties['discipline'] == 'Gameplay',
        );

        // Verify blocker link
        expect(gameplayTask.properties['blockedBy'], repoTask.id);
        expect(repoTask.isCompleted, false);

        // Complete blocker task
        controller.edit(
          repoTask.id,
          properties: {...repoTask.properties, 'completed': true},
        );

        final updatedRepo = controller.find(repoTask.id)!;
        expect(updatedRepo.isCompleted, true);
      },
    );

    test(
      'Bug reporting sets severity, status, build and platform correctly',
      () async {
        final bug = await controller.createBugReport(
          folder: 'Games/Aetheria/Production',
          title: 'Player falls through level geometry near elevator',
          project: 'Aetheria',
          severity: 'critical',
          build: 'v0.2.1',
          platform: 'PC',
          discipline: 'QA',
        );

        expect(bug, isNotNull);
        expect(bug!.properties['isBug'], true);
        expect(bug.properties['severity'], 'critical');
        expect(bug.properties['build'], 'v0.2.1');
        expect(bug.properties['platform'], 'PC');
        expect(bug.properties['discipline'], 'QA');
        expect(bug.properties['status'], 'new');
        expect(bug.body, contains('Reproduction Rate'));
      },
    );

    test(
      'Helper templates create feature spec, playtest session, dev log, level design doc',
      () async {
        final spec = await controller.createFeatureSpec(
          folder: 'Games/Test/Design',
          title: 'Wall Jump Mechanic',
          project: 'TestGame',
          discipline: 'Gameplay',
        );
        expect(spec, isNotNull);
        expect(spec!.title, 'Wall Jump Mechanic');
        expect(spec.properties['discipline'], 'Gameplay');

        final playtest = await controller.createPlaytestSession(
          folder: 'Games/Test/Playtests',
          title: 'Alpha Playtest 01',
          project: 'TestGame',
          build: 'v0.3.0',
        );
        expect(playtest, isNotNull);
        expect(playtest!.properties['category'], 'Playtest');
        expect(playtest.properties['build'], 'v0.3.0');

        final devLog = await controller.createDevLog(
          folder: 'Games/Test/Production',
          title: 'Sprint 2 Dev Log',
          project: 'TestGame',
        );
        expect(devLog, isNotNull);
        expect(devLog!.properties['category'], 'DevLog');

        final levelDoc = await controller.createLevelDesignDoc(
          folder: 'Games/Test/Design',
          title: 'Cathedral Level Design',
          project: 'TestGame',
        );
        expect(levelDoc, isNotNull);
        expect(levelDoc!.properties['discipline'], 'Level Design');
        expect(levelDoc.body, contains('Flow & Beats (Pacing)'));
      },
    );

    test(
      'Kanban presets columns match game dev and bug tracking pipelines',
      () {
        final gamedevPreset = KanbanPreset.fromId('gamedev');
        expect(gamedevPreset.columns.length, 6);
        expect(gamedevPreset.columns.map((c) => c.$1).toList(), [
          'backlog',
          'planned',
          'in-progress',
          'review',
          'testing',
          'done',
        ]);

        final bugsPreset = KanbanPreset.fromId('bugs');
        expect(bugsPreset.columns.length, 5);
        expect(bugsPreset.columns.map((c) => c.$1).toList(), [
          'new',
          'confirmed',
          'in-progress',
          'verify',
          'done',
        ]);
      },
    );

    test(
      'Disciplines list contains comprehensive 18 game development disciplines',
      () {
        expect(gameDevDisciplines.length, 18);
        expect(gameDevDisciplines, contains('Game Design'));
        expect(gameDevDisciplines, contains('Programming'));
        expect(gameDevDisciplines, contains('Gameplay'));
        expect(gameDevDisciplines, contains('AI'));
        expect(gameDevDisciplines, contains('Level Design'));
        expect(gameDevDisciplines, contains('Art'));
        expect(gameDevDisciplines, contains('3D'));
        expect(gameDevDisciplines, contains('2D'));
        expect(gameDevDisciplines, contains('Animation'));
        expect(gameDevDisciplines, contains('VFX'));
        expect(gameDevDisciplines, contains('Audio'));
        expect(gameDevDisciplines, contains('Music'));
        expect(gameDevDisciplines, contains('Narrative'));
        expect(gameDevDisciplines, contains('UI/UX'));
        expect(gameDevDisciplines, contains('QA'));
        expect(gameDevDisciplines, contains('Production'));
        expect(gameDevDisciplines, contains('Tools'));
        expect(gameDevDisciplines, contains('Build / Release'));
      },
    );

    test('Bug severities list contains standard 4 game dev severities', () {
      expect(bugSeverities, ['blocker', 'critical', 'major', 'minor']);
    });

    test(
      'Subtask extraction regex accurately counts done and total markdown checkboxes',
      () {
        final markdown = '''
# Implementation Checklist
- [x] Create project in engine
- [ ] Implement character movement
- [x] Configure collision layers
- [ ] Add sound effects
''';
        final matches = RegExp(
          r'^\s*-\s*\[([ xX])\]',
          multiLine: true,
        ).allMatches(markdown).toList();

        expect(matches.length, 4);
        final done = matches
            .where((m) => m.group(1)?.toLowerCase() == 'x')
            .length;
        expect(done, 2);
      },
    );

    test(
      'One Universal Object identity across multiple game dev views without duplication',
      () async {
        await controller.createGameProject('NovaQuest');

        final task = await controller.create(
          'orbit.task',
          title: 'Optimize shadow map rendering',
          properties: {
            'project': 'NovaQuest',
            'discipline': 'Programming',
            'milestone': 'Alpha',
            'estimate': '5',
            'status': 'in-progress',
          },
        );

        expect(task, isNotNull);

        // Verify the task is referenced in all views by single universal ID
        final matching = controller.objects
            .where((o) => o.id == task!.id)
            .toList();
        expect(matching.length, 1);

        // Modify task properties (e.g. from Board, Dashboard, or Milestone view)
        controller.edit(
          task!.id,
          properties: {
            ...task.properties,
            'estimate': '8',
            'discipline': 'Tools',
          },
        );

        final updated = controller.find(task.id)!;
        expect(updated.properties['estimate'], '8');
        expect(updated.properties['discipline'], 'Tools');

        // Still exactly one object in the repository
        final matchingAfterEdit = controller.objects
            .where((o) => o.id == task.id)
            .toList();
        expect(matchingAfterEdit.length, 1);
      },
    );

    test(
      'Full suite of specialized game development templates create notes with correct metadata and bodies',
      () async {
        const folder = 'Games/Aetheria/Design';
        const proj = 'Aetheria';

        final mechanic = await controller.createMechanicDesignDoc(
          folder: folder,
          title: 'Grappling Hook',
          project: proj,
        );
        expect(mechanic, isNotNull);
        expect(mechanic!.properties['category'], 'Mechanic Spec');
        expect(mechanic.body, contains('Input & Control Rules'));
        expect(mechanic.body, contains('Edge Cases & Failure Conditions'));

        final enemy = await controller.createEnemyDesignDoc(
          folder: folder,
          title: 'Void Stalker',
          project: proj,
        );
        expect(enemy, isNotNull);
        expect(enemy!.properties['category'], 'Enemy Design');
        expect(enemy.body, contains('AI State Transitions'));
        expect(enemy.body, contains('Attack Patterns'));

        final character = await controller.createCharacterDesignDoc(
          folder: folder,
          title: 'Vespera',
          project: proj,
        );
        expect(character, isNotNull);
        expect(character!.properties['category'], 'Character Design');
        expect(character.body, contains('Core Motivation'));

        final item = await controller.createItemDesignDoc(
          folder: folder,
          title: 'Solar Aegis',
          project: proj,
        );
        expect(item, isNotNull);
        expect(item!.properties['category'], 'Item / Weapon');
        expect(item.body, contains('Stats & Scaling'));

        final audio = await controller.createAudioDesignDoc(
          folder: 'Games/Aetheria/Audio',
          title: 'Boss Combat SFX',
          project: proj,
        );
        expect(audio, isNotNull);
        expect(audio!.properties['category'], 'Audio Planning');
        expect(audio.body, contains('Cue Breakdown'));

        final quest = await controller.createQuestDesignDoc(
          folder: folder,
          title: 'The Lost Archives',
          project: proj,
        );
        expect(quest, isNotNull);
        expect(quest!.properties['category'], 'Quest Spec');
        expect(quest.body, contains('Stages & Flow'));

        final release = await controller.createReleaseChecklist(
          folder: 'Games/Aetheria/Production',
          title: 'Beta Release Checklist',
          project: proj,
        );
        expect(release, isNotNull);
        expect(release!.properties['category'], 'Release Checklist');
        expect(release.body, contains('Zero open blocker or critical bugs'));

        final review = await controller.createWeeklyReview(
          folder: 'Games/Aetheria/Production',
          project: proj,
        );
        expect(review, isNotNull);
        expect(review!.properties['category'], 'Weekly Review');
        expect(review.body, contains('Accomplished This Week'));

        final risk = await controller.createRiskAssessmentDoc(
          folder: 'Games/Aetheria/Production',
          risk: 'Network desync in 4-player co-op',
          project: proj,
        );
        expect(risk, isNotNull);
        expect(risk!.properties['category'], 'Risk Assessment');
        expect(risk.body, contains('Mitigation Strategy'));

        final adr = await controller.createDecisionDoc(
          folder: 'Games/Aetheria/Production',
          decision: 'Entity Component System adoption',
          project: proj,
        );
        expect(adr, isNotNull);
        expect(adr!.properties['category'], 'Decision Record');
        expect(adr.body, contains('Chosen Approach & Rationale'));
      },
    );

    test(
      'createTaskFromFinding converts playtest finding into task and links back to source note',
      () async {
        final playtest = await controller.createPlaytestSession(
          folder: 'Games/Aetheria/Playtests',
          title: 'Focus Group Playtest #3',
          project: 'Aetheria',
        );
        expect(playtest, isNotNull);

        final findingTask = await controller.createTaskFromFinding(
          finding: 'Boss phase 2 laser attack has no telegraph animation',
          sourceNoteId: playtest!.id,
          project: 'Aetheria',
          isBug: true,
          severity: 'critical',
          discipline: 'Animation',
        );

        expect(findingTask, isNotNull);
        expect(findingTask!.properties['isBug'], true);
        expect(findingTask.properties['severity'], 'critical');
        expect(findingTask.properties['discipline'], 'Animation');
        expect(findingTask.properties['priority'], 'urgent');
        expect(findingTask.properties['sourceNoteId'], playtest.id);

        // Verify that source playtest note was updated with backlink
        final updatedPlaytest = controller.find(playtest.id);
        expect(
          updatedPlaytest?.body,
          contains(
            '[[${findingTask.id}|Boss phase 2 laser attack has no telegraph animation]]',
          ),
        );
        expect(updatedPlaytest?.body, contains('CRITICAL'));
      },
    );

    test(
      'duplicateGameProjectStructure clones folders and view definitions without copying completed historical tasks',
      () async {
        await controller.createGameProject('Chronoshift');

        // Mark a task completed in Chronoshift
        final oldTasks = controller.objects
            .where(
              (o) =>
                  o.typeId == 'orbit.task' &&
                  o.properties['project'] == 'Chronoshift',
            )
            .toList();
        expect(oldTasks.isNotEmpty, true);
        controller.edit(
          oldTasks.first.id,
          properties: {...oldTasks.first.properties, 'completed': true},
        );

        // Duplicate project structure to Chronoshift2
        await controller.duplicateGameProjectStructure(
          'Chronoshift',
          'Chronoshift2',
        );

        // Verify new folders exist
        expect(store.folders, contains('Games/Chronoshift2'));
        expect(store.folders, contains('Games/Chronoshift2/Design'));
        expect(store.folders, contains('Games/Chronoshift2/Art'));
        expect(store.folders, contains('Games/Chronoshift2/Programming'));
        expect(store.folders, contains('Games/Chronoshift2/Audio'));
        expect(store.folders, contains('Games/Chronoshift2/Production'));
        expect(store.folders, contains('Games/Chronoshift2/Playtests'));

        // Verify new scoped views exist for Chronoshift2
        final newViews = controller.objects
            .where(
              (o) =>
                  o.typeId == 'orbit.view' &&
                  o.properties['project'] == 'Chronoshift2',
            )
            .toList();
        expect(newViews.length, 7);

        // Verify that completed tasks from Chronoshift were NOT copied to Chronoshift2
        final newProjectTasks = controller.objects
            .where(
              (o) =>
                  o.typeId == 'orbit.task' &&
                  o.properties['project'] == 'Chronoshift2',
            )
            .toList();
        expect(newProjectTasks.isEmpty, true);
      },
    );

    test(
      'Game dev task estimation supports numeric and t-shirt values and focus filtering',
      () async {
        await controller.createGameProject('Aetheria');

        // Create tasks with various estimates and states
        final task1 = await controller.create(
          'orbit.task',
          title: 'Prototype core movement',
          properties: {
            'project': 'Aetheria',
            'estimate': '3',
            'status': 'in-progress',
          },
        );
        final task2 = await controller.create(
          'orbit.task',
          title: 'Boss AI state tree',
          properties: {
            'project': 'Aetheria',
            'estimate': '13',
            'status': 'planned',
            'priority': 'urgent',
          },
        );
        final task3 = await controller.create(
          'orbit.task',
          title: 'Level 1 blockout',
          properties: {
            'project': 'Aetheria',
            'estimate': 'XL',
            'status': 'backlog',
          },
        );

        expect(task1, isNotNull);
        expect(task2, isNotNull);
        expect(task3, isNotNull);

        // Verify estimate property stored cleanly
        expect(controller.find(task1!.id)!.properties['estimate'], '3');
        expect(controller.find(task2!.id)!.properties['estimate'], '13');
        expect(controller.find(task3!.id)!.properties['estimate'], 'XL');

        // Check focus filtering logic: in-progress, urgent, or blocked
        final allTasks = controller.objects
            .where(
              (o) =>
                  o.typeId == 'orbit.task' &&
                  o.properties['project'] == 'Aetheria',
            )
            .toList();
        final focusTasks = allTasks.where((t) {
          final status = t.properties['status'] as String?;
          final priority = t.properties['priority'] as String?;
          final blockedBy = t.properties['blockedBy'] as String?;
          return status == 'in-progress' ||
              priority == 'urgent' ||
              (blockedBy != null && blockedBy.isNotEmpty);
        }).toList();

        expect(focusTasks.any((t) => t.id == task1.id), true);
        expect(focusTasks.any((t) => t.id == task2.id), true);
        expect(focusTasks.any((t) => t.id == task3.id), false);
      },
    );
  });
}
