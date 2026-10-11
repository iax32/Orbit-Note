import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/canvas_svg.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

void main() {
  group('Canvas Section Header Size & Line Thickness', () {
    test(
      'default section element has 13px font size and 1.5px stroke width',
      () {
        final section = CanvasElement({
          'id': 'sec-1',
          'type': 'section',
          'x': 100.0,
          'y': 100.0,
          'width': 360.0,
          'height': 40.0,
          'text': 'WEAPONS WE CAN ADD',
          'color': 0xFF8B7CF6,
        });

        expect(section.sectionFontSize, equals(13.0));
        expect(section.sectionStrokeWidth, equals(1.5));
      },
    );

    test('explicit fontSize and strokeWidth are respected', () {
      final section = CanvasElement({
        'id': 'sec-2',
        'type': 'section',
        'x': 100.0,
        'y': 100.0,
        'width': 400.0,
        'height': 60.0,
        'text': 'BIG HEADER',
        'fontSize': 28.0,
        'strokeWidth': 4.0,
      });

      expect(section.sectionFontSize, equals(28.0));
      expect(section.sectionStrokeWidth, equals(4.0));
    });

    test('headerSize presets map to expected font sizes and stroke widths', () {
      final sizes = {
        'small': (13.0, 1.5),
        'medium': (18.0, 2.5),
        'large': (24.0, 3.5),
        'xlarge': (32.0, 4.5),
        'huge': (42.0, 6.0),
      };

      for (final entry in sizes.entries) {
        final section = CanvasElement({
          'id': 'sec-${entry.key}',
          'type': 'section',
          'x': 0.0,
          'y': 0.0,
          'width': 300.0,
          'height': 50.0,
          'text': 'TITLE',
          'headerSize': entry.key,
        });

        expect(
          section.sectionFontSize,
          equals(entry.value.$1),
          reason: 'Font size mismatch for preset ${entry.key}',
        );
        expect(
          section.sectionStrokeWidth,
          equals(entry.value.$2),
          reason: 'Stroke width mismatch for preset ${entry.key}',
        );
      }
    });

    test('markdown heading prefixes automatically configure size and line', () {
      final h1 = CanvasElement({
        'id': 'sec-h1',
        'type': 'section',
        'x': 0.0,
        'y': 0.0,
        'width': 300.0,
        'height': 50.0,
        'text': '# Main Heading',
      });
      expect(h1.sectionFontSize, equals(24.0));
      expect(h1.sectionStrokeWidth, equals(3.5));

      final h2 = CanvasElement({
        'id': 'sec-h2',
        'type': 'section',
        'x': 0.0,
        'y': 0.0,
        'width': 300.0,
        'height': 50.0,
        'text': '## Sub Heading',
      });
      expect(h2.sectionFontSize, equals(18.0));
      expect(h2.sectionStrokeWidth, equals(2.5));

      final h3 = CanvasElement({
        'id': 'sec-h3',
        'type': 'section',
        'x': 0.0,
        'y': 0.0,
        'width': 300.0,
        'height': 50.0,
        'text': '### Small Heading',
      });
      expect(h3.sectionFontSize, equals(13.0));
      expect(h3.sectionStrokeWidth, equals(1.5));
    });

    test(
      'taller section elements scale font size and stroke width proportionally',
      () {
        final tallSection = CanvasElement({
          'id': 'sec-tall',
          'type': 'section',
          'x': 0.0,
          'y': 0.0,
          'width': 400.0,
          'height': 120.0,
          'text': 'RESIZED SECTION',
        });

        // 120 * (13 / 40) = 39.0
        expect(tallSection.sectionFontSize, equals(39.0));
        expect(tallSection.sectionStrokeWidth, closeTo(39.0 * 0.12, 0.01));
      },
    );

    test('SVG export includes custom font-size and stroke-width', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'sec-svg',
            'type': 'section',
            'x': 50.0,
            'y': 60.0,
            'width': 320.0,
            'height': 80.0,
            'text': '# LEVEL 1 WEAPONS',
            'color': 0xFF8B7CF6,
          },
        ],
      });

      final svg = canvasToSvg(scene);
      expect(svg, contains('font-size="24'));
      expect(svg, contains('stroke-width="3.5"'));
      expect(svg, contains('LEVEL 1 WEAPONS'));
      expect(svg, isNot(contains('# LEVEL 1 WEAPONS')));
    });

    test('OrbitCanvasPainter paints section without error', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'sec-p',
            'type': 'section',
            'x': 10.0,
            'y': 20.0,
            'width': 350.0,
            'height': 60.0,
            'text': 'GUNS WE CAN ADD',
            'color': 0xFF8B7CF6,
            'headerSize': 'large',
          },
        ],
      });

      final painter = OrbitCanvasPainter(
        textCache: CanvasTextCache(),
        scene: scene,
        camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
        selection: const {'sec-p'},
        objects: const {},
        colors: orbitDarkTheme().colorScheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(800, 600));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    testWidgets(
      'Selection toolbar displays section header size and line thickness controls',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1400, 900);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        Map<String, dynamic> latest = {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'sec-tool',
              'type': 'section',
              'x': 200.0,
              'y': 200.0,
              'width': 360.0,
              'height': 40.0,
              'text': 'GUNS WE CAN ADD',
              'color': 0xFF8B7CF6,
            },
          ],
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'board',
                data: latest,
                focusElementId: 'sec-tool',
                onChanged: (v) => latest = v,
                objects: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check that toolbar controls for section are visible
        expect(find.byTooltip('Section Header Size'), findsOneWidget);
        expect(find.byTooltip('Decrease Header Size'), findsOneWidget);
        expect(find.byTooltip('Increase Header Size'), findsOneWidget);
        expect(find.byTooltip('Line Thickness'), findsOneWidget);

        // Tap Increase Header Size button
        await tester.tap(find.byTooltip('Increase Header Size'));
        await tester.pumpAndSettle();

        final updatedElem = (latest['elements'] as List).first as Map;
        expect(updatedElem['headerSize'], equals('medium'));
        expect(updatedElem['fontSize'], equals(18.0));
        expect(updatedElem['strokeWidth'], equals(2.5));
      },
    );

    testWidgets('Line thickness toolbar control updates strokeWidth', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      Map<String, dynamic> latest = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'sec-line',
            'type': 'section',
            'x': 200.0,
            'y': 200.0,
            'width': 360.0,
            'height': 40.0,
            'text': 'ARMOR',
            'color': 0xFF8B7CF6,
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board',
              data: latest,
              focusElementId: 'sec-line',
              onChanged: (v) => latest = v,
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open line thickness menu
      await tester.tap(find.byTooltip('Line Thickness'));
      await tester.pumpAndSettle();

      // Select Heavy (6.0px)
      await tester.tap(find.text('Heavy (6.0px)'));
      await tester.pumpAndSettle();

      final updatedElem = (latest['elements'] as List).first as Map;
      expect(updatedElem['strokeWidth'], equals(6.0));
      expect(updatedElem['lineThickness'], equals(6.0));
    });

    testWidgets('Editing section text with # prefix upgrades to large header', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      Map<String, dynamic> latest = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'sec-edit',
            'type': 'section',
            'x': 200.0,
            'y': 200.0,
            'width': 360.0,
            'height': 40.0,
            'text': 'INITIAL',
            'color': 0xFF8B7CF6,
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board',
              data: latest,
              camera: const {'x': 0.0, 'y': 0.0, 'zoom': 1.0},
              onChanged: (v) => latest = v,
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final surface = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
      );
      // Click on section element to select and focus
      await tester.tapAt(tester.getTopLeft(surface) + const Offset(250, 220));
      await tester.pumpAndSettle();

      // Press Enter to edit text of selected element
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Find the TextField
      final textField = find.byKey(const ValueKey('canvas-element-text-field'));
      expect(textField, findsOneWidget);

      await tester.enterText(textField, '# ADVANCED WEAPONS');
      await tester.pumpAndSettle();

      // Press Enter to finish text editing
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final updatedElem = (latest['elements'] as List).first as Map;
      expect(updatedElem['text'], equals('# ADVANCED WEAPONS'));
      expect(updatedElem['headerSize'], equals('large'));
      expect(updatedElem['fontSize'], equals(24.0));
      expect(updatedElem['strokeWidth'], equals(3.5));
      expect(updatedElem['height'], greaterThanOrEqualTo(66.0));
    });

    testWidgets('Context menu offers Section Header Size and Line Thickness', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      Map<String, dynamic> latest = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'sec-ctx',
            'type': 'section',
            'x': 200.0,
            'y': 200.0,
            'width': 360.0,
            'height': 40.0,
            'text': 'OPTIONS',
            'color': 0xFF8B7CF6,
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board',
              data: latest,
              camera: const {'x': 0.0, 'y': 0.0, 'zoom': 1.0},
              onChanged: (v) => latest = v,
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Right-click on the section element to open context menu
      final surface = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
      );
      await tester.tapAt(
        tester.getTopLeft(surface) + const Offset(250, 220),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Verify section menu items exist
      expect(find.text('SECTION HEADER SIZE'), findsOneWidget);
      expect(find.text('Small (13px)'), findsOneWidget);
      expect(find.text('Medium (18px)'), findsOneWidget);
      expect(find.text('Large (24px)'), findsOneWidget);
      expect(find.text('Extra Large (32px)'), findsOneWidget);
      expect(find.text('Huge (42px)'), findsOneWidget);

      expect(find.text('LINE THICKNESS'), findsOneWidget);
      expect(find.text('Hairline (1.0px)'), findsOneWidget);
      expect(find.text('Standard (1.5px)'), findsOneWidget);
      expect(find.text('Medium (2.5px)'), findsOneWidget);
      expect(find.text('Thick (4.0px)'), findsOneWidget);
      expect(find.text('Heavy (6.0px)'), findsOneWidget);

      // Tap on Huge (42px)
      await tester.tap(find.text('Huge (42px)'));
      await tester.pumpAndSettle();

      final updatedElem = (latest['elements'] as List).first as Map;
      expect(updatedElem['headerSize'], equals('huge'));
      expect(updatedElem['fontSize'], equals(42.0));
      expect(updatedElem['strokeWidth'], equals(6.0));
      expect(updatedElem['height'], greaterThanOrEqualTo(104.0));
    });
  });
}
