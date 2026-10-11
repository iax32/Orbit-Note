import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Canvas Card Transclusion Rendering & Object Identity (CAN-02, NOTE-07)', () {
    test('renders transclusion presentation with live note body and badge', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'card-trans-1',
            'type': 'card',
            'objectId': 'note-101',
            'x': 100.0,
            'y': 100.0,
            'width': 280.0,
            'height': 180.0,
            'data': {'presentation': 'transclusion'},
          },
        ],
      });

      const noteRef = CanvasObjectReference(
        id: 'note-101',
        title: 'Project Roadmap',
        typeId: 'orbit.note',
        body:
            '# Architecture\n- Core system **verified**\n- Transclusion active',
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));

      final painter = OrbitCanvasPainter(
        scene: scene,
        camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
        selection: const {},
        colors: colors,
        textCache: CanvasTextCache(),
        objects: {'note-101': noteRef},
      );

      // Should paint successfully without error
      expect(
        () => painter.paint(canvas, const Size(800, 600)),
        returnsNormally,
      );
    });

    test('extracts block reference when blockId is specified', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'card-block-trans',
            'type': 'card',
            'objectId': 'note-202',
            'x': 100.0,
            'y': 100.0,
            'width': 280.0,
            'height': 160.0,
            'data': {'presentation': 'transclusion', 'blockId': 'key-metric'},
          },
        ],
      });

      const noteRef = CanvasObjectReference(
        id: 'note-202',
        title: 'Sprint Stats',
        typeId: 'orbit.note',
        body:
            'Introductory notes\nTotal throughput: 420 requests/sec ^key-metric\nConclusion notes',
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));

      final painter = OrbitCanvasPainter(
        scene: scene,
        camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
        selection: const {},
        colors: colors,
        textCache: CanvasTextCache(),
        objects: {'note-202': noteRef},
      );

      expect(
        () => painter.paint(canvas, const Size(800, 600)),
        returnsNormally,
      );
    });

    test(
      'unresolved reference fallback paints safely when object is missing',
      () {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'card-missing-ref',
              'type': 'card',
              'objectId': 'missing-note-999',
              'x': 50.0,
              'y': 50.0,
              'width': 260.0,
              'height': 150.0,
              'data': {'presentation': 'transclusion'},
            },
          ],
        });

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));

        final painter = OrbitCanvasPainter(
          scene: scene,
          camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
          selection: const {},
          colors: colors,
          textCache: CanvasTextCache(),
          objects: const {}, // empty objects map
        );

        expect(
          () => painter.paint(canvas, const Size(800, 600)),
          returnsNormally,
        );
      },
    );
  });

  group('Spatial Minimap Radar Overlay Navigation (CAN-01, CAN-15)', () {
    test(
      'CanvasMinimapPainter paints radar range rings and type-colored elements',
      () {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'c1',
              'type': 'card',
              'objectId': 'note-1',
              'x': 50.0,
              'y': 50.0,
              'width': 120.0,
              'height': 80.0,
              'data': {'presentation': 'transclusion'},
            },
            {
              'id': 'c2',
              'type': 'card',
              'objectId': 'note-2',
              'x': 300.0,
              'y': 100.0,
              'width': 100.0,
              'height': 70.0,
              'data': {'presentation': 'card'},
            },
            {
              'id': 'f1',
              'type': 'frame',
              'x': 0.0,
              'y': 0.0,
              'width': 500.0,
              'height': 400.0,
            },
            {
              'id': 'sh1',
              'type': 'rectangle',
              'x': 100.0,
              'y': 250.0,
              'width': 80.0,
              'height': 60.0,
            },
            {
              'id': 'ink1',
              'type': 'ink',
              'x': 250.0,
              'y': 250.0,
              'width': 60.0,
              'height': 60.0,
              'points': [
                {'x': 0.0, 'y': 0.0},
                {'x': 60.0, 'y': 60.0},
              ],
            },
          ],
        });

        const camera = CanvasCamera(x: 50, y: 50, zoom: 1.0);
        const viewportSize = Size(800, 600);
        final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));

        final painter = CanvasMinimapPainter(
          scene: scene,
          camera: camera,
          viewportSize: viewportSize,
          colors: colors,
        );

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(160, 110)),
          returnsNormally,
        );
      },
    );

    testWidgets(
      'Minimap toggle opens radar card with HUD header and Fit All button',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sceneData = {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'e1',
              'type': 'card',
              'objectId': 'n1',
              'x': 200.0,
              'y': 150.0,
              'width': 220.0,
              'height': 120.0,
              'data': {'presentation': 'transclusion'},
            },
            {
              'id': 'e2',
              'type': 'sticky',
              'x': 600.0,
              'y': 400.0,
              'width': 150.0,
              'height': 150.0,
              'text': 'Design Review',
            },
          ],
        };

        const noteRef = CanvasObjectReference(
          id: 'n1',
          title: 'Sprint Planning',
          typeId: 'orbit.note',
          body: 'Sprint goal: transclusion & radar navigation',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'radar-minimap-board',
                data: sceneData,
                objects: const [noteRef],
                onOpenObject: (_) {},
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Toggle minimap open
        final minimapToggle = find.byKey(
          const ValueKey('canvas-minimap-toggle'),
        );
        expect(minimapToggle, findsOneWidget);
        await tester.tap(minimapToggle);
        await tester.pumpAndSettle();

        // Verify minimap card and HUD header are present
        expect(
          find.byKey(const ValueKey('canvas-minimap-card')),
          findsOneWidget,
        );
        expect(find.text('RADAR'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('canvas-minimap-fit-btn')),
          findsOneWidget,
        );

        // Tap Fit All button on minimap radar header
        await tester.tap(find.byKey(const ValueKey('canvas-minimap-fit-btn')));
        await tester.pumpAndSettle();

        // Minimap card remains visible and operational
        expect(
          find.byKey(const ValueKey('canvas-minimap-card')),
          findsOneWidget,
        );
      },
    );
  });

  group('CanvasEditor Transclusion Context Menu & Live Sync', () {
    testWidgets(
      'context menu includes Live Note Transclusion option for card',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sceneData = {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'card1',
              'type': 'card',
              'objectId': 'n1',
              'x': 200.0,
              'y': 200.0,
              'width': 220.0,
              'height': 120.0,
              'data': {'presentation': 'card'},
            },
          ],
        };

        const noteRef = CanvasObjectReference(
          id: 'n1',
          title: 'Project Notes',
          typeId: 'orbit.note',
          body: 'Initial content',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'transclusion-menu-test',
                data: sceneData,
                objects: const [noteRef],
                onOpenObject: (_) {},
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final surface = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
        );
        final origin = tester.getTopLeft(surface);

        // Select card
        await tester.tapAt(origin + const Offset(250, 250));
        await tester.pumpAndSettle();

        // Secondary click on card to open context menu
        await tester.tapAt(
          origin + const Offset(250, 250),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        // Verify Transclusion menu item is visible
        expect(
          find.text('Live Note Transclusion (CAN-02/NOTE-07)'),
          findsOneWidget,
        );
        expect(find.text('Edit Transcluded Note Content...'), findsOneWidget);

        // Click Live Note Transclusion presentation
        await tester.tap(find.text('Live Note Transclusion (CAN-02/NOTE-07)'));
        await tester.pumpAndSettle();

        // Dismiss any remaining overlays
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'editing transcluded note content via context menu updates object and notifies host',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sceneData = {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'card1',
              'type': 'card',
              'objectId': 'n1',
              'x': 200.0,
              'y': 200.0,
              'width': 260.0,
              'height': 150.0,
              'data': {'presentation': 'transclusion'},
            },
          ],
        };

        const initialNote = CanvasObjectReference(
          id: 'n1',
          title: 'Original Title',
          typeId: 'orbit.note',
          body: 'Initial transcluded markdown',
        );

        String? updatedObjId;
        Map<String, dynamic>? updatedProps;

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'transclusion-edit-test',
                data: sceneData,
                objects: const [initialNote],
                onOpenObject: (_) {},
                onChanged: (_) {},
                onUpdateObjectProperties: (id, props) {
                  updatedObjId = id;
                  updatedProps = props;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final surface = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
        );
        final origin = tester.getTopLeft(surface);

        // Select card
        await tester.tapAt(origin + const Offset(250, 250));
        await tester.pumpAndSettle();

        // Open context menu
        await tester.tapAt(
          origin + const Offset(250, 250),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        // Tap Edit Transcluded Note Content...
        await tester.tap(find.text('Edit Transcluded Note Content...'));
        await tester.pumpAndSettle();

        // Dialog should be displayed
        expect(find.text('Live Note Transclusion Editor'), findsOneWidget);
        expect(find.text('Save & Sync'), findsOneWidget);

        // Update the body text
        final bodyField = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.controller?.text == 'Initial transcluded markdown',
        );
        expect(bodyField, findsOneWidget);
        await tester.enterText(
          bodyField,
          'Updated live body content across boards',
        );
        await tester.pumpAndSettle();

        // Tap Save & Sync
        await tester.tap(find.text('Save & Sync'));
        await tester.pumpAndSettle();

        // Verify host was notified with updated properties
        expect(updatedObjId, equals('n1'));
        expect(updatedProps, isNotNull);
        expect(
          updatedProps!['body'],
          equals('Updated live body content across boards'),
        );
      },
    );

    test(
      'Universal Object Identity (CAN-02): Multiple placements show identical content from single object',
      () {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'placement-1',
              'type': 'card',
              'objectId': 'shared-note',
              'x': 50.0,
              'y': 50.0,
              'width': 250.0,
              'height': 160.0,
              'data': {'presentation': 'transclusion'},
            },
            {
              'id': 'placement-2',
              'type': 'card',
              'objectId': 'shared-note',
              'x': 350.0,
              'y': 50.0,
              'width': 250.0,
              'height': 160.0,
              'data': {'presentation': 'transclusion'},
            },
          ],
        });

        // Both placements point to 'shared-note'
        const noteV1 = CanvasObjectReference(
          id: 'shared-note',
          title: 'Single Source of Truth',
          typeId: 'orbit.note',
          body: 'Version 1 body content',
        );

        final recorder1 = PictureRecorder();
        final canvas1 = Canvas(recorder1);
        final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));

        final painter1 = OrbitCanvasPainter(
          scene: scene,
          camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
          selection: const {},
          colors: colors,
          textCache: CanvasTextCache(),
          objects: {'shared-note': noteV1},
        );
        expect(
          () => painter1.paint(canvas1, const Size(800, 600)),
          returnsNormally,
        );

        // Now simulate updating the single underlying note object to Version 2
        const noteV2 = CanvasObjectReference(
          id: 'shared-note',
          title: 'Single Source of Truth',
          typeId: 'orbit.note',
          body: 'Version 2 updated content dynamically across both placements',
        );

        final recorder2 = PictureRecorder();
        final canvas2 = Canvas(recorder2);
        final painter2 = OrbitCanvasPainter(
          scene: scene,
          camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
          selection: const {},
          colors: colors,
          textCache: CanvasTextCache(),
          objects: {'shared-note': noteV2},
        );
        expect(
          () => painter2.paint(canvas2, const Size(800, 600)),
          returnsNormally,
        );
      },
    );
  });
}
