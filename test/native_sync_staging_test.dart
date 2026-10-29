import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';

void main() {
  late Directory root;
  late NativeWorkspaceStore store;
  final bytes = Uint8List.fromList(utf8.encode('verified attachment'));
  final hash = sha256.convert(bytes).toString();
  setUp(() async {
    root = await Directory.systemTemp.createTemp('orbit-stage-');
    store = NativeWorkspaceStore();
    await store.initialize(path: root.path);
  });
  tearDown(() async {
    await store.close();
    await root.delete(recursive: true);
  });

  test('transfer limit and stream errors clean partial staging', () async {
    await expectLater(
      store.stage(Stream.value(bytes), expectedHash: hash, maxBytes: 1),
      throwsA(isA<WorkspaceFailure>()),
    );
    Stream<List<int>> broken() async* {
      yield bytes;
      throw const WorkspaceFailure('offline');
    }

    await expectLater(
      store.stage(broken(), expectedHash: hash, maxBytes: 100),
      throwsA(isA<WorkspaceFailure>()),
    );
    expect(
      (await store.listFiles()).where((p) => p.endsWith('.part')),
      isEmpty,
    );
  });
  test(
    'validated native stages expose exact reusable checksum proof',
    () async {
      final stage = await store.stageWithChecksums(
        Stream.value(bytes),
        expectedHash: hash,
        maxBytes: 100,
      );
      try {
        expect(stage, isA<WorkspaceStageChecksums>());
        expect(
          (stage as WorkspaceStageChecksums).md5Hash,
          md5.convert(bytes).toString(),
        );
        expect(await stage.openRead().expand((c) => c).toList(), bytes);
      } finally {
        await stage.close();
      }
    },
  );

  test(
    'guard rejection removes automatic recovery intent before reopen',
    () async {
      final stage = await store.stage(
        Stream.value(bytes),
        expectedHash: hash,
        maxBytes: 100,
      );
      var checks = 0;
      await expectLater(
        stage.commit(
          'Attachments/new.bin',
          expectedHash: null,
          checkCurrent: () {
            if (++checks == 3) throw const WorkspaceConflict('Draft appeared');
          },
        ),
        throwsA(isA<WorkspaceConflict>()),
      );
      await stage.close();
      expect(await store.read('Attachments/new.bin'), isNull);
      expect(
        (await store.listFiles()).where(
          (p) => p.startsWith('.orbit/recovery/'),
        ),
        isEmpty,
      );
      await store.initialize(path: root.path);
      expect(await store.read('Attachments/new.bin'), isNull);
    },
  );

  test('changed staged content never publishes', () async {
    final stage = await store.stage(
      Stream.value(bytes),
      expectedHash: hash,
      maxBytes: 100,
    );
    final path = (await store.listFiles()).singleWhere(
      (p) => p.endsWith('.part'),
    );
    await File('${root.path}/$path').writeAsString('tampered', flush: true);
    await expectLater(
      stage.commit(
        'Attachments/new.bin',
        expectedHash: null,
        checkCurrent: () {},
      ),
      throwsA(isA<WorkspaceConflict>()),
    );
    await stage.close();
    expect(await store.read('Attachments/new.bin'), isNull);
  });

  test('stale expected hash preserves external content', () async {
    await store.write('Attachments/new.bin', bytes, expectedHash: null);
    final stage = await store.stage(
      Stream.value(bytes),
      expectedHash: hash,
      maxBytes: 100,
    );
    await File(
      '${root.path}/Attachments/new.bin',
    ).writeAsString('external', flush: true);
    await expectLater(
      stage.commit(
        'Attachments/new.bin',
        expectedHash: hash,
        checkCurrent: () {},
      ),
      throwsA(isA<WorkspaceConflict>()),
    );
    await stage.close();
    expect(utf8.decode((await store.read('Attachments/new.bin'))!), 'external');
  });

  test('closed stage cannot publish into a reopened store', () async {
    final stage = await store.stage(
      Stream.value(bytes),
      expectedHash: hash,
      maxBytes: 100,
    );
    await store.initialize(path: root.path);
    await expectLater(
      stage.commit(
        'Attachments/new.bin',
        expectedHash: null,
        checkCurrent: () {},
      ),
      throwsA(isA<WorkspaceConflict>()),
    );
    await stage.close();
    expect(await store.read('Attachments/new.bin'), isNull);
  });

  test(
    'interrupted attachment stage resumes after reopening the vault',
    () async {
      final complete = Uint8List.fromList([1, 2, 3, 4]);
      final completeHash = sha256.convert(complete).toString();
      final info = WorkspaceAttachmentStageInfo(
        id: 'stage-resume-1',
        operation: 'restore',
        target: 'Attachments/resume.bin',
        expectedHash: completeHash,
        maxBytes: 100,
        length: 0,
      );
      Stream<List<int>> interrupted() async* {
        yield [1, 2];
        throw const WorkspaceFailure('simulated interruption');
      }

      await expectLater(
        store.stageAttachment(interrupted(), info: info),
        throwsA(isA<WorkspaceFailure>()),
      );
      expect((await store.listAttachmentStages()).single.length, 2);

      await store.initialize(path: root.path);
      final resumed = await store.resumeAttachmentStage(
        info.id,
        Stream.value([3, 4]),
      );
      expect(resumed.length, 4);
      await resumed.commit(
        info.target,
        expectedHash: null,
        checkCurrent: () {},
      );
      await resumed.close();
      expect(await store.read(info.target), complete);
      expect(await store.listAttachmentStages(), isEmpty);
    },
  );

  test(
    'discard removes an interrupted attachment stage without publishing it',
    () async {
      final info = WorkspaceAttachmentStageInfo(
        id: 'stage-discard-1',
        operation: 'relink',
        target: 'Attachments/new.bin',
        expectedHash: hash,
        maxBytes: 100,
        length: 0,
        sourceName: 'new.bin',
      );
      Stream<List<int>> interrupted() async* {
        yield bytes;
        throw const WorkspaceFailure('simulated interruption');
      }

      await expectLater(
        store.stageAttachment(interrupted(), info: info),
        throwsA(isA<WorkspaceFailure>()),
      );
      await store.discardAttachmentStage(info.id);
      expect(await store.listAttachmentStages(), isEmpty);
      expect(await store.read(info.target), isNull);
    },
  );

  test(
    'resume offset includes flushed bytes after a crash before manifest update',
    () async {
      final complete = Uint8List.fromList([1, 2, 3, 4]);
      final info = WorkspaceAttachmentStageInfo(
        id: 'crash-tail',
        operation: 'shared-sync',
        target: 'Attachments/crash.bin',
        expectedHash: sha256.convert(complete).toString(),
        maxBytes: 4,
        length: 0,
      );
      Stream<List<int>> broken() async* {
        yield [1];
        throw const WorkspaceFailure('crash');
      }

      await expectLater(
        store.stageAttachment(broken(), info: info),
        throwsA(isA<WorkspaceFailure>()),
      );
      final part = (await store.listFiles()).singleWhere(
        (p) => p.endsWith('crash-tail.part'),
      );
      await File(
        '${root.path}/$part',
      ).writeAsBytes([2, 3], mode: FileMode.append, flush: true);
      await store.initialize(path: root.path);
      expect((await store.listAttachmentStages()).single.length, 3);
      final resumed = await store.resumeAttachmentStage(
        info.id,
        Stream.value([4]),
      );
      await resumed.commit(
        info.target,
        expectedHash: null,
        checkCurrent: () {},
      );
      await resumed.close();
      expect(await store.read(info.target), complete);
    },
  );

  test(
    'reopen prunes only attachment stages older than the retention window',
    () async {
      final info = WorkspaceAttachmentStageInfo(
        id: 'stage-expired-1',
        operation: 'restore',
        target: 'Attachments/expired.bin',
        expectedHash: hash,
        maxBytes: 100,
        length: 0,
      );
      Stream<List<int>> interrupted() async* {
        yield [1, 2];
        throw const WorkspaceFailure('simulated interruption');
      }

      await expectLater(
        store.stageAttachment(interrupted(), info: info),
        throwsA(isA<WorkspaceFailure>()),
      );
      final manifest = File(
        '${root.path}/.orbit/device/recovery/attachments/attachment-${info.id}.json',
      );
      final record =
          jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      record['updatedAt'] = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 31))
          .toIso8601String();
      await manifest.writeAsString(jsonEncode(record), flush: true);

      await store.initialize(path: root.path);
      expect(await store.listAttachmentStages(), isEmpty);
      expect(
        await File(
          '${root.path}/.orbit/device/recovery/attachments/attachment-${info.id}.part',
        ).exists(),
        isFalse,
      );
    },
  );
}
