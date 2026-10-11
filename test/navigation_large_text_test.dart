import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/canvas_search.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/features/canvas/canvas_search_overlay.dart';
import 'package:orbit_note/features/pdf/pdf_bookmarks_dialog.dart';
import 'package:orbit_note/features/pdf/pdf_outline_dialog.dart';
import 'package:orbit_note/features/pdf/pdf_zoom_dialog.dart';

Future<void> mount(WidgetTester tester, Widget child, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: orbitDarkTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2.5)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pump();
}

void main() {
  for (final size in [const Size(320, 640), const Size(568, 320)]) {
    testWidgets(
      'Expanded Canvas search fits and exposes full results at $size',
      (tester) async {
        final input = TextEditingController(text: 'architecture');
        final focus = FocusNode();
        addTearDown(input.dispose);
        addTearDown(focus.dispose);
        var selected = -1, closed = 0, next = 0;
        CanvasSearchCategory? category;
        const title = 'Architecture reference with a long descriptive name';
        await mount(
          tester,
          Align(
            alignment: Alignment.topLeft,
            child: CanvasSearchOverlay(
              searchController: input,
              searchFocusNode: focus,
              results: [
                for (var i = 0; i < 25; i++)
                  CanvasSearchResult(
                    elementId: '$i',
                    elementType: 'card',
                    title: '$title $i',
                    snippet:
                        'Important source context and matching text for item $i',
                    bounds: const CanvasBounds(0, 0, 100, 100),
                  ),
              ],
              activeIndex: 0,
              category: CanvasSearchCategory.all,
              onCategoryChanged: (v) => category = v,
              onNext: () => next++,
              onPrevious: () {},
              onSelectIndex: (i) => selected = i,
              onClose: () => closed++,
            ),
          ),
          size,
        );
        await tester.tap(find.byTooltip('Show results'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getBottomRight(find.byType(CanvasSearchOverlay)).dy,
          lessThanOrEqualTo(size.height),
        );
        final first = find.text('$title 0');
        await reveal(tester, first);
        expect(tester.widget<Text>(first).maxLines, isNull);
        await tester.tap(first);
        expect(selected, 0);
        await reveal(tester, find.text('Media'));
        await tester.tap(find.text('Media'));
        expect(category, CanvasSearchCategory.media);
        await tester.tap(find.byTooltip('Next (Enter)'));
        expect(next, 1);
        await tester.tap(find.byTooltip('Close (Esc)'));
        expect(closed, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Canvas active search result survives keyboard insets at $size',
      (tester) async {
        final input = TextEditingController(text: 'design');
        final focus = FocusNode();
        addTearDown(input.dispose);
        addTearDown(focus.dispose);
        addTearDown(tester.view.resetViewInsets);
        var active = 0;
        final results = [
          for (var i = 0; i < 30; i++)
            CanvasSearchResult(
              elementId: '$i',
              elementType: 'sticky',
              title: 'Design reference $i with a long descriptive title',
              snippet: 'Context for reference $i',
              bounds: const CanvasBounds(0, 0, 100, 100),
            ),
        ];
        await mount(
          tester,
          StatefulBuilder(
            builder: (context, change) => Align(
              alignment: Alignment.topLeft,
              child: CanvasSearchOverlay(
                searchController: input,
                searchFocusNode: focus,
                results: results,
                activeIndex: active,
                category: CanvasSearchCategory.all,
                onCategoryChanged: (_) {},
                onNext: () => change(() => active = active == 0 ? 29 : 0),
                onPrevious: () {},
                onSelectIndex: (_) {},
                onClose: () {},
              ),
            ),
          ),
          size,
        );
        await tester.tap(find.byTooltip('Show results'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Next (Enter)'));
        await tester.pumpAndSettle();
        expect(
          find.text(results.last.title).hitTestable(at: Alignment.topCenter),
          findsOneWidget,
        );
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height > 400 ? 240 : 80,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Close (Esc)').hitTestable(), findsOneWidget);
        await tester.tap(find.byTooltip('Next (Enter)'));
        await tester.pumpAndSettle();
        expect(
          find.text(results.first.title).hitTestable(at: Alignment.topCenter),
          findsOneWidget,
        );
        expect(active, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Outline headings wrap and keyboard reveals variable rows at $size',
      (tester) async {
        const title =
            'Long chapter title describing architecture and storage boundaries';
        await mount(
          tester,
          PdfOutlineDialog(
            nodes: [
              for (var i = 0; i < 40; i++)
                PdfOutlineNode(
                  title: '$title $i',
                  dest: PdfDest(i + 1, PdfDestCommand.fit, null),
                  children: const [],
                ),
            ],
          ),
          size,
        );
        expect(tester.widget<Text>(find.text('$title 0')).maxLines, isNull);
        for (var i = 0; i < 30; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
        }
        final target = find.widgetWithText(ListTile, '$title 30');
        expect(target, findsOneWidget);
        expect(tester.widget<ListTile>(target).selected, true);
        expect(target.hitTestable(at: Alignment.topCenter), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(
          find
              .widgetWithText(ListTile, '$title 29')
              .hitTestable(at: Alignment.topCenter),
          findsOneWidget,
        );
        expect(find.text('Close').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Bookmark labels and unavailable page warnings wrap at $size', (
      tester,
    ) async {
      const name =
          'Very long named bookmark for the architecture appendix and source records';
      await mount(
        tester,
        PdfBookmarksDialog(
          pages: const [1, 5],
          names: const {1: name, 5: name},
          pageCount: 2,
          loadPreview: (_) async => null,
          onRename: (_, _) async => false,
        ),
        size,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pdf-bookmark-1')),
        80,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<Text>(find.text(name).first).maxLines, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final warning = find.text('Page 5 · unavailable in this PDF');
      expect(tester.widget<Text>(warning).maxLines, isNull);
      await reveal(tester, warning);
      expect(warning.hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Open page'),
            )
            .onPressed,
        isNull,
      );
      await reveal(tester, find.byTooltip('Rename bookmark on page 5'));
      await tester.tap(find.byTooltip('Rename bookmark on page 5'));
      await tester.pumpAndSettle();
      final helper = find.text('Leave blank to use the page number.');
      await reveal(tester, helper);
      expect(
        tester.renderObject<RenderParagraph>(helper).didExceedMaxLines,
        false,
      );
      await tester.tap(find.text('Save name'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not save.'), findsOneWidget);
      final input = tester.widget<TextField>(find.byType(TextField).last);
      expect(input.controller!.text, name);
      final error = find.textContaining('Could not save.');
      await reveal(tester, error);
      expect(
        tester.renderObject<RenderParagraph>(error).didExceedMaxLines,
        false,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Saved pages'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Zoom validation stays readable at $size', (tester) async {
      await mount(
        tester,
        const PdfZoomDialog(current: 100, minimum: 10, maximum: 800),
        size,
      );
      await tester.enterText(find.byType(TextField), 'invalid');
      await tester.tap(find.text('Apply zoom'));
      await tester.pumpAndSettle();
      expect(find.text('Enter 10–800%.'), findsOneWidget);
      final error = find.text('Enter 10–800%.');
      await reveal(tester, error);
      expect(
        tester.renderObject<RenderParagraph>(error).didExceedMaxLines,
        false,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
