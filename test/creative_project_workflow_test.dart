import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/workspace/milestone_view.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/memory_store.dart';

class FixedNativeStore extends NativeWorkspaceStore {
  FixedNativeStore(this.path);
  final String path;
  @override
  Future<void> initialize({String? path}) =>
      super.initialize(path: path ?? this.path);
}

class PartialProjectRepository extends WorkspaceRepository {
  PartialProjectRepository()
    : super(store: FolderMemoryStore(), index: MemoryObjectIndex());
  @override
  Future<UniversalObject> create({
    required String typeId,
    required String title,
    String body = '',
    Map<String, dynamic> properties = const {},
    Map<String, dynamic> data = const {},
  }) {
    if (title.endsWith('— Decisions')) {
      throw StateError('Simulated interruption');
    }
    return super.create(
      typeId: typeId,
      title: title,
      body: body,
      properties: properties,
      data: data,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<(ProviderContainer, WorkspaceController)> controllerFor(
    WorkspaceRepository repo,
  ) async {
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    final controller = container.read(workspaceProvider.notifier);
    for (var i = 0; i < 200 && controller.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(controller.loading, isFalse);
    return (container, controller);
  }

  test(
    'creative project links canonical objects, prevents duplicates and survives native restart',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-creative-');
      final repo = WorkspaceRepository(
        store: FixedNativeStore(root.path),
        index: MemoryObjectIndex(),
      );
      final (container, controller) = await controllerFor(repo);
      try {
        final brief = await controller.createCreativeProject(
          'Forest Film',
          briefBody: '# Forest Film\n\nAudience: young adults.',
        );
        expect(brief, isNotNull, reason: controller.error);
        final board = controller.find(
          brief!.properties['projectBoardId'] as String,
        )!;
        final refs = controller.find(
          brief.properties['referenceBoardId'] as String,
        )!;
        final view = controller.find(
          brief.properties['milestoneViewId'] as String,
        )!;
        final tasks = controller.activeObjects
            .where(
              (o) =>
                  o.typeId == 'orbit.task' &&
                  o.properties['project'] == brief.id,
            )
            .toList();
        expect(tasks, hasLength(4));
        expect(view.properties['milestoneStages'], [
          'Explore',
          'Decide',
          'Produce',
          'Review',
        ]);
        final placements = (board.data['elements'] as List)
            .cast<Map>()
            .where((e) => e['type'] == 'card')
            .toList();
        expect(
          placements.where((p) => tasks.any((t) => t.id == p['objectId'])),
          hasLength(4),
        );
        expect(placements.any((p) => p['objectId'] == refs.id), isTrue);
        expect(brief.body, contains('[[${board.id}|'));
        final count = controller.objects.length;
        expect(
          await controller.createCreativeProject('forest film', briefBody: ''),
          isNull,
        );
        expect(controller.objects, hasLength(count));
        expect(controller.error, contains('already exists'));
        expect(
          await controller.createCreativeProject('../unsafe', briefBody: ''),
          isNull,
        );
        expect(controller.objects, hasLength(count));
        // Removing a placement persists while its source remains available.
        final changed = {
          ...board.data,
          'elements': (board.data['elements'] as List)
              .where((e) => (e as Map)['objectId'] != tasks.first.id)
              .toList(),
        };
        await repo.save(board.copyWith(data: changed));
        await repo.save(tasks.first.copyWith(title: 'Renamed deliverable'));
        await repo.close();
        final reopened = WorkspaceRepository(
          store: FixedNativeStore(root.path),
          index: MemoryObjectIndex(),
        );
        try {
          await reopened.initialize();
          final restored = reopened.objects.firstWhere((o) => o.id == board.id);
          expect(
            (restored.data['elements'] as List).any(
              (e) => (e as Map)['objectId'] == tasks.first.id,
            ),
            isFalse,
          );
          expect(
            reopened.objects.firstWhere((o) => o.id == tasks.first.id).title,
            'Renamed deliverable',
          );
          expect(
            reopened.objects
                .firstWhere((o) => o.id == view.id)
                .properties['milestoneStages'],
            view.properties['milestoneStages'],
          );
        } finally {
          await reopened.close();
        }
      } finally {
        container.dispose();
        await repo.close();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'interrupted scaffold retains saved knowledge and reports incomplete setup',
    () async {
      final repo = PartialProjectRepository();
      final (container, controller) = await controllerFor(repo);
      try {
        expect(
          await controller.createCreativeProject(
            'Interrupted',
            briefBody: '# Keep this brief',
          ),
          isNull,
        );
        expect(
          controller.activeObjects
              .where((o) => o.properties['isCreativeBrief'] == true)
              .single
              .body,
          '# Keep this brief',
        );
        expect(controller.error, contains('saved items remain available'));
      } finally {
        container.dispose();
        await repo.close();
      }
    },
  );
  testWidgets('creative milestone view uses project stages', (tester) async {
    final repo = WorkspaceRepository(
      store: FolderMemoryStore(),
      index: MemoryObjectIndex(),
    );
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    final controller = container.read(workspaceProvider.notifier);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await controller.createCreativeProject('Poster', briefBody: '# Poster');
    });
    try {
      final brief = controller.activeObjects.firstWhere(
        (o) => o.properties['isCreativeBrief'] == true,
      );
      final view = controller.find(
        brief.properties['milestoneViewId'] as String,
      )!;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: MilestoneView(
              controller: controller,
              viewObject: view,
              scope: brief.id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Vertical Slice'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    } finally {
      container.dispose();
      await tester.runAsync(repo.close);
    }
  });
  for (final useMenu in [true, false]) {
    testWidgets(
      'section removal through ${useMenu ? 'interior context menu' : 'visible delete button'} retains children and undoes',
      (tester) async {
        Map<String, dynamic> data = {
          'schemaVersion': 1,
          'extension': 'keep',
          'elements': [
            {
              'id': 'column',
              'type': 'column',
              'text': 'Inspiration',
              'x': 50.0,
              'y': 50.0,
              'width': 260.0,
              'height': 300.0,
            },
            {
              'id': 'card',
              'type': 'card',
              'objectId': 'source',
              'columnId': 'column',
              'x': 66.0,
              'y': 105.0,
              'width': 180.0,
              'height': 100.0,
            },
          ],
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'board',
                data: data,
                objects: const [],
                onOpenObject: (_) {},
                onChanged: (v) => data = v,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final surface = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
        );
        final origin = tester.getTopLeft(surface);
        if (useMenu) {
          final click = await tester.startGesture(
            origin + const Offset(100, 270),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await click.up();
          await tester.pumpAndSettle();
          await tester.tap(find.text('Remove from canvas'));
        } else {
          await tester.tapAt(origin + const Offset(100, 70));
          await tester.pump();
          await tester.tap(
            find.byKey(const ValueKey('canvas-remove-selection')),
          );
        }
        await tester.pumpAndSettle();
        final remaining = (data['elements'] as List).single as Map;
        expect(remaining['objectId'], 'source');
        expect(remaining['columnId'], isNull);
        expect(data['extension'], 'keep');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(data['elements'], hasLength(2));
        expect(
          (data['elements'] as List).cast<Map>().firstWhere(
            (e) => e['id'] == 'card',
          )['columnId'],
          'column',
        );
      },
    );
  }
}
