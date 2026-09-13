import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/path_safety.dart';

class _FailureStore extends NativeWorkspaceStore {
  int? failAfterWrites;
  @override
  Future<void> write(
    String path,
    Uint8List bytes, {
    required String? expectedHash,
  }) async {
    if (failAfterWrites != null && !path.startsWith('.orbit/')) {
      if (failAfterWrites == 0) {
        throw const WorkspaceFailure('Simulated storage lock');
      }
      failAfterWrites = failAfterWrites! - 1;
    }
    await super.write(path, bytes, expectedHash: expectedHash);
  }
}

void main() {
  late Directory root;
  late _FailureStore store;
  late WorkspaceRepository repo;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('orbit-universal-folders-');
    store = _FailureStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    await repo.initialize(path: root.path);
  });
  tearDown(() async {
    await repo.close();
    await root.delete(recursive: true);
  });
  Future<List<String>> mixed() async {
    await repo.createFolder('Notes/Math/Nested');
    return [
      for (final type in [
        'orbit.note',
        'orbit.canvas',
        'orbit.view',
        'orbit.task',
      ])
        (await repo.create(
          typeId: type,
          title: type,
          properties: {'folder': 'Notes/Math/Nested', 'custom': 'keep'},
        )).id,
    ];
  }

  test(
    'mixed folder deletion trashes all owners at root without ghost folders',
    () async {
      final ids = await mixed();
      await repo.deleteFolder('Notes/Math');
      expect(repo.folders.where((f) => f.startsWith('Notes/Math')), isEmpty);
      for (final id in ids) {
        final object = repo.objects.singleWhere((o) => o.id == id);
        expect(object.isDeleted, isTrue);
        expect(object.properties['folder'], 'Notes');
        expect(object.properties['custom'], 'keep');
      }
      await repo.initialize(path: root.path);
      expect(repo.objects.map((o) => o.id), unorderedEquals(ids));
      await repo.restore(ids.first);
      expect(repo.objectFolder(ids.first), 'Notes');
      expect(await Directory('${root.path}/Notes/Math').exists(), isFalse);
    },
  );
  test(
    'nested folder rename moves every owner and retains identities',
    () async {
      final ids = await mixed();
      await repo.moveFolder('Notes/Math', 'Notes/Archive/Math');
      for (final id in ids) {
        expect(repo.objectFolder(id), 'Notes/Archive/Math/Nested');
        expect(
          repo.objects.singleWhere((o) => o.id == id).properties['folder'],
          'Notes/Archive/Math/Nested',
        );
      }
      expect(repo.folders, isNot(contains('Notes/Math')));
      await repo.initialize(path: root.path);
      expect(repo.objects.map((o) => o.id), unorderedEquals(ids));
    },
  );
  test('mixed batch moves use one command', () async {
    final ids = await mixed();
    await repo.createFolder('Notes/Target');
    await repo.moveObjectsToFolder(ids, 'Notes/Target');
    expect(ids.map(repo.objectFolder).toSet(), {'Notes/Target'});
    expect(repo.objectPath(ids.first), startsWith('Notes/Target/'));
  });
  test('batch preflight failure leaves all owners unchanged', () async {
    final ids = await mixed();
    await repo.createFolder('Notes/Target');
    final path = repo.objectPath(ids.first)!;
    final basename = path.split('/').last;
    await File(
      '${root.path}/Notes/Target/$basename',
    ).writeAsString('external file');
    await expectLater(
      repo.moveObjectsToFolder(ids, 'Notes/Target'),
      throwsA(isA<WorkspaceConflict>()),
    );
    expect(ids.map(repo.objectFolder).toSet(), {'Notes/Math/Nested'});
    expect(repo.readOnly, isFalse);
  });
  test('Notes moved together retain relative links to each other', () async {
    await repo.createFolder('Notes/From');
    await repo.createFolder('Notes/To');
    final second = await repo.create(
      typeId: 'orbit.note',
      title: 'Second',
      properties: {'folder': 'Notes/From'},
    );
    final filename = repo.objectPath(second.id)!.split('/').last;
    final first = await repo.create(
      typeId: 'orbit.note',
      title: 'First',
      body: '[Second]($filename)\n\nKeep these blank lines.\n',
      properties: {'folder': 'Notes/From'},
    );
    await repo.moveObjectsToFolder([first.id, second.id], 'Notes/To');
    expect(repo.objects.singleWhere((o) => o.id == first.id).body, first.body);
    await repo.initialize(path: root.path);
    expect(repo.readOnly, isFalse);
    expect(repo.objects.singleWhere((o) => o.id == first.id).body, first.body);
  });
  test(
    'failed Note write leaves folder metadata and physical path together',
    () async {
      final ids = await mixed();
      await repo.createFolder('Notes/Target');
      final before = repo.objectPath(ids.first);
      store.failAfterWrites = 0;
      await expectLater(
        repo.moveObjectsToFolder(ids, 'Notes/Target'),
        throwsA(isA<WorkspaceFailure>()),
      );
      expect(repo.objectPath(ids.first), before);
      expect(
        repo.objects.singleWhere((o) => o.id == ids.first).properties['folder'],
        'Notes/Math/Nested',
      );
      expect(repo.readOnly, isTrue);
      store.failAfterWrites = null;
      await repo.initialize(path: root.path);
      expect(repo.readOnly, isFalse);
      expect(ids.map(repo.objectFolder).toSet(), {'Notes/Target'});
    },
  );
  test('interrupted mixed folder command rolls forward on reopen', () async {
    final ids = await mixed();
    store.failAfterWrites = 1;
    await expectLater(
      repo.moveFolder('Notes/Math', 'Notes/Renamed'),
      throwsA(isA<WorkspaceFailure>()),
    );
    expect(repo.readOnly, isTrue);
    store.failAfterWrites = null;
    await repo.initialize(path: root.path);
    expect(repo.readOnly, isFalse);
    expect(ids.map(repo.objectFolder).toSet(), {'Notes/Renamed/Nested'});
    expect(repo.folders, isNot(contains('Notes/Math')));
  });
  test('external edit during recovery is retained and stops command', () async {
    final ids = await mixed();
    store.failAfterWrites = 0;
    await expectLater(
      repo.moveFolder('Notes/Math', 'Notes/Renamed'),
      throwsA(isA<WorkspaceFailure>()),
    );
    final path = repo.objectPath(ids.first)!;
    final original = await File('${root.path}/$path').readAsString();
    await File('${root.path}/$path').writeAsString('$original\nexternal edit');
    store.failAfterWrites = null;
    await repo.initialize(path: root.path);
    expect(repo.readOnly, isTrue);
    expect(
      await File('${root.path}/$path').readAsString(),
      endsWith('external edit'),
    );
  });
  test('portable folder names share repository validation', () {
    for (final name in [
      'a<',
      'a>',
      'a:',
      'a"',
      'a/',
      'a\\',
      'a|',
      'a?',
      'a*',
      'a.',
      'a ',
      'CON',
      '..',
      '',
    ]) {
      expect(
        () => validateFolderName(name),
        throwsA(isA<WorkspaceFailure>()),
        reason: name,
      );
    }
    for (final name in ['Math', 'Grüße 数学']) {
      expect(() => validateFolderName(name), returnsNormally);
    }
  });
}
