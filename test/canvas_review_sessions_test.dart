import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/collaboration_controller.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:orbit_note/domain/collaboration.dart';
import 'package:orbit_note/features/workspace/canvas_conflict_dialog.dart';
import 'canvas_shared_presence_test.dart' show CanvasSessions;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CanvasSessions f;
  setUp(() async {
    HttpOverrides.global = null;
    f = CanvasSessions();
    await f.open();
  });
  tearDown(() => f.close());

  Future<void> conflict() async {
    f.edit(f.firstWorkspace, 0, 30);
    f.edit(f.firstWorkspace, 1, 140);
    f.edit(f.secondWorkspace, 0, 50);
    f.edit(f.secondWorkspace, 2, 250);
    await f.first.pump();
    await f.second.pump();
    expect(f.second.canReviewCanvas(f.id), isTrue);
  }

  test(
    'reviewed mixed changes converge, survive repository reopen and do not duplicate IDs',
    () async {
      await conflict();
      final review = await f.second.reviewCanvas(f.id);
      expect(review.comparison.placements.map((p) => p.id), [f.ids[0]]);
      await f.second.resolveCanvas(review, {
        f.ids[0]: CanvasConflictSide.local,
      });
      await f.first.pump();
      expect(
        f.firstWorkspace.find(f.id)!.data,
        f.secondWorkspace.find(f.id)!.data,
      );
      final data = f.secondWorkspace.find(f.id)!.data;
      expect(
        [for (final e in (data['elements'] as List).take(3)) e['x']],
        [50, 140, 250],
      );
      expect(data['future'], {'retained': true});
      expect(
        (data['elements'] as List).map((e) => e['id']).toSet(),
        hasLength(64),
      );
      expect(f.second.conflicts, isEmpty);
      expect(f.second.pendingChanges, 0);
      await f.secondRepo.initialize();
      expect(f.secondRepo.objects.singleWhere((o) => o.id == f.id).data, data);
    },
  );
  test(
    'new local edit invalidates a review instead of overwriting a draft',
    () async {
      await conflict();
      final review = await f.second.reviewCanvas(f.id);
      f.edit(f.secondWorkspace, 0, 99);
      await expectLater(
        f.second.resolveCanvas(review, {f.ids[0]: CanvasConflictSide.shared}),
        throwsStateError,
      );
      expect(f.secondWorkspace.find(f.id)!.data['elements'][0]['x'], 99);
      expect(f.second.conflicts, contains(f.id));
    },
  );
  test(
    'new shared edit invalidates a review before any local mutation',
    () async {
      await conflict();
      final review = await f.second.reviewCanvas(f.id);
      f.edit(f.firstWorkspace, 0, 77);
      await f.first.pump();
      await expectLater(
        f.second.resolveCanvas(review, {f.ids[0]: CanvasConflictSide.shared}),
        throwsStateError,
      );
      expect(f.secondWorkspace.find(f.id)!.data['elements'][0]['x'], 50);
      final next = await f.second.reviewCanvas(f.id);
      expect(next.comparison.placements.single.shared!['x'], 77);
    },
  );
  test(
    'reconnecting or adopting shared content invalidates outstanding choices',
    () async {
      await conflict();
      final review = await f.second.reviewCanvas(f.id);
      await f.second.adoptServer(f.id);
      await expectLater(
        f.second.resolveCanvas(review, {f.ids[0]: CanvasConflictSide.local}),
        throwsStateError,
      );
      await f.second.connect(f.endpoint, f.room, f.secondToken);
      await expectLater(
        f.second.resolveCanvas(review, {f.ids[0]: CanvasConflictSide.local}),
        throwsStateError,
      );
      expect(f.second.conflicts, isEmpty);
    },
  );
  test(
    'divergent reconnect without a known base cannot invent a placement merge',
    () async {
      f.edit(f.secondWorkspace, 0, 123);
      await f.second.connect(f.endpoint, f.room, f.secondToken);
      expect(f.second.conflicts, contains(f.id));
      expect(f.second.canReviewCanvas(f.id), isFalse);
      await expectLater(f.second.reviewCanvas(f.id), throwsStateError);
    },
  );
  test(
    'failed local save preserves the conflict and prevents publishing a resolution',
    () async {
      await conflict();
      final review = await f.second.reviewCanvas(f.id);
      f.secondStore.failWrites = true;
      try {
        await expectLater(
          f.second.resolveCanvas(review, {f.ids[0]: CanvasConflictSide.shared}),
          throwsStateError,
        );
        expect(f.second.conflicts, contains(f.id));
        final server = await f.first.inspectRoom(
          f.endpoint,
          f.room,
          f.firstToken,
        );
        expect(server['documents'][f.id]['version'], review.serverVersion);
        expect(f.secondWorkspace.failures, contains(f.id));
      } finally {
        f.secondStore.failWrites = false;
      }
      await f.secondWorkspace.flush(f.id);
      final next = await f.second.reviewCanvas(f.id);
      await f.second.resolveCanvas(next, {
        for (final p in next.comparison.placements)
          p.id: CanvasConflictSide.local,
      });
      expect(f.second.conflicts, isEmpty);
    },
  );
  test(
    'lost resolution acknowledgement replays once and retains later edits',
    () async {
      await conflict();
      // Resolve on Alice, whose transport can lose an acknowledgement.
      await f.first.pump();
      // Alice's already-acknowledged board has no conflict; Bob publishes a later
      // overlapping edit directly after first adopting, to establish a fresh race.
      await f.second.adoptServer(f.id);
      f.edit(f.firstWorkspace, 0, 70);
      f.edit(f.secondWorkspace, 0, 80);
      await f.second.pump();
      await f.first.pump();
      final review = await f.first.reviewCanvas(f.id);
      f.transport.loseNextEdit = true;
      await f.first.resolveCanvas(review, {f.ids[0]: CanvasConflictSide.local});
      expect(f.first.pendingChanges, 1);
      f.edit(f.firstWorkspace, 3, 390);
      await f.first.retryNow();
      await f.first.pump();
      await f.second.pump();
      expect(
        f.firstWorkspace.find(f.id)!.data,
        f.secondWorkspace.find(f.id)!.data,
      );
      expect(f.firstWorkspace.find(f.id)!.data['elements'][0]['x'], 70);
      expect(f.firstWorkspace.find(f.id)!.data['elements'][3]['x'], 390);
      expect(f.first.pendingChanges, 0);
    },
  );

  test(
    'native resolution retains the complete before-image and reopens portable data',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-canvas-review-history-',
      );
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      final workspace = WorkspaceController()..repository = repo;
      final controller = CollaborationController(
        workspace,
        http.Client(),
        automaticPolling: false,
      );
      try {
        for (final entry in f.secondStore.files.entries) {
          final target = File(p.join(root.path, entry.key));
          await target.parent.create(recursive: true);
          await target.writeAsBytes(entry.value);
        }
        await workspace.initialize(path: root.path);
        workspace.pausePdfIndex(true);
        workspace.cancelAllTimers();
        await controller.connect(f.endpoint, f.room, f.secondToken);
        f.edit(f.firstWorkspace, 0, 30);
        f.edit(workspace, 0, 50);
        await f.first.pump();
        await controller.pump();
        final review = await controller.reviewCanvas(f.id);
        final authoredPath = p.join(root.path, repo.objectPath(f.id)!);
        final original = await File(authoredPath).readAsBytes();
        await controller.resolveCanvas(review, {
          f.ids[0]: CanvasConflictSide.shared,
        });
        final beforeImages = await Directory(
          p.join(root.path, '.orbit', 'history'),
        ).list().where((e) => e is File).cast<File>().toList();
        final retained = <String>[];
        for (final file in beforeImages) {
          retained.add(base64Encode(await file.readAsBytes()));
        }
        expect(retained, contains(base64Encode(original)));
        controller.disconnect();
        await workspace.initialize(path: root.path);
        workspace.pausePdfIndex(true);
        workspace.cancelAllTimers();
        expect(workspace.find(f.id)!.data['elements'][0]['x'], 30);
        expect(workspace.find(f.id)!.data['future'], {'retained': true});
      } finally {
        controller.dispose();
        workspace.cancelAllTimers();
        await workspace.closeWorkspace();
        if (!p.isWithin(
          Directory.systemTemp.absolute.path,
          root.absolute.path,
        )) {
          throw StateError('Unexpected fixture path');
        }
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'a shared edit arriving during local resolution saving remains a new review conflict',
    () async {
      await conflict();
      final review = await f.second.reviewCanvas(f.id);
      final gate = Completer<void>();
      f.secondStore.writeGate = gate.future;
      final result = expectLater(
        f.second.resolveCanvas(review, {f.ids[0]: CanvasConflictSide.local}),
        throwsStateError,
      );
      try {
        for (
          var i = 0;
          i < 200 && !f.secondWorkspace.dirty.contains(f.id);
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        expect(f.secondWorkspace.dirty, contains(f.id));
        f.edit(f.firstWorkspace, 0, 77);
        await f.first.pump();
      } finally {
        gate.complete();
        f.secondStore.writeGate = null;
      }
      await result;
      expect(f.second.canReviewCanvas(f.id), isTrue);
      expect(f.secondWorkspace.find(f.id)!.data['elements'][0]['x'], 50);
      final latest = await f.second.reviewCanvas(f.id);
      expect(latest.comparison.placements.single.shared!['x'], 77);
      expect(f.secondWorkspace.failures, isEmpty);
    },
  );

  testWidgets(
    'compact enlarged review requires a choice and exposes removal-safe language',
    (tester) async {
      await tester.runAsync(conflict);
      final review = (await tester.runAsync(
        () => f.second.reviewCanvas(f.id),
      ))!;
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: CanvasConflictDialog(controller: f.second, review: review),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save resolution & sync'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Choose all mine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose all mine'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save resolution & sync'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
