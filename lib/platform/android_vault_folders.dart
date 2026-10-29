import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool get usesAndroidVaultFolders =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// SAF-selected folders are imported through Android streams into a local Vault.
/// The original folder and other apps' private files are never modified.
Future<String?> importAndroidVaultFolder() async {
  const channel = MethodChannel('orbit_note/vault_folders');
  final path = await channel.invokeMethod<String>('importFolder');
  if (path != null && (path.isEmpty || !path.startsWith('/'))) {
    throw const FormatException('Android did not return a local Vault folder.');
  }
  return path;
}
