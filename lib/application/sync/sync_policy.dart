import '../../domain/sync_entry.dart';
import '../../domain/workspace_failure.dart';
import '../../infrastructure/storage/path_safety.dart';

enum SyncPathRole {
  manifest,
  object,
  attachment,
  tombstone,
  excluded,
  unsupported,
}

SyncPathRole syncPathRole(String path) {
  validateRelativePath(path);
  if (RegExp(r'\.orbit-[^/]+\.tmp$').hasMatch(path) ||
      path.startsWith('.orbit/device/') ||
      path.startsWith('.orbit-sync/')) {
    return SyncPathRole.excluded;
  }
  if (path.startsWith('.orbit/tombstones/') && path.endsWith('.json')) {
    return SyncPathRole.tombstone;
  }
  if (path.startsWith('.orbit/')) return SyncPathRole.excluded;
  if (path == 'workspace.json') return SyncPathRole.manifest;
  if (path.startsWith('Attachments/')) return SyncPathRole.attachment;
  if ((path.startsWith('Notes/') && path.endsWith('.md')) ||
      (path.startsWith('Objects/') && path.endsWith('.object.json')) ||
      (path.startsWith('Boards/') && path.endsWith('.board.json')) ||
      (path.startsWith('Drawings/') && path.endsWith('.drawing.json'))) {
    return SyncPathRole.object;
  }
  // Loose user documents are opaque blobs, not Orbit objects. Keep their exact
  // relative paths; never infer object identities or decode them as UTF-8.
  // Hidden/configuration files and unknown formats still need explicit policy.
  final parts = path.split('/');
  final name = parts.last.toLowerCase();
  final dot = name.lastIndexOf('.');
  if (!parts.any((part) => part.startsWith('.')) &&
      dot > 0 &&
      _looseFileExtensions.contains(name.substring(dot + 1))) {
    return SyncPathRole.attachment;
  }
  return SyncPathRole.unsupported;
}

const _looseFileExtensions = {
  'pdf',
  'txt',
  'md',
  'markdown',
  'rtf',
  'csv',
  'tsv',
  'doc',
  'docx',
  'odt',
  'xls',
  'xlsx',
  'ods',
  'ppt',
  'pptx',
  'odp',
  'epub',
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'tif',
  'tiff',
  'svg',
  'avif',
  'heic',
  'mp3',
  'wav',
  'ogg',
  'flac',
  'm4a',
  'aac',
  'mp4',
  'webm',
  'mov',
  'mkv',
  'glb',
  'gltf',
  'obj',
  'mtl',
  'stl',
  'fbx',
  'blend',
};

void validateSyncEntries(Map<String, SyncEntry> entries) {
  final paths = <String>{};
  for (final pair in entries.entries) {
    final entry = pair.value;
    SyncEntry.fromJson(entry.toJson());
    final path = entry.path;
    final role = syncPathRole(path);
    if (entry.key != pair.key ||
        role == SyncPathRole.excluded ||
        role == SyncPathRole.unsupported ||
        path.length > 220 ||
        path
            .split('/')
            .any(
              (part) =>
                  part.endsWith('.') ||
                  part.endsWith(' ') ||
                  RegExp(r'[<>"|?*\x00-\x1f]').hasMatch(part) ||
                  RegExp(
                    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
                    caseSensitive: false,
                  ).hasMatch(part),
            )) {
      throw const WorkspaceFailure(
        'Sync contains an unsupported identity or nonportable path.',
      );
    }
    if (!paths.add(path.toLowerCase())) {
      throw const WorkspaceConflict('Sync paths collide.');
    }
  }
  for (final path in paths) {
    final parts = path.split('/');
    for (var i = 1; i < parts.length; i++) {
      if (paths.contains(parts.take(i).join('/'))) {
        throw const WorkspaceConflict('A sync path is both file and folder.');
      }
    }
  }
}
