import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/workspace/quick_switcher_dialog.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now();

  UniversalObject makeObject({
    required String id,
    required String title,
    String typeId = 'orbit.note',
    String body = '',
    Map<String, dynamic> properties = const {},
  }) {
    return UniversalObject(
      id: id,
      workspaceId: 'ws-1',
      typeId: typeId,
      title: title,
      body: body,
      properties: properties,
      data: const {},
      createdAt: now,
      updatedAt: now,
    );
  }

  group('QuickSwitcherDialog tests', () {
    late WorkspaceController controller;
    late UniversalObject note1;
    late UniversalObject note2;
    late UniversalObject note3;

    setUp(() async {
      final store = MemoryStore();
      final index = MemoryObjectIndex();
      final repo = WorkspaceRepository(store: store, index: index);
      await repo.initialize();

      controller = WorkspaceController();
      controller.repository = repo;

      note1 = makeObject(id: 'note-1', title: 'Calculus Notes');
      note2 = makeObject(id: 'note-2', title: 'Linear Algebra');
      note3 = makeObject(id: 'note-3', title: 'Meeting Record');

      controller.objects = [note1, note2, note3];
      controller.session = SessionState(
        tabs: ['note-1'],
        activeId: 'note-1',
        recent: ['note-1', 'note-2'],
        bookmarkedTabs: ['note-2'],
      );
    });

    Widget createTestApp(Widget child) {
      return MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(body: child),
      );
    }

    testWidgets('displays open tabs and documents, filters by query', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                key: const ValueKey('open-switcher'),
                onPressed: () => showQuickSwitcher(context, controller),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Open the Quick Switcher
      await tester.tap(find.byKey(const ValueKey('open-switcher')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Should find the Quick Switcher dialog and items
      expect(find.byType(QuickSwitcherDialog), findsOneWidget);
      expect(find.text('Calculus Notes'), findsOneWidget);
      expect(find.text('Linear Algebra'), findsOneWidget);
      expect(find.text('Meeting Record'), findsOneWidget);

      // Filter by query "linear"
      await tester.enterText(
        find.byKey(const ValueKey('quick-switcher-search-input')),
        'Linear',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Linear Algebra'), findsOneWidget);
      expect(find.text('Calculus Notes'), findsNothing);
      expect(find.text('Meeting Record'), findsNothing);
    });

    testWidgets('keyboard navigation and Enter opens selected note', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                key: const ValueKey('open-switcher'),
                onPressed: () => showQuickSwitcher(context, controller),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('open-switcher')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Press ArrowDown to select second item
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // Press Enter to activate
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Dialog should be dismissed
      expect(find.byType(QuickSwitcherDialog), findsNothing);
      expect(controller.session.activeId, isNotNull);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('offers create note option when search has no exact match', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                key: const ValueKey('open-switcher'),
                onPressed: () => showQuickSwitcher(context, controller),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('open-switcher')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Type brand new note name
      await tester.enterText(
        find.byKey(const ValueKey('quick-switcher-search-input')),
        'Brand New Concept',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show Create new note option
      expect(find.textContaining('Create new note'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);

      // Tap Create new note option
      await tester.runAsync(() async {
        await tester.tap(find.text('NEW'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(find.byType(QuickSwitcherDialog), findsNothing);
      final created = controller.objects.firstWhere(
        (o) => o.title == 'Brand New Concept',
      );
      expect(created, isNotNull);
      expect(created.typeId, 'orbit.note');
    });
  });

  group('NoteEditor Bookmark and Focus Mode header buttons', () {
    testWidgets('renders bookmark button and triggers callback', (
      tester,
    ) async {
      bool bookmarkToggled = false;
      bool focusModeToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: NoteEditor(
              noteId: 'n1',
              title: 'Physics Lab',
              body: '# Introduction\nMeasurements and results.',
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
              isBookmarked: false,
              onToggleBookmark: () => bookmarkToggled = true,
              isFocusMode: false,
              onToggleFocusMode: () => focusModeToggled = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final bookmarkBtn = find.byKey(const ValueKey('note-bookmark-toggle'));
      expect(bookmarkBtn, findsOneWidget);
      final focusBtn = find.byKey(const ValueKey('note-focus-mode-toggle'));
      expect(focusBtn, findsOneWidget);

      await tester.tap(bookmarkBtn);
      expect(bookmarkToggled, isTrue);

      await tester.tap(focusBtn);
      expect(focusModeToggled, isTrue);
    });

    testWidgets('shows active states when bookmarked and in focus mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: NoteEditor(
              noteId: 'n1',
              title: 'Physics Lab',
              body: '# Introduction\nMeasurements and results.',
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
              isBookmarked: true,
              onToggleBookmark: () {},
              isFocusMode: true,
              onToggleFocusMode: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final bookmarkBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('note-bookmark-toggle')),
      );
      expect(bookmarkBtn.tooltip, contains('Remove from bookmarks'));

      final focusBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('note-focus-mode-toggle')),
      );
      expect(focusBtn.tooltip, contains('Exit focus mode'));
    });
  });
}
