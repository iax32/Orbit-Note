import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/main.dart';
import 'package:orbit_note/platform/android_vault_folders.dart';
import 'support/memory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('orbit_note/vault_folders');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'folder import returns a local path and cancellation remains cancellation',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'importFolder');
        return '/data/user/0/org.orbitnote.app/files/vaults/imported';
      });
      expect(await importAndroidVaultFolder(), startsWith('/data/'));
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      expect(await importAndroidVaultFolder(), isNull);
    },
  );

  test(
    'provider errors and invalid paths are reported rather than treated as cancel',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'vault_import',
          message: 'Android denied folder access.',
        );
      });
      await expectLater(
        importAndroidVaultFolder(),
        throwsA(isA<PlatformException>()),
      );
      for (final path in [
        '',
        'content://documents/tree/123',
        'relative/path',
      ]) {
        messenger.setMockMethodCallHandler(channel, (_) async => path);
        await expectLater(importAndroidVaultFolder(), throwsFormatException);
      }
    },
  );

  testWidgets(
    'Android folder flow explains local copy, shows provider failure and permits retry',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      t.view.physicalSize = const Size(1000, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = MemoryStore()..failAllInitializations = true;
      final repository = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      var picks = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        picks++;
        if (picks == 1) {
          throw PlatformException(
            code: 'vault_import',
            message: 'Android denied folder access.',
          );
        }
        return null;
      });
      await t.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repository)],
          child: const OrbitNoteApp(),
        ),
      );
      await t.pumpAndSettle();
      final controller = ProviderScope.containerOf(
        t.element(find.byType(OrbitNoteApp)),
      ).read(workspaceProvider.notifier);
      controller.cancelAllTimers();
      await t.tap(find.text('Import Vault folder'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('original folder stays unchanged'),
        findsOneWidget,
      );
      await t.tap(find.text('Choose Vault folder'));
      await t.pumpAndSettle();
      expect(find.text('Android denied folder access.'), findsOneWidget);
      expect(find.text('Importing Vault'), findsNothing);
      expect(controller.hasWorkspace, isFalse);
      await t.tap(find.text('Import Vault folder'));
      await t.pumpAndSettle();
      await t.tap(find.text('Choose Vault folder'));
      await t.pumpAndSettle();
      expect(picks, 2);
      expect(find.text('Importing Vault'), findsNothing);
      expect(controller.hasWorkspace, isFalse);
      expect(t.takeException(), isNull);
      controller.cancelAllTimers();
      await t.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
