import 'dart:convert';
import 'package:file_selector/file_selector.dart';

Future<bool> exportFile(String name, String content) async {
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return false;
  await XFile.fromData(
    utf8.encode(content),
    name: name,
    mimeType: 'application/json',
  ).saveTo(location.path);
  return true;
}
