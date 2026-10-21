import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/starter_templates.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_starter_dialog.dart';
import 'package:orbit_note/features/notes/note_template_dialog.dart';
import 'package:orbit_note/features/notes/note_templates.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

Widget host(Widget child, {double scale = 1}) => MaterialApp(
  theme: orbitDarkTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  test(
    'everyday categories search across terms and retain the original catalog',
    () {
      expect(
        NoteTemplates.all.map((t) => t.id).toSet(),
        hasLength(NoteTemplates.all.length),
      );
      expect(
        NoteTemplates.all.where((t) => t.customizable).length,
        greaterThanOrEqualTo(24),
      );
      for (final category in NoteTemplateCategory.values) {
        expect(NoteTemplates.search('', category: category), isNotEmpty);
      }
      expect(
        NoteTemplates.search(
          ' nature   observation ',
          category: NoteTemplateCategory.outdoors,
        ).map((t) => t.id),
        contains('nature_field_log'),
      );
      expect(
        NoteTemplates.search(
          'prompt experiment',
          category: NoteTemplateCategory.ai,
        ).map((t) => t.id),
        contains('ai_prompt_lab'),
      );
      expect(
        NoteTemplates.search('camping', category: NoteTemplateCategory.code),
        isEmpty,
      );
      expect(NoteTemplates.byId('cornell'), isNotNull);
      expect(NoteTemplates.byId('story_outline'), isNotNull);
      expect(NoteTemplates.byId('article_reverse'), isNotNull);
    },
  );
  test(
    'custom title and local calendar date materialize once without altering the starter',
    () {
      final original = NoteTemplates.byId('journal_daily')!;
      final note = original.instantiate(
        title: ' My thoughts\r\nfrom today ',
        date: DateTime(2026, 10, 25, 0, 30),
      );
      expect(note.defaultTitle, 'My thoughts from today');
      expect(note.body, startsWith('# My thoughts from today\n'));
      expect(note.body, contains('2026-10-25'));
      expect(note.body, isNot(contains('{{')));
      expect(original.body, contains('{{title}}'));
      expect(note.instantiate(title: 'Other'), same(note));
      expect(
        original
            .instantiate(title: '  ', date: DateTime(2026, 1, 2))
            .defaultTitle,
        original.defaultTitle,
      );
    },
  );
  test(
    'all new starters persist as ordinary notes with distinct identities',
    () async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      addTearDown(repo.close);
      final expected = <String, String>{};
      for (final template in NoteTemplates.all.where((t) => t.customizable)) {
        final note = template.instantiate(date: DateTime(2026, 10, 20));
        expect(note.body, isNot(contains('{{')));
        expect(note.body, isNot(contains('[[Related Note]]')));
        final object = await repo.create(
          typeId: 'orbit.note',
          title: note.defaultTitle,
          body: note.body,
          properties: {'tags': note.tags},
        );
        expected[object.id] = note.body;
      }
      await repo.initialize();
      for (final entry in expected.entries) {
        expect(
          repo.objects.singleWhere((o) => o.id == entry.key).body,
          entry.value,
        );
      }
      expect(
        expected.length,
        NoteTemplates.all.where((t) => t.customizable).length,
      );
    },
  );
  test(
    'Canvas starters generate fresh editable placements and valid connectors on every insertion',
    () {
      var next = 0;
      expect(CanvasStarters.all.map((t) => t.id).toSet(), hasLength(8));
      for (final starter in CanvasStarters.all) {
        final first = starter.createElements(() => 'p${next++}');
        final second = starter.createElements(() => 'p${next++}');
        final ids = first.map((e) => e.id).toSet();
        expect(ids.intersection(second.map((e) => e.id).toSet()), isEmpty);
        for (final e in first) {
          expect(e.locked, isFalse);
          expect(e.objectId, isNull);
          if (e.type == 'connector') {
            expect(ids, contains(e.startId));
            expect(ids, contains(e.endId));
          }
        }
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': first.map((e) => e.data).toList(),
        });
        expect(scene.readOnly, isFalse);
        expect(scene.contentBounds, isNotNull);
        final history = CanvasHistory(scene);
        for (final element in second) {
          history.put(element);
        }
        history.commit();
        history.undo();
        expect(scene.elements.map((e) => e.id).toSet(), ids);
        history.redo();
        expect(scene.length, first.length + second.length);
      }
      expect(
        () => CanvasStarters.all.first.createElements(() => 'duplicate'),
        throwsStateError,
      );
      expect(
        CanvasStarters.search('nature observation').map((s) => s.id),
        contains('everyday_nature'),
      );
    },
  );

  testWidgets(
    'search, preview, custom title and create return prepared Markdown',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      NoteTemplate? selected;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await NoteTemplateDialog.show(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('note-template-search-field')),
        'field log',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('template-item-nature_field_log')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('template-custom-title')),
        'Riverbank observations',
      );
      await tester.pump();
      expect(find.textContaining('# Riverbank observations'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('create-note-from-template-button')),
      );
      await tester.pumpAndSettle();
      expect(selected!.defaultTitle, 'Riverbank observations');
      expect(selected!.body, isNot(contains('{{')));
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'compact template details and empty search remain usable at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(host(const NoteTemplateDialog(), scale: scale));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('note-template-search-field')),
          'daily journal',
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('template-item-journal_daily')),
          160,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('compact-template-browse')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('template-item-journal_daily')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('template-preview-journal_daily')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byKey(const ValueKey('note-template-search-field')),
          'no-such-starter-xyz',
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('create-note-from-template-button')),
              )
              .onPressed,
          isNull,
        );
        expect(find.textContaining('No matching templates'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'category filtering changes the active selection before creating',
    (tester) async {
      await tester.pumpWidget(host(const NoteTemplateDialog()));
      await tester.pumpAndSettle();
      final chip = find.byKey(const ValueKey('template-category-journal'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('template-item-cornell')), findsNothing);
      expect(
        find.byKey(const ValueKey('template-item-journal_daily')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Canvas library previews and inserts without changing existing placements; one Undo restores it',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final existing = {
        'id': 'old',
        'type': 'sticky',
        'text': 'Keep me',
        'x': 0,
        'y': 0,
        'width': 200,
        'height': 100,
        'future': true,
      };
      Map<String, dynamic> latest = {
        'schemaVersion': 1,
        'future': 'keep',
        'elements': [existing],
      };
      await tester.pumpWidget(
        host(
          CanvasEditor(
            canvasId: 'board',
            data: latest,
            onChanged: (v) => latest = v,
            objects: const [],
            onOpenObject: (_) {},
          ),
        ),
      );
      await tester.tap(find.byTooltip('Canvas template library'));
      await tester.pumpAndSettle();
      expect(find.byType(CanvasStarterDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('canvas-starter-search')),
        'mind map',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('canvas-starter-everyday_mind_map')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to Canvas'));
      await tester.pumpAndSettle();
      expect(latest['future'], 'keep');
      final items = latest['elements'] as List;
      expect(items.first, existing);
      expect(items, hasLength(14));
      expect(
        items
            .skip(1)
            .where((e) => e['type'] != 'connector')
            .every((e) => e['x'] > 200),
        isTrue,
      );
      await tester.tapAt(const Offset(600, 600));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(latest['elements'], [existing]);
    },
  );
  testWidgets(
    'applied starter stays empty after intentional deletion and reopen',
    (tester) async {
      Map<String, dynamic> data = {
        'schemaVersion': 1,
        'canvasPreset': 'everyday_mind_map',
        'elements': [],
      };
      await tester.pumpWidget(
        host(
          CanvasEditor(
            canvasId: 'preset',
            data: data,
            onChanged: (v) => data = v,
            objects: const [],
            onOpenObject: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(data['elements'], hasLength(13));
      expect(data['canvasPresetApplied'], isTrue);
      await tester.pumpWidget(const SizedBox());
      data = {...data, 'elements': []};
      var emissions = 0;
      await tester.pumpWidget(
        host(
          CanvasEditor(
            canvasId: 'preset',
            data: data,
            onChanged: (_) => emissions++,
            objects: const [],
            onOpenObject: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(emissions, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'an outstanding Canvas starter cannot apply after editing permission changes',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var readOnly = false, emissions = 0;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return CanvasEditor(
                canvasId: 'board',
                readOnly: readOnly,
                data: const {'schemaVersion': 1, 'elements': []},
                onChanged: (_) => emissions++,
                objects: const [],
                onOpenObject: (_) {},
              );
            },
          ),
        ),
      );
      await tester.tap(find.byTooltip('Canvas template library'));
      await tester.pumpAndSettle();
      update(() => readOnly = true);
      await tester.pump();
      await tester.tap(find.text('Add to Canvas'));
      await tester.pumpAndSettle();
      expect(emissions, 0);
      expect(find.byTooltip('Canvas template library'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Canvas library keeps search, previews and insertion reachable with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(host(const CanvasStarterDialog(), scale: 2));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('canvas-starter-search')),
        'nature observation',
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('canvas-starter-everyday_nature')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('canvas-starter-everyday_nature')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Add to Canvas'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
