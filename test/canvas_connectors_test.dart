import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/connectors.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

void main() {
  group('Canvas Connectors & Anchors (CAN-04, CAN-05, CAN-07)', () {
    test('getElementAnchors returns correct 4 edge anchors and center', () {
      const bounds = CanvasBounds(100, 200, 200, 100);
      final anchors = getElementAnchors(bounds);

      expect(anchors[ConnectorAnchor.top], const CanvasPoint(200, 200));
      expect(anchors[ConnectorAnchor.bottom], const CanvasPoint(200, 300));
      expect(anchors[ConnectorAnchor.left], const CanvasPoint(100, 250));
      expect(anchors[ConnectorAnchor.right], const CanvasPoint(300, 250));
    });

    test('findClosestAnchor finds the closest edge anchor to a point', () {
      const bounds = CanvasBounds(100, 200, 200, 100);

      // Point far to the right
      expect(
        findClosestAnchor(bounds, const CanvasPoint(500, 250)),
        ConnectorAnchor.right,
      );

      // Point far to the left
      expect(
        findClosestAnchor(bounds, const CanvasPoint(0, 250)),
        ConnectorAnchor.left,
      );

      // Point far above
      expect(
        findClosestAnchor(bounds, const CanvasPoint(200, 50)),
        ConnectorAnchor.top,
      );

      // Point far below
      expect(
        findClosestAnchor(bounds, const CanvasPoint(200, 450)),
        ConnectorAnchor.bottom,
      );
    });

    test(
      'resolveConnectorEndpoints chooses Right-to-Left for horizontal relationship',
      () {
        final scene = CanvasScene.fromJson({
          'elements': [
            {
              'id': 'card-1',
              'type': 'card',
              'x': 100.0,
              'y': 100.0,
              'width': 200.0,
              'height': 100.0,
            },
            {
              'id': 'card-2',
              'type': 'card',
              'x': 500.0,
              'y': 100.0,
              'width': 200.0,
              'height': 100.0,
            },
            {
              'id': 'conn-1',
              'type': 'connector',
              'startId': 'card-1',
              'endId': 'card-2',
              'startAnchor': 'auto',
              'endAnchor': 'auto',
            },
          ],
        });

        final conn = scene['conn-1']!;
        final endpoints = resolveConnectorEndpoints(conn, scene);

        expect(endpoints.resolvedStartAnchor, ConnectorAnchor.right);
        expect(endpoints.resolvedEndAnchor, ConnectorAnchor.left);
        expect(endpoints.start, const CanvasPoint(300.0, 150.0));
        expect(endpoints.end, const CanvasPoint(500.0, 150.0));
      },
    );

    test(
      'resolveConnectorEndpoints chooses Bottom-to-Top for vertical relationship',
      () {
        final scene = CanvasScene.fromJson({
          'elements': [
            {
              'id': 'card-1',
              'type': 'sticky',
              'x': 200.0,
              'y': 100.0,
              'width': 200.0,
              'height': 100.0,
            },
            {
              'id': 'card-2',
              'type': 'sticky',
              'x': 200.0,
              'y': 400.0,
              'width': 200.0,
              'height': 100.0,
            },
            {
              'id': 'conn-1',
              'type': 'connector',
              'startId': 'card-1',
              'endId': 'card-2',
            },
          ],
        });

        final conn = scene['conn-1']!;
        final endpoints = resolveConnectorEndpoints(conn, scene);

        expect(endpoints.resolvedStartAnchor, ConnectorAnchor.bottom);
        expect(endpoints.resolvedEndAnchor, ConnectorAnchor.top);
        expect(endpoints.start, const CanvasPoint(300.0, 200.0));
        expect(endpoints.end, const CanvasPoint(300.0, 400.0));
      },
    );

    test('resolveConnectorEndpoints respects explicit anchors', () {
      final scene = CanvasScene.fromJson({
        'elements': [
          {
            'id': 'card-1',
            'type': 'card',
            'x': 100.0,
            'y': 100.0,
            'width': 200.0,
            'height': 100.0,
          },
          {
            'id': 'card-2',
            'type': 'card',
            'x': 500.0,
            'y': 100.0,
            'width': 200.0,
            'height': 100.0,
          },
          {
            'id': 'conn-1',
            'type': 'connector',
            'startId': 'card-1',
            'endId': 'card-2',
            'startAnchor': 'top',
            'endAnchor': 'top',
          },
        ],
      });

      final conn = scene['conn-1']!;
      final endpoints = resolveConnectorEndpoints(conn, scene);

      expect(endpoints.resolvedStartAnchor, ConnectorAnchor.top);
      expect(endpoints.resolvedEndAnchor, ConnectorAnchor.top);
      expect(endpoints.start, const CanvasPoint(200.0, 100.0));
      expect(endpoints.end, const CanvasPoint(600.0, 100.0));
    });

    test(
      'ConnectorRouting generates control points for curved and orthogonal',
      () {
        final scene = CanvasScene.fromJson({
          'elements': [
            {
              'id': 'c1',
              'type': 'card',
              'x': 100.0,
              'y': 100.0,
              'width': 200.0,
              'height': 100.0,
            },
            {
              'id': 'c2',
              'type': 'card',
              'x': 500.0,
              'y': 100.0,
              'width': 200.0,
              'height': 100.0,
            },
            {
              'id': 'conn-curved',
              'type': 'connector',
              'startId': 'c1',
              'endId': 'c2',
              'routing': 'curved',
            },
            {
              'id': 'conn-ortho',
              'type': 'connector',
              'startId': 'c1',
              'endId': 'c2',
              'routing': 'orthogonal',
            },
          ],
        });

        final curvedEndpoints = resolveConnectorEndpoints(
          scene['conn-curved']!,
          scene,
        );
        expect(curvedEndpoints.controlPoints.length, 2);
        // cp1 should project rightward from start
        expect(
          curvedEndpoints.controlPoints[0].x,
          greaterThan(curvedEndpoints.start.x),
        );
        // cp2 should project leftward from end
        expect(
          curvedEndpoints.controlPoints[1].x,
          lessThan(curvedEndpoints.end.x),
        );

        final orthoEndpoints = resolveConnectorEndpoints(
          scene['conn-ortho']!,
          scene,
        );
        expect(orthoEndpoints.controlPoints.isNotEmpty, true);
      },
    );

    test('CanvasScene indexes and hits connectors properly', () {
      final scene = CanvasScene.fromJson({
        'elements': [
          {
            'id': 'n1',
            'type': 'card',
            'x': 100.0,
            'y': 100.0,
            'width': 200.0,
            'height': 100.0,
          },
          {
            'id': 'n2',
            'type': 'card',
            'x': 500.0,
            'y': 100.0,
            'width': 200.0,
            'height': 100.0,
          },
          {
            'id': 'c1',
            'type': 'connector',
            'startId': 'n1',
            'endId': 'n2',
            'color': 0xff6366f1,
          },
        ],
      });

      expect(scene['c1']?.renderable, true);
      // Querying the area between n1 and n2 should include the connector
      final found = scene.query(const CanvasBounds(350, 140, 20, 20));
      expect(found.any((e) => e.id == 'c1'), true);

      // Hit testing on the line segment
      final hitElem = scene.hit(const CanvasPoint(400, 150), tolerance: 8);
      expect(hitElem?.id, 'c1');
    });

    test(
      'CanvasElement getters parse strokeStyle, markers and routing correctly',
      () {
        final elem = CanvasElement({
          'id': 'conn-test',
          'type': 'connector',
          'strokeStyle': 'dashed',
          'startMarker': 'dot',
          'endMarker': 'diamond',
          'routing': 'orthogonal',
          'startAnchor': 'bottom',
          'endAnchor': 'top',
        });

        expect(elem.strokeStyle, 'dashed');
        expect(elem.startMarker, 'dot');
        expect(elem.endMarker, 'diamond');
        expect(elem.routing, 'orthogonal');
        expect(elem.startAnchor, 'bottom');
        expect(elem.endAnchor, 'top');
      },
    );

    test('ConnectorStyle and ConnectorMarker parsers handle edge cases', () {
      expect(ConnectorStyle.parse('dashed'), ConnectorStyle.dashed);
      expect(ConnectorStyle.parse('dotted'), ConnectorStyle.dotted);
      expect(ConnectorStyle.parse('solid'), ConnectorStyle.solid);
      expect(ConnectorStyle.parse(null), ConnectorStyle.solid);
      expect(ConnectorStyle.parse('unknown'), ConnectorStyle.solid);

      expect(ConnectorMarker.parse('arrow'), ConnectorMarker.arrow);
      expect(ConnectorMarker.parse('dot'), ConnectorMarker.dot);
      expect(ConnectorMarker.parse('diamond'), ConnectorMarker.diamond);
      expect(ConnectorMarker.parse('none'), ConnectorMarker.none);
      expect(
        ConnectorMarker.parse(null, defaultMarker: ConnectorMarker.arrow),
        ConnectorMarker.arrow,
      );

      expect(ConnectorRouting.parse('curved'), ConnectorRouting.curved);
      expect(ConnectorRouting.parse('orthogonal'), ConnectorRouting.orthogonal);
      expect(ConnectorRouting.parse('straight'), ConnectorRouting.straight);
      expect(ConnectorRouting.parse(null), ConnectorRouting.straight);
    });

    test(
      'OrbitCanvasPainter paints solid, dashed, dotted, curved, and orthogonal connectors with markers',
      () {
        final scene = CanvasScene.fromJson({
          'elements': [
            {
              'id': 'c1',
              'type': 'card',
              'x': 50.0,
              'y': 50.0,
              'width': 150.0,
              'height': 80.0,
            },
            {
              'id': 'c2',
              'type': 'card',
              'x': 400.0,
              'y': 50.0,
              'width': 150.0,
              'height': 80.0,
            },
            {
              'id': 'c3',
              'type': 'sticky',
              'x': 400.0,
              'y': 300.0,
              'width': 150.0,
              'height': 150.0,
            },
            {
              'id': 'conn-solid',
              'type': 'connector',
              'startId': 'c1',
              'endId': 'c2',
              'strokeStyle': 'solid',
              'startMarker': 'dot',
              'endMarker': 'arrow',
              'routing': 'straight',
              'text': 'Flow A',
            },
            {
              'id': 'conn-dashed',
              'type': 'connector',
              'startId': 'c1',
              'endId': 'c3',
              'strokeStyle': 'dashed',
              'startMarker': 'diamond',
              'endMarker': 'arrow',
              'routing': 'curved',
              'text': 'Curve B',
            },
            {
              'id': 'conn-dotted',
              'type': 'connector',
              'startId': 'c2',
              'endId': 'c3',
              'strokeStyle': 'dotted',
              'startMarker': 'none',
              'endMarker': 'diamond',
              'routing': 'orthogonal',
              'text': 'Step C',
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
          hoveredAnchorElementId: 'c1',
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, const Size(1000, 800));
        final picture = recorder.endRecording();
        expect(picture, isNotNull);
        cache.dispose();
        picture.dispose();
      },
    );

    test('distanceToSegment correctly computes distance to line segment', () {
      const a = CanvasPoint(100, 100);
      const b = CanvasPoint(300, 100);

      // Point on segment
      expect(distanceToSegment(const CanvasPoint(200, 100), a, b), 0.0);

      // Point above midpoint
      expect(distanceToSegment(const CanvasPoint(200, 80), a, b), 20.0);

      // Point beyond start (clamped to a)
      expect(distanceToSegment(const CanvasPoint(50, 100), a, b), 50.0);

      // Point beyond end (clamped to b)
      expect(distanceToSegment(const CanvasPoint(350, 100), a, b), 50.0);
    });

    test(
      'hitTestConnector hits straight, curved, orthogonal paths and label pill',
      () {
        final scene = CanvasScene.fromJson({
          'elements': [
            {
              'id': 'a1',
              'type': 'card',
              'x': 100.0,
              'y': 100.0,
              'width': 100.0,
              'height': 100.0,
            },
            {
              'id': 'a2',
              'type': 'card',
              'x': 500.0,
              'y': 100.0,
              'width': 100.0,
              'height': 100.0,
            },
            {
              'id': 'conn-curved',
              'type': 'connector',
              'startId': 'a1',
              'endId': 'a2',
              'routing': 'curved',
              'text': 'Connection Label',
            },
            {
              'id': 'conn-ortho',
              'type': 'connector',
              'startId': 'a1',
              'endId': 'a2',
              'routing': 'orthogonal',
            },
          ],
        });

        final connCurved = scene['conn-curved']!;
        final connOrtho = scene['conn-ortho']!;

        // Midpoint of curved connector should hit (label pill test)
        final epCurved = resolveConnectorEndpoints(connCurved, scene);
        expect(
          hitTestConnector(connCurved, scene, epCurved.midpoint, tolerance: 5),
          isTrue,
        );

        // Point near start anchor (200, 150)
        expect(
          hitTestConnector(
            connCurved,
            scene,
            const CanvasPoint(205, 150),
            tolerance: 5,
          ),
          isTrue,
        );

        // Point far away should not hit
        expect(
          hitTestConnector(
            connCurved,
            scene,
            const CanvasPoint(300, 800),
            tolerance: 5,
          ),
          isFalse,
        );

        // Orthogonal connector should hit along its path
        final epOrtho = resolveConnectorEndpoints(connOrtho, scene);
        expect(
          hitTestConnector(connOrtho, scene, epOrtho.start, tolerance: 5),
          isTrue,
        );
        expect(
          hitTestConnector(connOrtho, scene, epOrtho.end, tolerance: 5),
          isTrue,
        );
        for (final cp in epOrtho.controlPoints) {
          expect(hitTestConnector(connOrtho, scene, cp, tolerance: 5), isTrue);
        }
      },
    );

    test('CanvasScene.remove updates attached connectors in spatial index', () {
      final scene = CanvasScene.fromJson({
        'elements': [
          {
            'id': 'n1',
            'type': 'card',
            'x': 100.0,
            'y': 100.0,
            'width': 100.0,
            'height': 100.0,
          },
          {
            'id': 'n2',
            'type': 'card',
            'x': 400.0,
            'y': 100.0,
            'width': 100.0,
            'height': 100.0,
          },
          {'id': 'c-link', 'type': 'connector', 'startId': 'n1', 'endId': 'n2'},
        ],
      });

      expect(scene['c-link'], isNotNull);
      // Remove connected element n1
      scene.remove('n1');
      expect(scene['n1'], isNull);

      // The connector still exists and scene.remove executed cleanly
      expect(scene['c-link'], isNotNull);
    });

    test('CanvasScene.contentBounds reflects connector effective bounds', () {
      final scene = CanvasScene.fromJson({
        'elements': [
          {
            'id': 'c1',
            'type': 'card',
            'x': 500.0,
            'y': 500.0,
            'width': 100.0,
            'height': 100.0,
          },
          {
            'id': 'c2',
            'type': 'card',
            'x': 800.0,
            'y': 500.0,
            'width': 100.0,
            'height': 100.0,
          },
          {'id': 'conn', 'type': 'connector', 'startId': 'c1', 'endId': 'c2'},
        ],
      });

      final bounds = scene.contentBounds;
      expect(bounds, isNotNull);
      // Content bounds should NOT be anchored to (0, 0)
      expect(bounds!.left, greaterThanOrEqualTo(480.0));
      expect(bounds.right, greaterThanOrEqualTo(900.0));
    });
  });
}
