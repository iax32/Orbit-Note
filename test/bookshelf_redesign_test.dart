import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/pdf/library/pdf_library_view.dart';
import 'package:orbit_note/features/pdf/library/pdf_book_model.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  test(
    'unknown and malformed metadata does not fabricate completion or crash',
    () {
      final object = UniversalObject(
        id: 'pdf',
        workspaceId: 'vault',
        typeId: 'orbit.file',
        title: 'Reader.pdf',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        properties: {
          'pageCount': double.nan,
          'lastReadPage': 9,
          'readingTimeMinutes': double.infinity,
          'pdfBookmarks': [2, null, '3', -1],
        },
      );
      final book = PdfBookMeta.fromObject(object);
      expect(book.isFinished, isFalse);
      expect(book.progress, 0);
      expect(book.lastReadPage, 9);
      expect(book.readingTimeMinutes, 0);
      expect(book.bookmarksCount, 1);
    },
  );
  testWidgets(
    'narrow large-text library keeps PDF objects, filters and saved rooms',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final c = WorkspaceController()
        ..repository = repo
        ..hasWorkspace = true
        ..loading = false;
      addTearDown(c.cancelAllTimers);
      final book = await tester.runAsync(
        () => c.create(
          'orbit.file',
          title: 'A long lecture reader without a filename extension',
          properties: {
            'mimeType': 'application/pdf',
            'author': 'A reader with a long author name',
            'lastReadPage': 5,
            'totalPages': 10,
            'lastRoomId': 'fireplace_cabin',
            'pdfBookmarks': [2, 'invalid', null, -1],
          },
        ),
      );
      c.session.noteViews = {
        'pdf:primary:${book!.id}': {'page': 6},
      };
      await tester.runAsync(
        () => c.create(
          'orbit.note',
          title: 'Reading annotation',
          body: 'A linked note',
          properties: {
            'pdfSource': {
              'objectId': book.id,
              'page': 2,
              'quote': 'A quotation',
            },
          },
        ),
      );
      String? opened;
      String? room;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: OrbitLibraryView(
            controller: c,
            onOpenBook: (id, {roomId}) {
              opened = id;
              room = roomId;
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Bookshelf'), findsOneWidget);
      expect(find.text('Page 6 of 10'), findsWidgets);
      final continueButton = find.byKey(
        const ValueKey('hero-continue-reading-btn'),
      );
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      expect(opened, book.id);
      expect(room, 'fireplace_cabin');
      final layout = find.byKey(const ValueKey('library-layout'));
      await tester.ensureVisible(layout);
      await tester.pump();
      await tester.tap(layout);
      await tester.pump();
      final notes = find.byKey(ValueKey('book-memories-btn-${book.id}'));
      await tester.ensureVisible(notes);
      await tester.pump();
      await tester.tap(notes);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Bookmark on Page 2'), findsOneWidget);
      expect(find.text('Highlights & Notes (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(c.flushAll);
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'empty library uses a real empty state without a fabricated resume',
    (tester) async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final c = WorkspaceController()
        ..repository = repo
        ..hasWorkspace = true
        ..loading = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: OrbitLibraryView(controller: c, onOpenBook: (_, {roomId}) {}),
        ),
      );
      expect(find.text('A place for your reading'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('hero-continue-reading-btn')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      c.cancelAllTimers();
    },
  );
}
