import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../domain/workspace_failure.dart';
import 'path_safety.dart';
import 'workspace_store.dart';

/// One logical folder command, rolled forward after interruption. All entries
/// are verified before the first write. Unrecognized/changed data stops recovery.
class NativeFolderCommands {
  NativeFolderCommands(this.file, this.write);
  final Future<File> Function(String) file;
  final Future<void> Function(String, Uint8List, String?) write;
  Future<String?> _hash(String path) async {
    final f = await file(path);
    return await f.exists()
        ? (await sha256.bind(f.openRead()).first).toString()
        : null;
  }

  void _owner(String path) {
    validateRelativePath(path);
    if (!((path.startsWith('Notes/') && path.endsWith('.md')) ||
        (path.startsWith('Objects/') && path.endsWith('.object.json')) ||
        (path.startsWith('Boards/') && path.endsWith('.board.json')) ||
        (path.startsWith('Drawings/') && path.endsWith('.drawing.json')))) {
      throw const WorkspaceFailure(
        'Folder command has an unsupported owning file.',
      );
    }
  }

  Future<void> apply(
    List<FolderFileChange> changes,
    String workspaceId,
    List<String> createFolders,
    List<String> removeFolders,
  ) async {
    final targets = <String>{}, sources = <String>{};
    for (final c in changes) {
      _owner(c.source);
      _owner(c.target);
      if (!sources.add(c.source.toLowerCase()) ||
          !targets.add(c.target.toLowerCase())) {
        throw const WorkspaceConflict(
          'Folder command contains colliding objects.',
        );
      }
      if (await _hash(c.source) != c.expectedHash ||
          (c.source != c.target &&
              await FileSystemEntity.type(
                    (await file(c.target)).path,
                    followLinks: false,
                  ) !=
                  FileSystemEntityType.notFound)) {
        throw const WorkspaceConflict(
          'A file changed or its destination already exists.',
        );
      }
    }
    for (final path in [...createFolders, ...removeFolders]) {
      validateNotesPath(path);
      if (path == 'Notes' && removeFolders.contains(path)) {
        throw const WorkspaceFailure('Cannot delete the Notes root.');
      }
      await file(path);
    }
    final id = const Uuid().v4();
    final entries = <Map<String, dynamic>>[];
    for (final c in changes) {
      final stagePath = '.orbit/recovery/$id-${entries.length}.folder-data';
      final stage = await file(stagePath);
      await stage.parent.create(recursive: true);
      await stage.writeAsBytes(c.bytes, flush: true);
      entries.add({
        'source': c.source,
        'target': c.target,
        'beforeHash': c.expectedHash,
        'afterHash': sha256.convert(c.bytes).toString(),
        'stage': stagePath,
      });
    }
    final record = {
      'format': 'orbit-note-folder-command',
      'version': 1,
      'workspaceId': workspaceId,
      'files': entries,
      'createFolders': createFolders,
      'removeFolders': removeFolders,
    };
    final journal = await file('.orbit/recovery/$id.folder.json');
    await journal.parent.create(recursive: true);
    await journal.writeAsString(jsonEncode(record), flush: true);
    await _finish(journal, record);
  }

