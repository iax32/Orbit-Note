import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/path_safety.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory folder;
  late WorkspaceRepository repository;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('orbit-storage-test-');
    repository = WorkspaceRepository(
      store: NativeWorkspaceStore(),
      index: MemoryObjectIndex(),
    );
    await repository.initialize(path: folder.path);
  });
  tearDown(() async {
    await repository.close();
    await folder.delete(recursive: true);
  });
  Future<File> owner(String id) async =>
      (await folder
                  .list(recursive: true)
                  .where(
                    (e) =>
                        e is File &&
                        e.path.contains(id) &&
                        (e.path.endsWith('.md') ||
                            e.path.endsWith('.object.json')),
                  )
                  .toList())
              .single
          as File;

  test('note, task and trash survive a clean reopen without SQL', () async {
    final note = await repository.create(
      typeId: 'orbit.note',
      title: 'First',
      body: '**Markdown**',
    );
    final edited = await repository.save(
      note.copyWith(title: 'Renamed', body: '# Saved'),
    );
    expect(edited.revision, 2);
    final task = await repository.create(
      typeId: 'orbit.task',
      title: 'Finish',
      properties: {
        'completed': false,
        'priority': 'high',
        'dueDate': '2026-09-10',
      },
    );
    await repository.trash(task.id);
    final workspaceId = repository.workspaceId;
    await repository.close();
    repository = WorkspaceRepository(
      store: NativeWorkspaceStore(),
      index: MemoryObjectIndex(),
    );
    await repository.initialize(path: folder.path);
    expect(repository.workspaceId, workspaceId);
    expect(
      repository.objects.firstWhere((o) => o.id == note.id).body,
      '# Saved',
    );
    expect(
      repository.objects.firstWhere((o) => o.id == task.id).isDeleted,
      isTrue,
    );
    final restored = await repository.restore(task.id);
    expect(restored.isDeleted, isFalse);
    expect(restored.properties['priority'], 'high');
    expect(await (await owner(note.id)).readAsString(), contains('# Saved'));
  });

  test('external edit conflicts retain both source and pending edit', () async {
    final note = await repository.create(
      typeId: 'orbit.note',
      title: 'Concurrent',
      body: 'Original',
    );
    final file = await owner(note.id);
    await file.writeAsString(
      (await file.readAsString()).replaceAll('Original', 'External'),
    );
    WorkspaceConflict? failure;
    try {
      await repository.save(note.copyWith(body: 'My pending text'));
    } on WorkspaceConflict catch (error) {
      failure = error;
    }
    expect(failure, isNotNull);
    expect(await file.readAsString(), endsWith('External'));
    final recovery = File(p.join(folder.path, failure!.recoveryPath!));
    expect(await recovery.readAsString(), contains('My pending text'));
    await repository.refresh();
    expect(repository.objects.single.body, 'External');
  });

  test('stale local revision cannot overwrite newer content', () async {
    final first = await repository.create(typeId: 'orbit.note', title: 'One');
    await repository.save(first.copyWith(body: 'Second'));
    await expectLater(
      repository.save(first.copyWith(body: 'Stale')),
      throwsA(isA<WorkspaceConflict>()),
    );
    expect(repository.objects.single.body, 'Second');
  });

  test(
    'attachment bytes deduplicate and removing a reference retains original',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final first = await repository.importAttachment(
        name: 'image.png',
        bytes: bytes,
      );
      final second = await repository.importAttachment(
        name: 'renamed.png',
        bytes: bytes,
      );
      expect(second.id, first.id);
      final path = first.properties['contentRef'] as String;
      final note = await repository.create(
        typeId: 'orbit.note',
        title: 'Image',
        body: '![]($path)',
      );
      await repository.save(note.copyWith(body: 'Removed embed'));
      expect(await repository.readAttachment(path), bytes);
      await repository.trash(first.id);
      expect(await repository.readAttachment(path), bytes);
    },
  );

  test(
    'external attachment changes are reported separately from objects',
    () async {
      final path = 'Attachments/external/replaced.png';
      final event = repository.externalAttachmentChanges.firstWhere(
        (changed) => changed == path,
      );
      final file = File(p.join(folder.path, path));
      await file.parent.create(recursive: true);
      await file.writeAsBytes([9, 8, 7], flush: true);
      expect(await event.timeout(const Duration(seconds: 3)), path);
    },
  );

  test(
    'relinking preserves file identity and retains the previous source',
    () async {
      final first = await repository.importAttachment(
        name: 'old.png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final oldPath = first.properties['contentRef'] as String;
      final updated = await repository.relinkAttachment(
        first,
        name: 'new.png',
        bytes: Uint8List.fromList([4, 5, 6]),
      );
      expect(updated.id, first.id);
      expect(updated.properties['contentRef'], isNot(oldPath));
      final history = updated.properties['attachmentSourceHistory'] as List;
      expect(history.single['contentRef'], oldPath);
      final restored = await repository.restoreAttachmentSource(
        updated,
        oldPath,
      );
      expect(restored.properties['contentRef'], oldPath);
      expect(restored.properties['checksum'], first.properties['checksum']);
      expect(
        await repository.readAttachment(oldPath),
        Uint8List.fromList([1, 2, 3]),
      );
    },
  );

  test(
    'forgetting a retained source removes history and only its immutable bytes',
    () async {
      final first = await repository.importAttachment(
        name: 'old.png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final oldPath = first.properties['contentRef'] as String;
      final updated = await repository.relinkAttachment(
        first,
        name: 'new.png',
        bytes: Uint8List.fromList([4, 5, 6]),
      );
      final phases = <String>[];
      final cleaned = await repository.forgetAttachmentSourceVersion(
        updated,
        oldPath,
        onProgress: (_, _, phase) => phases.add(phase),
      );

      expect(cleaned.id, first.id);
      expect(cleaned.properties['attachmentSourceHistory'], isEmpty);
      expect(await repository.readAttachment(oldPath), isNull);
      expect(
        await repository.readAttachment(
          cleaned.properties['contentRef'] as String,
        ),
        Uint8List.fromList([4, 5, 6]),
      );
      expect(phases, contains('Verifying retained source…'));
    },
  );

  test(
    'retained source cleanup preserves history when bytes changed externally',
    () async {
      final first = await repository.importAttachment(
        name: 'old.png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final oldPath = first.properties['contentRef'] as String;
      final updated = await repository.relinkAttachment(
        first,
        name: 'new.png',
        bytes: Uint8List.fromList([4, 5, 6]),
      );
      await File(p.join(folder.path, oldPath)).writeAsBytes([9, 9, 9]);

      await expectLater(
        repository.forgetAttachmentSourceVersion(updated, oldPath),
        throwsA(isA<WorkspaceConflict>()),
      );
      final current = repository.objects.singleWhere(
        (object) => object.id == first.id,
      );
      expect(current.properties['attachmentSourceHistory'], isNotEmpty);
      expect(await File(p.join(folder.path, oldPath)).readAsBytes(), [9, 9, 9]);
    },
  );

  test(
    'retained source cleanup refuses paths used by another file object',
    () async {
      final first = await repository.importAttachment(
        name: 'old.png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final oldPath = first.properties['contentRef'] as String;
      final updated = await repository.relinkAttachment(
        first,
        name: 'new.png',
        bytes: Uint8List.fromList([4, 5, 6]),
      );
      final other = await repository.create(
        typeId: 'orbit.file',
        title: 'Shared source',
        properties: {'contentRef': oldPath},
      );

      await expectLater(
        repository.forgetAttachmentSourceVersion(updated, oldPath),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(await repository.readAttachment(oldPath), isNotNull);
      await repository.trash(other.id);
    },
  );

  test('missing attachment recovery requires the recorded checksum', () async {
    final attachment = await repository.importAttachment(
      name: 'missing.png',
      bytes: Uint8List.fromList([7, 8, 9]),
    );
    final path = attachment.properties['contentRef'] as String;
    final file = File(p.join(folder.path, path));
    await file.delete();
    await expectLater(
      repository.recoverMissingAttachment(
        path,
        Uint8List.fromList([0]),
        expectedChecksum: attachment.properties['checksum'] as String,
      ),
      throwsA(isA<WorkspaceFailure>()),
    );
    await repository.recoverMissingAttachment(
      path,
      Uint8List.fromList([7, 8, 9]),
      expectedChecksum: attachment.properties['checksum'] as String,
    );
    expect(
      await repository.readAttachment(path),
      Uint8List.fromList([7, 8, 9]),
    );
  });

  test(
    'streamed missing attachment recovery reports progress and verifies bytes',
    () async {
      final attachment = await repository.importAttachment(
        name: 'streamed.png',
        bytes: Uint8List.fromList([7, 8, 9, 10]),
      );
      final path = attachment.properties['contentRef'] as String;
      await File(p.join(folder.path, path)).delete();
      final progress = <int>[];

      await repository.recoverMissingAttachmentStream(
        path,
        Stream<List<int>>.fromIterable([
          [7, 8],
          [9, 10],
        ]),
        expectedChecksum: attachment.properties['checksum'] as String,
        onProgress: progress.add,
      );

      expect(progress, isNotEmpty);
      expect(progress.last, 4);
      expect(await repository.readAttachment(path), [7, 8, 9, 10]);
    },
  );

  test(
    'streamed relinking verifies and persists the source without buffering the UI',
    () async {
      final first = await repository.importAttachment(
        name: 'old.png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final next = Uint8List.fromList([4, 5, 6, 7]);
      final checksum = sha256.convert(next).toString();
      final progress = <int>[];

      final updated = await repository.relinkAttachmentStream(
        first,
        name: 'new.png',
        expectedChecksum: checksum,
        bytes: Stream<List<int>>.fromIterable([
          [4, 5],
          [6, 7],
        ]),
        onProgress: progress.add,
      );

      expect(updated.properties['checksum'], checksum);
      expect(updated.properties['byteLength'], next.length);
      expect(progress.last, next.length);
      expect(
        await repository.readAttachment(
          updated.properties['contentRef'] as String,
        ),
        next,
      );
    },
  );

  test(
    'interrupted streamed recovery is listed and can resume from its saved offset',
    () async {
      final payload = Uint8List.fromList([11, 12, 13, 14]);
      final attachment = await repository.importAttachment(
        name: 'resume.bin',
        bytes: payload,
      );
      final path = attachment.properties['contentRef'] as String;
      await File(p.join(folder.path, path)).delete();
      Stream<List<int>> interrupted() async* {
        yield [11, 12];
        throw const WorkspaceFailure('simulated interruption');
      }

      await expectLater(
        repository.recoverMissingAttachmentStream(
          path,
          interrupted(),
          expectedChecksum: attachment.properties['checksum'] as String,
        ),
        throwsA(isA<WorkspaceFailure>()),
      );
      final stages = await repository.attachmentRecoveryStages(target: path);
      expect(stages, hasLength(1));
      expect(stages.single.length, 2);

      await repository.recoverMissingAttachmentStream(
        path,
        Stream.value([13, 14]),
        expectedChecksum: stages.single.expectedHash,
        resumableStageId: stages.single.id,
      );
      expect(await repository.readAttachment(path), payload);
      expect(await repository.attachmentRecoveryStages(target: path), isEmpty);
    },
  );

  test(
    'cancelling streamed recovery preserves a resumable native stage',
    () async {
      final payload = Uint8List.fromList([21, 22, 23, 24]);
      final attachment = await repository.importAttachment(
        name: 'cancel.bin',
        bytes: payload,
      );
      final path = attachment.properties['contentRef'] as String;
      await File(p.join(folder.path, path)).delete();
      var cancelled = false;

      await expectLater(
        repository.recoverMissingAttachmentStream(
          path,
          Stream<List<int>>.fromIterable([
            [21, 22],
            [23, 24],
          ]),
          expectedChecksum: attachment.properties['checksum'] as String,
          onProgress: (_) => cancelled = true,
          isCancelled: () => cancelled,
        ),
        throwsA(isA<WorkspaceFailure>()),
      );

      final stages = await repository.attachmentRecoveryStages(target: path);
      expect(stages, hasLength(1));
      expect(stages.single.length, 2);
      expect(await repository.readAttachment(path), isNull);

      await repository.recoverMissingAttachmentStream(
        path,
        Stream.value([23, 24]),
        expectedChecksum: stages.single.expectedHash,
        resumableStageId: stages.single.id,
      );
      expect(await repository.readAttachment(path), payload);
    },
  );

  test(
    'portable export retains canonical files and excludes device history',
    () async {
      await repository.create(
        typeId: 'orbit.note',
        title: 'Portable',
        body: 'Text',
      );
      await repository.writeDeviceSettings({'activeId': 'private-session'});
      await repository.writeDeviceSettings({
        'activeId': 'private-next-session',
      });
      final bundle = jsonDecode(await repository.exportBundle()) as Map;
      final files = bundle['files'] as Map;
      expect(bundle['format'], 'orbit-note-backup');
      expect(files.keys, contains('workspace.json'));
      expect(files.keys.any((k) => k.toString().startsWith('Notes/')), isTrue);
      expect(
        files.keys.any((k) => k.toString().startsWith('.orbit/device/')),
        isFalse,
      );
      expect(
        files.values.any(
          (v) => utf8
              .decode(base64Decode(v as String))
              .contains('private-session'),
        ),
        isFalse,
      );
    },
  );

  test(
    'future workspace opens read-only without changing its manifest',
    () async {
      final file = File(p.join(folder.path, 'workspace.json'));
      final doc = jsonDecode(await file.readAsString()) as Map;
      doc['version'] = 100;
      final source = jsonEncode(doc);
      await file.writeAsString(source);
      await repository.initialize(path: folder.path);
      expect(repository.readOnly, isTrue);
      await expectLater(
        repository.create(typeId: 'orbit.note', title: 'Blocked'),
        throwsA(isA<WorkspaceReadOnly>()),
      );
      expect(await file.readAsString(), source);
    },
  );

  test(
    'unsafe attachment paths and reserved filenames cannot escape workspace',
    () async {
      for (final path in [
        '../escape',
        '/absolute',
        'C:/escape',
        'Attachments/../../escape',
        r'Attachments\..\escape',
      ]) {
        expect(
          () => validateRelativePath(path),
          throwsA(isA<WorkspaceFailure>()),
        );
      }
      final attachment = await repository.importAttachment(
        name: '../CON.png',
        bytes: Uint8List(2),
      );
      expect(attachment.properties['contentRef'], startsWith('Attachments/'));
      expect(attachment.properties['contentRef'], isNot(contains('../')));
    },
  );

  test(
    'index failure never changes a durable save into lost content',
    () async {
      await repository.close();
      repository = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: _FailingIndex(),
      );
      await repository.initialize(path: folder.path);
      final note = await repository.create(
        typeId: 'orbit.note',
        title: 'Index failure',
        body: 'Durable',
      );
      expect(await (await owner(note.id)).readAsString(), endsWith('Durable'));
      expect(repository.issues.join(), contains('index'));
      expect((await repository.search('Durable')).single.id, note.id);
    },
  );

  test(
    'failed durable write keeps existing content and loaded revision',
    () async {
      await repository.close();
      final store = _FailingStore(NativeWorkspaceStore());
      repository = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repository.initialize(path: folder.path);
      final note = await repository.create(
        typeId: 'orbit.note',
        title: 'Disk full',
        body: 'Before',
      );
      store.failWrites = true;
      await expectLater(
        repository.save(note.copyWith(body: 'After')),
        throwsA(isA<WorkspaceFailure>()),
      );
      expect(repository.objects.single.revision, 1);
      expect(await (await owner(note.id)).readAsString(), endsWith('Before'));
    },
  );

  test(
    'staged native save replays after interruption only when source still matches',
    () async {
      final note = await repository.create(
        typeId: 'orbit.note',
        title: 'Recovery',
        body: 'Before',
      );
      final target = await owner(note.id);
      final relative = p
          .relative(target.path, from: folder.path)
          .replaceAll('\\', '/');
      final before = await target.readAsBytes();
      final after = Uint8List.fromList(
        utf8.encode(utf8.decode(before).replaceAll('Before', 'Recovered')),
      );
      final tempPath = '$relative.orbit-interrupted.tmp';
      await File(
        p.join(folder.path, tempPath),
      ).writeAsBytes(after, flush: true);
      final journal = File(
        p.join(folder.path, '.orbit', 'recovery', 'interrupted.json'),
      );
      await journal.writeAsString(
        jsonEncode({
          'format': 'orbit-note-file-save',
          'version': 1,
          'target': relative,
          'temp': tempPath,
          'beforeHash': sha256.convert(before).toString(),
          'afterHash': sha256.convert(after).toString(),
        }),
        flush: true,
      );
      await repository.initialize(path: folder.path);
      expect(repository.objects.single.body, 'Recovered');
      expect(
        await journal.exists(),
        isFalse,
        reason: 'Completed recovery no longer accumulates permanent journals',
      );
    },
  );
}

class _FailingIndex extends MemoryObjectIndex {
  @override
  Future<void> initialize(String location) async =>
      throw StateError('Simulated index failure');
}

class _FailingStore implements WorkspaceStore {
  _FailingStore(this.delegate);
  final WorkspaceStore delegate;
  bool failWrites = false;
  @override
  String get location => delegate.location;
  @override
  bool get isBrowser => false;
  @override
  Future<void> initialize({String? path}) => delegate.initialize(path: path);
  @override
  Future<void> close() => delegate.close();
  @override
  Future<List<String>> listFiles() => delegate.listFiles();
  @override
  Future<Uint8List?> read(String relativePath) => delegate.read(relativePath);
  @override
  Future<void> write(
    String relativePath,
    Uint8List bytes, {
    required String? expectedHash,
  }) {
    if (failWrites) throw const WorkspaceFailure('Simulated full disk.');
    return delegate.write(relativePath, bytes, expectedHash: expectedHash);
  }

  @override
  Future<void> deleteFile(
    String relativePath, {
    required String? expectedHash,
  }) => delegate.deleteFile(relativePath, expectedHash: expectedHash);
}
