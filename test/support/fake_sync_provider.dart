import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:orbit_note/application/sync/sync_provider.dart';
import 'package:orbit_note/domain/sync_entry.dart';
import 'package:orbit_note/domain/workspace_failure.dart';

/// One simulated server shared by any number of independently persisted replicas.
class FakeSyncProvider implements SyncProvider {
  FakeSyncProvider(this.workspaceId);
  @override
  final String workspaceId;
  @override
  String get bindingId => 'fake:account:$workspaceId';
  @override
  bool supportsConditionalPublication = true;
  bool offline = false, failAfterUpload = false;
  int generation = 0, uploads = 0, fetches = 0;
  final records = <String, RemoteSyncEntry>{};
  final bytes = <String, Uint8List>{};
  final operations = <String, RemoteSyncEntry>{};
  final removals = <String, int>{};

  void _online() {
    if (offline) throw const WorkspaceFailure('Offline');
  }

  @override
  Future<SyncDelta> fetchChanges(String? cursor) async {
    _online();
    fetches++;
    final after = cursor == null ? 0 : int.parse(cursor);
    return SyncDelta(
      entries: records.values
          .where((e) => int.parse(e.version) > after)
          .toList(),
      removedKeys: removals.keys.where((k) => removals[k]! > after).toSet(),
      cursor: '$generation',
      reset: cursor == null,
    );
  }

  @override
  Future<RemoteSyncEntry?> inspect(String key) async {
    _online();
    return records[key];
  }

  @override
  Stream<List<int>> download(RemoteSyncEntry entry) async* {
    _online();
    if (records[entry.entry.key]?.version != entry.version) {
      throw const WorkspaceConflict('Remote version changed before download');
    }
    yield Uint8List.fromList(bytes[entry.entry.key]!);
  }

  @override
  Future<RemoteSyncEntry> upload(
    SyncEntry entry,
    Stream<List<int>> source, {
    required String operationId,
    required String? expectedVersion,
  }) async {
    _online();
    final data = Uint8List.fromList(
      await source.expand((chunk) => chunk).toList(),
    );
    if (sha256.convert(data).toString() != entry.hash) {
      throw const WorkspaceConflict('Upload hash mismatch');
    }
    final prior = operations[operationId];
    if (prior != null) {
      if (!prior.entry.sameAs(entry)) {
        throw const WorkspaceConflict(
          'Operation ID reused for different content',
        );
      }
      return prior;
    }
    if (records[entry.key]?.version != expectedVersion) {
      throw const WorkspaceConflict('Remote conditional publication failed');
    }
    final next = RemoteSyncEntry(
      entry,
      records[entry.key]?.remoteId ?? 'file:${entry.key}',
      '${++generation}',
    );
    records[entry.key] = next;
    bytes[entry.key] = data;
    operations[operationId] = next;
    removals.remove(entry.key);
    uploads++;
    if (failAfterUpload) {
      failAfterUpload = false;
      throw const WorkspaceFailure('Connection lost after server committed');
    }
    return next;
  }

  void removeOutsideOrbit(String key) {
    records.remove(key);
    bytes.remove(key);
    removals[key] = ++generation;
  }
}
