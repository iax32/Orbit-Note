import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/portable_preferences.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

class _PreferenceFailureStore extends MemoryStore {
  bool failPreferences = false;
  @override
  Future<void> write(
    String relativePath,
    Uint8List bytes, {
    required String? expectedHash,
  }) async {
    if (failPreferences && relativePath.startsWith('Objects/')) {
      throw const WorkspaceFailure('Preference disk failure');
    }
    return super.write(relativePath, bytes, expectedHash: expectedHash);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const a = '11111111-1111-4111-8111-111111111111';
  const b = '22222222-2222-4222-8222-222222222222';
  UniversalObject record(
    String id,
    Map<String, dynamic> fields, {
    int version = 1,
  }) => UniversalObject(
    id: id,
    workspaceId: a,
    typeId: PortablePreferences.typeId,
    title: 'Preferences',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    data: {'version': version, 'fields': fields},
  );
  Map<String, dynamic> field(int clock, dynamic value) => {
    'clock': clock,
    'value': value,
  };

  test(
    'independent changes merge deterministically without wall clock time',
    () {
      final records = [
        record(a, {'themePreset': field(1, 'paper'), 'fontSize': field(3, 20)}),
        record(b, {
          'themePreset': field(2, 'orbit'),
          'defaultCodeWrap': field(3, true),
        }),
      ];
      final merged = PortablePreferences.merge(records);
      expect(merged.values, {
        'themePreset': 'orbit',
        'fontSize': 20,
        'defaultCodeWrap': true,
      });
      expect(PortablePreferences.merge(records.reversed).values, merged.values);
      expect(merged.clock, 3);
      final tied = [
        record(a, {'fontSize': field(5, 18)}),
        record(b, {'fontSize': field(5, 22)}),
      ];
      expect(PortablePreferences.merge(tied).values['fontSize'], 22);
      expect(PortablePreferences.merge(tied.reversed).values['fontSize'], 22);
    },
  );

  test(
    'unknown records preserved; future/corrupt data refused; secrets excluded',
    () {
      expect(
        () => PortablePreferences.merge([record(a, {}, version: 2)]),
        throwsFormatException,
      );
      expect(
        () => PortablePreferences.merge([
          record(a, {'fontSize': field(-1, 20)}),
        ]),
        throwsFormatException,
      );
      final unknown = record(a, {
        'future': field(9, {'retained': true}),
      });
      expect(PortablePreferences.merge([unknown]).clock, 9);
      expect(unknown.data['fields'], contains('future'));
      final selected = PortablePreferences.select({
        'themePreset': 'paper',
        'uiZoom': 2,
        'tabs': [a],
        'pythonExecutable': 'private-path',
        'accessToken': 'private',
      });
      expect(selected, isNot(contains('uiZoom')));
      expect(selected, isNot(contains('tabs')));
      expect(selected, isNot(contains('pythonExecutable')));
      expect(selected, isNot(contains('accessToken')));
    },
  );

  Future<
    ({
      ProviderContainer container,
      WorkspaceController c,
      WorkspaceRepository repo,
    })
  >
  open(MemoryStore store) async {
    final repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    final c = container.read(workspaceProvider.notifier);
    await c.initialize();
    return (container: container, c: c, repo: repo);
  }

  test(
    'settings survive reopen, pending local changes survive remote refresh',
    () async {
      final store = MemoryStore();
      final first = await open(store);
      first.c.updateSession((s) {
        s.collapsedFolders = ['Notes/Research'];
        s.fontSize = 21;
        s.uiZoom = 1.5;
      });
      expect(await first.c.flushAll(), isTrue);
      expect(first.repo.preferenceRecords, hasLength(1));
      expect(first.repo.objects, isEmpty);
      expect(await first.repo.search('Workspace preferences'), isEmpty);
      final portable = first.repo.preferenceRecords.single;
      expect(portable.data.toString(), isNot(contains('uiZoom')));
      first.c.cancelAllTimers();
      first.container.dispose();
      final second = await open(store);
      expect(second.c.session.collapsedFolders, ['Notes/Research']);
      expect(second.c.session.fontSize, 21);
      expect(second.c.session.uiZoom, 1.5);
      // In-place edits must not mutate the saved comparison snapshot.
      second.c.updateSession((s) => s.collapsedFolders.clear());
      expect(await second.c.flushAll(), isTrue);
      expect(
        PortablePreferences.merge(
          second.repo.preferenceRecords,
        ).values['collapsedFolders'],
        isEmpty,
      );
      second.c.updateSession((s) => s.fontSize = 24);
      await second.repo.writePortablePreferences(b, {
        'fontSize': 18,
        'defaultCodeWrap': true,
      });
      second.c.mergeRepositoryObjects();
      expect(second.c.session.fontSize, 24);
      expect(second.c.session.defaultCodeWrap, isTrue);
      expect(await second.c.flushAll(), isTrue);
      expect(
        PortablePreferences.merge(
          second.repo.preferenceRecords,
        ).values['fontSize'],
        24,
      );
      second.c.cancelAllTimers();
      second.container.dispose();
    },
  );

  test(
    'first-run devices publish choices, not competing default snapshots',
    () async {
      final storeA = MemoryStore();
      final first = await open(storeA);
      final storeB = MemoryStore()..files.addAll(storeA.files);
      final second = await open(storeB);
      first.c.updateSession((s) => s.fontSize = 23);
      second.c.updateSession((s) => s.themePreset = 'paper');
      expect(await first.c.flushAll(), isTrue);
      expect(await second.c.flushAll(), isTrue);
      expect(
        PortablePreferences.fields(first.repo.preferenceRecords.single).keys,
        ['fontSize'],
      );
      expect(
        PortablePreferences.fields(second.repo.preferenceRecords.single).keys,
        ['themePreset'],
      );
      final merged = PortablePreferences.merge([
        ...first.repo.preferenceRecords,
        ...second.repo.preferenceRecords,
      ]).values;
      expect(merged, {'fontSize': 23, 'themePreset': 'paper'});
      first.c.cancelAllTimers();
      second.c.cancelAllTimers();
      first.container.dispose();
      second.container.dispose();
    },
  );

  test(
    'failed portable save remains recoverable after closing and reopening',
    () async {
      final store = _PreferenceFailureStore();
      final first = await open(store);
      expect(await first.c.flushAll(), isTrue);
      first.c.updateSession((s) => s.fontSize = 23);
      store.failPreferences = true;
      expect(await first.c.flushAll(), isFalse);
      expect(first.c.error, contains('Preference disk failure'));
      first.c.cancelAllTimers();
      first.container.dispose();
      store.failPreferences = false;
      final second = await open(store);
      expect(second.c.session.fontSize, 23);
      expect(await second.c.flushAll(), isTrue);
      expect(
        PortablePreferences.merge(
          second.repo.preferenceRecords,
        ).values['fontSize'],
        23,
      );
      second.c.cancelAllTimers();
      second.container.dispose();
    },
  );
}
