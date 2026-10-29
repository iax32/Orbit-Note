import '../application/backup_bundle.dart';

Future<String> localBackupImportParent() async => throw UnsupportedError(
  'Local Vault storage is not available in a browser.',
);

Future<String> importBackup(BackupBundle bundle, String parent) async =>
    throw UnsupportedError('Import into a new folder is available on desktop.');
