import 'package:flutter/material.dart';
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
      expect(find.byKey(ValueKey('folder-note:${note.id}')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('folder:Notes/Research')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('folder-note:${note.id}')), findsNothing);
      c.openObject(note.id);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('folder-note:${note.id}')), findsOneWidget);
      final rootRow = find.byKey(const ValueKey('folder:Notes'));
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
}
