import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/research_dossier.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/research_dossier_workspace.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'support/capture_ui.dart';
import 'research_dossier_test.dart' show draft;

void main() {
  late MemoryStore store;
  late ProviderContainer container;
  late WorkspaceController c;
  late UniversalObject root;
  setUp(() async {
    store = MemoryStore();
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(
          WorkspaceRepository(store: store, index: MemoryObjectIndex()),
        ),
      ],
    );
    c = container.read(workspaceProvider.notifier);
    await c.initialize();
    root = (await c.saveDossierRecord(
      title: 'Example game',
      data: draft('dossier'),
    ))!;
  });
  tearDown(() {
    c.cancelAllTimers();
    container.dispose();
  });
  Future<void> mount(
    WidgetTester t, {
    Size size = const Size(1400, 1000),
    double scale = 1,
    UniversalObject? edit,
  }) async {
    await t.binding.setSurfaceSize(size);
    addTearDown(() => t.binding.setSurfaceSize(null));
    await prepareCapture(t);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: orbitTheme(preset: 'paper'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => edit == null
                    ? showResearchDossier(context, c)
                    : showDossierEditor(
                        context,
                        c,
                        kind: dossierData(edit)['kind'],
                        rootId: root.id,
                        previous: edit,
                      ),
                child: const Text('Open research'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open research'));
    await t.pumpAndSettle();
  }

  Future<void> save(WidgetTester t) async {
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Save research'));
    await t.runAsync(() async {
      await t.tap(find.widgetWithText(FilledButton, 'Save research'));
      await c.flushAll();
    });
    await t.pumpAndSettle();
  }

  testWidgets(
    'dossier navigation, filtering and template creation work at enlarged narrow text',
    (t) async {
      await mount(t, size: const Size(390, 844), scale: 2);
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.byTooltip('Research templates'));
      await t.tap(find.byTooltip('Research templates'));
      await t.pumpAndSettle();
      await t.tap(find.text('Inventory system'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
      await save(t);
      expect(c.objects.any((o) => o.title == 'Inventory system'), isTrue);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'structure row editing preserves unknown row data and failed saves retain draft',
    (t) async {
      final record = (await t.runAsync(
        () => c.saveDossierRecord(
          title: 'Player layout',
          data: {
            ...draft('structure', root: root.id),
            'rows': [
              {
                'offset': '0x20',
                'size': '4',
                'name': 'health',
                'type': 'float',
                'explanation': 'Suspected',
                'future': {'retained': true},
              },
            ],
          },
        ),
      ))!;
      await mount(t, edit: record);
      await t.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Player layout revised',
      );
      await t.ensureVisible(find.widgetWithText(TextField, 'explanation'));
      await t.enterText(
        find.widgetWithText(TextField, 'explanation'),
        'Observed field',
      );
      store.failWrites = true;
      await save(t);
      expect(find.text('Player layout revised'), findsOneWidget);
      expect(c.find(record.id)!.title, 'Player layout');
      store.failWrites = false;
      await save(t);
      expect(c.find(record.id)!.title, 'Player layout revised');
      expect(
        dossierRows(dossierData(c.find(record.id)!), 'rows').single['future'],
        {'retained': true},
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'function dossier presents relationships, build warnings and history',
    (t) async {
      await t.runAsync(() async {
        final layout = (await c.saveDossierRecord(
          title: 'Player object',
          data: draft('structure', root: root.id),
        ))!;
        await c.saveDossierRecord(
          title: 'Read player health',
          data: {
            ...draft('function', root: root.id, build: 'old-build'),
            'prototype': 'float readHealth(Player* player)',
            'convention': 'x64',
            'rows': [
              {
                'address': '0x140001000',
                'instruction': 'movss xmm0, [rcx+0x20]',
                'explanation': 'Observed load; meaning is a hypothesis',
                'branch': 'return',
              },
            ],
            'links': [
              {'id': layout.id, 'role': 'field', 'offset': '+0x20'},
            ],
          },
        );
      });
      await mount(t);
      await t.tap(find.text('Read player health'));
      await t.pumpAndSettle();
      await captureUi(
        t,
        'research-dossier',
        target: find.byKey(const ValueKey('dossier-capture')),
      );
      expect(find.textContaining('Needs rechecking'), findsOneWidget);
      expect(find.text('Copy live summary'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
