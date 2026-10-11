import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/canvas/canvas_rich_text.dart';
import 'package:orbit_note/features/notes/latex/latex_templates.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_template_dialog.dart';
import 'package:orbit_note/features/notes/note_templates.dart';
import 'package:orbit_note/features/workspace/workspace_shell.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

import 'support/memory_store.dart';

Widget host(Widget child) => MaterialApp(
  theme: orbitDarkTheme(),
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoteTemplates Catalog & Search (EDT-09, STUDY-02)', () {
    test('contains expected structured template catalog', () {
      expect(NoteTemplates.all.length, greaterThanOrEqualTo(7));

      final cornell = NoteTemplates.byId('cornell');
      expect(cornell, isNotNull);
      expect(cornell!.name, 'Cornell Notes');
      expect(cornell.tags, contains('cornell'));
      expect(cornell.body, contains('## Cue Column / Keywords'));
      expect(cornell.body, contains('## Notes Area'));
      expect(cornell.body, contains('## Summary'));

      final meeting = NoteTemplates.byId('meeting');
      expect(meeting, isNotNull);
      expect(meeting!.name, contains('Meeting'));
      expect(meeting.body, contains('## Action Items'));

      final lit = NoteTemplates.byId('literature');
      expect(lit, isNotNull);
      expect(lit!.body, contains('## Core Thesis'));

      final rfc = NoteTemplates.byId('project_rfc');
      expect(rfc, isNotNull);
      expect(rfc!.body, contains('## 1. Summary & Motivation'));

      final blank = NoteTemplates.byId('blank');
      expect(blank, isNotNull);
      expect(blank!.body, isEmpty);

      final design = NoteTemplates.byId('software_design');
      expect(design, isNotNull);
      expect(design!.body, contains('## Acceptance checks'));
      expect(NoteTemplates.byId('research_log')!.tags, contains('research'));
      expect(
        NoteTemplates.byId('book_notes')!.body,
        contains('Quotes to revisit'),
      );
    });

    test('search filters templates by title, tag, or content correctly', () {
      final studyResults = NoteTemplates.search('study');
      expect(studyResults.any((t) => t.id == 'cornell'), isTrue);

      final meetingResults = NoteTemplates.search('agenda');
      expect(meetingResults.any((t) => t.id == 'meeting'), isTrue);

      final rfcResults = NoteTemplates.search('rfc');
      expect(rfcResults.any((t) => t.id == 'project_rfc'), isTrue);

      final nonExistent = NoteTemplates.search('supercalifragilistic');
      expect(nonExistent, isEmpty);

      final emptyQuery = NoteTemplates.search('');
      expect(emptyQuery.length, equals(NoteTemplates.all.length));
    });
  });

  group('LaTeX Theorems, Definitions & Proofs (EDT-12, NOTE-07)', () {
    test(
      'LatexTemplates contains theoremProof template with AMS environments',
      () {
        final theoremTemplate = LatexTemplates.all.firstWhere(
          (t) => t.id == 'theorem_proof',
        );
        expect(theoremTemplate.name, contains('Theorems'));
        expect(theoremTemplate.body, contains(r'\newtheorem{theorem}'));
        expect(theoremTemplate.body, contains(r'\begin{theorem}'));
        expect(theoremTemplate.body, contains(r'\begin{proof}'));
      },
    );

    test('CanvasRichText formats theorems, proofs, and blackboard bold sets', () {
      final theoremText = CanvasRichText.formatMathToUnicode(
        r'\begin{theorem}[Cauchy-Schwarz] |x \cdot y| \le \|x\| \|y\| \end{theorem}',
      );
      expect(theoremText, contains('[Theorem (Cauchy-Schwarz)]'));
      expect(theoremText, contains('≤'));

      final proofText = CanvasRichText.formatMathToUnicode(
        r'\begin{proof} By direct calculation. \qed \end{proof}',
      );
      expect(proofText, contains('[Proof]'));
      expect(proofText, contains('∎'));

      final setsText = CanvasRichText.formatMathToUnicode(
        r'x \in \mathbb{R} \land z \in \mathbb{C}',
      );
      expect(setsText, contains('x ∈ ℝ ∧ z ∈ ℂ'));
    });
  });

  group('NoteTemplateDialog Widget (EDT-09, STUDY-02)', () {
    testWidgets(
      'renders search field, template list and returns selected template',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        NoteTemplate? selected;

        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selected = await NoteTemplateDialog.show(context);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        );

        // Open dialog
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Verify search field and initial template list
        expect(
          find.byKey(const ValueKey('note-template-search-field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('template-item-cornell')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('template-item-meeting')),
          findsOneWidget,
        );

        // Type in search field
        await tester.enterText(
          find.byKey(const ValueKey('note-template-search-field')),
          'Meeting',
        );
        await tester.pumpAndSettle();

        // Only Meeting template should be visible
        expect(
          find.byKey(const ValueKey('template-item-meeting')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('template-item-cornell')),
          findsNothing,
        );

        // Select Meeting template item
        await tester.tap(find.byKey(const ValueKey('template-item-meeting')));
        await tester.pumpAndSettle();

        // Submit via Create Note button
        final createBtn = find.byKey(
          const ValueKey('create-note-from-template-button'),
        );
        expect(createBtn, findsOneWidget);
        await tester.tap(createBtn);
        await tester.pumpAndSettle();

        expect(selected, isNotNull);
        expect(selected!.id, 'meeting');
      },
    );
  });

  group('WorkspaceShell Template Creation Integration (EDT-09)', () {
    testWidgets('header plus menu displays New Note from Template option', (
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

      // Find the header add/import button
      final addBtnFinder = find.byIcon(Icons.add_circle_outline);
      expect(addBtnFinder, findsOneWidget);
      await tester.tap(addBtnFinder);
      await tester.pumpAndSettle();

      // Expect template option to be present
      expect(
        find.byKey(const ValueKey('new-note-from-template')),
        findsOneWidget,
      );
      expect(find.text('New Note from Template…'), findsOneWidget);
    });
  });

  group('NoteEditor Word Goal Milestone Badge (EDT-13, MOT-04)', () {
    testWidgets('renders progress percentage and milestone completion state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Incomplete goal: 5 words out of 10
      await tester.pumpWidget(
        host(
          NoteEditor(
            noteId: 'note-test-goal',
            title: 'Goal Essay',
            body: 'One two three four five.',
            onTitleChanged: (_) {},
            onBodyChanged: (_) {},
            linkTargets: const [],
            onOpenObject: (_) {},
            initialViewState: const {'targetWords': 10},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final goalBadge = find.byKey(const ValueKey('footer-target-goal-badge'));
      expect(goalBadge, findsOneWidget);
      expect(find.text('5/10 words (50%)'), findsOneWidget);

      // Complete goal: 12 words out of 10
      await tester.pumpWidget(
        host(
          NoteEditor(
            noteId: 'note-test-goal-complete',
            title: 'Goal Finished',
            body:
                'One two three four five six seven eight nine ten eleven twelve.',
            onTitleChanged: (_) {},
            onBodyChanged: (_) {},
            linkTargets: const [],
            onOpenObject: (_) {},
            initialViewState: const {'targetWords': 10},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(goalBadge, findsOneWidget);
      expect(find.text('✓ Goal reached (12/10)'), findsOneWidget);
    });
  });
}
