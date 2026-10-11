import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/backlinks.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/wiki_links.dart';
import 'package:orbit_note/features/workspace/local_context_graph.dart';
import 'package:orbit_note/features/workspace/object_inspector.dart';
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
    bool isDeleted = false,
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
      deletedAt: isDeleted ? now : null,
    );
  }

  group('Backlinks Domain Engine', () {
    test('extractContextSnippet extracts surrounding sentence with ellipsis', () {
      const text =
          'First sentence. This is the second sentence containing the target keyword inside. Third sentence follows.';
      final start = text.indexOf('target keyword');
      final end = start + 'target keyword'.length;

      final snippet = extractContextSnippet(text, start, end, maxRadius: 60);
      expect(snippet, contains('target keyword'));
      expect(snippet, contains('second sentence'));
    });

    test(
      'findLinkedMentions finds wikilinks, canvas cards, and task contexts',
      () {
        final target = makeObject(
          id: 'target-1',
          typeId: 'orbit.note',
          title: 'Project Apollo',
        );

        final noteSource = makeObject(
          id: 'note-src',
          typeId: 'orbit.note',
          title: 'Architecture Overview',
          body:
              'We are aligning this work with [[target-1|Apollo Project]] milestone.',
        );

        final canvasSource = makeObject(
          id: 'canvas-src',
          typeId: 'orbit.canvas',
          title: 'Mission Board',
          data: {
            'elements': [
              {'targetId': 'target-1', 'title': 'Apollo Epic'},
            ],
          },
        );

        final taskSource = makeObject(
          id: 'task-src',
          typeId: 'orbit.task',
          title: 'Verify rocket telemetry',
          properties: {'contextId': 'target-1'},
        );

        final eventSource = makeObject(
          id: 'event-src',
          typeId: 'orbit.event',
          title: 'Launch Review',
          properties: {'contextId': 'target-1'},
        );

        final objects = [
          target,
          noteSource,
          canvasSource,
          taskSource,
          eventSource,
        ];
        final linkTargets = [
          NoteLinkTarget(id: 'target-1', title: 'Project Apollo'),
        ];

        final linked = findLinkedMentions(
          targetId: 'target-1',
          objects: objects,
          targets: linkTargets,
        );

        expect(linked.length, 4);

        final wikilinkRef = linked.firstWhere(
          (m) => m.type == LinkedMentionType.wikilink,
        );
        expect(wikilinkRef.source.id, 'note-src');
        expect(wikilinkRef.label, 'Apollo Project');
        expect(wikilinkRef.snippet, contains('aligning this work'));

        final canvasRef = linked.firstWhere(
          (m) => m.type == LinkedMentionType.canvasElement,
        );
        expect(canvasRef.source.id, 'canvas-src');
        expect(canvasRef.snippet, contains('Apollo Epic'));

        final taskRef = linked.firstWhere(
          (m) => m.type == LinkedMentionType.taskContext,
        );
        expect(taskRef.source.id, 'task-src');

        final eventRef = linked.firstWhere(
          (m) => m.type == LinkedMentionType.eventContext,
        );
        expect(eventRef.source.id, 'event-src');
      },
    );

    test('findUnlinkedMentions finds title and alias occurrences safely', () {
      final target = makeObject(
        id: 'target-1',
        typeId: 'orbit.note',
        title: 'Quantum Computing',
        properties: {
          'aliases': ['QC', 'Quantum'],
        },
      );

      final note = makeObject(
        id: 'source-1',
        typeId: 'orbit.note',
        title: 'Physics Research',
        body: '''
Here is unlinked quantum computing text in prose.
Also another mention of QC in lab reports.
Existing link: [[target-1|Quantum Computing]] should NOT be matched.
Code block:
```
var quantum computing = true;
```
Inline code: `quantum computing` should not match.
Markdown link: [quantum computing](https://example.com) should not match.
Sub-word non-match: PreQuantumComputing should not match.
''',
      );

      final objects = [target, note];
      final linkTargets = [
        NoteLinkTarget(
          id: 'target-1',
          title: 'Quantum Computing',
          aliases: ['QC', 'Quantum'],
        ),
      ];

      final unlinked = findUnlinkedMentions(
        targetId: 'target-1',
        objects: objects,
        targets: linkTargets,
      );

      // Should match "quantum computing" in first sentence and "QC" in second sentence
      expect(
        unlinked.any((m) => m.matchedText.toLowerCase() == 'quantum computing'),
        isTrue,
      );
      expect(unlinked.any((m) => m.matchedText == 'QC'), isTrue);

      // None of the matches should be inside code or existing links
      for (final m in unlinked) {
        expect(
          m.source.body.substring(m.startIndex, m.endIndex),
          m.matchedText,
        );
        expect(m.matchedText, isNot('PreQuantumComputing'));
      }
    });

    test(
      'linkMentionInMarkdown replaces unlinked mention with canonical wikilink',
      () {
        const original =
            'Please inspect Quantum Computing before next meeting.';
        final mention = UnlinkedMention(
          source: makeObject(
            id: 'src-1',
            typeId: 'orbit.note',
            title: 'Source',
            body: original,
          ),
          targetId: 'target-1',
          targetTitle: 'Quantum Computing',
          matchedText: 'Quantum Computing',
          snippet: '...',
          startIndex: 15,
          endIndex: 32,
        );

        final linked = linkMentionInMarkdown(original, mention, 'target-1');
        expect(
          linked,
          'Please inspect [[target-1|Quantum Computing]] before next meeting.',
        );
      },
    );

    test(
      'linkMentionInMarkdown returns original body when matchedText is empty',
      () {
        const original = 'Some note content without corruption';
        final emptyMention = UnlinkedMention(
          source: makeObject(
            id: 'src-1',
            typeId: 'orbit.note',
            title: 'Source',
            body: original,
          ),
          targetId: 'target-1',
          targetTitle: 'Target',
          matchedText: '',
          snippet: '...',
          startIndex: 0,
          endIndex: 0,
        );

        final result = linkMentionInMarkdown(
          original,
          emptyMention,
          'target-1',
        );
        expect(result, equals(original));
      },
    );
  });

  group('WorkspaceController Backlinks and 1-Click Linking', () {
    test('linkUnlinkedMention mutates source body and updates state', () async {
      final store = MemoryStore();
      final index = MemoryObjectIndex();
      final repo = WorkspaceRepository(store: store, index: index);
      final controller = WorkspaceController();
      controller.repository = repo;

      final target = makeObject(
        id: 'target-1',
        typeId: 'orbit.note',
        title: 'Neural Networks',
      );
      final source = makeObject(
        id: 'source-1',
        typeId: 'orbit.note',
        title: 'Deep Learning',
        body: 'We study neural networks extensively.',
      );

      controller.objects = [target, source];
      controller.session = SessionState(activeId: 'target-1');

      final unlinked = controller.unlinkedMentions('target-1');
      expect(unlinked, isNotEmpty);
      expect(unlinked.first.matchedText, 'neural networks');

      await controller.linkUnlinkedMention(unlinked.first, 'target-1');

      final updatedSource = controller.find('source-1');
      expect(
        updatedSource?.body,
        'We study [[target-1|neural networks]] extensively.',
      );

      // Now linkedMentions should find the new wikilink
      final linked = controller.linkedMentions('target-1');
      expect(linked.length, 1);
      expect(linked.first.source.id, 'source-1');
    });
  });

  group('LocalContextGraph & ObjectInspector UI Integration', () {
    testWidgets('LocalContextGraph builds and renders nodes and edges', (
      tester,
    ) async {
      final store = MemoryStore();
      final index = MemoryObjectIndex();
      final repo = WorkspaceRepository(store: store, index: index);
      final controller = WorkspaceController();
      controller.repository = repo;

      final target = makeObject(
        id: 'target-1',
        typeId: 'orbit.note',
        title: 'Root Node',
      );
      final connected = makeObject(
        id: 'connected-1',
        typeId: 'orbit.note',
        title: 'Child Node',
        body: 'Links to [[target-1]]',
      );

      controller.objects = [target, connected];

      String? tappedId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalContextGraph(
              controller: controller,
              focusId: 'target-1',
              height: 300,
              onOpenObject: (id) => tappedId = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LocalContextGraph), findsOneWidget);
      expect(find.text('2 nodes · 1 link'), findsOneWidget);
      expect(find.text('1 Hop'), findsOneWidget);
      expect(find.text('2 Hops'), findsOneWidget);
      expect(tappedId, isNull);
    });

    testWidgets(
      'ObjectInspector displays Linked, Unlinked tabs and 1-Click link button',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final store = MemoryStore();
        final index = MemoryObjectIndex();
        final repo = WorkspaceRepository(store: store, index: index);

        final target = makeObject(
          id: 'target-1',
          typeId: 'orbit.note',
          title: 'Target Document',
        );
        final linkedSource = makeObject(
          id: 'source-linked',
          typeId: 'orbit.note',
          title: 'Linked Source Note',
          body: 'Points directly to [[target-1|Target Document]] here.',
        );
        final unlinkedSource = makeObject(
          id: 'source-unlinked',
          typeId: 'orbit.note',
          title: 'Unlinked Source Note',
          body: 'Mentions Target Document casually in a paragraph.',
        );

        await repo.initialize();
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();

        c.objects = [target, linkedSource, unlinkedSource];
        c.hasWorkspace = true;
        c.loading = false;
        c.session.activeId = 'target-1';

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 350,
                  height: 1200,
                  child: ObjectInspector(controller: c, onRename: (_) {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check relations section header and tabs
        expect(find.text('RELATIONS & REFERENCES'), findsOneWidget);
        expect(find.text('Linked'), findsOneWidget);
        expect(find.text('Unlinked'), findsOneWidget);

        // Tab 0 (Linked) is active by default: should show Linked Source Note
        expect(find.text('Linked Source Note'), findsOneWidget);

        // Switch to Tab 1 (Unlinked)
        await tester.tap(find.text('Unlinked'));
        await tester.pumpAndSettle();

        // Unlinked Source Note should be visible with + Link button
        expect(find.text('Unlinked Source Note'), findsOneWidget);
        final linkBtn = find.byKey(
          const ValueKey('orbit-link-mention-source-unlinked-9'),
        );
        expect(linkBtn, findsOneWidget);

        // Tap Link button to convert to wikilink
        await tester.tap(linkBtn);
        await tester.pumpAndSettle();

        // Verify the source note was mutated to contain wikilink
        final updated = c.find('source-unlinked');
        expect(
          updated?.body,
          'Mentions [[target-1|Target Document]] casually in a paragraph.',
        );
      },
    );
  });
}
