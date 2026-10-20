import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/source_search.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/domain/research_comparison.dart';
import 'package:orbit_note/domain/reverse_engineering.dart';
import 'package:orbit_note/domain/source_browser.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/source_browser_dialog.dart';
import 'package:orbit_note/features/workspace/source_search_dialog.dart';
import 'package:orbit_note/features/workspace/research_comparison_dialog.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/platform/source_folder.dart';
import 'support/memory_store.dart';

class InvestigationFolder extends SourceFolder {
  InvestigationFolder() : super('Selected project');
  bool changed = false;
  @override
  Future<SourceFileListing> list() async => const SourceFileListing([
    SourceFileEntry('src/player.cpp', 'cpp'),
    SourceFileEntry('scripts/main.lua', 'lua'),
  ]);
  @override
  Future<String> read(String path) async => changed
      ? 'changed source\n'
      : path.endsWith('.cpp')
      ? 'void jump() {\r\n  return;\r\n}\r\n'
      : 'return player\n';
}

class InvestigationNativeStore extends NativeWorkspaceStore {
  InvestigationNativeStore(this.root);
  final String root;
  @override
  Future<void> initialize({String? path}) =>
      super.initialize(path: path ?? root);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 13);
  UniversalObject function(
    String id,
    String build, {
    String title = 'Jump',
    String binary = 'game',
    String? module = 'player',
    String address = '0x1010',
    String base = '0x1000',
    String purpose = 'Movement',
    String? rva,
  }) => UniversalObject(
    id: id,
    workspaceId: 'vault',
    typeId: 'orbit.note',
    title: title,
    createdAt: now,
    updatedAt: now,
    properties: {
      'category': 'Function',
      'binaryId': binary,
      'binaryVersion': build,
      'moduleId': ?module,
      'addressSpace': 'virtual',
      'address': address,
      'moduleBase': base,
      'purpose': purpose,
      'rva': ?rva,
    },
  );
  ResearchBuildComparison compare(List<UniversalObject> records) =>
      ResearchBuildComparison(
        records,
        const ResearchBuild('game', '1'),
        const ResearchBuild('game', '2'),
      );
  Future<(ProviderContainer, WorkspaceController)> open(
    WorkspaceRepository repository,
  ) async {
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repository)],
    );
    final c = container.read(workspaceProvider.notifier);
    while (c.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    return (container, c);
  }

  Future<UniversalObject> create(WorkspaceController c, String build) async =>
      (await c.createFunctionDoc(
        folder: 'Notes',
        name: 'Jump',
        purpose: 'Movement',
        location: ResearchAddress(
          binaryId: 'game',
          binaryVersion: build,
          moduleId: 'player',
          address: build == '1' ? '0x1010' : '0x9010',
          moduleBase: build == '1' ? '0x1000' : '0x9000',
        ),
      ))!;

  test(
    'rebasing is distinct from changed recorded relative offsets and metadata',
    () {
      final a = function('a', '1');
      final b = function('b', '2', address: '0x9010', base: '0x9000');
      expect(compare([a, b]).rows.single.state, 'Rebased');
      expect(
        compare([a, function('b', '2', address: '0x1020')]).rows.single.fields,
        contains('relative location'),
      );
      expect(
        compare([
          a,
          function('b', '2', purpose: 'New observation'),
        ]).rows.single.state,
        'Changed',
      );
      expect(compare([a, function('b', '2')]).rows.single.state, 'Unchanged');
    },
  );
  test('build and module identities prevent numerical address conflation', () {
    final result = compare([
      function('a', '1'),
      function('b', '2', module: 'audio'),
      function('other', '2', binary: 'unrelated'),
    ]);
    expect(result.sources.length, 2);
    expect(
      result.rows.map((r) => r.state),
      unorderedEquals(['Added', 'Removed']),
    );
    expect(
      () => ResearchBuildComparison(
        [],
        const ResearchBuild('game', '1'),
        const ResearchBuild('different', '2'),
      ),
      throwsFormatException,
    );
    expect(
      () => ResearchBuildComparison(
        [],
        const ResearchBuild('game', '1'),
        const ResearchBuild('game', '1'),
      ),
      throwsFormatException,
    );
  });
  test(
    'duplicates and unnamed/incomplete/contradictory locations remain uncertain',
    () {
      final a = function('a', '1'), b = function('b', '2');
      final duplicate = compare([a, b, function('c', '2')]).rows.single;
      expect(duplicate.state, 'Ambiguous');
      expect(duplicate.after.length, 2);
      expect(() => duplicate.after.clear(), throwsUnsupportedError);
      expect(
        compare([a, function('b', '2', rva: '0x20')]).rows.single.state,
        'Unmatched',
      );
      expect(
        compare([function('a', '1', module: null), b]).rows.map((r) => r.state),
        contains('Unmatched'),
      );
      expect(
        compare([
          function('a', '1', title: 'sub_1010'),
          function('b', '2', title: 'sub_1010'),
        ]).rows.every((r) => r.state == 'Unmatched'),
        isTrue,
      );
    },
  );
  test('reports preserve UUID/revision links and bound oversized imports', () {
    final result = compare([
      function('a', '1', title: 'Jump [extra]\n# injected'),
      function('b', '2', title: 'Jump [extra]\n# injected'),
    ]);
    expect(result.markdown, contains('[[a]] · revision 1'));
    expect(result.markdown, isNot(contains('\n# injected')));
    expect(result.markdown, contains('edited note bodies are not compared'));
    expect(
      () => compare(List.generate(1001, (i) => function('$i', '1'))),
      throwsFormatException,
    );
  });
  test(
    'all-file search filters before limits, retains line endings and source hashes',
    () async {
      const text = 'Jump\r\nJUMP\rjumping\n😀 jump\n';
      final result = await searchSourceFiles(
        files: const [
          SourceFileEntry('other.txt', ''),
          SourceFileEntry('src/player.cpp', 'cpp'),
        ],
        read: (_) async => text,
        query: 'jump',
        wholeWord: true,
        pathFilter: 'src/',
        maxHits: 10,
      );
      expect(result.total, 1);
      expect(result.processed, 1);
      expect(result.hits.map((h) => h.line), [1, 2, 4]);
      expect(
        result.hits.first.sourceSha256,
        sha256.convert(utf8.encode(text)).toString(),
      );
      final capped = await searchSourceFiles(
        files: const [SourceFileEntry('x.cpp', 'cpp')],
        read: (_) async => text,
        query: 'jump',
        maxHits: 1,
      );
      expect(capped.hits.length, 1);
      expect(capped.truncated, isTrue);
    },
  );
  test(
    'search skips failures, reports incomplete budget and never claims cancellation complete',
    () async {
      const files = [
        SourceFileEntry('a.cpp', 'cpp'),
        SourceFileEntry('b.cpp', 'cpp'),
      ];
      final failed = await searchSourceFiles(
        files: files,
        query: 'x',
        read: (p) async {
          if (p.startsWith('a')) throw StateError('unreadable');
          return 'x';
        },
      );
      expect(failed.skipped, ['a.cpp']);
      expect(failed.processed, 2);
      final limited = await searchSourceFiles(
        files: files,
        query: 'x',
        read: (_) async => 'xx',
        maxCharacters: 2,
      );
      expect(limited.processed, 1);
      expect(limited.truncated, isTrue);
      final entered = Completer<void>(), pending = Completer<String>();
      var cancelled = false, reads = 0;
      final searching = searchSourceFiles(
        files: files,
        query: 'x',
        read: (_) {
          reads++;
          entered.complete();
          return pending.future;
        },
        cancelled: () => cancelled,
      );
      await entered.future;
      cancelled = true;
      pending.complete('x');
      final result = await searching;
      expect(result.cancelled, isTrue);
      expect(result.hits, isEmpty);
      expect(reads, 1);
      for (final invalid in ['', 'x\ny', 'x' * 301]) {
        await expectLater(
          searchSourceFiles(
            files: files,
            read: (_) async => 'x',
            query: invalid,
          ),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'whole-word search handles supplementary Unicode letters and large-file cancellation',
    () async {
      final result = await searchSourceFiles(
        files: const [SourceFileEntry('dump.log', '')],
        query: 'jump',
        wholeWord: true,
        read: (_) async => '𐐀jump\njump𐐀\n😀jump\nJump\n',
      );
      expect(result.hits.map((h) => h.line), [3, 4]);
      var stop = false;
      final future = searchSourceFiles(
        files: const [SourceFileEntry('many.txt', '')],
        query: 'absent',
        read: (_) async {
          Timer.run(() => stop = true);
          return List.filled(100000, 'line').join('\n');
        },
        cancelled: () => stop,
      );
      final cancelled = await future;
      expect(cancelled.cancelled, true);
      expect(cancelled.processed, 0);
      expect(sourceLanguage('dump.asm'), 'x86asm');
      expect(sourceLanguage('trace.log'), '');
    },
  );
  test(
    'source evidence and comparison persist as ordinary files with retained provenance',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-investigation-',
      );
      ProviderContainer? container;
      WorkspaceRepository? repo;
      try {
        repo = WorkspaceRepository(
          store: InvestigationNativeStore(root.path),
          index: MemoryObjectIndex(),
        );
        final opened = await open(repo);
        container = opened.$1;
        final c = opened.$2;
        final a = await create(c, '1'), b = await create(c, '2');
        final source = (await c.createSourceEvidence(
          const SourceExcerpt(
            'local repository',
            'src/player.cpp',
            4,
            5,
            'jump();\r\nreturn;\r\n',
            'cpp',
          ),
          folder: 'Notes',
          ownerId: a.id,
        ))!;
        final comparison = compare([a, b]);
        final report = (await c.saveResearchComparison(
          comparison,
          folder: 'Notes',
        ))!;
        final task = (await c.createComparisonInvestigation(
          comparison,
          comparison.rows.single,
          folder: 'Notes',
        ))!;
        expect(task.typeId, 'orbit.task');
        expect(task.properties['completed'], false);
        expect(report.properties['resourceIds'], [a.id, b.id]);
        expect(
          source.properties['sourceCapture'],
          containsPair('method', 'working-tree-capture'),
        );
        await c.flushAll();
        container.dispose();
        container = null;
        await repo.close();
        repo = WorkspaceRepository(
          store: InvestigationNativeStore(root.path),
          index: MemoryObjectIndex(),
        );
        await repo.initialize();
        final restored = repo.objects;
        expect(restored.firstWhere((o) => o.id == source.id).body, source.body);
        expect(
          restored
              .firstWhere((o) => o.id == report.id)
              .properties['sourceVersions'],
          {a.id: a.revision, b.id: b.revision},
        );
        expect(
          restored.firstWhere((o) => o.id == task.id).properties['resourceIds'],
          [a.id, b.id],
        );
        expect(
          (await root
                  .list(recursive: true)
                  .where((e) => e.path.endsWith('.md'))
                  .toList())
              .length,
          greaterThanOrEqualTo(4),
        );
      } finally {
        container?.dispose();
        await repo?.close();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'stale comparisons and failed saves preserve original function records',
    () async {
      final store = MemoryStore();
      final (container, c) = await open(
        WorkspaceRepository(store: store, index: MemoryObjectIndex()),
      );
      try {
        final a = await create(c, '1'), b = await create(c, '2');
        final snapshot = compare([a, b]);
        c.edit(a.id, body: '${a.body}\nNew observation');
        expect(
          await c.saveResearchComparison(snapshot, folder: 'Notes'),
          isNull,
        );
        await c.flushAll();
        expect(
          await c.createComparisonInvestigation(
            snapshot,
            snapshot.rows.single,
            folder: 'Notes',
          ),
          isNull,
        );
        final refreshed = compare([c.find(a.id)!, c.find(b.id)!]);
        store.failWrites = true;
        expect(
          await c.saveResearchComparison(refreshed, folder: 'Notes'),
          isNull,
        );
        expect(c.find(a.id)!.body, endsWith('New observation'));
        expect(c.find(b.id)!.body, b.body);
      } finally {
        container.dispose();
      }
    },
  );
  test(
    'source evidence rejects invalid scope, executable-looking language and missing owner',
    () async {
      final (container, c) = await open(
        WorkspaceRepository(store: MemoryStore(), index: MemoryObjectIndex()),
      );
      try {
        for (final path in ['../x.cpp', 'C:/x.cpp', '/x.cpp']) {
          expect(
            await c.createSourceEvidence(
              SourceExcerpt('repo', path, 1, 1, 'text', 'cpp'),
              folder: 'Notes',
            ),
            isNull,
          );
        }
        expect(
          await c.createSourceEvidence(
            const SourceExcerpt('repo', 'x.cpp', 1, 1, 'text', 'cpp\n```'),
            folder: 'Notes',
          ),
          isNull,
        );
        expect(
          await c.createSourceEvidence(
            const SourceExcerpt('repo', 'x.cpp', 1, 1, 'text', 'cpp'),
            folder: 'Notes',
            ownerId: 'missing',
          ),
          isNull,
        );
      } finally {
        container.dispose();
      }
    },
  );
  testWidgets(
    'search navigates exact lines and save evidence captures the same snapshot',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SourceExcerpt? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: SourceBrowserDialog(
            initialFolder: InvestigationFolder(),
            onSaveExcerpt: (v) async {
              saved = v;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search all files'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Find across source files'),
        'return',
      );
      await tester.tap(find.text('Search files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('src/player.cpp:2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save evidence note'));
      await tester.pumpAndSettle();
      expect(saved!.start, 2);
      expect(saved!.end, 2);
      expect(saved!.text, '  return;\r\n');
      expect(saved!.sourceSha256, hasLength(64));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('changed source never selects an obsolete search result', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final folder = InvestigationFolder();
    await tester.pumpWidget(
      MaterialApp(home: SourceBrowserDialog(initialFolder: folder)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search all files'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Find across source files'),
      'return',
    );
    await tester.tap(find.text('Search files'));
    await tester.pumpAndSettle();
    folder.changed = true;
    await tester.tap(find.text('src/player.cpp:2'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('This file changed since the search'),
      findsOneWidget,
    );
    final last = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Last line'),
    );
    expect(last.controller!.text, '1');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'comparison creates connected tasks once and saves a navigable report',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (container, c) = (await tester.runAsync(
        () => open(
          WorkspaceRepository(store: MemoryStore(), index: MemoryObjectIndex()),
        ),
      ))!;
      try {
        await tester.runAsync(() async {
          await create(c, '1');
          await create(c, '2');
        });
        await tester.pumpWidget(
          MaterialApp(
            home: ResearchComparisonDialog(
              controller: c,
              matchesScope: (_) => true,
              folder: 'Notes',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Jump'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Create investigation task'));
        await tester.tap(find.text('Create investigation task'));
        await tester.runAsync(() async {
          for (
            var i = 0;
            i < 100 && c.ofType('orbit.task').isEmpty && c.error == null;
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 2));
          }
        });
        await tester.pumpAndSettle();
        expect(c.ofType('orbit.task'), hasLength(1), reason: c.error);
        expect(find.text('Open investigation task'), findsOneWidget);
        expect(
          c
              .connectionsFrom(c.ofType('orbit.task').single.id)
              .map((e) => e.target.id)
              .toSet(),
          containsAll(
            c.objects
                .where((o) => o.properties['category'] == 'Function')
                .map((o) => o.id),
          ),
        );
        await tester.ensureVisible(find.text('Save comparison note'));
        await tester.tap(find.text('Save comparison note'));
        await tester.runAsync(() async {
          for (
            var i = 0;
            i < 100 &&
                !c.objects.any(
                  (o) => o.properties['category'] == 'Build Comparison',
                ) &&
                c.error == null;
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 2));
          }
        });
        await tester.pumpAndSettle();
        expect(
          c.objects.where(
            (o) => o.properties['category'] == 'Build Comparison',
          ),
          hasLength(1),
        );
        expect(find.text('Open saved report'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        container.dispose();
      }
    },
  );
  for (final size in [const Size(360, 640), const Size(640, 360)]) {
    testWidgets('technical dialogs reflow at 200% text on $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (container, c) = (await tester.runAsync(
        () => open(
          WorkspaceRepository(store: MemoryStore(), index: MemoryObjectIndex()),
        ),
      ))!;
      try {
        await tester.runAsync(() async {
          await create(c, '1');
          await create(c, '2');
        });
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: ResearchComparisonDialog(
              controller: c,
              matchesScope: (_) => true,
              folder: 'Notes',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: SourceSearchDialog(
              folder: InvestigationFolder(),
              files: const [SourceFileEntry('x.cpp', 'cpp')],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        container.dispose();
      }
    });
  }
}
