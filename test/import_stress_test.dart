import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/main.dart';
import 'support/memory_store.dart';

class SwitchingStore extends FolderMemoryStore {
  String selected = 'one';
  final vaults = <String, Map<String, Uint8List>>{};
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
}

class DelayedDrop extends DropItemFile {
  DelayedDrop(this.gate, this.fileName)
    : super.fromData(Uint8List.fromList([1, 2, 3]), name: fileName);
  final Completer<Uint8List> gate;
  final String fileName;
  @override
  String get name => fileName;
  @override
  String get path => fileName;
  @override
  Future<int> length() async => 3;
  @override
  Future<Uint8List> readAsBytes() => gate.future;
}

void main() {
  test('queued import cannot land in a newly initialized Vault', () async {
    final store = SwitchingStore();
    final repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    addTearDown(repo.close);
    await repo.initialize();
    final switching = repo.initialize(path: 'two');
    final import = repo.importAttachment(
      name: 'old.bin',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    final refused = expectLater(import, throwsA(isA<Exception>()));
    await switching;
    await refused;
    expect(repo.objects.where((o) => o.typeId == 'orbit.file'), isEmpty);
  });
  test(
    'attachment hashing and storage use an owned byte snapshot while queued',
    () async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      addTearDown(repo.close);
      await repo.initialize();
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final original = Uint8List.fromList(bytes);
      final importing = repo.importAttachment(name: 'source.bin', bytes: bytes);
      bytes.fillRange(0, bytes.length, 99);
      final object = await importing;
      expect(
        await repo.readAttachment(object.properties['contentRef'] as String),
        original,
      );
      expect(
        object.properties['checksum'],
        sha256.convert(original).toString(),
      );
    },
  );

  Future<WorkspaceController> app(
    WidgetTester tester,
    WorkspaceRepository repo,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: const OrbitNoteApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(OrbitNoteApp)),
    ).read(workspaceProvider.notifier);
  }

  DropDoneDetails details(DelayedDrop file) => DropDoneDetails(
    files: [file],
    localPosition: Offset.zero,
    globalPosition: Offset.zero,
  );

  testWidgets(
    'a delayed Explorer drop refuses capture after switching Vaults',
    (tester) async {
      final store = SwitchingStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      final c = await app(tester, repo);
      final before = repo.workspaceId;
      final gate = Completer<Uint8List>();
      tester
          .widget<DropTarget>(
            find.byKey(const ValueKey('explorer-drop-target')).first,
          )
          .onDragDone!(details(DelayedDrop(gate, 'OldVault.bin')));
      await tester.pump();
      await repo.initialize(path: 'two');
      c.mergeRepositoryObjects();
      c.notify();
      await tester.pumpAndSettle();
      expect(repo.workspaceId, isNot(before));
      gate.complete(Uint8List.fromList([1, 2, 3]));
      await tester.pumpAndSettle();
      expect(c.objects.where((o) => o.title == 'OldVault.bin'), isEmpty);
      await c.flushAll();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'delayed note drop computes link from the captured target folder',
    (tester) async {
      final store = SwitchingStore()..folderList.add('Notes/Deep');
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      final c = await app(tester, repo);
      final a = (await c.create(
        'orbit.note',
        title: 'Target',
        properties: {'folder': 'Notes/Deep'},
      ))!;
      final b = (await c.create('orbit.note', title: 'Other'))!;
      c.openObject(a.id);
      await tester.pumpAndSettle();
      final gate = Completer<Uint8List>();
      tester
          .widget<DropTarget>(find.byKey(const ValueKey('content-drop-target')))
          .onDragDone!(details(DelayedDrop(gate, 'Evidence.txt')));
      await tester.pump();
      c.openObject(b.id);
      await tester.pumpAndSettle();
      gate.complete(Uint8List.fromList([1, 2, 3]));
      await tester.pumpAndSettle();
      final attachment = c.objects.singleWhere(
        (o) => o.title == 'Evidence.txt',
      );
      final relative = p.posix.relative(
        attachment.properties['contentRef'] as String,
        from: p.posix.dirname(repo.objectPath(a.id)!),
      );
      expect(c.find(a.id)!.body, contains('(<$relative>)'));
      expect(c.find(b.id)!.body, isNot(contains('Evidence')));
      await c.flushAll();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed Canvas file read does not abort the remaining drop batch',
    (tester) async {
      final repo = WorkspaceRepository(
        store: SwitchingStore(),
        index: MemoryObjectIndex(),
      );
      final c = await app(tester, repo);
      final board = (await c.create('orbit.canvas', title: 'Board'))!;
      c.openObject(board.id);
      await tester.pumpAndSettle();
      final bad = Completer<Uint8List>(), good = Completer<Uint8List>();
      tester
          .widget<DropTarget>(find.byKey(const ValueKey('content-drop-target')))
          .onDragDone!(
        DropDoneDetails(
          files: [DelayedDrop(bad, 'Bad.txt'), DelayedDrop(good, 'Good.txt')],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();
      bad.completeError(StateError('Read failed'));
      good.complete(Uint8List.fromList([7, 8, 9]));
      await tester.pumpAndSettle();
      expect(c.objects.where((o) => o.title == 'Good.txt'), hasLength(1));
      expect(c.find(board.id)!.data['elements'], hasLength(1));
      expect(tester.takeException(), isNull);
      await c.flushAll();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'trash during delayed drop cannot append content to a deleted note',
    (tester) async {
      final repo = WorkspaceRepository(
        store: SwitchingStore(),
        index: MemoryObjectIndex(),
      );
      final c = await app(tester, repo);
      final note = (await c.create('orbit.note', title: 'Target'))!;
      c.openObject(note.id);
      await tester.pumpAndSettle();
      final gate = Completer<Uint8List>();
      tester
          .widget<DropTarget>(find.byKey(const ValueKey('content-drop-target')))
          .onDragDone!(details(DelayedDrop(gate, 'Late.txt')));
      await tester.pump();
      await c.trash(note.id);
      await tester.pumpAndSettle();
      final before = c.find(note.id)!.body;
      gate.complete(Uint8List.fromList([1, 2, 3]));
      await tester.pumpAndSettle();
      expect(c.find(note.id)!.body, before);
      expect(c.find(note.id)!.isDeleted, isTrue);
      await c.flushAll();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
