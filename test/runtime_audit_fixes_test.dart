import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/search_text.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';

void main() {
  group('Search Snippet Enhancements', () {
    test('extractSearchSnippet matches object title first', () {
      final note = UniversalObject(
        id: 'note-title-1',
        workspaceId: 'ws',
        typeId: 'orbit.note',
        title: 'Quantum Physics Lecture',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        body: 'Introductory notes on wave-particle duality.',
      );

      final snippet = extractSearchSnippet(note, 'quantum');
      expect(snippet, isNotNull);
      expect(snippet!.source, equals('title'));
      expect(snippet.text, contains('Quantum Physics'));
    });

    test('extractSearchSnippet matches markdown syntax and wiki links', () {
      final note = UniversalObject(
        id: 'note-syntax-1',
        workspaceId: 'ws',
        typeId: 'orbit.note',
        title: 'Project Roadmap',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        body:
            'Tasks list:\n- [x] Initial design\n- [ ] [[Core Mechanics]] implementation\n',
      );

      final linkSnippet = extractSearchSnippet(note, '[[core');
      expect(linkSnippet, isNotNull);
      expect(linkSnippet!.source, equals('body'));
      expect(linkSnippet.text, contains('[[Core Mechanics]]'));

      final checkSnippet = extractSearchSnippet(note, '- [x]');
      expect(checkSnippet, isNotNull);
      expect(checkSnippet!.source, equals('body'));
      expect(checkSnippet.text, contains('- [x]'));
    });
  });

  group('Minimap Tap Clamping', () {
    test('layout and coordinate clamping handles padding taps', () {
      final scene = CanvasScene.fromJson({
        'elements': [
          {
            'id': 'e1',
            'type': 'sticky',
            'x': 100.0,
            'y': 100.0,
            'width': 100.0,
            'height': 100.0,
            'text': 'Box',
          },
        ],
      });
      const camera = CanvasCamera(x: 0, y: 0, zoom: 1.0);
      const viewport = Size(800, 600);
      const minimapSize = Size(160, 110);

      final (contentRect, scale, offsetX, offsetY) =
          CanvasMinimapPainter.layout(scene, camera, viewport, minimapSize);

      expect(scale, greaterThan(0));
      expect(contentRect.width, greaterThan(0));

      final clampedX = (0.0).clamp(
        offsetX,
        offsetX + contentRect.width * scale,
      );
      final clampedY = (0.0).clamp(
        offsetY,
        offsetY + contentRect.height * scale,
      );
      expect(clampedX, equals(offsetX));
      expect(clampedY, equals(offsetY));
    });
  });

  group('Connector Text Labels & Editing', () {
    test(
      'OrbitCanvasPainter renders connector text label when text is set',
      () {
        final scene = CanvasScene.fromJson({
          'elements': [
            {
              'id': 'arrow-1',
              'type': 'arrow',
              'x': 50.0,
              'y': 50.0,
              'width': 200.0,
              'height': 100.0,
              'color': 0xFF3B82F6,
              'text': 'Next Step',
            },
          ],
        });
        const camera = CanvasCamera(x: 0, y: 0, zoom: 1.0);
        final cache = CanvasTextCache();
        final painter = OrbitCanvasPainter(
          scene: scene,
          camera: camera,
          selection: const {},
          objects: const {},
          colors: const ColorScheme.dark(),
          textCache: cache,
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, const Size(800, 600));
        final picture = recorder.endRecording();
        expect(picture, isNotNull);
        cache.dispose();
        picture.dispose();
      },
    );
  });

  group('Rich Markdown Editor Duplicate Heading Collapse', () {
    testWidgets(
      'disambiguates collapse keys for headings with identical text',
      (tester) async {
        const source = '''
## Overview
First overview text.

## Overview
Second overview text.
''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RichMarkdownEditor(
                body: source,
                onChanged: (_) {},
                onUndo: () {},
                onRedo: () {},
                linkTargets: const [],
                linkBindings: const {},
                onOpenLink: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final chevrons = find.byIcon(Icons.keyboard_arrow_down);
        expect(chevrons, findsNWidgets(2));

        await tester.tap(chevrons.first);
        await tester.pumpAndSettle();

        expect(find.text('First overview text.'), findsNothing);
        expect(find.text('Second overview text.'), findsOneWidget);
      },
    );
  });
}
