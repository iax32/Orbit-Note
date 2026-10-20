import '../../domain/sync_entry.dart';

class RemoteSyncEntry {
  const RemoteSyncEntry(this.entry, this.remoteId, this.version);
  final SyncEntry entry;
  final String remoteId, version;
  Map<String, dynamic> toJson() => {
    'entry': entry.toJson(),
    'id': remoteId,
    'version': version,
  };
  factory RemoteSyncEntry.fromJson(Map<String, dynamic> value) =>
      RemoteSyncEntry(
        SyncEntry.fromJson(Map<String, dynamic>.from(value['entry'] as Map)),
        value['id'] as String,
        value['version'] as String,
      );
}

class SyncDelta {
  const SyncDelta({
    required this.entries,
    required this.removedKeys,
    required this.cursor,
    this.reset = false,
    this.protocolVersion = 1,
    this.forks = const {},
  });
  final int protocolVersion;
  final List<RemoteSyncEntry> entries;
  final Set<String> removedKeys;
  final String cursor;
  final bool reset;
  final Map<String, List<RemoteSyncEntry>> forks;
}

/// Publications never overwrite prior bytes. Concurrent children remain visible
/// as forks, including races after an expected-head check. See ADR-0030.
abstract interface class ImmutableRevisionSyncProvider implements SyncProvider {
  Future<RemoteSyncEntry> publishResolution(
    SyncEntry entry,
    Stream<List<int>> bytes, {
    required String operationId,
    required List<String> parents,
  });
}

/// The first engine requires atomic conditional publication. A provider must
/// prove this capability, not emulate it with GET followed by an unchecked PUT.
abstract interface class SyncProvider {
  String get bindingId; // Provider + account + remote Vault, never a token.
  String get workspaceId;
  bool get supportsConditionalPublication;
  Future<SyncDelta> fetchChanges(String? cursor);
  Future<RemoteSyncEntry?> inspect(String key);
  Stream<List<int>> download(RemoteSyncEntry entry);
  Future<RemoteSyncEntry> upload(
    SyncEntry entry,
    Stream<List<int>> bytes, {
    required String operationId,
    required String? expectedVersion,
  });
}

/// Implementations stage/verify streams and apply through normal repository
/// commands. Dirty drafts, changed hashes and Vault switches must reject apply.
abstract interface class SyncReplica {
  String get workspaceId;
  Future<Map<String, SyncEntry>> inventory();
  Stream<List<int>> read(SyncEntry expected);
  Future<void> apply(
    SyncEntry incoming,
    Stream<List<int>> bytes, {
    required SyncEntry? expected,
  });
  Future<void> preserveConflict(
    String conflictId,
    SyncEntry? local,
    RemoteSyncEntry remote,
    Stream<List<int>> remoteBytes,
  );
}

abstract interface class SyncStateStore {
  Future<Map<String, dynamic>?> load();

  /// A successful return means the state is durable. Serialize/CAS writers.
  Future<void> save(Map<String, dynamic> state);
}
