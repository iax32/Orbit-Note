import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/infrastructure/storage/native_history_retention.dart';

void main() {
  late Directory root;
  setUp(
    () async =>
        root = await Directory.systemTemp.createTemp('orbit-history-worker-'),
  );
  tearDown(() async => root.delete(recursive: true));

  Future<void> revision(
    String id,
    String target,
    int age, {
    String area = '.orbit',
  }) async {
    final before = File('${root.path}/$area/history/$id.before');
    await before.parent.create(recursive: true);
    await before.writeAsString('original revision $id');
    await File('${root.path}/$area/history/$id.json').writeAsString(
      jsonEncode({
        'format': 'orbit-note-file-save',
        'version': 1,
        'target': target,
        'beforePath': '$area/history/$id.before',
        'completedAt': DateTime.now()
            .toUtc()
            .subtract(Duration(days: age))
            .toIso8601String(),
      }),
    );
  }

  Future<void> prune({
    String area = '.orbit',
    int count = 1,
    int bytes = 1,
    Duration age = const Duration(days: 1),
  }) => pruneNativeHistory(
    root: root.path,
    area: area,
    maxEntries: count,
    maxBytes: bytes,
    maxAge: age,
  );
  Future<bool> exists(String path) => File('${root.path}/$path').exists();

  test(
    'retains last recovery version for every target despite byte, count and age limits',
    () async {
      await revision('a-old', 'Notes/a.md', 40);
      await revision('a-last', 'Notes/a.md', 30);
      await revision('b-old', 'Boards/b.board.json', 40);
      await revision('b-last', 'Boards/b.board.json', 30);
      await prune();
      expect(await exists('.orbit/history/a-last.before'), isTrue);
      expect(await exists('.orbit/history/b-last.before'), isTrue);
      expect(await exists('.orbit/history/a-old.before'), isFalse);
      expect(await exists('.orbit/history/b-old.before'), isFalse);
    },
  );

  test(
    'pending save journals retain their before images and unknown records stay untouched',
    () async {
      await revision('old', 'Notes/a.md', 10);
      await revision('latest', 'Notes/a.md', 0);
      final journal = File('${root.path}/.orbit/recovery/old.json');
      await journal.parent.create(recursive: true);
      await journal.writeAsString('{pending');
      final unknown = File('${root.path}/.orbit/history/future.json');
      await unknown.writeAsString('{"format":"future","version":200}');
      final malformed = File('${root.path}/.orbit/history/broken.json');
      await malformed.writeAsString('{unknown');
      await prune();
      expect(await exists('.orbit/history/old.before'), isTrue);
      expect(await journal.readAsString(), '{pending');
      expect(await unknown.readAsString(), '{"format":"future","version":200}');
      expect(await malformed.readAsString(), '{unknown');
    },
  );

  test(
    'malformed records cannot prune another entry or escape the Vault',
    () async {
      await revision('own', 'Notes/a.md', 1);
      await revision('another', 'Notes/a.md', 2);
      final metadata = File('${root.path}/.orbit/history/own.json');
      final record = jsonDecode(await metadata.readAsString()) as Map;
      await metadata.writeAsString(
        jsonEncode({...record, 'beforePath': '.orbit/history/another.before'}),
      );
      final external = File('${root.path}/outside.before');
      await external.writeAsString('preserve');
      final escape = File('${root.path}/.orbit/history/escape.json');
      await escape.writeAsString(
        jsonEncode({...record, 'beforePath': '../outside.before'}),
      );
      await prune();
      expect(await exists('.orbit/history/own.before'), isTrue);
      expect(await exists('.orbit/history/another.before'), isTrue);
      expect(await external.readAsString(), 'preserve');
      expect(await escape.exists(), isTrue);
    },
  );

  test(
    'device history and authored history have independent retention',
    () async {
      await revision('authored', 'Notes/a.md', 5);
      await revision(
        'device-old',
        '.orbit/device/settings.json',
        5,
        area: '.orbit/device',
      );
      await revision(
        'device-new',
        '.orbit/device/settings.json',
        0,
        area: '.orbit/device',
      );
      await prune(area: '.orbit/device');
      expect(await exists('.orbit/history/authored.before'), isTrue);
      expect(await exists('.orbit/device/history/device-old.before'), isFalse);
      expect(await exists('.orbit/device/history/device-new.before'), isTrue);
    },
  );

  test(
    'large history maintenance yields to input while preserving its count boundary',
    () async {
      for (var i = 0; i < 240; i++) {
        await revision('entry-$i', 'Notes/a.md', i);
      }
      var ticks = 0;
      var finished = false;
      Future<void> input() async {
        while (!finished) {
          await Future<void>.delayed(Duration.zero);
          ticks++;
        }
      }

      final inputWork = input();
      try {
        await prune(
          count: 20,
          bytes: 1024 * 1024,
          age: const Duration(days: 1000),
        );
      } finally {
        finished = true;
        await inputWork;
      }
      final retained = await Directory(
        '${root.path}/.orbit/history',
      ).list().where((file) => file.path.endsWith('.before')).length;
      expect(retained, 20);
      expect(ticks, greaterThan(0));
    },
  );
}
