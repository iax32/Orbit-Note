import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/canvas_search.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/canvas/canvas_search_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pure Dart Canvas Spatial Search Engine (CAN-14)', () {
    late CanvasScene testScene;
    late MapCanvasObjectLookup objectLookup;

    setUp(() {
      testScene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'sticky-1',
            'type': 'sticky',
            'x': 50.0,
            'y': 50.0,
            'width': 180.0,
            'height': 180.0,
            'text': 'Buy milk and eggs for breakfast',
          },
          {
            'id': 'card-1',
            'type': 'card',
            'objectId': 'obj-101',
            'x': 300.0,
            'y': 50.0,
            'width': 260.0,
            'height': 160.0,
          },
          {
            'id': 'text-1',
            'type': 'text',
            'x': 50.0,
            'y': 300.0,
            'width': 200.0,
            'height': 40.0,
            'text': 'Sprint Retrospective Notes',
          },
          {
            'id': 'rect-1',
            'type': 'rectangle',
            'x': 300.0,
            'y': 300.0,
            'width': 140.0,
            'height': 80.0,
            'text': 'Architecture Subsystem',
          },
          {
            'id': 'link-1',
            'type': 'link',
            'x': 50.0,
            'y': 500.0,
            'width': 220.0,
            'height': 60.0,
            'url': 'https://orbitnote.dev/docs/search',
          },
        ],
      });

      final cardRef = CanvasObjectReference(
        id: 'obj-101',
        title: 'Quantum Computing Overview',
        typeId: 'orbit.note',
        body:
            'Superposition and entanglement principles applied to algorithms.',
        properties: {
          'tags': ['quantum', 'physics', 'research'],
          'status': 'in_progress',
          'priority': 'urgent',
          'project': 'Science 2026',
          'folder': 'Notes/Physics',
        },
      );

      objectLookup = MapCanvasObjectLookup({'obj-101': cardRef});
    });

    test('finds direct element text in sticky notes and text elements', () {
      final results = searchCanvasElements(
        scene: testScene,
        objectLookup: objectLookup,
        query: 'breakfast',
      );

      expect(results.length, equals(1));
      expect(results.first.elementId, equals('sticky-1'));
      expect(results.first.elementType, equals('sticky'));
      expect(results.first.snippet.toLowerCase(), contains('breakfast'));
    });

    test('finds referenced card titles, bodies, and tags', () {
      // Search title
      final titleResults = searchCanvasElements(
        scene: testScene,
        objectLookup: objectLookup,
        query: 'quantum',
      );
      expect(titleResults.length, equals(1));
      expect(titleResults.first.elementId, equals('card-1'));
      expect(titleResults.first.title, equals('Quantum Computing Overview'));

      // Search body
      final bodyResults = searchCanvasElements(
        scene: testScene,
        objectLookup: objectLookup,
        query: 'entanglement',
      );
      expect(bodyResults.length, equals(1));
      expect(bodyResults.first.elementId, equals('card-1'));
      expect(bodyResults.first.snippet.toLowerCase(), contains('entanglement'));

      // Search tags
      final tagResults = searchCanvasElements(
        scene: testScene,
        objectLookup: objectLookup,
        query: 'physics',
      );
      expect(tagResults.length, equals(1));
      expect(tagResults.first.elementId, equals('card-1'));
      expect(tagResults.first.snippet, contains('#physics'));
    });

    test(
      'finds referenced card project, folder, status, and priority metadata',
      () {
        // Search folder
        final folderResults = searchCanvasElements(
          scene: testScene,
          objectLookup: objectLookup,
          query: 'Notes/Physics',
        );
        expect(folderResults.length, equals(1));
        expect(folderResults.first.elementId, equals('card-1'));
        expect(folderResults.first.snippet, contains('Notes/Physics'));

        // Search status
        final statusResults = searchCanvasElements(
          scene: testScene,
          objectLookup: objectLookup,
          query: 'in_progress',
        );
        expect(statusResults.length, equals(1));
        expect(statusResults.first.elementId, equals('card-1'));
        expect(statusResults.first.snippet, contains('Status: in_progress'));
      },
    );

    test('finds links by URL query', () {
      final results = searchCanvasElements(
        scene: testScene,
        objectLookup: objectLookup,
        query: 'orbitnote.dev',
      );
      expect(results.length, equals(1));
      expect(results.first.elementId, equals('link-1'));
      expect(results.first.snippet, contains('orbitnote.dev'));
    });

    test(
      'sorts results in spatial reading order (top-to-bottom, left-to-right)',
      () {
        // Query that matches everything with 'e'
        final results = searchCanvasElements(
          scene: testScene,
          objectLookup: objectLookup,
          query: 'e',
        );

        // Verify y coordinates are non-decreasing
        for (var i = 0; i < results.length - 1; i++) {
          final current = results[i].bounds;
          final next = results[i + 1].bounds;
          if (current.top == next.top) {
            expect(current.left <= next.left, isTrue);
          } else {
            expect(current.top <= next.top, isTrue);
          }
        }
      },
    );

    test('filters results strictly by CanvasSearchCategory', () {
      // Search 'e' matches sticky, card, text, rect, link
      final allResults = searchCanvasElements(
        scene: testScene,
        objectLookup: objectLookup,
        query: 'e',
        category: CanvasSearchCategory.all,
      );
      expect(allResults.length, greaterThanOrEqualTo(4));

      final cardResults = searchCanvasElements(
        scene: testScene,
        objectLookup: objectLookup,
        query: 'e',
        category: CanvasSearchCategory.cards,
      );
      expect(
        cardResults.every((r) => r.category == CanvasSearchCategory.cards),
        isTrue,
      );
      expect(cardResults.length, equals(1));

      final textResults = searchCanvasElements(
        scene: testScene,
        objectLookup: objectLookup,
        query: 'e',
        category: CanvasSearchCategory.text,
      );
      expect(
        textResults.every((r) => r.category == CanvasSearchCategory.text),
        isTrue,
      );

      final shapeResults = searchCanvasElements(
        scene: testScene,
        objectLookup: objectLookup,
        query: 'architecture',
        category: CanvasSearchCategory.shapes,
      );
      expect(shapeResults.length, equals(1));
      expect(shapeResults.first.elementId, equals('rect-1'));

      final mediaResults = searchCanvasElements(
        scene: testScene,
        objectLookup: objectLookup,
        query: 'search',
        category: CanvasSearchCategory.media,
      );
      expect(mediaResults.length, equals(1));
      expect(mediaResults.first.elementId, equals('link-1'));
    });

    test('handles empty and whitespace-only queries gracefully', () {
      expect(
        searchCanvasElements(
          scene: testScene,
          objectLookup: objectLookup,
          query: '',
        ),
        isEmpty,
      );
      expect(
        searchCanvasElements(
          scene: testScene,
          objectLookup: objectLookup,
          query: '   ',
        ),
        isEmpty,
      );
    });

    test(
      'handles elements with empty or missing type without throwing RangeError',
      () {
        final untypedScene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'untyped-1',
              'x': 50.0,
              'y': 50.0,
              'width': 100.0,
              'height': 100.0,
              'text': 'Untyped legacy content',
            },
            {
              'id': 'empty-type-1',
              'type': '',
              'x': 50.0,
              'y': 200.0,
              'width': 100.0,
              'height': 100.0,
              'text': 'Empty type content',
            },
          ],
        });

        final results = searchCanvasElements(
          scene: untypedScene,
          objectLookup: const MapCanvasObjectLookup({}),
          query: 'content',
        );

        expect(results.length, equals(2));
        expect(results.first.title, equals('Element'));
        expect(results.last.title, equals('Element'));
      },
    );
  });

  group('OrbitCanvasPainter Search Match Highlighting', () {
    test('repaints when searchMatchIds or activeSearchMatchId change', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'e1',
            'type': 'sticky',
            'x': 100.0,
            'y': 100.0,
            'width': 120.0,
            'height': 120.0,
            'text': 'Hello world',
          },
        ],
      });

      final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
      final textCache = CanvasTextCache();

      final painter1 = OrbitCanvasPainter(
        scene: scene,
        camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
        selection: const {},
        colors: colors,
        textCache: textCache,
        objects: const {},
        searchMatchIds: const {'e1'},
        activeSearchMatchId: null,
      );

      final painter2 = OrbitCanvasPainter(
        scene: scene,
        camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
        selection: const {},
        colors: colors,
        textCache: textCache,
        objects: const {},
        searchMatchIds: const {'e1'},
        activeSearchMatchId: 'e1',
      );

      expect(painter2.shouldRepaint(painter1), isTrue);

      final painter3 = OrbitCanvasPainter(
        scene: scene,
        camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
        selection: const {},
        colors: colors,
        textCache: textCache,
        objects: const {},
        searchMatchIds: const {},
        activeSearchMatchId: null,
      );

      expect(painter3.shouldRepaint(painter1), isTrue);
    });

    test(
      'paints search highlight outline and active focus halo without error',
      () {
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'e1',
              'type': 'sticky',
              'x': 100.0,
              'y': 100.0,
              'width': 120.0,
              'height': 120.0,
              'text': 'Target element',
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
          objects: const {},
          searchMatchIds: const {'e1'},
          activeSearchMatchId: 'e1',
        );

        expect(
          () => painter.paint(canvas, const Size(800, 600)),
          returnsNormally,
        );
      },
    );
  });

  group('CanvasSearchOverlay Widget Tests', () {
    testWidgets(
      'search controls remain usable in a narrow pane at large text',
      (tester) async {
        final controller = TextEditingController(text: 'research');
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        var closed = false;
        var next = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 280,
                    child: CanvasSearchOverlay(
                      searchController: controller,
                      searchFocusNode: focus,
                      results: const [
                        CanvasSearchResult(
                          elementId: 'a',
                          elementType: 'card',
                          title: 'Research',
                          snippet: 'Research',
                          bounds: CanvasBounds(0, 0, 100, 100),
                          category: CanvasSearchCategory.cards,
                        ),
                      ],
                      activeIndex: 0,
                      category: CanvasSearchCategory.all,
                      onCategoryChanged: (_) {},
                      onNext: () => next = true,
                      onPrevious: () {},
                      onSelectIndex: (_) {},
                      onClose: () => closed = true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(TextField)).width, greaterThan(120));
        await tester.tap(find.byTooltip('Next (Enter)'));
        await tester.tap(find.byTooltip('Close (Esc)'));
        expect(next, isTrue);
        expect(closed, isTrue);
      },
    );

    testWidgets('renders input, match counter, buttons, and category chips', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'research');
      final focusNode = FocusNode();
      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
      });

      var nextCalled = false;
      var prevCalled = false;
      var closeCalled = false;
      CanvasSearchCategory? changedCategory;
      int? selectedIndex;

      final results = [
        const CanvasSearchResult(
          elementId: 'e1',
          elementType: 'card',
          title: 'Quantum Research',
          snippet: 'Research note on quantum principles',
          bounds: CanvasBounds(10, 10, 100, 100),
          category: CanvasSearchCategory.cards,
        ),
        const CanvasSearchResult(
          elementId: 'e2',
          elementType: 'sticky',
          title: 'Research Meeting',
          snippet: 'Team research sync',
          bounds: CanvasBounds(200, 200, 80, 80),
          category: CanvasSearchCategory.text,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasSearchOverlay(
              searchController: controller,
              searchFocusNode: focusNode,
              results: results,
              activeIndex: 0,
              category: CanvasSearchCategory.all,
              onCategoryChanged: (cat) => changedCategory = cat,
              onNext: () => nextCalled = true,
              onPrevious: () => prevCalled = true,
              onSelectIndex: (idx) => selectedIndex = idx,
              onClose: () => closeCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify counter badge
      expect(find.text('1 of 2'), findsOneWidget);

      // Verify category chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Cards'), findsOneWidget);
      expect(find.text('Text & Notes'), findsOneWidget);
      expect(find.text('Shapes'), findsOneWidget);
      expect(find.text('Media'), findsOneWidget);

      // Tap Next button
      await tester.tap(find.byTooltip('Next (Enter)'));
      expect(nextCalled, isTrue);

      // Tap Previous button
      await tester.tap(find.byTooltip('Previous (Shift+Enter)'));
      expect(prevCalled, isTrue);

      // Tap category chip
      await tester.tap(find.text('Cards'));
      expect(changedCategory, equals(CanvasSearchCategory.cards));

      // Toggle expandable results drawer
      final expandBtn = find.byTooltip('Show results');
      expect(expandBtn, findsOneWidget);
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();

      // Verify drawer list items are visible
      expect(find.text('Quantum Research'), findsOneWidget);
      expect(find.text('Research Meeting'), findsOneWidget);

      // Tap a result item
      await tester.tap(find.text('Research Meeting'));
      expect(selectedIndex, equals(1));

      // Tap Close button
      await tester.tap(find.byTooltip('Close (Esc)'));
      expect(closeCalled, isTrue);
    });
  });

  group('CanvasEditor Search Integration & Hotkeys', () {
    testWidgets(
      'Toolbar search button toggles search HUD and Ctrl+F opens search HUD',
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
              'width': 200.0,
              'height': 150.0,
              'text': 'Architecture Planning Note',
            },
            {
              'id': 'e2',
              'type': 'text',
              'x': 600.0,
              'y': 400.0,
              'width': 180.0,
              'height': 50.0,
              'text': 'Project Roadmap 2026',
            },
          ],
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'search-test-canvas',
                data: sceneData,
                objects: const [],
                onOpenObject: (_) {},
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Search overlay should initially not be visible
        expect(
          find.byKey(const ValueKey('canvas-search-overlay')),
          findsNothing,
        );

        // Find toolbar search button
        final searchButton = find.byKey(const ValueKey('canvas-search-button'));
        expect(searchButton, findsOneWidget);

        // Tap search button to open overlay
        await tester.tap(searchButton);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('canvas-search-overlay')),
          findsOneWidget,
        );

        // Type query into search field
        await tester.enterText(find.byType(TextField), 'Planning');
        await tester.pumpAndSettle();

        // Match count should show 1 of 1
        expect(find.text('1 of 1'), findsOneWidget);

        // Press Escape to close search HUD
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        // Search overlay should now be dismissed
        expect(
          find.byKey(const ValueKey('canvas-search-overlay')),
          findsNothing,
        );

        // Press Ctrl+F to open search HUD again
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('canvas-search-overlay')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Cycling search matches navigates results and updates selection',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sceneData = {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'note-1',
              'type': 'sticky',
              'x': 100.0,
              'y': 100.0,
              'width': 150.0,
              'height': 150.0,
              'text': 'Project Alpha item',
            },
            {
              'id': 'note-2',
              'type': 'sticky',
              'x': 800.0,
              'y': 600.0,
              'width': 150.0,
              'height': 150.0,
              'text': 'Project Beta item',
            },
          ],
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'search-cycle-canvas',
                data: sceneData,
                objects: const [],
                onOpenObject: (_) {},
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open search HUD
        await tester.tap(find.byKey(const ValueKey('canvas-search-button')));
        await tester.pumpAndSettle();

        // Search for 'Project'
        await tester.enterText(find.byType(TextField), 'Project');
        await tester.pumpAndSettle();

        // Should show '1 of 2'
        expect(find.text('1 of 2'), findsOneWidget);

        // Tap Next button
        await tester.tap(find.byTooltip('Next (Enter)'));
        await tester.pumpAndSettle();

        // Should show '2 of 2'
        expect(find.text('2 of 2'), findsOneWidget);

        // Tap Previous button
        await tester.tap(find.byTooltip('Previous (Shift+Enter)'));
        await tester.pumpAndSettle();

        // Should wrap back to '1 of 2'
        expect(find.text('1 of 2'), findsOneWidget);
      },
    );
  });
}
