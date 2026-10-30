import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../application/backup_bundle.dart';
import 'vault_folder_name.dart';

/// Mobile downloads belong to the app's writable Vault storage. A document-tree
/// picker does not grant dart:io access to an arbitrary Android folder.
Future<String> localBackupImportParent({
  Future<Directory> Function()? documentsDirectory,
}) async => (await Directory(
  p.join(
    (await (documentsDirectory ?? getApplicationDocumentsDirectory)()).path,
    'Vaults',
  ),
).create(recursive: true)).path;

/// Publish a unique new folder only after all bytes have been flushed. Failure
/// leaves an explicitly incomplete staging folder; no existing workspace is touched.
Future<String> importBackup(
  BackupBundle bundle,
  String parent, {
  Future<void> Function(File, Uint8List)? writeFile,
}) async {
  final root = await Directory(parent).resolveSymbolicLinks();
  final token = const Uuid().v4();
  final stage = await Directory(p.join(root, '.orbit-import-$token')).create();
  for (final directory in bundle.directories) {
    await Directory(
      p.joinAll([stage.path, ...directory.split('/')]),
    ).create(recursive: true);
  }
  for (final entry in bundle.files.entries) {
    // Never replay journals supplied by an imported archive automatically.
    final relative = entry.key.startsWith('.orbit/recovery/')
        ? '.orbit/imported-recovery/${entry.key.substring('.orbit/recovery/'.length)}'
        : entry.key;
    final file = File(p.joinAll([stage.path, ...relative.split('/')]));
    if (await file.exists()) {
      throw const FileSystemException('Import file collision');
    }
    await file.parent.create(recursive: true);
    if (writeFile != null) {
      await writeFile(file, entry.value);
    } else {
      await file.writeAsBytes(entry.value, flush: true);
    }
  }
  final name = vaultFolderName(bundle.name);
  var target = p.join(root, name);
  var copy = 2;
  while (await FileSystemEntity.type(target, followLinks: false) !=
      FileSystemEntityType.notFound) {
    target = p.join(root, '$name (${copy++})');
  }
  await stage.rename(target);
  // Reports are supplemental. Failure to write one cannot undo the publication.
  if (bundle.warnings.isNotEmpty) {
    try {
      final report = File(
        p.join(target, '.orbit', 'import-reports', '$token.json'),
      );
      await report.parent.create(recursive: true);
      await report.writeAsString(
        jsonEncode({'version': 1, 'warnings': bundle.warnings}),
        flush: true,
      );
    } on FileSystemException {
      /* Warnings were already shown before import. */
    }
  }
  return target;
}
