import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'staged_export_native.dart';

Future<bool> exportFile(
  String name,
  String content, {
  String mimeType = 'application/json',
  bool Function()? isCancelled,
  void Function(int completed, int total)? onProgress,
}) async {
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return false;
  return writeStagedExport(
    location.path,
    utf8.encode(content),
    isCancelled: isCancelled,
    onProgress: onProgress,
  );
}

Future<bool> exportBinaryFile(
  String name,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
  bool Function()? isCancelled,
  void Function(int completed, int total)? onProgress,
}) async {
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return false;
  return writeStagedExport(
    location.path,
    bytes,
    isCancelled: isCancelled,
    onProgress: onProgress,
  );
}
