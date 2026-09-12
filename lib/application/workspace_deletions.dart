import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../domain/object_tombstone.dart';
import '../domain/workspace_failure.dart';
import '../infrastructure/storage/object_codec.dart';
import '../infrastructure/storage/path_safety.dart';
import '../infrastructure/storage/workspace_store.dart';

/// Roll forward only a locally prepared, exact-version object deletion.
/// Portable tombstones are declarative: their presence never executes a delete.
class WorkspaceDeletions {
  WorkspaceDeletions(this.store, this.workspaceId);
  final WorkspaceStore store;
  final String workspaceId;

  static bool ownsPath(String path) =>
      (path.startsWith('Notes/') && path.endsWith('.md')) ||
      (path.startsWith('Objects/') && path.endsWith('.object.json')) ||
      (path.startsWith('Boards/') && path.endsWith('.board.json')) ||
      (path.startsWith('Drawings/') && path.endsWith('.drawing.json'));

  static bool isJournal(String path) =>
      path.startsWith('.orbit/recovery/delete-') && path.endsWith('.json');

  Future<void> delete(String objectId, String path, String expectedHash) async {
    final record = ObjectTombstone(
      workspaceId: workspaceId,
      objectId: objectId,
      operationId: const Uuid().v4(),
      path: path,
      beforeHash: expectedHash,
      deletedAt: DateTime.now().toUtc(),
    );
    // Validate before publishing an intent; unknown formats remain untouched.
    ObjectTombstone.fromJson(record.toJson());
    await _validateSource(record, allowAbsent: false);
    if (await store.read(record.storagePath) != null) {
      throw const WorkspaceConflict(
        'A deletion record already exists for this object.',
      );
    }
    final journal = '.orbit/recovery/delete-$objectId.json';
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'orbit-note-object-delete',
          'version': 1,
          'tombstone': record.toJson(),
        }),
      ),
    );
    await store.write(journal, bytes, expectedHash: null);
    await _finish(journal, bytes);
  }

  Future<void> recover() async {
    for (final path in (await store.listFiles()).where(isJournal)) {
      final bytes = await store.read(path);
      if (bytes == null) continue;
      await _finish(path, bytes);
    }
  }

  Future<Uint8List?> _validateSource(
    ObjectTombstone record, {
    required bool allowAbsent,
  }) async {
    validateRelativePath(record.path);
    if (record.workspaceId != workspaceId ||
        !ownsPath(record.path) ||
        record.path.contains('.orbit-')) {
      throw const WorkspaceConflict(
        'Deletion belongs to a different Vault or unsupported path.',
      );
    }
    final current = await store.read(record.path);
    if (current == null) {
      if (allowAbsent) return null;
      throw const WorkspaceConflict(
        'The object file disappeared before deletion.',
      );
    }
    if (sha256.convert(current).toString() != record.beforeHash) {
      throw const WorkspaceConflict(
        'The object changed before deletion; its current bytes are preserved.',
      );
    }
    final object = ObjectCodec().decode(
      utf8.decode(current),
      workspaceId,
      markdown: record.path.endsWith('.md'),
    );
    if (object.id != record.objectId || object.isReadOnly) {
      throw const WorkspaceConflict(
        'Deletion identity or format does not match.',
      );
    }
    return current;
  }

  Future<void> _finish(String journal, Uint8List journalBytes) async {
    final json = jsonDecode(utf8.decode(journalBytes)) as Map<String, dynamic>;
    if (json['format'] != 'orbit-note-object-delete' || json['version'] != 1) {
      throw const FormatException('Unsupported deletion journal retained.');
    }
    final record = ObjectTombstone.fromJson(
      Map<String, dynamic>.from(json['tombstone'] as Map),
    );
    if (journal != '.orbit/recovery/delete-${record.objectId}.json') {
      throw const FormatException('Deletion journal identity mismatch.');
    }
    final tombstoneBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(record.toJson())),
    );
    final prior = await store.read(record.storagePath);
    if (prior != null &&
        sha256.convert(prior).toString() !=
            sha256.convert(tombstoneBytes).toString()) {
      throw const WorkspaceConflict(
        'Conflicting deletion records are preserved.',
      );
    }
    final current = await _validateSource(record, allowAbsent: true);
    if (current != null) {
      await store.deleteFile(record.path, expectedHash: record.beforeHash);
    }
    // A crash here leaves the journal to publish the same tombstone on reopen.
    if (prior == null) {
      await store.write(record.storagePath, tombstoneBytes, expectedHash: null);
    }
    await store.deleteFile(
      journal,
      expectedHash: sha256.convert(journalBytes).toString(),
    );
  }
}
