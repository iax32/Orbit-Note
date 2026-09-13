import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'support/memory_store.dart';

class TestFolderStore extends MemoryStore implements WorkspaceFolderStore {
  final folders = <String>['Notes'];
  @override
  Future<List<String>> listFolders() async => List.of(folders);
  @override
  Future<void> createFolder(String path) async {
    if (!folders.contains(path)) {
      folders.add(path);
    }
  }

  @override
  Future<void> deleteFolder(String path) async {
    folders.remove(path);
    folders.removeWhere((f) => f.startsWith('$path/'));
    files.removeWhere((k, _) => k.startsWith('$path/'));
  }

  @override
  Future<void> movePath(
    String source,
    String target,
    Map<String, FileReplacement> replacements,
  ) async {
    final content = files.remove(source);
    if (content != null) {
      files[target] = content;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Canvas in Notes Explorer Navigation', () {
    late ProviderContainer container;
    late WorkspaceController controller;

    setUp(() async {
      final repo = WorkspaceRepository(
        store: TestFolderStore(),
        index: MemoryObjectIndex(),
      );
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      controller = container.read(workspaceProvider.notifier);
      await controller.initialize();
    });

    tearDown(() => container.dispose());

    test(
      'creating and opening a canvas while in notes explorer stays in notes explorer',
      () async {
        controller.navigate(OrbitDestination.notes);
        expect(controller.session.destination, OrbitDestination.notes);

        // Create a canvas with a folder inside Notes Explorer
        final canvas = await controller.create(
          'orbit.canvas',
          title: 'Math Exercises',
          properties: {'folder': 'akmath/exercises'},
        );
        expect(canvas, isNotNull);
        // Destination must remain notes!
        expect(controller.session.destination, OrbitDestination.notes);
        expect(controller.session.activeId, canvas!.id);

        // Re-opening the canvas must keep destination as notes
        controller.openObject(canvas.id);
        expect(controller.session.destination, OrbitDestination.notes);

        // Creating a canvas via createExerciseCanvas also retains notes destination
        final exercise = await controller.createExerciseCanvas(
          folder: 'akmath/exercises',
          title: 'Exercise 01',
        );
        expect(exercise, isNotNull);
        expect(controller.session.destination, OrbitDestination.notes);
        expect(controller.session.activeId, exercise!.id);
      },
    );

    test(
      'opening an object with a folder property from home opens in notes explorer',
      () async {
        final canvas = await controller.create(
          'orbit.canvas',
          title: 'Game Loop',
          properties: {'folder': 'MyGame/Design'},
        );
        expect(canvas, isNotNull);

        // User goes to Home
        controller.session.destination = OrbitDestination.home;
        controller.session.activeId = null;

        // User opens canvas that has a folder
        controller.openObject(canvas!.id);
        expect(controller.session.destination, OrbitDestination.notes);
        expect(controller.session.activeId, canvas.id);
      },
    );

    test(
      'opening a flat canvas from canvas gallery preserves canvas destination',
      () async {
        final flatCanvas = await controller.create(
          'orbit.canvas',
          title: 'Quick Scratchpad',
        );
        expect(flatCanvas, isNotNull);

        // Navigate explicitly to Canvas rail gallery
        controller.navigate(OrbitDestination.canvas);
        expect(controller.session.destination, OrbitDestination.canvas);

        // Open the flat canvas from canvas gallery
        controller.openObject(flatCanvas!.id);
        expect(controller.session.destination, OrbitDestination.canvas);
        expect(controller.session.activeId, flatCanvas.id);

        // Opening a note from canvas gallery switches to notes explorer
        final note = await controller.create(
          'orbit.note',
          title: 'Meeting Note',
        );
        expect(note, isNotNull);
        controller.openObject(note!.id);
        expect(controller.session.destination, OrbitDestination.notes);
      },
    );
  });

  group('Canvas Card Templates & Standalone Cards', () {
    testWidgets(
      'renders standalone cards and template cards cleanly without error fallback',
      (tester) async {
        final canvasData = {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'elem-1',
              'type': 'card',
              'text': 'Input Manager\n(Keyboard / Gamepad / Touch)',
              'x': 100.0,
              'y': 100.0,
              'width': 220.0,
              'height': 90.0,
              'color': 0xff8b7cf6,
            },
            {
              'id': 'elem-2',
              'type': 'card',
              'text': 'Player Controller\n(Movement, States, Physics)',
              'x': 340.0,
              'y': 100.0,
              'width': 220.0,
              'height': 90.0,
              'color': 0xff6f7fea,
            },
            {
              'id': 'elem-3',
              'type': 'card',
              'objectId': 'missing-obj-id',
              'text': 'Cached Subsystem\n(Fallback text)',
              'x': 580.0,
              'y': 100.0,
              'width': 220.0,
              'height': 90.0,
              'color': 0xff65c6a3,
            },
          ],
        };

        Map<String, dynamic> latest = canvasData;
        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'test-canvas',
                data: latest,
                onChanged: (v) => latest = v,
                objects: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Ensure no exceptions occurred during custom paint
        expect(tester.takeException(), isNull);

        // Right-click on the first card (at x=210, y=200 with toolbar) and select Open / edit to verify inline text editing activates
        await tester.tapAt(const Offset(210, 200), buttons: 2);
        await tester.pumpAndSettle();
        expect(find.text('Open / edit'), findsOneWidget);
        await tester.tap(find.text('Open / edit'));
        await tester.pumpAndSettle();

        // The inline TextField overlay must appear for standalone card editing
        expect(
          find.byKey(const ValueKey('canvas-element-text-field')),
          findsOneWidget,
        );
      },
    );

    testWidgets('empty canvas context menu includes Add Card option', (
      tester,
    ) async {
      Map<String, dynamic> latest = {'schemaVersion': 1, 'elements': []};
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'test-canvas',
              data: latest,
              onChanged: (v) => latest = v,
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Right click on empty canvas area
      await tester.tapAt(const Offset(300, 300), buttons: 2);
      await tester.pumpAndSettle();

      expect(find.text('Add Card'), findsOneWidget);
      expect(find.text('Add Sticky'), findsOneWidget);
      expect(find.text('Add Text'), findsOneWidget);

      // Tap Add Card
      await tester.tap(find.text('Add Card'));
      await tester.pumpAndSettle();

      // Element should have been added
      final elements = latest['elements'] as List;
      expect(elements.length, 1);
      expect(elements.first['type'], 'card');
    });
  });
}
