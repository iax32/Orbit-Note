import 'dart:async';
import 'dart:convert';

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

  /// Explicit resolution retains old cloud revisions and ordinary local history.
  /// The durable operation ID makes a lost publication acknowledgement retryable.
  Future<SyncResult> resolve(
    String key, {
    String? remoteVersion,
    String? expectedLocalHash,
  }) {
    if (_running != null) {
      throw StateError('Wait for the current sync to finish.');
    }
    return _running = _resolve(
      key,
      remoteVersion,
      expectedLocalHash,
    ).whenComplete(() => _running = null);
  }

  Future<SyncResult> _resolve(
    String key,
    String? remoteVersion,
    String? expectedLocalHash,
  ) async {
    final target = provider;
    if (target is! ImmutableRevisionSyncProvider) {
      throw const WorkspaceFailure(
        'This provider needs another resolution workflow.',
      );
    }
    final state = await stateStore.load();
    if (state == null ||
        state['format'] != 'orbit-note-sync-state' ||
        state['version'] != 1 ||
        state['workspaceId'] != replica.workspaceId ||
        state['bindingId'] != provider.bindingId) {
      throw const WorkspaceConflict(
        'Sync binding changed. Refresh before resolving.',
      );
    }
    final conflicts = Map<String, dynamic>.from(state['conflicts'] as Map);
    final conflict = conflicts[key] as Map?;
    if (conflict == null || conflict['reason'] == 'missing-without-tombstone') {
      throw const WorkspaceConflict(
        'Refresh or recover the missing source before resolving.',
      );
    }
    final alternatives =
        [
              if (conflict['remote'] is Map) conflict['remote'],
              ...?conflict['alternatives'] as List?,
            ]
            .map(
              (v) =>
                  RemoteSyncEntry.fromJson(Map<String, dynamic>.from(v as Map)),
            )
            .toList();
    final local = (await replica.inventory())[key];
    if (expectedLocalHash != null &&
        expectedLocalHash != (local?.hash ?? 'absent')) {
      throw const WorkspaceConflict(
        'Local content changed after review. Review the latest version before resolving.',
      );
    }
    RemoteSyncEntry? chosen;
    if (remoteVersion != null) {
      final matches = alternatives.where((e) => e.version == remoteVersion);
      if (matches.length != 1) {
        throw const WorkspaceConflict('Choose a reviewed version.');
      }
      chosen = matches.single;
    }
    final entry = chosen?.entry ?? local;
    if (entry == null) {
      throw const WorkspaceConflict('There is no local source to keep.');
    }
    final parents = alternatives.map((e) => e.version).toList()..sort();
    final intents = Map<String, dynamic>.from(
      state['resolutions'] as Map? ?? {},
    );
    final prior = intents[key] as Map?;
    final same =
        prior != null &&
        SyncEntry.fromJson(
          Map<String, dynamic>.from(prior['entry'] as Map),
        ).sameAs(entry) &&
        jsonEncode(prior['parents']) == jsonEncode(parents);
    final operation = same ? prior['operation'] as String : const Uuid().v4();
    intents[key] = {
      'operation': operation,
      'entry': entry.toJson(),
      'parents': parents,
    };
    state['resolutions'] = intents;
    await stateStore.save(state);
    final published = await target.publishResolution(
      entry,
      chosen == null ? replica.read(entry) : provider.download(chosen),
      operationId: operation,
      parents: parents,
    );
    if (!entry.sameAs(published.entry)) {
      throw const WorkspaceConflict('Unexpected resolution acknowledgement.');
    }
    if (!entry.sameAs(local)) {
      await replica.apply(entry, provider.download(published), expected: local);
    }
    (state['base'] as Map)[key] = entry.toJson();
    (state['remote'] as Map)[key] = published.toJson();
    (state['pending'] as Map).remove(key);
    conflicts.remove(key);
    intents.remove(key);
    state['conflicts'] = conflicts;
    await stateStore.save(state);
    return _run();
  }

  Future<SyncResult> _run() async {
    if (replica.workspaceId != provider.workspaceId ||
        (!provider.supportsConditionalPublication &&
            provider is! ImmutableRevisionSyncProvider)) {
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
    for (final fork in delta.forks.entries) {
      if (fork.value.length < 2 ||
          fork.value.any((e) => e.entry.key != fork.key) ||
          delta.entries.any((e) => e.entry.key == fork.key)) {
        throw const WorkspaceConflict('Remote branches are ambiguous.');
      }
      remote.remove(fork.key);
      for (final alternative in fork.value) {
        validateSyncEntries({fork.key: alternative.entry});
        await replica.preserveConflict(
          alternative.version,
          local[fork.key],
          alternative,
          provider.download(alternative),
        );
      }
      conflicts[fork.key] = {
        'reason': 'concurrent-revisions',
        'local': local[fork.key]?.toJson(),
        'alternatives': fork.value.map((e) => e.toJson()).toList(),
      };
    }
    await stateStore.save(state);
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
      if (delta.forks.containsKey(key)) continue;
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
