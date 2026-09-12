import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

void main() {
  late Directory root;
  late NativeWorkspaceStore store;
  late WorkspaceRepository repo;
  late WorkspaceController controller;
  late ProviderContainer container;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('orbit-delete-test-');
    store = _TestStore('${root.path}/vault');
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    await repo.initialize(path: '${root.path}/vault');
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    container.read(workspaceProvider);
    controller = container.read(workspaceProvider.notifier);
    for (var i = 0; i < 200 && controller.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(controller.loading, isFalse);
  });

  tearDown(() async {
    await controller.flushAll();
    container.dispose();
    await repo.close();
    await root.delete(recursive: true);
  });

  test('deleteFolder trashes contained notes and deletes directory', () async {
    await repo.createFolder('Notes/Projects/App');
    final note = await repo.create(
      typeId: 'orbit.note',
      title: 'App Specs',
      body: 'Content',
    );
    await repo.moveNote(note.id, 'Notes/Projects/App');

    expect(repo.folders, contains('Notes/Projects/App'));
    expect(repo.objects.firstWhere((o) => o.id == note.id).deletedAt, isNull);

    await controller.deleteFolder('Notes/Projects/App');

    // Folder removed from folder list
    expect(repo.folders.contains('Notes/Projects/App'), isFalse);
    // Note inside folder was moved to trash
    final trashedNote = repo.objects.firstWhere((o) => o.id == note.id);
    expect(trashedNote.deletedAt, isNotNull);
    // Directory removed on disk
    final dir = Directory('${root.path}/vault/Notes/Projects/App');
    expect(await dir.exists(), isFalse);
  });

  test('deletePermanently purges file, memory object, and index', () async {
    final note = await repo.create(
      typeId: 'orbit.note',
      title: 'Secret Note',
      body: 'To be destroyed',
    );
    final notePath = repo.objectPath(note.id);
    expect(notePath, isNotNull);
    final file = File('${root.path}/vault/$notePath');
    expect(await file.exists(), isTrue);

    // Trash first
    await controller.trash(note.id);
    expect(
      repo.objects.firstWhere((o) => o.id == note.id).deletedAt,
      isNotNull,
    );

    // Now delete permanently
    await controller.deletePermanently(note.id);
    expect(repo.objects.any((o) => o.id == note.id), isFalse);
    expect(await file.exists(), isFalse);
  });

  test(
    'emptyTrash purges all trashed items and preserves active ones',
    () async {
      final activeNote = await repo.create(
        typeId: 'orbit.note',
        title: 'Active Note',
        body: 'Keep me',
      );
      final trash1 = await repo.create(
        typeId: 'orbit.note',
        title: 'Trash 1',
        body: 'Delete me 1',
      );
      final trash2 = await repo.create(
        typeId: 'orbit.note',
        title: 'Trash 2',
        body: 'Delete me 2',
      );

      await controller.trash(trash1.id);
      await controller.trash(trash2.id);

      expect(controller.objects.where((o) => o.isDeleted).length, 2);

      await controller.emptyTrash();

      expect(controller.objects.where((o) => o.isDeleted), isEmpty);
      expect(repo.objects.any((o) => o.id == activeNote.id), isTrue);
      expect(repo.objects.any((o) => o.id == trash1.id), isFalse);
      expect(repo.objects.any((o) => o.id == trash2.id), isFalse);
    },
  );

  test('showAttachments toggles and persists in session state', () async {
    expect(controller.showAttachments, isFalse);

    controller.toggleShowAttachments();
    expect(controller.showAttachments, isTrue);
    expect(controller.session.showAttachments, isTrue);

    controller.toggleShowAttachments();
    expect(controller.showAttachments, isFalse);
    expect(controller.session.showAttachments, isFalse);
  });
}

class _TestStore extends NativeWorkspaceStore {
  _TestStore(this.testPath);
  final String testPath;
  @override
  Future<void> initialize({String? path}) =>
      super.initialize(path: path ?? testPath);
}
