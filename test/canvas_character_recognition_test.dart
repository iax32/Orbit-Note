import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/character_recognizer.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/shape_recognizer.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

CanvasPoint _pt(double x, double y) => CanvasPoint(x, y);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Handwriting Character Recognizer (Digits & Letters)', () {
    final recognizer = CharacterRecognizer();

    test('recognizes digit 1 from vertical stroke', () {
      final stroke = [
        _pt(100, 50),
        _pt(100, 80),
        _pt(100, 110),
        _pt(100, 140),
        _pt(100, 170),
      ];
      final result = recognizer.recognize([stroke]);
      expect(result, isNotNull);
      expect(result!.char, anyOf('1', 'I', 'l'));
      expect(result.confidence, greaterThan(0.70));
    });

    test('recognizes digit 0 from circular loop', () {
      final stroke = [
        _pt(50, 10),
        _pt(20, 30),
        _pt(15, 60),
        _pt(20, 85),
        _pt(50, 100),
        _pt(80, 85),
        _pt(85, 60),
        _pt(80, 30),
        _pt(50, 10),
      ];
      final result = recognizer.recognize([stroke]);
      expect(result, isNotNull);
      expect(result!.char, anyOf('0', 'O', 'o'));
      expect(result.confidence, greaterThan(0.70));
    });

    test('recognizes digit 7 from top-bar and diagonal', () {
      final stroke = [
        _pt(20, 20),
        _pt(50, 20),
        _pt(80, 20),
        _pt(60, 50),
        _pt(40, 80),
        _pt(30, 110),
      ];
      final result = recognizer.recognize([stroke]);
      expect(result, isNotNull);
      expect(result!.char, equals('7'));
      expect(result.confidence, greaterThan(0.70));
    });

    test('recognizes letter C from curved open arc', () {
      final stroke = [
        _pt(85, 25),
        _pt(55, 10),
        _pt(25, 30),
        _pt(15, 60),
        _pt(25, 90),
        _pt(55, 105),
        _pt(85, 90),
      ];
      final result = recognizer.recognize([stroke]);
      expect(result, isNotNull);
      expect(result!.char, equals('C'));
      expect(result.confidence, greaterThan(0.70));
    });

    test('recognizes letter L from vertical and horizontal stroke', () {
      final stroke = [
        _pt(30, 20),
        _pt(30, 60),
        _pt(30, 100),
        _pt(30, 120),
        _pt(60, 120),
        _pt(90, 120),
      ];
      final result = recognizer.recognize([stroke]);
      expect(result, isNotNull);
      expect(result!.char, equals('L'));
      expect(result.confidence, greaterThan(0.70));
    });

    test('recognizes letter S from serpentine curve', () {
      final stroke = [
        _pt(80, 25),
        _pt(50, 15),
        _pt(25, 35),
        _pt(50, 60),
        _pt(75, 85),
        _pt(50, 105),
        _pt(20, 95),
      ];
      final result = recognizer.recognize([stroke]);
      expect(result, isNotNull);
      expect(result!.char, equals('S'));
      expect(result.confidence, greaterThan(0.70));
    });

    test('recognizes letter V from downward and upward diagonal', () {
      final stroke = [
        _pt(20, 20),
        _pt(35, 65),
        _pt(50, 110),
        _pt(65, 65),
        _pt(80, 20),
      ];
      final result = recognizer.recognize([stroke]);
      expect(result, isNotNull);
      expect(result!.char, equals('V'));
      expect(result.confidence, greaterThan(0.70));
    });

    test('recognizes letter Z from horizontal, diagonal, and horizontal', () {
      final stroke = [
        _pt(20, 20),
        _pt(80, 20),
        _pt(50, 65),
        _pt(20, 110),
        _pt(80, 110),
      ];
      final result = recognizer.recognize([stroke]);
      expect(result, isNotNull);
      expect(result!.char, equals('Z'));
      expect(result.confidence, greaterThan(0.70));
    });

    test('recognizes multi-stroke letter T (crossbar + stem)', () {
      final stroke1 = [_pt(15, 20), _pt(50, 20), _pt(85, 20)];
      final stroke2 = [_pt(50, 20), _pt(50, 60), _pt(50, 100)];

      final result = recognizer.recognize([stroke1, stroke2]);
      expect(result, isNotNull);
      expect(result!.char, equals('T'));
      expect(result.confidence, greaterThan(0.70));
    });

    test('recognizes multi-stroke letter X (two crossing diagonals)', () {
      final stroke1 = [_pt(15, 20), _pt(50, 60), _pt(85, 100)];
      final stroke2 = [_pt(85, 20), _pt(50, 60), _pt(15, 100)];

      final result = recognizer.recognize([stroke1, stroke2]);
      expect(result, isNotNull);
      expect(result!.char, equals('X'));
      expect(result.confidence, greaterThan(0.70));
    });

    test('recognizes multi-stroke math symbol = (two parallel bars)', () {
      final stroke1 = [_pt(20, 40), _pt(50, 40), _pt(80, 40)];
      final stroke2 = [_pt(20, 70), _pt(50, 70), _pt(80, 70)];

      final result = recognizer.recognize([stroke1, stroke2]);
      expect(result, isNotNull);
      expect(result!.char, equals('='));
      expect(result.confidence, greaterThan(0.70));
    });

    test('recognizes multi-stroke math symbol + (vertical + horizontal)', () {
      final stroke1 = [_pt(50, 20), _pt(50, 80)];
      final stroke2 = [_pt(20, 50), _pt(80, 50)];

      final result = recognizer.recognize([stroke1, stroke2]);
      expect(result, isNotNull);
      expect(result!.char, equals('+'));
      expect(result.confidence, greaterThan(0.70));
    });
  });

  group('Unified Ink Gesture Classifier (recognizeInkGesture)', () {
    test('classifies closed circle as ellipse shape', () {
      final inkElem = CanvasElement({
        'id': 'ink-circle',
        'type': 'ink',
        'x': 50,
        'y': 50,
        'width': 120,
        'height': 120,
        'points': [
          {'x': 60.0, 'y': 0.0},
          {'x': 18.0, 'y': 18.0},
          {'x': 0.0, 'y': 60.0},
          {'x': 18.0, 'y': 102.0},
          {'x': 60.0, 'y': 120.0},
          {'x': 102.0, 'y': 102.0},
          {'x': 120.0, 'y': 60.0},
          {'x': 102.0, 'y': 18.0},
          {'x': 60.0, 'y': 0.0},
        ],
      });

      final gesture = recognizeInkGesture(inkElem);
      expect(gesture, isNotNull);
      expect(gesture!.isShape, isTrue);
      expect(gesture.shape?.type, equals('ellipse'));
    });

    test('classifies box stroke as rectangle shape', () {
      final inkElem = CanvasElement({
        'id': 'ink-rect',
        'type': 'ink',
        'x': 100,
        'y': 100,
        'width': 150,
        'height': 100,
        'points': [
          {'x': 0.0, 'y': 0.0},
          {'x': 150.0, 'y': 0.0},
          {'x': 150.0, 'y': 100.0},
          {'x': 0.0, 'y': 100.0},
          {'x': 0.0, 'y': 0.0},
        ],
      });

      final gesture = recognizeInkGesture(inkElem);
      expect(gesture, isNotNull);
      expect(gesture!.isShape, isTrue);
      expect(gesture.shape?.type, equals('rectangle'));
    });

    test('classifies letter stroke as character text', () {
      final inkElem = CanvasElement({
        'id': 'ink-letter-l',
        'type': 'ink',
        'x': 40,
        'y': 40,
        'width': 40,
        'height': 50,
        'points': [
          {'x': 0.0, 'y': 0.0},
          {'x': 0.0, 'y': 25.0},
          {'x': 0.0, 'y': 50.0},
          {'x': 20.0, 'y': 50.0},
          {'x': 40.0, 'y': 50.0},
        ],
      });

      final gesture = recognizeInkGesture(inkElem);
      expect(gesture, isNotNull);
      expect(gesture!.isCharacter, isTrue);
      expect(gesture.character?.char, equals('L'));
    });

    test('convertInkToText creates valid renderable text element', () {
      final inkElem = CanvasElement({
        'id': 'ink-conv-1',
        'type': 'ink',
        'x': 120,
        'y': 180,
        'width': 35,
        'height': 55,
        'color': 0xff3b82f6,
        'points': [
          {'x': 0.0, 'y': 0.0},
          {'x': 0.0, 'y': 55.0},
          {'x': 35.0, 'y': 55.0},
        ],
      });

      final textElem = convertInkToText(inkElem, text: 'L');
      expect(textElem.id, equals('ink-conv-1'));
      expect(textElem.type, equals('text'));
      expect(textElem.text, equals('L'));
      expect(textElem.color, equals(0xff3b82f6));
      expect(textElem.x, equals(120));
      expect(textElem.y, equals(180));
      expect(textElem.renderable, isTrue);
    });
  });

  group('CanvasEditor Auto-Recognition UI & Controls', () {
    testWidgets(
      'auto-recognize toggle is present in toolbar when pen is active and disabled by default',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sceneData = {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'r1',
              'type': 'rectangle',
              'x': 50,
              'y': 50,
              'width': 100,
              'height': 100,
            },
          ],
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'board-autorecog-test',
                data: sceneData,
                objects: const [],
                onOpenObject: (_) {},
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to pen tool
        await tester.tap(find.byTooltip('Draw and erase'));
        await tester.pumpAndSettle();
        final penBtn = find.text('Pen (P)');
        expect(penBtn, findsOneWidget);
        await tester.tap(penBtn);
        await tester.pumpAndSettle();

        // Verify Auto-recognize toggle button is visible
        final autoRecogBtn = find.byTooltip(
          'Auto-recognize ink to text & shapes (disabled, shortcut K)',
        );
        expect(autoRecogBtn, findsOneWidget);

        // Tap auto-recognize toggle button to enable it
        await tester.tap(autoRecogBtn);
        await tester.pumpAndSettle();

        // Verify tooltip updates to active
        final activeRecogBtn = find.byTooltip(
          'Auto-recognize ink active: Converts handwriting to text & shapes (K)',
        );
        expect(activeRecogBtn, findsOneWidget);

        // Tap again to disable
        await tester.tap(activeRecogBtn);
        await tester.pumpAndSettle();
        expect(
          find.byTooltip(
            'Auto-recognize ink to text & shapes (disabled, shortcut K)',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('context menu contains text recognition actions for ink', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sceneData = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'ink1',
            'type': 'ink',
            'x': 200,
            'y': 200,
            'width': 80,
            'height': 80,
            'points': [
              {'x': 0.0, 'y': 0.0},
              {'x': 0.0, 'y': 80.0},
              {'x': 80.0, 'y': 80.0},
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board-context-ink-test',
              data: sceneData,
              objects: const [],
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

      // Select the ink first
      await tester.tapAt(origin + const Offset(200, 240));
      await tester.pumpAndSettle();

      // Right click / secondary click on ink to open context menu
      await tester.tapAt(
        origin + const Offset(200, 240),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Verify text recognition context menu actions appear
      expect(find.text('Auto-Recognize (Text or Shape)'), findsOneWidget);
      expect(find.text('Convert Stroke to Text'), findsOneWidget);
      expect(find.text('Auto-Detect Clean Shape'), findsOneWidget);

      // Dismiss menu
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    });
  });
}
