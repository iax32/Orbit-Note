import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  for (final status in ['todo', 'testing', 'syllabus', 'custom-workflow']) {
    testWidgets('TaskDetail preserves status $status without assertion', (
      tester,
    ) async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final task = await repo.create(
        typeId: 'orbit.task',
        title: 'Task',
        properties: {'status': status},
      );
      final controller = WorkspaceController()
        ..repository = repo
        ..objects = repo.objects;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskDetail(object: task, controller: controller),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(repo.objects.single.properties['status'], status);
    });
  }
  for (final kind in ['active', 'deleted', 'missing', 'note']) {
    testWidgets('TaskDetail preserves $kind blocker without assertion', (
      tester,
    ) async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final blocker = await repo.create(
        typeId: kind == 'note' ? 'orbit.note' : 'orbit.task',
        title: 'Blocker',
      );
      if (kind == 'deleted') await repo.trash(blocker.id);
      final id = kind == 'missing'
          ? '00000000-0000-4000-8000-000000000001'
          : blocker.id;
      final task = await repo.create(
        typeId: 'orbit.task',
        title: 'Task',
        properties: {'blockedBy': id},
      );
      final controller = WorkspaceController()
        ..repository = repo
        ..objects = repo.objects;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskDetail(object: task, controller: controller),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        repo.objects
            .singleWhere((o) => o.id == task.id)
            .properties['blockedBy'],
        id,
      );
    });
  }
}
