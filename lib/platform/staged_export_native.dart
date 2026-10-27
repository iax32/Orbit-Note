import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Stages complete bytes beside a user-selected destination. Existing exports
/// are not opened/truncated; cancellation or a changed destination keeps them.
Future<bool> writeStagedExport(
  String destination,
  Uint8List bytes, {
  bool Function()? isCancelled,
  void Function(int completed, int total)? onProgress,
}) async {
  if (isCancelled?.call() == true) return false;
  final target = File(destination).absolute;
  final type = await FileSystemEntity.type(target.path, followLinks: false);
  if (type != FileSystemEntityType.notFound &&
      type != FileSystemEntityType.file) {
    throw const FileSystemException(
      'Choose an ordinary file as the export destination.',
    );
  }
  Future<String?> fingerprint() async => await target.exists()
      ? (await sha256.bind(target.openRead()).first).toString()
      : null;
  final before = await fingerprint();
  final stage = File('${target.path}.orbit-export-${const Uuid().v4()}.tmp');
  RandomAccessFile? handle;
  try {
    await stage.create(exclusive: true);
    handle = await stage.open(mode: FileMode.writeOnly);
    const chunk = 256 * 1024;
    for (var offset = 0; offset < bytes.length; offset += chunk) {
      if (isCancelled?.call() == true) return false;
      final end = (offset + chunk).clamp(0, bytes.length);
      await handle.writeFrom(bytes, offset, end);
      onProgress?.call(end, bytes.length);
    }
    await handle.flush();
    await handle.close();
    handle = null;
    if (isCancelled?.call() == true) return false;
    if (await fingerprint() != before) {
      throw const FileSystemException(
        'The destination changed while exporting. Choose another name; the existing file was retained.',
      );
    }
    await stage.rename(target.path);
    return true;
  } finally {
    await handle?.close();
    if (await stage.exists()) await stage.delete();
  }
}
