import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'package:orbit_note/features/workspace/folder_color_dialog.dart';
import 'package:orbit_note/features/workspace/note_folder_explorer.dart';
import 'package:orbit_note/features/workspace/orbit_explorer_row.dart';
import 'package:orbit_note/features/workspace/orbit_tab_strip.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

class TestFolderStore extends MemoryStore
    implements WorkspaceFolderStore, WorkspaceFolderCommandStore {
  final folders = <String>['Notes'];

  @override
  Future<List<String>> listFolders() async => folders.toList()..sort();

  @override
  Future<void> createFolder(String path) async {
    if (!folders.contains(path)) folders.add(path);
  }

  @override
  Future<void> deleteFolder(String path) async {
    folders.remove(path);
  }

  @override
  Future<void> movePath(
    String source,
    String target,
    Map<String, FileReplacement> replacements,
  ) async {
    folders.remove(source);
    folders.add(target);
  }

  @override
  Future<void> applyFolderCommand(
    List<FolderFileChange> changes, {
    required String workspaceId,
    List<String> createFolders = const [],
    List<String> removeFolders = const [],
  }) async {
    final next = Map.of(files);
    for (final change in changes) {
      next.remove(change.source);
      next[change.target] = change.bytes;
    }
    files
      ..clear()
      ..addAll(next);
    folders.removeWhere((f) => removeFolders.contains(f));
    folders.addAll(createFolders.where((f) => !folders.contains(f)));
  }
}

