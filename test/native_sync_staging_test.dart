import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';

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
}
