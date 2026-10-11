import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/canvas/canvas_rich_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Canvas Mathematical Formatting Engine (CAN-02, CAN-15, NOTE-07)', () {
    test(
      'formatMathToUnicode converts Greek symbols and mathematical operators',
      () {
        expect(
          CanvasRichText.formatMathToUnicode(r'\alpha + \beta = \gamma'),
          'α + β = γ',
        );
        expect(
          CanvasRichText.formatMathToUnicode(r'\pi \approx 3.14159'),
          'π ≈ 3.14159',
        );
        expect(
          CanvasRichText.formatMathToUnicode(r'\int_0^\infty e^{-x} dx'),
          '∫₀^∞ e⁻ˣ dx',
        );
        expect(
          CanvasRichText.formatMathToUnicode(r'\sum_{i=1}^n x_i'),
          '∑ᵢ₌₁ⁿ xᵢ',
        );
        expect(
          CanvasRichText.formatMathToUnicode(r'a \le b \land c \ne d'),
          'a ≤ b ∧ c ≠ d',
        );
        expect(
          CanvasRichText.formatMathToUnicode(r'\pm \sqrt{x} \times \Delta y'),
          '± √(x) × Δ y',
        );
      },
    );

    test('formatMathToUnicode formats fractions and radicals', () {
      expect(CanvasRichText.formatMathToUnicode(r'\frac{1}{2}'), '½');
      expect(CanvasRichText.formatMathToUnicode(r'\frac{3}{4}'), '¾');
      expect(CanvasRichText.formatMathToUnicode(r'\frac{a}{b}'), 'a / b');
      expect(
        CanvasRichText.formatMathToUnicode(r'\sqrt{x^2 + y^2}'),
        '√(x² + y²)',
      );
      expect(CanvasRichText.formatMathToUnicode(r'\sqrt[3]{8}'), '³√(8)');
    });

    test('formatMathToUnicode converts exponents and subscripts', () {
      expect(CanvasRichText.formatMathToUnicode('E = mc^2'), 'E = mc²');
      expect(
        CanvasRichText.formatMathToUnicode('x_0 + x_1 = y^{12}'),
        'x₀ + x₁ = y¹²',
      );
      expect(
        CanvasRichText.formatMathToUnicode(r'e^{i\pi} + 1 = 0'),
        'eⁱπ + 1 = 0',
      );
    });

    test(
      'parseLines detects display math blocks, code blocks, and blockquotes',
      () {
        const content = '''
# Physics Formulas

\$\$
E = mc^2
\$\$

```dart
final speedOfLight = 299792458;
```

> "Science is a way of thinking much more than it is a body of knowledge."

- Inline formula: \$F = ma\$
''';

        final lines = CanvasRichText.parseLines(content);
        expect(lines.any((l) => l.type == CanvasRichLineType.heading1), isTrue);
        expect(
          lines.any((l) => l.type == CanvasRichLineType.displayMath),
          isTrue,
        );
        expect(
          lines.any((l) => l.type == CanvasRichLineType.codeBlock),
          isTrue,
        );
        expect(
          lines.any((l) => l.type == CanvasRichLineType.blockquote),
          isTrue,
        );
        expect(lines.any((l) => l.type == CanvasRichLineType.bullet), isTrue);

        final mathLine = lines.firstWhere(
          (l) => l.type == CanvasRichLineType.displayMath,
        );
        expect(mathLine.contentText, contains('mc²'));

        final bulletLine = lines.firstWhere(
          (l) => l.type == CanvasRichLineType.bullet,
        );
        expect(bulletLine.contentText, contains('F = ma'));
      },
    );

    test(
      'hasRichFormatting returns true for math, code, and quote constructs',
      () {
        expect(CanvasRichText.hasRichFormatting(r'$$\int x dx$$'), isTrue);
        expect(
          CanvasRichText.hasRichFormatting(r'The formula is $E=mc^2$ inline'),
          isTrue,
        );
        expect(CanvasRichText.hasRichFormatting('```\ncode\n```'), isTrue);
        expect(CanvasRichText.hasRichFormatting('> Notable citation'), isTrue);
        expect(
          CanvasRichText.hasRichFormatting(
            'Plain boring string without formatting',
          ),
          isFalse,
        );
      },
    );

    test(
      'CanvasRichText.draw renders display math, code blocks, and blockquotes',
      () {
        const content = '''
# Title
\$\$
\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
\$\$
```
x = 42
```
> Important axiom
''';

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF8B5CF6));

        expect(
          () => CanvasRichText.draw(
            canvas: canvas,
            text: content,
            bounds: const Rect.fromLTWH(0, 0, 300, 400),
            accent: const Color(0xFF8B5CF6),
            colors: colors,
            textCache: CanvasTextCache(),
          ),
          returnsNormally,
        );
      },
    );
  });

  group('Transclusion Cards with Mathematical Equations (CAN-02, NOTE-07)', () {
    test('renders transcluded note with LaTeX equations seamlessly', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'card-math-trans',
            'type': 'card',
            'objectId': 'note-math-1',
            'x': 50.0,
            'y': 50.0,
            'width': 320.0,
            'height': 240.0,
            'data': {'presentation': 'transclusion'},
          },
        ],
      });

      const noteRef = CanvasObjectReference(
        id: 'note-math-1',
        title: 'Quantum Field Notes',
        typeId: 'orbit.note',
        body: '''
# Wave Function
Schrodinger formulation:
\$\$
i\\hbar \\frac{\\partial}{\\partial t} \\Psi = \\hat{H} \\Psi
\$\$
- Energy relation: \$E = h\\nu\$
- Momentum: \$p = \\frac{h}{\\lambda}\$
''',
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF8B5CF6));

      final painter = OrbitCanvasPainter(
        scene: scene,
        camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
        selection: const {},
        colors: colors,
        textCache: CanvasTextCache(),
        objects: {'note-math-1': noteRef},
      );

      expect(
        () => painter.paint(canvas, const Size(800, 600)),
        returnsNormally,
      );
    });
  });

  group('Canvas Minimap Spatial Search Radar Dots (CAN-14 Refinement)', () {
    test(
      'CanvasMinimapPainter paints radar dots and targeting rings for search matches',
      () {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'elem-search-1',
              'type': 'card',
              'objectId': 'note-1',
              'x': 100.0,
              'y': 100.0,
              'width': 200.0,
              'height': 150.0,
            },
            {
              'id': 'elem-search-2',
              'type': 'sticky',
              'x': 500.0,
              'y': 300.0,
              'width': 180.0,
              'height': 120.0,
              'text': 'Quantum mechanics notes',
            },
            {
              'id': 'elem-other',
              'type': 'rectangle',
              'x': 800.0,
              'y': 600.0,
              'width': 100.0,
              'height': 100.0,
            },
          ],
        });

        const camera = CanvasCamera(x: 0, y: 0, zoom: 1.0);
        const viewportSize = Size(1000, 700);
        final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF8B5CF6));

        final painter = CanvasMinimapPainter(
          scene: scene,
          camera: camera,
          viewportSize: viewportSize,
          colors: colors,
          searchMatchIds: {'elem-search-1', 'elem-search-2'},
          activeSearchMatchId: 'elem-search-2',
        );

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(160, 110)),
          returnsNormally,
        );
      },
    );

    test(
      'CanvasMinimapPainter triggers repaint when searchMatchIds or activeSearchMatchId changes',
      () {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'e1',
              'type': 'sticky',
              'x': 100.0,
              'y': 100.0,
              'width': 100.0,
              'height': 100.0,
            },
          ],
        });

        const camera = CanvasCamera(x: 0, y: 0, zoom: 1.0);
        const viewportSize = Size(800, 600);
        final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF8B5CF6));

        final p1 = CanvasMinimapPainter(
          scene: scene,
          camera: camera,
          viewportSize: viewportSize,
          colors: colors,
          searchMatchIds: {'e1'},
          activeSearchMatchId: 'e1',
        );

        final p2 = CanvasMinimapPainter(
          scene: scene,
          camera: camera,
          viewportSize: viewportSize,
          colors: colors,
          searchMatchIds: {'e1'},
          activeSearchMatchId: null, // Active changed
        );

        expect(p2.shouldRepaint(p1), isTrue);

        final p3 = CanvasMinimapPainter(
          scene: scene,
          camera: camera,
          viewportSize: viewportSize,
          colors: colors,
          searchMatchIds: {'e1', 'e2'}, // Matches changed
          activeSearchMatchId: 'e1',
        );

        expect(p3.shouldRepaint(p1), isTrue);

        final p4 = CanvasMinimapPainter(
          scene: scene,
          camera: camera,
          viewportSize: viewportSize,
          colors: colors,
          searchMatchIds: {'e1'},
          activeSearchMatchId: 'e1',
        );

        expect(p4.shouldRepaint(p1), isFalse);
      },
    );
  });

  group('Formula Insertion & Minimap Radar UI Integration', () {
    testWidgets(
      'Minimap shows match counter pill when search matches are present',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sceneData = {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'e1',
              'type': 'sticky',
              'x': 200.0,
              'y': 150.0,
              'width': 220.0,
              'height': 120.0,
              'text': 'Calculus derivatives',
            },
          ],
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'canvas-test-radar',
                title: 'Math Radar Board',
                data: sceneData,
                objects: const [],
                onChanged: (_) {},
                onOpenObject: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open minimap
        final minimapToggle = find.byKey(
          const ValueKey('canvas-minimap-toggle'),
        );
        expect(minimapToggle, findsOneWidget);
        await tester.tap(minimapToggle);
        await tester.pumpAndSettle();

        // Verify minimap card opened with RADAR header
        expect(
          find.byKey(const ValueKey('canvas-minimap-card')),
          findsOneWidget,
        );
        expect(find.text('RADAR'), findsOneWidget);

        // Open search HUD
        final searchBtn = find.byKey(const ValueKey('canvas-search-button'));
        expect(searchBtn, findsOneWidget);
        await tester.tap(searchBtn);
        await tester.pumpAndSettle();

        // Type query that matches
        await tester.enterText(find.byType(TextField).first, 'Calculus');
        await tester.pumpAndSettle();

        // Minimap header should show match pill: "1" and tooltip
        expect(find.text('1'), findsWidgets);
        expect(find.byTooltip('1 search match'), findsOneWidget);
      },
    );
  });
}
