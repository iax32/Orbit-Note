import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/domain/search_workspace.dart';
import 'package:orbit_note/features/workspace/search_view.dart';
import 'package:orbit_note/features/workspace/command_palette.dart';
import 'search_workspace_test.dart' as fixtures;
import 'support/memory_store.dart';

class _Controller extends fixtures.SearchController {
  _Controller() {
    repository = WorkspaceRepository(
      store: MemoryStore(),
      index: MemoryObjectIndex(),
    );
  }
  String? openedId;
  @override
  void openObject(String id, {bool secondary = false, bool reveal = false}) =>
      openedId = id;
}

void main() {
  const title =
      'Detailed interdisciplinary research and literature review document';
  const project =
      'Interdisciplinary literature review for the upcoming research conference';
  const recipe =
      'Research conference review with detailed project and folder filters';

  Future<void> mount(WidgetTester tester, Size size, Widget child) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: orbitDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.5)),
            child: child!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(
    WidgetTester tester,
    Finder finder, {
    bool dialog = false,
  }) async {
    final root = dialog ? find.byType(Dialog) : find.byType(CustomScrollView);
    final scroll = find
        .descendant(of: root, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      finder.hitTestable(),
      120,
      scrollable: scroll,
      maxScrolls: 80,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  void readable(WidgetTester tester, Finder finder) {
    expect(
      tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
      isFalse,
    );
  }

  for (final size in [const Size(320, 640), const Size(568, 320)]) {
    testWidgets('search failure and empty states remain reachable at $size', (
      tester,
    ) async {
      final c = _Controller()..fail = true;
      await mount(tester, size, SearchView(controller: c));
      await fixtures.search(tester, 'research');
      await reveal(tester, find.text('Retry'));
      c.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('No matches'));
      readable(tester, find.text('No matches'));
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'search filters and exact source preview fit keyboard insets at $size',
      (tester) async {
        final c = _Controller()
          ..found = [
            fixtures.result(
              'source',
              title: title,
              properties: {'project': project, 'folder': project},
            ),
          ];
        await mount(tester, size, SearchView(controller: c));
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height > 400 ? 240 : 80,
        );
        addTearDown(tester.view.resetViewInsets);
        await fixtures.search(tester, 'research');
        await reveal(tester, find.byTooltip('Filter by project'));
        await tester.tap(find.byTooltip('Filter by project'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(project).last);
        await tester.pumpAndSettle();
        await reveal(tester, find.byTooltip('Preview $title'));
        readable(tester, find.text(title));
        await tester.tap(find.byTooltip('Preview $title'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        readable(tester, find.text(title).last);
        await tester.tap(find.text('Open at match'));
        await tester.pumpAndSettle();
        expect(c.opened?.location, c.found.single.location);
        expect(c.opened?.object.id, 'source');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'keyboard selection reveals variable-height lazy search rows at $size',
      (tester) async {
        final c = _Controller()
          ..found = [
            for (var i = 0; i < 25; i++)
              fixtures.result('result-$i', title: '$title $i'),
          ];
        await mount(tester, size, SearchView(controller: c));
        await fixtures.search(tester, 'research');
        for (var i = 0; i < 18; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
        }
        final selected = find.text('$title 18');
        expect(selected.hitTestable(), findsOneWidget);
        readable(tester, selected);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(c.opened?.object.id, 'result-18');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
      },
    );

    testWidgets(
      'saved search management wraps recipes and preserves undo at $size',
      (tester) async {
        final c = _Controller();
        c.session.searchWorkspace =
            const SearchLibrary({
              'custom': {'keep': true},
            }).save(
              const SavedSearch(
                recipe,
                project,
                SearchOptions(project: project),
              ),
            );
        await mount(tester, size, SearchView(controller: c));
        await reveal(tester, find.text('Manage'));
        await tester.tap(find.text('Manage'));
        await tester.pumpAndSettle();
        readable(
          tester,
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text(project),
          ),
        );
        await reveal(tester, find.byTooltip('Remove $recipe'), dialog: true);
        await tester.tap(find.byTooltip('Remove $recipe'));
        await tester.pumpAndSettle();
        expect(SearchLibrary(c.session.searchWorkspace).saved, isEmpty);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(
          SearchLibrary(c.session.searchWorkspace).saved.single.query,
          project,
        );
        expect(c.session.searchWorkspace['custom'], {'keep': true});
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'saving a search keeps validation and cancellation reachable at $size',
      (tester) async {
        final c = _Controller()..found = [fixtures.result('source')];
        await mount(tester, size, SearchView(controller: c));
        await fixtures.search(tester, 'research');
        await reveal(tester, find.text('Save search'));
        await tester.tap(find.text('Save search'));
        await tester.pumpAndSettle();
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height > 400 ? 240 : 80,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        readable(tester, find.text('Enter a name.'));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(SearchLibrary(c.session.searchWorkspace).saved, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'palette long titles, navigation and close fit keyboard insets at $size',
      (tester) async {
        final c = _Controller()
          ..objects = [
            fixtures.result('first', title: title).object,
            fixtures.result('second', title: '$title second').object,
          ];
        c.session.recent = ['first', 'second'];
        await mount(
          tester,
          size,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showCommandPalette(context, c),
              child: const Text('Open palette'),
            ),
          ),
        );
        await tester.tap(find.text('Open palette'));
        await tester.pumpAndSettle();
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height > 400 ? 240 : 80,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          find.text('$title second').hitTestable(at: Alignment.topCenter),
          findsOneWidget,
        );
        readable(tester, find.text('$title second'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(c.openedId, 'second');
        expect(find.byType(CommandPalette), findsNothing);
        await tester.tap(find.text('Open palette'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close palette'));
        await tester.pumpAndSettle();
        expect(find.byType(CommandPalette), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'wide search preview keeps its open action reachable in a short window',
    (tester) async {
      final c = _Controller()
        ..found = [fixtures.result('source', title: title)];
      await mount(tester, const Size(1000, 320), SearchView(controller: c));
      tester.view.viewInsets = const FakeViewPadding(bottom: 80);
      addTearDown(tester.view.resetViewInsets);
      await fixtures.search(tester, 'research');
      await reveal(tester, find.byTooltip('Preview $title'));
      await tester.tap(find.byTooltip('Preview $title'));
      await tester.pumpAndSettle();
      expect(find.text('Open at match').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Open at match'));
      await tester.pumpAndSettle();
      expect(c.opened?.object.id, 'source');
      expect(tester.takeException(), isNull);
    },
  );
}
