import 'dart:io';
import 'package:orbit_note/infrastructure/storage/native_vault_lock.dart';

/// Diagnostic/conformance helper: 0 = acquired, 2 = unavailable. No Vault writes.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    exitCode = 64;
    return;
  }
  NativeVaultLock? lock;
  try {
    lock = await NativeVaultLock.acquire(File(args.single));
  } on Object {
    exitCode = 2;
  } finally {
    await lock?.close();
  }
}
