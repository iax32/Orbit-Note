import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

void main() {
  group('CanvasObjectReference helpers', () {
    test('detects completion state accurately', () {
      const openRef = CanvasObjectReference(
        id: 't1',
        title: 'Open Task',
        typeId: 'orbit.task',
        properties: {'status': 'open'},
      );
      expect(openRef.isCompleted, isFalse);

      const doneRef1 = CanvasObjectReference(
        id: 't2',
        title: 'Done Task 1',
        typeId: 'orbit.task',
        properties: {'completed': true},
      );
      expect(doneRef1.isCompleted, isTrue);

      const doneRef2 = CanvasObjectReference(
        id: 't3',
        title: 'Done Task 2',
        typeId: 'orbit.task',
        properties: {'status': 'done'},
      );
      expect(doneRef2.isCompleted, isTrue);
    });

    test('extracts file types, tags, and project/folder metadata', () {
      const pdfRef = CanvasObjectReference(
        id: 'f1',
        title: 'Paper.pdf',
        typeId: 'orbit.file',
        properties: {
          'mimeType': 'application/pdf',
          'filePath': 'Attachments/paper.pdf',
          'project': 'Research',
          'folder': 'Papers',
          'tags': ['ml', 'agents'],
          'priority': 'high',
          'dueDate': '2026-10-01',
        },
      );
      expect(pdfRef.isPdf, isTrue);
      expect(pdfRef.isImage, isFalse);
      expect(pdfRef.contentRef, 'Attachments/paper.pdf');
      expect(pdfRef.project, 'Research');
      expect(pdfRef.folder, 'Papers');
      expect(pdfRef.tags, ['ml', 'agents']);
      expect(pdfRef.priority, 'high');
      expect(pdfRef.dueDate, '2026-10-01');

      const imgRef = CanvasObjectReference(
        id: 'f2',
        title: 'Diagram.png',
        typeId: 'orbit.file',
        properties: {
          'mimeType': 'image/png',
          'attachmentRef': 'Attachments/diagram.png',
        },
      );
      expect(imgRef.isPdf, isFalse);
      expect(imgRef.isImage, isTrue);
      expect(imgRef.contentRef, 'Attachments/diagram.png');
    });

    test('extracts PDF highlight source quote if present', () {
      const highlightRef = CanvasObjectReference(
        id: 'n1',
        title: 'Highlight Note',
        typeId: 'orbit.note',
        properties: {
          'pdfSource': {
            'fileId': 'pdf-1',
            'page': 3,
            'quote': 'Personal knowledge systems must be local-first.',
          },
        },
      );
      expect(highlightRef.pdfSource, isNotNull);
      expect(highlightRef.pdfSource!['page'], 3);
      expect(
        highlightRef.pdfSource!['quote'],
        'Personal knowledge systems must be local-first.',
      );
    });
  });

  group('CanvasElement getters', () {
    test('cardPresentation defaults to card and reads custom presentation', () {
      final defaultCard = CanvasElement({
        'id': 'c1',
        'type': 'card',
        'x': 0.0,
        'y': 0.0,
        'width': 200.0,
        'height': 150.0,
      });
      expect(defaultCard.cardPresentation, 'card');

      final compactCard = CanvasElement({
        'id': 'c2',
        'type': 'card',
        'x': 0.0,
        'y': 0.0,
        'width': 200.0,
        'height': 44.0,
        'presentation': 'compact',
      });
      expect(compactCard.cardPresentation, 'compact');

      final previewCard = CanvasElement({
        'id': 'c3',
        'type': 'card',
        'x': 0.0,
        'y': 0.0,
        'width': 260.0,
        'height': 220.0,
        'presentation': 'preview',
      });
      expect(previewCard.cardPresentation, 'preview');

      final propertiesCard = CanvasElement({
        'id': 'c4',
        'type': 'card',
        'x': 0.0,
        'y': 0.0,
        'width': 260.0,
        'height': 200.0,
        'presentation': 'properties',
      });
      expect(propertiesCard.cardPresentation, 'properties');
    });

    test('viewConfig parses dynamic view configuration', () {
      final cardWithView = CanvasElement({
        'id': 'v1',
        'type': 'card',
        'x': 0.0,
        'y': 0.0,
        'width': 280.0,
        'height': 240.0,
        'viewConfig': {
          'type': 'task',
          'status': 'open',
          'project': 'Orbit Note',
          'limit': 5,
        },
      });
      expect(cardWithView.viewConfig, isNotNull);
      expect(cardWithView.viewConfig!['type'], 'task');
      expect(cardWithView.viewConfig!['status'], 'open');
      expect(cardWithView.viewConfig!['project'], 'Orbit Note');
    });
  });

  group('OrbitCanvasPainter card presentation rendering', () {
    testWidgets('paints all 4 presentations without error', (tester) async {
      final elementsData = [
        {
          'id': 'card-compact',
          'type': 'card',
          'x': 10.0,
          'y': 10.0,
          'width': 220.0,
          'height': 48.0,
          'objectId': 't1',
          'title': 'Compact Task',
          'presentation': 'compact',
        },
        {
          'id': 'card-card',
          'type': 'card',
          'x': 10.0,
          'y': 70.0,
          'width': 240.0,
          'height': 140.0,
          'objectId': 'n1',
          'title': 'Card Note',
          'body': 'This is regular note body text.',
          'presentation': 'card',
        },
        {
          'id': 'card-preview',
          'type': 'card',
          'x': 10.0,
          'y': 220.0,
          'width': 260.0,
          'height': 180.0,
          'objectId': 'f1',
          'title': 'Preview PDF',
          'presentation': 'preview',
        },
        {
          'id': 'card-properties',
          'type': 'card',
          'x': 10.0,
          'y': 410.0,
          'width': 260.0,
          'height': 180.0,
          'objectId': 't2',
          'title': 'Properties Task',
          'presentation': 'properties',
        },
      ];

      final objects = {
        't1': const CanvasObjectReference(
          id: 't1',
          title: 'Compact Task',
          typeId: 'orbit.task',
          properties: {'status': 'open'},
        ),
        'n1': const CanvasObjectReference(
          id: 'n1',
          title: 'Card Note',
          typeId: 'orbit.note',
          body: 'This is regular note body text.',
        ),
        'f1': const CanvasObjectReference(
          id: 'f1',
          title: 'Preview PDF',
          typeId: 'orbit.file',
          properties: {
            'mimeType': 'application/pdf',
            'pdfSource': {
              'page': 1,
              'quote': 'Offline-first spatial computing architecture.',
            },
          },
        ),
        't2': const CanvasObjectReference(
          id: 't2',
          title: 'Properties Task',
          typeId: 'orbit.task',
          properties: {
            'completed': true,
            'project': 'Orbit',
            'priority': 'high',
            'dueDate': '2026-12-31',
            'tags': ['core', 'v1'],
          },
        ),
      };

      final textCache = CanvasTextCache();
      addTearDown(textCache.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CustomPaint(
              size: const Size(800, 800),
              painter: OrbitCanvasPainter(
                scene: CanvasScene.fromJson({'elements': elementsData}),
                camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
                colors: orbitDarkTheme().colorScheme,
                selection: {},
                objects: objects,
                textCache: textCache,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets(
      'paints embedded dynamic view card with items and progress bar',
      (tester) async {
        final elementsData = [
          {
            'id': 'view-card-1',
            'type': 'card',
            'x': 20.0,
            'y': 20.0,
            'width': 300.0,
            'height': 220.0,
            'title': 'Active Sprint Tasks',
            'presentation': 'card',
            'viewConfig': {
              'type': 'task',
              'status': 'all',
              'project': 'Engine',
            },
          },
        ];

        final objects = {
          't1': const CanvasObjectReference(
            id: 't1',
            title: 'Build parser',
            typeId: 'orbit.task',
            properties: {'completed': true, 'project': 'Engine'},
          ),
          't2': const CanvasObjectReference(
            id: 't2',
            title: 'Write tests',
            typeId: 'orbit.task',
            properties: {'completed': false, 'project': 'Engine'},
          ),
        };

        final textCache = CanvasTextCache();
        addTearDown(textCache.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CustomPaint(
                size: const Size(600, 400),
                painter: OrbitCanvasPainter(
                  scene: CanvasScene.fromJson({'elements': elementsData}),
                  camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
                  colors: orbitDarkTheme().colorScheme,
                  selection: {},
                  objects: objects,
                  textCache: textCache,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );
  });

  group('CanvasCardPreviewTooltip widget', () {
    testWidgets('renders task card tooltip and triggers actions', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') return null;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final element = CanvasElement({
        'id': 'card-1',
        'type': 'card',
        'x': 50.0,
        'y': 50.0,
        'width': 240.0,
        'height': 140.0,
        'objectId': 'task-10',
      });
      const object = CanvasObjectReference(
        id: 'task-10',
        title: 'Deploy Production Release',
        typeId: 'orbit.task',
        properties: {
          'completed': false,
          'priority': 'urgent',
          'dueDate': '2026-10-15',
          'project': 'Milestone 1',
        },
      );

      bool toggled = false;
      String? toggledId;
      bool opened = false;
      bool cycled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasCardPreviewTooltip(
              element: element,
              object: object,
              objects: {'task-10': object},
              onOpen: () => opened = true,
              onToggleTask: (id) {
                toggled = true;
                toggledId = id;
              },
              onCyclePresentation: () => cycled = true,
              onDismiss: () {},
              onEnterTooltip: () {},
              onExitTooltip: () {},
            ),
          ),
        ),
      );

      // Verify title & badges
      expect(find.text('Deploy Production Release'), findsOneWidget);
      expect(find.textContaining('TASK'), findsOneWidget);
      expect(find.text('Milestone 1'), findsOneWidget);
      expect(find.text('urgent'), findsOneWidget);

      // Tap toggle task button
      final toggleBtn = find.byKey(
        const ValueKey('canvas-card-tooltip-toggle-action'),
      );
      expect(toggleBtn, findsOneWidget);
      await tester.tap(toggleBtn);
      await tester.pump();
      expect(toggled, isTrue);
      expect(toggledId, 'task-10');

      // Tap cycle presentation button
      final cycleBtn = find.byKey(
        const ValueKey('canvas-card-tooltip-cycle-presentation'),
      );
      expect(cycleBtn, findsOneWidget);
      await tester.tap(cycleBtn);
      await tester.pump();
      expect(cycled, isTrue);

      // Tap copy link button
      final copyLinkBtn = find.byKey(
        const ValueKey('canvas-card-tooltip-copy-link'),
      );
      expect(copyLinkBtn, findsOneWidget);
      await tester.tap(copyLinkBtn);
      await tester.pumpAndSettle();

      // Tap open button
      final openBtn = find.byKey(
        const ValueKey('canvas-card-tooltip-open-button'),
      );
      expect(openBtn, findsOneWidget);
      await tester.tap(openBtn);
      await tester.pump();
      expect(opened, isTrue);
    });

    testWidgets('renders PDF highlight quote and tags in tooltip', (
      tester,
    ) async {
      final element = CanvasElement({
        'id': 'card-2',
        'type': 'card',
        'x': 50.0,
        'y': 50.0,
        'width': 240.0,
        'height': 140.0,
        'objectId': 'quote-1',
      });
      const object = CanvasObjectReference(
        id: 'quote-1',
        title: 'Core Philosophy',
        typeId: 'orbit.note',
        body: 'Extended notes on spatial computing and universal cards.',
        properties: {
          'tags': ['design', 'architecture'],
          'pdfSource': {
            'fileId': 'doc-pdf',
            'page': 12,
            'quote': 'Knowledge objects must retain universal stable identity.',
          },
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasCardPreviewTooltip(
              element: element,
              object: object,
              objects: {'quote-1': object},
              onOpen: () {},
              onToggleTask: (_) {},
              onCyclePresentation: () {},
              onDismiss: () {},
              onEnterTooltip: () {},
              onExitTooltip: () {},
            ),
          ),
        ),
      );

      expect(find.text('Core Philosophy'), findsOneWidget);
      expect(find.textContaining('PDF HIGHLIGHT'), findsOneWidget);
      expect(find.textContaining('12'), findsOneWidget);
      expect(
        find.textContaining(
          'Knowledge objects must retain universal stable identity.',
        ),
        findsOneWidget,
      );
      expect(find.text('#design'), findsOneWidget);
      expect(find.text('#architecture'), findsOneWidget);
    });
  });

  group('CanvasEditor interactive card controls', () {
    testWidgets('direct on-canvas tap on task checkbox calls onToggleTask', (
      tester,
    ) async {
      Map<String, dynamic> data = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'task-el-1',
            'type': 'card',
            'x': 50.0,
            'y': 50.0,
            'width': 220.0,
            'height': 120.0,
            'objectId': 't-direct',
            'presentation': 'card',
          },
        ],
      };

      const taskObj = CanvasObjectReference(
        id: 't-direct',
        title: 'Review PR #42',
        typeId: 'orbit.task',
        properties: {'completed': false},
      );

      String? toggledTaskId;

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board-1',
              data: data,
              onChanged: (v) => data = v,
              objects: const [taskObj],
              onOpenObject: (_) {},
              onToggleTask: (id) => toggledTaskId = id,
            ),
          ),
        ),
      );

      final surface = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
      );
      final origin = tester.getTopLeft(surface);
      // In OrbitCanvasPainter card presentation, checkbox is drawn at:
      // bounds.left + 16, bounds.top + 48, size 20x20.
      // Screen coordinate for element at (50, 50) is origin + (50 + 16 + 10, 50 + 48 + 10) = origin + (76, 108).
      await tester.tapAt(origin + const Offset(76, 108));
      await tester.pumpAndSettle();

      expect(toggledTaskId, 't-direct');
    });

    testWidgets('presentation cycling changes element presentation in data', (
      tester,
    ) async {
      Map<String, dynamic> data = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'card-cycle',
            'type': 'card',
            'x': 100.0,
            'y': 100.0,
            'width': 220.0,
            'height': 120.0,
            'objectId': 'n-cycle',
            'presentation': 'card',
          },
        ],
      };

      const noteObj = CanvasObjectReference(
        id: 'n-cycle',
        title: 'Architecture Note',
        typeId: 'orbit.note',
        body: 'Architecture notes content.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board-2',
              data: data,
              onChanged: (v) => data = v,
              objects: const [noteObj],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );

      final surface = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
      );
      final origin = tester.getTopLeft(surface);

      // Select the card first
      await tester.tapAt(origin + const Offset(150, 140));
      await tester.pumpAndSettle();

      // Right click / secondary click on the card to open context menu
      await tester.tapAt(
        origin + const Offset(150, 140),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Verify presentation menu items exist in the context menu
      expect(find.textContaining('Compact'), findsOneWidget);
      expect(find.textContaining('Standard Card'), findsOneWidget);
      expect(find.textContaining('Expanded Preview'), findsOneWidget);
      expect(find.textContaining('Selected Properties Table'), findsOneWidget);

      // Select "Preview"
      await tester.tap(find.textContaining('Expanded Preview'));
      await tester.pumpAndSettle();

      final updatedEl =
          (data['elements'] as List).single as Map<String, dynamic>;
      expect(updatedEl['presentation'], 'preview');
    });
  });
}
