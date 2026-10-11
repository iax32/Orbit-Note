import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

import 'support/memory_store.dart';

void main() {
  late MemoryStore store;
  late WorkspaceRepository repository;

  setUp(() async {
    store = MemoryStore();
    repository = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    await repository.initialize();
    store.files['.orbit/recovery/save-journal.json'] = Uint8List.fromList(
      '{"pending":true}'.codeUnits,
    );
    store.files['.orbit/imported-recovery/conflict.json'] = Uint8List.fromList(
      '{"source":"backup"}'.codeUnits,
    );
    store.files['.orbit/device/recovery/attachment.bin'] = Uint8List.fromList([
      0,
      1,
      255,
    ]);
    store.files['Notes/normal.md'] = Uint8List.fromList('# Note'.codeUnits);
  });

  tearDown(() => repository.close());

  test(
    'lists retained recovery files without exposing ordinary content',
    () async {
      final files = await repository.recoveryFiles();

      expect(files.map((file) => file.path), [
        '.orbit/device/recovery/attachment.bin',
        '.orbit/imported-recovery/conflict.json',
        '.orbit/recovery/save-journal.json',
      ]);
      expect(files.first.length, 3);
    },
  );

  test('reads a bounded immutable recovery copy', () async {
    final snapshot = await repository.readRecoveryFile(
      '.orbit/recovery/save-journal.json',
    );

    expect(snapshot.path, '.orbit/recovery/save-journal.json');
    expect(String.fromCharCodes(snapshot.bytes), '{"pending":true}');
    expect(() => snapshot.bytes[0] = 0, throwsUnsupportedError);
  });

  test('rejects paths outside the retained recovery areas', () async {
    expect(
      () => repository.readRecoveryFile('Notes/normal.md'),
      throwsA(isA<Exception>()),
    );
    expect(
      () => repository.readRecoveryFile('../.orbit/recovery/escape.json'),
      throwsA(isA<Exception>()),
    );
  });
}
