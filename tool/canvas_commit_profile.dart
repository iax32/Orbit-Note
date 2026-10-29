// Local-only CPU/save handoff probe. No Vault writer, provider or account.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:orbit_note/application/sync/sync_inventory.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/infrastructure/storage/object_codec.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('Supply an isolated board fixture.');
  }
  final codec = ObjectCodec();
  final previousSource = await File(args.single).readAsString();
  var object = codec.decode(previousSource, 'local-probe', markdown: false);
  final previousObject = object;
  final scene = CanvasScene.fromJson(object.data);
  final results = <Map<String, Object>>[];
  Future<void> stage(String name, Future<void> Function() work) async {
    final clock = Stopwatch()..start();
    var last = 0, gap = 0, ticks = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
      final now = clock.elapsedMicroseconds;
      if (now - last > gap) gap = now - last;
      last = now;
      ticks++;
    });
    await work();
    final duration = clock.elapsedMicroseconds;
    await Future<void>.delayed(const Duration(milliseconds: 4));
    timer.cancel();
    results.add({
      'stage': name,
      'us': duration,
      'maxLoopGapUs': gap,
      'ticks': ticks,
    });
  }

  final commits = Stopwatch()..start();
  for (var i = 0; i < 20; i++) {
    scene.put(
      CanvasElement(
        immutableObjectData({
          'id': 'local-$i',
          'type': 'ink',
          'x': 0.0,
          'y': 0.0,
          'points': [
            for (var p = 0; p < 200; p++)
              {'x': p * .5, 'y': p % 4 * 1.0, 'pressure': .6},
          ],
        }),
      ),
    );
    object = object.copyWith(data: scene.snapshotJson());
  }
  commits.stop();
  await stage(
    'idle',
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  for (var i = 0; i < 3; i++) {
    await stage('encode-$i', () async {
      await codec.encodeForSave(
        object,
        previousObject: previousObject,
        previousSource: previousSource,
      );
    });
  }
  final bytes = (await codec.encodeForSave(
    object,
    previousObject: previousObject,
    previousSource: previousSource,
  )).bytes;
  await stage('hash', () async {
    await codec.hashBytes(bytes);
  });
  await stage('decode', () async {
    await codec.decodeForLoad(bytes, 'local-probe', markdown: false);
  });
  final store = _ProbeStore({
    'workspace.json': Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'orbit-note-workspace',
          'version': 1,
          'id': 'local-probe',
        }),
      ),
    ),
    'Boards/profile.board.json': bytes,
  });
  final hash = await codec.hashBytes(bytes);
  for (final cached in [false, true]) {
    await stage(
      cached ? 'sync-inventory-cached' : 'sync-inventory-cold',
      () async {
        final inventory = await captureSyncInventory(
          store,
          'local-probe',
          knownObjects: cached
              ? {'Boards/profile.board.json': (hash: hash, object: object)}
              : const {},
        );
        if (!inventory.ready) throw StateError('Probe inventory is not ready.');
      },
    );
  }
  await stage('previous-sync-main-thread-work', () async {
    sha256.convert(bytes);
    codec.decode(utf8.decode(bytes), 'local-probe', markdown: false);
  });
  await codec.close();
  stdout.writeln(
    jsonEncode({
      'commitsUs': commits.elapsedMicroseconds,
      'bytes': bytes.length,
      'stages': results,
    }),
  );
}

class _ProbeStore implements WorkspaceStore {
  _ProbeStore(this.files);
  final Map<String, Uint8List> files;
  @override
  String get location => 'Local read-only probe';
  @override
  bool get isBrowser => false;
  @override
  Future<void> initialize({String? path}) async {}
  @override
  Future<List<String>> listFiles() async => files.keys.toList();
  @override
  Future<Uint8List?> read(String path) async => files[path];
  @override
  Future<void> write(
    String path,
    Uint8List bytes, {
    required String? expectedHash,
  }) async => throw UnsupportedError('Read-only probe.');
  @override
  Future<void> deleteFile(String path, {required String? expectedHash}) async =>
      throw UnsupportedError('Read-only probe.');
  @override
  Future<void> close() async {}
}
