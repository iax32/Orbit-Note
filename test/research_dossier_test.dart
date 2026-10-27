import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/research_dossier.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/object_connections.dart';
import 'package:orbit_note/domain/linked_section.dart';
import 'package:orbit_note/domain/note_composition.dart';
import 'package:orbit_note/domain/research_comparison.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/memory_store.dart';

Map<String, dynamic> draft(
  String kind, {
  String root = 'root',
  String build = 'v1',
}) => {
  'version': 1,
  'kind': kind,
  'state': 'suspected',
  'confidence': 'low',
  'build': build,
  if (kind != 'dossier') 'dossierId': root,
  'rows': <dynamic>[],
  'links': <dynamic>[],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'layout validation keeps 64-bit offsets exact and flags intentional overlaps',
    () {
      final data = {
        ...draft('structure'),
        'rows': [
          {
            'offset': '0xFFFFFFFFFFFFFFF0',
            'size': '8',
            'name': 'flags',
            'type': 'uint64',
            'explanation': 'Observed',
            'future': {'kept': true},
          },
          {
            'offset': '0xFFFFFFFFFFFFFFF4',
            'size': '4',
            'name': 'alias',
            'type': 'uint32',
            'explanation': 'Union hypothesis',
          },
        ],
      };
      validateDossier(data);
      final o = UniversalObject(
        id: 'layout',
        workspaceId: 'w',
        typeId: 'orbit.note',
        title: 'Player',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        properties: {'researchDossier': data},
      );
      expect(
        dossierWarnings(o, [o]).any((w) => w.contains('Overlapping')),
        isTrue,
      );
      expect(dossierSummary(data), contains('0xFFFFFFFFFFFFFFF0'));
      expect(
        () => validateDossier({
          ...data,
          'rows': [
            {'offset': '0xFFFFFFFFFFFFFFFF', 'size': '2'},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => validateDossier({
          ...data,
          'rows': [
            {'offset': '0x10', 'size': '0'},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => validateDossier({...data, 'version': 2}),
        throwsFormatException,
      );
      expect(
        () => validateDossier({
          ...data,
          'rows': List.filled(501, {'offset': '0', 'size': '1'}),
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'function explanations use real responsive Markdown columns with lossless code fences',
    () {
      final data = {
        ...draft('function'),
        'prototype': 'float getHealth(Player* p)',
        'rows': [
          {
            'address': '0x10',
            'instruction': 'mov eax, [rcx+0x20]',
            'explanation': 'Recorded field access',
            'branch': 'return',
          },
          {
            'address': '0x14',
            'instruction': '``` unusual authored text',
            'explanation': 'Literal',
            'branch': '',
          },
        ],
      };
      final body = updateDossierBody(
        '',
        data,
        creating: true,
        notes: '## Personal notes\n\nNever remove this.',
      );
      final document = MarkdownDocument.parse(body);
      expect(
        document.blocks.any((b) => NoteColumns.parse(b.source) != null),
        isTrue,
      );
      final saved = updateDossierBody(body, {...data, 'summary': 'Changed'});
      expect(
        saved.endsWith('## Personal notes\n\nNever remove this.\n'),
        isTrue,
      );
      expect(saved, contains('mov eax, [rcx+0x20]'));
      expect(
        () => updateDossierBody('User removed markers', data),
        throwsFormatException,
      );
      expect(
        () => updateDossierBody('$body\n$dossierStart', data),
        throwsFormatException,
      );
      final literal = updateDossierBody(
        '',
        data,
        creating: true,
        notes:
            '## Literal examples\n\n```text\n$dossierStart\n$dossierEnd\n```\n',
      );
      expect(
        updateDossierBody(literal, {...data, 'summary': 'Revised'}),
        contains('```text\n$dossierStart\n$dossierEnd\n```'),
      );
      for (final template in dossierTemplates.values) {
        expect(MarkdownDocument.parse(template).source, template);
      }
    },
  );

  late MemoryStore store;
  late WorkspaceRepository repo;
  late ProviderContainer container;
  late WorkspaceController c;
  setUp(() async {
    store = MemoryStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    c = container.read(workspaceProvider.notifier);
    await c.initialize();
  });
  tearDown(() {
    c.cancelAllTimers();
    container.dispose();
  });
  Future<UniversalObject> root() => c
      .saveDossierRecord(title: 'Game dossier', data: draft('dossier'))
      .then((v) => v!);

  test(
    'all research kinds create ordinary connected notes and reopen without losing unknown fields',
    () async {
      final r = await root();
      for (final kind in dossierKinds.where((k) => k != 'dossier')) {
        final o = await c.saveDossierRecord(
          title: 'Recorded $kind',
          data: {
            ...draft(kind, root: r.id),
            'future': {
              'nested': [1, 2],
            },
          },
          notes: '## Observations\n\nAuthored evidence',
        );
        expect(o, isNotNull);
        expect(o!.typeId, 'orbit.note');
        expect(o.body, contains('Authored evidence'));
      }
      final reopened = WorkspaceRepository(
        store: MemoryStore()..files.addAll(store.files),
        index: MemoryObjectIndex(),
      );
      await reopened.initialize();
      expect(reopened.objects.where(isDossierRecord), hasLength(8));
      expect(
        dossierData(
          reopened.objects.firstWhere(
            (o) => dossierData(o)['kind'] == 'offset',
          ),
        )['future'],
        {
          'nested': [1, 2],
        },
      );
      final edges = ObjectConnectionResolver().resolve(reopened.objects);
      expect(edges.any((e) => e.target.id == r.id), isTrue);
      await reopened.close();
    },
  );
  test(
    'evidence warnings survive unrelated edits; acknowledgement and build review are explicit',
    () async {
      final r = await root();
      final evidence = (await c.create(
        'orbit.note',
        title: 'Trace',
        body: 'Original',
        open: false,
      ))!;
      var finding = (await c.saveDossierRecord(
        title: 'Field meaning',
        data: {
          ...draft('hypothesis', root: r.id),
          'state': 'confirmed',
          'links': [
            {'id': evidence.id, 'role': 'evidence', 'offset': ''},
          ],
        },
      ))!;
      expect(dossierWarnings(finding, c.objects), isEmpty);
      c.edit(evidence.id, body: 'Changed trace');
      await c.flush(evidence.id);
      expect(
        dossierWarnings(finding, c.objects).single,
        contains('Source changed'),
      );
      finding = (await c.saveDossierRecord(
        previous: finding,
        title: finding.title,
        data: {...dossierData(finding), 'summary': 'Extra detail'},
      ))!;
      expect(
        dossierWarnings(finding, c.objects).single,
        contains('Source changed'),
      );
      finding = (await c.saveDossierRecord(
        previous: finding,
        title: finding.title,
        data: dossierData(finding),
        reviewSources: true,
      ))!;
      expect(dossierWarnings(finding, c.objects), isEmpty);
      await c.saveDossierRecord(
        previous: r,
        title: r.title,
        data: {...dossierData(r), 'build': 'v2'},
      );
      expect(
        dossierWarnings(finding, c.objects).single,
        contains('Needs rechecking'),
      );
      expect(dossierData(c.find(finding.id)!)['state'], 'confirmed');
      expect(dossierRows(dossierData(finding), 'history'), hasLength(3));
      expect(await c.trash(evidence.id), isTrue);
      expect(
        dossierWarnings(
          finding,
          c.objects,
        ).any((w) => w.contains('Missing linked')),
        isTrue,
      );
    },
  );
  test(
    'stale forms and failed writes preserve notes; recoverable changes can undo',
    () async {
      final r = await root();
      final o = (await c.saveDossierRecord(
        title: 'Function',
        data: draft('function', root: r.id),
        notes: 'Keep my text.',
      ))!;
      final saved = await c.saveDossierRecord(
        previous: o,
        title: 'Updated function',
        data: {...dossierData(o), 'prototype': 'void tick()'},
      );
      expect(saved, isNotNull);
      expect(
        await c.saveDossierRecord(
          previous: o,
          title: 'Stale',
          data: dossierData(o),
        ),
        isNull,
      );
      expect(c.find(o.id)!.title, 'Updated function');
      expect(await c.undoPlanning(), isTrue);
      expect(c.find(o.id)!.body, o.body);
      final current = c.find(o.id)!;
      store.failWrites = true;
      expect(
        await c.saveDossierRecord(
          previous: current,
          title: 'Failed',
          data: dossierData(current),
        ),
        isNull,
      );
      store.failWrites = false;
      expect(c.find(o.id)!.title, current.title);
      expect(
        await c.saveDossierRecord(
          previous: current,
          title: 'Preserved',
          data: {...dossierData(current), 'kind': 'offset'},
        ),
        isNull,
      );
      c.edit(current.id, body: 'Ordinary note without generated markers');
      await c.flush(current.id);
      final edited = c.find(current.id)!;
      expect(
        await c.saveDossierRecord(
          previous: edited,
          title: 'Would overwrite',
          data: dossierData(edited),
        ),
        isNull,
      );
      expect(c.find(o.id)!.body, 'Ordinary note without generated markers');
    },
  );
  test(
    'maps reference canonical notes and retain offset/role labels; live summaries update',
    () async {
      final r = await root();
      final target = (await c.saveDossierRecord(
        title: 'Player',
        data: draft('structure', root: r.id),
      ))!;
      final source = (await c.saveDossierRecord(
        title: 'Root pointer',
        data: {
          ...draft('offset', root: r.id),
          'address': '0x1234',
          'links': [
            {'id': target.id, 'role': 'pointer', 'offset': '+0x20'},
          ],
        },
      ))!;
      final board = (await c.createDossierMap(r.id))!;
      final elements = board.data['elements'] as List;
      expect(elements.where((e) => e['objectId'] == source.id), hasLength(1));
      expect(
        elements.where((e) => e['text'] == 'pointer · +0x20'),
        hasLength(1),
      );
      final embed = LinkedSection.parse(dossierLiveEmbed(target))!;
      final updated = (await c.saveDossierRecord(
        previous: target,
        title: target.title,
        data: {...dossierData(target), 'summary': 'New layout evidence'},
      ))!;
      final resolved = resolveLinkedSection(embed, c.objects, {});
      expect(resolved.text, contains('New layout evidence'));
      expect(c.find(updated.id)!.id, target.id);
    },
  );
  test(
    'bad identities, future schemas and invalid locations never replace durable data',
    () async {
      final r = await root();
      expect(
        await c.saveDossierRecord(
          title: 'Missing parent',
          data: draft('offset'),
        ),
        isNull,
      );
      expect(
        await c.saveDossierRecord(
          title: 'Bad address',
          data: {
            ...draft('offset', root: r.id),
            'address': 'not hex',
          },
        ),
        isNull,
      );
      expect(
        await c.saveDossierRecord(
          title: 'Missing evidence',
          data: {
            ...draft('journal', root: r.id),
            'links': [
              {'id': 'missing', 'role': 'evidence'},
            ],
          },
        ),
        isNull,
      );
      await expectLater(
        repo.save(
          r.copyWith(
            properties: {
              ...r.properties,
              'researchDossier': {...dossierData(r), 'version': 2},
            },
          ),
        ),
        throwsFormatException,
      );
      expect(repo.objects.firstWhere((o) => o.id == r.id).body, r.body);
    },
  );
  test(
    'actual native Markdown round trip retains dossier metadata and notes',
    () async {
      final dir = await Directory.systemTemp.createTemp('orbit-dossier-');
      final native = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await native.initialize(path: dir.path);
        final metadata = {
          ...draft('dossier'),
          'future': {'preserved': true},
        };
        final saved = await native.create(
          typeId: 'orbit.note',
          title: 'Native dossier',
          body: updateDossierBody(
            '',
            metadata,
            creating: true,
            notes: 'Private observations 😀',
          ),
          properties: {'researchDossier': metadata},
        );
        await native.close();
        await native.initialize(path: dir.path);
        expect(
          native.objects.firstWhere((o) => o.id == saved.id).body,
          contains('Private observations 😀'),
        );
        expect(
          dossierData(
            native.objects.firstWhere((o) => o.id == saved.id),
          )['future'],
          {'preserved': true},
        );
      } finally {
        await native.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'dossier functions bridge to existing build comparison with explicit module and symbol identities',
    () async {
      final r = await root();
      for (final build in ['v1', 'v2']) {
        expect(
          await c.saveDossierRecord(
            title: 'Tick $build',
            data: {
              ...draft('function', root: r.id, build: build),
              'moduleId': 'explicit-engine-id',
              'symbol': 'tick',
              'module': 'engine.dll',
              'addressSpace': 'rva',
              'address': '0x1234',
            },
          ),
          isNotNull,
        );
      }
      final compared = ResearchBuildComparison(
        c.objects,
        ResearchBuild(r.id, 'v1'),
        ResearchBuild(r.id, 'v2'),
      );
      expect(compared.rows.single.state, 'Unchanged');
      expect(compared.sources, hasLength(2));
    },
  );
  test(
    'glossary abbreviations participate in universal note mentions',
    () async {
      final r = await root();
      final term = (await c.saveDossierRecord(
        title: 'Relative virtual address',
        data: {
          ...draft('glossary', root: r.id),
          'aliases': 'RVA, image offset; RVA',
        },
      ))!;
      expect(c.linkTargets.firstWhere((t) => t.id == term.id).aliases, [
        'RVA',
        'image offset',
      ]);
    },
  );
}
