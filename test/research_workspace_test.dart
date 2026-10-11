import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/research_workspace.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/backlinks.dart';
import 'package:orbit_note/features/workspace/graph_view.dart';
import 'package:orbit_note/features/workspace/decision_editor_dialog.dart';
import 'package:orbit_note/features/workspace/research_workspace_view.dart';
import 'package:orbit_note/features/notes/rich/dynamic_view_block.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/memory_store.dart';

class ResearchNativeStore extends NativeWorkspaceStore {
  ResearchNativeStore(this.root);
  final String root;
  @override
  Future<void> initialize({String? path}) =>
      super.initialize(path: path ?? root);
}

Future<(ProviderContainer, WorkspaceController)> researchController(
  WorkspaceRepository repo,
) async {
  final container = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(repo)],
  );
  final c = container.read(workspaceProvider.notifier);
  for (var i = 0; i < 300 && c.loading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(c.loading, false);
  return (container, c);
}

Future<UniversalObject?> saveRecord(
  WorkspaceController c,
  String kind, {
  UniversalObject? previous,
  String state = 'Proposed',
  List<String> evidence = const [],
  List<String> assumptions = const [],
}) => c.saveResearchRecord(
  previous: previous,
  kind: kind,
  title: '$kind statement',
  body: '## Rationale\n\nUser reasoning.',
  state: state,
  confidence: 'Medium',
  importance: 'High',
  evidence: evidence,
  assumptions: assumptions,
  supersedes: [],
  project: 'project-a',
  folder: 'Notes',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('unrelated custom properties do not become research records', () {
    expect(
      () => validateResearchProperties({
        'researchKind': 'custom imported category',
      }),
      returnsNormally,
    );
  });
  testWidgets(
    'malformed collection entries stay preserved and cannot be silently dropped',
    (tester) async {
      final setup = await tester.runAsync(() async {
        final (container, c) = await researchController(
          WorkspaceRepository(
            store: FolderMemoryStore(),
            index: MemoryObjectIndex(),
          ),
        );
        final view = (await c.createResearchCollection(
          title: 'Imported collection',
        ))!;
        c.objects = [
          for (final o in c.objects)
            if (o.id == view.id)
              o.copyWith(
                properties: {
                  ...o.properties,
                  'referenceEntries': [42],
                },
              )
            else
              o,
        ];
        return (container, c, view);
      });
      final (container, c, view) = setup!;
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: ResearchWorkspaceView(controller: c, view: view),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('The saved collection is preserved'),
          findsOneWidget,
        );
        expect(c.find(view.id)!.properties['referenceEntries'], [42]);
        expect(find.text('Add references'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      }
    },
  );
  testWidgets(
    'decision form supports enlarged text and reports validation without losing the draft',
    (tester) async {
      final setup = await tester.runAsync(
        () => researchController(
          WorkspaceRepository(
            store: FolderMemoryStore(),
            index: MemoryObjectIndex(),
          ),
        ),
      );
      final (container, c) = setup!;
      try {
        await tester.binding.setSurfaceSize(const Size(360, 740));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 740),
                  textScaler: TextScaler.linear(1.6),
                ),
                child: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => showDecisionEditor(context, c),
                      child: const Text('Open editor'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save record'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Enter a statement.'), findsOneWidget);
        expect(
          find.text('Reasoning and alternatives · Markdown'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.binding.setSurfaceSize(null);
        container.dispose();
      }
    },
  );

  test(
    'decisions preserve reasoning and warn about changed, missing and disproved evidence',
    () async {
      final (container, c) = await researchController(
        WorkspaceRepository(
          store: FolderMemoryStore(),
          index: MemoryObjectIndex(),
        ),
      );
      try {
        final source = (await c.create(
          'orbit.note',
          title: 'Reference',
          body: 'Original',
        ))!;
        final assumption = (await saveRecord(
          c,
          'assumption',
          state: 'Unverified',
          evidence: [source.id],
        ))!;
        final decision = (await saveRecord(
          c,
          'decision',
          evidence: [source.id],
          assumptions: [assumption.id],
        ))!;
        expect(researchReviewReasons(decision, c.objects), isEmpty);
        final externalSource = source.copyWith(
          body: 'An external Markdown edit without changed frontmatter',
        );
        expect(
          researchReviewReasons(decision, [
            for (final o in c.objects)
              if (o.id == source.id) externalSource else o,
          ]).single,
          contains('Evidence changed'),
        );
        expect(
          findLinkedMentions(
            targetId: source.id,
            objects: c.objects,
            targets: c.linkTargets,
          ).where((m) => m.source.id == decision.id).single.label,
          'Supported by',
        );
        expect(
          GraphData.build(objects: c.objects).edges.any(
            (e) => e.sourceId == decision.id && e.targetId == assumption.id,
          ),
          true,
        );
        c.edit(source.id, body: 'Changed');
        expect(
          researchReviewReasons(decision, c.objects).single,
          contains('Evidence changed'),
        );
        expect(await c.reviewResearchDecision(decision.id), true);
        expect(researchReviewReasons(c.find(decision.id)!, c.objects), isEmpty);
        await saveRecord(
          c,
          'assumption',
          previous: c.find(assumption.id),
          state: 'Disproved',
          evidence: [source.id],
        );
        expect(
          researchReviewReasons(c.find(decision.id)!, c.objects).single,
          contains('Disproved assumption'),
        );
        expect(await c.reviewResearchDecision(decision.id), true);
        expect(
          researchReviewReasons(c.find(decision.id)!, c.objects).single,
          contains('Disproved assumption'),
        );
        final surviving = c.objects.where((o) => o.id != source.id).toList();
        expect(
          researchReviewReasons(c.find(decision.id)!, surviving),
          contains('Missing evidence · ${source.id}'),
        );
        expect(c.find(decision.id)!.body, decision.body);
      } finally {
        container.dispose();
        await c.repository.close();
      }
    },
  );

  test(
    'stale record edits, self links and mistyped assumption relations are rejected',
    () async {
      final (container, c) = await researchController(
        WorkspaceRepository(
          store: FolderMemoryStore(),
          index: MemoryObjectIndex(),
        ),
      );
      try {
        final source = (await c.create('orbit.note', title: 'Source'))!;
        final decision = (await saveRecord(c, 'decision'))!;
        c.edit(
          decision.id,
          body: 'Newer reasoning',
          properties: {
            ...decision.properties,
            'futureField': {'keep': true},
          },
        );
        expect(await saveRecord(c, 'decision', previous: decision), isNull);
        expect(c.find(decision.id)!.body, 'Newer reasoning');
        expect(
          await saveRecord(
            c,
            'decision',
            previous: c.find(decision.id),
            evidence: [decision.id],
          ),
          isNull,
        );
        expect(
          await saveRecord(c, 'decision', assumptions: [source.id]),
          isNull,
        );
        final saved = await saveRecord(
          c,
          'decision',
          previous: c.find(decision.id),
        );
        expect(saved!.properties['futureField'], {'keep': true});
        c.objects = [
          for (final o in c.objects)
            if (o.id == saved.id)
              UniversalObject.fromJson({
                ...o.toJson(),
                'schemaVersion': 99,
              }, body: o.body)
            else
              o,
        ];
        expect(await c.reviewResearchDecision(saved.id), false);
        expect(
          await saveRecord(c, 'decision', previous: c.find(saved.id)),
          isNull,
        );
      } finally {
        container.dispose();
        await c.repository.close();
      }
    },
  );

  test(
    'linked collections, decisions, versions and unknown metadata survive native restart',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-research-');
      final repo = WorkspaceRepository(
        store: ResearchNativeStore(root.path),
        index: MemoryObjectIndex(),
      );
      final (container, c) = await researchController(repo);
      String collectionId = '', decisionId = '', sourceId = '';
      try {
        final source = (await c.create(
          'orbit.note',
          title: 'Evidence',
          body: 'Owned source',
        ))!;
        sourceId = source.id;
        final board = (await c.create(
          'orbit.canvas',
          data: {
            'schemaVersion': 1,
            'elements': [
              {
                'id': 'placement-1',
                'type': 'card',
                'objectId': source.id,
                'referenceCaption': 'Why saved',
                'referenceStatus': 'Chosen',
                'referenceTags': ['mood'],
                'x': 0,
                'y': 0,
                'width': 200,
                'height': 100,
              },
            ],
          },
        ))!;
        final collection = (await c.createResearchCollection(
          title: 'Research',
          folder: 'Notes',
          entries: c.researchBoardEntries(board.id),
        ))!;
        collectionId = collection.id;
        c.edit(
          collection.id,
          properties: {
            ...collection.properties,
            'researchLayout': 'Compare',
            'researchTag': 'mood',
            'unknown': 42,
          },
        );
        await c.flush(collection.id);
        final decision = (await saveRecord(
          c,
          'decision',
          evidence: [source.id],
        ))!;
        decisionId = decision.id;
        await saveRecord(
          c,
          'decision',
          previous: c.find(decision.id),
          evidence: [source.id],
          state: 'Accepted',
        );
        expect(c.getDocumentSnapshots(decision.id), isNotEmpty);
        expect(
          c
              .getDocumentSnapshots(decision.id)
              .first['researchFields']['researchState'],
          'Proposed',
        );
      } finally {
        container.dispose();
        await repo.close();
      }
      final reloaded = WorkspaceRepository(
        store: ResearchNativeStore(root.path),
        index: MemoryObjectIndex(),
      );
      final (otherContainer, other) = await researchController(reloaded);
      try {
        final collection = other.find(collectionId)!;
        expect(collection.properties['researchLayout'], 'Compare');
        expect(collection.properties['unknown'], 42);
        expect(
          (collection.properties['referenceEntries'] as List)
              .single['objectId'],
          sourceId,
        );
        expect(
          researchReviewReasons(other.find(decisionId)!, other.objects),
          isEmpty,
        );
        other.edit(
          collectionId,
          properties: {...collection.properties, 'referenceEntries': []},
        );
        await other.flush(collectionId);
        expect(other.find(sourceId)!.body, 'Owned source');
      } finally {
        otherContainer.dispose();
        await reloaded.close();
        await root.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'narrow enlarged-text research layout, compare, filters and decision UI',
    (tester) async {
      final setup = await tester.runAsync(
        () => researchController(
          WorkspaceRepository(
            store: FolderMemoryStore(),
            index: MemoryObjectIndex(),
          ),
        ),
      );
      final (container, c) = setup!;
      try {
        final view = (await tester.runAsync(() async {
          final source = (await c.create(
            'orbit.note',
            title: 'Landscape study',
            body: 'Evidence text',
          ))!;
          return c.createResearchCollection(
            title: 'Research',
            folder: 'Notes',
            entries: [
              {
                'objectId': source.id,
                'referenceTags': ['art'],
              },
            ],
          );
        }))!;
        await tester.binding.setSurfaceSize(const Size(360, 740));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 740),
                  textScaler: TextScaler.linear(1.6),
                ),
                child: Scaffold(
                  body: ResearchWorkspaceView(controller: c, view: view),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Landscape study'), findsOneWidget);
        await tester.tap(find.byType(Checkbox).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compare').first);
        await tester.pumpAndSettle();
        expect(find.text('Evidence text'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(DynamicViewConfig.parse('view: ${view.id}').viewId, view.id);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.binding.setSurfaceSize(null);
        container.dispose();
      }
    },
  );

  test(
    'future and malformed collections are rejected without modifying sources',
    () {
      expect(
        () => validateResearchProperties({
          'viewType': 'research',
          'researchVersion': 2,
          'referenceEntries': [],
          'researchLayout': 'Gallery',
        }),
        throwsFormatException,
      );
      expect(
        () => validateResearchProperties({
          'viewType': 'research',
          'researchVersion': 1,
          'referenceEntries': [42],
          'researchLayout': 'Gallery',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'a failed record save retains the draft and recoverable history',
    () async {
      final store = FolderMemoryStore();
      final (container, c) = await researchController(
        WorkspaceRepository(store: store, index: MemoryObjectIndex()),
      );
      try {
        final record = (await saveRecord(c, 'decision'))!;
        store.failWrites = true;
        expect(
          await saveRecord(c, 'decision', previous: record, state: 'Accepted'),
          isNull,
        );
        expect(c.failures.containsKey(record.id), true);
        expect(c.find(record.id)!.properties['researchState'], 'Accepted');
        expect(
          c.getDocumentSnapshots(record.id).single['label'],
          contains('Proposed'),
        );
      } finally {
        container.dispose();
        await c.repository.close();
      }
    },
  );

  test(
    'removing linked file membership preserves original attachment bytes',
    () async {
      final (container, c) = await researchController(
        WorkspaceRepository(
          store: FolderMemoryStore(),
          index: MemoryObjectIndex(),
        ),
      );
      try {
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final source = await c.repository.importAttachment(
          name: 'evidence.pdf',
          bytes: bytes,
        );
        c.mergeRepositoryObjects();
        final collection = (await c.createResearchCollection(
          title: 'Evidence',
          entries: [
            {'objectId': source.id},
          ],
        ))!;
        c.edit(
          collection.id,
          properties: {...collection.properties, 'referenceEntries': []},
        );
        await c.flush(collection.id);
        expect(
          await c.repository.readAttachment(
            source.properties['contentRef'] as String,
          ),
          bytes,
        );
        expect(c.find(source.id)!.isDeleted, false);
        expect(researchSourceType(c.find(source.id)), 'PDF');
      } finally {
        container.dispose();
        await c.repository.close();
      }
    },
  );

  testWidgets('saved research embeds share live sources and board commentary', (
    tester,
  ) async {
    final setup = await tester.runAsync(() async {
      final (container, c) = await researchController(
        WorkspaceRepository(
          store: FolderMemoryStore(),
          index: MemoryObjectIndex(),
        ),
      );
      final source = (await c.create('orbit.note', title: 'Shared source'))!;
      final board = (await c.create(
        'orbit.canvas',
        data: {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'card',
              'type': 'card',
              'objectId': source.id,
              'referenceCaption': 'Initial caption',
              'x': 0,
              'y': 0,
              'width': 100,
              'height': 100,
            },
          ],
        },
      ))!;
      final view = (await c.createResearchCollection(
        title: 'Reusable',
        entries: c.researchBoardEntries(board.id),
      ))!;
      return (container, c, source, board, view);
    });
    final (container, c, source, board, view) = setup!;
    try {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  for (var i = 0; i < 2; i++)
                    Expanded(
                      child: DynamicViewBlock(
                        source: 'view: ${view.id}',
                        controller: c,
                        onChanged: (_) {},
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Shared source'), findsNWidgets(2));
      expect(find.text('Initial caption'), findsNWidgets(2));
      c.edit(source.id, title: 'Updated source');
      c.edit(
        board.id,
        data: {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'card',
              'type': 'card',
              'objectId': source.id,
              'referenceCaption': 'Updated caption',
              'x': 0,
              'y': 0,
              'width': 100,
              'height': 100,
            },
          ],
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('Updated source'), findsNWidgets(2));
      expect(find.text('Updated caption'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
      container.dispose();
    }
  });
}
