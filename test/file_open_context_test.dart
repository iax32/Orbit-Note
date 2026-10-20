import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/main.dart';
import 'package:orbit_note/features/files/code_file_preview.dart';
import 'support/memory_store.dart';

class ContextStore extends MemoryStore {
  String selected = 'one';
  final vaults = <String, Map<String, Uint8List>>{};
  final reads = <(String, String)>[];
  @override
  String get location => selected;
  @override
  Future<void> initialize({String? path}) async {
    if (path != null && path != selected) {
      vaults[selected] = Map.of(files);
      selected = path;
      files
        ..clear()
        ..addAll(vaults[path] ?? {});
    }
  }

  @override
  Future<Uint8List?> read(String path) async {
    reads.add((selected, path));
    return super.read(path);
  }
}

void main() {
  for (final change in ['vault', 'trash', 'attachment']) {
    testWidgets(
      change == 'vault'
          ? 'external-open consent cannot read a new Vault after switching'
          : change == 'trash'
          ? 'external-open consent cannot open a source trashed while confirming'
          : 'external-open consent retires when attachment bytes are invalidated',
      (t) async {
        final store = ContextStore();
        final repo = WorkspaceRepository(
          store: store,
          index: MemoryObjectIndex(),
        );
        var launches = 0;
        const channel = MethodChannel('plugins.flutter.io/url_launcher');
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          launches++;
          return false;
        });
        addTearDown(
          () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        t.view.physicalSize = const Size(1400, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repo)],
            child: const OrbitNoteApp(),
          ),
        );
        await t.pumpAndSettle();
        final c = ProviderScope.containerOf(
          t.element(find.byType(OrbitNoteApp)),
        ).read(workspaceProvider.notifier);
        final source = await c.importProjectAttachment(
          'synthetic.exe',
          Uint8List.fromList([1, 2, 3]),
        );
        c.openObject(source.id);
        c.cancelAllTimers();
        c.pausePdfIndex(true);
        await t.pumpAndSettle();
        final open = find.widgetWithText(TextButton, 'Open original');
        await t.ensureVisible(open);
        await t.tap(open);
        await t.pumpAndSettle();
        expect(find.text('Open this file externally?'), findsOneWidget);
        if (change == 'vault') {
          c.cancelAllTimers();
          await repo.initialize(path: 'two');
          c.mergeRepositoryObjects();
          c.notify();
        } else if (change == 'trash') {
          await c.trash(source.id);
        } else {
          c.attachmentRevision++;
          c.notify();
        }
        await t.pumpAndSettle();
        store.reads.clear();
        await t.tap(find.widgetWithText(FilledButton, 'Open file'));
        await t.pumpAndSettle();
        expect(
          store.reads.where((r) => r.$2.startsWith('Attachments/')),
          isEmpty,
        );
        expect(launches, 0);
        c.cancelAllTimers();
        await c.flushAll();
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'attachment invalidation refreshes visible source with unchanged metadata',
    (t) async {
      final store = ContextStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: const OrbitNoteApp(),
        ),
      );
      await t.pumpAndSettle();
      final c = ProviderScope.containerOf(
        t.element(find.byType(OrbitNoteApp)),
      ).read(workspaceProvider.notifier);
      final source = await c.importProjectAttachment(
        'watch.cpp',
        Uint8List.fromList(utf8.encode('before\r\n')),
      );
      c.openObject(source.id);
      c.cancelAllTimers();
      await t.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(CodeFilePreview),
        matching: find.byType(TextField),
      );
      expect(t.widget<TextField>(field).controller!.text, 'before\r\n');
      store.files[source.properties['contentRef'] as String] =
          Uint8List.fromList(utf8.encode('after\r\n'));
      c.attachmentRevision++;
      c.notify();
      await t.pumpAndSettle();
      expect(t.widget<TextField>(field).controller!.text, 'after\r\n');
      expect(
        c.find(source.id)!.properties['checksum'],
        source.properties['checksum'],
      );
      c.cancelAllTimers();
      await c.flushAll();
      await t.pumpWidget(const SizedBox());
    },
  );
}
