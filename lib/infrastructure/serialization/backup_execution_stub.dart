import '../../application/backup_bundle.dart';

Future<BackupBundle> parseBackupBundle(String source) async =>
    BackupBundle.parse(source);
