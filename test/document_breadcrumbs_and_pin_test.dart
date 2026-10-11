import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/workspace/document_breadcrumbs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now();

  UniversalObject makeObject({
    required String id,
    required String title,
    String typeId = 'orbit.note',
    String body = '',
    Map<String, dynamic> properties = const {},
  }) {
    return UniversalObject(
      id: id,
      workspaceId: 'ws-1',
      typeId: typeId,
      title: title,
      body: body,
      properties: properties,
      data: const {},
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget createTestApp(Widget child) {
    return MaterialApp(
      theme: orbitDarkTheme(),
      home: Scaffold(body: child),
    );
  }

  group('DocumentBreadcrumbs widget tests', () {
    testWidgets('renders vault, folder segments and document title', (
      tester,
    ) async {
      final note1 = makeObject(
        id: 'n1',
        title: 'Architecture Overview',
        properties: {'folder': 'Notes/Projects/Mobile'},
      );
      final note2 = makeObject(
        id: 'n2',
        title: 'API Specification',
        properties: {'folder': 'Notes/Projects/Mobile'},
      );

      await tester.pumpWidget(
        createTestApp(
          DocumentBreadcrumbs(
            vaultName: 'Engineering Vault',
            folderPath: 'Notes/Projects/Mobile',
            documentTitle: 'Architecture Overview',
            documentId: 'n1',
            allFolders: const [
              'Notes',
              'Notes/Projects',
              'Notes/Projects/Mobile',
              'Notes/Projects/Backend',
            ],
            allObjects: [note1, note2],
          ),
        ),
      );
      await tester.pump();

      // Check Vault segment
      expect(find.byKey(const ValueKey('breadcrumb-vault')), findsOneWidget);
      expect(find.text('Engineering Vault'), findsOneWidget);

      // Check Folder segments (Notes, Projects, Mobile)
      expect(
        find.byKey(const ValueKey('breadcrumb-folder-0')),
        findsOneWidget,
      ); // Notes
      expect(
        find.byKey(const ValueKey('breadcrumb-folder-1')),
        findsOneWidget,
      ); // Projects
      expect(
        find.byKey(const ValueKey('breadcrumb-folder-2')),
        findsOneWidget,
      ); // Mobile
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Mobile'), findsOneWidget);

      // Check Document segment
      expect(find.byKey(const ValueKey('breadcrumb-document')), findsOneWidget);
      expect(find.text('Architecture Overview'), findsOneWidget);
    });

    testWidgets(
      'clicking folder segment opens popover and navigates to sibling note',
      (tester) async {
        String? openedId;

        final note1 = makeObject(
          id: 'n1',
          title: 'Architecture Overview',
          properties: {'folder': 'Notes/Projects/Mobile'},
        );
        final note2 = makeObject(
          id: 'n2',
          title: 'API Specification',
          properties: {'folder': 'Notes/Projects/Mobile'},
        );

        await tester.pumpWidget(
          createTestApp(
            DocumentBreadcrumbs(
              vaultName: 'Engineering Vault',
              folderPath: 'Notes/Projects/Mobile',
              documentTitle: 'Architecture Overview',
              documentId: 'n1',
              allFolders: const [
                'Notes',
                'Notes/Projects',
                'Notes/Projects/Mobile',
              ],
              allObjects: [note1, note2],
              onOpenObject: (id) => openedId = id,
              onCreateNoteInFolder: (_) {},
            ),
          ),
        );
        await tester.pump();

        // Tap on 'Mobile' folder segment (index 2)
        final mobileFolderKey = const ValueKey('breadcrumb-folder-2');
        await tester.tap(find.byKey(mobileFolderKey));
        await tester.pumpAndSettle();

        // Should show sibling notes and new note option
        expect(find.text('API Specification'), findsOneWidget);
        expect(find.text('New note in "Mobile"'), findsOneWidget);

        // Tap sibling note 'API Specification'
        await tester.tap(find.text('API Specification'));
        await tester.pumpAndSettle();

        expect(openedId, equals('n2'));
      },
    );

    testWidgets(
      'clicking new note option in folder menu calls onCreateNoteInFolder',
      (tester) async {
        String? createdInFolder;

        await tester.pumpWidget(
          createTestApp(
            DocumentBreadcrumbs(
              vaultName: 'Engineering Vault',
              folderPath: 'Notes/Projects/Mobile',
              documentTitle: 'Architecture Overview',
              documentId: 'n1',
              allFolders: const [
                'Notes',
                'Notes/Projects',
                'Notes/Projects/Mobile',
              ],
              allObjects: const [],
              onCreateNoteInFolder: (f) => createdInFolder = f,
            ),
          ),
        );
        await tester.pump();

        // Tap on 'Projects' folder segment (index 1)
        await tester.tap(find.byKey(const ValueKey('breadcrumb-folder-1')));
        await tester.pumpAndSettle();

        // Tap 'New note in "Projects"'
        await tester.tap(find.text('New note in "Projects"'));
        await tester.pumpAndSettle();

        expect(createdInFolder, equals('Notes/Projects'));
      },
    );

    testWidgets(
      'document segment popover provides quick actions and triggers bookmark and pin',
      (tester) async {
        bool bookmarkToggled = false;
        bool pinToggled = false;

        await tester.pumpWidget(
          createTestApp(
            DocumentBreadcrumbs(
              vaultName: 'Engineering Vault',
              folderPath: 'Notes/Projects',
              documentTitle: 'System Design',
              documentId: 'n1',
              isBookmarked: false,
              onToggleBookmark: () => bookmarkToggled = true,
              isPinned: false,
              onTogglePin: () => pinToggled = true,
            ),
          ),
        );
        await tester.pump();

        // Tap document segment
        await tester.tap(find.byKey(const ValueKey('breadcrumb-document')));
        await tester.pumpAndSettle();

        // Check actions in menu
        expect(find.text('Copy relative path'), findsOneWidget);
        expect(find.text('Copy wiki-link [[...]]'), findsOneWidget);
        expect(find.text('Bookmark note'), findsOneWidget);
        expect(find.text('Pin tab'), findsOneWidget);

        // Tap 'Bookmark note'
        await tester.tap(find.text('Bookmark note'));
        await tester.pumpAndSettle();
        expect(bookmarkToggled, isTrue);

        // Open menu again and tap 'Pin tab'
        await tester.tap(find.byKey(const ValueKey('breadcrumb-document')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pin tab'));
        await tester.pumpAndSettle();
        expect(pinToggled, isTrue);
      },
    );

    testWidgets('showMoveToFolderDialog lets user select target folder', (
      tester,
    ) async {
      String? selectedFolder;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                key: const ValueKey('open-move-dialog'),
                onPressed: () async {
                  selectedFolder = await showMoveToFolderDialog(context, [
                    'Notes',
                    'Notes/Archive',
                    'Notes/Work',
                  ], currentFolder: 'Notes');
                },
                child: const Text('Move'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('open-move-dialog')));
      await tester.pumpAndSettle();

      expect(find.text('Move to Folder'), findsOneWidget);
      expect(find.text('Notes/Archive'), findsOneWidget);
      expect(find.text('Notes/Work'), findsOneWidget);

      await tester.tap(find.text('Notes/Work'));
      await tester.pumpAndSettle();

      expect(selectedFolder, equals('Notes/Work'));
    });
  });

  group('NoteEditor Header Pin and Word Goal Features', () {
    testWidgets('renders pin toggle button and responds to tap', (
      tester,
    ) async {
      bool pinToggled = false;

      await tester.pumpWidget(
        createTestApp(
          NoteEditor(
            noteId: 'n1',
            title: 'Kernel Modules',
            body: 'Notes on Linux kernel module compilation.',
            onTitleChanged: (_) {},
            onBodyChanged: (_) {},
            linkTargets: const [],
            onOpenObject: (_) {},
            isPinned: false,
            onTogglePin: () => pinToggled = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final pinBtn = find.byKey(const ValueKey('note-pin-toggle'));
      expect(pinBtn, findsOneWidget);

      await tester.tap(pinBtn);
      expect(pinToggled, isTrue);
    });

    testWidgets('renders active pin state with unpin tooltip', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          NoteEditor(
            noteId: 'n1',
            title: 'Kernel Modules',
            body: 'Notes on Linux kernel module compilation.',
            onTitleChanged: (_) {},
            onBodyChanged: (_) {},
            linkTargets: const [],
            onOpenObject: (_) {},
            isPinned: true,
            onTogglePin: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final pinBtnWidget = tester.widget<IconButton>(
        find.byKey(const ValueKey('note-pin-toggle')),
      );
      expect(pinBtnWidget.tooltip, contains('Unpin tab'));
    });

    testWidgets('renders word goal badge when targetWords is configured', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          NoteEditor(
            noteId: 'n1',
            title: 'Research Essay',
            body: 'One two three four five six seven eight nine ten.',
            onTitleChanged: (_) {},
            onBodyChanged: (_) {},
            linkTargets: const [],
            onOpenObject: (_) {},
            initialViewState: const {'targetWords': 100},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final goalBadge = find.byKey(const ValueKey('note-word-goal-badge'));
      expect(goalBadge, findsOneWidget);
      expect(find.text('10/100'), findsOneWidget);
    });

    testWidgets(
      'note-copy-as-menu contains Wiki-Link and Relative Path options',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            NoteEditor(
              noteId: 'n1',
              title: 'Research Essay',
              body: 'Content of essay.',
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        final copyMenuBtn = find.byKey(const ValueKey('note-copy-as-menu'));
        expect(copyMenuBtn, findsOneWidget);

        await tester.tap(copyMenuBtn);
        await tester.pumpAndSettle();

        expect(find.text('Wiki-Link'), findsOneWidget);
        expect(find.text('Relative Path'), findsOneWidget);
        expect(find.text('Plain Text'), findsOneWidget);
        expect(find.text('HTML'), findsOneWidget);
      },
    );
  });
}
