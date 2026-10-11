import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
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
  group('NoteEditor View State Restoration Hardening (EDT-15)', () {
    testWidgets(
      'didUpdateWidget restores mode, split ratio, and clamped selection across note switch',
      (tester) async {
        String currentNoteId = 'note-1';
        String currentTitle = 'First Note';
        String currentBody = 'This is the first note with some content.';
        Map<String, dynamic> currentViewState = {
          'mode': 'split',
          'splitRatio': 0.6,
          'base': 5,
          'extent': 10,
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => NoteEditor(
                  noteId: currentNoteId,
                  title: currentTitle,
                  body: currentBody,
                  onTitleChanged: (_) {},
                  onBodyChanged: (_) {},
                  linkTargets: const [],
                  onOpenObject: (_) {},
                  initialViewState: currentViewState,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to note-2 with write mode and different selection
        currentNoteId = 'note-2';
        currentTitle = 'Second Note';
        currentBody = 'Short';
        currentViewState = {
          'mode': 'write',
          'splitRatio': 0.5,
          'base': 2,
          'extent': 4,
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => NoteEditor(
                  noteId: currentNoteId,
                  title: currentTitle,
                  body: currentBody,
                  onTitleChanged: (_) {},
                  onBodyChanged: (_) {},
                  linkTargets: const [],
                  onOpenObject: (_) {},
                  initialViewState: currentViewState,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final field = find.byKey(const ValueKey('note-body'));
        expect(field, findsOneWidget);
        final controller = tester.widget<TextField>(field).controller!;
        expect(controller.text, 'Short');
        expect(controller.selection.baseOffset, 2);
        expect(controller.selection.extentOffset, 4);
      },
    );

    testWidgets(
      'clamped selection safely falls back when document is shortened without mutating content',
      (tester) async {
        final initialViewState = {
          'mode': 'write',
          'base': 500, // far beyond document length
          'extent': 600,
        };

        var bodyChanged = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteEditor(
                noteId: 'note-short',
                title: 'Short Document',
                body: 'Hello world',
                onTitleChanged: (_) {},
                onBodyChanged: (_) => bodyChanged = true,
                linkTargets: const [],
                onOpenObject: (_) {},
                initialViewState: initialViewState,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final field = find.byKey(const ValueKey('note-body'));
        final controller = tester.widget<TextField>(field).controller!;
        // Clamped safely to end of document (11)
        expect(controller.selection.baseOffset, 11);
        expect(controller.selection.extentOffset, 11);
        // Document content was NOT mutated
        expect(controller.text, 'Hello world');
        expect(bodyChanged, isFalse);
      },
    );
  });

  group('HomeView Continue Writing & Navigation Trail (CTX-10 & EDT-15)', () {
    testWidgets(
      'HomeView renders CONTINUE WRITING card for recent note and resumes writing',
      (tester) async {
        final env = await _setupTestWorkspace();
        final c = env.controller;

        // Create two notes
        final note1 = (await c.create(
          'orbit.note',
          title: 'Architecture Decisions',
        ))!;
        c.edit(
          note1.id,
          body: 'We decided on local-first storage and standard Markdown.',
        );

        final note2 = (await c.create(
          'orbit.note',
          title: 'Sprint Retrospective',
        ))!;
        c.edit(
          note2.id,
          body: 'The retrospective went really well with the team.',
        );

        // Update session recents
        c.updateSession((s) {
          s.recent = [note2.id, note1.id];
          s.destination = OrbitDestination.home;
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: env.container,
            child: MaterialApp(
              home: Scaffold(body: HomeView(controller: c)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check Continue Writing card exists
        expect(find.text('Continue writing'), findsOneWidget);
        expect(find.text('Sprint Retrospective'), findsWidgets);
        expect(find.text('Resume writing'), findsOneWidget);

        // Check Where was I trail exists
        await tester.scrollUntilVisible(
          find.text('Recent:'),
          180,
          scrollable: find
              .descendant(
                of: find.byType(HomeView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Recent:'), findsOneWidget);
        expect(find.text('Architecture Decisions'), findsWidgets);

        // Tap Resume writing -> should open note2
        await tester.ensureVisible(find.text('Resume writing'));
        await tester.tap(find.text('Resume writing'));
        await tester.pumpAndSettle();

        expect(c.session.activeId, note2.id);

        env.container.dispose();
      },
    );

    testWidgets('CommandPalette provides Continue writing shortcut', (
      tester,
    ) async {
      final env = await _setupTestWorkspace();
      final c = env.controller;

      final note = (await c.create('orbit.note', title: 'Research Findings'))!;
      c.updateSession((s) {
        s.recent = [note.id];
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: env.container,
          child: MaterialApp(
            home: Scaffold(body: CommandPalette(controller: c)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue writing: Research Findings'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      expect(find.text('Continue writing: Research Findings'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Continue writing  ');
      await tester.pumpAndSettle();
      expect(find.text('Continue writing: Research Findings'), findsOneWidget);

      // Tap Continue writing
      await tester.tap(find.text('Continue writing: Research Findings'));
      await tester.pumpAndSettle();

      expect(c.session.activeId, note.id);

      env.container.dispose();
    });
  });
}
