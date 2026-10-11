import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/groups.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

void main() {
  group('Canvas Groups Domain Engine (CAN-04, CAN-05)', () {
    test(
      'groupElements assigns shared unique groupId to multiple elements',
      () {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'e1',
              'type': 'rectangle',
              'x': 10,
              'y': 10,
              'width': 100,
              'height': 80,
            },
            {
              'id': 'e2',
              'type': 'sticky',
              'x': 120,
              'y': 20,
              'width': 150,
              'height': 150,
            },
          ],
        });

        final grouped = groupElements(scene, ['e1', 'e2']);
        expect(grouped.length, 2);
        expect(grouped[0].groupId, isNotNull);
        expect(grouped[0].groupId, equals(grouped[1].groupId));
        expect(grouped[0].groupId!.startsWith('grp_'), isTrue);
      },
    );

    test('groupElements requires at least 2 elements', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'e1',
            'type': 'rectangle',
            'x': 10,
            'y': 10,
            'width': 100,
            'height': 80,
          },
        ],
      });

      final grouped = groupElements(scene, ['e1']);
      expect(grouped, isEmpty);
    });

    test('getGroupMembers and getAllGroupIds retrieve grouped elements', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'e1',
            'type': 'rectangle',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 100,
            'groupId': 'grp_1',
          },
          {
            'id': 'e2',
            'type': 'diamond',
            'x': 200,
            'y': 200,
            'width': 100,
            'height': 100,
            'groupId': 'grp_1',
          },
          {
            'id': 'e3',
            'type': 'text',
            'x': 400,
            'y': 400,
            'width': 100,
            'height': 50,
          },
        ],
      });

      final members = getGroupMembers(scene, 'grp_1');
      expect(members.map((e) => e.id).toSet(), equals({'e1', 'e2'}));

      final groupIds = getAllGroupIds(scene);
      expect(groupIds, equals(['grp_1']));
    });

    test('calculateGroupBounds returns accurate union bounding box', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'e1',
            'type': 'rectangle',
            'x': 50,
            'y': 60,
            'width': 100,
            'height': 80,
            'groupId': 'grp_A',
          },
          {
            'id': 'e2',
            'type': 'sticky',
            'x': 200,
            'y': 150,
            'width': 120,
            'height': 100,
            'groupId': 'grp_A',
          },
        ],
      });

      final bounds = calculateGroupBounds(scene, 'grp_A');
      expect(bounds, isNotNull);
      expect(bounds!.left, 50);
      expect(bounds.top, 60);
      expect(bounds.right, 320); // 200 + 120
      expect(bounds.bottom, 250); // 150 + 100
      expect(bounds.width, 270);
      expect(bounds.height, 190);
    });

    test('ungroupElements removes groupId across all group members', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'e1',
            'type': 'rectangle',
            'x': 0,
            'y': 0,
            'width': 50,
            'height': 50,
            'groupId': 'grp_team',
          },
          {
            'id': 'e2',
            'type': 'ellipse',
            'x': 100,
            'y': 100,
            'width': 50,
            'height': 50,
            'groupId': 'grp_team',
          },
        ],
      });

      // Ungrouping by referencing only e1 ungroups all members of grp_team
      final ungrouped = ungroupElements(scene, ['e1']);
      expect(ungrouped.length, 2);
      expect(ungrouped[0].groupId, isNull);
      expect(ungrouped[1].groupId, isNull);
    });

    test(
      'isGroupLocked detects locked members to prevent group transforms',
      () {
        final unlockedScene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'e1',
              'type': 'rectangle',
              'x': 0,
              'y': 0,
              'width': 50,
              'height': 50,
              'groupId': 'grp_X',
              'locked': false,
            },
            {
              'id': 'e2',
              'type': 'sticky',
              'x': 60,
              'y': 0,
              'width': 50,
              'height': 50,
              'groupId': 'grp_X',
              'locked': false,
            },
          ],
        });
        expect(isGroupLocked(unlockedScene, 'grp_X'), isFalse);

        final lockedScene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'e1',
              'type': 'rectangle',
              'x': 0,
              'y': 0,
              'width': 50,
              'height': 50,
              'groupId': 'grp_X',
              'locked': false,
            },
            {
              'id': 'e2',
              'type': 'sticky',
              'x': 60,
              'y': 0,
              'width': 50,
              'height': 50,
              'groupId': 'grp_X',
              'locked': true,
            },
          ],
        });
        expect(isGroupLocked(lockedScene, 'grp_X'), isTrue);
      },
    );

    test(
      'duplicateGroupElements clones group members with new shared groupId and offset',
      () {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'orig_1',
              'type': 'rectangle',
              'x': 100,
              'y': 100,
              'width': 60,
              'height': 40,
              'groupId': 'grp_orig',
            },
            {
              'id': 'orig_2',
              'type': 'ellipse',
              'x': 200,
              'y': 100,
              'width': 40,
              'height': 40,
              'groupId': 'grp_orig',
            },
          ],
        });

        var idCounter = 1;
        final dupes = duplicateGroupElements(
          scene,
          'grp_orig',
          () => 'dup_${idCounter++}',
          offset: const CanvasPoint(50, 50),
        );

        expect(dupes.length, 2);
        expect(dupes[0].id, 'dup_1');
        expect(dupes[1].id, 'dup_2');
        expect(dupes[0].x, 150);
        expect(dupes[0].y, 150);
        expect(dupes[1].x, 250);
        expect(dupes[1].y, 150);
        expect(dupes[0].groupId, isNotNull);
        expect(dupes[0].groupId, isNot(equals('grp_orig')));
        expect(dupes[0].groupId, equals(dupes[1].groupId));
      },
    );

    test(
      'CanvasHistory supports atomic undo and redo of grouping and ungrouping',
      () {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'e1',
              'type': 'rectangle',
              'x': 0,
              'y': 0,
              'width': 100,
              'height': 80,
            },
            {
              'id': 'e2',
              'type': 'sticky',
              'x': 120,
              'y': 0,
              'width': 100,
              'height': 80,
            },
          ],
        });
        final history = CanvasHistory(scene);

        // Perform grouping transaction
        history.begin();
        final grouped = groupElements(scene, [
          'e1',
          'e2',
        ], newGroupId: 'grp_test');
        for (final e in grouped) {
          history.put(e);
        }
        history.commit();

        expect(scene['e1']?.groupId, 'grp_test');
        expect(scene['e2']?.groupId, 'grp_test');

        // Undo grouping
        expect(history.undo(), isTrue);
        expect(scene['e1']?.groupId, isNull);
        expect(scene['e2']?.groupId, isNull);

        // Redo grouping
        expect(history.redo(), isTrue);
        expect(scene['e1']?.groupId, 'grp_test');
        expect(scene['e2']?.groupId, 'grp_test');

        // Perform ungrouping transaction
        history.begin();
        final ungrouped = ungroupElements(scene, ['e1']);
        for (final e in ungrouped) {
          history.put(e);
        }
        history.commit();

        expect(scene['e1']?.groupId, isNull);
        expect(scene['e2']?.groupId, isNull);

        // Undo ungrouping restores group
        expect(history.undo(), isTrue);
        expect(scene['e1']?.groupId, 'grp_test');
        expect(scene['e2']?.groupId, 'grp_test');
      },
    );

    test(
      'group data serializes and deserializes cleanly through toJson roundtrip',
      () {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'e1',
              'type': 'rectangle',
              'x': 10,
              'y': 20,
              'width': 100,
              'height': 80,
              'groupId': 'grp_persistent',
            },
          ],
        });

        final json = scene.toJson();
        final elementsList = json['elements'] as List;
        final e1Map = elementsList.first as Map<String, dynamic>;
        expect(e1Map['groupId'], 'grp_persistent');

        final reloaded = CanvasScene.fromJson(json);
        expect(reloaded['e1']?.groupId, 'grp_persistent');
      },
    );
  });

  group('Canvas Painter Group Rendering', () {
    testWidgets(
      'OrbitCanvasPainter renders group bounds and badge for selected groups',
      (tester) async {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'g1',
              'type': 'rectangle',
              'x': 100,
              'y': 100,
              'width': 120,
              'height': 80,
              'groupId': 'grp_visual',
            },
            {
              'id': 'g2',
              'type': 'sticky',
              'x': 260,
              'y': 100,
              'width': 120,
              'height': 80,
              'groupId': 'grp_visual',
            },
          ],
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CustomPaint(
                size: const Size(800, 600),
                painter: OrbitCanvasPainter(
                  scene: scene,
                  camera: CanvasCamera(),
                  selection: {'g1', 'g2'},
                  colors: const ColorScheme.dark(),
                  objects: const {},
                  textCache: CanvasTextCache(),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('CanvasEditor Group Interactions (CAN-04, CAN-05)', () {
    testWidgets('CanvasEditor shows Group / Ungroup button in top toolbar', (
      tester,
    ) async {
      Map<String, dynamic> doc = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'c1',
            'type': 'rectangle',
            'x': 100,
            'y': 100,
            'width': 150,
            'height': 100,
          },
          {
            'id': 'c2',
            'type': 'sticky',
            'x': 300,
            'y': 100,
            'width': 150,
            'height': 100,
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board-1',
              data: doc,
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (data) => doc = data,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the Group / Ungroup toolbar button is present with its tooltip
      final groupButtonFinder = find.byTooltip(
        'Group (Ctrl+G) / Ungroup (Ctrl+Shift+G)',
      );
      expect(groupButtonFinder, findsNothing);
      final surface = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
      );
      await tester.tapAt(tester.getTopLeft(surface) + const Offset(150, 140));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(groupButtonFinder, findsOneWidget);
      final actions = find.byTooltip('Selection actions');
      await tester.ensureVisible(actions);
      await tester.tap(actions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      expect(doc['elements'], hasLength(4));
      expect(
        (doc['elements'] as List).where((e) => e['id'] == 'c1'),
        hasLength(1),
      );
    });

    testWidgets(
      'CanvasEditor single-click on grouped element selects all group members',
      (tester) async {
        Map<String, dynamic> doc = {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'item1',
              'type': 'rectangle',
              'x': 100,
              'y': 100,
              'width': 120,
              'height': 80,
              'groupId': 'grp_pair',
            },
            {
              'id': 'item2',
              'type': 'sticky',
              'x': 250,
              'y': 100,
              'width': 120,
              'height': 80,
              'groupId': 'grp_pair',
            },
          ],
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'board-1',
                data: doc,
                objects: const [],
                onOpenObject: (_) {},
                onChanged: (data) => doc = data,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final surface = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
        );
        final origin = tester.getTopLeft(surface);

        // Tap on item1 at screen coordinates inside the canvas
        await tester.tapAt(origin + const Offset(150, 140));
        await tester.pumpAndSettle();

        // Open context menu to verify selection has 2 items
        await tester.tapAt(
          origin + const Offset(150, 140),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        // Both items are selected, so Ungroup (Ctrl+Shift+G) should appear in context menu
        expect(find.text('Ungroup (Ctrl+Shift+G)'), findsOneWidget);
      },
    );

    testWidgets('Layer Manager shows Group badge for grouped elements', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      Map<String, dynamic> doc = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'e1',
            'type': 'rectangle',
            'x': 100,
            'y': 100,
            'width': 100,
            'height': 100,
            'groupId': 'grp_demo',
          },
          {
            'id': 'e2',
            'type': 'text',
            'x': 250,
            'y': 100,
            'width': 100,
            'height': 50,
            'text': 'Plain text',
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board-1',
              data: doc,
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (data) => doc = data,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the Layers button in the top toolbar
      final layersButton = find.byTooltip('Layers & element list');
      expect(layersButton, findsOneWidget);
      await tester.tap(layersButton);
      await tester.pumpAndSettle();

      // Check that the dialog is open and shows the 'Group' pill badge
      expect(find.text('Layers & Stacking Order'), findsOneWidget);
      expect(find.text('Group'), findsOneWidget);
    });
  });
}
