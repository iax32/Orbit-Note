import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';

void main() {
  test('a separate process cannot acquire an owned Vault', () async {
    final sdk = Platform.environment['FLUTTER_ROOT'];
    final cache = sdk == null
        ? File(Platform.resolvedExecutable).parent.parent.parent.parent.path
        : '$sdk/bin/cache';
    final dart = File(
      '$cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}',
    );
    expect(
      await dart.exists(),
      isTrue,
      reason: 'Native lock conformance requires the Flutter Dart SDK.',
    );
    final root = await Directory.systemTemp.createTemp('orbit-process-lock-');
    final store = NativeWorkspaceStore();
    try {
      await store.initialize(path: root.path);
      final args = [
        'tool/vault_lock_probe.dart',
        '${root.path}/.orbit/device/vault.lock',
      ];
      final denied = await Process.run(dart.path, args);
      expect(denied.exitCode, 2, reason: '${denied.stderr}');
      await store.close();
      final allowed = await Process.run(dart.path, args);
      expect(allowed.exitCode, 0, reason: '${allowed.stderr}');
    } finally {
      await store.close();
      await root.delete(recursive: true);
    }
  });
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

  test('rapid close and immediate reopen of the same Vault succeeds', () async {
    final root = await Directory.systemTemp.createTemp('orbit-rapid-reopen-');
    final store = NativeWorkspaceStore();
    try {
      for (var i = 0; i < 10; i++) {
        await store.initialize(path: root.path);
        await store.close();
      }
    } finally {
      await store.close();
      await root.delete(recursive: true);
    }
  });
}
