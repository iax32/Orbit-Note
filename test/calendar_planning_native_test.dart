import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/calendar_planning.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

void main() {
  test(
    'native planning JSON/Markdown and private view rebuild without a database',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-calendar-planning-',
      );
      var repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: root.path);
        final note = await repo.create(
          typeId: 'orbit.note',
          title: 'Lecture',
          body: 'Original knowledge',
        );
        final task = await repo.create(
          typeId: 'orbit.task',
          title: 'Assignment',
          body: 'Finish proof',
          properties: {
            'course': 'Math',
            'dueDate': '2026-10-20',
            'scheduledDate': '2026-10-15',
            'calendarPlan': {
              'version': 1,
              'kind': 'assignment',
              'estimateMinutes': 90,
              'resources': [note.id],
              'custom': 42,
            },
          },
        );
        final exam = await repo.create(
          typeId: 'orbit.event',
          title: 'Exam',
          properties: {
            'course': 'Math',
            'allDay': true,
            'startDate': '2026-10-20',
            'endDate': '2026-10-21',
            'calendarPlan': {
              'version': 1,
              'kind': 'exam',
              'estimateMinutes': 120,
              'resources': [note.id, task.id],
            },
          },
        );
        await repo.writeDeviceSettings({
          'noteViews': {
            'calendarPlanning': {
              'version': 1,
              'mode': 'Week',
              'date': '2026-10-20',
              'course': 'Math',
              'kind': 'all',
              'search': '',
              'completed': false,
            },
          },
        });
        expect(
          await File('${root.path}/${repo.objectPath(task.id)}').readAsString(),
          contains('Finish proof'),
        );
        await repo.close();
        repo = WorkspaceRepository(
          store: NativeWorkspaceStore(),
          index: MemoryObjectIndex(),
        );
        await repo.initialize(path: root.path);
        final rebuilt = repo.objects.singleWhere((o) => o.id == exam.id);
        expect(calendarResources(rebuilt), [note.id, task.id]);
        expect(
          repo.objects
              .singleWhere((o) => o.id == task.id)
              .properties['calendarPlan']['custom'],
          42,
        );
        expect(
          (await repo
              .readDeviceSettings())['noteViews']['calendarPlanning']['mode'],
          'Week',
        );
        expect(
          exportCalendarIcs(repo.objects),
          contains('UID:${exam.id}@orbit-note'),
        );
      } finally {
        await repo.close();
        final resolved = await root.resolveSymbolicLinks(),
            temp = await Directory.systemTemp.resolveSymbolicLinks();
        if (!resolved.toLowerCase().startsWith(
              '${temp.toLowerCase()}${Platform.pathSeparator}',
            ) ||
            !root.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('orbit-calendar-planning-')) {
          throw StateError('Unexpected cleanup target');
        }
        await root.delete(recursive: true);
      }
    },
  );
}
