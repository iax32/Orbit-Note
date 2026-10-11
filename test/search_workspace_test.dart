import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/domain/orbit_search.dart';
import 'package:orbit_note/domain/search_workspace.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/search_view.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

OrbitSearchResult result(
  String id, {
  String? title,
  String type = 'orbit.note',
  Map<String, dynamic> properties = const {},
  int day = 1,
  String kind = 'Paragraph',
}) {
  final object = UniversalObject(
    id: id,
    workspaceId: 'test',
    typeId: type,
    title: title ?? id,
    body: 'A useful research passage',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026, 9, day),
    properties: properties,
  );
  return OrbitSearchResult(
    object: object,
    location: ObjectReference(id),
    matchKind: kind,
    matchedText: 'A useful research passage',
    score: 60,
  );
}

class SearchController extends WorkspaceController {
  List<OrbitSearchResult> found = [];
  final pending = <String, Completer<List<OrbitSearchResult>>>{};
  OrbitSearchResult? opened;
  bool fail = false;
  @override
  Future<List<OrbitSearchResult>> searchLocations(String query) async {
    if (fail) throw StateError('Index unavailable');
    return pending[query]?.future ?? found;
  }

  @override
  void openSearchResult(OrbitSearchResult result) {
    opened = result;
  }

  // These UI fixtures exercise state without requiring a Vault persistence timer.
  @override
  void updateSession(void Function(SessionState) change) {
    change(session);
  }
}

