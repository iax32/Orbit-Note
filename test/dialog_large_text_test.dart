import 'support/settings_navigation.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/application/backup_bundle.dart';
import 'package:orbit_note/features/workspace/backup_import_dialog.dart';
import 'package:orbit_note/features/workspace/theme_color_settings.dart';
import 'package:orbit_note/features/workspace/theme_interchange_dialog.dart';
import 'package:orbit_note/features/workspace/harmonized_palette_dialog.dart';
import 'package:orbit_note/features/notes/document_history_dialog.dart';
import 'package:orbit_note/features/workspace/recovery_dialog.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

import 'support/memory_store.dart';

void main() {
  late WorkspaceController controller;
  late MemoryStore store;

  setUp(() async {
    store = MemoryStore();
    controller = WorkspaceController()
      ..repository = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
    await controller.initialize();
    controller.session.motion = 'off';
  });
  tearDown(() async {
    controller.cancelAllTimers();
  });

  Future<void> mount(
    WidgetTester tester,
    Size size,
    Widget child, {
    double textScale = 2.5,
  }) async {
    addTearDown(() async {
      controller.cancelAllTimers();
      final closing = controller.closeWorkspace();
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await closing;
    });
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
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final size in [const Size(320, 640), const Size(568, 320)]) {
    testWidgets(
      'backup review shows every notice and preserves consent at $size',
      (tester) async {
        final manifest = {
          'format': 'orbit-note-workspace',
          'version': 1,
          'id': 'test-vault',
          'name': 'A long workspace name retained from a backup',
        };
        final bundle = BackupBundle.parse(
          jsonEncode({
            'format': 'orbit-note-backup',
            'version': 1,
            'encoding': 'base64',
            'workspaceId': 'test-vault',
            'files': {
              'workspace.json': base64Encode(utf8.encode(jsonEncode(manifest))),
              for (var i = 0; i < 7; i++)
                'Notes/retained-original-$i.md': base64Encode(
                  utf8.encode('invalid object metadata'),
                ),
            },
          }),
        );
        expect(bundle.warnings.length, 7);
        bool? result;
        await mount(
          tester,
          size,
          Builder(
            builder: (context) => TextButton(
              child: const Text('Review backup'),
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (_) => BackupImportDialog(bundle: bundle),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('Review backup'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
        await Scrollable.ensureVisible(
          tester.element(find.text(bundle.warnings.last)),
          alignment: .5,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(result, isFalse);
        await tester.tap(find.text('Review backup'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.text('Choose folder'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(result, isTrue);
      },
    );

    testWidgets('theme dialogs reflow at $size with 250% text', (tester) async {
      await mount(
        tester,
        size,
        Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () =>
                    showOrbitThemeGalleryDialog(context, controller),
                child: const Text('Gallery'),
              ),
              TextButton(
                onPressed: () => showOrbitThemeExportDialog(
                  context,
                  controller,
                  exportFn: (_, _) async => false,
                ),
                child: const Text('Export'),
              ),
              TextButton(
                onPressed: () =>
                    showHarmonizedPaletteDialog(context, controller),
                child: const Text('Generate'),
              ),
              TextButton(
                onPressed: () => showOrbitThemeImportDialog(
                  context,
                  controller,
                  directJsonContent: jsonEncode(
                    OrbitThemePack.builtIn.first.toJson(),
                  ),
                ),
                child: const Text('Import'),
              ),
            ],
          ),
        ),
      );
      for (final action in ['Gallery', 'Export', 'Generate', 'Import']) {
        await tester.tap(find.text(action));
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull, reason: action);
        // Build and inspect the complete scroll surface, including preview controls.
        final dialogScroll = find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.drag(dialogScroll, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull, reason: action);
        await tester.tap(find.text(action == 'Gallery' ? 'Close' : 'Cancel'));
        await tester.pump(const Duration(milliseconds: 350));
      }
    });
    testWidgets('history selection and preview at $size with 250% text', (
      tester,
    ) async {
      final note = (await tester.runAsync(
        () => controller.create(
          'orbit.note',
          title: 'A long document title for a revision checkpoint',
          body: 'Original draft',
        ),
      ))!;
      await tester.runAsync(
        () => controller.createDocumentSnapshot(
          note.id,
          label: 'Before substantial changes to the original draft',
        ),
      );
      await mount(
        tester,
        size,
        DocumentHistoryDialog(
          controller: controller,
          objectId: note.id,
          currentTitle: note.title,
          currentBody: 'Updated draft',
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('snapshot-item-0')));
      await tester.tap(find.byKey(const ValueKey('snapshot-item-0')));
      await tester.ensureVisible(find.text('Preview'));
      await tester.tap(find.text('Preview'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Original draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('restore-snapshot-button')),
      );
      await tester.tap(find.byKey(const ValueKey('restore-snapshot-button')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(controller.find(note.id)!.body, 'Original draft');
    });

    testWidgets('recovery preview and byte-preserving export at $size', (
      tester,
    ) async {
      const path =
          '.orbit/recovery/a-very-long-retained-document-recovery-copy.json';
      final bytes = Uint8List.fromList(
        utf8.encode('Retained original contents'),
      );
      store.files[path] = bytes;
      Uint8List? exported;
      await mount(
        tester,
        size,
        WorkspaceRecoveryDialog(
          repository: controller.repository,
          exportCopy: (_, data) async {
            exported = data;
            return false;
          },
        ),
      );
      expect(tester.takeException(), isNull);
      await Scrollable.ensureVisible(
        tester.element(find.text(path)),
        alignment: .5,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text(path));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
      expect(find.text('Retained original contents'), findsOneWidget);
      await tester.tap(find.text('Export a copy'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(exported, orderedEquals(bytes));
      expect(store.files[path], orderedEquals(bytes));
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings controls remain usable at $size with 250% text', (
      tester,
    ) async {
      await mount(
        tester,
        size,
        SettingsView(
          controller: controller,
          onExport: () {},
          onImport: () {},
          onOpenWorkspace: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      await searchSettings(tester, 'default document format');
      final dropdown = find.byKey(
        const ValueKey('settings-default-format-dropdown'),
      );
      await tester.scrollUntilVisible(
        dropdown,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('settings-content')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(tester.element(dropdown), alignment: .5);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.tap(dropdown);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('LaTeX Document').last);
      await tester.pump(const Duration(milliseconds: 350));
      expect(controller.session.defaultDocumentFormat, 'latex');
      await searchSettings(tester, 'Workspace data');
      await tester.scrollUntilVisible(
        find.text('Import backup'),
        400,
        maxScrolls: 200,
        scrollable: find
            .descendant(
              of: find.byType(SettingsView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('snapshot label editor remains usable at 320% with keyboard', (
    tester,
  ) async {
    final note = (await tester.runAsync(
      () => controller.create(
        'orbit.note',
        title: 'Document history',
        body: 'Current draft',
      ),
    ))!;
    await mount(
      tester,
      const Size(320, 640),
      DocumentHistoryDialog(
        controller: controller,
        objectId: note.id,
        currentTitle: note.title,
        currentBody: note.body,
      ),
      textScale: 3.2,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('create-snapshot-button'))),
      alignment: .5,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-snapshot-button')));
    await tester.pump(const Duration(milliseconds: 350));
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'Before major refactor');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Save Snapshot'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      controller.getDocumentSnapshots(note.id).single['label'],
      'Before major refactor',
    );
    expect(controller.find(note.id)!.body, 'Current draft');
    expect(tester.takeException(), isNull);
  });

  testWidgets('color validation and actions survive keyboard insets', (
    tester,
  ) async {
    await mount(
      tester,
      const Size(320, 640),
      SingleChildScrollView(child: ThemeColorSettings(controller: controller)),
    );
    await tester.tap(find.text('Customize interface colors'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final role = find.byKey(const ValueKey('theme-color-background'));
    await Scrollable.ensureVisible(tester.element(role), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(role);
    await tester.pump(const Duration(milliseconds: 350));
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump(const Duration(milliseconds: 350));
    final input = find.byKey(const ValueKey('theme-color-hex'));
    await Scrollable.ensureVisible(tester.element(input), alignment: .5);
    await tester.pump();
    await tester.enterText(input, 'bad');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('theme-color-apply')))
          .onPressed,
      isNull,
    );
    await tester.enterText(input, '123456');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('theme-color-apply')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.session.colorOverrides['background'], 0xff123456);
    expect(tester.takeException(), isNull);
    controller.cancelAllTimers();
  });
}
