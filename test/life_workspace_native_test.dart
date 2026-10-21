import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/application/backup_bundle.dart';
import 'package:orbit_note/domain/life_workspace.dart';
import 'package:orbit_note/domain/life_templates.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

void main() {
  test(
    'native Life knowledge, templates and logs rebuild from portable files without a database',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-life-portable-',
      );
      var repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: root.path);
        final ids = <String>[];
        for (final preset in lifePresets) {
          final object = await repo.create(
            typeId: 'orbit.note',
            title: preset.title,
            body: preset.body,
            properties: {
              'life': {
                'version': 1,
                'kind': preset.kind.name,
                'state': 'active',
                ...preset.fields,
                'future': {'keep': true},
              },
            },
          );
          ids.add(object.id);
          expect(
            await File(
              '${root.path}/${repo.objectPath(object.id)}',
            ).readAsString(),
            contains(preset.body.split('\n').first),
          );
        }
        final habit = repo.objects.firstWhere(
          (o) => lifeKind(o) == LifeKind.habit,
        );
        final log = await repo.create(
          typeId: 'orbit.note',
          title: 'Dated record',
          properties: {
            'life': {
              'version': 1,
              'kind': 'habitLog',
              'state': 'active',
              'parentId': habit.id,
              'date': '2026-10-21',
              'value': 4,
              'outcome': 'done',
            },
          },
        );
        final bundle = BackupBundle.parse(await repo.exportBundle());
        expect(bundle.files.keys.any((p) => p.endsWith('.md')), true);
        await repo.close();
        repo = WorkspaceRepository(
          store: NativeWorkspaceStore(),
          index: MemoryObjectIndex(),
        );
        await repo.initialize(path: root.path);
        final index = LifeIndex(repo.objects, now: DateTime(2026, 10, 21));
        expect(index.records, hasLength(lifePresets.length + 1));
        expect(index.byId.keys.toSet(), containsAll(ids));
        expect(index.children[habit.id]!.single.id, log.id);
        expect(index.habitValue(habit.id, index.now), 4);
        expect(
          index.records
              .where((o) => o.id != log.id)
              .every((o) => lifeData(o)['future']['keep'] == true),
          true,
        );
      } finally {
        await repo.close();
        final resolved = await root.resolveSymbolicLinks(),
            temp = await Directory.systemTemp.resolveSymbolicLinks();
        if (!resolved.toLowerCase().startsWith(
              '${temp.toLowerCase()}${Platform.pathSeparator}',
            ) ||
            !root.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('orbit-life-portable-')) {
          throw StateError('Unexpected cleanup target');
        }
        await root.delete(recursive: true);
      }
    },
  );
}
