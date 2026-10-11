import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/study_card.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/study_workspace.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/object_codec.dart';
import 'support/memory_store.dart';

void main() {
  late MemoryStore store;
  late WorkspaceRepository repo;
  late ProviderContainer container;
  late WorkspaceController c;
  final now = DateTime.utc(2026, 10, 9, 12);
  Future<void> open() async {
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    for (var i = 0; i < 200 && c.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(c.hasWorkspace, true);
  }

  Future<UniversalObject> card({
    String course = 'Math',
    UniversalObject? source,
  }) async => (await c.createStudyCard(
    question: 'What is a basis?',
    answer: '**Independent** spanning vectors.',
    course: course,
    source: source,
    passage: 'A basis spans the vector space.',
    now: now,
  ))!;
  setUp(() async {
    store = MemoryStore();
    await open();
  });
  tearDown(() async {
    await c.closeWorkspace();
    container.dispose();
  });

  test(
    'source-linked Markdown card survives restart and an empty derived index',
    () async {
      final source = (await c.create(
        'orbit.note',
        title: 'Lecture',
        body: 'Original source',
        properties: {'course': 'Math'},
      ))!;
      final saved = await card(source: source);
      expect(saved.typeId, 'orbit.note');
      expect(StudyCard(saved).source!['objectId'], source.id);
      expect(c.backlinks(source.id).map((o) => o.id), contains(saved.id));
      expect(
        c.linkedMentions(source.id).where((m) => m.source.id == saved.id),
        hasLength(1),
      );
      expect(c.find(source.id)!.body, 'Original source');
      await c.closeWorkspace();
      container.dispose();
      await open();
      final rebuilt = c.find(saved.id)!;
      expect(rebuilt.body, saved.body);
      expect(rebuilt.properties['studyCard'], saved.properties['studyCard']);
      expect(studyQueue(c.studyCards, now).single.id, saved.id);
    },
  );

  for (final (rating, days) in [
    (StudyRating.hard, 1),
    (StudyRating.good, 3),
    (StudyRating.easy, 7),
  ]) {
    test(
      '${rating.name} first review schedules $days days with portable history',
      () async {
        final saved = await card();
        expect(await c.reviewStudyCard(saved, rating, now: now), true);
        final reviewed = StudyCard(c.find(saved.id)!);
        expect(reviewed.due, now.add(Duration(days: days)));
        expect(reviewed.history.single['rating'], rating.name);
        expect(studyQueue(c.studyCards, now), isEmpty);
        await c.closeWorkspace();
        container.dispose();
        await open();
        expect(
          StudyCard(c.find(saved.id)!).history.single['previousIntervalDays'],
          0,
        );
      },
    );
  }

  test('Again returns in ten minutes and cannot be reviewed early', () async {
    final saved = await card();
    expect(await c.reviewStudyCard(saved, StudyRating.again, now: now), true);
    final current = c.find(saved.id)!;
    expect(StudyCard(current).due, now.add(const Duration(minutes: 10)));
    expect(await c.reviewStudyCard(current, StudyRating.good, now: now), false);
    expect(StudyCard(c.find(saved.id)!).history, hasLength(1));
    expect(
      await c.reviewStudyCard(
        current,
        StudyRating.good,
        now: now.add(const Duration(minutes: 10)),
      ),
      true,
    );
  });

  test(
    'failed review keeps the queue and history; retry writes only one review',
    () async {
      final saved = await card();
      final files = {...store.files};
      store.failWrites = true;
      expect(await c.reviewStudyCard(saved, StudyRating.good, now: now), false);
      expect(store.files, files);
      expect(StudyCard(c.find(saved.id)!).history, isEmpty);
      expect(studyQueue(c.studyCards, now), hasLength(1));
      store.failWrites = false;
      expect(
        await c.reviewStudyCard(c.find(saved.id)!, StudyRating.good, now: now),
        true,
      );
      expect(StudyCard(c.find(saved.id)!).history, hasLength(1));
    },
  );

  test(
    'stale and concurrent reviews cannot overwrite or double-rate',
    () async {
      final saved = await card();
      final results = await Future.wait([
        c.reviewStudyCard(saved, StudyRating.good, now: now),
        c.reviewStudyCard(saved, StudyRating.easy, now: now),
      ]);
      expect(results.where((v) => v), hasLength(1));
      expect(await c.reviewStudyCard(saved, StudyRating.easy, now: now), false);
      expect(StudyCard(c.find(saved.id)!).history, hasLength(1));
    },
  );

  test(
    'undo rating restores schedule and history; later changes prevent undo',
    () async {
      final saved = await card();
      expect(await c.reviewStudyCard(saved, StudyRating.good, now: now), true);
      expect(await c.undoPlanning(), true);
      expect(StudyCard(c.find(saved.id)!).due, now);
      expect(StudyCard(c.find(saved.id)!).history, isEmpty);
      expect(
        await c.reviewStudyCard(c.find(saved.id)!, StudyRating.good, now: now),
        true,
      );
      c.edit(saved.id, body: 'Later edit');
      expect(await c.undoPlanning(), false);
      expect(c.find(saved.id)!.body, 'Later edit');
    },
  );

  test('card edits and undo retain source, history and unknown keys', () async {
    final saved = await card();
    await repo.save(
      saved.copyWith(
        properties: {
          ...saved.properties,
          'studyCard': {
            ...StudyCard(saved).record,
            'plugin': {'keep': true},
          },
        },
      ),
    );
    c.mergeRepositoryObjects();
    final current = c.find(saved.id)!;
    expect(
      await c.editStudyCard(current, 'New question', 'New answer', 'Physics'),
      true,
    );
    expect(StudyCard(c.find(saved.id)!).record['plugin'], {'keep': true});
    expect(await c.undoPlanning(), true);
    expect(c.find(saved.id)!.body, saved.body);
    expect(c.find(saved.id)!.title, saved.title);
  });

  test('pause and course/exam filters operate on canonical objects', () async {
    final math = await card();
    final physics = await card(course: 'Physics');
    expect(await c.reviewStudyCard(math, StudyRating.good, now: now), true);
    expect(studyQueue(c.studyCards, now, course: 'Math'), isEmpty);
    expect(
      studyQueue(
        c.studyCards,
        now,
        course: 'Math',
        horizon: now.add(const Duration(days: 3)),
      ).single.id,
      math.id,
    );
    expect(await c.suspendStudyCard(physics, true), true);
    expect(studyQueue(c.studyCards, now), isEmpty);
    expect(await c.suspendStudyCard(c.find(physics.id)!, false), true);
    expect(studyQueue(c.studyCards, now).single.id, physics.id);
  });

  test('edited/deleted source warns and preserves captured evidence', () async {
    final source = (await c.create('orbit.note', title: 'Lecture'))!;
    final saved = await card(source: source);
    expect(c.studySourceWarning(saved), null);
    c.edit(source.id, body: 'Changed');
    await c.flush(source.id);
    expect(c.studySourceWarning(saved), contains('edited'));
    await c.trash(source.id);
    expect(c.studySourceWarning(saved), contains('missing'));
    expect(
      StudyCard(c.find(saved.id)!).source!['passage'],
      'A basis spans the vector space.',
    );
    expect(c.openStudySource(saved), false);
  });

  test(
    'PDF highlight cards retain page navigation without copying attachment',
    () async {
      final pdf = (await c.create(
        'orbit.file',
        title: 'Textbook',
        properties: {'mimeType': 'application/pdf'},
      ))!;
      final highlight = (await c.create(
        'orbit.note',
        title: 'Highlight',
        body: '> evidence',
        properties: {
          'pdfSource': {'objectId': pdf.id, 'page': 7, 'checksum': 'a' * 64},
        },
      ))!;
      final saved = await card(source: highlight);
      expect(c.openStudySource(saved), true);
      expect(c.session.secondaryId, pdf.id);
      expect(c.session.noteViews['pdf:secondary:${pdf.id}']!['page'], 7);
      expect(StudyCard(saved).source!['objectId'], highlight.id);
    },
  );

  test('export retains UUIDs, Markdown, metadata and history', () async {
    final saved = await card();
    await c.reviewStudyCard(saved, StudyRating.easy, now: now);
    final json = jsonDecode(exportStudyCards(c.studyCards)) as Map;
    final exported = (json['cards'] as List).single as Map;
    expect(json['format'], 'orbit-note-study');
    expect(exported['id'], saved.id);
    expect(exported['body'], saved.body);
    expect(
      (exported['properties']['studyCard']['history'] as List),
      hasLength(1),
    );
  });

  test(
    'OCR passage cards verify actual source bytes and retain page/checksum',
    () async {
      final file = await repo.importAttachment(
        name: 'scan.png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      c.mergeRepositoryObjects();
      final checksum = file.properties['checksum'] as String;
      final saved = await c.createStudyCard(
        question: 'What was scanned?',
        answer: 'Evidence',
        source: c.find(file.id),
        passage: 'Evidence',
        page: 1,
        checksum: checksum,
        now: now,
      );
      expect(saved, isNotNull);
      expect(StudyCard(saved!).source!['checksum'], checksum);
      expect(StudyCard(saved).source!['page'], 1);
      final path = file.properties['contentRef'] as String;
      store.files[path] = Uint8List.fromList([9, 9, 9]);
      expect(
        await c.createStudyCard(
          question: 'Stale?',
          answer: 'No',
          source: c.find(file.id),
          checksum: checksum,
          passage: 'Evidence',
          page: 1,
        ),
        null,
      );
      expect(c.studyCards, hasLength(1));
    },
  );

  test(
    'repeated reviews grow intervals; long intervals clamp and unknown entries survive',
    () async {
      final saved = await card();
      await c.reviewStudyCard(saved, StudyRating.good, now: now);
      final first = c.find(saved.id)!;
      await c.reviewStudyCard(
        first,
        StudyRating.good,
        now: StudyCard(first).due,
      );
      final second = c.find(saved.id)!;
      expect(StudyCard(second).record['intervalDays'], 6);
      final extended = {
        ...StudyCard(second).record,
        'intervalDays': 3000,
        'history': [
          for (final h in StudyCard(second).history) {...h, 'plugin': 'keep'},
        ],
      };
      await repo.save(
        second.copyWith(
          properties: {...second.properties, 'studyCard': extended},
        ),
      );
      c.mergeRepositoryObjects();
      final long = c.find(saved.id)!;
      await c.reviewStudyCard(long, StudyRating.easy, now: StudyCard(long).due);
      final finalCard = StudyCard(c.find(saved.id)!);
      expect(finalCard.record['intervalDays'], 3650);
      expect(finalCard.history.first['plugin'], 'keep');
    },
  );

  test(
    'review clock rollback and suspended reviews reject without mutation',
    () async {
      final saved = await card();
      expect(
        await c.reviewStudyCard(
          saved,
          StudyRating.good,
          now: now.subtract(const Duration(seconds: 1)),
        ),
        false,
      );
      await c.suspendStudyCard(saved, true);
      expect(
        await c.reviewStudyCard(c.find(saved.id)!, StudyRating.good, now: now),
        false,
      );
      expect(StudyCard(c.find(saved.id)!).history, isEmpty);
    },
  );

  test(
    'failed card edits retain answer, source and course and can retry',
    () async {
      final saved = await card();
      store.failWrites = true;
      expect(
        await c.editStudyCard(saved, 'Revised', 'Changed', 'Physics'),
        false,
      );
      expect(c.find(saved.id)!.body, saved.body);
      store.failWrites = false;
      expect(
        await c.editStudyCard(
          c.find(saved.id)!,
          'Revised',
          'Changed',
          'Physics',
        ),
        true,
      );
      expect(c.find(saved.id)!.properties['course'], 'Physics');
    },
  );

  test(
    'deleted cards leave the queue and restore with schedule intact',
    () async {
      final saved = await card();
      await c.trash(saved.id);
      expect(studyQueue(c.studyCards, now), isEmpty);
      await repo.restore(saved.id);
      c.mergeRepositoryObjects();
      expect(studyQueue(c.studyCards, now).single.id, saved.id);
    },
  );

  test(
    'future metadata survives unrelated edits and never enters queue',
    () async {
      final saved = await card();
      final path = repo.objectPath(saved.id)!;
      store.files[path] = Uint8List.fromList(
        utf8.encode(
          ObjectCodec().encode(
            saved.copyWith(
              properties: {
                ...saved.properties,
                'studyCard': {...StudyCard(saved).record, 'version': 2},
              },
            ),
          ),
        ),
      );
      await c.closeWorkspace();
      container.dispose();
      // A future record is imported by file parsing, not accepted as a new command.
      await open();
      expect(c.find(saved.id)!.properties['studyCard']['version'], 2);
      expect(c.studyCards, isEmpty);
      c.edit(saved.id, title: 'Still editable');
      await c.flush(saved.id);
      expect(c.find(saved.id)!.properties['studyCard']['version'], 2);
    },
  );

  test(
    'invalid schedule and unsupported versions are rejected without writes',
    () async {
      final saved = await card();
      final files = {...store.files};
      for (final raw in [
        {...StudyCard(saved).record, 'version': 2},
        {...StudyCard(saved).record, 'due': 'not a date'},
        {...StudyCard(saved).record, 'intervalDays': -1},
        {
          ...StudyCard(saved).record,
          'history': [
            {'rating': 'fake'},
          ],
        },
      ]) {
        await expectLater(
          repo.save(
            saved.copyWith(properties: {...saved.properties, 'studyCard': raw}),
          ),
          throwsFormatException,
        );
      }
      expect(store.files, files);
    },
  );

  test(
    'understanding state is explicit, persistent and never inferred from reviews',
    () async {
      final source = (await c.create('orbit.note', title: 'Concept'))!;
      expect(await c.markStudyUnderstanding(source, 'uncertain'), true);
      final saved = await card(source: c.find(source.id)!);
      await c.reviewStudyCard(saved, StudyRating.easy, now: now);
      expect(c.find(source.id)!.properties['studyUnderstanding'], 'uncertain');
      await c.closeWorkspace();
      container.dispose();
      await open();
      expect(c.find(source.id)!.properties['studyUnderstanding'], 'uncertain');
      expect(
        await c.markStudyUnderstanding(c.find(source.id)!, 'mastered'),
        false,
      );
    },
  );

  test(
    'card creation is serialized and Vault closure waits for its durable write',
    () async {
      final gate = Completer<void>();
      store.writeGate = gate.future;
      final first = c.createStudyCard(
        question: 'Durable?',
        answer: 'Yes',
        now: now,
      );
      final duplicate = await c.createStudyCard(
        question: 'Duplicate?',
        answer: 'No',
        now: now,
      );
      expect(duplicate, null);
      var closed = false;
      final closing = c.closeWorkspace().then((_) => closed = true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(closed, false);
      gate.complete();
      final saved = await first;
      expect(saved, isNotNull);
      await closing;
      expect(closed, true);
      container.dispose();
      await open();
      expect(c.find(saved!.id)!.body, 'Yes');
      expect(c.studyCards, hasLength(1));
    },
  );

  testWidgets('review reveal, keyboard rating and caught-up feedback', (
    tester,
  ) async {
    final saved = await tester.runAsync(
      () => c.createStudyCard(
        question: 'Recall this concept',
        answer: 'An exact answer\n\n\$\$\nx^2\n\$\$',
        now: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: StudyWorkspace(controller: c)),
        ),
      ),
    );
    expect(find.text('An exact answer'), findsNothing);
    await tester.tap(find.text('Reveal answer'));
    await tester.pump();
    expect(find.text('An exact answer'), findsOneWidget);
    expect(find.byType(Math), findsOneWidget);
    await tester.runAsync(() => tester.sendKeyEvent(LogicalKeyboardKey.digit3));
    await tester.pumpAndSettle();
    expect(StudyCard(c.find(saved!.id)!).history, hasLength(1));
    expect(find.textContaining('caught up'), findsOneWidget);
  });

  testWidgets('compact large-text workspace and card editor have no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(380, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => card(course: 'A long course title with extra descriptive words'),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(body: StudyWorkspace(controller: c)),
        ),
      ),
    );
    expect(tester.takeException(), null);
    await tester.ensureVisible(find.text('Cards'));
    await tester.tap(find.text('Cards'));
    await tester.pump();
    expect(tester.takeException(), null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showStudyCardEditor(context, c),
              child: const Text('Editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Editor'));
    await tester.pumpAndSettle();
    expect(find.text('New study card'), findsOneWidget);
    expect(tester.takeException(), null);
  });
}
