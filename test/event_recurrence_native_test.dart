import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/event_recurrence.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/object_codec.dart';

void main() {
  test(
    'native recurrence history survives restart and future metadata stays editable',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-event-repeat-');
      var repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: root.path);
        final e = await repo.create(
          typeId: 'orbit.event',
          title: 'Lecture',
          properties: {
            'allDay': true,
            'startDate': '2026-10-09',
            'endDate': '2026-10-10',
            'eventRecurrence': {
              'version': 1,
              'frequency': 'weekly',
              'interval': 1,
              'anchorDate': '2026-10-09',
              'processed': 0,
              'paused': false,
              'overlap': 'earlier',
              'unknown': {'keep': true},
            },
          },
        );
        final p = advanceEventOccurrence(
          e,
          'completed',
          DateTime.utc(2026, 10, 9),
        );
        final saved = await repo.save(
          e.copyWith(
            properties: {
              ...p,
              'eventOccurrenceOverrides': {
                'version': 1,
                'custom': 'preserved',
                'items': {
                  'occurrence:2': {
                    'status': 'cancelled',
                    'unknown': {'keep': true},
                  },
                },
              },
            },
          ),
        );
        final path = repo.objectPath(e.id)!;
        await repo.close();
        repo = WorkspaceRepository(
          store: NativeWorkspaceStore(),
          index: MemoryObjectIndex(),
        );
        await repo.initialize(path: root.path);
        final restored = repo.objects.singleWhere((o) => o.id == e.id);
        expect(restored.properties['startDate'], '2026-10-16');
        expect(
          (restored.properties['eventOccurrenceOverrides'] as Map)['custom'],
          'preserved',
        );
        expect(
          (restored.properties['eventOccurrenceOverrides']
              as Map)['items']['occurrence:2']['status'],
          'cancelled',
        );
        expect(
          projectEventRange(
            [restored],
            DateTime(2026, 10, 9),
            DateTime(2026, 11),
          ).objects.whereType<EventOccurrence>().map((o) => o.occurrenceKey),
          isNot(contains('occurrence:2')),
        );
        expect(
          (restored.properties['eventOccurrenceHistory'] as List)
              .single['outcome'],
          'completed',
        );
        expect((restored.properties['eventRecurrence'] as Map)['unknown'], {
          'keep': true,
        });
        await repo.close();
        final future = saved.copyWith(
          properties: {
            ...saved.properties,
            'eventRecurrence': {
              ...saved.properties['eventRecurrence'] as Map,
              'version': 99,
            },
          },
        );
        await File(
          '${root.path}/$path',
        ).writeAsString(ObjectCodec().encode(future));
        repo = WorkspaceRepository(
          store: NativeWorkspaceStore(),
          index: MemoryObjectIndex(),
        );
        await repo.initialize(path: root.path);
        final imported = repo.objects.singleWhere((o) => o.id == e.id);
        await repo.save(imported.copyWith(title: 'Renamed lecture'));
        expect(
          jsonDecode(await File('${root.path}/$path').readAsString()),
          isNotNull,
        );
        expect(
          (repo.objects
                  .singleWhere((o) => o.id == e.id)
                  .properties['eventRecurrence']
              as Map)['version'],
          99,
        );
        expect(
          () => advanceEventOccurrence(imported, 'completed', DateTime.now()),
          throwsFormatException,
        );
      } finally {
        await repo.close();
        final target = root.absolute.path;
        final base = Directory.systemTemp.absolute.path;
        if (target.startsWith('$base${Platform.pathSeparator}') &&
            root.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('orbit-event-repeat-')) {
          await root.delete(recursive: true);
        }
      }
    },
  );
}
