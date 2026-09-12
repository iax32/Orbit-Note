import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/backup_bundle.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

import 'support/memory_store.dart';

void main() {
  late _FailingDeleteStore store;
  late WorkspaceRepository repo;
  setUp(() async {
    store = _FailingDeleteStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    await repo.initialize();
  });
  tearDown(() => repo.close());

  test(
    'permanent delete survives reopen and export without the derived index',
    () async {
      final object = await repo.create(
        typeId: 'orbit.note',
        title: 'Archived research',
        body: 'source',
        properties: {'archived': true},
      );
      final path = repo.objectPath(object.id)!;
      final hash = sha256.convert(store.files[path]!).toString();
      await repo.deletePermanently(object.id);
      expect(store.files[path], isNull);
      final tombstonePath = '.orbit/tombstones/${object.id}.json';
      final record =
          jsonDecode(utf8.decode(store.files[tombstonePath]!)) as Map;
      expect(record['beforeHash'], hash);
      expect(record['workspaceId'], repo.workspaceId);
      expect(record['objectId'], object.id);
      expect(
        store.files.keys.where((p) => p.startsWith('.orbit/recovery/delete-')),
        isEmpty,
      );
      await repo.initialize();
      expect(repo.objects, isEmpty);
      expect(repo.readOnly, isFalse);
      expect(
        BackupBundle.parse(await repo.exportBundle()).files,
        contains(tombstonePath),
      );
    },
  );

  test(
    'external edit before deletion is preserved without publishing intent',
    () async {
      final object = await repo.create(typeId: 'orbit.note', title: 'Changed');
      final path = repo.objectPath(object.id)!;
      final changed = Uint8List.fromList([
        ...store.files[path]!,
        ...utf8.encode('external'),
      ]);
      store.files[path] = changed;
      await expectLater(
        repo.deletePermanently(object.id),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(store.files[path], changed);
      expect(
        store.files.keys.where((p) => p.startsWith('.orbit/tombstones/')),
        isEmpty,
      );
    },
  );

  for (final boundary in ['intent', 'delete', 'tombstone', 'cleanup']) {
    test('restart recovers safely after failure at $boundary', () async {
      final object = await repo.create(
        typeId: 'orbit.note',
        title: 'Interrupted',
      );
      final path = repo.objectPath(object.id)!;
      store.failAt = boundary;
      await expectLater(
        repo.deletePermanently(object.id),
        throwsA(isA<WorkspaceFailure>()),
      );
      if (boundary == 'intent' || boundary == 'delete') {
        expect(store.files[path], isNotNull);
      }
      store.failAt = null;
      await repo.initialize();
      if (boundary == 'intent') {
        expect(repo.objects.single.id, object.id);
        expect(store.files['.orbit/tombstones/${object.id}.json'], isNull);
      } else {
        expect(repo.objects, isEmpty);
        expect(store.files[path], isNull);
        expect(store.files['.orbit/tombstones/${object.id}.json'], isNotNull);
        expect(repo.readOnly, isFalse);
        await repo.initialize();
        expect(repo.readOnly, isFalse);
      }
    });
  }

  test(
    'changed bytes after intent stop recovery instead of deleting newer work',
    () async {
      final object = await repo.create(
        typeId: 'orbit.note',
        title: 'Keep new edit',
      );
      final path = repo.objectPath(object.id)!;
      store.failAt = 'delete';
      await expectLater(
        repo.deletePermanently(object.id),
        throwsA(isA<WorkspaceFailure>()),
      );
      store.failAt = null;
      final changed = Uint8List.fromList([
        ...store.files[path]!,
        ...utf8.encode('external edit'),
      ]);
      store.files[path] = changed;
      await repo.initialize();
      expect(repo.readOnly, isTrue);
      expect(store.files[path], changed);
      expect(store.files['.orbit/tombstones/${object.id}.json'], isNull);
    },
  );

  test('portable tombstone never executes a deletion by itself', () async {
    final object = await repo.create(
      typeId: 'orbit.note',
      title: 'Both retained',
    );
    final path = repo.objectPath(object.id)!;
    final original = store.files[path]!;
    await repo.deletePermanently(object.id);
    store.files[path] = original;
    await repo.initialize();
    expect(repo.readOnly, isTrue);
    expect(store.files[path], original);
    expect(repo.objects.single.id, object.id);
  });

  test(
    'foreign deletion journal never publishes a tombstone or deletes bytes',
    () async {
      final object = await repo.create(
        typeId: 'orbit.note',
        title: 'Foreign intent',
      );
      final path = repo.objectPath(object.id)!;
      store.failAt = 'delete';
      await expectLater(
        repo.deletePermanently(object.id),
        throwsA(isA<WorkspaceFailure>()),
      );
      store.failAt = null;
      final journal = '.orbit/recovery/delete-${object.id}.json';
      final data = jsonDecode(utf8.decode(store.files[journal]!)) as Map;
      (data['tombstone'] as Map)['workspaceId'] =
          '11111111-1111-4111-8111-111111111111';
      store.files[journal] = Uint8List.fromList(utf8.encode(jsonEncode(data)));
      await repo.initialize();
      expect(repo.readOnly, isTrue);
      expect(store.files[path], isNotNull);
      expect(store.files['.orbit/tombstones/${object.id}.json'], isNull);
    },
  );
}

class _FailingDeleteStore extends MemoryStore {
  String? failAt;
  @override
  Future<void> write(
    String path,
    Uint8List bytes, {
    required String? expectedHash,
  }) async {
    if ((failAt == 'intent' && path.startsWith('.orbit/recovery/delete-')) ||
        (failAt == 'tombstone' && path.startsWith('.orbit/tombstones/'))) {
      throw const WorkspaceFailure('Injected disk failure');
    }
    await super.write(path, bytes, expectedHash: expectedHash);
  }

  @override
  Future<void> deleteFile(String path, {required String? expectedHash}) async {
    if ((failAt == 'delete' && path.startsWith('Notes/')) ||
        (failAt == 'cleanup' && path.startsWith('.orbit/recovery/delete-'))) {
      throw const WorkspaceFailure('Injected delete failure');
    }
    await super.deleteFile(path, expectedHash: expectedHash);
  }
}