  Future<void> _finish(File journal, Map record) async {
    if (record['format'] != 'orbit-note-folder-command' ||
        record['version'] != 1) {
      throw const WorkspaceFailure('Unsupported folder command retained.');
    }
    final manifest =
        jsonDecode(await (await file('workspace.json')).readAsString()) as Map;
    if (manifest['version'] != 1 || manifest['id'] != record['workspaceId']) {
      throw const WorkspaceConflict('Folder command belongs to another Vault.');
    }
    final entries = (record['files'] as List).cast<Map>();
    final create = (record['createFolders'] as List).cast<String>();
    final remove = (record['removeFolders'] as List).cast<String>();
    for (final folder in [...create, ...remove]) {
      validateNotesPath(folder);
      if (folder == 'Notes' && remove.contains(folder)) {
        throw const WorkspaceFailure('Cannot remove root.');
      }
    }
    final sources = <String>{}, targets = <String>{};
    for (final e in entries) {
      final source = e['source'] as String, target = e['target'] as String;
      _owner(source);
      _owner(target);
      if (!sources.add(source.toLowerCase()) ||
          !targets.add(target.toLowerCase())) {
        throw const WorkspaceConflict('Duplicate folder command paths.');
      }
      final stage = e['stage'] as String;
      if (!stage.startsWith('.orbit/recovery/') ||
          !stage.endsWith('.folder-data') ||
          await _hash(stage) != e['afterHash']) {
        throw const WorkspaceConflict(
          'Folder recovery payload is missing or changed.',
        );
      }
      final sourceHash = await _hash(source);
      if (source == target) {
        if (sourceHash != e['beforeHash'] && sourceHash != e['afterHash']) {
          throw const WorkspaceConflict(
            'Folder metadata changed outside Orbit.',
          );
        }
      } else {
        final targetHash = await _hash(target);
        if (!((sourceHash == e['beforeHash'] || sourceHash == e['afterHash']) &&
                targetHash == null ||
            sourceHash == null &&
                (targetHash == e['beforeHash'] ||
                    targetHash == e['afterHash']))) {
          throw const WorkspaceConflict(
            'Folder move source/destination needs recovery review.',
          );
        }
      }
    }
    for (final folder in create) {
      await Directory((await file(folder)).path).create(recursive: true);
    }
    for (final e in entries) {
      final source = e['source'] as String, target = e['target'] as String;
      final sourceHash = await _hash(source);
      if (source != target && sourceHash != null) {
        if ((sourceHash != e['beforeHash'] && sourceHash != e['afterHash']) ||
            await FileSystemEntity.type(
                  (await file(target)).path,
                  followLinks: false,
                ) !=
                FileSystemEntityType.notFound) {
          throw const WorkspaceConflict(
            'Folder destination changed during the command.',
          );
        }
        final destination = await file(target);
        await destination.parent.create(recursive: true);
        await (await file(source)).rename(destination.path);
      }
      if (await _hash(target) != e['afterHash']) {
        try {
          await write(
            target,
            await (await file(e['stage'] as String)).readAsBytes(),
            e['beforeHash'] as String,
          );
        } on Object {
          // Physical movement precedes the metadata write. If publication failed
          // with exact old bytes, restore the original location when possible.
          if (source != target &&
              await _hash(target) == e['beforeHash'] &&
              await FileSystemEntity.type(
                    (await file(source)).path,
                    followLinks: false,
                  ) ==
                  FileSystemEntityType.notFound) {
            try {
              await (await file(target)).rename((await file(source)).path);
            } on FileSystemException {
              /* Journal retains both expected locations. */
            }
          }
          rethrow;
        }
      }
    }
    final ordered = [...remove]..sort((a, b) => b.length.compareTo(a.length));
    for (final folder in ordered) {
      final directory = Directory((await file(folder)).path);
      if (await directory.exists()) {
        await directory.delete(); // Empty only; never recursive.
      }
    }
    // The journal is removed only after all data and directory operations finish.
    // Stages may remain as harmless recovery copies after a cleanup interruption.
    await journal.delete();
    for (final e in entries) {
      try {
        await (await file(e['stage'] as String)).delete();
      } on FileSystemException {
        /* Retain recovery copy. */
      }
    }
  }

  Future<void> recover() async {
    final directory = Directory((await file('.orbit/recovery')).path);
    if (!await directory.exists()) return;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File || !entry.path.endsWith('.folder.json')) continue;
      try {
        await _finish(entry, jsonDecode(await entry.readAsString()) as Map);
      } on Object {
        /* Repository exposes unresolved intent read-only. */
      }
    }
  }
}
