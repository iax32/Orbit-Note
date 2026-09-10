import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../domain/workspace_failure.dart';
import 'path_safety.dart';
import 'workspace_store.dart';

/// Durable roll-forward record for a same-Vault file/folder move. Recovery never
/// overwrites a source which differs from both recorded pre- and post-images.
class NativePathMoves {
  NativePathMoves(this.root, this.write);
  final String root;
  final Future<void> Function(String, Uint8List, String?) write;
  Future<String> _path(String relative) async {
    validateRelativePath(relative);
    var result = root;
    for (final part in relative.split('/')) {
      result = p.join(result, part);
      if (await FileSystemEntity.type(result, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const WorkspaceFailure('Moves cannot traverse symbolic links.');
      }
    }
    if (!p.isWithin(root, result)) {
      throw const WorkspaceFailure('Move path escapes the Vault.');
    }
    return result;
  }

  Future<void> move(
    String source,
    String target,
    Map<String, FileReplacement> replacements,
  ) async {
    validateNotesPath(source);
    validateNotesPath(target);
    if (!source.startsWith('Notes/') || !target.startsWith('Notes/')) {
      throw const WorkspaceFailure('Only Notes paths can be moved.');
    }
    final from = await _path(source), to = await _path(target);
    if (p.equals(from, to) || p.isWithin(from, to)) {
      throw const WorkspaceFailure(
        'Choose a different destination outside this folder.',
      );
    }
    if (await FileSystemEntity.type(to, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const WorkspaceFailure('The destination already exists.');
    }
    final type = await FileSystemEntity.type(from, followLinks: false);
    if (type != FileSystemEntityType.directory &&
        type != FileSystemEntityType.file) {
      throw const WorkspaceFailure('Move source is unavailable.');
    }
    final entities = type == FileSystemEntityType.file
        ? <FileSystemEntity>[File(from)]
        : await Directory(
            from,
          ).list(recursive: true, followLinks: false).toList();
    if (entities.any((e) => e is Link)) {
      throw const WorkspaceFailure(
        'Folders containing symbolic links cannot be moved.',
      );
    }
    final files = entities.whereType<File>().toList();
    final paths = files
        .map((f) => p.relative(f.path, from: root).replaceAll('\\', '/'))
        .toSet();
    if (replacements.keys.any((key) => !paths.contains(key))) {
      throw const WorkspaceConflict('A note disappeared before the move.');
    }
    final id = const Uuid().v4();
    final snapshots = <Map<String, dynamic>>[];
    for (final file in files) {
      final relative = p.relative(file.path, from: root).replaceAll('\\', '/');
      await _path(relative);
      final bytes = await file.readAsBytes();
      final before = sha256.convert(bytes).toString();
      final replacement = replacements[relative];
      if (replacement != null && before != replacement.expectedHash) {
        throw const WorkspaceConflict(
          'A note changed before the move. Reload and retry.',
        );
      }
      String? staged;
      if (replacement != null) {
        staged = '.orbit/recovery/$id-${snapshots.length}.move-data';
        final stage = File(await _path(staged));
        await stage.parent.create(recursive: true);
        await stage.writeAsBytes(replacement.bytes, flush: true);
      }
      snapshots.add({
        'path': relative,
        'beforeHash': before,
        'afterHash': replacement == null
            ? before
            : sha256.convert(replacement.bytes).toString(),
        'staged': staged,
      });
    }
    final record = {
      'format': 'orbit-note-path-move',
      'version': 1,
      'source': source,
      'target': target,
      'directory': type == FileSystemEntityType.directory,
      'files': snapshots,
    };
    final journal = File(await _path('.orbit/recovery/$id.move.json'));
    await journal.parent.create(recursive: true);
    await journal.writeAsString(jsonEncode(record), flush: true);
    await _finish(journal, record);
  }

  Future<void> _finish(File journal, Map record) async {
    final source = record['source'] as String,
        target = record['target'] as String;
    validateNotesPath(source);
    validateNotesPath(target);
    final from = await _path(source), to = await _path(target);
    if (!source.startsWith('Notes/') ||
        !target.startsWith('Notes/') ||
        p.equals(from, to) ||
        p.isWithin(from, to)) {
      throw const WorkspaceFailure('Invalid move record paths.');
    }
    final sourceExists =
        await FileSystemEntity.type(from, followLinks: false) !=
        FileSystemEntityType.notFound;
    final targetExists =
        await FileSystemEntity.type(to, followLinks: false) !=
        FileSystemEntityType.notFound;
    if (sourceExists == targetExists) {
      throw const WorkspaceConflict(
        'Move needs review: both source/destination exist or both are missing.',
      );
    }
    final files = (record['files'] as List).cast<Map>();
    Future<void> verifyTree() async {
      if (record['directory'] != true) return;
      final base = sourceExists ? from : to;
      final entries = await Directory(
        base,
      ).list(recursive: true, followLinks: false).toList();
      final expected = files
          .map((e) => (e['path'] as String).substring(source.length + 1))
          .toSet();
      final actual = entries
          .whereType<File>()
          .map((e) => p.relative(e.path, from: base).replaceAll('\\', '/'))
          .toSet();
      if (entries.any((e) => e is Link) ||
          actual.length != expected.length ||
          !actual.containsAll(expected)) {
        throw const WorkspaceConflict(
          'Folder contents changed during the move; recovery is retained.',
        );
      }
    }

    await verifyTree();
    for (final entry in files) {
      final original = entry['path'] as String;
      if (!(original == source || original.startsWith('$source/'))) {
        throw const WorkspaceFailure('Move record contains an unrelated file.');
      }
      final current = sourceExists
          ? original
          : '$target${original.substring(source.length)}';
      final bytes = await File(await _path(current)).readAsBytes();
      final hash = sha256.convert(bytes).toString();
      if (hash != entry['afterHash'] &&
          (!sourceExists || hash != entry['beforeHash'])) {
        throw const WorkspaceConflict(
          'External edits prevent automatic move recovery. Both the draft and original are retained.',
        );
      }
      final staged = entry['staged'];
      if (sourceExists && staged is String) {
        if (!staged.startsWith('.orbit/recovery/') ||
            !staged.endsWith('.move-data')) {
          throw const WorkspaceFailure('Unsupported staged move data.');
        }
        final after = await File(await _path(staged)).readAsBytes();
        if (sha256.convert(after).toString() != entry['afterHash']) {
          throw const WorkspaceFailure('Staged move bytes are corrupt.');
        }
      }
    }
    if (sourceExists) {
      for (final entry in files) {
        if (entry['staged'] is! String) continue;
        final original = entry['path'] as String;
        final current = await File(await _path(original)).readAsBytes();
        if (sha256.convert(current).toString() == entry['afterHash']) continue;
        await write(
          original,
          await File(await _path(entry['staged'] as String)).readAsBytes(),
          entry['beforeHash'] as String,
        );
      }
      await Directory(p.dirname(to)).create(recursive: true);
      await verifyTree();
      for (final entry in files) {
        if (sha256
                .convert(
                  await File(
                    await _path(entry['path'] as String),
                  ).readAsBytes(),
                )
                .toString() !=
            entry['afterHash']) {
          throw const WorkspaceConflict(
            'A file changed while the move was being prepared.',
          );
        }
      }
      if (await FileSystemEntity.type(to, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const WorkspaceConflict(
          'The move destination appeared during the operation.',
        );
      }
      if (record['directory'] == true) {
        await Directory(from).rename(to);
      } else {
        await File(from).rename(to);
      }
    }
    // Published move is now authoritative; leftover staging can be cleaned later.
    try {
      for (final entry in files) {
        if (entry['staged'] is String) {
          final file = File(await _path(entry['staged'] as String));
          if (await file.exists()) await file.delete();
        }
      }
      await journal.delete();
    } on FileSystemException {
      /* Published content is authoritative; retry cleanup at startup. */
    }
  }

  Future<void> recover() async {
    final directory = Directory(await _path('.orbit/recovery'));
    if (!await directory.exists()) return;
    await for (final file in directory.list(followLinks: false)) {
      if (file is! File || !file.path.endsWith('.move.json')) continue;
      try {
        final record = jsonDecode(await file.readAsString()) as Map;
        if (record['format'] == 'orbit-note-path-move' &&
            record['version'] == 1) {
          await _finish(file, record);
        }
      } on Object {
        /* Keep unresolved moves and staged bytes for explicit recovery. */
      }
    }
  }
}
