import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'package:orbit_note/features/workspace/study_resume_panel.dart';

void main() {
  late MemoryStore store;
  late ProviderContainer container;
  late WorkspaceController c;
  Future<void> open() async {
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(
          WorkspaceRepository(store: store, index: MemoryObjectIndex()),
        ),
      ],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    while (c.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  setUp(() async {
    store = MemoryStore();
    await open();
  });
  tearDown(() async {
    await c.closeWorkspace();
    container.dispose();
  });

  test('PDF page/zoom and Canvas camera restore only course state', () async {
    final pdf = (await c.create(
      'orbit.file',
      title: 'Paper',
      properties: {'course': 'Math'},
    ))!;
    final canvas = (await c.create(
      'orbit.canvas',
      title: 'Board',
      properties: {'course': 'Math'},
    ))!;
    c.openObject(pdf.id);
    c.openObject(canvas.id);
    final key = 'pdf:primary:${pdf.id}';
    c.session.noteViews = {
      key: {'page': 8, 'zoom': 1.5},
      'unrelated': {'page': 9},
    };
    c.session.cameras = {
      canvas.id: {'x': 10, 'y': 20, 'zoom': 2},
    };
    expect(await c.saveStudyResume('Math', 'Finish diagram'), true);
    expect(
      (c.studyResume('Math')!['context'] as Map)['noteViews'],
      isNot(contains('unrelated')),
    );
    c.session.noteViews = {
      'unrelated': {'page': 12},
    };
    c.session.cameras = {};
    expect(await c.resumeStudy('Math'), true);
    expect(c.session.noteViews[key]!['page'], 8);
    expect(c.session.noteViews[key]!['zoom'], 1.5);
    expect(c.session.noteViews['unrelated']!['page'], 12);
    expect(c.session.cameras[canvas.id]!['zoom'], 2);
    expect(c.studyResumeSerial, 1);
  });

  testWidgets(
    'continuation panel remains usable at narrow width and large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(380, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: StudyResumePanel(controller: c, course: 'Math'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Continue studying'));
      await tester.pumpAndSettle();
      expect(find.text('Your next step'), findsOneWidget);
      expect(find.text('Save current position'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'course positions, next step and dismissals survive restart without copying knowledge',
    () async {
      final note = (await c.create(
        'orbit.note',
        title: 'Lecture',
        body: 'Original',
        properties: {'course': 'Math', 'studyUnderstanding': 'uncertain'},
      ))!;
      c.openObject(note.id);
      c.session.positions = {note.id: 123};
      c.session.noteViews = {
        note.id: {'cursor': 3},
      };
      expect(await c.saveStudyResume('Math', 'Continue proof'), true);
      expect(await c.dismissStudyMaterial('Math', note.id), true);
      await c.closeWorkspace();
      container.dispose();
      await open();
      expect(c.studyResume('Math')!['studyContinuation'], 'Continue proof');
      expect(c.relatedStudyMaterial('Math'), isEmpty);
      c.session.positions = {};
      final other = (await c.create(
        'orbit.note',
        title: 'Other',
        properties: {'course': 'Physics'},
      ))!;
      c.openObject(other.id);
      expect(await c.resumeStudy('Math'), true);
      expect(c.session.positions[note.id], 123);
      expect(c.session.noteViews[note.id]!['cursor'], 3);
      expect(c.session.tabs, contains(other.id));
      expect(c.session.activeId, note.id);
      expect(c.find(note.id)!.body, 'Original');
      expect(await c.dismissStudyMaterial('Math', '', reset: true), true);
      expect(c.relatedStudyMaterial('Math').single.id, note.id);
    },
  );

  test(
    'changed sources reset offsets and missing sources fall back without resurrecting content',
    () async {
      final a = (await c.create(
        'orbit.note',
        title: 'A',
        body: 'old',
        properties: {'course': 'Math'},
      ))!;
      final b = (await c.create(
        'orbit.note',
        title: 'B',
        properties: {'course': 'Math'},
      ))!;
      c.openObject(a.id);
      c.openObject(b.id);
      c.session.positions = {a.id: 500};
      expect(await c.saveStudyResume('Math', ''), true);
      c.edit(a.id, body: 'new');
      await c.flushAll();
      await c.trash(b.id);
      expect(c.studyResumeWarnings('Math'), hasLength(2));
      expect(await c.resumeStudy('Math'), true);
      expect(c.session.positions.containsKey(a.id), false);
      expect(c.session.activeId, a.id);
      expect(c.find(a.id)!.body, 'new');
      await c.trash(a.id);
      expect(await c.resumeStudy('Math'), false);
      expect(c.error, contains('missing'));
    },
  );

  test(
    'unfinished work uses current course task state and save failures remain visible',
    () async {
      final note = (await c.create(
        'orbit.note',
        properties: {'course': 'Math'},
      ))!;
      await c.create(
        'orbit.task',
        title: 'Read',
        properties: {'course': 'Math'},
      );
      await c.create(
        'orbit.task',
        title: 'Done',
        properties: {'course': 'Math', 'completed': true},
      );
      await c.create(
        'orbit.task',
        title: 'Other',
        properties: {'course': 'Physics'},
      );
      expect(c.unfinishedStudyWork('Math').map((o) => o.title), ['Read']);
      c.openObject(note.id);
      store.failWrites = true;
      expect(await c.saveStudyResume('Math', 'Next'), false);
      expect(c.error, contains('Could not save'));
      store.failWrites = false;
      expect(await c.saveStudyResume('Math', 'Next'), true);
      c.session.spaces = {...c.session.spaces, 'version': 99};
      expect(await c.saveStudyResume('Math', 'Overwrite'), false);
      expect(c.session.spaces['version'], 99);
    },
  );
}
