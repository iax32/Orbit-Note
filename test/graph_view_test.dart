import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/graph_view.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  final now = DateTime.now();

  UniversalObject makeObject({
    required String id,
    required String typeId,
    required String title,
    String body = '',
    Map<String, dynamic> properties = const {},
    Map<String, dynamic> data = const {},
  }) {
    return UniversalObject(
      id: id,
      workspaceId: 'ws-1',
      typeId: typeId,
      title: title,
      body: body,
      properties: properties,
      data: data,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('GraphData Model & Link Extraction', () {
    test(
      'uses stable IDs, aliases and actual event context without guessing duplicates',
      () {
        final graph = GraphData.build(
          objects: [
            makeObject(
              id: 'a',
              typeId: 'orbit.note',
              title: 'Renamed',
              properties: {
                'aliases': ['Old'],
              },
            ),
            makeObject(id: 'b', typeId: 'orbit.note', title: 'Duplicate'),
            makeObject(id: 'c', typeId: 'orbit.note', title: 'Duplicate'),
            makeObject(
              id: 'source',
              typeId: 'orbit.note',
              title: 'Source',
              body: '[[a]] [[Old]] [[Duplicate]]',
            ),
            makeObject(
              id: 'event',
              typeId: 'orbit.event',
              title: 'Meeting',
              properties: {'contextId': 'a'},
            ),
          ],
        );
        expect(graph.edges, hasLength(2));
        expect(graph.edges.every((e) => e.targetId == 'a'), isTrue);
      },
    );
    test('extracts nodes and wiki link edges', () {
      final objects = [
        makeObject(
          id: 'note-1',
          typeId: 'orbit.note',
          title: 'Algorithms',
          body: 'Check [[Data Structures]] for fundamentals.',
        ),
        makeObject(
          id: 'note-2',
          typeId: 'orbit.note',
          title: 'Data Structures',
          body: 'Core foundations.',
        ),
        makeObject(
          id: 'task-1',
          typeId: 'orbit.task',
          title: 'Implement Binary Search',
          properties: {'context': 'note-1'},
        ),
      ];

      final graph = GraphData.build(objects: objects);
      expect(graph.nodes.length, 3);
      expect(graph.edges.length, 2);

      final algo = graph.nodes.firstWhere((n) => n.id == 'note-1');
      expect(algo.connectionCount, 2); // connected to note-2 and task-1
    });

    test('respects link bindings in frontmatter/properties', () {
      final objects = [
        makeObject(
          id: 'note-a',
          typeId: 'orbit.note',
          title: 'Graph Theory',
          body: 'Look at [[Eulerian Path]].',
          properties: {
            'orbitLinkBindings': {'Eulerian Path': 'note-b'},
          },
        ),
        makeObject(
          id: 'note-b',
          typeId: 'orbit.note',
          title: 'Eulerian Path Analysis',
        ),
      ];

      final graph = GraphData.build(objects: objects);
      expect(graph.nodes.length, 2);
      expect(graph.edges.length, 1);
      expect(graph.edges.first.sourceId, 'note-a');
      expect(graph.edges.first.targetId, 'note-b');
    });

    test('filters nodes by query and type', () {
      final objects = [
        makeObject(id: 'note-1', typeId: 'orbit.note', title: 'Mathematics'),
        makeObject(id: 'note-2', typeId: 'orbit.note', title: 'Physics'),
        makeObject(id: 'task-1', typeId: 'orbit.task', title: 'Homework'),
      ];

      final filteredTypes = GraphData.build(
        objects: objects,
        typeFilters: {'orbit.note'},
      );
      expect(filteredTypes.nodes.length, 2);
      expect(filteredTypes.nodes.every((n) => n.type == 'orbit.note'), isTrue);

      final searchGraph = GraphData.build(objects: objects, query: 'math');
      final mathNode = searchGraph.nodes.firstWhere((n) => n.id == 'note-1');
      final physNode = searchGraph.nodes.firstWhere((n) => n.id == 'note-2');
      expect(mathNode.matchesQuery, isTrue);
      expect(physNode.matchesQuery, isFalse);
    });

    test('local focus mode isolates connected neighborhood', () {
      final objects = [
        makeObject(
          id: 'note-1',
          typeId: 'orbit.note',
          title: 'Root',
          body: '[[Child]]',
        ),
        makeObject(
          id: 'note-2',
          typeId: 'orbit.note',
          title: 'Child',
          body: '[[Grandchild]]',
        ),
        makeObject(id: 'note-3', typeId: 'orbit.note', title: 'Grandchild'),
        makeObject(id: 'note-isolated', typeId: 'orbit.note', title: 'Island'),
      ];

      final localGraph = GraphData.build(
        objects: objects,
        focusId: 'note-1',
        maxHops: 1,
      );

      final ids = localGraph.nodes.map((n) => n.id).toSet();
      expect(ids.contains('note-1'), isTrue);
      expect(ids.contains('note-2'), isTrue);
      expect(ids.contains('note-isolated'), isFalse);
    });
  });

  group('GraphView Widget', () {
    testWidgets('renders graph view controls and canvas', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize(path: 'test');
      await repo.create(typeId: 'orbit.note', title: 'Cosmology');
      await repo.create(typeId: 'orbit.note', title: 'General Relativity');

      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(workspaceProvider);
      final controller = container.read(workspaceProvider.notifier);

      await tester.runAsync(() async {
        for (var i = 0; i < 100 && controller.loading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: GraphView(controller: controller)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Knowledge Graph'), findsOneWidget);
      expect(find.text('Global'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('2 nodes · 0 links'), findsOneWidget);

      // Switch to Local mode
      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();

      expect(find.text('Local'), findsOneWidget);
    });
  });
}
