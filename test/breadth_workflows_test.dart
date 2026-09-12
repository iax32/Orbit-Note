import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/calendar_event.dart';
import 'package:orbit_note/features/workspace/note_folder_explorer.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

class _TestStore extends NativeWorkspaceStore {
  _TestStore(this.root);
  final String root;
  @override
  Future<void> initialize({String? path}) => super.initialize(path: root);
}

void main() {
  testWidgets(
    'folder drop preserves identity and task date views use durable objects',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('orbit-breadth-ui-'),
      ))!;
      late WorkspaceRepository repo;
      late ProviderContainer container;
      late WorkspaceController c;
      await tester.runAsync(() async {
        repo = WorkspaceRepository(
          store: _TestStore(root.path),
          index: MemoryObjectIndex(),
        );
        container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        container.read(workspaceProvider);
        c = container.read(workspaceProvider.notifier);
        for (var i = 0; c.loading && i < 500; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(c.loading, isFalse);
        await c.organize(() => repo.createFolder('Notes/Target'));
        await c.create('orbit.note', title: 'Move me');
      });
      final note = c.ofType('orbit.note').single;
      Future<void> show(Widget Function() child) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  ref.watch(workspaceProvider);
                  return Scaffold(body: child());
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(
        () => NoteFolderExplorer(controller: c, notes: c.ofType('orbit.note')),
      );
      final from =
          tester.getTopLeft(find.byKey(ValueKey('folder-note:${note.id}'))) +
          const Offset(80, 20);
      final to =
          tester.getTopLeft(find.byKey(const ValueKey('folder:Notes/Target'))) +
          const Offset(80, 20);
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').contains('${note.id}.md'),
        ),
        findsOneWidget,
      );
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      for (
        var i = 0;
        i < 500 &&
            (c.loading ||
                !(repo.objectPath(note.id)?.startsWith('Notes/Target/') ??
                    false));
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(
        repo.objectPath(note.id),
        startsWith('Notes/Target/'),
        reason: c.error,
      );
      await tester.runAsync(() async {
        final task = (await c.create('orbit.task', title: 'Today task'))!;
        c.edit(task.id, properties: {'dueDate': calendarDate(DateTime.now())});
        await c.flushAll();
      });
      await show(() => TasksView(controller: c));
      await tester.tap(find.text('Today').first);
      await tester.pumpAndSettle();
      expect(find.text('Today task'), findsOneWidget);
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();
      expect(find.text('Today task'), findsNothing);
      await tester.runAsync(() async {
        await repo.refresh();
      });
      expect(repo.objectPath(note.id), startsWith('Notes/Target/'));
      expect(
        repo.objects
            .where((o) => o.typeId == 'orbit.task')
            .single
            .properties['dueDate'],
        calendarDate(DateTime.now()),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        container.dispose();
        await repo.close();
        await root.delete(recursive: true);
      });
    },
  );
}
