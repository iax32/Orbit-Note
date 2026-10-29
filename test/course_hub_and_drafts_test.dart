import 'package:orbit_note/domain/workspace_failure.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/course_progress.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/workspace/course_hub.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/main.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

class _CourseStore extends FolderMemoryStore {
  bool failLectures = false;
  @override
  Future<void> write(
    String path,
    Uint8List bytes, {
    required String? expectedHash,
  }) async {
    if (failLectures && path.startsWith('Notes/University/Partial/Lectures/')) {
      throw const WorkspaceFailure('Lecture write failed');
    }
    await super.write(path, bytes, expectedHash: expectedHash);
  }
}

class _SwitchingStore extends FolderMemoryStore {
  final vaults = <String, Map<String, Uint8List>>{};
  String selected = 'one';
  @override
  Future<void> initialize({String? path}) async {
    if (path == null || path == selected) return;
    vaults[selected] = Map.of(files);
    selected = path;
    files
      ..clear()
      ..addAll(vaults[path] ?? {});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FolderMemoryStore store;
  late WorkspaceRepository repo;
  late ProviderContainer container;
  late WorkspaceController c;
  setUp(() async {
    store = _CourseStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    for (var i = 0; i < 100 && c.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  });
  tearDown(() async {
    store.failWrites = false;
    store.writeGate = null;
    c.editorDraftConflicts.clear();
    await c.flushAll();
    container.dispose();
  });

  test(
    'same-frame note edits preserve both drafts and refuse exit until resolved',
    () async {
      final note = (await c.create(
        'orbit.note',
        body: 'base',
        properties: {
          'custom': {'keep': true},
        },
      ))!;
      expect(c.publishEditorBody('left', note.id, 'base', 'left edit'), isTrue);
      expect(
        c.publishEditorBody('right', note.id, 'base', 'right edit'),
        isFalse,
      );
      expect(c.find(note.id)!.body, 'left edit');
      expect(c.editorDraftConflicts['right']!.body, 'right edit');
      expect(await c.flushAll(), isFalse);
      final copy = await c.recoverEditorDraft('right');
      expect(copy!.body, 'right edit');
      expect(copy.id, isNot(note.id));
      expect(copy.properties['custom'], {'keep': true});
      expect(copy.properties['recoveredFrom'], note.id);
      expect(repo.objects.firstWhere((o) => o.id == note.id).body, 'left edit');
      expect(await c.flushAll(), isTrue);
    },
  );

  test('failed draft recovery keeps conflict and latest local text', () async {
    final note = (await c.create('orbit.note', body: 'base'))!;
    c.publishEditorBody('left', note.id, 'base', 'left');
    await c.flush(note.id);
    c.publishEditorBody('right', note.id, 'base', 'right');
    store.failWrites = true;
    expect(await c.recoverEditorDraft('right'), isNull);
    expect(c.editorDraftConflicts['right']!.body, 'right');
    expect(c.find(note.id)!.body, 'left');
    store.failWrites = false;
    expect(await c.recoverEditorDraft('right'), isNotNull);
    expect(c.editorDraftConflicts, isEmpty);
  });

  test(
    'recovery completing after a newer conflicting edit keeps newer draft',
    () async {
      final note = (await c.create('orbit.note', body: 'base'))!;
      c.publishEditorBody('left', note.id, 'base', 'left');
      await c.flush(note.id);
      c.publishEditorBody('right', note.id, 'base', 'right v1');
      final gate = Completer<void>();
      store.writeGate = gate.future;
      final saving = c.recoverEditorDraft('right');
      await Future<void>.delayed(Duration.zero);
      c.publishEditorBody('right', note.id, 'base', 'right v2');
      store.writeGate = null;
      gate.complete();
      expect((await saving)!.body, 'right v1');
      expect(c.editorDraftConflicts['right']!.body, 'right v2');
    },
  );

  test(
    'two Canvas panes retain scene, opaque data and canonical references',
    () async {
      final base = {
        'schemaVersion': 1,
        'elements': <dynamic>[],
        'opaque': {'keep': true},
      };
      final canvas = (await c.create('orbit.canvas', data: base))!;
      final left = {
        ...base,
        'elements': [
          {'id': 'a', 'type': 'text', 'text': 'left'},
        ],
      };
      final right = {
        ...base,
        'elements': [
          {'id': 'b', 'type': 'card', 'objectId': canvas.id},
        ],
      };
      expect(c.publishCanvasDraft('left', canvas.id, base, left), isTrue);
      expect(c.publishCanvasDraft('right', canvas.id, base, right), isFalse);
      (right['elements'] as List).clear();
      final recovered = (await c.recoverEditorDraft('right'))!;
      expect(recovered.typeId, 'orbit.canvas');
      expect(recovered.data['opaque'], {'keep': true});
      expect(
        (recovered.data['elements'] as List).single['objectId'],
        canvas.id,
      );
      expect((c.find(canvas.id)!.data['elements'] as List).single['id'], 'a');
    },
  );

  test(
    'autosave under parallel flushes retains all latest fields once',
    () async {
      final note = (await c.create('orbit.note', body: 'base'))!;
      final gate = Completer<void>();
      store.writeGate = gate.future;
      c.edit(note.id, body: 'first');
      final pending = [c.flush(note.id), c.flush(note.id), c.flush(note.id)];
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 100; i++) {
        c.edit(
          note.id,
          body: 'draft $i',
          title: 'title $i',
          properties: {'n': i},
        );
      }
      store.writeGate = null;
      gate.complete();
      await Future.wait(pending);
      final saved = repo.objects.firstWhere((o) => o.id == note.id);
      expect(saved.body, 'draft 99');
      expect(saved.title, 'title 99');
      expect(saved.properties['n'], 99);
      expect(c.dirty, isEmpty);
      expect(c.failures, isEmpty);
    },
  );

  test(
    'unchanged callbacks do not create dirty objects or extra revisions',
    () async {
      final note = (await c.create('orbit.note', body: 'same'))!;
      for (var i = 0; i < 100; i++) {
        c.edit(
          note.id,
          title: note.title,
          body: note.body,
          properties: note.properties,
        );
      }
      expect(c.dirty, isEmpty);
      expect(identical(c.find(note.id), note), isTrue);
      expect(
        repo.objects.firstWhere((o) => o.id == note.id).revision,
        note.revision,
      );
    },
  );

  test(
    'course setup isolates same-name semesters and survives metadata edits',
    () async {
      final a = (await c.createUniversityCourse(
        'Algorithms',
        semester: 'Winter',
        ects: 6.5,
      ))!;
      final b = (await c.createUniversityCourse(
        'Algorithms',
        semester: 'Summer',
        targetParentFolder: 'Summer',
      ))!;
      final exercise = CourseProgress(
        a,
        c.objects,
      ).members.firstWhere((o) => o.typeId == 'orbit.canvas');
      final task = (await c.addCourseMaterial(
        a.id,
        'assignment',
        'Sheet 1',
        dueDate: '2020-01-01',
      ))!;
      c.edit(task.id, properties: {...task.properties, 'completed': true});
      c.edit(
        exercise.id,
        properties: {...exercise.properties, 'exerciseStatus': 'solved'},
      );
      final progress = CourseProgress(a, c.objects);
      expect(progress.tasks, 1);
      expect(progress.completedTasks, 1);
      expect(progress.solvedExercises, 1);
      expect(CourseProgress(b, c.objects).tasks, 0);
      c.edit(
        a.id,
        body: 'User-edited course goals',
        properties: {
          ...a.properties,
          'unknown': {'keep': true},
        },
      );
      expect(
        await c.saveCourseDetails(a, {
          'courseDisplayName': 'Advanced Algorithms',
          'semester': 'Winter',
          'ects': 6.5,
          'courseCode': 'CS',
          'lecturer': 'Dr A',
          'courseStatus': 'passed',
        }),
        isTrue,
      );
      final latest = c.find(a.id)!;
      expect(latest.id, a.id);
      expect(latest.body, 'User-edited course goals');
      expect(latest.properties['unknown'], {'keep': true});
      expect(latest.properties['course'], 'Algorithms');
      expect(CourseProgress(latest, c.objects).completedTasks, 1);
      final stale = latest;
      c.edit(a.id, properties: {...latest.properties, 'ects': 8});
      expect(
        await c.saveCourseDetails(stale, {
          'courseDisplayName': 'Algorithms',
          'semester': 'Winter',
          'ects': 9,
          'courseStatus': 'active',
        }),
        isFalse,
      );
      expect(c.find(a.id)!.properties['ects'], 8);
    },
  );

  test(
    'unlink overrides old folders without deleting content; live board updates',
    () async {
      final course = (await c.createUniversityCourse('Graphics'))!;
      final task = (await c.addCourseMaterial(
        course.id,
        'assignment',
        'Lighting',
      ))!;
      final board = (await c.createCoursePlanningBoard(course.id))!;
      final again = (await c.createCoursePlanningBoard(course.id))!;
      expect(board.id, again.id);
      final live = c.objects.firstWhere(
        (o) => o.title.endsWith('— Open assignments'),
      );
      expect(c.queryViewObjects(live).map((o) => o.id), [task.id]);
      c.edit(task.id, properties: {...task.properties, 'completed': true});
      expect(c.queryViewObjects(live), isEmpty);
      final linked = c.find(task.id)!;
      expect(
        await c.linkCourseMaterial(course.id, linked, remove: true),
        isTrue,
      );
      expect(belongsToCourse(c.find(task.id)!, course), isFalse);
      expect(c.find(task.id)!.isDeleted, isFalse);
      final ids = (board.data['elements'] as List)
          .where((e) => e['type'] == 'card')
          .map((e) => e['objectId']);
      expect(
        ids,
        contains(task.id),
      ); // Placement persists independently of membership.
    },
  );

  test(
    'invalid courses, duplicates and partial setup cannot silently continue',
    () async {
      final count = c.objects.length;
      expect(await c.createUniversityCourse('../escape'), isNull);
      expect(await c.createUniversityCourse('Bad', ects: double.nan), isNull);
      expect(c.objects.length, count);
      final course = await c.createUniversityCourse('Valid');
      expect(course, isNotNull);
      final created = c.objects.length;
      expect(await c.createUniversityCourse('Valid'), isNull);
      expect(c.objects.length, created);
      store.failWrites = true;
      expect(await c.createUniversityCourse('Failed'), isNull);
      expect(c.objects.length, created);
    },
  );

  test('course planning commands retain canonical course identity', () async {
    final course = (await c.createUniversityCourse('Physics'))!;
    final planned = (await c.saveCalendarPlan(
      title: 'Exam',
      body: '',
      kind: 'exam',
      course: 'Physics',
      courseId: course.id,
      dates: {
        'allDay': true,
        'startDate': '2026-12-01',
        'endDate': '2026-12-02',
      },
      estimateMinutes: 60,
      resources: [],
    ))!;
    expect(planned.properties['courseId'], course.id);
    expect(belongsToCourse(planned, course), isTrue);
  });

  test('queued creates and folders reject Vault switches', () async {
    final switchedStore = _SwitchingStore();
    final switchedRepo = WorkspaceRepository(
      store: switchedStore,
      index: MemoryObjectIndex(),
    );
    addTearDown(switchedRepo.close);
    await switchedRepo.initialize();
    final switching = switchedRepo.initialize(path: 'two');
    final create = switchedRepo.create(
      typeId: 'orbit.note',
      title: 'Old Vault',
    );
    final folder = switchedRepo.createFolder('Old folder');
    final refused = [
      expectLater(create, throwsA(isA<Exception>())),
      expectLater(folder, throwsA(isA<Exception>())),
    ];
    await switching;
    await Future.wait(refused);
    expect(switchedRepo.objects, isEmpty);
    expect(switchedStore.folderList, isNot(contains('Old folder')));
  });

  test('create snapshots mutable nested data before queuing', () async {
    final properties = {
      'tags': ['original'],
    };
    final data = {
      'elements': <dynamic>[
        {'id': 'first', 'type': 'text'},
      ],
    };
    final creating = repo.create(
      typeId: 'orbit.canvas',
      title: 'Snapshot',
      properties: properties,
      data: data,
    );
    properties['tags']!.clear();
    (data['elements'] as List).clear();
    final saved = await creating;
    expect(saved.properties['tags'], ['original']);
    expect((saved.data['elements'] as List).single['id'], 'first');
  });

  test(
    'partial course setup stops and keeps the saved overview discoverable',
    () async {
      (store as _CourseStore).failLectures = true;
      expect(await c.createUniversityCourse('Partial'), isNull);
      expect(c.courses.map((o) => o.properties['course']), ['Partial']);
      expect(c.objects.where((o) => o.typeId == 'orbit.canvas'), isEmpty);
      expect(c.objects.where((o) => o.typeId == 'orbit.view'), isEmpty);
      expect(c.error, contains('Saved items are retained'));
    },
  );

  test(
    'course flashcards and resume remain isolated across identical names',
    () async {
      final a = (await c.createUniversityCourse('Networks'))!;
      final b = (await c.createUniversityCourse(
        'Networks',
        targetParentFolder: 'Summer',
      ))!;
      final card = (await c.createStudyCard(
        question: 'What is a packet?',
        answer: 'A unit of data',
        course: 'Networks',
        courseId: a.id,
      ))!;
      expect(c.matchesStudyCourse(card, a.id), isTrue);
      expect(c.matchesStudyCourse(card, b.id), isFalse);
      c.openObject(card.id);
      c.session.tabs = [card.id, b.id];
      expect(await c.saveStudyResume(a.id, 'Review packets'), isTrue);
      final saved = c.studyResume(a.id)!;
      expect((saved['context'] as Map)['tabs'], [card.id]);
      expect(c.studyResume(b.id), isNull);
    },
  );

  testWidgets('course hub stays usable at narrow widths and enlarged text', (
    tester,
  ) async {
    final course = await tester.runAsync(
      () => c.createUniversityCourse(
        'Very long course title with useful context',
        ects: 6.5,
      ),
    );
    expect(course, isNotNull);
    for (final size in [
      const Size(1100, 800),
      const Size(360, 640),
      const Size(640, 360),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(2),
              ),
              child: CourseHub(controller: c),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Add course'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => c.flushAll());
    c.cancelAllTimers();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('two note widgets cannot overwrite a same-frame competing body', (
    tester,
  ) async {
    final note = (await tester.runAsync(
      () => c.create('orbit.note', body: 'base'),
    ))!;
    c.session.defaultNoteMode = 'write';
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                for (final pane in ['left', 'right'])
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) {
                        ref.watch(workspaceProvider);
                        final latest = c.find(note.id)!;
                        return NoteEditor(
                          noteId: note.id,
                          title: note.title,
                          body: latest.body,
                          controller: c,
                          editorDraftId: pane,
                          onTitleChanged: (_) {},
                          onBodyChanged: (_) {},
                          linkTargets: const [],
                          onOpenObject: (_) {},
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final fields = find.byKey(const ValueKey('note-body'));
    final left = tester.widget<TextField>(fields.at(0));
    final right = tester.widget<TextField>(fields.at(1));
    left.controller!.text = 'left';
    left.onChanged!('left');
    right.controller!.text = 'right';
    right.onChanged!('right');
    expect(c.find(note.id)!.body, 'left');
    expect(c.editorDraftConflicts['right']!.body, 'right');
    expect(right.controller!.text, 'right');
    await tester.pump();
    expect(find.text('Review drafts'), findsOneWidget);
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, 'right');
    final copy = await tester.runAsync(() => c.recoverEditorDraft('right'));
    expect(copy!.body, 'right');
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, 'left');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => c.flushAll());
    c.cancelAllTimers();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets(
    'Canvas retains a competing scene during rebuild and discard restores shared scene',
    (tester) async {
      final canvas = (await tester.runAsync(
        () => c.create(
          'orbit.canvas',
          data: {
            'schemaVersion': 1,
            'elements': [
              {
                'id': 'item',
                'type': 'rectangle',
                'text': 'Original',
                'x': 50.0,
                'y': 50.0,
                'width': 200.0,
                'height': 140.0,
              },
            ],
          },
        ),
      ))!;
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(workspaceProvider);
                  final current = c.find(canvas.id)!;
                  return CanvasEditor(
                    canvasId: canvas.id,
                    data: current.data,
                    draftBaseData: current.data,
                    retainConflictingDraft: c.editorDraftConflicts.containsKey(
                      'pane',
                    ),
                    onDraftChanged: (base, next) =>
                        c.publishCanvasDraft('pane', canvas.id, base, next),
                    onChanged: (_) {},
                    objects: const [],
                    onOpenObject: (_) {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final surface = find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter is OrbitCanvasPainter &&
            (w.painter as OrbitCanvasPainter).paintOverlays,
      );
      final origin = tester.getTopLeft(surface);
      final gesture = await tester.startGesture(
        origin + const Offset(110, 120),
      );
      await gesture.moveBy(const Offset(100, 50));
      expect(
        (tester.widget<CustomPaint>(surface).painter as OrbitCanvasPainter)
            .scene['item']!
            .x,
        150.0,
      );
      final shared = {
        ...canvas.data,
        'elements': [
          {
            'id': 'item',
            'type': 'rectangle',
            'text': 'Shared edit',
            'x': 50.0,
            'y': 50.0,
            'width': 200.0,
            'height': 140.0,
          },
        ],
      };
      c.edit(canvas.id, data: shared);
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(c.editorDraftConflicts['pane'], isNotNull);
      expect(
        (c.find(canvas.id)!.data['elements'] as List).single['text'],
        'Shared edit',
      );
      expect(
        (c.editorDraftConflicts['pane']!.data['elements'] as List).single['x'],
        150.0,
      );
      c.discardEditorDraft('pane');
      await tester.pump();
      final painter =
          tester.widget<CustomPaint>(surface).painter as OrbitCanvasPainter;
      expect(painter.scene['item']!.text, 'Shared edit');
      c.cancelAllTimers();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => c.flushAll());
      c.cancelAllTimers();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets('Explorer exposes code, model and course entry points', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OrbitNoteApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('explorer-new-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Open code file'), findsOneWidget);
    expect(find.text('Open 3D model (OBJ / GLB)'), findsOneWidget);
    expect(find.text('Courses & study progress'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => c.flushAll());
    c.cancelAllTimers();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
