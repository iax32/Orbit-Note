import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../domain/source_browser.dart';

/// Read-only and explicitly scoped to a folder selected by the user.
class SourceFolder {
  SourceFolder(this.root);
  final String root;
  static const supported = true;
  static const ignored = {
    '.git',
    '.orbit-ide',
    '.dart_tool',
    'node_modules',
    'build',
    'dist',
    '.local',
    '.pub-cache',
    'library',
    'temp',
    'obj',
    'bin',
    '.idea',
    '.vs',
  };
  Future<SourceFileListing> list() async {
    final resolved = await Directory(root).resolveSymbolicLinks();
    final queue = <(String, int)>[(resolved, 0)];
    final files = <SourceFileEntry>[];
    var inspected = 0;
    var incomplete = false;
    while (queue.isNotEmpty && files.length < 5000 && inspected < 50000) {
      final (directory, depth) = queue.removeLast();
      try {
        await for (final entry in Directory(
          directory,
        ).list(followLinks: false)) {
          if (++inspected > 50000 || files.length >= 5000) {
            incomplete = true;
            break;
          }
          if (entry is Link) continue;
          final actual = await entry.resolveSymbolicLinks();
          if (!p.isWithin(resolved, actual)) continue;
          if (entry is Directory) {
            if (!ignored.contains(p.basename(entry.path).toLowerCase())) {
              if (depth >= 15) {
                incomplete = true;
              } else {
                queue.add((actual, depth + 1));
              }
            }
          } else if (entry is File) {
            final language = sourceLanguage(entry.path);
            if (language != null) {
              files.add(
                SourceFileEntry(
                  p.relative(actual, from: resolved).replaceAll('\\', '/'),
                  language,
                ),
              );
            }
          }
        }
      } on FileSystemException {
        incomplete = true;
      }
    }
    if (queue.isNotEmpty) incomplete = true;
    files.sort((a, b) => a.path.compareTo(b.path));
    return SourceFileListing(files, incomplete: incomplete);
  }

  Future<String> read(String relativePath) async {
    if (p.isAbsolute(relativePath) ||
        relativePath.contains('\\') ||
        relativePath
            .split('/')
            .any((s) => s.isEmpty || s == '..' || s == '.')) {
      throw const FormatException(
        'Choose a relative source file from this folder.',
      );
    }
    final resolved = await Directory(root).resolveSymbolicLinks();
    final file = File(p.join(resolved, relativePath));
    final actual = await file.resolveSymbolicLinks();
    if (!p.isWithin(resolved, actual)) {
      throw const FormatException('This file is outside the selected folder.');
    }
    final input = await File(actual).open();
    try {
      final bytes = await input.read(1024 * 1024 + 1);
      if (bytes.length > 1024 * 1024) {
        throw const FormatException(
          'This file exceeds the 1 MiB preview limit.',
        );
      }
      final text = utf8.decode(bytes);
      if (text.contains('\x00')) {
        throw const FormatException('This file contains binary data.');
      }
      return text;
    } finally {
      await input.close();
    }
  }
}