Future<void> mount(
  WidgetTester tester,
  SearchController c, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: tester.view.physicalSize / tester.view.devicePixelRatio,
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: SearchView(controller: c)),
      ),
    ),
  );
}

Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'reading excerpts hide generated anchors without changing source matches',
    () {
      final original = result('a');
      final anchored = OrbitSearchResult(
        object: original.object,
        location: const ObjectReference(
          'a',
          anchorType: 'block',
          anchorId: 'orbit-123',
        ),
        matchKind: 'Paragraph',
        matchedText: '# Research passage ^orbit-123…',
        score: 60,
      );
      expect(readableSearchExcerpt(anchored), 'Research passage');
      expect(anchored.matchedText, '# Research passage ^orbit-123…');
      expect(
        const SearchOptions().apply([anchored]).single.location.anchorId,
        'orbit-123',
      );
      final literal = OrbitSearchResult(
        object: original.object,
        location: original.location,
        matchKind: 'Source',
        matchedText: '^orbit-123',
        score: 65,
      );
      expect(readableSearchExcerpt(literal), '^orbit-123');
    },
  );
  test(
    'filters combine, leave source results intact and sort ties deterministically',
    () {
      final a = result(
        'a',
        title: 'Zebra',
        properties: {
          'project': 'Study',
          'folder': 'Math',
          'tags': ['exam'],
        },
      );
      final b = result(
        'b',
        title: 'Alpha',
        type: 'orbit.task',
        day: 3,
        properties: {
          'project': 'Study',
          'folder': 'Math',
          'tags': ['exam'],
          'completed': true,
        },
      );
      final c = result(
        'c',
        title: 'Alpha',
        day: 3,
        properties: {
          'tags': ['other'],
        },
      );
      final all = [a, b, c];
      expect(
        const SearchOptions(
          project: 'Study',
          folder: 'Math',
          tag: 'exam',
          matchKind: 'Paragraph',
          hideCompleted: true,
        ).apply(all),
        [a],
      );
      expect(const SearchOptions(order: SearchOrder.modified).apply(all), [
        b,
        c,
        a,
      ]);
      expect(const SearchOptions(order: SearchOrder.title).apply(all), [
        b,
        c,
        a,
      ]);
      expect(const SearchOptions(tag: 'gone').apply(all), isEmpty);
      expect(all, [a, b, c]);
    },
  );
  test(
    'recipes preserve unknown data, history is bounded, future versions are untouched',
    () {
      var library = SearchLibrary({
        'custom': {'color': 'blue'},
        'saved': [
          {'version': 9, 'name': 'Future', 'query': 'future', 'opaque': 42},
          {
            'name': 'Exam',
            'query': 'old',
            'extension': {'keep': true},
          },
          null,
        ],
      });
      library = SearchLibrary(
        library.save(
          const SavedSearch('exam', 'research', SearchOptions(tag: 'exam')),
        ),
      );
      expect(library.saved.single.options.tag, 'exam');
      expect((library.json['saved'] as List)[1]['extension'], {'keep': true});
      final saved = library.saved.single;
      library = SearchLibrary(library.remove(saved.name));
      final historyBeforeUndo = library.recent;
      library = SearchLibrary(library.restore(saved));
      expect(library.recent, historyBeforeUndo);
      expect((library.json['saved'] as List).last['extension'], {'keep': true});
      expect((library.json['saved'] as List).first['version'], 9);
      for (var i = 0; i < 15; i++) {
        library = SearchLibrary(library.remember('query $i'));
      }
      library = SearchLibrary(library.remember('QUERY 14'));
      expect(library.recent.length, 10);
      expect(library.recent.first, 'QUERY 14');
      expect(library.json['custom'], {'color': 'blue'});
      expect(SearchLibrary(library.clearRecent()).recent, isEmpty);
      final future = SearchLibrary({
        'version': 2,
        'opaque': [1, 2],
      });
      expect(future.remember('research'), same(future.json));
      expect(() => future.save(saved), throwsStateError);
      expect(SessionState.fromJson({}).searchWorkspace, isEmpty);
    },
  );
  test(
    'device settings reopen recipes; failed saves retain previous bytes and can retry',
    () async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final session = SessionState.fromJson({
        'unrelated': {'keep': true},
      });
      session.searchWorkspace = const SearchLibrary({}).save(
        const SavedSearch(
          'Proofs',
          'research',
          SearchOptions(folder: 'Math', order: SearchOrder.modified),
        ),
      );
      await repo.writeDeviceSettings(session.toJson());
      final reopened = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await reopened.initialize();
      final restored = SessionState.fromJson(
        await reopened.readDeviceSettings(),
      );
      expect(
        SearchLibrary(restored.searchWorkspace).saved.single.options.folder,
        'Math',
      );
      expect(restored.extra['unrelated'], {'keep': true});
      restored.searchWorkspace = SearchLibrary(
        restored.searchWorkspace,
      ).clearRecent();
      store.failWrites = true;
      await expectLater(
        reopened.writeDeviceSettings(restored.toJson()),
        throwsA(anything),
      );
      store.failWrites = false;
      expect(
        SearchLibrary(
          SessionState.fromJson(
            await reopened.readDeviceSettings(),
          ).searchWorkspace,
        ).recent,
        ['research'],
      );
      await reopened.writeDeviceSettings(restored.toJson());
      expect(
        SearchLibrary(
          SessionState.fromJson(
            await reopened.readDeviceSettings(),
          ).searchWorkspace,
        ).recent,
        isEmpty,
      );
    },
  );
  testWidgets(
    'query arrows select exact result; opening records history and Escape clears',
    (tester) async {
      final c = SearchController()..found = [result('First'), result('Second')];
      await mount(tester, c);
      await search(tester, 'research');
      expect(SearchLibrary(c.session.searchWorkspace).recent, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(c.opened?.object.id, 'Second');
      expect(SearchLibrary(c.session.searchWorkspace).recent, ['research']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Recent searches'), findsOneWidget);
      await tester.tap(find.text('Clear history'));
      await tester.pump();
      expect(SearchLibrary(c.session.searchWorkspace).recent, isEmpty);
    },
  );
  testWidgets(
    'save filters and restore recipe; remove offers non-destructive undo',
    (tester) async {
      final c = SearchController()
        ..found = [
          result(
            'Proof',
            properties: {
              'tags': ['exam'],
            },
          ),
        ];
      await mount(tester, c);
      await search(tester, 'research');
      await tester.tap(find.text('More filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter by tag'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'exam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Exam passages');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(
        SearchLibrary(c.session.searchWorkspace).saved.single.options.tag,
        'exam',
      );
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Exam passages'));
      await tester.pumpAndSettle();
      expect(find.text('exam'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove Exam passages'));
      await tester.pumpAndSettle();
      expect(SearchLibrary(c.session.searchWorkspace).saved, isEmpty);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        SearchLibrary(c.session.searchWorkspace).saved.single.query,
        'research',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'late query cannot replace newer results; search failure retries',
    (tester) async {
      final first = Completer<List<OrbitSearchResult>>();
      final c = SearchController()
        ..pending['first'] = first
        ..found = [result('New')];
      await mount(tester, c);
      await tester.enterText(find.byType(TextField), 'first');
      await tester.pump(const Duration(milliseconds: 200));
      await search(tester, 'second');
      first.complete([result('Old')]);
      await tester.pumpAndSettle();
      expect(find.text('Old'), findsNothing);
      expect(find.text('New'), findsOneWidget);
      c.fail = true;
      await search(tester, 'broken');
      expect(find.text('Search is temporarily unavailable.'), findsOneWidget);
      c.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('New'), findsOneWidget);
    },
  );
  testWidgets(
    'small pane and enlarged text support preview without layout errors',
    (tester) async {
      tester.view.physicalSize = const Size(560, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = SearchController()
        ..found = [
          result(
            'Research source',
            properties: {
              'folder': 'Math',
              'tags': ['exam'],
            },
          ),
        ];
      await mount(tester, c, scale: 1.5);
      await search(tester, 'research');
      await tester.tap(find.text('More filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Preview Research source'));
      await tester.pumpAndSettle();
      expect(find.text('Open at match'), findsOneWidget);
      expect(find.text('Matched paragraph'), findsOneWidget);
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      expect(c.opened, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
