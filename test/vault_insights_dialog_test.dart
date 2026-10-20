import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/workspace/vault_insights_dialog.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  testWidgets(
    'large-text insights refresh, navigate and copy only aggregate diagnostics',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize(path: 'test');
      final note = await repo.create(
        typeId: 'orbit.note',
        title: 'Private title',
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.read(workspaceProvider);
      final c = container.read(workspaceProvider.notifier);
      await tester.runAsync(() async {
        while (c.loading) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      });
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => VaultInsightsDialog(controller: c),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Copy diagnostic counts'));
      await tester.pumpAndSettle();
      expect(copied, contains('"objects": 1'));
      expect(copied, isNot(contains(note.id)));
      expect(copied, isNot(contains('Private title')));
      c.edit(note.id, body: 'An unsaved draft');
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy diagnostic counts'));
      await tester.pumpAndSettle();
      expect(copied, contains('"unsavedObjects": 1'));
      await tester.scrollUntilVisible(
        find.text('Isolated notes'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Isolated notes'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Private title'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Private title'));
      await tester.pumpAndSettle();
      expect(c.session.activeId, note.id);
      expect(find.text('Vault Insights'), findsNothing);
      container.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
