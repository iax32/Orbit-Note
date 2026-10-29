import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/backup_bundle.dart';
import 'package:orbit_note/application/backup_execution.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  test(
    'worker validation preserves portable bytes and rejects corrupt bundles',
    () async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      addTearDown(repo.close);
      await repo.create(
        typeId: 'orbit.note',
        title: 'Portable',
        body: 'x' * 300000,
        properties: {
          'future': {'keep': true},
        },
      );
      final source = await repo.exportBundle();
      final expected = BackupBundle.parse(source);
      final actual = await parseBackupBundle(source);
      expect(actual.files, expected.files);
      expect(actual.totalBytes, expected.totalBytes);
      expect(actual.warnings, expected.warnings);
      final damaged = jsonDecode(source) as Map<String, dynamic>;
      (damaged['files'] as Map)['../outside'] = base64Encode([1]);
      await expectLater(
        parseBackupBundle(jsonEncode(damaged)),
        throwsA(anything),
      );
      await expectLater(parseBackupBundle('{'), throwsA(anything));
    },
  );
}
