import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/sync_entry.dart';
import '../../domain/workspace_failure.dart';
import 'sync_provider.dart';
import 'sync_policy.dart';

class SyncResult {
  const SyncResult({
    required this.pending,
    required this.conflicts,
    required this.missing,
  });
  final int pending, conflicts, missing;
  bool get upToDate => pending == 0 && conflicts == 0 && missing == 0;
}

/// Provider-neutral reconciliation. No network operation owns local save success.
/// Each pass persists observations/outbox before publishing anything remotely.
class SyncEngine {
  SyncEngine({
    required this.replica,
    required this.provider,
    required this.stateStore,
  });
  final SyncReplica replica;
  final SyncProvider provider;
  final SyncStateStore stateStore;
  Future<SyncResult>? _running;

  Future<SyncResult> sync() {
    // Manual/foreground/autosync callers join the same pass.
    return _running ??= _run().whenComplete(() => _running = null);
  }

  Future<SyncResult> _run() async {
    if (replica.workspaceId != provider.workspaceId ||
        !provider.supportsConditionalPublication) {
      throw const WorkspaceFailure(
        'Sync identity or safe publication capability is unavailable.',
      );
    }
    final state =
        await stateStore.load() ??
        <String, dynamic>{
          'format': 'orbit-note-sync-state',
          'version': 1,
          'workspaceId': replica.workspaceId,
          'bindingId': provider.bindingId,
          'replicaId': const Uuid().v4(),
          'cursor': null,
          'base': <String, dynamic>{},
          'remote': <String, dynamic>{},
          'pending': <String, dynamic>{},
          'conflicts': <String, dynamic>{},
        };
    if (state['format'] != 'orbit-note-sync-state' ||
        state['version'] != 1 ||
        state['workspaceId'] != replica.workspaceId ||
        state['bindingId'] != provider.bindingId) {
      throw const WorkspaceFailure(
        'Sync state belongs to another Vault/provider or a newer protocol.',
      );
    }
    final base = Map<String, dynamic>.from(state['base'] as Map);
    final remote = Map<String, dynamic>.from(state['remote'] as Map);
    final pending = Map<String, dynamic>.from(state['pending'] as Map);
    final conflicts = Map<String, dynamic>.from(state['conflicts'] as Map);
    state.addAll({
      'base': base,
      'remote': remote,
      'pending': pending,
      'conflicts': conflicts,
    });
    var local = await replica.inventory();
    validateSyncEntries(local);
    // Local durable files plus this outbox survive an offline provider failure.
    for (final entry in local.entries) {
      final previous = base[entry.key] == null
          ? null
          : SyncEntry.fromJson(
              Map<String, dynamic>.from(base[entry.key] as Map),
            );
      if (!entry.value.sameAs(previous)) {
        final old = pending[entry.key] as Map?;
        final unchangedPending =
            old != null &&
            entry.value.sameAs(
              SyncEntry.fromJson(
                Map<String, dynamic>.from(old['entry'] as Map),
              ),
            );
        pending[entry.key] = {
          'operationId': unchangedPending
              ? old['operationId']
              : const Uuid().v4(),
          'entry': entry.value.toJson(),
        };
      } else {
        pending.remove(entry.key);
      }
    }
    await stateStore.save(state);
    final delta = await provider.fetchChanges(state['cursor'] as String?);
    if (delta.protocolVersion != 1) {
      throw const WorkspaceFailure(
        'This cloud Vault requires a newer sync protocol.',
      );
    }
    if (delta.reset) remote.clear();
    for (final key in delta.removedKeys) {
      remote.remove(key);
    }
    for (final item in delta.entries) {
      remote[item.entry.key] = item.toJson();
    }
    if (delta.entries.map((e) => e.entry.key).toSet().length !=
        delta.entries.length) {
      throw const WorkspaceConflict('Remote sync identities are ambiguous.');
    }
    validateSyncEntries({
      for (final item in remote.entries)
        item.key: RemoteSyncEntry.fromJson(
          Map<String, dynamic>.from(item.value as Map),
        ).entry,
    });
    validateSyncEntries({
      ...local,
      for (final item in remote.entries)
        item.key: RemoteSyncEntry.fromJson(
          Map<String, dynamic>.from(item.value as Map),
        ).entry,
    });
    // Do not acknowledge the cursor until every change below is durable.
    var missing = 0;
    int priority(String key) {
      final candidate = remote[key] == null
          ? local[key]
          : RemoteSyncEntry.fromJson(
              Map<String, dynamic>.from(remote[key] as Map),
            ).entry;
      if (candidate == null) return 2;
      if (candidate.deleted) return 2;
      return switch (syncPathRole(candidate.path)) {
        SyncPathRole.attachment => 0,
        SyncPathRole.manifest => 3,
        _ => 1,
      };
    }

    final keys = {...base.keys, ...local.keys, ...remote.keys}.toList()
      ..sort((a, b) {
        final order = priority(a).compareTo(priority(b));
        return order == 0 ? a.compareTo(b) : order;
      });
    for (final key in keys) {
      final previous = base[key] == null
          ? null
          : SyncEntry.fromJson(Map<String, dynamic>.from(base[key] as Map));
      var current = local[key];
      var other = remote[key] == null
          ? null
          : RemoteSyncEntry.fromJson(
              Map<String, dynamic>.from(remote[key] as Map),
            );
      var action = reconcileSyncEntry(
        base: previous,
        local: current,
        remote: other?.entry,
      );
      if (action == SyncAction.upload) {
        // Feed snapshots may be stale. Refresh before deciding and still require
        // atomic expectedVersion on upload to close the read/write race.
        other = await provider.inspect(key);
        if (other != null) validateSyncEntries({key: other.entry});
        action = reconcileSyncEntry(
          base: previous,
          local: current,
          remote: other?.entry,
        );
      }
      switch (action) {
        case SyncAction.unchanged:
        case SyncAction.acknowledge:
          if (current != null) base[key] = current.toJson();
          pending.remove(key);
          conflicts.remove(key);
        case SyncAction.upload:
          final operation = pending[key] as Map;
          final published = await provider.upload(
            current!,
            replica.read(current),
            operationId: operation['operationId'] as String,
            expectedVersion: other?.version,
          );
          if (!published.entry.sameAs(current)) {
            throw const WorkspaceFailure(
              'Provider did not acknowledge the expected content.',
            );
          }
          base[key] = current.toJson();
          remote[key] = published.toJson();
          pending.remove(key);
          conflicts.remove(key);
        case SyncAction.download:
          await replica.apply(
            other!.entry,
            provider.download(other),
            expected: current,
          );
          base[key] = other.entry.toJson();
          pending.remove(key);
          conflicts.remove(key);
        case SyncAction.conflict:
          final id = '${current!.hash}-${other!.entry.hash}';
          await replica.preserveConflict(
            id,
            current,
            other,
            provider.download(other),
          );
          conflicts[key] = {
            'id': id,
            'local': current.toJson(),
            'remote': other.toJson(),
          };
        case SyncAction.missing:
          missing++;
          conflicts[key] = {'reason': 'missing-without-tombstone'};
      }
      await stateStore.save(state);
    }
    state['cursor'] = delta.cursor;
    await stateStore.save(state);
    // A local edit during transfer must remain pending against the captured base.
    local = await replica.inventory();
    for (final entry in local.entries) {
      final previous = base[entry.key] == null
          ? null
          : SyncEntry.fromJson(
              Map<String, dynamic>.from(base[entry.key] as Map),
            );
      if (!entry.value.sameAs(previous)) {
        pending.putIfAbsent(
          entry.key,
          () => {
            'operationId': const Uuid().v4(),
            'entry': entry.value.toJson(),
          },
        );
      }
    }
    await stateStore.save(state);
    return SyncResult(
      pending: pending.length,
      conflicts: conflicts.length,
      missing: missing,
    );
  }
}
