import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/arrangement.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

CanvasElement _makeElement({
  required String id,
  String type = 'card',
  double x = 0,
  double y = 0,
  double width = 200,
  double height = 100,
  bool locked = false,
  String text = '',
  String? objectId,
}) {
  return CanvasElement({
    'id': id,
    'type': type,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'locked': locked,
    'text': text,
    'objectId': ?objectId,
  });
}

void main() {
  group('Canvas Auto-Arrange Layouts (CAN-10)', () {
    test(
      'grid arrangement arranges 4 elements in a 2x2 grid with 24px gap',
      () {
        final items = [
          _makeElement(id: 'c1', x: 100, y: 100, width: 200, height: 100),
          _makeElement(id: 'c2', x: 400, y: 100, width: 200, height: 100),
          _makeElement(id: 'c3', x: 100, y: 300, width: 200, height: 100),
          _makeElement(id: 'c4', x: 400, y: 300, width: 200, height: 100),
        ];

        final rearranged = arrangeCanvas(items, CanvasArrangement.grid);
        expect(rearranged.length, 4);

        // Row 0 (col 0 and col 1)
        expect(rearranged[0].x, closeTo(100, 0.01));
        expect(rearranged[0].y, closeTo(100, 0.01));

        expect(rearranged[1].x, closeTo(100 + 200 + 24, 0.01)); // 324
        expect(rearranged[1].y, closeTo(100, 0.01));

        // Row 1 (col 0 and col 1)
        expect(rearranged[2].x, closeTo(100, 0.01));
        expect(rearranged[2].y, closeTo(100 + 100 + 24, 0.01)); // 224

        expect(rearranged[3].x, closeTo(324, 0.01));
        expect(rearranged[3].y, closeTo(224, 0.01));
      },
    );

    test('grid arrangement arranges 6 elements in a 3-column layout', () {
      final items = List.generate(
        6,
        (i) => _makeElement(
          id: 'item-$i',
          x: i * 50.0,
          y: i * 50.0,
          width: 100,
          height: 80,
        ),
      );

      final rearranged = arrangeCanvas(items, CanvasArrangement.grid);
      expect(rearranged.length, 6);

      // 6 elements -> sqrt(6) ~ 2.44 -> ceil() is 3 columns!
      // Col 0, 1, 2 for first 3 items:
      expect(rearranged[0].x, closeTo(0, 0.01));
      expect(rearranged[1].x, closeTo(100 + 24, 0.01)); // 124
      expect(rearranged[2].x, closeTo(124 + 100 + 24, 0.01)); // 248

      // All row 0 items share y = 0
      expect(rearranged[0].y, closeTo(0, 0.01));
      expect(rearranged[1].y, closeTo(0, 0.01));
      expect(rearranged[2].y, closeTo(0, 0.01));

      // Row 1 items share y = 80 + 24 = 104
      expect(rearranged[3].y, closeTo(104, 0.01));
      expect(rearranged[4].y, closeTo(104, 0.01));
      expect(rearranged[5].y, closeTo(104, 0.01));
    });

    test('stackH aligns items horizontally with consistent 24px spacing', () {
      final items = [
        _makeElement(id: 's1', x: 50, y: 80, width: 100, height: 60),
        _makeElement(id: 's2', x: 200, y: 120, width: 150, height: 80),
        _makeElement(id: 's3', x: 400, y: 90, width: 120, height: 70),
      ];

      final rearranged = arrangeCanvas(items, CanvasArrangement.stackH);
      expect(rearranged.length, 3);

      expect(rearranged[0].x, closeTo(50, 0.01));
      expect(rearranged[0].y, closeTo(80, 0.01)); // Top of bounds is 80

      expect(rearranged[1].x, closeTo(50 + 100 + 24, 0.01)); // 174
      expect(rearranged[1].y, closeTo(80, 0.01));

      expect(rearranged[2].x, closeTo(174 + 150 + 24, 0.01)); // 348
      expect(rearranged[2].y, closeTo(80, 0.01));
    });

    test('stackV aligns items vertically with consistent 24px spacing', () {
      final items = [
        _makeElement(id: 'v1', x: 70, y: 40, width: 100, height: 50),
        _makeElement(id: 'v2', x: 120, y: 150, width: 120, height: 60),
      ];

      final rearranged = arrangeCanvas(items, CanvasArrangement.stackV);
      expect(rearranged.length, 2);

      expect(rearranged[0].x, closeTo(70, 0.01)); // Left of bounds is 70
      expect(rearranged[0].y, closeTo(40, 0.01));

      expect(rearranged[1].x, closeTo(70, 0.01));
      expect(rearranged[1].y, closeTo(40 + 50 + 24, 0.01)); // 114
    });

    test('radial arrangement positions others in circle around root', () {
      final items = [
        _makeElement(id: 'root', x: 200, y: 200, width: 100, height: 100),
        _makeElement(id: 'n1', x: 100, y: 100, width: 60, height: 60),
        _makeElement(id: 'n2', x: 300, y: 100, width: 60, height: 60),
        _makeElement(id: 'n3', x: 300, y: 300, width: 60, height: 60),
        _makeElement(id: 'n4', x: 100, y: 300, width: 60, height: 60),
      ];

      final rearranged = arrangeCanvas(items, CanvasArrangement.radial);
      expect(rearranged.length, 5);

      final root = rearranged.firstWhere((e) => e.id == 'root');
      expect(root.x, closeTo(200, 0.01));
      expect(root.y, closeTo(200, 0.01));

      final rootCenter = root.bounds.center;
      // All other nodes should be at approximately equal distance from root center
      final distances = <double>[];
      for (final node in rearranged) {
        if (node.id == 'root') continue;
        final d = (node.bounds.center - rootCenter).length;
        distances.add(d);
      }

      for (var i = 1; i < distances.length; i++) {
        expect(distances[i], closeTo(distances[0], 0.01));
      }
    });

    test('ignores locked elements and returns empty on < 2 elements', () {
      final single = [_makeElement(id: 'only', x: 10, y: 10)];
      expect(arrangeCanvas(single, CanvasArrangement.grid), isEmpty);

      final withLocked = [
        _makeElement(id: 'm1', x: 10, y: 10, locked: false),
        _makeElement(id: 'm2', x: 50, y: 50, locked: true),
      ];
      // Only 1 unlocked element remaining -> returns empty
      expect(arrangeCanvas(withLocked, CanvasArrangement.grid), isEmpty);
    });
  });

  group('Canvas Painter PDF & Research Cards (CAN-15, FILE-13)', () {
    test('CanvasObjectReference holds PDF source properties correctly', () {
      const obj = CanvasObjectReference(
        id: 'anno-42',
        title: 'Quantum Entanglement',
        typeId: 'orbit.note',
        body: 'Notes on experimental verification.',
        properties: {
          'pdfHighlightVersion': 1,
          'pdfSource': {
            'objectId': 'pdf-quantum-doc',
            'title': 'Quantum Physics.pdf',
            'page': 7,
            'quote': 'Entangled states exhibit non-local correlation.',
            'color': 0xff3b82f6,
          },
        },
      );

      expect(obj.properties['pdfSource'], isNotNull);
      final src = obj.properties['pdfSource'] as Map;
      expect(src['page'], 7);
      expect(src['quote'], contains('non-local correlation'));
      expect(src['color'], 0xff3b82f6);
    });

    test(
      'CanvasArrangement enum has user-facing labels for all 12 options',
      () {
        expect(CanvasArrangement.values.length, 12);
        expect(CanvasArrangement.grid.label, 'Arrange in grid');
        expect(CanvasArrangement.stackH.label, 'Stack horizontally');
        expect(CanvasArrangement.stackV.label, 'Stack vertically');
        expect(CanvasArrangement.radial.label, 'Arrange in radial circle');
      },
    );
  });
}
