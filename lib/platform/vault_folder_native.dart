import 'dart:io';
import 'package:path/path.dart' as p;

Future<String> createVaultFolder(String parent, String name) async {
  final label = name.trim();
  if (label.isEmpty ||
      label == '.' ||
      label == '..' ||
      label.endsWith('.') ||
      RegExp(r'[<>:"/\\|?*\x00-\x1f]').hasMatch(label) ||
      RegExp(
        r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
        caseSensitive: false,
      ).hasMatch(label)) {
    throw const FormatException(
      'Choose a portable folder name without path separators.',
    );
  }
  final root = await Directory(parent).resolveSymbolicLinks();
  final folder = Directory(p.join(root, label));
  if (await FileSystemEntity.type(folder.path, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw const FileSystemException(
      'A folder or file with this name already exists.',
    );
  }
  await folder.create();
  return folder.path;
}
