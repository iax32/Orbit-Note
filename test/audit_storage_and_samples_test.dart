import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

class _Store extends MemoryStore {
  int settingsWrites = 0;
  @override
  Future<void> write(
    String relativePath,
    Uint8List bytes, {
    required String? expectedHash,
  }) {
    if (relativePath == '.orbit/device/settings.json') settingsWrites++;
    return super.write(relativePath, bytes, expectedHash: expectedHash);
  }
}

class _ObservedWorkspace extends WorkspaceController {
  int notifications = 0;
  @override
  void notify() {
    notifications++;
    super.notify();
  }
}

void main() {
  test(
    'device view checkpoints avoid root notifications; preferences and failures still announce',
    () async {
      final store = _Store();
      final repository = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repository.initialize();
      addTearDown(repository.close);
      final workspace = _ObservedWorkspace()
        ..repository = repository
        ..hasWorkspace = true
        ..loading = false;
      addTearDown(workspace.cancelAllTimers);
      await workspace.saveSession();
      final initial = workspace.notifications;
      workspace.session.positions = {'example': 200};
      await workspace.saveSession();
      expect(workspace.notifications, initial);
      expect((await repository.readDeviceSettings())['positions'], {
        'example': 200.0,
      });
      workspace.session.fontSize += 1;
      await workspace.saveSession();
      expect(workspace.notifications, initial + 1);
      store.failWrites = true;
      workspace.session.positions = {'example': 300};
      await workspace.saveSession();
      expect(workspace.sessionSaveFailed, isTrue);
      expect(workspace.notifications, initial + 2);
      store.failWrites = false;
      await workspace.saveSession();
      expect(workspace.sessionSaveFailed, isFalse);
      expect(workspace.notifications, initial + 3);
    },
  );
  test(
    'identical device settings do not journal a write; future and extension fields remain safe',
    () async {
      final store = _Store();
      final repository = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repository.initialize();
      addTearDown(repository.close);
      await repository.writeDeviceSettings({'theme': 'warm-paper'});
      final writes = store.settingsWrites;
      for (var i = 0; i < 20; i++) {
        await repository.writeDeviceSettings({'theme': 'warm-paper'});
      }
      expect(store.settingsWrites, writes);
      final record =
          jsonDecode(utf8.decode(store.files['.orbit/device/settings.json']!))
              as Map;
      store.files['.orbit/device/settings.json'] = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            ...record,
            'futureExtension': {'keep': true},
          }),
        ),
      );
      await repository.writeDeviceSettings({'theme': 'orbit-dark'});
      final changed =
          jsonDecode(utf8.decode(store.files['.orbit/device/settings.json']!))
              as Map;
      expect(changed['futureExtension'], {'keep': true});
      store.files['.orbit/device/settings.json'] = Uint8List.fromList(
        utf8.encode(jsonEncode({...changed, 'version': 999})),
      );
      await expectLater(
        repository.writeDeviceSettings({'theme': 'orbit-dark'}),
        throwsA(isA<WorkspaceReadOnly>()),
      );
      expect(
        jsonDecode(
          utf8.decode(store.files['.orbit/device/settings.json']!),
        )['version'],
        999,
      );
    },
  );
  test(
    'immutable ink reuses its sample view; malformed and mutable legacy samples retain behavior',
    () {
      final owned = CanvasElement(
        immutableObjectData({
          'id': 'stroke',
          'type': 'ink',
          'points': [
            null,
            {'x': 1, 'pressure': .3},
            'unknown',
            {'x': 2, 'pressure': .7},
          ],
        }),
      );
      expect(owned.inkSamples!.length, 2);
      expect(identical(owned.inkSamples, owned.inkSamples), isTrue);
      expect(() => owned.inkSamples!.clear(), throwsUnsupportedError);
      final mutable = <dynamic>[
        {'x': 1, 'y': 2},
      ];
      final legacy = CanvasElement({
        'id': 'legacy',
        'type': 'ink',
        'points': mutable,
      });
      expect(legacy.inkSamples!.length, 1);
      mutable.add({'x': 2, 'y': 3});
      expect(legacy.inkSamples!.length, 2);
    },
  );
}
