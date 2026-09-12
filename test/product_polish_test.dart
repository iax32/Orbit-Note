import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/main.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  group('Canvas Product Polish', () {
    test('supports section element type and serialization', () {
      final section = CanvasElement({
        'id': 'sec-1',
        'type': 'section',
        'x': 100.0,
        'y': 200.0,
        'width': 300.0,
        'height': 40.0,
        'text': 'DESIGN TOKENS',
        'color': 0xFF8B7CF6,
      });

      expect(section.type, equals('section'));
      expect(section.text, equals('DESIGN TOKENS'));
      expect(section.bounds.width, equals(300.0));

      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [section.data],
      });
      expect(scene['sec-1'], isNotNull);
      final json = scene.toJson();
      final restored = CanvasScene.fromJson(json);
      expect(restored['sec-1']?.type, equals('section'));
      expect(restored['sec-1']?.text, equals('DESIGN TOKENS'));
    });

    test('supports swatch element type and serialization', () {
      final swatch = CanvasElement({
        'id': 'swatch-1',
        'type': 'swatch',
        'x': 50.0,
        'y': 60.0,
        'width': 140.0,
        'height': 160.0,
        'text': 'Primary Violet',
        'color': 0xFF8B7CF6,
      });

      expect(swatch.type, equals('swatch'));
      expect(swatch.text, equals('Primary Violet'));

      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [swatch.data],
      });
      final restored = CanvasScene.fromJson(scene.toJson());
      expect(restored['swatch-1']?.type, equals('swatch'));
      expect(restored['swatch-1']?.color, equals(0xFF8B7CF6));
    });

    test('locked elements can be hit when includeLocked is true', () {
      final locked = CanvasElement({
        'id': 'rect-locked',
        'type': 'rectangle',
        'x': 0.0,
        'y': 0.0,
        'width': 100.0,
        'height': 100.0,
        'locked': true,
      });

      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [locked.data],
      });
      expect(scene.hit(const CanvasPoint(50, 50)), isNull);
      expect(
        scene.hit(const CanvasPoint(50, 50), includeLocked: true)?.id,
        equals('rect-locked'),
      );
    });
  });

  group('Rich Markdown Collapsible Headings & Blocks', () {
    test('heading fold algorithm correctly hides child blocks', () {
      const source = '''# Heading 1
Paragraph under H1.
## Heading 2
Paragraph under H2.
# Next Heading 1
Outside folded section.
''';

      final doc = MarkdownDocument.parse(source);
      final collapsedHeadings = {'1:Heading 1'};

      final hiddenBlocks = <MarkdownBlock>{};
      int? collapsedLevel;
      for (int i = 0; i < doc.blocks.length; i++) {
        final b = doc.blocks[i];
        if (b.kind == MarkdownBlockKind.heading) {
          if (collapsedLevel != null && b.level <= collapsedLevel) {
            collapsedLevel = null;
          }
          final key = '${b.level}:${b.content.trim()}';
          if (collapsedHeadings.contains(key)) {
            collapsedLevel = b.level;
            continue;
          }
        }
        if (collapsedLevel != null) {
          hiddenBlocks.add(b);
        }
      }

      // Paragraphs and H2 under H1 should be hidden
      expect(
        hiddenBlocks.any((b) => b.content.contains('Paragraph under H1')),
        isTrue,
      );
      expect(hiddenBlocks.any((b) => b.content.contains('Heading 2')), isTrue);
      expect(
        hiddenBlocks.any((b) => b.content.contains('Paragraph under H2')),
        isTrue,
      );
      // Next Heading 1 and its children are NOT hidden
      expect(
        hiddenBlocks.any((b) => b.content.contains('Next Heading 1')),
        isFalse,
      );
      expect(
        hiddenBlocks.any((b) => b.content.contains('Outside folded section')),
        isFalse,
      );
    });
  });

  group('Object Icons & Covers', () {
    test('UniversalObject preserves icon and cover properties', () {
      final note = UniversalObject(
        id: 'note-cover-test',
        workspaceId: 'ws-1',
        typeId: 'orbit.note',
        title: 'Project Roadmap',
        body: 'Details here',
        properties: {'icon': '🚀', 'cover': 'gradient:violet'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = note.toJson();
      final restored = UniversalObject.fromJson(json);

      expect(restored.properties['icon'], equals('🚀'));
      expect(restored.properties['cover'], equals('gradient:violet'));
    });
  });

  group('Tasks Manual Order & Duplicate View', () {
    test('TaskViewConfig holds view state correctly', () {
      final config = TaskViewConfig(
        id: 'view-1',
        name: 'Urgent Tasks',
        baseTab: 'todo',
        sortOption: 'manual',
        filterPriority: 'urgent',
        showDueDate: true,
        showPriority: true,
        showProject: false,
      );

      expect(config.name, equals('Urgent Tasks'));
      expect(config.baseTab, equals('todo'));
      expect(config.sortOption, equals('manual'));
      expect(config.filterPriority, equals('urgent'));
      expect(config.showProject, isFalse);
    });
  });

  group('Obsidian-style Vault Switcher & Bottom Bar', () {
    testWidgets(
      'renders vault switcher at bottom of explorer with help and settings',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repository = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repository)],
            child: const OrbitNoteApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Find the unfold_more icon and Help/Settings buttons in the bottom footer
        expect(find.byIcon(Icons.unfold_more), findsOneWidget);
        expect(find.byIcon(Icons.help_outline), findsOneWidget);
        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

        // Verify clicking Help icon opens the shortcuts/help dialog
        await tester.tap(find.byIcon(Icons.help_outline));
        await tester.pumpAndSettle();
        expect(find.text('Orbit Note Help & Shortcuts'), findsOneWidget);
        expect(find.text('KEYBOARD SHORTCUTS'), findsOneWidget);
        expect(find.text('Ctrl + P'), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Orbit Note Help & Shortcuts'), findsNothing);

        // Verify clicking Vault Switcher opens the Your Vaults dialog
        await tester.tap(find.byIcon(Icons.unfold_more));
        await tester.pumpAndSettle();
        expect(find.text('Your Vaults'), findsOneWidget);
        expect(find.text('ACTIONS'), findsOneWidget);
        expect(find.text('New Vault'), findsOneWidget);
        expect(find.text('Open Folder as Vault'), findsOneWidget);

        // Close vault switcher
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.text('Your Vaults'), findsNothing);
      },
    );

    testWidgets(
      'creates canvas and renames it via top-left title field and explorer menu',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repository = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repository)],
            child: const OrbitNoteApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Canvases tab using the rail
        await tester.tap(find.byTooltip('Canvas'));
        await tester.pumpAndSettle();

        // Tap "Create canvas" button
        final createBtn = find.widgetWithText(FilledButton, 'Create canvas');
        expect(createBtn, findsOneWidget);
        await tester.tap(createBtn);
        await tester.pumpAndSettle();

        // Verify canvas title field is visible with default title
        final titleField = find.byKey(const ValueKey('canvas-title-field'));
        expect(titleField, findsOneWidget);
        expect(find.text('Untitled canvas'), findsWidgets);

        // Rename via the inline canvas title field
        await tester.enterText(titleField, 'Project Roadmap');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Verify updated title is displayed in canvas editor and explorer
        expect(find.text('Project Roadmap'), findsWidgets);

        // Find three dots in explorer for the canvas
        final moreBtn = find.byTooltip('Object actions');
        expect(moreBtn, findsOneWidget);
        await tester.tap(moreBtn);
        await tester.pumpAndSettle();

        // Tap "Rename" from context menu
        final renameOption = find.text('Rename');
        expect(renameOption, findsOneWidget);
        await tester.tap(renameOption);
        await tester.pumpAndSettle();

        // Enter new title in dialog and submit
        expect(find.text('Rename object'), findsOneWidget);
        final dialogInput = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(dialogInput, 'Final Roadmap 2026');
        await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
        await tester.pumpAndSettle();

        // Verify canvas title is updated everywhere
        expect(find.text('Final Roadmap 2026'), findsWidgets);
      },
    );
  });

  group('Desktop Tab Ergonomics', () {
    test(
      'closeOtherTabs and closeTabsToTheRight manage tab list and preserve drafts',
      () async {
        final repository = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        await repository.initialize();
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();

        final o1 = await c.create('orbit.note', title: 'Note 1');
        final o2 = await c.create('orbit.note', title: 'Note 2');
        final o3 = await c.create('orbit.note', title: 'Note 3');
        final o4 = await c.create('orbit.note', title: 'Note 4');

        c.openObject(o1!.id);
        c.openObject(o2!.id);
        c.openObject(o3!.id);
        c.openObject(o4!.id);

        expect(c.session.tabs, containsAll([o1.id, o2.id, o3.id, o4.id]));

        // Test closeTabsToTheRight
        c.closeTabsToTheRight(o2.id);
        expect(c.session.tabs, equals([o1.id, o2.id]));

        // Re-add tabs
        c.openObject(o3.id);
        c.openObject(o4.id);
        expect(c.session.tabs.length, equals(4));

        // Test closeOtherTabs
        c.closeOtherTabs(o3.id);
        expect(c.session.tabs, equals([o3.id]));
        expect(c.session.activeId, equals(o3.id));
      },
    );

    testWidgets(
      'middle-click closes tab and right-click displays tab context menu',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repository = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        await repository.initialize();
        final n1 = await repository.create(
          typeId: 'orbit.note',
          title: 'Alpha Note',
        );
        final n2 = await repository.create(
          typeId: 'orbit.note',
          title: 'Beta Note',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repository)],
            child: const OrbitNoteApp(),
          ),
        );
        await tester.pumpAndSettle();

        final c = ProviderScope.containerOf(
          tester.element(find.byType(OrbitNoteApp)),
        ).read(workspaceProvider.notifier);

        c.openObject(n1.id);
        c.openObject(n2.id);
        await tester.pumpAndSettle();

        expect(find.text('Alpha Note'), findsWidgets);
        expect(find.text('Beta Note'), findsWidgets);

        final tabFinder = find.descendant(
          of: find.byType(ReorderableListView),
          matching: find.text('Alpha Note'),
        );
        expect(tabFinder, findsOneWidget);

        // Right-click tab opens context menu
        await tester.tap(tabFinder, buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        expect(find.text('Close Tab'), findsOneWidget);
        expect(find.text('Close Other Tabs'), findsOneWidget);
        expect(find.text('Close Tabs to the Right'), findsOneWidget);
        expect(find.text('Copy Reference'), findsOneWidget);

        // Tap Close Tab from menu
        await tester.tap(find.text('Close Tab'));
        await tester.pumpAndSettle();

        expect(c.session.tabs.contains(n1.id), isFalse);
        expect(c.session.tabs.contains(n2.id), isTrue);

        // Re-open n1 and test middle click
        c.openObject(n1.id);
        await tester.pumpAndSettle();
        expect(c.session.tabs.contains(n1.id), isTrue);

        final n1TabFinder = find.descendant(
          of: find.byType(ReorderableListView),
          matching: find.text('Alpha Note'),
        );
        // Middle click on tab n1
        await tester.tap(n1TabFinder, buttons: kTertiaryButton);
        await tester.pumpAndSettle();

        expect(c.session.tabs.contains(n1.id), isFalse);
      },
    );
  });

  group('Live Note Statistics', () {
    testWidgets(
      'shows live note statistics in status bar for note and updates on edit',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repository = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        await repository.initialize();
        final note = await repository.create(
          typeId: 'orbit.note',
          title: 'Draft Note',
          body: 'The quick brown fox jumps over the lazy dog.',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repository)],
            child: const OrbitNoteApp(),
          ),
        );
        await tester.pumpAndSettle();

        final c = ProviderScope.containerOf(
          tester.element(find.byType(OrbitNoteApp)),
        ).read(workspaceProvider.notifier);

        c.openObject(note.id);
        await tester.pumpAndSettle();

        // 9 words, 44 characters, 1 min read
        final statsFinder = find.byKey(const ValueKey('note-live-statistics'));
        expect(statsFinder, findsOneWidget);
        expect(
          find.text('9 words · 44 characters · 1 min read'),
          findsOneWidget,
        );

        // Edit body and verify statistics update live
        c.edit(note.id, body: 'Hello world');
        await tester.pumpAndSettle();

        expect(
          find.text('2 words · 11 characters · 1 min read'),
          findsOneWidget,
        );
      },
    );
  });

  group('Canvas Quick Duplicate, Multi-Selection Alignment & Context Menu', () {
    testWidgets('Canvas alignment and empty space menu interact properly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repository.initialize();
      final canvas = await repository.create(
        typeId: 'orbit.canvas',
        title: 'Geometry Board',
        data: {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'el-1',
              'type': 'sticky',
              'x': 100.0,
              'y': 100.0,
              'width': 200.0,
              'height': 150.0,
              'text': 'First Item',
            },
            {
              'id': 'el-2',
              'type': 'sticky',
              'x': 400.0,
              'y': 250.0,
              'width': 200.0,
              'height': 150.0,
              'text': 'Second Item',
            },
          ],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repository)],
          child: const OrbitNoteApp(),
        ),
      );
      await tester.pumpAndSettle();

      final c = ProviderScope.containerOf(
        tester.element(find.byType(OrbitNoteApp)),
      ).read(workspaceProvider.notifier);

      c.openObject(canvas.id);
      await tester.pumpAndSettle();
      expect(find.byType(CanvasEditor), findsOneWidget);

      // Right click on empty canvas area (avoiding el-1 and el-2)
      final canvasTopLeft = tester.getTopLeft(find.byType(CanvasEditor));
      await tester.tapAt(
        canvasTopLeft + const Offset(50, 500),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();

      // Verify empty canvas context menu items
      expect(find.text('Add Text'), findsOneWidget);
      expect(find.text('Add Sticky'), findsOneWidget);
      expect(find.text('Add Section'), findsOneWidget);
      expect(find.text('Add Color Swatch'), findsOneWidget);
      expect(find.text('Fit All'), findsOneWidget);
      expect(find.text('100% Zoom'), findsOneWidget);

      // Tap Add Sticky from empty canvas context menu
      await tester.tap(find.text('Add Sticky'));
      await tester.pumpAndSettle();

      // Canvas should now have a 3rd element
      final updatedCanvas = c.find(canvas.id)!;
      final elements = (updatedCanvas.data['elements'] as List);
      expect(elements.length, equals(3));
    });
  });
}
