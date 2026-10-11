import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/workspace_shell.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  group('SessionState bookmarkedTabs Serialization', () {
    test('serializes and deserializes bookmarkedTabs correctly', () {
      final state = SessionState(
        activeId: 'note-1',
        tabs: ['note-1', 'note-2', 'note-3'],
        bookmarkedTabs: ['note-1', 'note-3'],
      );

      final json = state.toJson();
      expect(json['bookmarkedTabs'], ['note-1', 'note-3']);

      final restored = SessionState.fromJson(json);
      expect(restored.bookmarkedTabs, ['note-1', 'note-3']);
    });

    test('handles missing or malformed bookmarkedTabs gracefully', () {
      final json = {'activeId': 'note-1'};
      final restored = SessionState.fromJson(json);
      expect(restored.bookmarkedTabs, isEmpty);

      final jsonWithDuplicates = {
        'bookmarkedTabs': ['note-1', 'note-1', 'note-2'],
      };
      final deduped = SessionState.fromJson(jsonWithDuplicates);
      expect(deduped.bookmarkedTabs, ['note-1', 'note-2']);
    });
  });

  group('WorkspaceController Bookmark Operations', () {
    late WorkspaceController controller;
    late WorkspaceRepository repo;

    setUp(() {
      final store = MemoryStore();
      final index = MemoryObjectIndex();
      repo = WorkspaceRepository(store: store, index: index);
      controller = WorkspaceController();
      controller.repository = repo;
      controller.session = SessionState(
        tabs: ['note-1', 'note-2'],
        activeId: 'note-1',
      );
      controller.objects = [
        UniversalObject(
          id: 'note-1',
          workspaceId: 'ws-1',
          typeId: 'orbit.note',
          title: 'First Note',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        UniversalObject(
          id: 'note-2',
          workspaceId: 'ws-1',
          typeId: 'orbit.note',
          title: 'Second Note',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
    });

    test('toggleBookmark bookmarks and unbookmarks tabs', () {
      expect(controller.isBookmarked('note-1'), isFalse);

      controller.toggleBookmark('note-1');
      expect(controller.isBookmarked('note-1'), isTrue);
      expect(controller.session.bookmarkedTabs, contains('note-1'));

      controller.toggleBookmark('note-1');
      expect(controller.isBookmarked('note-1'), isFalse);
      expect(controller.session.bookmarkedTabs, isNot(contains('note-1')));
    });

    test('bookmarkTab and unbookmarkTab are idempotent', () {
      controller.bookmarkTab('note-1');
      controller.bookmarkTab('note-1');
      expect(controller.session.bookmarkedTabs, ['note-1']);

      controller.bookmarkTab('note-2');
      expect(controller.session.bookmarkedTabs, ['note-1', 'note-2']);

      controller.unbookmarkTab('note-1');
      expect(controller.isBookmarked('note-1'), isFalse);
      expect(controller.isBookmarked('note-2'), isTrue);

      controller.unbookmarkTab('note-1');
      expect(controller.session.bookmarkedTabs, ['note-2']);
    });

    test('bookmarkedObjects returns universal objects for bookmarked tabs', () {
      controller.bookmarkTab('note-1');
      controller.bookmarkTab('non-existent');

      final bookmarks = controller.bookmarkedObjects;
      expect(bookmarks.length, 1);
      expect(bookmarks.first.id, 'note-1');
      expect(bookmarks.first.title, 'First Note');
    });
  });

  group('WorkspaceShell Tab Bar & Bookmarking UI', () {
    testWidgets('renders bookmark icon and toggles bookmark on click', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = MemoryStore();
      final index = MemoryObjectIndex();
      final repo = WorkspaceRepository(store: store, index: index);

      final note = UniversalObject(
        id: 'note-1',
        workspaceId: 'ws-1',
        typeId: 'orbit.note',
        title: 'Bookmarked Note',
        body: 'Hello world',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.initialize();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();
      c.objects = [note];
      c.hasWorkspace = true;
      c.loading = false;
      c.session.activeId = 'note-1';
      c.session.tabs = ['note-1'];
      c.session.bookmarkedTabs = [];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WorkspaceShell()),
        ),
      );
      await tester.pumpAndSettle();

      // Find the bookmark icon button for note-1
      final bookmarkBtn = find.byKey(const ValueKey('tab-bookmark-note-1'));
      expect(bookmarkBtn, findsOneWidget);

      // Initially not bookmarked
      expect(c.isBookmarked('note-1'), isFalse);

      // Tap bookmark button
      await tester.tap(bookmarkBtn);
      await tester.pumpAndSettle();

      // Should now be bookmarked
      expect(c.isBookmarked('note-1'), isTrue);

      // Tap again to unbookmark
      await tester.tap(bookmarkBtn);
      await tester.pumpAndSettle();
      expect(c.isBookmarked('note-1'), isFalse);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('Ctrl+Shift+D toggles bookmark on active tab', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = MemoryStore();
      final index = MemoryObjectIndex();
      final repo = WorkspaceRepository(store: store, index: index);

      final note = UniversalObject(
        id: 'note-1',
        workspaceId: 'ws-1',
        typeId: 'orbit.note',
        title: 'Shortcut Note',
        body: 'Prose',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.initialize();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();
      c.objects = [note];
      c.hasWorkspace = true;
      c.loading = false;
      c.session.activeId = 'note-1';
      c.session.tabs = ['note-1'];
      c.session.bookmarkedTabs = [];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WorkspaceShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(c.isBookmarked('note-1'), isFalse);

      // Trigger Ctrl+Shift+D
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      expect(c.isBookmarked('note-1'), isTrue);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('new tab button and bookmarks menu button are visible', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = MemoryStore();
      final index = MemoryObjectIndex();
      final repo = WorkspaceRepository(store: store, index: index);

      final note = UniversalObject(
        id: 'note-1',
        workspaceId: 'ws-1',
        typeId: 'orbit.note',
        title: 'First Note',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.initialize();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();
      c.objects = [note];
      c.hasWorkspace = true;
      c.loading = false;
      c.session.activeId = 'note-1';
      c.session.tabs = ['note-1'];
      c.session.bookmarkedTabs = ['note-1'];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WorkspaceShell()),
        ),
      );
      await tester.pumpAndSettle();

      // + New Tab button
      expect(find.byKey(const ValueKey('new-tab-button')), findsOneWidget);

      // Bookmarks menu button
      final bookmarksBtn = find.byKey(
        const ValueKey('workspace-bookmarks-button'),
      );
      expect(bookmarksBtn, findsOneWidget);

      // Tap bookmarks menu button to open dropdown
      await tester.tap(bookmarksBtn);
      await tester.pumpAndSettle();

      // Verify the bookmarked note appears in the popup menu
      expect(find.text('First Note'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
