import 'package:orbit_note/features/workspace/life_pack_dialog.dart';
import 'package:orbit_note/features/notes/note_template_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/life_workspace.dart';
import 'package:orbit_note/domain/life_templates.dart';
import 'package:orbit_note/features/workspace/life_workspace.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  late MemoryStore store;
  late ProviderContainer container;
  late WorkspaceController c;
  setUp(() async {
    store = MemoryStore();
    final repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    for (var i = 0; i < 200 && c.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  });
  tearDown(() async {
    store.failWrites = false;
    await c.closeWorkspace();
    container.dispose();
  });
  Future<void> host(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(1200, 900),
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(
              ctx,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final config in [
    (const Size(1200, 900), 1.0),
    (const Size(380, 760), 2.0),
  ]) {
    testWidgets(
      'all Life areas remain usable at ${config.$1}, text ${config.$2}',
      (tester) async {
        await host(
          tester,
          LifeWorkspace(controller: c),
          size: config.$1,
          scale: config.$2,
        );
        for (final section in lifeSections) {
          final chip = find.widgetWithText(ChoiceChip, section).first;
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: section);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
  for (final kind in LifeKind.values.where(
    (k) => ![
      'session',
      'habitLog',
      'routineLog',
      'review',
      'template',
    ].contains(k.name),
  )) {
    testWidgets('${kind.label} setup works at narrow width and enlarged text', (
      tester,
    ) async {
      await host(
        tester,
        LifeRecordForm(
          controller: c,
          kind: kind,
          preset: lifePresets.where((p) => p.kind == kind).firstOrNull,
        ),
        size: const Size(380, 760),
        scale: 2,
      );
      expect(find.text('Save'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      // The standalone dialog route may close on a valid preset. Empty titles
      // remain open with an accessible validation message.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
  testWidgets('goal setup preserves entered writing when validation fails', (
    tester,
  ) async {
    await host(tester, LifeRecordForm(controller: c, kind: LifeKind.goal));
    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Writing (Markdown)',
    );
    await tester.enterText(field, 'Keep this thought');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a title'), findsOneWidget);
    expect(find.text('Keep this thought'), findsOneWidget);
  });
  testWidgets('Home summary reflects actual goals and resumable workouts', (
    tester,
  ) async {
    await tester.runAsync(() => c.createLife(LifeKind.goal, 'Learn'));
    await host(tester, LifeHomeCard(controller: c));
    expect(find.textContaining('1 active goals'), findsOneWidget);
    await tester.tap(find.text('Open Life'));
    await tester.pumpAndSettle();
    expect(find.text('Life workspace'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets(
    'failed persistent form save keeps writing and can retry successfully',
    (tester) async {
      await host(
        tester,
        LifeRecordForm(controller: c, kind: LifeKind.goal, persist: true),
      );
      final title = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Title',
      );
      final body = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Writing (Markdown)',
      );
      await tester.enterText(title, 'A real goal');
      await tester.enterText(body, 'Preserve my full draft');
      store.failWrites = true;
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(find.text('Preserve my full draft'), findsOneWidget);
      expect(c.lifeIndex.of(LifeKind.goal), isEmpty);
      store.failWrites = false;
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(
        c.lifeIndex.of(LifeKind.goal).single.body,
        'Preserve my full draft',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('personal templates appear in the shared note template picker', (
    tester,
  ) async {
    final source = await tester.runAsync(
      () => c.create(
        'orbit.note',
        title: 'My reusable source',
        body: 'Reusable words',
      ),
    );
    final template = await tester.runAsync(
      () => c.savePersonalTemplate(source!, 'Personal moon journal'),
    );
    await host(tester, NoteTemplateDialog(personalTemplates: [template!]));
    await tester.enterText(
      find.byKey(const ValueKey('note-template-search-field')),
      'Personal moon',
    );
    await tester.pumpAndSettle();
    expect(find.text('Personal moon journal'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('connected pack setup fits narrow screens and large text', (
    tester,
  ) async {
    await host(
      tester,
      Builder(
        builder: (ctx) => TextButton(
          onPressed: () => showLifePackSetup(ctx, c),
          child: const Text('Setup'),
        ),
      ),
      size: const Size(380, 760),
      scale: 2,
    );
    await tester.tap(find.text('Setup'));
    await tester.pumpAndSettle();
    expect(find.text('Create workspace'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  for (final kind in [
    LifeKind.goal,
    LifeKind.habit,
    LifeKind.routine,
    LifeKind.exercise,
    LifeKind.session,
    LifeKind.experiment,
    LifeKind.checkin,
    LifeKind.skill,
    LifeKind.life,
    LifeKind.template,
  ]) {
    testWidgets(
      '${kind.label} populated detail stays accessible at 200 percent text',
      (tester) async {
        final record = await tester.runAsync(() async {
          final exercise = (await c.createLife(
            LifeKind.exercise,
            'My exercise',
          ))!;
          final fields = <String, dynamic>{
            'date': '2026-10-21',
            'target': 5,
            'unit': 'minutes',
            if (kind == LifeKind.routine || kind == LifeKind.life)
              'items': [
                'A long but meaningful step that should wrap cleanly',
                'A second step',
              ],
            if (kind == LifeKind.template) 'templateFormat': 'note',
            if (kind == LifeKind.session)
              'sets': [
                {
                  'id': 'set-one',
                  'exerciseId': exercise.id,
                  'completed': false,
                  'weight': 25,
                  'reps': 6,
                  'distance': 0,
                  'seconds': 0,
                  'weightUnit': 'kg',
                  'distanceUnit': 'km',
                },
              ],
          };
          final o = (await c.createLife(
            kind,
            'Selected ${kind.name}',
            body: 'Writing with context and links.',
            fields: fields,
          ))!;
          if (kind == LifeKind.exercise) {
            await c.createLife(
              LifeKind.session,
              'Completed result',
              fields: {
                'date': '2026-10-20',
                'state': 'completed',
                'sets': [
                  {
                    'id': 'done',
                    'exerciseId': o.id,
                    'completed': true,
                    'weight': 20,
                    'reps': 4,
                    'weightUnit': 'kg',
                    'distanceUnit': 'km',
                  },
                ],
              },
            );
          }
          return o;
        });
        await host(
          tester,
          LifeWorkspace(controller: c),
          size: const Size(380, 760),
          scale: 2,
        );
        final chip = find.widgetWithText(ChoiceChip, kind.section).first;
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        final row = find.text(record!.title);
        await tester.scrollUntilVisible(
          row,
          250,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text('Back to ${kind.section}'), findsOneWidget);
        for (var i = 0; i < 5; i++) {
          await tester.drag(find.byType(ListView).last, const Offset(0, -450));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
  testWidgets(
    'clearing optional measurements removes the saved value and its trend sample',
    (tester) async {
      final entry = await tester.runAsync(
        () => c.createLife(
          LifeKind.checkin,
          'Check-in',
          fields: {'date': '2026-10-21', 'sleepHours': 7},
        ),
      );
      await host(
        tester,
        LifeRecordForm(
          controller: c,
          kind: LifeKind.checkin,
          object: entry,
          persist: true,
        ),
      );
      final field = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Sleep hours (optional, 0–24)',
      );
      await tester.enterText(field, '');
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(lifeData(c.find(entry!.id)!)['sleepHours'], isNull);
      expect(c.lifeIndex.series(LifeKind.checkin, 'sleepHours'), isEmpty);
    },
  );
}
