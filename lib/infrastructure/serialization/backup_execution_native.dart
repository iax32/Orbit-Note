import 'dart:isolate';
import '../../application/backup_bundle.dart';

/// Validation and base64 decoding can touch every byte in a shared Vault.
/// Isolate.run transfers the finished result without copying it back to the UI.
Future<BackupBundle> parseBackupBundle(String source) =>
    Isolate.run(() => BackupBundle.parse(source));
