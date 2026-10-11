import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/study_card.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/object_codec.dart';

void main() {
  test(
    'native Markdown card rebuilds and retains the pre-review recovery file',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-study-');
      var repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: root.path);
        final now = DateTime.utc(2026, 10, 9);
        final card = await repo.create(
          typeId: 'orbit.note',
          title: 'What is portable?',
          body: '**Markdown** and documented metadata.',
          properties: {
            'studyCard': StudyCard.initial(now),
            'course': 'Architecture',
            'custom': {'retained': true},
          },
        );
        final changed = await repo.save(
          card.copyWith(
            properties: {
              ...card.properties,
              'studyCard': StudyCard(card).reviewed(StudyRating.good, now),
            },
          ),
        );
        final path = repo.objectPath(card.id)!;
        final source = await File('${root.path}/$path').readAsString();
        expect(source, contains('studyCard:'));
        expect(
          ObjectCodec().decode(source, repo.workspaceId, markdown: true).body,
          card.body,
        );
        final beforeFiles = await Directory('${root.path}/.orbit/history')
            .list(recursive: true)
            .where((e) => e is File && e.path.endsWith('.before'))
            .cast<File>()
            .toList();
        var recovered = false;
        for (final before in beforeFiles) {
          final text = utf8.decode(await before.readAsBytes());
          if (text.contains(card.id)) {
            final prior = ObjectCodec().decode(
              text,
              repo.workspaceId,
              markdown: true,
            );
            if (StudyCard(prior).history.isEmpty && prior.body == card.body) {
              recovered = true;
            }
          }
        }
        expect(recovered, true);
        await repo.writeDeviceSettings({
          'spaces': {
            'version': 1,
            'items': [
              {
                'version': 1,
                'id': 'study-context',
                'name': 'Study: Architecture',
                'kind': 'space',
                'studyVersion': 1,
                'studyCourse': 'Architecture',
                'studyContinuation': 'Return to portability',
                'studyDismissed': [card.id],
                'context': {
                  'tabs': [card.id],
                  'activeId': card.id,
                  'positions': {card.id: 80},
                  'noteViews': {},
                  'cameras': {},
                },
                'futureField': {'retained': true},
              },
            ],
          },
        });
        await repo.close();
        repo = WorkspaceRepository(
          store: NativeWorkspaceStore(),
          index: MemoryObjectIndex(),
        );
        await repo.initialize(path: root.path);
        final rebuilt = repo.objects.singleWhere((o) => o.id == card.id);
        expect(rebuilt.properties, changed.properties);
        expect(StudyCard(rebuilt).history.single['rating'], 'good');
        final settings = await repo.readDeviceSettings();
        final context =
            ((settings['spaces'] as Map)['items'] as List).single as Map;
        expect(context['studyContinuation'], 'Return to portability');
        expect(context['studyDismissed'], [card.id]);
        expect((context['context'] as Map)['positions'], {card.id: 80});
        expect(context['futureField'], {'retained': true});
      } finally {
        await repo.close();
        // This directory was created above and its resolved target is checked
        // before recursive cleanup; no user Vault can become the cleanup target.
        final resolved = await root.resolveSymbolicLinks();
        final temp = await Directory.systemTemp.resolveSymbolicLinks();
        if (!resolved.toLowerCase().startsWith(
              '${temp.toLowerCase()}${Platform.pathSeparator}',
            ) ||
            !root.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('orbit-study-')) {
          throw StateError('Unexpected temporary test directory.');
        }
        await root.delete(recursive: true);
      }
    },
  );
}
