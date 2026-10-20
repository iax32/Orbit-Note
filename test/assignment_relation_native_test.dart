import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/project_context.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';

class AssignmentNativeStore extends NativeWorkspaceStore {
  AssignmentNativeStore(this.root);
  final String root;
  @override
  Future<void> initialize({String? path}) =>
      super.initialize(path: path ?? root);
}

void main() {
  test(
    'tags, assignment, precise connections and Undo survive an isolated native reopen',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-assignment-quality-',
      );
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(
            WorkspaceRepository(
              store: AssignmentNativeStore(root.path),
              index: MemoryObjectIndex(),
            ),
          ),
        ],
      );
      container.read(workspaceProvider);
      final c = container.read(workspaceProvider.notifier);
      try {
        while (c.loading) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        c.pausePdfIndex(true);
        c.cancelAllTimers();
        final project = (await c.create(
          'orbit.note',
          title: 'Project',
          properties: {'isCreativeBrief': true},
        ))!;
        final source = (await c.create(
          'orbit.note',
          title: 'Design',
          body: '# Design\r\n\r\nExact source.\r\n',
          properties: {
            'future': {
              'version': 91,
              'keep': ['original'],
            },
          },
        ))!;
        await c.addTagToObject(source.id, '#Research');
        expect(await c.assignObjectProject(source.id, project.id), isTrue);
        expect(
          await c.addProjectConnection(
            source.id,
            'supports',
            '${project.id}#heading',
            'Evidence',
          ),
          isTrue,
        );
        expect(await c.undoProjectMutation(source.id), isTrue);
        expect(
          c.find(source.id)!.properties.containsKey('orbitConnections'),
          isFalse,
        );
        expect(
          await c.addProjectConnection(
            source.id,
            'supports',
            '${project.id}#heading',
            'Evidence',
          ),
          isTrue,
        );
        final count = c.activeObjects.length;
        expect(await c.flushAll(), isTrue);
        await c.initialize();
        expect(c.activeObjects, hasLength(count));
        final restored = c.find(source.id)!;
        expect(restored.body, source.body);
        expect(restored.properties['future'], {
          'version': 91,
          'keep': ['original'],
        });
        expect(restored.properties['tags'], ['Research']);
        expect(restored.properties['project'], project.id);
        final connections = ProjectConnection.read(
          restored.properties['orbitConnections'],
        );
        expect(connections, hasLength(1));
        expect(connections.single.target.target, '${project.id}#heading');
      } finally {
        c.cancelAllTimers();
        container.dispose();
        // Close this test's store before deleting only the explicitly allocated root.
        await c.repository.close();
        final resolved = root.absolute.path;
        expect(resolved, startsWith(Directory.systemTemp.absolute.path));
        await root.delete(recursive: true);
      }
    },
  );
}
