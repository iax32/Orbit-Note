import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/notes/word_goal_dialog.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/main.dart';
import 'support/memory_store.dart';

void main() {
  group('Navigation History Stack & Direct Jump', () {
    testWidgets('c.backHistory and c.forwardHistory track visited documents', (
      tester,
    ) async {
      final repository = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );

      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();

      final docA = (await c.create('orbit.note', title: 'Doc A'))!;
      final docB = (await c.create('orbit.note', title: 'Doc B'))!;
      final docC = (await c.create('orbit.note', title: 'Doc C'))!;

      expect(c.session.activeId, docC.id);
      expect(c.canNavigateBack, isTrue);
      expect(c.canNavigateForward, isFalse);

      // Back history should contain docB and docA (most recent first)
      final back = c.backHistory;
      expect(back.length, 2);
      expect(back[0].id, docB.id);
      expect(back[1].id, docA.id);

      // Jump directly to docA
      c.jumpToHistoryObject(docA.id);
      expect(c.session.activeId, docA.id);
      expect(c.canNavigateBack, isFalse);
      expect(c.canNavigateForward, isTrue);

      // Forward history should contain docB and docC
      final forward = c.forwardHistory;
      expect(forward.length, 2);
      expect(forward[0].id, docB.id);
      expect(forward[1].id, docC.id);

      // Jump forward to docC
      c.jumpToHistoryObject(docC.id);
      expect(c.session.activeId, docC.id);

      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets(
      'right-clicking back button shows history menu and jumps to selected document',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repository = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repository)],
            child: const OrbitNoteApp(),
          ),
        );
        await tester.pumpAndSettle();

        final c = ProviderScope.containerOf(
          tester.element(find.byType(OrbitNoteApp)),
        ).read(workspaceProvider.notifier);

        final doc1 = (await c.create('orbit.note', title: 'Alpha Note'))!;
        final doc2 = (await c.create('orbit.note', title: 'Beta Note'))!;
        final doc3 = (await c.create('orbit.note', title: 'Gamma Note'))!;

        c.openObject(doc1.id);
        await tester.pumpAndSettle();
        c.openObject(doc2.id);
        await tester.pumpAndSettle();
        c.openObject(doc3.id);
        await tester.pumpAndSettle();

        expect(c.session.activeId, doc3.id);

        // Secondary tap (right-click) on the back button
        final backBtn = find.byKey(const ValueKey('nav-back-button'));
        expect(backBtn, findsOneWidget);

        await tester.tap(backBtn, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        // History menu should appear showing Alpha Note and Beta Note
        expect(find.text('Beta Note'), findsWidgets);
        expect(find.text('Alpha Note'), findsWidgets);

        // Tap Alpha Note in the menu
        await tester.tap(find.text('Alpha Note').last);
        await tester.pumpAndSettle();

        // Should have jumped directly to doc1
        expect(c.session.activeId, doc1.id);

        await tester.pump(const Duration(milliseconds: 700));
      },
    );
  });

  group('Universal Document Duplication', () {
    testWidgets('c.duplicateObject clones notes, canvases, and properties', (
      tester,
    ) async {
      final repository = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );

      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();

      final note = (await c.create(
        'orbit.note',
        title: 'Project Roadmap',
        body: '# Roadmap\n- Milestones',
        properties: {'folder': 'Notes/Work', 'priority': 'high'},
      ))!;

      final duplicate = await c.duplicateObject(note.id);
      expect(duplicate, isNotNull);
      expect(duplicate!.title, 'Project Roadmap (Copy)');
      expect(duplicate.body, '# Roadmap\n- Milestones');
      expect(duplicate.properties['folder'], 'Notes/Work');
      expect(duplicate.properties['priority'], 'high');
      expect(duplicate.id, isNot(equals(note.id)));
      expect(c.session.activeId, duplicate.id);

      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('c.duplicateObjects batch duplicates multiple items', (
      tester,
    ) async {
      final repository = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );

      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();

      final item1 = (await c.create('orbit.task', title: 'Task One'))!;
      final item2 = (await c.create('orbit.task', title: 'Task Two'))!;

      final copies = await c.duplicateObjects([item1.id, item2.id]);
      expect(copies.length, 2);
      expect(copies[0].title, 'Task One (Copy)');
      expect(copies[1].title, 'Task Two (Copy)');

      await tester.pump(const Duration(milliseconds: 700));
    });
  });

  group('Word Goal Dialog & Progress Ring', () {
    testWidgets('WordGoalProgressRing renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: WordGoalProgressRing(progress: 0.75, size: 20)),
          ),
        ),
      );
      expect(find.byType(WordGoalProgressRing), findsOneWidget);
    });

    testWidgets(
      'WordGoalDialog displays presets, accepts custom goal, and applies it',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        int? updatedGoal;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showWordGoalDialog(
                    context,
                    currentWords: 350,
                    targetWords: 500,
                    onTargetWordsChanged: (val) => updatedGoal = val,
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.byType(WordGoalDialog), findsOneWidget);
        expect(find.text('Current count: 350 words'), findsOneWidget);
        expect(find.text('70% of goal'), findsOneWidget);

        // Tap preset chip '1000 (Article)'
        await tester.tap(find.text('1000 (Article)'));
        await tester.pumpAndSettle();

        expect(find.text('35% of goal'), findsOneWidget);

        // Tap 'Set Goal'
        final setBtn = find.byKey(const ValueKey('set-word-goal-button'));
        await tester.ensureVisible(setBtn);
        await tester.tap(setBtn);
        await tester.pumpAndSettle();

        expect(updatedGoal, 1000);
        expect(find.byType(WordGoalDialog), findsNothing);
      },
    );

    testWidgets('WordGoalDialog allows clearing active goal', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int? updatedGoal = 500;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showWordGoalDialog(
                  context,
                  currentWords: 200,
                  targetWords: 500,
                  onTargetWordsChanged: (val) => updatedGoal = val,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final clearBtn = find.byKey(const ValueKey('clear-word-goal-button'));
      expect(clearBtn, findsOneWidget);
      await tester.ensureVisible(clearBtn);

      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(updatedGoal, isNull);
      expect(find.byType(WordGoalDialog), findsNothing);
    });
  });
}