void main() {
  group('SessionState & Storage Folder Colors', () {
    test('SessionState preserves folderColors and defaults to empty', () {
      final s = SessionState();
      expect(s.folderColors, isEmpty);

      s.folderColors = {'Notes/Projects': 0xFF8B7CF6, 'Notes/Math': 0xFF06B6D4};
      expect(s.folderColors['Notes/Projects'], 0xFF8B7CF6);
      expect(s.folderColors['Notes/Math'], 0xFF06B6D4);
    });

    test(
      'SessionState toJson and fromJson round-trips folderColors safely',
      () {
        final original = SessionState(
          folderColors: {
            'Notes/Projects': 0xFF8B7CF6,
            'Notes/Research': 0xFF10B981,
          },
        );
        final json = original.toJson();
        expect(json['folderColors'], isNotNull);
        expect((json['folderColors'] as Map)['Notes/Projects'], 0xFF8B7CF6);

        final restored = SessionState.fromJson(json);
        expect(restored.folderColors['Notes/Projects'], 0xFF8B7CF6);
        expect(restored.folderColors['Notes/Research'], 0xFF10B981);
      },
    );

    test(
      'SessionState handles corrupted or absent folderColors gracefully',
      () {
        final s = SessionState.fromJson({
          'folderColors': {
            'Notes/Valid': 0xFF8B7CF6,
            'Notes/InvalidValue': 'not_an_int',
            123: 0xFF10B981,
          },
        });
        expect(s.folderColors.length, 1);
        expect(s.folderColors['Notes/Valid'], 0xFF8B7CF6);
      },
    );
  });

  group('WorkspaceController Folder Color Identity & Inheritance', () {
    test(
      'setFolderColor, folderColorValue, and inheritance work correctly',
      () async {
        final repository = WorkspaceRepository(
          store: TestFolderStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();

        await repository.createFolder('Notes/Math');
        await repository.createFolder('Notes/Math/Calculus');
        await repository.createFolder('Notes/Math/Calculus/Advanced');

        expect(c.folderColorValue('Notes/Math'), isNull);

        // Set color on root Math folder (Violet = 0xFF8B7CF6)
        c.setFolderColor('Notes/Math', 0xFF8B7CF6);
        expect(c.folderColorValue('Notes/Math'), 0xFF8B7CF6);

        // Subfolders inherit Math's color because they don't have an explicit color
        expect(c.folderColorValue('Notes/Math/Calculus'), 0xFF8B7CF6);
        expect(c.folderColorValue('Notes/Math/Calculus/Advanced'), 0xFF8B7CF6);

        // Overriding child subfolder with Cyan (0xFF06B6D4)
        c.setFolderColor('Notes/Math/Calculus', 0xFF06B6D4);
        expect(c.folderColorValue('Notes/Math/Calculus'), 0xFF06B6D4);
        // Grandchild now inherits from immediate parent Calculus
        expect(c.folderColorValue('Notes/Math/Calculus/Advanced'), 0xFF06B6D4);

        // Clear color on Calculus
        c.setFolderColor('Notes/Math/Calculus', null);
        // Reverts to inheriting from ancestor Math
        expect(c.folderColorValue('Notes/Math/Calculus'), 0xFF8B7CF6);
      },
    );

    test('moveFolder preserves and rewrites folderColors keys', () async {
      final repository = WorkspaceRepository(
        store: TestFolderStore(),
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();

      await repository.createFolder('Notes/Science');
      await repository.createFolder('Notes/Science/Physics');
      c.setFolderColor('Notes/Science', 0xFF10B981);
      c.setFolderColor('Notes/Science/Physics', 0xFF3B82F6);
      c.updateSession((s) => s.collapsedFolders = ['Notes/Science/Physics']);

      // Rename/move folder to 'Notes/STEM'
      await c.moveFolder('Notes/Science', 'Notes/STEM');

      expect(c.folderColorValue('Notes/Science'), isNull);
      expect(c.folderColorValue('Notes/STEM'), 0xFF10B981);
      expect(c.folderColorValue('Notes/STEM/Physics'), 0xFF3B82F6);
      expect(c.session.collapsedFolders, ['Notes/STEM/Physics']);
    });

    test(
      'deleteFolder removes colors of deleted folder and subfolders',
      () async {
        final repository = WorkspaceRepository(
          store: TestFolderStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();

        await repository.createFolder('Notes/Temp');
        await repository.createFolder('Notes/Temp/Drafts');
        c.setFolderColor('Notes/Temp', 0xFFF59E0B);
        c.setFolderColor('Notes/Temp/Drafts', 0xFFF43F5E);
        c.updateSession((s) => s.collapsedFolders = ['Notes/Temp/Drafts']);

        await c.deleteFolder('Notes/Temp');

        expect(c.folderColorValue('Notes/Temp'), isNull);
        expect(c.session.collapsedFolders, isEmpty);
        expect(c.folderColorValue('Notes/Temp/Drafts'), isNull);
        expect(c.session.folderColors.containsKey('Notes/Temp'), isFalse);
        expect(
          c.session.folderColors.containsKey('Notes/Temp/Drafts'),
          isFalse,
        );
      },
    );
  });

  group('Folder Color Dialog Widget Tests', () {
    testWidgets(
      'showFolderColorDialog renders swatches, preview, and applies selected preset',
      (tester) async {
        Color? selectedResult;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(extensions: [const OrbitColors()]),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  key: const ValueKey('open-dialog-btn'),
                  onPressed: () {
                    showFolderColorDialog(
                      context,
                      folderName: 'Algorithms',
                      currentColor: null,
                      onColorSelected: (color) {
                        selectedResult = color;
                      },
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('open-dialog-btn')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('folder-color-dialog')),
          findsOneWidget,
        );
        expect(find.text('Folder Color Identity'), findsOneWidget);
        expect(find.text('Algorithms'), findsWidgets);

        // Tap on Sapphire swatch
        final sapphireSwatch = find.byKey(
          const ValueKey('folder-color-swatch-sapphire'),
        );
        expect(sapphireSwatch, findsOneWidget);
        await tester.tap(sapphireSwatch);
        await tester.pumpAndSettle();

        // Hex field should reflect 3B82F6
        final hexField = find.byKey(const ValueKey('folder-color-hex-field'));
        expect(
          find.descendant(of: hexField, matching: find.text('3B82F6')),
          findsOneWidget,
        );

        // Tap Apply
        final applyBtn = find.byKey(
          const ValueKey('folder-color-apply-button'),
        );
        await tester.tap(applyBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('folder-color-dialog')), findsNothing);
        expect(selectedResult, isNotNull);
        expect(selectedResult!.toARGB32(), const Color(0xFF3B82F6).toARGB32());
      },
    );

    testWidgets('showFolderColorDialog allows typing custom hex code', (
      tester,
    ) async {
      Color? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [const OrbitColors()]),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('open-dialog-btn'),
                onPressed: () {
                  showFolderColorDialog(
                    context,
                    folderName: 'MyNotes',
                    isNote: true,
                    currentColor: const Color(0xFF8B7CF6),
                    onColorSelected: (color) {
                      selectedResult = color;
                    },
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-dialog-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Note Color Accent'), findsOneWidget);

      // Enter custom hex 123456
      final hexField = find.byKey(const ValueKey('folder-color-hex-field'));
      await tester.enterText(hexField, '123456');
      await tester.pumpAndSettle();

      // Tap Apply
      final applyBtn = find.byKey(const ValueKey('folder-color-apply-button'));
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      expect(selectedResult, isNotNull);
      expect(selectedResult!.toARGB32(), 0xFF123456);
    });

    testWidgets('showFolderColorDialog reset button clears color', (
      tester,
    ) async {
      Color? selectedResult = const Color(0xFF8B7CF6);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [const OrbitColors()]),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('open-dialog-btn'),
                onPressed: () {
                  showFolderColorDialog(
                    context,
                    folderName: 'Important',
                    currentColor: const Color(0xFF8B7CF6),
                    onColorSelected: (color) {
                      selectedResult = color;
                    },
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-dialog-btn')));
      await tester.pumpAndSettle();

      final clearBtn = find.byKey(const ValueKey('folder-color-clear-button'));
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(selectedResult, isNull);
    });
  });

  group('NoteFolderExplorer & OrbitTabStrip Color Identity Integration', () {
    testWidgets(
      'Explorer rows and child notes render with inherited accent colors',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repository = WorkspaceRepository(
          store: FolderMemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();

        await repository.createFolder('Notes/Design');
        c.setFolderColor('Notes/Design', 0xFF8B7CF6); // Violet

        // Create a child note without explicit color
        final childNote = await c.create(
          'orbit.note',
          title: 'Color Systems',
          properties: {'folder': 'Notes/Design'},
        );

        // Create another child note with explicit Emerald color
        final customColorNote = await c.create(
          'orbit.note',
          title: 'Emerald Spec',
          properties: {'folder': 'Notes/Design', 'color': 0xFF10B981},
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData.dark().copyWith(
                extensions: [const OrbitColors()],
              ),
              home: Scaffold(
                body: NoteFolderExplorer(controller: c, notes: c.activeObjects),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the folder row
        final folderRow = tester.widget<OrbitExplorerRow>(
          find.byKey(const ValueKey('folder:Notes/Design')),
        );
        expect(folderRow.accentColor, isNotNull);
        expect(folderRow.accentColor!.toARGB32(), 0xFF8B7CF6);

        // Child note should inherit folder color
        final childRow = tester.widget<OrbitExplorerRow>(
          find.byKey(ValueKey('folder-note:${childNote!.id}')),
        );
        expect(childRow.accentColor, isNotNull);
        expect(childRow.accentColor!.toARGB32(), 0xFF8B7CF6);

        // Custom note should have its own explicit color
        final customRow = tester.widget<OrbitExplorerRow>(
          find.byKey(ValueKey('folder-note:${customColorNote!.id}')),
        );
        expect(customRow.accentColor, isNotNull);
        expect(customRow.accentColor!.toARGB32(), 0xFF10B981);
        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets('OrbitTabStrip reflects active object and folder accent colors', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = WorkspaceRepository(
        store: FolderMemoryStore(),
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();

      await repository.createFolder('Notes/Obsidian');
      c.setFolderColor('Notes/Obsidian', 0xFF06B6D4); // Cyan

      final note = await c.create(
        'orbit.note',
        title: 'Theme Spec',
        properties: {'folder': 'Notes/Obsidian'},
      );

      c.openObject(note!.id);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(extensions: [const OrbitColors()]),
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: OrbitTabStrip(
                  controller: c,
                  onActivate: (_) {},
                  onContextMenu: (object, pos) {},
                ),
              ),
              body: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));

      // Find the tab AnimatedContainer
      final tabFinder = find.byType(AnimatedContainer);
      expect(tabFinder, findsWidgets);

      // Look for the AnimatedContainer with top border matching Cyan (0xFF06B6D4)
      bool foundMatchingBorder = false;
      for (final element in tabFinder.evaluate()) {
        final widget = element.widget as AnimatedContainer;
        final decoration = widget.decoration;
        if (decoration is BoxDecoration && decoration.border is Border) {
          final border = decoration.border as Border;
          if (border.top.color.toARGB32() == 0xFF06B6D4) {
            foundMatchingBorder = true;
            break;
          }
        }
      }
      expect(foundMatchingBorder, isTrue);
    });

    testWidgets(
      'Folder and note popup menus show color options and handle resetting',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repository = WorkspaceRepository(
          store: TestFolderStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();

        await repository.createFolder('Notes/Projects');
        c.setFolderColor('Notes/Projects', 0xFF8B7CF6);

        final note = await c.create(
          'orbit.note',
          title: 'Project Roadmap',
          properties: {'folder': 'Notes/Projects', 'color': 0xFF10B981},
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData.dark().copyWith(
                extensions: [const OrbitColors()],
              ),
              home: Scaffold(
                body: NoteFolderExplorer(controller: c, notes: c.activeObjects),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open folder popup menu via secondary tap
        final folderRowFinder = find.byKey(
          const ValueKey('folder:Notes/Projects'),
        );
        await tester.tap(folderRowFinder, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('Change folder color…'), findsOneWidget);
        expect(find.text('Reset folder color'), findsOneWidget);

        // Tap Reset folder color
        await tester.tap(find.text('Reset folder color'));
        await tester.pumpAndSettle();
        expect(c.folderColorValue('Notes/Projects'), isNull);

        // Now open note popup menu via secondary tap
        final noteRowFinder = find.byKey(ValueKey('folder-note:${note!.id}'));
        await tester.tap(noteRowFinder, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('Change accent color…'), findsOneWidget);
        expect(find.text('Reset color'), findsOneWidget);

        // Tap Reset color
        await tester.tap(find.text('Reset color'));
        await tester.pumpAndSettle();
        final updatedNote = c.find(note.id);
        expect(updatedNote?.properties['color'], isNull);
        expect(updatedNote?.properties['accent'], isNull);

        await tester.pump(const Duration(milliseconds: 700));
      },
    );
  });
}
