import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/workspace/note_folder_explorer.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/main.dart';
import 'support/memory_store.dart';

void main() {
  void setupDesktopViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Explorer Folder Collapse & Expand All', () {
    testWidgets(
      'c.allKnownFolders, collapseAllFolders, and expandAllFolders work correctly',
      (tester) async {
        final repository = WorkspaceRepository(
          store: FolderMemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();

        await repository.createFolder('Notes/Projects');
        await repository.createFolder('Notes/Projects/Design');
        await repository.createFolder('Notes/Archive');

        await c.create(
          'orbit.note',
          title: 'Project Spec',
          properties: {'folder': 'Notes/Projects/Design'},
        );

        final folders = c.allKnownFolders;
        expect(folders.contains('Notes'), isTrue);
        expect(folders.contains('Notes/Projects'), isTrue);
        expect(folders.contains('Notes/Projects/Design'), isTrue);
        expect(folders.contains('Notes/Archive'), isTrue);

        expect(c.areAllFoldersCollapsed, isFalse);

        c.collapseAllFolders();
        expect(c.areAllFoldersCollapsed, isTrue);
        expect(c.session.collapsedFolders.length, folders.length);

        c.expandAllFolders();
        expect(c.areAllFoldersCollapsed, isFalse);
        expect(c.session.collapsedFolders, isEmpty);

        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets('Explorer toolbar collapse/expand button toggles folders', (
      tester,
    ) async {
      setupDesktopViewport(tester);

      final repository = WorkspaceRepository(
        store: FolderMemoryStore(),
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();

      await repository.createFolder('Notes/FolderA');
      await repository.createFolder('Notes/FolderB');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const OrbitNoteApp(),
        ),
      );
      await tester.pumpAndSettle();

      c.navigate(OrbitDestination.notes);
      await tester.pumpAndSettle();

      final collapseButton = find.byKey(
        const ValueKey('explorer-collapse-expand-all'),
      );
      expect(collapseButton, findsOneWidget);

      // Initially expanded -> tap collapses all
      await tester.tap(collapseButton);
      await tester.pumpAndSettle();
      expect(c.areAllFoldersCollapsed, isTrue);

      // Now collapsed -> tap expands all
      await tester.tap(collapseButton);
      await tester.pumpAndSettle();
      expect(c.areAllFoldersCollapsed, isFalse);

      await tester.pump(const Duration(milliseconds: 700));
    });
  });

  group('Explorer Keyboard Shortcuts (Ctrl+D & Ctrl+Shift+E)', () {
    testWidgets(
      'Ctrl+Shift+E in NoteFolderExplorer toggles collapse/expand all',
      (tester) async {
        setupDesktopViewport(tester);

        final repository = WorkspaceRepository(
          store: FolderMemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();

        await repository.createFolder('Notes/Folder1');
        await repository.createFolder('Notes/Folder2');

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: NoteFolderExplorer(controller: c, notes: c.activeObjects),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Focus explorer and send Ctrl+Shift+E
        await tester.tap(find.text('Notes'));
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(c.areAllFoldersCollapsed, isTrue);

        // Send Ctrl+Shift+E again
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(c.areAllFoldersCollapsed, isFalse);

        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets('Ctrl+D in NoteFolderExplorer duplicates selected note', (
      tester,
    ) async {
      setupDesktopViewport(tester);

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

      await c.create('orbit.note', title: 'Original Doc');
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: NoteFolderExplorer(controller: c, notes: c.activeObjects),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Click on note row to select and focus it
      await tester.tap(find.text('Original Doc'));
      await tester.pumpAndSettle();

      // Press Ctrl+D
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // Expect duplicate created with (Copy) suffix
      final copies = c.activeObjects.where((o) => o.title.contains('(Copy)'));
      expect(copies.length, 1);
      expect(copies.first.title, 'Original Doc (Copy)');

      await tester.pump(const Duration(milliseconds: 700));
    });
  });

  group('NoteEditor Polish (Selection Counter, Metric Cycling, Copy All)', () {
    testWidgets(
      'note-line-col-indicator displays selection range when text is selected',
      (tester) async {
        setupDesktopViewport(tester);

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

        const content =
            'First line content here\nSecond line follows\nThird line ends';
        final note = (await c.create(
          'orbit.note',
          title: 'Selection Test',
          body: content,
        ))!;

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: NoteEditor(
                noteId: note.id,
                title: note.title,
                body: note.body,
                linkTargets: const [],
                onOpenObject: (_) {},
                initialViewState: const {'mode': 'write'},
                onBodyChanged: (_) {},
                onTitleChanged: (_) {},
                onViewStateChanged: (_) {},
                vaultName: 'Vault',
                folderPath: 'Notes',
                allFolders: const ['Notes'],
                allObjects: c.activeObjects,
                folderLookup: (_) => 'Notes',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initial indicator shows Ln 1, Col 1
        expect(find.textContaining('Ln 1, Col 1'), findsOneWidget);

        // Select single-line text in body TextField
        final bodyField = find.byKey(const ValueKey('note-body'));
        expect(bodyField, findsOneWidget);

        final textField = tester.widget<TextField>(bodyField);
        textField.controller!.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 10,
        );
        await tester.pump();

        // Expect indicator to show selection count
        expect(find.textContaining('(10 selected)'), findsOneWidget);

        // Multi-line selection spanning lines 1 and 2
        textField.controller!.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 30,
        );
        await tester.pump();

        expect(find.textContaining('(2 lines, 30 selected)'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets('Tapping document-stats-toggle cycles through metrics', (
      tester,
    ) async {
      setupDesktopViewport(tester);

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
        title: 'Metric Test',
        body: 'The quick brown fox jumps over the lazy dog.',
      ))!;

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: NoteEditor(
              noteId: note.id,
              title: note.title,
              body: note.body,
              linkTargets: const [],
              onOpenObject: (_) {},
              initialViewState: const {'mode': 'write'},
              onBodyChanged: (_) {},
              onTitleChanged: (_) {},
              onViewStateChanged: (_) {},
              vaultName: 'Vault',
              folderPath: 'Notes',
              allFolders: const ['Notes'],
              allObjects: c.activeObjects,
              folderLookup: (_) => 'Notes',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final statsToggle = find.byKey(const ValueKey('document-stats-toggle'));
      expect(statsToggle, findsOneWidget);

      // Mode 0: Default (9 words · 44 characters · ~1 min read)
      expect(find.textContaining('9 words'), findsOneWidget);

      // Tap 1 -> Mode 1: Characters only
      await tester.tap(statsToggle);
      await tester.pumpAndSettle();
      expect(find.text('44 characters'), findsOneWidget);

      // Tap 2 -> Mode 2: Chars no spaces
      await tester.tap(statsToggle);
      await tester.pumpAndSettle();
      expect(find.text('36 chars (no spaces)'), findsOneWidget);

      // Tap 3 -> Mode 3: Reading time
      await tester.tap(statsToggle);
      await tester.pumpAndSettle();
      expect(find.text('~1 min read (9 words)'), findsOneWidget);

      // Tap 4 -> Back to Mode 0
      await tester.tap(statsToggle);
      await tester.pumpAndSettle();
      expect(find.textContaining('9 words'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('Markdown option exists in note-copy-as-menu', (tester) async {
      setupDesktopViewport(tester);

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
        title: 'Copy Note',
        body: '# Heading\nSome markdown content',
      ))!;

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: NoteEditor(
              noteId: note.id,
              title: note.title,
              body: note.body,
              linkTargets: const [],
              onOpenObject: (_) {},
              initialViewState: const {'mode': 'write'},
              onBodyChanged: (_) {},
              onTitleChanged: (_) {},
              onViewStateChanged: (_) {},
              vaultName: 'Vault',
              folderPath: 'Notes',
              allFolders: const ['Notes'],
              allObjects: c.activeObjects,
              folderLookup: (_) => 'Notes',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final copyMenu = find.byKey(const ValueKey('note-copy-as-menu'));
      expect(copyMenu, findsOneWidget);

      await tester.tap(copyMenu);
      await tester.pumpAndSettle();

      final markdownItem = find.widgetWithText(
        PopupMenuItem<String>,
        'Markdown',
      );
      expect(markdownItem, findsOneWidget);

      await tester.tap(markdownItem);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Copied entire note to clipboard'),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
