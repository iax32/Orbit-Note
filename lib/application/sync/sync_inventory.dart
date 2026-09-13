import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/object_tombstone.dart';
import '../../domain/sync_entry.dart';
import '../../domain/universal_object.dart';
import '../../domain/workspace_failure.dart';
import '../../infrastructure/storage/object_codec.dart';
import '../../infrastructure/storage/workspace_store.dart';
import 'sync_policy.dart';

class SyncInventory {
  SyncInventory(
    Map<String, SyncEntry> entries,
    Map<String, String> sources,
    List<String> folders,
    List<String> issues,
  ) : entries = Map.unmodifiable(entries),
      sourcePaths = Map.unmodifiable(sources),
      folders = List.unmodifiable(folders),
      issues = List.unmodifiable(issues);
  final Map<String, SyncEntry> entries;
  final Map<String, String> sourcePaths;
  final List<String> folders, issues;
  bool get ready => issues.isEmpty;
}

class SyncFootprint {
  const SyncFootprint(this.files, this.bytes, this.largest);
  final int files, bytes, largest;
}

/// Invoked under the repository command queue. It never rewrites a file or index.
/// Unknown authored files block complete-sync claims instead of being discarded.
Future<SyncInventory> captureSyncInventory(
  WorkspaceStore store,
  String workspaceId,
) async {
  final entries = <String, SyncEntry>{}, sources = <String, String>{};
  final issues = <String>[];
  final objects = <UniversalObject>[];
  final attachmentHashes = <String, String>{};
  final paths = await store.listFiles();
  final deviceBytes = await store.read('.orbit/device/settings.json');
  if (deviceBytes != null) {
    try {
      final settings = jsonDecode(utf8.decode(deviceBytes)) as Map;
      final data = settings['data'];
      if (data is Map &&
          data['archivedFolders'] is List &&
          (data['archivedFolders'] as List).isNotEmpty) {
        issues.add(
          'Folder Archive is currently device-local. Migrate its metadata before connecting this Vault to sync.',
        );
      }
    } on Object {
      issues.add(
        'Device settings need review before checking portable Archive metadata.',
      );
    }
  }
  for (final path in paths) {
    if (path.startsWith('.orbit/recovery/') ||
        RegExp(r'\.orbit-[^/]+\.tmp$').hasMatch(path)) {
      issues.add('Pending recovery must be resolved before sync: $path');
    }
    try {
      final role = syncPathRole(path);
      if (role == SyncPathRole.excluded) continue;
      if (role == SyncPathRole.unsupported) {
        issues.add('Unrecognized file needs an explicit sync policy: $path');
        continue;
      }
      var logicalPath = path;
      String key, hash;
      var deleted = false;
      if (role == SyncPathRole.attachment && store is WorkspaceStreamingStore) {
        key = 'blob:$path';
        hash =
            (await sha256
                    .bind((store as WorkspaceStreamingStore).openRead(path))
                    .first)
                .toString();
        attachmentHashes[path] = hash;
      } else {
        final bytes = await store.read(path);
        if (bytes == null) throw const WorkspaceConflict('File disappeared.');
        hash = sha256.convert(bytes).toString();
        if (role == SyncPathRole.attachment) {
          key = 'blob:$path';
          attachmentHashes[path] = hash;
        } else if (role == SyncPathRole.manifest) {
          final manifest = jsonDecode(utf8.decode(bytes)) as Map;
          if (manifest['format'] != 'orbit-note-workspace' ||
              manifest['version'] != 1 ||
              manifest['id'] != workspaceId) {
            throw const WorkspaceConflict(
              'Vault identity or version mismatch.',
            );
          }
          key = 'vault:$workspaceId';
        } else if (role == SyncPathRole.tombstone) {
          final record = ObjectTombstone.fromJson(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
          );
          if (record.workspaceId != workspaceId || record.storagePath != path) {
            throw const WorkspaceConflict('Deletion identity mismatch.');
          }
          key = record.objectId;
          logicalPath = record.path;
          deleted = true;
        } else {
          final object = ObjectCodec().decode(
            utf8.decode(bytes),
            workspaceId,
            markdown: path.endsWith('.md'),
          );
          if (object.isReadOnly) {
            throw const WorkspaceReadOnly('Newer object format.');
          }
          objects.add(object);
          key = object.id;
        }
      }
      if (entries.containsKey(key)) {
        throw const WorkspaceConflict('Duplicate object/deletion identity.');
      }
      entries[key] = SyncEntry(
        key: key,
        path: logicalPath,
        hash: hash,
        deleted: deleted,
      );
      sources[key] = path;
    } on Object catch (error) {
      issues.add('Cannot safely synchronize $path: $error');
    }
  }
  if (!entries.containsKey('vault:$workspaceId')) {
    issues.add('A valid Vault manifest is required.');
  }
  for (final object in objects.where((o) => o.typeId == 'orbit.file')) {
    final path = object.properties['contentRef'];
    if (path is! String ||
        !attachmentHashes.containsKey(path) ||
        attachmentHashes[path] != object.properties['checksum']) {
      issues.add('Attachment is missing or changed for object ${object.id}.');
    }
  }
  try {
    validateSyncEntries(entries);
  } on Object catch (error) {
    issues.add('$error');
  }
  final folders = store is WorkspaceFolderStore
      ? await (store as WorkspaceFolderStore).listFolders()
      : <String>[];
  return SyncInventory(entries, sources, folders, issues);
}
