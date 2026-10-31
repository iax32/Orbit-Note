import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/object_codec.dart';
import 'support/memory_store.dart';

class _ObservedStore extends FolderMemoryStore {
  int noteReads = 0;
  @override
  Future<Uint8List?> read(String path) {
    if (path.startsWith('Notes/')) noteReads++;
    return super.read(path);
  }
}

void main() {
  test(
    'warm-file Vault scan yields before publishing its complete compatible snapshot',
    () async {
      final store = _ObservedStore(), codec = ObjectCodec();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      const count = 2000;
      for (var i = 0; i < count; i++) {
        final o = UniversalObject(
          id: 'fixture-$i',
          workspaceId: repo.workspaceId,
          typeId: 'orbit.note',
          title: 'Source $i',
          body: 'Exact café 😀 $i\r\n',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          properties: {
            'future-field': {'n': i},
          },
        );
        store.files['Notes/fixture-$i.md'] = Uint8List.fromList(
          utf8.encode(codec.encode(o)),
        );
      }
      final last = Uint8List.fromList(store.files['Notes/fixture-1999.md']!);
      var scanTicks = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
        if (store.noteReads > 0 && store.noteReads < count) {
          scanTicks++;
          expect(repo.objects, isEmpty);
        }
      });
      try {
        await repo.initialize();
        expect(scanTicks, greaterThan(0));
        expect(repo.objects, hasLength(count));
        final tail = repo.objects.firstWhere((o) => o.id == 'fixture-1999');
        expect(tail.body, 'Exact café 😀 1999\r\n');
        expect(tail.properties['future-field'], {'n': 1999});
        expect(store.files['Notes/fixture-1999.md'], orderedEquals(last));
      } finally {
        timer.cancel();
        await repo.close();
        await codec.close();
      }
    },
  );
}
