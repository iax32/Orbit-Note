import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/domain/document_anchors.dart';
import 'package:orbit_note/domain/wiki_links.dart';
import 'package:orbit_note/domain/orbit_search.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/backlinks.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'support/memory_store.dart';

UniversalObject object(
  String id,
  String title, {
  String body = '',
  String type = 'orbit.note',
  Map<String, dynamic> data = const {},
  Map<String, dynamic> properties = const {},
}) => UniversalObject(
  id: id,
  workspaceId: 'vault',
  typeId: type,
  title: title,
  body: body,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  data: data,
  properties: properties,
);

void main() {
  test(
    'precise references preserve page, block, labels, elements and unknown anchors',
    () {
      for (final target in [
        'id#page=17',
        'id#^b-1',
        'id#element=e-1',
        'id#label=eq%3Apartition',
        'id#Equivalence%20Relations',
        'id#future=value',
      ]) {
        expect(ObjectReference.parse(target).target, target);
      }
      final target = const NoteLinkTarget(
        id: 'uuid',
        title: 'Relations',
        aliases: ['Sets'],
      );
      final source = '[[Sets#^block|Claim]] [[uuid#page=17|Paper]]';
      expect(
        wikiLinksToMarkdown(source, [target]),
        contains('orbit-object:uuid#^block'),
      );
      expect(
        wikiLinksToMarkdown(source, [target]),
        contains('orbit-object:uuid#page=17'),
      );
      expect(
        stabilizeWikiLinks(source, [target]),
        contains('[[uuid#page=17|Paper]]'),
      );
      expect(
        stabilizeWikiLinks(source, [target]),
        contains('[[uuid#^block|Claim]]'),
      );
    },
  );
  test(
    'lazy anchors distinguish duplicate paragraphs, edit and deletion safely',
    () {
      const source = 'A partition.\r\n\r\nA partition.\r\n';
      final first = anchorDocumentBlock(source, 'n', 1, 'first');
      final second = anchorDocumentBlock(
        first.source,
        'n',
        first.source.lastIndexOf('A partition'),
        'second',
      );
      expect(
        resolveDocumentFragment(second.source, first.reference)?.text,
        contains('^first'),
      );
      expect(
        resolveDocumentFragment(second.source, second.reference)?.text,
        contains('^second'),
      );
      final changed = second.source.replaceFirst(
        'A partition.',
        'A revised claim.',
      );
      expect(
        resolveDocumentFragment(changed, first.reference)?.text,
        contains('revised'),
      );
      expect(
        resolveDocumentFragment('A partition. ^second\n', first.reference),
        isNull,
      );
      expect(
        anchorDocumentBlock(second.source, 'n', 1, 'unused').source,
        second.source,
      );
      final rich = MarkdownDocument.parse(second.source);
      expect(rich.source, second.source);
      expect(
        rich.blocks
            .where((b) => b.kind == MarkdownBlockKind.text)
            .first
            .content,
        'A partition.',
      );
      expect(rich.blocks.first.replaceContent('Changed'), contains('^first'));
    },
  );
  test('code and ambiguous anchors are not silently retargeted', () {
    const code = '```markdown\nFake ^x\n```\n\n    example ^x\n';
    expect(
      resolveDocumentFragment(
        code,
        const ObjectReference('n', anchorType: 'block', anchorId: 'x'),
      ),
      isNull,
    );
    expect(() => anchorDocumentBlock(code, 'n', 15, 'new'), throwsStateError);
    expect(
      resolveDocumentFragment(
        'One ^x\n\nTwo ^x\n',
        const ObjectReference('n', anchorType: 'block', anchorId: 'x'),
      ),
      isNull,
    );
    expect(
      resolveDocumentFragment(
        '# Same\n\n# Same\n',
        const ObjectReference('n', anchorType: 'heading', anchorId: 'Same'),
      ),
      isNull,
    );
  });
  test(
    'shared search ranks names and deep-opens Unicode, canvas, LaTeX and tasks',
    () {
      final items = [
        object('exact', 'partition'),
        object('prefix', 'partition exercises'),
        object(
          'alias',
          'Sets',
          properties: {
            'aliases': ['partition'],
          },
        ),
        object(
          'note',
          'Notes',
          body: '# Partitions\n\nA partition of Ω. ^claim\n',
        ),
        object(
          'latex',
          'Relations.tex',
          body:
              r'\section{Sets}'
              '\n\n'
              r'$A \subseteq B$ \label{eq:set}',
          properties: {'documentFormat': 'latex'},
        ),
        object('task', 'Study partition', type: 'orbit.task'),
        object(
          'canvas',
          'Exercise board',
          type: 'orbit.canvas',
          data: {
            'schemaVersion': 1,
            'elements': [
              {
                'id': 'sticky',
                'type': 'sticky',
                'text': 'partition exercise',
                'x': 0,
                'y': 0,
                'width': 200,
                'height': 100,
              },
              {
                'id': 'card',
                'type': 'card',
                'objectId': 'note',
                'x': 300,
                'y': 0,
                'width': 200,
                'height': 100,
              },
            ],
          },
        ),
      ];
      final lookup = {for (final o in items) o.id: o};
      final results = const OrbitSearchCoordinator().project(
        items,
        'partition',
        objects: lookup,
      );
      expect(results.first.object.id, 'exact');
      expect(
        results.first.score,
        lessThan(results.firstWhere((r) => r.object.id == 'prefix').score),
      );
      expect(
        results
            .firstWhere(
              (r) => r.object.id == 'note' && r.matchKind == 'Paragraph',
            )
            .location
            .target,
        'note#^claim',
      );
      expect(
        results
            .where((r) => r.location.anchorType == 'element')
            .map((r) => r.location.anchorId),
        containsAll(['sticky', 'card']),
      );
      expect(results.any((r) => r.object.typeId == 'orbit.task'), isTrue);
      expect(
        const OrbitSearchCoordinator()
            .project(items, 'subseteq')
            .single
            .location
            .target,
        'latex#label=eq%3Aset',
      );
      expect(
        const OrbitSearchCoordinator().project(items, 'Ω').single.sourceOffset,
        isNotNull,
      );
      expect(
        const OrbitSearchCoordinator()
            .project(items.reversed, 'partition', objects: lookup)
            .map((r) => '${r.location.target}:${r.sourceOffset}'),
        results.map((r) => '${r.location.target}:${r.sourceOffset}'),
      );
    },
  );
  test('backlinks retain exact targets and source context', () {
    final target = object('n', 'Claim', body: 'Canonical ^c');
    final source = object('s', 'Proof', body: 'This uses [[n#^c|the claim]].');
    final mentions = findLinkedMentions(
      targetId: 'n',
      objects: [target, source],
      targets: [const NoteLinkTarget(id: 'n', title: 'Claim')],
    );
    expect(mentions.single.targetLocation?.target, 'n#^c');
    expect(mentions.single.sourceOffset, source.body.indexOf('[['));
  });

  test(
    'live placements share canonical source, survive reopen and placement deletion',
    () async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      final c = container.read(workspaceProvider.notifier);
      while (c.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      addTearDown(() async {
        await c.flushAll();
        container.dispose();
      });
      final note = (await c.create(
        'orbit.note',
        title: 'Claim',
        body: 'A partition.\n',
      ))!;
      final board = (await c.create('orbit.canvas', title: 'Proof'))!;
      final before = c.activeObjects.length;
      final first = await c.placeNoteBlock(note.id, 1, board.id);
      final second = await c.placeNoteBlock(note.id, 1, board.id);
      expect(c.activeObjects.length, before);
      expect(first.anchorId, isNot(second.anchorId));
      final elements = c.find(board.id)!.data['elements'] as List;
      expect(elements.length, 2);
      expect(elements[0]['referenceTarget'], elements[1]['referenceTarget']);
      expect(elements[0].containsKey('text'), isFalse);
      c.edit(
        note.id,
        body:
            '${c.find(note.id)!.body.replaceFirst('A partition.', 'A revised partition.')}\nElsewhere only source.\n',
      );
      await c.flush(note.id);
      await c.initialize();
      final savedBoard = c.find(board.id)!;
      final savedNote = c.find(note.id)!;
      final target = ObjectReference.parse(
        (savedBoard.data['elements'] as List)[0]['referenceTarget'] as String,
      );
      expect(
        resolveDocumentFragment(savedNote.body, target)?.text,
        contains('revised'),
      );
      final found = await c.searchLocations('revised');
      expect(
        (await c.searchLocations(
          'Elsewhere',
        )).any((r) => r.object.id == board.id),
        isFalse,
      );
      expect(
        found.any(
          (r) => r.object.id == board.id && r.location.anchorType == 'element',
        ),
        isTrue,
      );
      c.edit(
        board.id,
        data: {
          ...savedBoard.data,
          'elements': [(savedBoard.data['elements'] as List)[1]],
        },
      );
      await c.flush(board.id);
      expect(c.find(note.id)?.body, savedNote.body);
      c.edit(note.id, body: 'Removed block.');
      await c.flush(note.id);
      expect(resolveDocumentFragment(c.find(note.id)!.body, target), isNull);
    },
  );
}
