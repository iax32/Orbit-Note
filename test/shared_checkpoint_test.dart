import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/platform/shared_checkpoint.dart';
import 'package:orbit_note/infrastructure/storage/workspace_sync_state_store.dart';
import 'support/memory_store.dart';

void main() {
  test(
    'disconnect while encoding cannot write a stale shared journal',
    () async {
      final files = MemoryStore();
      await files.initialize();
      var current = true;
      const path = '.orbit/device/shared/guard.json';
      final store = WorkspaceSyncStateStore(
        files,
        storagePath: path,
        checkCurrent: () {
          if (!current) throw StateError('Opening changed');
        },
      );
      await store.load();
      final saving = store.save({'snapshot': 'large ' * 100000});
      current = false;
      await expectLater(saving, throwsA(isA<StateError>()));
      expect(await files.read(path), isNull);
    },
  );
  test(
    'large shared journal survives restart with original exact snapshots',
    () async {
      final files = MemoryStore();
      await files.initialize();
      const path = '.orbit/device/shared/test.json';
      final first = WorkspaceSyncStateStore(files, storagePath: path);
      expect(await first.load(), isNull);
      final text = 'pressure sample 😀\r\n' * 600000;
      final state = <String, dynamic>{
        'format': 'orbit-shared-outbox',
        'version': 1,
        'documents': {
          'board': {'snapshot': text},
        },
        'inflight': {
          'board': {'snapshot': '$text next', 'operation': 'stable-op'},
        },
        'future': [1, 2, 3],
      };
      expect(
        utf8.encode(jsonEncode(state)).length,
        greaterThan(16 * 1024 * 1024),
      );
      final watch = Stopwatch()..start();
      await first.save(state);
      watch.stop();
      final stored = await files.read(path);
      expect(stored!.length, lessThan(16 * 1024 * 1024));
      final restarted = WorkspaceSyncStateStore(files, storagePath: path);
      expect(await restarted.load(), state);
      // Byte ownership/compare-before-write still refuses another writer.
      await first.save({...state, 'future': 'newer'});
      await expectLater(restarted.save(state), throwsA(anything));
      // ignore: avoid_print
      print(
        'SHARED_CHECKPOINT: decoded=${utf8.encode(jsonEncode(state)).length} stored=${stored.length} saveMs=${watch.elapsedMilliseconds}',
      );
    },
  );
  test(
    'legacy JSON and damaged compressed journals remain distinguishable',
    () async {
      final old = Uint8List.fromList(
        utf8.encode('{"version":1,"future":true}'),
      );
      expect(await decodeSharedCheckpoint(old), {'version': 1, 'future': true});
      await expectLater(
        decodeSharedCheckpoint(Uint8List.fromList([31, 139, 0, 0])),
        throwsA(anything),
      );
    },
  );
}
