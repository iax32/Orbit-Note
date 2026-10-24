import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

void main() {
  late Directory root;
  late NativeWorkspaceStore store;
  late WorkspaceRepository repo;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('orbit-folder-import-');
    store = NativeWorkspaceStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    await repo.initialize(path: root.path);
    await repo.createFolder('Notes/Course');
    await repo.createFolder('Notes/Course/Week 1');
  });
  tearDown(() async {
    await repo.close();
    await root.delete(recursive: true);
  });

  test(
    'folder imports persist for every file type without moving an existing identical file',
    () async {
      final bytes = Uint8List.fromList([37, 80, 68, 70, 0, 255]);
      final loose = await repo.importAttachment(
        name: 'lecture.PDF',
        bytes: bytes,
      );
      final filed = await repo.importAttachment(
        name: 'lecture.PDF',
        bytes: bytes,
        folder: 'Course/Week 1',
      );
      expect(filed.id, isNot(loose.id));
      expect(repo.objectFolder(loose.id), 'Notes');
      expect(repo.objectFolder(filed.id), 'Notes/Course/Week 1');
      expect(filed.properties['contentRef'], loose.properties['contentRef']);
      final repeated = await repo.importAttachment(
        name: 'lecture.PDF',
        bytes: bytes,
        folder: 'Notes/Course/Week 1',
      );
      expect(repeated.id, filed.id);
      for (final ext in ['png', 'cpp', 'glb', 'wav', 'docx']) {
        final item = await repo.importAttachment(
          name: 'sample.$ext',
          bytes: Uint8List.fromList(ext.codeUnits),
          folder: 'Notes/Course/Week 1',
        );
        expect(repo.objectFolder(item.id), 'Notes/Course/Week 1');
      }
      await repo.initialize(path: root.path);
      expect(repo.objectFolder(filed.id), 'Notes/Course/Week 1');
      expect(repo.objectFolder(loose.id), 'Notes');
      expect(
        await repo.readAttachment(filed.properties['contentRef'] as String),
        bytes,
      );
      expect((await repo.syncInventory()).ready, isTrue);
    },
  );

  test(
    'removed or unsafe import destinations fail before writing any bytes',
    () async {
      await Directory('${root.path}/Notes/Course/Week 1').delete();
      final before = await store.listFiles();
      for (final folder in [
        'Notes/Course/Week 1',
        'Notes/Missing',
        '../outside',
      ]) {
        await expectLater(
          repo.importAttachment(
            name: 'test.pdf',
            bytes: Uint8List.fromList([1, 2]),
            folder: folder,
          ),
          throwsA(isA<WorkspaceFailure>()),
        );
      }
      expect(await store.listFiles(), before);
      expect(repo.objects, isEmpty);
    },
  );
}
