import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/application/sync/sync_inventory.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/object_codec.dart';
import 'support/memory_store.dart';
import 'canvas_commit_performance_test.dart' show drawing;

void main() {
  test(
    'large sync inventories yield while preserving hashes and validating changed bytes',
    () async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      addTearDown(repo.close);
      await repo.initialize();
      final board = await repo.create(
        typeId: 'orbit.canvas',
        title: 'Large',
        data: drawing(),
      );
      final path = repo.objectPath(board.id)!;
      final original = Uint8List.fromList(store.files[path]!);
      var ticks = 0;
      final heartbeat = Timer.periodic(
        const Duration(milliseconds: 1),
        (_) => ticks++,
      );
      final cold = await captureSyncInventory(store, repo.workspaceId);
      final cached = await repo.syncInventory();
      heartbeat.cancel();
      expect(ticks, greaterThan(0));
      expect(cold.ready, true);
      expect(cached.ready, true);
      expect(
        cold.entries.map((k, v) => MapEntry(k, v.toJson())),
        cached.entries.map((k, v) => MapEntry(k, v.toJson())),
      );
      expect(store.files[path], original);
      expect(repo.objects.firstWhere((o) => o.id == board.id), same(board));
      final known = {path: (hash: cold.entries[board.id]!.hash, object: board)};
      final changed = jsonDecode(utf8.decode(original)) as Map<String, dynamic>;
      changed['object']['id'] = 'external-identity';
      store.files[path] = Uint8List.fromList(utf8.encode(jsonEncode(changed)));
      final after = await captureSyncInventory(
        store,
        repo.workspaceId,
        knownObjects: known,
      );
      expect(after.ready, true);
      expect(after.entries, contains('external-identity'));
      expect(after.entries, isNot(contains(board.id)));
      changed['version'] = 7;
      store.files[path] = Uint8List.fromList(utf8.encode(jsonEncode(changed)));
      expect(
        (await captureSyncInventory(
          store,
          repo.workspaceId,
          knownObjects: known,
        )).ready,
        false,
      );
      store.files[path] = Uint8List.fromList(
        original.take(original.length - 10).toList(),
      );
      final malformed = await captureSyncInventory(
        store,
        repo.workspaceId,
        knownObjects: known,
      );
      expect(
        malformed.ready,
        false,
        reason: 'A valid header cannot bypass malformed trailing data',
      );
    },
  );

  test(
    'compact sync headers preserve attachment validation and future formats',
    () async {
      final codec = ObjectCodec();
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      addTearDown(repo.close);
      await repo.initialize();
      final object = await repo.create(
        typeId: 'orbit.file',
        title: 'Missing',
        properties: {
          'contentRef': 'Attachments/missing.pdf',
          'checksum': '0' * 64,
        },
        data: {'padding': 'x' * 100000},
      );
      final path = repo.objectPath(object.id)!;
      final header = await codec.inspectForSync(
        store.files[path]!,
        repo.workspaceId,
        markdown: false,
      );
      expect(header.id, object.id);
      expect(header.attachmentPath, 'Attachments/missing.pdf');
      expect(header.attachmentHash, '0' * 64);
      final inventory = await captureSyncInventory(store, repo.workspaceId);
      expect(inventory.ready, false);
      expect(
        inventory.issues.any(
          (s) => s.contains('Attachment is missing or changed'),
        ),
        true,
      );
    },
  );
}
