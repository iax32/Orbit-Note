// Synthetic metadata only. Does not open or inspect any user Vault.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:orbit_note/infrastructure/storage/native_history_retention.dart';

Future<void> main() async {
  final root = await Directory.systemTemp.createTemp('orbit-history-profile-');
  final folder = await Directory(
    p.join(root.path, '.orbit', 'history'),
  ).create(recursive: true);
  try {
    for (var i = 0; i < 200; i++) {
      await File(
        p.join(folder.path, '$i.before'),
      ).writeAsString('Synthetic revision $i');
      await File(p.join(folder.path, '$i.json')).writeAsString(
        jsonEncode({
          'format': 'orbit-note-file-save',
          'version': 1,
          'beforePath': '.orbit/history/$i.before',
          'target': 'Notes/fixture-${i % 20}.md',
          'completedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    }
    // Previous foreground scan, read-only: same metadata decoding and component
    // safety checks, without deleting any fixture data during the comparison.
    Future<void> foreground() async {
      final entries = <Map<String, Object>>[];
      await for (final entity in folder.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final record = jsonDecode(await entity.readAsString()) as Map;
        var path = root.path;
        for (final part in (record['beforePath'] as String).split('/')) {
          path = p.join(path, part);
          if (await FileSystemEntity.type(path, followLinks: false) ==
              FileSystemEntityType.link) {
            throw StateError('Unexpected fixture link');
          }
        }
        final file = File(path);
        if (await file.exists()) {
          entries.add({
            'target': record['target'] as String,
            'time': DateTime.parse(record['completedAt'] as String),
            'size': await file.length(),
          });
        }
      }
      entries.sort(
        (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
      );
    }

    final maintenance = NativeHistoryMaintenance();
    Future<void> background() => maintenance.prune(
      root: root.path,
      area: '.orbit',
      maxEntries: 1000,
      maxBytes: 1024 * 1024,
      maxAge: const Duration(days: 365),
    );
    Future<Map<String, int>> measure(Future<void> Function() work) async {
      final watch = Stopwatch()..start();
      var last = 0, maxGap = 0, ticks = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
        final now = watch.elapsedMicroseconds;
        final gap = now - last;
        if (gap > maxGap) maxGap = gap;
        last = now;
        ticks++;
      });
      try {
        await work();
        final tail = watch.elapsedMicroseconds - last;
        if (tail > maxGap) maxGap = tail;
        return {
          'wallUs': watch.elapsedMicroseconds,
          'maxLoopGapUs': maxGap,
          'ticks': ticks,
        };
      } finally {
        timer.cancel();
      }
    }

    final result = {
      'revisions': 200,
      'idle': await measure(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      ),
      'foreground': await measure(foreground),
      'workerCold': await measure(background),
      'workerRepeat': await measure(background),
    };
    await maintenance.close();
    stdout.writeln(jsonEncode(result));
  } finally {
    await root.delete(recursive: true);
  }
}
