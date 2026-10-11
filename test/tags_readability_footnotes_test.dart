import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/features/notes/document_stats_dialog.dart';
import 'package:orbit_note/features/notes/markdown_editing.dart';
import 'package:orbit_note/features/workspace/workspace_shell.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

import 'support/memory_store.dart';

Widget host(Widget child) => MaterialApp(
  theme: orbitDarkTheme(),
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentStats Readability & Complexity (EDT-13)', () {
    test('computes zero readability for empty text safely', () {
      final stats = DocumentStats.compute('');
      expect(stats.words, 0);
      expect(stats.characters, 0);
      expect(stats.sentences, 0);
      expect(stats.fleschReadingEase, 0.0);
      expect(stats.fleschKincaidGrade, 0.0);
      expect(stats.readingEaseLabel, 'N/A');
      expect(stats.gradeLevelLabel, 'N/A');
      expect(stats.averageSentenceLength, 0.0);
      expect(stats.averageWordLength, 0.0);
      expect(stats.syllables, 0);
    });

    test('computes high reading ease and elementary grade for simple prose', () {
      const simpleText =
          'The cat sat on the mat. The sun was hot. We had fun in the park. A dog ran to the ball.';
      final stats = DocumentStats.compute(simpleText);

      expect(stats.words, greaterThan(10));
      expect(stats.sentences, 4);
      // Flesch Reading Ease should be high (> 80)
      expect(stats.fleschReadingEase, greaterThan(75.0));
      expect(stats.readingEaseLabel, anyOf('Easy', 'Very Easy', 'Fairly Easy'));
      // Flesch-Kincaid Grade should be elementary (<= 5)
      expect(stats.fleschKincaidGrade, lessThanOrEqualTo(5.0));
      expect(stats.averageSentenceLength, lessThanOrEqualTo(6.0));
      expect(stats.syllables, greaterThan(10));
    });

    test('computes moderate readability for standard academic text', () {
      const academicText =
          'The quantum mechanical approximation demonstrates significant variability across multi-dimensional topological manifold spaces. '
          'Consequently, empirical observations necessitate rigorous mathematical validation prior to formal theoretical extrapolation.';
      final stats = DocumentStats.compute(academicText);

      expect(stats.words, greaterThan(15));
      expect(stats.sentences, 2);
      expect(stats.fleschReadingEase, lessThan(50.0));
      expect(
        stats.readingEaseLabel,
        anyOf('Difficult', 'Fairly Difficult', 'Very Difficult (Academic)'),
      );
      expect(stats.fleschKincaidGrade, greaterThan(10.0));
      expect(stats.averageSentenceLength, greaterThan(10.0));
    });

    test('formatSummary includes readability and grade level metrics', () {
      const text =
          'Orbit Note provides local-first offline knowledge management with fast mathematical typesetting and spatial canvas tools.';
      final stats = DocumentStats.compute(text);
      final summary = stats.formatSummary(title: 'Overview');

      expect(summary, contains('Statistics for: Overview'));
      expect(summary, contains('Readability:'));
      expect(summary, contains('Grade level:'));
      expect(summary, contains('Average sentence:'));
    });

    testWidgets('showDocumentStatsDialog renders Readability card with scores', (
      tester,
    ) async {
      const sampleText =
          'Here is a simple sentence. Another informative sentence follows it. Good work.';

      await tester.pumpWidget(
        host(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showDocumentStatsDialog(
                ctx,
                title: 'Design Spec',
                text: sampleText,
                isLatex: false,
              ),
              child: const Text('Open Stats'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Stats'));
      await tester.pumpAndSettle();

      expect(find.text('Document Analytics'), findsOneWidget);
      expect(find.text('Readability & Complexity'), findsOneWidget);
      expect(find.text('Reading Ease'), findsOneWidget);
      expect(find.text('Target Level'), findsOneWidget);
      expect(find.textContaining('Avg sentence:'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    });
  });

  group('MarkdownEditing.insertFootnote (EDT-12)', () {
    test('inserts first footnote [^1] and appends definition at end', () {
      const initial = 'This is an insightful claim about gravity.';
      final value = TextEditingValue(
        text: initial,
        selection: const TextSelection.collapsed(offset: 27), // after "claim"
      );

      final result = MarkdownEditing.insertFootnote(value);

      expect(
        result.text,
        startsWith('This is an insightful claim[^1] about gravity.'),
      );
      expect(result.text, endsWith('\n\n[^1]: '));
      expect(result.selection.start, result.text.length);
      expect(result.selection.isCollapsed, isTrue);
    });

    test('increments footnote index when [^1] already exists', () {
      const initial =
          'First observation[^1] is noted.\nSecond observation follows here.\n\n[^1]: Initial reference.';
      final value = TextEditingValue(
        text: initial,
        selection: const TextSelection.collapsed(offset: 50),
      );

      final result = MarkdownEditing.insertFootnote(value);

      expect(result.text, contains('[^2]'));
      expect(result.text, endsWith('\n\n[^2]: '));
      expect(result.selection.start, result.text.length);
    });

    test('increments to [^3] when [^1] and [^2] are present', () {
      const initial =
          'Point one[^1], point two[^2].\n\n[^1]: First\n[^2]: Second';
      final value = TextEditingValue(
        text: initial,
        selection: const TextSelection.collapsed(offset: 10),
      );

      final result = MarkdownEditing.insertFootnote(value);

      expect(result.text, contains('[^3]'));
      expect(result.text, endsWith('\n\n[^3]: '));
    });
  });

  group('WorkspaceController Tags Management & Filtering (TAG-01)', () {
    test('collects tags from object properties and hashtags in body', () async {
      final store = MemoryStore();
      final controller = WorkspaceController();
      controller.repository = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await controller.initialize();

      // Create note with properties tags
      final note1 = await controller.create(
        'orbit.note',
        title: 'Quantum Physics',
        body: 'Notes on wave mechanics and matrix representations.',
        properties: {
          'tags': ['physics', 'quantum', 'research'],
        },
      );
      expect(note1, isNotNull);

      // Create note with body hashtags
      final note2 = await controller.create(
        'orbit.note',
        title: 'Meeting Notes',
        body: 'Discussed project timelines with team. #planning #research',
      );
      expect(note2, isNotNull);

      // Verify allTags gathers and deduplicates
      final tags = controller.allTags;
      expect(tags, contains('physics'));
      expect(tags, contains('quantum'));
      expect(tags, contains('research'));
      expect(tags, contains('planning'));

      // Verify countForTag
      expect(controller.countForTag('research'), 2);
      expect(controller.countForTag('physics'), 1);
      expect(controller.countForTag('planning'), 1);
      expect(controller.countForTag('nonexistent'), 0);
    });

    test(
      'addTagToObject and removeTagFromObject modifies properties cleanly',
      () async {
        final store = MemoryStore();
        final controller = WorkspaceController();
        controller.repository = WorkspaceRepository(
          store: store,
          index: MemoryObjectIndex(),
        );
        await controller.initialize();

        final note = await controller.create(
          'orbit.note',
          title: 'Draft Document',
          body: 'Simple text.',
        );
        expect(note, isNotNull);

        // Add tags
        await controller.addTagToObject(note!.id, 'draft');
        await controller.addTagToObject(note.id, '#ideas');

        var updated = controller.find(note.id)!;
        expect(updated.properties['tags'], contains('draft'));
        expect(updated.properties['tags'], contains('ideas'));

        // Check tagsForObject
        expect(controller.tagsForObject(note.id), contains('draft'));
        expect(controller.tagsForObject(note.id), contains('ideas'));

        // Remove a tag
        await controller.removeTagFromObject(note.id, 'draft');
        updated = controller.find(note.id)!;
        expect(updated.properties['tags'], isNot(contains('draft')));
        expect(updated.properties['tags'], contains('ideas'));
      },
    );

    test('activeTagFilter filters objects and can be cleared', () async {
      final store = MemoryStore();
      final controller = WorkspaceController();
      controller.repository = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await controller.initialize();

      expect(controller.activeTagFilter, isNull);

      controller.activeTagFilter = 'research';
      expect(controller.activeTagFilter, 'research');

      controller.clearTagFilter();
      expect(controller.activeTagFilter, isNull);

      controller.activeTagFilter = '#math';
      expect(controller.activeTagFilter, 'math');
    });
  });

  group('WorkspaceShell Tag Filter Explorer UI (TAG-01)', () {
    testWidgets('renders tag filter button and applies tag filter', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize();

      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();

      await c.create(
        'orbit.note',
        title: 'Research Thesis',
        body: 'Detailed work on astronomy.',
        properties: {
          'tags': ['astronomy', 'research'],
        },
      );

      await c.create(
        'orbit.note',
        title: 'Grocery List',
        body: 'Milk, eggs, coffee.',
      );

      c.session.destination = OrbitDestination.notes;
      c.hasWorkspace = true;
      c.loading = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: host(const WorkspaceShell()),
        ),
      );
      await tester.pumpAndSettle();

      // Check tag filter button is present
      final tagBtnFinder = find.byKey(
        const ValueKey('explorer-tag-filter-button'),
      );
      expect(tagBtnFinder, findsOneWidget);

      // Initially both notes exist in the explorer list
      expect(find.widgetWithText(ListTile, 'Research Thesis'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Grocery List'), findsOneWidget);

      // Set active tag filter
      c.activeTagFilter = 'astronomy';
      await tester.pumpAndSettle();

      // Active tag banner appears
      expect(find.text('#astronomy'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Research Thesis'), findsOneWidget);
      // Grocery List should be excluded from the explorer list
      expect(find.widgetWithText(ListTile, 'Grocery List'), findsNothing);

      // Tap clear tag filter button
      final clearBtn = find.byKey(const ValueKey('clear-active-tag-filter'));
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // Both notes return in explorer
      expect(c.activeTagFilter, isNull);
      expect(find.widgetWithText(ListTile, 'Research Thesis'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Grocery List'), findsOneWidget);
    });
  });
}
