import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_components.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/pdf/library/book_memories_dialog.dart';
import 'package:orbit_note/features/pdf/library/pdf_book_model.dart';
import 'package:orbit_note/features/pdf/library/pdf_library_view.dart';
import 'package:orbit_note/features/pdf/reading_rooms/ambient_sound_mixer.dart';
import 'package:orbit_note/features/pdf/reading_rooms/reading_atmosphere_painter.dart';
import 'package:orbit_note/features/pdf/reading_rooms/reading_room_dialog.dart';
import 'package:orbit_note/features/pdf/reading_rooms/reading_room_model.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

import 'support/memory_store.dart';

Widget testHost(Widget child) => OrbitMotionScope(
  preference: 'off',
  osReduced: true,
  child: MaterialApp(
    theme: orbitDarkTheme(),
    home: Scaffold(body: child),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingRoom & Catalog Models', () {
    test('catalog contains all 6 virtual reading rooms with atmospheres', () {
      final rooms = ReadingRoomCatalog.all;
      expect(rooms.length, 6);

      final ids = rooms.map((r) => r.id).toSet();
      expect(
        ids,
        containsAll([
          'rainy_library',
          'fireplace_cabin',
          'midnight_study',
          'night_train',
          'forest_cabin',
          'cozy_cafe',
        ]),
      );

      for (final room in rooms) {
        expect(room.name, isNotEmpty);
        expect(room.description, isNotEmpty);
        expect(room.soundChannels, isNotEmpty);
        for (final channel in room.soundChannels) {
          expect(channel.volume, inInclusiveRange(0.0, 1.0));
          expect(channel.isMuted, isFalse);
        }
      }
    });

    test('sound channel volume adjusts and clamps properly', () {
      final channel = AmbientSoundChannel(
        id: 'test_rain',
        name: 'Soft Rain',
        volume: 0.5,
      );

      channel.volume = 0.8;
      expect(channel.volume, 0.8);

      channel.volume = 1.5;
      expect(channel.volume, 1.0);

      channel.volume = -0.5;
      expect(channel.volume, 0.0);

      channel.isMuted = true;
      expect(channel.isMuted, isTrue);
    });

    test('atmosphere types match catalog environments', () {
      expect(
        ReadingRoomCatalog.rainyLibrary.atmosphereType,
        RoomAtmosphereType.rain,
      );
      expect(
        ReadingRoomCatalog.fireplaceCabin.atmosphereType,
        RoomAtmosphereType.fireplace,
      );
      expect(
        ReadingRoomCatalog.midnightStudy.atmosphereType,
        RoomAtmosphereType.midnight,
      );
      expect(
        ReadingRoomCatalog.nightTrain.atmosphereType,
        RoomAtmosphereType.train,
      );
      expect(
        ReadingRoomCatalog.forestCabin.atmosphereType,
        RoomAtmosphereType.forest,
      );
      expect(
        ReadingRoomCatalog.cozyCafe.atmosphereType,
        RoomAtmosphereType.cafe,
      );
    });
  });

  group('PdfBookMeta Model Extraction', () {
    test(
      'extracts book properties and defaults accurately from UniversalObject',
      () {
        final obj = UniversalObject(
          id: 'book_1',
          workspaceId: 'default',
          typeId: 'orbit.file',
          title: 'Structure and Interpretation of Computer Programs.pdf',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          body: '',
          properties: {
            'mimeType': 'application/pdf',
            'author': 'Harold Abelson, Gerald Jay Sussman',
            'shelf': 'Programming & CS',
            'isFavorite': true,
            'lastReadPage': 42,
            'totalPages': 657,
            'readingTimeMinutes': 125,
            'pdfBookmarks': [10, 42, 105],
            'notesCount': 5,
          },
        );

        final book = PdfBookMeta.fromObject(obj);
        expect(book.id, 'book_1');
        expect(book.title, 'Structure and Interpretation of Computer Programs');
        expect(book.author, 'Harold Abelson, Gerald Jay Sussman');
        expect(book.shelf, 'Programming & CS');
        expect(book.isFavorite, isTrue);
        expect(book.lastReadPage, 42);
        expect(book.totalPages, 657);
        expect(book.readingTimeMinutes, 125);
        expect(book.formattedReadingTime, '2h 5m');
        expect(book.bookmarksCount, 3);
        expect(book.notesCount, 5);
        expect(book.progress, closeTo(42 / 657, 0.001));
        expect(book.hasStarted, isTrue);
        expect(book.isFinished, isFalse);
      },
    );

    test('handles default fallbacks for unread book without metadata', () {
      final obj = UniversalObject(
        id: 'book_empty',
        workspaceId: 'default',
        typeId: 'orbit.file',
        title: 'Plain Book',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        body: '',
      );

      final book = PdfBookMeta.fromObject(obj);
      expect(book.title, 'Plain Book');
      expect(book.author, 'Unknown Author');
      expect(book.shelf, 'Currently Reading');
      expect(book.isFavorite, isFalse);
      expect(book.lastReadPage, 1);
      expect(book.totalPages, 1);
      expect(book.progress, 0.0);
      expect(book.readingTimeMinutes, 0);
      expect(book.formattedReadingTime, '0m');
      expect(book.hasStarted, isFalse);
    });
  });

  group('Virtual Reading Room Widgets', () {
    testWidgets(
      'AmbientSoundMixer renders sound channels and toggles master audio',
      (tester) async {
        final room = ReadingRoomCatalog.rainyLibrary;
        bool changed = false;

        await tester.pumpWidget(
          testHost(
            AmbientSoundMixer(room: room, onChanged: () => changed = true),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Atmospheric Ambience'), findsOneWidget);
        expect(find.text('Playing in room'), findsOneWidget);

        // Verify channel names from rainy library
        expect(find.text('Window Rain'), findsOneWidget);
        expect(find.text('Distant Thunder'), findsOneWidget);

        // Tap master pause toggle
        final masterToggle = find.byKey(
          const ValueKey('sound-mixer-master-toggle'),
        );
        expect(masterToggle, findsOneWidget);
        await tester.tap(masterToggle);
        await tester.pumpAndSettle();

        expect(find.text('Audio paused'), findsOneWidget);
        expect(changed, isTrue);

        // Mute first channel
        final muteBtn = find.byKey(
          ValueKey('mute-${room.soundChannels.first.id}'),
        );
        expect(muteBtn, findsOneWidget);
        await tester.tap(muteBtn);
        await tester.pumpAndSettle();
        expect(room.soundChannels.first.isMuted, isTrue);
      },
    );

    testWidgets('ReadingAtmosphere renders animated atmosphere view', (
      tester,
    ) async {
      await tester.pumpWidget(
        testHost(
          ReadingAtmosphere(
            room: ReadingRoomCatalog.fireplaceCabin,
            child: const Text('Reading under warm hearth glow'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reading under warm hearth glow'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets(
      'ReadingRoomAmbienceSheet switches rooms and paper tone filters',
      (tester) async {
        ReadingRoom currentRoom = ReadingRoomCatalog.rainyLibrary;
        String currentTone = 'normal';
        int? startedSessionMinutes;

        await tester.pumpWidget(
          testHost(
            ReadingRoomAmbienceSheet(
              initialRoom: currentRoom,
              activeColorFilter: currentTone,
              onRoomChanged: (r) => currentRoom = r,
              onColorFilterChanged: (f) => currentTone = f,
              onStartSession: (min, r) => startedSessionMinutes = min,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check environment room cards
        expect(
          find.byKey(const ValueKey('room-chip-rainy_library')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('room-chip-fireplace_cabin')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('room-chip-midnight_study')),
          findsOneWidget,
        );

        // Switch to Fireplace Cabin
        await tester.tap(
          find.byKey(const ValueKey('room-chip-fireplace_cabin')),
        );
        await tester.pumpAndSettle();
        expect(currentRoom.id, 'fireplace_cabin');

        // Select Cozy Sepia tone
        await tester.ensureVisible(find.text('Cozy Sepia'));
        await tester.tap(find.text('Cozy Sepia'));
        await tester.pumpAndSettle();
        expect(currentTone, 'sepia');

        // Select Dark Mode tone
        await tester.ensureVisible(find.text('Dark Mode'));
        await tester.tap(find.text('Dark Mode'));
        await tester.pumpAndSettle();
        expect(currentTone, 'dark');

        // Start focus timer session
        final startBtn = find.text('Start');
        expect(startBtn, findsOneWidget);
        await tester.ensureVisible(startBtn);
        await tester.tap(startBtn);
        await tester.pumpAndSettle();
        expect(startedSessionMinutes, 25);
      },
    );
  });

  group('BookMemoriesDialog & Note Export', () {
    testWidgets('renders book memories, bookmarks, and exports study note', (
      tester,
    ) async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final controller = WorkspaceController()
        ..repository = repo
        ..hasWorkspace = true
        ..loading = false;
      addTearDown(controller.cancelAllTimers);

      final bookObj = await controller.create(
        'orbit.file',
        title:
            'Design Patterns Elements of Reusable Object-Oriented Software.pdf',
        body: '',
        properties: {
          'mimeType': 'application/pdf',
          'author': 'Gang of Four',
          'shelf': 'Architecture',
          'totalPages': 395,
          'pdfBookmarks': [14, 87, 102],
        },
      );
      expect(bookObj, isNotNull);

      // Create a highlight annotation
      final noteObj = await controller.create(
        'orbit.note',
        title: 'Factory Pattern quote',
        body: "Program to an interface, not an implementation.",
        properties: {
          'pdfHighlightVersion': 1,
          'pdfSource': {
            'objectId': bookObj!.id,
            'page': 14,
            'quote': "Program to an interface, not an implementation.",
          },
        },
      );
      expect(noteObj, isNotNull);

      final bookMeta = PdfBookMeta.fromObject(bookObj);
      int? jumpedPage;

      await tester.pumpWidget(
        testHost(
          BookMemoriesDialog(
            book: bookMeta,
            controller: controller,
            bookmarks: const [14, 87, 102],
            annotations: [PdfAnnotation(noteObj!)],
            onJumpToPage: (p) => jumpedPage = p,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reading notes'), findsOneWidget);
      expect(find.text('Bookmark on Page 14'), findsOneWidget);
      expect(find.text('Bookmark on Page 87'), findsOneWidget);
      expect(find.text('Bookmark on Page 102'), findsOneWidget);

      // Jump to page 87
      await tester.tap(find.text('Bookmark on Page 87'));
      await tester.pumpAndSettle();
      expect(jumpedPage, 87);

      // Switch to Highlights & Notes tab
      await tester.tap(find.text('Highlights & Notes (1)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Program to an interface'), findsWidgets);

      // Export notes to Orbit Note
      final exportBtn = find.text('Export to Orbit Note');
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      // Memory repository work belongs to the widget test's zone. Moving only
      // later queue operations into runAsync can strand its earlier barrier.
      for (
        var i = 0;
        i < 100 &&
            !controller.activeObjects.any(
              (o) => o.title.startsWith('Reading Notes:'),
            );
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      controller.cancelAllTimers();

      // Verify study note was created in controller
      final notes = controller.activeObjects
          .where(
            (o) =>
                o.typeId == 'orbit.note' && o.title.contains('Reading Notes:'),
          )
          .toList();
      expect(controller.error, isNull);
      expect(notes.isNotEmpty, isTrue);
      expect(notes.first.body, contains('# Reading Notes:'));
      expect(notes.first.body, contains('Gang of Four'));
      expect(notes.first.body, contains('Program to an interface'));
    });
  });

  group('OrbitLibraryView Bookshelf', () {
    testWidgets('filters shelves, searches books, and triggers onOpenBook', (
      tester,
    ) async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final controller = WorkspaceController()
        ..repository = repo
        ..hasWorkspace = true
        ..loading = false;
      addTearDown(controller.cancelAllTimers);

      // Create test PDF books
      await controller.create(
        'orbit.file',
        title: 'Clean Code.pdf',
        body: '',
        properties: {
          'mimeType': 'application/pdf',
          'author': 'Robert C. Martin',
          'shelf': 'Tech & Code',
          'isFavorite': true,
          'lastReadPage': 50,
          'totalPages': 464,
        },
      );

      await controller.create(
        'orbit.file',
        title: 'Deep Work.pdf',
        body: '',
        properties: {
          'mimeType': 'application/pdf',
          'author': 'Cal Newport',
          'shelf': 'Productivity',
          'isFavorite': false,
          'lastReadPage': 1,
          'totalPages': 304,
        },
      );

      String? openedBookId;

      await tester.pumpWidget(
        testHost(
          OrbitLibraryView(
            controller: controller,
            onOpenBook: (id, {roomId}) => openedBookId = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bookshelf'), findsOneWidget);
      expect(find.text('Clean Code'), findsWidgets);
      expect(find.text('Deep Work'), findsOneWidget);

      // Tap on Favorites filter chip
      await tester.tap(find.byKey(const ValueKey('shelf-tab-favorites')));
      await tester.pumpAndSettle();

      // Clean Code is favorite, Deep Work is not
      expect(find.text('Clean Code'), findsWidgets);
      expect(find.text('Deep Work'), findsNothing);

      // Search for 'Clean'
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Clean');
      await tester.pumpAndSettle();

      expect(find.text('Clean Code'), findsWidgets);

      // Open the filtered book card; resume only appears on the main shelf.
      final heroResume = find.byKey(
        ValueKey(
          'book-card-${controller.activeObjects.firstWhere((o) => o.title == 'Clean Code.pdf').id}',
        ),
      );
      expect(heroResume, findsOneWidget);
      await tester.tap(heroResume);
      await tester.pumpAndSettle();

      expect(openedBookId, isNotNull);
      controller.cancelAllTimers();
    });
  });
}
