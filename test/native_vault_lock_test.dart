import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';

void main() {
  test(
    'native Vault ownership rejects another store and releases on close',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-lock-');
      final first = NativeWorkspaceStore(), second = NativeWorkspaceStore();
      try {
        await first.initialize(path: root.path);
        await expectLater(
          second.initialize(path: root.path),
          throwsA(isA<WorkspaceFailure>()),
        );
        await first.close();
        await second.initialize(path: root.path);
        await second.close();
        // An old lock file does not imply an active process.
        await first.initialize(path: root.path);
      } finally {
        await first.close();
        await second.close();
        await root.delete(recursive: true);
      }
    },
  );

  test('failed initialization releases the previous Vault lock', () async {
    final root = await Directory.systemTemp.createTemp('orbit-lock-switch-');
    final first = NativeWorkspaceStore(), second = NativeWorkspaceStore();
    try {
      await first.initialize(path: '${root.path}/vault');
      final bad = File('${root.path}/not-a-directory');
      await bad.writeAsString('occupied');
      await expectLater(
        first.initialize(path: bad.path),
        throwsA(isA<FileSystemException>()),
      );
      await second.initialize(path: '${root.path}/vault');
    } finally {
      await first.close();
      await second.close();
      await root.delete(recursive: true);
    }
  });
}
