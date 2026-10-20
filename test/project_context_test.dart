import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/project_context.dart';
import 'package:orbit_note/domain/backlinks.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/domain/research_workspace.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/project_context_panel.dart';
import 'package:orbit_note/features/workspace/calendar_view.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/memory_store.dart';
import 'support/pdf_fixture.dart';

void main() {
  late MemoryStore store;
  late WorkspaceRepository repo;
  late ProviderContainer container;
  late WorkspaceController c;
  late UniversalObject brief, other;
  setUp(() async {
    store = MemoryStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    for (var i = 0; i < 100 && c.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    brief = (await c.create(
      'orbit.note',
      title: 'Movement brief',
      properties: {'isCreativeBrief': true},
    ))!;
    other = (await c.create(
      'orbit.note',
      title: 'Other brief',
      properties: {'isCreativeBrief': true},
    ))!;
    expect(await c.selectProject(brief.id), isTrue);
  });
  tearDown(() async {
    store.failWrites = false;
    await c.flushAll();
    container.dispose();
  });

  test(
    'project follows creation and search without changing explicit ownership',
    () async {
      final note = (await c.create('orbit.note', title: 'Movement source'))!;
      final task = (await c.create('orbit.task', title: 'Movement test'))!;
      final board = (await c.create('orbit.canvas', title: 'Movement board'))!;
      final foreign = (await c.create(
        'orbit.note',
        title: 'Movement foreign',
        properties: {'project': other.id},
      ))!;
      final unassigned = (await c.create(
        'orbit.note',
        title: 'Movement unassigned',
        properties: {'project': ''},
      ))!;
      for (final o in [note, task, board]) {
        expect(o.properties['project'], brief.id);
      }
      final results = await c.searchLocations('Movement');
      expect(
        results.map((r) => r.object.id),
        containsAll([brief.id, note.id, task.id, board.id]),
      );
      expect(results.map((r) => r.object.id), isNot(contains(foreign.id)));
      expect(results.map((r) => r.object.id), isNot(contains(unassigned.id)));
      await c.selectProject(null);
      expect(
        (await c.searchLocations('Movement')).map((r) => r.object.id),
        contains(foreign.id),
      );
    },
  );

  test(
    'attachment ownership persists alongside original bytes and survives reopen',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final attachment = await c.importProjectAttachment('evidence.bin', bytes);
      expect(attachment.properties['project'], brief.id);
      await c.saveSession();
      await c.initialize();
      expect(c.selectedProjectId, brief.id);
      expect(c.find(attachment.id)!.properties['project'], brief.id);
      expect(
        await store.read(attachment.properties['contentRef'] as String),
        bytes,
      );
    },
  );

  test('recording is opt-in, project scoped, pausable and clearable', () async {
    final note = (await c.create('orbit.note', title: 'Design'))!;
    expect(c.projectRecord(brief.id)['events'], isNull);
    c.setProjectRecording(true);
    c.openObject(note.id);
    c.openObject(other.id);
    c.openObject(note.id);
    expect((c.projectRecord(brief.id)['events'] as List).length, 1);
    c.setProjectRecording(false);
    await c.create('orbit.task');
    expect((c.projectRecord(brief.id)['events'] as List).length, 1);
    c.clearProjectActivity();
    expect(c.projectRecord(brief.id)['events'], isEmpty);
  });

  test('only successful durable saves become activity', () async {
    final note = (await c.create('orbit.note'))!;
    c.setProjectRecording(true);
    store.failWrites = true;
    c.edit(note.id, body: 'pending');
    await c.flush(note.id);
    expect(c.projectRecord(brief.id)['events'], isNull);
    expect(c.dirty, contains(note.id));
    store.failWrites = false;
    await c.retry(note.id);
    expect(
      (c.projectRecord(brief.id)['events'] as List).first['action'],
      'saved',
    );
  });

  test(
    'continuation restores split, source position and Canvas camera after reopen',
    () async {
      final note = (await c.create('orbit.note'))!;
      final canvas = (await c.create('orbit.canvas'))!;
      c.openObject(note.id);
      c.openObject(canvas.id, secondary: true);
      c.session.positions = {note.id: 120};
      c.session.cameras = {
        canvas.id: {'x': 24, 'y': 42, 'zoom': 1.5},
      };
      c.session.noteViews = {
        note.id: {'mode': 'rich', 'selectionStart': 7},
      };
      c.session.splitAxis = 'vertical';
      expect(
        await c.saveProjectContinuation('Check diagonal movement'),
        isTrue,
      );
      c.session.positions = {};
      c.session.cameras = {};
      c.session.activeId = other.id;
      await c.saveSession();
      await c.initialize();
      expect(await c.resumeProject(), isTrue);
      expect(c.session.activeId, note.id);
      expect(c.session.secondaryId, canvas.id);
      expect(c.session.positions[note.id], 120);
      expect(c.session.cameras[canvas.id]!['zoom'], 1.5);
      expect(c.session.splitAxis, 'vertical');
      expect(c.projectRecord(brief.id)['nextStep'], 'Check diagonal movement');
    },
  );

  test(
    'failed settings save reports failure and preserves continuation draft',
    () async {
      store.failWrites = true;
      expect(await c.saveProjectContinuation('Keep this question'), isFalse);
      expect(await c.selectProject(other.id), isFalse);
      expect(c.selectedProjectId, brief.id);
    },
  );

  test(
    'unknown context and future relation formats cannot be overwritten',
    () async {
      c.session.projectContext = {
        'version': 99,
        'selected': brief.id,
        'future': 42,
      };
      expect(await c.selectProject(other.id), isFalse);
      c.setProjectRecording(true);
      expect(c.session.projectContext['future'], 42);
      expect(c.session.projectContext['version'], 99);
      final note = (await c.create(
        'orbit.note',
        properties: {
          'orbitConnections': {'version': 99, 'items': []},
        },
      ))!;
      expect(
        await c.addProjectConnection(note.id, 'supports', other.id, ''),
        isFalse,
      );
      expect(c.find(note.id)!.properties['orbitConnections']['version'], 99);
    },
  );

  test(
    'precise authored connections survive reopen and contribute backlinks',
    () async {
      final note = (await c.create('orbit.note', title: 'Evidence'))!;
      expect(
        await c.addProjectConnection(
          note.id,
          'supports',
          '${brief.id}#page=3',
          'Observed on build 12',
        ),
        isTrue,
      );
      await c.initialize();
      var link = ProjectConnection.read(
        c.find(note.id)!.properties['orbitConnections'],
      ).single;
      expect(link.target.page, 3);
      expect(link.note, 'Observed on build 12');
      expect(link.warning(c.find(brief.id)), isNull);
      final mentions = findLinkedMentions(
        targetId: brief.id,
        targets: c.linkTargets,
        objects: c.activeObjects,
      );
      expect(
        mentions.any(
          (m) => m.source.id == note.id && m.targetLocation?.page == 3,
        ),
        isTrue,
      );
      c.edit(brief.id, body: 'New evidence');
      await c.flush(brief.id);
      expect(link.warning(c.find(brief.id)), contains('changed'));
      expect(await c.reviewProjectConnection(note.id, link.id), isTrue);
      link = ProjectConnection.read(
        c.find(note.id)!.properties['orbitConnections'],
      ).single;
      expect(link.warning(c.find(brief.id)), isNull);
      expect(await c.removeProjectConnection(note.id, link.id), isTrue);
      expect(
        ProjectConnection.read(c.find(note.id)!.properties['orbitConnections']),
        isEmpty,
      );
    },
  );

  test(
    'connection validation rejects duplicates, self links, missing targets and unsupported types',
    () async {
      final note = (await c.create('orbit.note'))!;
      expect(
        await c.addProjectConnection(note.id, 'supports', brief.id, ''),
        isTrue,
      );
      expect(
        await c.addProjectConnection(note.id, 'supports', brief.id, ''),
        isFalse,
      );
      expect(
        await c.addProjectConnection(note.id, 'implements', note.id, ''),
        isFalse,
      );
      expect(
        await c.addProjectConnection(note.id, 'blocks', 'missing', ''),
        isFalse,
      );
      expect(
        await c.addProjectConnection(note.id, 'magic', brief.id, ''),
        isFalse,
      );
    },
  );

  test(
    'unknown authored connection records survive remove and review',
    () async {
      final note = (await c.create(
        'orbit.note',
        properties: {
          'orbitConnections': {
            'version': 1,
            'future': 42,
            'items': [
              {'futureKind': true},
            ],
          },
        },
      ))!;
      expect(
        await c.addProjectConnection(note.id, 'implements', brief.id, ''),
        isTrue,
      );
      final link = ProjectConnection.read(
        c.find(note.id)!.properties['orbitConnections'],
      ).single;
      expect(await c.removeProjectConnection(note.id, link.id), isTrue);
      expect(c.find(note.id)!.properties['orbitConnections'], {
        'version': 1,
        'future': 42,
        'items': [
          {'futureKind': true},
        ],
      });
    },
  );

  test('assignment preserves unknown metadata and file contents', () async {
    final note = (await c.create(
      'orbit.note',
      body: '# Design',
      properties: {
        'custom': {'keep': true},
      },
    ))!;
    expect(await c.assignObjectProject(note.id, other.id), isTrue);
    expect(c.find(note.id)!.body, '# Design');
    expect(c.find(note.id)!.properties['custom'], {'keep': true});
    expect(c.find(note.id)!.properties['project'], other.id);
  });

  testWidgets('project controls wrap at narrow widths and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(380, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Column(
                children: [
                  ProjectContextBar(controller: c),
                  Expanded(child: ProjectContextPanel(controller: c)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Activity'));
    await tester.pump();
    expect(find.text('Record project activity'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Where to continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'undo connection edits preserves later prose and unrelated metadata',
    () async {
      final note = (await c.create('orbit.note', properties: {'custom': 1}))!;
      expect(
        await c.addProjectConnection(note.id, 'blocks', brief.id, ''),
        isTrue,
      );
      c.edit(
        note.id,
        body: 'Later prose',
        properties: {...c.find(note.id)!.properties, 'custom': 2},
      );
      await c.flush(note.id);
      expect(await c.undoProjectMutation(note.id), isTrue);
      expect(c.find(note.id)!.body, 'Later prose');
      expect(c.find(note.id)!.properties['custom'], 2);
      expect(
        c.find(note.id)!.properties.containsKey('orbitConnections'),
        isFalse,
      );
    },
  );

  test(
    'undo refuses changed connection metadata and assignment restores membership',
    () async {
      final note = (await c.create('orbit.note'))!;
      expect(await c.assignObjectProject(note.id, other.id), isTrue);
      expect(await c.undoProjectMutation(note.id), isTrue);
      expect(c.find(note.id)!.properties['project'], brief.id);
      expect(
        await c.addProjectConnection(note.id, 'blocks', brief.id, ''),
        isTrue,
      );
      c.edit(
        note.id,
        properties: {
          ...c.find(note.id)!.properties,
          'orbitConnections': {'version': 2, 'items': []},
        },
      );
      await c.flush(note.id);
      expect(await c.undoProjectMutation(note.id), isFalse);
      expect(c.find(note.id)!.properties['orbitConnections']['version'], 2);
    },
  );

  test(
    'failed connection save retains recoverable draft and reports failure',
    () async {
      final note = (await c.create('orbit.note'))!;
      store.failWrites = true;
      expect(
        await c.addProjectConnection(note.id, 'implements', brief.id, ''),
        isFalse,
      );
      expect(c.dirty, contains(note.id));
      expect(
        ProjectConnection.read(c.find(note.id)!.properties['orbitConnections']),
        hasLength(1),
      );
      store.failWrites = false;
      await c.retry(note.id);
      await c.initialize();
      expect(
        ProjectConnection.read(c.find(note.id)!.properties['orbitConnections']),
        hasLength(1),
      );
    },
  );

  test(
    'changed sources reset saved positions and missing objects are skipped',
    () async {
      final note = (await c.create('orbit.note', body: 'Before'))!;
      final board = (await c.create('orbit.canvas'))!;
      c.openObject(note.id);
      c.session.positions = {'note:primary:${note.id}': 100};
      expect(await c.saveProjectContinuation('Review this'), isTrue);
      final serial = c.studyResumeSerial;
      c.edit(note.id, body: 'Changed text');
      await c.flush(note.id);
      await c.trash(board.id);
      expect(await c.resumeProject(), isTrue);
      expect(
        c.session.positions.containsKey('note:primary:${note.id}'),
        isFalse,
      );
      expect(c.session.tabs, isNot(contains(board.id)));
      expect(c.studyResumeSerial, serial + 1);
      expect(c.error, contains('changed sources'));
    },
  );

  test(
    'continuation drafts and private recording controls survive reopen',
    () async {
      c.setProjectContinuationDraft('Unfinished question');
      c.setProjectRecording(true);
      c.pinProjectPanel(true);
      await c.saveSession();
      await c.initialize();
      expect(c.projectRecord(brief.id)['draft'], 'Unfinished question');
      expect(c.projectRecording, isTrue);
      expect(c.projectPanelPinned, isTrue);
      expect(await c.clearProjectSavedContext(), isTrue);
      expect(c.projectRecording, isFalse);
      expect(c.projectRecord(brief.id), isEmpty);
    },
  );

  test(
    'malformed saved positions are retained rather than partially applied',
    () async {
      c.session.projectContext = {
        'version': 1,
        'selected': brief.id,
        'projects': {
          brief.id: {
            'context': {
              'tabs': [1, 2],
            },
            'future': true,
          },
        },
      };
      final active = c.session.activeId;
      expect(await c.resumeProject(), isFalse);
      expect(c.session.activeId, active);
      expect(c.projectRecord(brief.id)['future'], isTrue);
    },
  );

  test(
    'native portable metadata and device-only project state survive reopen',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'orbit-project-context-',
      );
      final native = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await native.initialize(path: folder.path);
        final source = await native.create(
          typeId: 'orbit.note',
          title: 'Specification',
          body: '# Mechanics',
          properties: {
            'project': brief.id,
            'unknown': {'keep': true},
            'orbitConnections': {
              'version': 1,
              'items': [
                {
                  'id': 'relation-1',
                  'kind': 'implements',
                  'target': '${brief.id}#Mechanics',
                },
              ],
            },
          },
        );
        await native.writeDeviceSettings(
          SessionState(
            projectContext: {
              'version': 1,
              'selected': brief.id,
              'projects': {
                brief.id: {'recording': false, 'draft': 'Next step'},
              },
            },
          ).toJson(),
        );
        final path = native.objectPath(source.id)!;
        expect(
          await File('${folder.path}/$path').readAsString(),
          contains('orbitConnections'),
        );
        await native.close();
        await native.initialize(path: folder.path);
        final reopened = native.objects.singleWhere((o) => o.id == source.id);
        expect(reopened.body, '# Mechanics');
        expect(reopened.properties['unknown'], {'keep': true});
        expect(
          ProjectConnection.read(
            reopened.properties['orbitConnections'],
          ).single.target.anchorId,
          'Mechanics',
        );
        expect(
          SessionState.fromJson(
            await native.readDeviceSettings(),
          ).projectContext['selected'],
          brief.id,
        );
      } finally {
        await native.close();
        await folder.delete(recursive: true);
      }
    },
  );

  test(
    'PDF connection navigation targets the secondary page and repeated requests',
    () async {
      final file = await c.importProjectAttachment(
        'reference.pdf',
        researchPdf(),
      );
      c.openObject(brief.id);
      final token = researchVersion(file);
      c.openProjectReference(
        ObjectReference(file.id, page: 2),
        sourceVersion: token,
      );
      final key = 'pdf:secondary:${file.id}';
      final serial = c.session.noteViews[key]!['request'];
      expect(c.session.activeId, brief.id);
      expect(c.session.secondaryId, file.id);
      expect(c.session.noteViews[key]!['page'], 2);
      c.openProjectReference(
        ObjectReference(file.id, page: 2),
        sourceVersion: token,
      );
      expect(c.session.noteViews[key]!['request'], greaterThan(serial));
      c.edit(file.id, title: 'Changed reference');
      await c.flush(file.id);
      c.openProjectReference(
        ObjectReference(file.id, page: 2),
        sourceVersion: token,
      );
      expect(c.session.noteViews[key]!['page'], 1);
      expect(c.error, contains('old precise position was not reused'));
    },
  );
  test(
    'stale connection dialogs cannot overwrite newer source edits',
    () async {
      final source = (await c.create('orbit.note'))!;
      final token = researchVersion(source);
      c.edit(source.id, body: 'New draft');
      expect(
        await c.addProjectConnection(
          source.id,
          'supports',
          brief.id,
          '',
          expectedSourceVersion: token,
        ),
        isFalse,
      );
      expect(c.find(source.id)!.body, 'New draft');
      expect(c.find(source.id)!.properties['orbitConnections'], isNull);
    },
  );
  test(
    'project activity retention is bounded and full context storage reports failure',
    () async {
      c.setProjectRecording(true);
      for (var i = 0; i < 320; i++) {
        c.recordProjectActivity(brief, 'action-$i');
      }
      final events = c.projectRecord(brief.id)['events'] as List;
      expect(events.length, 300);
      expect(events.first['action'], 'action-319');
      expect(events.last['action'], 'action-20');
      c.session.projectContext = {
        'version': 1,
        'selected': brief.id,
        'projects': {
          for (var i = 0; i < 30; i++) 'other-$i': {'future': true},
        },
      };
      expect(await c.saveProjectContinuation('No room'), isFalse);
      expect(c.projectRecord(brief.id), isEmpty);
    },
  );
  test('new calendar events inherit explicit project scope', () async {
    final event = await c.saveEvent(
      title: 'Playtest',
      body: '',
      properties: {
        'allDay': true,
        'startDate': '2026-10-12',
        'endDate': '2026-10-13',
      },
    );
    expect(event, isNotNull);
    expect(event!.properties['project'], brief.id);
  });

  testWidgets(
    'selected project calendar stays accessible in a short large-text viewport',
    (tester) async {
      tester.view.physicalSize = const Size(380, 380);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: Column(
                  children: [
                    ProjectContextBar(controller: c),
                    Expanded(child: CalendarView(controller: c)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'deduplicated capture preserves existing project and course ownership',
    () async {
      final bytes = Uint8List.fromList([99, 88, 77]);
      final original = await c.importProjectAttachment('shared.bin', bytes);
      expect(original.properties['project'], brief.id);
      await c.selectProject(other.id);
      final reused = await c.importProjectAttachment('shared-again.bin', bytes);
      expect(reused.id, original.id);
      expect(reused.properties['project'], brief.id);
      expect(c.find(original.id)!.properties['project'], brief.id);
      final courseSource = await repo.importAttachment(
        name: 'course.bin',
        bytes: Uint8List.fromList([11, 12, 13]),
      );
      await repo.save(
        courseSource.copyWith(
          properties: {...courseSource.properties, 'course': 'Original course'},
        ),
      );
      c.mergeRepositoryObjects();
      final courseReuse = await c.importProjectAttachment(
        'course-again.bin',
        Uint8List.fromList([11, 12, 13]),
      );
      expect(courseReuse.properties['course'], 'Original course');
      expect(courseReuse.properties.containsKey('project'), isFalse);
    },
  );
  test(
    'reused creative reference keeps its original owner and capture provenance',
    () async {
      final first = (await c.create(
        'orbit.canvas',
        title: 'First board',
        properties: {'project': brief.id},
      ))!;
      final second = (await c.create(
        'orbit.canvas',
        title: 'Second board',
        properties: {'project': other.id},
      ))!;
      final bytes = Uint8List.fromList([55, 66, 77]);
      final original = await c.captureCreativeReference(
        first.id,
        'shared.bin',
        bytes,
      );
      final reused = await c.captureCreativeReference(
        second.id,
        'shared.bin',
        bytes,
      );
      expect(reused.id, original.id);
      expect(reused.properties['project'], brief.id);
      expect(reused.properties['referenceBoardId'], first.id);
    },
  );
}
