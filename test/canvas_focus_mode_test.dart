import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/workspace/workspace_shell.dart';
import 'package:orbit_note/features/workspace/orbit_tab_strip.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'support/capture_ui.dart';

Finder surface() => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
);

void main() {
  Future<(WorkspaceController, String)> mount(
    WidgetTester t,
    Size size, {
    double scale = 1,
  }) async {
    t.view.physicalSize = size * 2;
    t.view.devicePixelRatio = 2;
    t.view.padding = const FakeViewPadding(top: 48, bottom: 40);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPadding);
    late ProviderContainer container;
    late WorkspaceController c;
    late String boardId;
    await t.runAsync(() async {
      container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(
            WorkspaceRepository(
              store: MemoryStore(),
              index: MemoryObjectIndex(),
            ),
          ),
        ],
      );
      c = container.read(workspaceProvider.notifier);
      await c.initialize();
      c.pausePdfIndex(true);
      c.session.autoSnapshotOnClose = false;
      c.session.autoSaveInterval = 10000;
      await c.create('orbit.note', title: 'Reference notes', open: true);
      final board = (await c.create(
        'orbit.canvas',
        title: 'Tablet sketch',
        data: {
          'schemaVersion': 1,
          'future': {'preserved': true},
          'elements': [
            {
              'id': 'reference',
              'type': 'rectangle',
              'x': 40.0,
              'y': 40.0,
              'width': 100.0,
              'height': 80.0,
            },
          ],
        },
      ))!;
      boardId = board.id;
      c.session.sidebarVisible = true;
      c.session.inspectorVisible = true;
    });
    await prepareCapture(t);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: orbitDarkTheme().copyWith(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const WorkspaceShell(),
        ),
      ),
    );
    await t.pumpAndSettle();
    c.cancelAllTimers();
    addTearDown(() async {
      c.cancelAllTimers();
      await t.pumpWidget(const SizedBox());
      container.dispose();
    });
    return (c, boardId);
  }

  for (final size in [const Size(1024, 768), const Size(820, 1180)]) {
    testWidgets(
      'Canvas focus fills the safe tablet viewport and restores chrome at $size',
      (t) async {
        final (c, id) = await mount(t, size);
        final before = t.getSize(surface());
        final editor = t.state(find.byType(CanvasEditor));
        final tabs = List.of(c.session.tabs);
        final camera =
            (t.widget<CustomPaint>(surface()).painter as OrbitCanvasPainter)
                .camera;
        await t.tap(find.byTooltip('Show minimap'));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('canvas-minimap-card')),
          findsOneWidget,
        );
        await t.runAsync(() => t.tap(find.byTooltip('Focus on drawing')));
        await t.pumpAndSettle();
        final focused = t.getSize(surface());
        expect(focused.width, size.width);
        expect(focused.height, closeTo(size.height - 44, 1));
        expect(focused.height - before.height, greaterThan(90));
        expect(focused.width - before.width, greaterThan(40));
        expect(identical(editor, t.state(find.byType(CanvasEditor))), isTrue);
        expect(
          (t.widget<CustomPaint>(surface()).painter as OrbitCanvasPainter)
              .camera
              .zoom,
          camera.zoom,
        );
        expect(find.byType(OrbitTabStrip), findsNothing);
        expect(find.byKey(const ValueKey('canvas-minimap-card')), findsNothing);
        expect(find.byTooltip('Zoom in'), findsNothing);
        expect(find.byTooltip('Draw and erase'), findsNothing);
        expect(find.byTooltip('Exit Canvas focus'), findsOneWidget);
        expect(c.session.tabs, tabs);
        expect(c.session.sidebarVisible, isTrue);
        expect(c.session.inspectorVisible, isTrue);
        final dock = t.getRect(find.byKey(const ValueKey('canvas-focus-dock')));
        expect(dock.width, lessThanOrEqualTo(160));
        expect(dock.height, greaterThanOrEqualTo(48));
        expect(dock.top, greaterThanOrEqualTo(24));
        await captureUi(t, 'canvas-focus-${size.width.toInt()}');
        await t.tap(find.byTooltip('Show Canvas tools'));
        await t.pumpAndSettle();
        expect(t.getSize(surface()), focused);
        expect(find.byTooltip('Draw and erase'), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.byTooltip('Draw and erase'), findsNothing);
        await t.runAsync(() => t.tap(find.byTooltip('Exit Canvas focus')));
        await t.pumpAndSettle();
        expect(c.session.focusMode, isFalse);
        expect(identical(editor, t.state(find.byType(CanvasEditor))), isTrue);
        expect(t.getSize(surface()), before);
        expect(find.byType(OrbitTabStrip), findsOneWidget);
        expect(
          find.byKey(const ValueKey('canvas-minimap-card')),
          findsOneWidget,
        );
        expect(c.find(id)!.data['future'], {'preserved': true});
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'stylus strokes, undo/redo and normal tool state survive focus transitions',
    (t) async {
      final (c, id) = await mount(t, const Size(1024, 768));
      await t.runAsync(() => t.tap(find.byTooltip('Focus on drawing')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Show Canvas tools'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Draw and erase'));
      await t.pumpAndSettle();
      await t.tap(find.text('Pen (P)'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Hide Canvas tools'));
      await t.pumpAndSettle();
      final at = t.getRect(surface()).topLeft + const Offset(240, 250);
      final gesture = await t.startGesture(at, kind: PointerDeviceKind.stylus);
      await gesture.moveBy(const Offset(80, 20));
      await t.pump();
      await gesture.up();
      await t.pumpAndSettle();
      final elements = c.find(id)!.data['elements'] as List;
      expect(elements.where((e) => e['type'] == 'ink'), hasLength(1));
      await t.tap(find.byTooltip('Undo drawing'));
      await t.pumpAndSettle();
      expect(
        (c.find(id)!.data['elements'] as List).where((e) => e['type'] == 'ink'),
        isEmpty,
      );
      await t.tap(find.byTooltip('Show Canvas tools'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byTooltip('Redo (Ctrl+Shift+Z)'));
      await t.tap(find.byTooltip('Redo (Ctrl+Shift+Z)'));
      await t.pumpAndSettle();
      expect(
        (c.find(id)!.data['elements'] as List).where((e) => e['type'] == 'ink'),
        hasLength(1),
      );
      await t.tap(find.byTooltip('Hide Canvas tools'));
      await t.pumpAndSettle();
      await t.runAsync(() => t.tap(find.byTooltip('Exit Canvas focus')));
      await t.pumpAndSettle();
      await t.runAsync(() => c.flushAll());
      expect(c.find(id)!.data['future'], {'preserved': true});
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'focus keeps recovery warnings and touch controls available with enlarged text',
    (t) async {
      final (c, _) = await mount(t, const Size(800, 600), scale: 2);
      c.error = 'Save needs attention';
      c.updateSession((s) => s.focusMode = true);
      await t.pumpAndSettle();
      expect(find.text('Save needs attention'), findsOneWidget);
      expect(find.byTooltip('Exit Canvas focus'), findsOneWidget);
      await t.tap(find.byTooltip('Show Canvas tools'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.byTooltip('Hide Canvas tools'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'standalone focus without an exit callback retains normal recovery controls',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'standalone',
              focusMode: true,
              data: const {'schemaVersion': 1, 'elements': []},
              onChanged: (_) {},
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byTooltip('Draw and erase'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'tablet system Back leaves drawing focus before leaving the workspace',
    (t) async {
      final (c, id) = await mount(t, const Size(1024, 768));
      await t.runAsync(() => t.tap(find.byTooltip('Focus on drawing')));
      await t.pumpAndSettle();
      expect(c.session.focusMode, isTrue);
      await t.runAsync(() => t.binding.handlePopRoute());
      await t.pumpAndSettle();
      expect(c.session.focusMode, isFalse);
      expect(c.session.activeId, id);
      expect(find.byType(CanvasEditor), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
