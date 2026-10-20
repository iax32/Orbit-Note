import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  late MemoryStore store;
  late ProviderContainer container;
  late WorkspaceController c;
  setUp(() async {
    store = MemoryStore();
    final repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    while (c.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    c.pausePdfIndex(true);
    c.cancelAllTimers();
  });
  tearDown(() {
    c.cancelAllTimers();
    container.dispose();
  });

  test('a stale mention never links a different repeated occurrence', () async {
    final target = (await c.create('orbit.note', title: 'Orbit'))!;
    final source = (await c.create(
      'orbit.note',
      body: 'First Orbit. Later Orbit.',
    ))!;
    final mention = c.unlinkedMentions(target.id).first;
    c.edit(source.id, body: 'First changed. Later Orbit.');
    await c.linkUnlinkedMention(mention, target.id);
    expect(c.find(source.id)!.body, 'First changed. Later Orbit.');
  });

  test('a trashed destination cannot receive a mention link', () async {
    final target = (await c.create('orbit.note', title: 'Orbit'))!;
    final source = (await c.create('orbit.note', body: 'Orbit is useful.'))!;
    final mention = c.unlinkedMentions(target.id).first;
    await c.trash(target.id);
    await c.linkUnlinkedMention(mention, target.id);
    expect(c.find(source.id)!.body, source.body);
  });

  test(
    'tag membership normalizes hash and whitespace before duplicate checks',
    () async {
      final note = (await c.create(
        'orbit.note',
        properties: {
          'tags': [' #Draft ', 'ideas'],
          'future': {'keep': 1},
        },
      ))!;
      await c.addTagToObject(note.id, '#draft');
      expect(c.find(note.id)!.properties['tags'], [' #Draft ', 'ideas']);
      await c.removeTagFromObject(note.id, ' DRAFT ');
      expect(c.find(note.id)!.properties['tags'], ['ideas']);
      expect(c.find(note.id)!.properties['future'], {'keep': 1});
    },
  );

  test('tag commands cannot edit Trash', () async {
    final note = (await c.create(
      'orbit.note',
      properties: {
        'tags': ['keep'],
      },
    ))!;
    await c.trash(note.id);
    await c.addTagToObject(note.id, 'new');
    await c.removeTagFromObject(note.id, 'keep');
    expect(c.find(note.id)!.properties['tags'], ['keep']);
  });

  test(
    'tag edits preserve unknown entries and do not replace future formats',
    () async {
      final note = (await c.create(
        'orbit.note',
        properties: {
          'tags': [
            'draft',
            {
              'future': ['value', 2],
            },
            7,
          ],
        },
      ))!;
      await c.addTagToObject(note.id, 'ideas');
      await c.removeTagFromObject(note.id, 'draft');
      expect(c.find(note.id)!.properties['tags'], [
        {
          'future': ['value', 2],
        },
        7,
        'ideas',
      ]);
      c.updateProperty(note.id, 'tags', {
        'version': 99,
        'items': ['keep'],
      });
      await c.addTagToObject(note.id, 'new');
      await c.removeTagFromObject(note.id, 'keep');
      expect(c.find(note.id)!.properties['tags'], {
        'version': 99,
        'items': ['keep'],
      });
    },
  );

  test(
    'failed mention save reports failure while retaining a retryable draft',
    () async {
      final target = (await c.create('orbit.note', title: 'Orbit'))!;
      final source = (await c.create('orbit.note', body: 'Orbit is useful.'))!;
      final mention = c.unlinkedMentions(target.id).first;
      store.failWrites = true;
      expect(await c.linkUnlinkedMention(mention, target.id), isFalse);
      expect(c.dirty, contains(source.id));
      expect(c.find(source.id)!.body, '[[${target.id}|Orbit]] is useful.');
      store.failWrites = false;
      await c.retry(source.id);
      expect(c.dirty, isNot(contains(source.id)));
      await c.initialize();
      expect(c.find(source.id)!.body, '[[${target.id}|Orbit]] is useful.');
    },
  );

  test(
    'reopening retires retained tag, assignment and relation commands',
    () async {
      final project = (await c.create(
        'orbit.note',
        properties: {'isCreativeBrief': true},
      ))!;
      final source = (await c.create('orbit.note'))!;
      final generation = c.workspaceGeneration;
      await c.initialize();
      await c.addTagToObject(
        source.id,
        'retired',
        expectedGeneration: generation,
      );
      expect(c.find(source.id)!.properties['tags'], isNull);
      expect(
        await c.assignObjectProject(
          source.id,
          project.id,
          expectedGeneration: generation,
        ),
        isFalse,
      );
      expect(
        await c.addProjectConnection(
          source.id,
          'supports',
          project.id,
          '',
          expectedGeneration: generation,
        ),
        isFalse,
      );
      expect(c.find(source.id)!.properties['orbitConnections'], isNull);
    },
  );

  test(
    'assignment rejects changed membership but preserves newer prose and unknown metadata',
    () async {
      final project = (await c.create(
        'orbit.note',
        properties: {'isCreativeBrief': true},
      ))!;
      final source = (await c.create(
        'orbit.note',
        properties: {'project': 'original'},
      ))!;
      c.edit(
        source.id,
        body: 'New prose',
        properties: {
          ...source.properties,
          'project': 'changed',
          'future': {'keep': 2},
        },
      );
      expect(
        await c.assignObjectProject(source.id, project.id, expected: source),
        isFalse,
      );
      expect(c.find(source.id)!.properties['project'], 'changed');
      expect(
        await c.assignObjectProject(
          source.id,
          project.id,
          expected: c.find(source.id),
        ),
        isTrue,
      );
      expect(c.find(source.id)!.body, 'New prose');
      expect(c.find(source.id)!.properties['future'], {'keep': 2});
      expect(await c.undoProjectMutation(source.id), isTrue);
      expect(c.find(source.id)!.properties['project'], 'changed');
    },
  );

  test(
    'failed assignment retains metadata and succeeds after normal save retry',
    () async {
      final project = (await c.create(
        'orbit.note',
        properties: {'isCreativeBrief': true},
      ))!;
      final source = (await c.create('orbit.note', properties: {'future': 7}))!;
      store.failWrites = true;
      expect(await c.assignObjectProject(source.id, project.id), isFalse);
      expect(c.dirty, contains(source.id));
      expect(c.find(source.id)!.properties['future'], 7);
      store.failWrites = false;
      await c.retry(source.id);
      await c.initialize();
      expect(c.find(source.id)!.properties['project'], project.id);
      expect(c.find(source.id)!.properties['future'], 7);
    },
  );
}
