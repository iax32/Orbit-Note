import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;
import '../../domain/workspace_failure.dart';
import 'path_safety.dart';
import '../workers/native_task_worker.dart';

typedef _HistoryRequest = ({
  String root,
  String area,
  int entries,
  int bytes,
  Duration age,
});

/// One lazy worker per open store. Every save still enforces retention before
/// completing maintenance; no 60-second delay weakens the disk-space bound.
class NativeHistoryMaintenance {
  final _worker = NativeTaskWorker<_HistoryRequest, bool>(_runMaintenance);
  Future<void> prune({
    required String root,
    required String area,
    required int maxEntries,
    required int maxBytes,
    required Duration maxAge,
  }) async {
    await _worker.run((
      root: root,
      area: area,
      entries: maxEntries,
      bytes: maxBytes,
      age: maxAge,
    ));
  }

  Future<void> close() => _worker.close();
}

bool _runMaintenance(_HistoryRequest request) {
  _prune(
    request.root,
    request.area,
    request.entries,
    request.bytes,
    request.age,
  );
  return true;
}

/// One-shot helper for offline checks. Open stores own NativeHistoryMaintenance
/// instead, so repeated autosaves reuse the same worker.
/// Only small configuration strings cross the isolate boundary. History payloads
/// and metadata stay on the worker; no decoded history graph enters the UI heap.
Future<void> pruneNativeHistory({
  required String root,
  required String area,
  required int maxEntries,
  required int maxBytes,
  required Duration maxAge,
}) => Isolate.run(() => _prune(root, area, maxEntries, maxBytes, maxAge));

void _prune(
  String root,
  String area,
  int maxEntries,
  int maxBytes,
  Duration maxAge,
) {
  if (area != '.orbit' && area != '.orbit/device') {
    throw const WorkspaceFailure('Unsupported history area.');
  }
  File checked(String relative) {
    validateRelativePath(relative);
    var path = root;
    for (final part in relative.split('/')) {
      path = p.join(path, part);
      if (FileSystemEntity.typeSync(path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const WorkspaceFailure('History cannot traverse symbolic links.');
      }
    }
    return File(path);
  }

  final folder = Directory(checked('$area/history').path);
  if (!folder.existsSync()) return;
  final entries =
      <
        ({File metadata, File before, String target, DateTime time, int size})
      >[];
  for (final entity in folder.listSync(followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    try {
      final metadata = checked('$area/history/${p.basename(entity.path)}');
      // Generated save records are small. Unknown/oversized records stay intact.
      if (metadata.lengthSync() > 1024 * 1024) continue;
      final record = jsonDecode(metadata.readAsStringSync());
      if (record is! Map ||
          record['format'] != 'orbit-note-file-save' ||
          record['version'] != 1 ||
          record['completedAt'] is! String ||
          record['beforePath'] is! String ||
          record['target'] is! String) {
        continue;
      }
      final before = checked(record['beforePath'] as String);
      // A malformed record must never remove another record's before-image.
      final ownBefore =
          '${metadata.path.substring(0, metadata.path.length - 5)}.before';
      if (!p.isWithin(folder.path, before.path) ||
          !p.equals(ownBefore, before.path) ||
          !before.existsSync()) {
        continue;
      }
      entries.add((
        metadata: metadata,
        before: before,
        target: record['target'] as String,
        time: DateTime.parse(record['completedAt'] as String),
        size: before.lengthSync(),
      ));
    } on Object {
      // Unsupported, malformed or inaccessible recovery/history is preserved.
    }
  }
  entries.sort((a, b) => b.time.compareTo(a.time));
  final keptTargets = <String>{};
  var count = 0, bytes = 0;
  final cutoff = DateTime.now().toUtc().subtract(maxAge);
  for (final entry in entries) {
    final preserveLast = keptTargets.add(entry.target);
    if (!preserveLast &&
        (count >= maxEntries ||
            bytes + entry.size > maxBytes ||
            entry.time.isBefore(cutoff))) {
      final journal = checked(
        '$area/recovery/${p.basename(entry.metadata.path)}',
      );
      if (journal.existsSync()) continue;
      // Recheck path components before each removal, including provider changes.
      checked('$area/history/${p.basename(entry.before.path)}').deleteSync();
      checked('$area/history/${p.basename(entry.metadata.path)}').deleteSync();
    } else {
      count++;
      bytes += entry.size;
    }
  }
}
