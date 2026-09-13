import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';

Future<bool> exportFile(
  String name,
  String content, {
  String mimeType = 'application/json',
}) async {
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return false;
  await XFile.fromData(
    utf8.encode(content),
    name: name,
    mimeType: mimeType,
  ).saveTo(location.path);
  return true;
}

Future<bool> exportBinaryFile(
  String name,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) async {
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return false;
  await XFile.fromData(
    bytes,
    name: name,
    mimeType: mimeType,
  ).saveTo(location.path);
  return true;
}
