import 'dart:convert';
import 'dart:typed_data';

import '../domain/workspace_failure.dart';
import '../infrastructure/storage/object_codec.dart';
import '../infrastructure/storage/path_safety.dart';

/// Fully validated in memory before an import creates anything on disk.
class BackupBundle {
  BackupBundle._(
    this.files,
    this.name,
    this.totalBytes,
    this.warnings,
    this.directories,
  );
  final List<String> directories;
  final Map<String, Uint8List> files;
  final String name;
  final List<String> warnings;
  final int totalBytes;
  static const maxEncodedBytes = 128 * 1024 * 1024;
  static const maxDecodedBytes = 80 * 1024 * 1024;

  factory BackupBundle.parse(String source) {
    if (source.length > maxEncodedBytes) {
      throw const WorkspaceFailure('Backup exceeds the 128 MiB import limit.');
    }
    final root = jsonDecode(source);
    if (root is! Map ||
        root['format'] != 'orbit-note-backup' ||
        root['version'] != 1 ||
        root['encoding'] != 'base64' ||
        root['files'] is! Map) {
      throw const WorkspaceFailure('Unsupported backup format.');
    }
    final entries = root['files'] as Map;
    if (entries.length > 10000) {
      throw const WorkspaceFailure('Too many backup files.');
    }
    final files = <String, Uint8List>{};
    final names = <String>{};
    var total = 0;
    for (final entry in entries.entries) {
      final path = entry.key as String;
      validateRelativePath(path);
      if (path.length > 220 ||
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
        throw const WorkspaceFailure('Backup contains a nonportable path.');
      }
      if (!names.add(path.toLowerCase())) {
        throw const WorkspaceFailure('Backup paths collide.');
      }
      if (path.startsWith('.orbit/device/') ||
          path.startsWith('.orbit/cache/') ||
          path.startsWith('.orbit/workspace.sqlite')) {
        throw const WorkspaceFailure(
          'Backup contains excluded device/cache files.',
        );
      }
      final bytes = base64Decode(entry.value as String);
      total += bytes.length;
      if (total > maxDecodedBytes) {
        throw const WorkspaceFailure('Decoded backup exceeds 80 MiB.');
      }
      files[path] = bytes;
    }
    for (final path in names) {
      final parts = path.split('/');
      for (var i = 1; i < parts.length; i++) {
        if (names.contains(parts.take(i).join('/'))) {
          throw const WorkspaceFailure(
            'A backup path is both a file and a folder.',
          );
        }
      }
    }
    final manifestBytes = files['workspace.json'];
    final directories = <String>[];
    if (root['directories'] != null) {
      if (root['directories'] is! List ||
          (root['directories'] as List).length > 10000) {
        throw const WorkspaceFailure('Invalid backup folder list.');
      }
      final folderNames = <String>{};
      for (final value in root['directories'] as List) {
        if (value is! String) {
          throw const WorkspaceFailure('Invalid backup folder.');
        }
        validateNotesPath(value);
        final lower = value.toLowerCase();
        if (!folderNames.add(lower) ||
            names.any((file) => file == lower || lower.startsWith('$file/'))) {
          throw const WorkspaceFailure('Backup folder paths collide.');
        }
        directories.add(value);
      }
    }
    if (manifestBytes == null) {
      throw const WorkspaceFailure('Missing workspace manifest.');
    }
    final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map;
    if (manifest['format'] != 'orbit-note-workspace' ||
        manifest['version'] != 1 ||
        manifest['id'] != root['workspaceId'] ||
        manifest['id'] is! String) {
      throw const WorkspaceFailure(
        'Backup workspace identity/version is invalid.',
      );
    }
    final warnings = <String>[];
    final ids = <String>{};
    for (final entry in files.entries) {
      final markdown =
          entry.key.startsWith('Notes/') && entry.key.endsWith('.md');
      final structured =
          (entry.key.startsWith('Objects/') ||
              entry.key.startsWith('Boards/') ||
              entry.key.startsWith('Drawings/')) &&
          entry.key.endsWith('.json');
      if (!markdown && !structured) continue;
      try {
        final object = ObjectCodec().decode(
          utf8.decode(entry.value),
          manifest['id'] as String,
          markdown: markdown,
        );
        if (!ids.add(object.id)) {
          warnings.add(
            '${entry.key}: duplicate identity retained; opening may be read-only.',
          );
        }
        final ref = object.properties['contentRef'];
        if (ref is String && !files.containsKey(ref)) {
          warnings.add(
            '${entry.key}: attachment reference is missing its original bytes.',
          );
        }
      } catch (e) {
        warnings.add(
          '${entry.key}: preserved original bytes; not adopted as an editable object. $e',
        );
      }
    }
    return BackupBundle._(
      Map.unmodifiable(files),
      manifest['name'] as String? ?? 'Imported workspace',
      total,
      List.unmodifiable(warnings),
      List.unmodifiable(directories),
    );
  }
}
