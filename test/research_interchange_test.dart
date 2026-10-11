import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/reverse_engineering.dart';
import 'package:orbit_note/domain/wiki_links.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/workspace/research_record_dialog.dart';
import 'package:orbit_note/features/workspace/function_table_view.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

import 'support/memory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('research opt-in preserves unknown settings', () {
    expect(SessionState.fromJson({}).reverseEngineeringEnabled, false);
    final enabled = SessionState.fromJson({
      'reverseEngineeringEnabled': true,
      'future': {'flag': 'keep'},
    });
    expect(enabled.reverseEngineeringEnabled, true);
    enabled.reverseEngineeringEnabled = false;
    expect(SessionState.fromJson(enabled.toJson()).extra['future'], {
      'flag': 'keep',
    });
  });
  test('64-bit addresses keep precision and normalize leading zeros', () {
    expect(normalizeResearchAddress('0X0000abcdef'), '0xABCDEF');
    expect(normalizeResearchAddress('ffffffffffffffff'), '0xFFFFFFFFFFFFFFFF');
    for (final value in ['xyz', '-1', '0x', '10000000000000000']) {
      expect(() => normalizeResearchAddress(value), throwsFormatException);
    }
  });

  ResearchAddress location({
    String build = 'v1',
    String binary = 'binary',
    String base = '0x140000000',
    String address = '0x140001000',
  }) => ResearchAddress(
    binaryId: binary,
    binaryVersion: build,
    moduleId: 'module',
    address: address,
    moduleBase: base,
  );
  test(
    'address identity survives rebase and separates builds and binaries',
    () {
      final original = location();
      expect(original.toProperties()['rva'], '0x1000');
      expect(
        original.identity,
        location(base: '0x180000000', address: '0x180001000').identity,
      );
      expect(original.identity, isNot(location(build: 'v2').identity));
      expect(original.identity, isNot(location(binary: 'other').identity));
      expect(const ResearchAddress(address: '0x1000').identity, isNull);
    },
  );
  test('inconsistent address context fails rather than misresolving', () {
    expect(
      () => const ResearchAddress(
        addressSpace: 'rva',
        address: '0x10',
        rva: '0x20',
      ).toProperties(),
      throwsFormatException,
    );
    expect(
      const ResearchAddress(
        addressSpace: 'rva',
        address: '0x10',
        moduleBase: '0x1000',
      ).toProperties()['rva'],
      '0x10',
    );
    expect(
      () => location(address: '0x10').toProperties(),
      throwsFormatException,
    );
    expect(
      () => const ResearchAddress(
        address: '0x1010',
        moduleBase: '0x1000',
        rva: '0x11',
      ).toProperties(),
      throwsFormatException,
    );
    expect(
      () => const ResearchAddress(addressSpace: 'physical').toProperties(),
      throwsFormatException,
    );
  });
  test('CSV handles quoted commas, escaped quotes, multiline and BOM', () {
    final plan = FunctionImportPlan.csv(
      '\uFEFFName,RVA,Module,Purpose\r\n'
      'Decode,0x000010,game.exe,"Reads a,b and ""quoted"" text\r\nsecond line"\r\n',
    );
    final fn = plan.functions.single;
    expect(fn.purpose, 'Reads a,b and "quoted" text\r\nsecond line');
    expect(fn.location.address, isEmpty);
    expect(fn.location.toProperties()['rva'], '0x10');
    expect(fn.location.addressSpace, 'rva');
  });
  test('header detection does not discard a symbol containing name', () {
    expect(
      FunctionImportPlan.csv('rename_object,0x1000').functions.single.name,
      'rename_object',
    );
  });
  test('malformed imports fail validation for the entire batch', () {
    for (final csv in [
      'Name,Address\nGood,0x10\nBad,garbage',
      'Name,Address\nGood,0x10,extra',
      'Name,Address\n"Unclosed,0x10',
    ]) {
      expect(() => FunctionImportPlan.csv(csv), throwsFormatException);
    }
    for (final json in [
      '{"version":2,"functions":[]}',
      '{}',
      '[{"name":"Good","address":"0x10"},false]',
      '[{"name":"Missing"}]',
    ]) {
      expect(() => FunctionImportPlan.json(json), throwsFormatException);
    }
  });
  test(
    'versioned JSON retains provenance and distinct address/RVA context',
    () {
      final plan = FunctionImportPlan.json(
        jsonEncode({
          'version': 1,
          'tool': 'Ghidra',
          'source': 'symbols.json',
          'context': {
            'binaryId': 'b',
            'binaryVersion': 'build-17',
            'moduleId': 'm',
            'moduleBase': '0x1000',
          },
          'functions': [
            {'name': 'Decode', 'address': '0x1010', 'rva': '0x10'},
          ],
        }),
      );
      expect(plan.tool, 'Ghidra');
      expect(plan.functions.single.location.identity, isNotNull);
      expect(
        plan.functions.single.location.toProperties()['binaryVersion'],
        'build-17',
      );
    },
  );

  group('durable research and playtest commands', () {
    late WorkspaceController controller;
    late ProviderContainer container;
    late WorkspaceRepository repository;
    late FolderMemoryStore store;
    setUp(() async {
      store = FolderMemoryStore();
      repository = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repository)],
      );
      container.read(workspaceProvider);
      controller = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 100 && controller.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    });
    tearDown(() async {
      await controller.flushAll();
      container.dispose();
    });
    test(
      'all record categories are readable Markdown and survive refresh',
      () async {
        for (final category in researchRecordCategories) {
          final note = await controller.createResearchRecord(
            folder: 'Notes/Research',
            category: category,
            title: category,
          );
          expect(note!.typeId, 'orbit.note');
          expect(note.properties['category'], category);
          expect(note.body, contains('## Summary'));
          if (category == 'Patch') {
            expect(note.properties['appliesToBinary'], false);
          }
        }
        await repository.refresh();
        expect(
          repository.objects
              .where((o) => o.properties['researchSchemaVersion'] == 1)
              .length,
          12,
        );
        expect(store.files.keys.where((p) => p.endsWith('.md')).length, 12);
      },
    );
    test(
      'evidence uses stable IDs and rejects contradictory or missing links',
      () async {
        final finding = (await controller.createResearchRecord(
          folder: 'Notes',
          category: 'Finding',
          title: 'Observed write',
        ))!;
        final hypothesis = (await controller.createResearchRecord(
          folder: 'Notes',
          category: 'Hypothesis',
          title: 'State update',
          supportingIds: [finding.id],
        ))!;
        expect(parseWikiLinks(hypothesis.body).single.target, finding.id);
        expect(hypothesis.properties['supportingIds'], [finding.id]);
        controller.edit(finding.id, title: 'Renamed observation');
        await controller.flush(finding.id);
        await repository.refresh();
        expect(
          repository.objects
              .firstWhere((o) => o.id == hypothesis.id)
              .properties['supportingIds'],
          [finding.id],
        );
        await expectLater(
          controller.createResearchRecord(
            folder: 'Notes',
            category: 'Hypothesis',
            title: 'Bad',
            supportingIds: [finding.id],
            contradictingIds: [finding.id],
          ),
          throwsFormatException,
        );
        await expectLater(
          controller.createResearchRecord(
            folder: 'Notes',
            category: 'Hypothesis',
            title: 'Bad',
            supportingIds: ['missing'],
          ),
          throwsFormatException,
        );
      },
    );
    test(
      'validation errors write no functions and save failures count only successes',
      () async {
        final before = controller.objects.length;
        expect(
          () => controller.importFunctionsFromJson(
            '[{"name":"Good","address":"0x10"},{"name":"Bad"}]',
            folder: 'Notes',
          ),
          throwsFormatException,
        );
        expect(controller.objects.length, before);
        store.failWrites = true;
        expect(
          await controller.importFunctionsFromCsv(
            'Name,Address\nTest,0x10',
            folder: 'Notes',
          ),
          0,
        );
        store.failWrites = false;
      },
    );
    test(
      'RVA-only imports do not invent a virtual address or disassembly',
      () async {
        expect(
          await controller.importFunctionsFromCsv(
            'Name,RVA\nDecode,0x40',
            folder: 'Notes',
          ),
          1,
        );
        final function = controller.objects.singleWhere(
          (o) => o.title == 'Decode',
        );
        expect(function.properties['address'], isNull);
        expect(function.properties['rva'], '0x40');
        expect(function.body, isNot(contains('push    rbp')));
      },
    );
    test('unknown tool metadata survives canonical Markdown refresh', () async {
      await controller.importFunctionsFromJson(
        jsonEncode({
          'version': 1,
          'context': {'binaryVersion': 'v1', 'customArchitecture': 'future'},
          'functions': [
            {
              'name': 'Fn',
              'address': '0x10',
              'customSymbol': {
                'flags': [7, 8],
              },
            },
          ],
        }),
        folder: 'Notes',
      );
      await repository.refresh();
      final provenance =
          repository.objects
                  .singleWhere((o) => o.title == 'Fn')
                  .properties['researchProvenance']
              as Map;
      expect((provenance['record'] as Map)['customSymbol'], {
        'flags': [7, 8],
      });
      expect((provenance['context'] as Map)['customArchitecture'], 'future');
    });
    test(
      'research maps reference canonical records and retain evidence edges',
      () async {
        final finding = (await controller.createResearchRecord(
          folder: 'Notes',
          category: 'Finding',
          title: 'Observation',
        ))!;
        final hypothesis = (await controller.createResearchRecord(
          folder: 'Notes',
          category: 'Hypothesis',
          title: 'Inference',
          supportingIds: [finding.id],
        ))!;
        final count = controller.objects.length;
        final map = (await controller.createResearchMap(
          folder: 'Notes',
          title: 'Evidence',
          objectIds: [finding.id, hypothesis.id, finding.id],
        ))!;
        expect(controller.objects.length, count + 1);
        final scene = CanvasScene.fromJson(map.data);
        final raw = map.data['elements'] as List;
        expect(
          raw
              .where((e) => e['type'] == 'card')
              .map((e) => e['objectId'])
              .toSet(),
          {finding.id, hypothesis.id},
        );
        expect(
          raw.where((e) => e['type'] == 'connector').single['text'],
          'Supports',
        );
        expect(scene.elements.every((e) => e.renderable), true);
        controller.edit(map.id, data: {'schemaVersion': 1, 'elements': []});
        await controller.flush(map.id);
        await repository.refresh();
        expect(
          repository.objects.firstWhere((o) => o.id == finding.id).isDeleted,
          false,
        );
        await expectLater(
          controller.createResearchMap(
            folder: 'Notes',
            title: 'Bad',
            objectIds: ['missing'],
          ),
          throwsFormatException,
        );
      },
    );
    testWidgets(
      'function table separates research types and never invents a location',
      (tester) async {
        tester.view.physicalSize = const Size(1800, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final function = (await tester.runAsync(
          () => controller.createResearchRecord(
            folder: 'Notes',
            category: 'Function',
            title: 'Unknown function',
          ),
        ))!;
        await tester.runAsync(
          () => controller.createResearchRecord(
            folder: 'Notes',
            category: 'String',
            title: 'String at same address',
            location: const ResearchAddress(address: '0x10'),
          ),
        );
        final view = (await tester.runAsync(
          () => controller.create('orbit.view', title: 'Functions'),
        ))!;
        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: FunctionTableView(controller: controller, viewObject: view),
            ),
          ),
        );
        await tester.pump();
        expect(find.text(function.title), findsOneWidget);
        expect(find.text('String at same address'), findsNothing);
        expect(find.text('Not recorded'), findsOneWidget);
        expect(find.text('0x0'), findsNothing);
        final copy = tester.widget<IconButton>(
          find.byWidgetPredicate(
            (widget) =>
                widget is IconButton &&
                widget.tooltip == 'Address not recorded',
          ),
        );
        expect(copy.onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'record dialog validates before saving and creates a readable patch',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showResearchRecordDialog(
                    context,
                    controller,
                    folder: 'Notes',
                    initialCategory: 'Patch',
                  ),
                  child: const Text('New record'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('New record'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create record'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Choose a research record type and title.'),
          findsOneWidget,
        );
        expect(controller.objects, isEmpty);
        await tester.enterText(
          find.widgetWithText(TextField, 'Name'),
          'Proposed bounds check',
        );
        await tester.runAsync(() async {
          await tester.tap(find.text('Create record'));
          for (var i = 0; i < 100 && controller.objects.isEmpty; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        expect(find.text('Research record'), findsNothing);
        expect(controller.objects.single.properties['category'], 'Patch');
        expect(controller.objects.single.properties['appliesToBinary'], false);
        expect(tester.takeException(), isNull);
      },
    );
    test(
      'playtest task references survive same-title notes and rename',
      () async {
        final source = (await controller.create(
          'orbit.note',
          title: 'Playtest',
        ))!;
        await controller.create('orbit.note', title: 'Playtest');
        final task = (await controller.createTaskFromFinding(
          finding: 'Fix jump',
          sourceNoteId: source.id,
        ))!;
        expect(parseWikiLinks(task.body).single.target, source.id);
        expect(
          parseWikiLinks(controller.find(source.id)!.body).single.target,
          task.id,
        );
        await repository.refresh();
        expect(
          repository.objects
              .firstWhere((o) => o.id == source.id)
              .properties['findingTaskIds'],
          [task.id],
        );
        expect(
          await controller.createTaskFromFinding(
            finding: 'Orphan',
            sourceNoteId: 'missing',
          ),
          isNull,
        );
      },
    );
  });
}
