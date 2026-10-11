import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/pdf/pdf_bookmarks_dialog.dart';

void main() {
  testWidgets('Tab into a result supports arrows and Enter without a mouse', (
    tester,
  ) async {
    int? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Bookmarks'),
              onPressed: () async {
                opened = await showDialog<int>(
                  context: context,
                  builder: (_) => PdfBookmarksDialog(
                    pages: const [1, 2, 3],
                    names: const {},
                    pageCount: 3,
                    loadPreview: (_) async => null,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Sort control.
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // First result.
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('pdf-bookmark-2')))
          .selected,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opened, 2);
  });
  testWidgets(
    'sorting preserves selection and arrows follow the sorted results',
    (tester) async {
      final requested = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfBookmarksDialog(
              pages: const [3, 1, 2],
              names: const {1: 'Bravo', 2: 'alpha', 3: 'Alpha'},
              pageCount: 3,
              loadPreview: (p) async {
                requested.add(p);
                return null;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(requested, [1, 2]);
      Future<void> sort(String name) async {
        await tester.tap(find.byTooltip('Sort bookmarks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name).last);
        await tester.pumpAndSettle();
      }

      await sort('Name: A–Z');
      expect(requested, [1, 2]);
      expect(
        tester
            .widgetList<ListTile>(find.byType(ListTile))
            .where((w) => w.selected)
            .single
            .title,
        isA<Text>().having((w) => w.data, 'title', 'alpha'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(requested.last, 3); // Equal names use page-number order.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(requested.last, 1);
      final count = requested.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(requested.length, count); // No redundant preview at the boundary.
      await sort('Page: last to first');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(requested.last, 2);
      await sort('Name: Z–A');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(requested.last, 1);
      await tester.enterText(
        find.widgetWithText(TextField, 'Find a bookmark'),
        'no matches',
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard selection scrolls a long list and Enter opens its page',
    (tester) async {
      int? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Bookmarks'),
                onPressed: () async {
                  opened = await showDialog<int>(
                    context: context,
                    builder: (_) => PdfBookmarksDialog(
                      pages: List.generate(60, (i) => i + 1),
                      names: const {},
                      pageCount: 60,
                      loadPreview: (_) async => null,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('pdf-bookmark-31')), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('pdf-bookmark-31')))
            .selected,
        isTrue,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(opened, 31);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sorting and rows fit a narrow dialog at enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: PdfBookmarksDialog(
            pages: const [1, 99],
            names: const {1: 'A very long bookmark title'},
            pageCount: 3,
            loadPreview: (_) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'bookmark names search, retain failed rename text, and disable absent pages',
    (tester) async {
      var saveSucceeds = false;
      final requested = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfBookmarksDialog(
              pages: const [1, 2, 99],
              names: const {2: 'Equations'},
              pageCount: 3,
              loadPreview: (page) async {
                requested.add(page);
                return null;
              },
              onRename: (page, name) async => saveSucceeds,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.widgetWithText(TextField, 'Find a bookmark');
      await tester.enterText(search, 'equations');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Equations'), findsOneWidget);
      expect(requested, [1, 2]);
      await tester.tap(find.byTooltip('Rename bookmark on page 2'));
      await tester.pumpAndSettle();
      final name = find.widgetWithText(TextField, 'Bookmark name');
      await tester.enterText(name, 'Derivations');
      await tester.tap(find.text('Save name'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not save.'), findsOneWidget);
      expect(tester.widget<TextField>(name).controller!.text, 'Derivations');
      saveSucceeds = true;
      await tester.tap(find.text('Save name'));
      await tester.pumpAndSettle();
      expect(find.text('No matching bookmarks.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Open page'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(search, '99');
      await tester.pumpAndSettle();
      expect(find.textContaining('unavailable in this PDF'), findsOneWidget);
      expect(requested, isNot(contains(99)));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Open page'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
