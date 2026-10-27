import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'package:orbit_note/main.dart';
import 'support/memory_store.dart';

class FolderFixtureStore extends MemoryStore implements WorkspaceFolderStore {
  final folders = ['Notes', 'Notes/Research'];
  @override
  Future<List<String>> listFolders() async => List.of(folders);
  @override
  Future<void> createFolder(String path) async {
    folders.add(path);
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
  ) async => throw UnsupportedError('Native movement is tested separately');
}

void main() {
  testWidgets(
    'folder tree creates folders, collapses and reveals an opened note',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FolderFixtureStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final note = await repo.create(
        typeId: 'orbit.note',
        title: 'Nested note',
      );
      final path = repo.objectPath(note.id)!;
      store.files[path.replaceFirst('Notes/', 'Notes/Research/')] = store.files
          .remove(path)!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: const OrbitNoteApp(),
        ),
      );
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(
        tester.element(find.byType(OrbitNoteApp)),
      ).read(workspaceProvider.notifier);
      c.openObject(note.id);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('explorer-type-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-chip-notes')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('folder-note:${note.id}')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('folder:Notes/Research')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('folder-note:${note.id}')), findsNothing);
      c.openObject(note.id);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('folder-note:${note.id}')), findsNothing);
      c.openObject(note.id, reveal: true);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('folder-note:${note.id}')), findsOneWidget);
      final rootRow = find.byKey(const ValueKey('folder:Notes'));
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      await pointer.moveTo(tester.getCenter(rootRow));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: rootRow,
          matching: find.byTooltip('Folder actions'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New folder'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Folder name'),
        'CON',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Folder name'), findsOneWidget);
      expect(store.folders, isNot(contains('Notes/CON')));
      await tester.enterText(
        find.widgetWithText(TextField, 'Folder name'),
        'Drafts',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('folder:Notes/Drafts')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'created projects (Reverse Engineering, Games, Course) appear in the explorer tree',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FolderFixtureStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: const OrbitNoteApp(),
        ),
      );
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(
        tester.element(find.byType(OrbitNoteApp)),
      ).read(workspaceProvider.notifier);

      // 1. Create Reverse Engineering Project
      final reOverview = await c.createReverseEngineeringProject('GameClient');
      expect(reOverview, isNotNull);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('explorer-type-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-chip-notes')));
      await tester.pumpAndSettle();

      expect(find.text('Reverse Engineering'), findsWidgets);
      expect(find.text('GameClient'), findsWidgets);
      expect(
        find.byKey(ValueKey('folder-note:${reOverview!.id}')),
        findsOneWidget,
      );

      // Collapse Reverse Engineering to test collapse and save vertical space
      await tester.tap(find.text('Reverse Engineering').first);
      await tester.pumpAndSettle();

      // 2. Create Game Project
      final gameGdd = await c.createGameProject('ShadowQuest');
      expect(gameGdd, isNotNull);
      await tester.pumpAndSettle();

      expect(find.text('Games'), findsWidgets);
      expect(find.text('ShadowQuest'), findsWidgets);
      expect(
        find.byKey(ValueKey('folder-note:${gameGdd!.id}')),
        findsOneWidget,
      );

      // Collapse Games to test collapse and save vertical space
      await tester.tap(find.text('Games').first);
      await tester.pumpAndSettle();

      // 3. Create University Course
      final courseOverview = await c.createUniversityCourse('DiscreteMath');
      expect(courseOverview, isNotNull);
      await tester.pumpAndSettle();

      expect(find.text('University'), findsWidgets);
      expect(find.text('DiscreteMath'), findsWidgets);
      expect(
        find.byKey(ValueKey('folder-note:${courseOverview!.id}')),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
