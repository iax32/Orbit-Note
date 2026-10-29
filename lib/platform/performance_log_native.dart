import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'performance_log_types.dart';

Future<PerformanceLogStore?> createPerformanceLogStore() async {
  final root = await getApplicationSupportDirectory();
  final store = NativePerformanceLogStore(
    Directory(p.join(root.path, 'Performance')),
    defaultEnabled: Platform.isWindows,
  );
  await store.initialize();
  return store;
}

/// Small, local, rotating diagnostic files, independent of Vault data/sync.
class NativePerformanceLogStore implements PerformanceLogStore {
  NativePerformanceLogStore(
    this.directory, {
    this.defaultEnabled = false,
    this.maxBytes = 512 * 1024,
  });
  final Directory directory;
  final bool defaultEnabled;
  final int maxBytes;
  bool _enabled = false;
  @override
  bool get enabled => _enabled;
  File get _current => File(p.join(directory.path, 'canvas-performance.jsonl'));
  File get _previous =>
      File(p.join(directory.path, 'canvas-performance.previous.jsonl'));
  File get _settings =>
      File(p.join(directory.path, 'performance-settings.json'));
  @override
  String get path => _current.path;
  Future<void> initialize() async {
    _enabled = defaultEnabled;
    if (await _settings.exists()) {
      if (await _settings.length() > 4096) {
        _enabled = false;
        return;
      }
      final value = jsonDecode(await _settings.readAsString());
      _enabled =
          value is Map && value['version'] == 1 && value['enabled'] == true;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    await directory.create(recursive: true);
    await _settings.writeAsString(
      jsonEncode({'version': 1, 'enabled': enabled}),
      flush: true,
    );
    _enabled = enabled;
  }

  @override
  Future<void> append(String lines) async {
    if (!_enabled || lines.isEmpty) return;
    final bytes = utf8.encode(lines);
    if (bytes.length > maxBytes) {
      throw const FormatException('Diagnostic batch exceeds limit');
    }
    await directory.create(recursive: true);
    if (await _current.exists() &&
        await _current.length() + bytes.length > maxBytes) {
      if (await _previous.exists()) await _previous.delete();
      await _current.rename(_previous.path);
    }
    await _current.writeAsBytes(bytes, mode: FileMode.append);
  }

  @override
  Future<String> read() async {
    final parts = <String>[];
    for (final file in [_previous, _current]) {
      if (await file.exists() && await file.length() <= maxBytes) {
        parts.add(await file.readAsString());
      }
    }
    return parts.join();
  }
}
