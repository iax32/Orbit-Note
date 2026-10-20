import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/linked_section.dart';
import 'package:orbit_note/domain/note_composition.dart';
import 'package:orbit_note/domain/object_connections.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/domain/project_context.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/study_card.dart';
import 'package:orbit_note/features/notes/media_clipboard.dart';
import 'package:orbit_note/features/workspace/object_bridges.dart';
import 'package:orbit_note/features/workspace/graph_view.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/memory_store.dart';

UniversalObject object(
  String id, {
  String type = 'orbit.note',
  String body = '',
  Map<String, dynamic> properties = const {},
  Map<String, dynamic> data = const {},
}) => UniversalObject(
  id: id,
  workspaceId: 'vault',
  typeId: type,
  title: id,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  body: body,
  properties: properties,
  data: data,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Portable references and derived connections', () {
    test(
      'graph and connection browser derive the same live references including files and views',
      () {
        final objects = [
          object(
            'note',
            body: const NoteObjectBlock(
              'file',
              'PDF',
              fragment: 'page=2',
            ).encode(),
          ),
          object('file', type: 'orbit.file'),
          object(
            'board',
            type: 'orbit.canvas',
            data: {
              'elements': [
                {'id': 'card', 'objectId': 'note'},
              ],
            },
          ),
          object(
            'view',
            type: 'orbit.view',
            properties: {
              'memberIds': ['note'],
            },
          ),
        ];
        final connections = ObjectConnectionResolver().resolve(objects);
        final graph = GraphData.build(
          objects: objects,
          connections: connections,
        );
        expect(
          graph.nodes.map((n) => n.id),
          containsAll(['note', 'file', 'board', 'view']),
        );
        expect(graph.edges, hasLength(3));
        expect(
          graph.edges.any((e) => e.sourceId == 'note' && e.targetId == 'file'),
          isTrue,
        );
      },
    );

    test('study cards retain exact page provenance in connections', () {
      final card = object(
        'card',
        properties: {
          'studyCard': StudyCard.initial(
            DateTime.utc(2026),
            source: {
              'objectId': 'pdf',
              'page': 5,
              'title': 'PDF',
              'passage': 'Source text',
              'revision': 1,
              'capturedAt': DateTime.utc(2026).toIso8601String(),
            },
          ),
        },
      );
      expect(
        ObjectConnectionResolver()
            .resolve([card, object('pdf')])
            .single
            .target
            .target,
        'pdf#page=5',
      );
    });
    test('large workspace edits reparse one source rather than all notes', () {
      final objects = [
        object('target'),
        for (var i = 0; i < 1000; i++)
          object(
            'note-$i',
            body: const NoteObjectBlock('target', 'Shared').encode(),
          ),
      ];
      final resolver = ObjectConnectionResolver();
      expect(resolver.resolve(objects), hasLength(1000));
      final parsed = resolver.parsedSources;
      objects[500] = objects[500].copyWith(body: '${objects[500].body}More');
      expect(resolver.resolve(objects), hasLength(1000));
      expect(resolver.parsedSources - parsed, 1);
    });
    test(
      'native Markdown and Canvas retain precise bridges and unknown data',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'orbit-live-bridges-',
        );
        final repo = WorkspaceRepository(
          store: NativeWorkspaceStore(),
          index: MemoryObjectIndex(),
        );
        try {
          await repo.initialize(path: dir.path);
          final source = await repo.create(
            typeId: 'orbit.note',
            title: 'Source',
            body: '# Origin\nText ^stable',
          );
          final ref = ObjectReference.parse('${source.id}#^stable');
          final note = await repo.create(
            typeId: 'orbit.note',
            title: 'Reference',
            body: NoteObjectBlock(
              source.id,
              source.title,
              fragment: ref.fragment,
            ).encode(eol: '\r\n'),
            properties: {'future': true},
          );
          final canvas = await repo.create(
            typeId: 'orbit.canvas',
            title: 'Board',
            data: {
              'schemaVersion': 1,
              'future': 42,
              'elements': [
                {
                  'id': 'place',
                  'type': 'card',
                  'objectId': source.id,
                  'referenceTarget': ref.target,
                },
              ],
            },
          );
          await repo.close();
          await repo.initialize(path: dir.path);
          final edges = ObjectConnectionResolver().resolve(
            repo.objects,
            pathFor: repo.objectPath,
          );
          expect(edges.map((e) => e.target.target), [ref.target, ref.target]);
          expect(
            repo.objects
                .firstWhere((o) => o.id == note.id)
                .properties['future'],
            isTrue,
          );
          expect(
            repo.objects.firstWhere((o) => o.id == canvas.id).data['future'],
            42,
          );
        } finally {
          await repo.close();
          await dir.delete(recursive: true);
        }
      },
    );
    for (final fragment in [
      null,
      'page=12',
      '^alpha',
      'Design%20%E2%9C%A8',
      'element=item%2520',
      'future=value',
    ]) {
      test('live card preserves location $fragment and CRLF', () {
        final block = NoteObjectBlock(
          'source',
          'A [title]',
          fragment: fragment,
        );
        final encoded = block.encode(eol: '\r\n');
        final parsed = NoteObjectBlock.parse(encoded)!;
        expect(parsed.id, 'source');
        expect(parsed.reference.target, block.reference.target);
        expect(parsed.encode(eol: '\r\n'), encoded);
        final placement = markdownCanvasItems(encoded).single;
        expect(placement['objectId'], 'source');
        expect(placement['referenceTarget'], block.reference.target);
        final pasted = canvasClipboardMarkdown(
          '$canvasClipboardPrefix${jsonEncode({
            'elements': [placement],
          })}',
        )!;
        expect(pasted, contains(block.reference.target));
        expect(
          markdownCanvasItems(pasted).single['referenceTarget'],
          block.reference.target,
        );
      });
    }
    test('unknown and malformed markers stay literal; code is never an embed', () {
      for (final source in [
        '<!-- orbit:object v=2 -->\n[X](orbit-object:a)\n<!-- /orbit:object -->\n',
        '<!-- orbit:object v=1 -->\n[X](orbit-object:a#bad location)\n<!-- /orbit:object -->\n',
        '```md\n${const NoteObjectBlock('a', 'A').encode()}```\n',
      ]) {
        expect(
          markdownCanvasItems(source).every((e) => e['type'] == 'sticky'),
          isTrue,
        );
      }
    });
    test(
      'live cards, sections and nested columns have exact source offsets',
      () {
        final card = const NoteObjectBlock(
          'target',
          'Target',
          fragment: 'page=4',
        ).encode();
        final section = LinkedSection(
          ObjectReference.parse('target#^intro'),
          'Saved fallback',
        ).encode();
        final body = NoteColumns.create(['Intro\n\n$card', section]);
        final edges = ObjectConnectionResolver().resolve([
          object('note', body: body),
          object('target'),
        ]);
        expect(edges.map((e) => e.target.target), [
          'target#page=4',
          'target#^intro',
        ]);
        expect(edges.map((e) => e.offset), [
          body.indexOf('<!-- orbit:object'),
          body.indexOf('<!-- orbit:section'),
        ]);
      },
    );
    test(
      'attachment paths resolve relative to the note; ambiguous files are not guessed',
      () {
        final file = object(
          'file',
          type: 'orbit.file',
          properties: {'contentRef': 'Attachments/a b.png'},
        );
        final note = object(
          'note',
          body: '![Picture](<../../Attachments/a b.png>)',
        );
        final resolver = ObjectConnectionResolver();
        expect(
          resolver
              .resolve([note, file], pathFor: (_) => 'Notes/Sub/note.md')
              .single
              .target
              .id,
          'file',
        );
        expect(
          resolver.resolve([
            note,
            file,
            file.copyWith(title: 'Duplicate'),
          ], pathFor: (_) => 'Notes/Sub/note.md'),
          isEmpty,
        );
      },
    );
    test(
      'inline code, exact backtick runs and escaped syntax stay literal',
      () {
        final note = object(
          'note',
          body:
              r'`[x](orbit-object:a)`'
              '\n'
              r'`` ` [x](orbit-object:a) ``'
              '\n'
              r'\[x](orbit-object:a)'
              '\n'
              r'` unmatched [x](orbit-object:a)'
              '\n'
              r'[yes](orbit-object:a)',
        );
        final edges = ObjectConnectionResolver().resolve([note, object('a')]);
        expect(edges, hasLength(2));
        expect(edges.map((e) => e.offset), [
          note.body.indexOf('[x]', note.body.indexOf('unmatched')),
          note.body.indexOf('[yes]'),
        ]);
      },
    );
    test(
      'Canvas placements, resources and ownership use canonical identity',
      () {
        final target = object('target');
        final board = object(
          'board',
          type: 'orbit.canvas',
          data: {
            'elements': [
              {
                'id': 'placement',
                'type': 'card',
                'objectId': 'target',
                'referenceTarget': 'target#^intro',
              },
            ],
          },
        );
        final task = object(
          'task',
          type: 'orbit.task',
          properties: {
            'courseId': 'target',
            'gameplayResourceIds': ['board'],
            'resources': ['target'],
          },
        );
        final edges = ObjectConnectionResolver().resolve([target, board, task]);
        expect(edges.first.target.target, 'target#^intro');
        expect(edges.first.location.target, 'board#element=placement');
        expect(
          edges.where((e) => e.source.id == 'task').map((e) => e.target.id),
          containsAll(['board', 'target']),
        );
      },
    );
    test(
      'PDF passage, study provenance, research evidence and authored relations bridge back',
      () {
        final pdf = object('pdf', type: 'orbit.file');
        final passage = object(
          'quote',
          properties: {
            'pdfSource': {'objectId': 'pdf', 'page': 9},
          },
        );
        final relation = object(
          'decision',
          properties: {
            'researchVersion': 1,
            'researchKind': 'decision',
            'evidenceIds': ['quote'],
            'orbitConnections': {
              'version': 1,
              'items': [
                {
                  'id': 'rel',
                  'kind': 'references',
                  'target': 'pdf#page=3',
                  'note': 'Evidence',
                },
              ],
            },
          },
        );
        final edges = ObjectConnectionResolver().resolve([
          pdf,
          passage,
          relation,
        ]);
        expect(edges.any((e) => e.target.target == 'pdf#page=9'), isTrue);
        expect(
          edges.any(
            (e) => e.authoredId == 'rel' && e.target.target == 'pdf#page=3',
          ),
          isTrue,
        );
        expect(edges.any((e) => e.label == 'Supported by'), isTrue);
      },
    );
    test(
      'cache only reparses changed sources and invalidates aliases and attachment identities',
      () {
        final target = object(
          'target',
          properties: {
            'aliases': ['Alias'],
          },
        );
        final source = object('source', body: '[[Alias]]');
        final resolver = ObjectConnectionResolver();
        expect(resolver.resolve([source, target]).single.target.id, 'target');
        expect(resolver.parsedSources, 2);
        resolver.resolve([source, target]);
        expect(resolver.parsedSources, 2);
        resolver.resolve([source.copyWith(body: '[[Alias]] extra'), target]);
        expect(resolver.parsedSources, 3);
        expect(
          resolver.resolve([source, target.copyWith(properties: {})]),
          isEmpty,
        );
      },
    );
    test(
      'deleted targets retain explicit references but deleted sources disappear',
      () {
        final source = object(
          'source',
          body: const NoteObjectBlock('gone', 'Remembered').encode(),
        );
        final gone = object('gone').copyWith(deletedAt: DateTime.utc(2026));
        final resolver = ObjectConnectionResolver();
        expect(resolver.resolve([source, gone]).single.target.id, 'gone');
        expect(
          resolver.resolve([
            source.copyWith(deletedAt: DateTime.utc(2026)),
            gone,
          ]),
          isEmpty,
        );
      },
    );
  });

  group('Workspace bridges', () {
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
      container.read(workspaceProvider);
      c = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 100 && c.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    });
    tearDown(() async {
      store.failWrites = false;
      store.writeGate = null;
      c.editorDraftConflicts.clear();
      await c.flushAll();
      container.dispose();
    });
    test(
      'placing and embedding retain one source and survive repository reopen',
      () async {
        final source = (await c.create(
          'orbit.task',
          title: 'Build',
          properties: {
            'custom': {'future': true},
          },
        ))!;
        final note = (await c.create(
          'orbit.note',
          body: 'Original',
          properties: {'future': 42},
        ))!;
        final board = (await c.create(
          'orbit.canvas',
          data: {
            'version': 1,
            'elements': [],
            'future': {'keep': 1},
          },
        ))!;
        expect(
          await c.embedReferenceInNote(note, ObjectReference(source.id)),
          isTrue,
        );
        final placement = await c.placeReferenceOnCanvas(
          board,
          ObjectReference(source.id),
        );
        expect(placement, isNotNull);
        expect(
          c.backlinks(source.id).map((o) => o.id),
          containsAll([note.id, board.id]),
        );
        expect(c.outboundLinks(note.id).single.id, source.id);
        expect(c.find(note.id)!.properties['future'], 42);
        expect(c.find(board.id)!.data['future'], {'keep': 1});
        final reopened = WorkspaceRepository(
          store: store,
          index: MemoryObjectIndex(),
        );
        await reopened.initialize();
        final restored = reopened.objects.firstWhere((o) => o.id == board.id);
        expect(
          (restored.data['elements'] as List).single['objectId'],
          source.id,
        );
        expect(reopened.objects.where((o) => o.title == 'Build'), hasLength(1));
      },
    );
    test(
      'stale target snapshots and competing drafts refuse mutation',
      () async {
        final source = (await c.create('orbit.note'))!;
        final note = (await c.create('orbit.note', body: 'base'))!;
        c.edit(note.id, body: 'latest');
        expect(
          await c.embedReferenceInNote(note, ObjectReference(source.id)),
          isFalse,
        );
        c.publishEditorBody('other', note.id, 'base', 'retained');
        expect(
          await c.embedReferenceInNote(
            c.find(note.id)!,
            ObjectReference(source.id),
          ),
          isFalse,
        );
        expect(c.find(note.id)!.body, 'latest');
        final board = (await c.create('orbit.canvas'))!;
        c.edit(board.id, data: {...board.data, 'custom': true});
        expect(
          await c.placeReferenceOnCanvas(board, ObjectReference(source.id)),
          isNull,
        );
      },
    );
    test('failed save reports failure and retains recoverable draft', () async {
      final source = (await c.create('orbit.note'))!;
      final target = (await c.create('orbit.note'))!;
      store.failWrites = true;
      expect(
        await c.embedReferenceInNote(target, ObjectReference(source.id)),
        isFalse,
      );
      expect(c.dirty, contains(target.id));
      expect(c.find(target.id)!.body, contains(source.id));
      store.failWrites = false;
      await c.flush(target.id);
      expect(c.dirty, isNot(contains(target.id)));
    });
    test(
      'self references, unavailable sources and future scenes are rejected',
      () async {
        final note = (await c.create('orbit.note'))!;
        expect(
          await c.embedReferenceInNote(note, ObjectReference(note.id)),
          isFalse,
        );
        expect(
          await c.embedReferenceInNote(note, const ObjectReference('missing')),
          isFalse,
        );
        final board = (await c.create(
          'orbit.canvas',
          data: {'schemaVersion': 999, 'elements': []},
        ))!;
        expect(
          await c.placeReferenceOnCanvas(board, ObjectReference(note.id)),
          isNull,
        );
        expect(c.openReference(const ObjectReference('missing')), isFalse);
      },
    );
    test('open beside preserves page and source-location request', () async {
      final file = (await c.create(
        'orbit.file',
        properties: {'mimeType': 'application/pdf'},
      ))!;
      expect(
        c.openReference(
          ObjectReference(file.id, page: 12),
          secondary: true,
          offset: 8,
        ),
        isTrue,
      );
      expect(c.session.noteViews['pdf:secondary:${file.id}']!['page'], 12);
      expect(
        c.locationRequests[file.id]!.reference.target,
        '${file.id}#page=12',
      );
      expect(c.locationRequests[file.id]!.offset, 8);
    });
    test(
      'course context and creation use canonical ownership rather than display names',
      () async {
        final course = (await c.create(
          'orbit.note',
          title: 'Course',
          properties: {'isCourseOverview': true, 'course': 'A'},
        ))!;
        c.edit(
          course.id,
          properties: {...course.properties, 'courseId': course.id},
        );
        await c.flush(course.id);
        expect(objectProject(c.find(course.id)!), course.id);
        expect(await c.selectProject(course.id), isTrue);
        final task = (await c.create('orbit.task', title: 'Assignment'))!;
        expect(task.properties['courseId'], course.id);
        expect(task.properties['project'], isNull);
        expect(c.projectObjects(course.id).map((o) => o.id), contains(task.id));
        final explicit = (await c.create(
          'orbit.note',
          properties: {'courseId': 'other'},
        ))!;
        expect(explicit.properties['courseId'], 'other');
        expect(explicit.properties['course'], isNull);
      },
    );
    test(
      'authored relationships preserve unknown data and support review/undo',
      () async {
        final source = (await c.create(
          'orbit.note',
          properties: {
            'orbitConnections': {
              'version': 1,
              'future': 8,
              'items': [
                {'futureKind': true},
              ],
            },
          },
        ))!;
        final target = (await c.create('orbit.note', body: 'Original'))!;
        expect(
          await c.addProjectConnection(
            source.id,
            'inspired by',
            target.id,
            'Reason',
          ),
          isTrue,
        );
        final relation = ProjectConnection.read(
          c.find(source.id)!.properties['orbitConnections'],
        ).single;
        expect(c.connectionsTo(target.id).single.authoredId, relation.id);
        c.edit(target.id, body: 'Changed');
        expect(relation.warning(c.find(target.id)), contains('changed'));
        expect(await c.reviewProjectConnection(source.id, relation.id), isTrue);
        expect(await c.removeProjectConnection(source.id, relation.id), isTrue);
        expect(c.find(source.id)!.properties['orbitConnections']['future'], 8);
        expect(await c.undoProjectMutation(source.id), isTrue);
        expect(c.connectionsTo(target.id).single.label, 'inspired by');
      },
    );
    Future<void> mount(
      Widget child,
      WidgetTester tester, {
      Size size = const Size(900, 700),
      double scale = 1,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(body: child),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'two live task cards update together without duplicated task data',
      (tester) async {
        final task = (await tester.runAsync(
          () => c.create('orbit.task', title: 'Shared task'),
        ))!;
        await mount(
          ListView(
            children: [
              for (var i = 0; i < 2; i++)
                ObjectReferenceCard(
                  controller: c,
                  reference: ObjectReference(task.id),
                  interactive: true,
                ),
            ],
          ),
          tester,
        );
        await tester.tap(find.byType(Checkbox).first);
        await tester.pump();
        expect(
          tester
              .widgetList<Checkbox>(find.byType(Checkbox))
              .every((w) => w.value == true),
          isTrue,
        );
        await tester.runAsync(() async {
          c.edit(task.id, title: 'Renamed task');
          await c.flushAll();
        });
        await tester.pump();
        expect(find.text('Renamed task'), findsNWidgets(2));
        expect(c.objects.where((o) => o.id == task.id), hasLength(1));
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'missing precise sections show fallback without guessing nearby text',
      (tester) async {
        final source = (await tester.runAsync(
          () => c.create('orbit.note', body: 'Unrelated text'),
        ))!;
        await mount(
          ObjectReferenceCard(
            controller: c,
            reference: ObjectReference.parse('${source.id}#^missing'),
          ),
          tester,
        );
        expect(find.textContaining('missing or ambiguous'), findsOneWidget);
        expect(find.text('Unrelated text'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      testWidgets('picker and Connections fit $size at 200% text', (
        tester,
      ) async {
        final source = (await tester.runAsync(
          () => c.create(
            'orbit.note',
            title: 'Very long source title with clear context',
          ),
        ))!;
        await mount(
          Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showObjectReferencePicker(context, c),
                  child: const Text('Pick'),
                ),
                TextButton(
                  onPressed: () => showObjectConnections(context, c, source.id),
                  child: const Text('Inspect'),
                ),
              ],
            ),
          ),
          tester,
          size: size,
          scale: 2,
        );
        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Inspect'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close connections'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      });
    }
    testWidgets(
      'connection view shows precise uses and source-version rationale',
      (tester) async {
        final target = (await tester.runAsync(
          () => c.create('orbit.note', title: 'Source', body: 'Intro ^intro'),
        ))!;
        final owner = (await tester.runAsync(
          () => c.create('orbit.note', title: 'Owner', body: 'Before'),
        ))!;
        await tester.runAsync(
          () => c.embedReferenceInNote(
            owner,
            ObjectReference.parse('${target.id}#^intro'),
          ),
        );
        await tester.runAsync(
          () => c.addProjectConnection(
            owner.id,
            'references',
            target.id,
            'Design evidence',
          ),
        );
        await tester.runAsync(() async {
          c.edit(target.id, body: 'New intro ^intro');
          await c.flushAll();
        });
        await mount(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showObjectConnections(context, c, owner.id),
              child: const Text('Inspect'),
            ),
          ),
          tester,
        );
        await tester.tap(find.text('Inspect'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('References (2)'));
        await tester.pumpAndSettle();
        expect(find.text('Design evidence'), findsOneWidget);
        expect(find.textContaining('Source changed'), findsOneWidget);
        expect(find.text('Mark source reviewed'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'shared picker searches before pagination and chooses canonical duplicates with keyboard',
      (tester) async {
        final choices = await tester.runAsync(() async {
          final items = <UniversalObject>[];
          for (var i = 0; i < 44; i++) {
            items.add(
              (await c.create('orbit.note', title: 'A $i', open: false))!,
            );
          }
          items.add(
            (await c.create(
              'orbit.note',
              title: 'Z duplicate',
              body: 'First',
              open: false,
            ))!,
          );
          items.add(
            (await c.create(
              'orbit.note',
              title: 'Z duplicate',
              body: 'Second',
              open: false,
            ))!,
          );
          return items;
        });
        UniversalObject? picked;
        await mount(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showObjectReferencePicker(context, c);
              },
              child: const Text('Pick'),
            ),
          ),
          tester,
        );
        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Z duplicate');
        await tester.pumpAndSettle();
        expect(find.byType(ListTile), findsNWidgets(2));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        final duplicates =
            choices!.where((o) => o.title == 'Z duplicate').toList()
              ..sort((a, b) => a.id.compareTo(b.id));
        expect(picked!.id, duplicates.last.id);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'saved-view membership updates live and exact use opens the source offset',
      (tester) async {
        final records = await tester.runAsync(() async {
          final target = (await c.create('orbit.note', title: 'Material'))!;
          final note = (await c.create(
            'orbit.note',
            title: 'Owner',
            body: 'Before',
          ))!;
          await c.embedReferenceInNote(note, ObjectReference(target.id));
          final view = (await c.create(
            'orbit.view',
            title: 'Collection',
            properties: {
              'memberIds': [target.id],
            },
          ))!;
          return (target, note, view);
        });
        final (target, note, view) = records!;
        await mount(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showObjectConnections(context, c, target.id),
              child: const Text('Inspect'),
            ),
          ),
          tester,
        );
        await tester.tap(find.text('Inspect'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Saved views'));
        await tester.pumpAndSettle();
        expect(find.text('Collection'), findsOneWidget);
        await tester.runAsync(() async {
          c.edit(view.id, properties: {...view.properties, 'memberIds': []});
          await c.flushAll();
        });
        await tester.pumpAndSettle();
        expect(find.text('Included by saved view'), findsNothing);
        await tester.tap(find.text('Used in (1)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Go to exact use'));
        await tester.pumpAndSettle();
        expect(
          c.locationRequests[note.id]!.offset,
          c.find(note.id)!.body.indexOf('<!-- orbit:object'),
        );
        await tester.runAsync(() => c.flushAll());
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets('reference dialogs reject a changed Vault generation', (
      tester,
    ) async {
      final source = (await tester.runAsync(
        () => c.create('orbit.note', title: 'Old source'),
      ))!;
      await mount(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showObjectConnections(context, c, source.id),
            child: const Text('Inspect'),
          ),
        ),
        tester,
      );
      await tester.tap(find.text('Inspect'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => c.initialize());
      await tester.pumpAndSettle();
      expect(find.text('Vault changed'), findsOneWidget);
      expect(find.text('Connect objects'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
