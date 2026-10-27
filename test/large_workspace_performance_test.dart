import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/infrastructure/storage/native_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/object_codec.dart';
import 'package:orbit_note/infrastructure/storage/object_index.dart';

UniversalObject _note(int n, String workspace) => UniversalObject(
  id: 'fixture-$n',
  workspaceId: workspace,
  typeId: 'orbit.note',
  title: 'Course $n',
  body: List.filled(16, 'Exact source $n: café 😀 needle-$n\r\n').join(),
  properties: {
    'future-field': {'number': n},
  },
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _CountingIndex extends MemoryObjectIndex {
  int replacements = 0, updates = 0;
  @override
  Future<void> replaceAll(List<UniversalObject> objects) {
    replacements++;
    return super.replaceAll(objects);
  }

  @override
  Future<void> upsert(UniversalObject object) {
    updates++;
    return super.upsert(object);
  }
}

void main() {
  test(
    'index rebuild failure preserves old results, queued updates survive yielding',
    () async {
      for (final native in [false, true]) {
        final root = await Directory.systemTemp.createTemp(
          'orbit-index-atomic-',
        );
        final ObjectIndex index = native
            ? DriftObjectIndex()
            : MemoryObjectIndex();
        try {
          await index.initialize(root.path);
          await index.upsert(_note(9999, 'workspace'));
          final invalid = _note(
            9000,
            'workspace',
          ).copyWith(properties: {'invalid': double.nan});
          await expectLater(
            index.replaceAll([
              ...List.generate(130, (i) => _note(i, 'workspace')),
              invalid,
            ]),
            throwsA(anything),
          );
          expect((await index.search('needle-9999')).single, 'fixture-9999');
          expect(await index.search('needle-0'), isEmpty);
          final rebuilding = index.replaceAll(
            List.generate(1000, (i) => _note(i, 'workspace')),
          );
          final updating = index.upsert(_note(9998, 'workspace'));
          await rebuilding;
          await updating;
          expect((await index.search('needle-9998')).single, 'fixture-9998');
          expect((await index.search('Exact source')).length, 1001);
          final submitted = [_note(7000, 'workspace')];
          final replacing = index.replaceAll(submitted);
          submitted.clear();
          await replacing;
          expect((await index.search('needle-7000')).single, 'fixture-7000');
        } finally {
          await index.close();
          await root.delete(recursive: true);
        }
      }
    },
  );
  test(
    '3000-object native search rebuild is complete and survives reopening',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-index-load-');
      final index = DriftObjectIndex();
      try {
        await index.initialize(root.path);
        final objects = List.generate(
          3000,
          (i) => _note(i, 'fixture-workspace'),
        );
        final watch = Stopwatch()..start();
        await index.replaceAll(objects);
        final rebuild = watch.elapsedMicroseconds;
        expect((await index.search('needle-2999')).single, 'fixture-2999');
        expect((await index.search('Exact source')).length, 3000);
        await index.close();
        await index.initialize(root.path);
        expect((await index.search('needle-2999')).single, 'fixture-2999');
        debugPrint(
          'Large workspace: 3000-object native index rebuild=$rebuild us',
        );
      } finally {
        await index.close();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    '1000 native notes reopen losslessly and leave original files untouched',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-vault-load-');
      final index = _CountingIndex();
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: index,
      );
      Timer? heartbeat;
      try {
        await repo.initialize(path: root.path);
        final workspace = repo.workspaceId;
        await repo.close();
        await Directory('${root.path}/Notes').create(recursive: true);
        final codec = ObjectCodec();
        final expected = <String, String>{};
        for (var i = 0; i < 1000; i++) {
          final path = '${root.path}/Notes/fixture-$i.md';
          final source = codec.encode(_note(i, workspace));
          await File(path).writeAsString(source);
          expected[path] = source;
        }
        final watch = Stopwatch()..start();
        var last = 0, worst = 0, ticks = 0;
        heartbeat = Timer.periodic(const Duration(milliseconds: 2), (_) {
          final now = watch.elapsedMicroseconds;
          if (now - last > worst) worst = now - last;
          last = now;
          ticks++;
        });
        await repo.initialize(path: root.path);
        heartbeat.cancel();
        heartbeat = null;
        expect(repo.objects.length, 1000);
        expect(ticks, greaterThan(0));
        expect(repo.objects.last.properties['future-field'], isA<Map>());
        final elapsed = watch.elapsedMicroseconds;
        for (final entry in expected.entries) {
          expect(await File(entry.key).readAsString(), entry.value);
        }
        expect(repo.objects.first.body.contains('café 😀'), true);
        debugPrint(
          'Large workspace: 1000 notes reopen=$elapsed us, heartbeat maximum=$worst us, ticks=$ticks',
        );
        final snapshots = {for (final o in repo.objects) o.id: o};
        final rebuilds = index.replacements, updates = index.updates;
        final refresh = Stopwatch()..start();
        await repo.refresh();
        debugPrint(
          'Large workspace: unchanged refresh=${refresh.elapsedMicroseconds} us',
        );
        expect(repo.objects.every((o) => identical(o, snapshots[o.id])), true);
        expect(index.replacements, rebuilds);
        expect(index.updates, updates);
        final changedPath = '${root.path}/Notes/fixture-0.md';
        await File(changedPath).writeAsString(
          expected[changedPath]!.replaceAll('Exact source', 'New evidence'),
        );
        await repo.refresh();
        expect(index.updates, updates + 1);
        expect(index.replacements, rebuilds);
        expect(
          repo.objects
              .where((o) => o.id != 'fixture-0')
              .every((o) => identical(o, snapshots[o.id])),
          true,
        );
        expect((await repo.search('New evidence')).single.id, 'fixture-0');
        await File(changedPath).delete();
        await repo.refresh();
        expect(index.replacements, rebuilds + 1);
        expect(await index.search('New evidence'), isEmpty);
      } finally {
        heartbeat?.cancel();
        await repo.close();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'long mixed Markdown parses exact LF/CRLF source and trailing carriage returns',
    () {
      for (final ending in ['\n', '\r\n']) {
        final lines = <String>[];
        for (var i = 0; i < 3000; i++) {
          lines.addAll([
            'Paragraph $i with **bold** and [reference][course].',
            '',
          ]);
          if (i % 20 == 0) {
            lines.addAll([
              '## Section $i',
              '',
              r'$$',
              r'\int_0^1 x^2 dx',
              r'$$',
              '',
            ]);
          }
        }
        lines.addAll([
          '[course]: <https://example.test/reference> "Title"',
          '',
          'Trailing\r',
        ]);
        final source = lines.join(ending);
        final watch = Stopwatch()..start();
        final doc = MarkdownDocument.parse(source);
        expect(doc.source, source);
        expect(doc.blocks.length, greaterThan(3000));
        debugPrint(
          'Large note: ${jsonEncode(ending)} ${doc.blocks.length} blocks parse=${watch.elapsedMicroseconds} us',
        );
      }
    },
  );
}
