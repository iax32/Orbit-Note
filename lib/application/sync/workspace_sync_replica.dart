part of '../workspace_repository.dart';

/// Repository-owned adapter. The required live guard belongs to the controller,
/// which knows about drafts, saves in flight, disposal and workspace switches.
class WorkspaceSyncReplica implements SyncReplica {
  WorkspaceSyncReplica(
    this.repository, {
    required this.canApply,
    this.isCurrent,
    this.onApplied,
  }) : workspaceId = repository.workspaceId,
       _generation = repository._syncGeneration;

  final WorkspaceRepository repository;
  final bool Function() canApply;
  final bool Function()? isCurrent;
  final void Function()? onApplied;
  final int _generation;
  @override
  final String workspaceId;
  static const maxDocumentBytes = 32 * 1024 * 1024;
  static const maxBlobBytes = 2 * 1024 * 1024 * 1024;

  /// Use this state wrapper with the replica. It serializes writes with Vault
  /// switches, so a late provider acknowledgement cannot write another Vault.
  SyncStateStore createStateStore() => _ReplicaStateStore(this);
  SyncStateStore createDriveSettingsStore() => _ReplicaStateStore(
    this,
    path: '.orbit/device/sync/drive-settings-v1.json',
  );
  SyncStateStore createDriveJournalStore() => _ReplicaStateStore(
    this,
    path: '.orbit/device/sync/drive-uploads-v1.json',
  );
  Future<WorkspaceStage> stageTransfer(Stream<List<int>> bytes, String hash) {
    final staging = _staging;
    return staging is WorkspaceChecksumStagingStore
        ? staging.stageWithChecksums(
            bytes,
            expectedHash: hash,
            maxBytes: maxBlobBytes,
          )
        : staging.stage(bytes, expectedHash: hash, maxBytes: maxBlobBytes);
  }

  void _check({bool applying = false}) {
    repository._requireWritable();
    if (isCurrent?.call() == false ||
        repository._syncGeneration != _generation ||
        repository.workspaceId != workspaceId) {
      throw const WorkspaceConflict(
        'Sync belongs to a different Vault opening.',
      );
    }
    if (applying && !canApply()) {
      throw const WorkspaceConflict(
        'Save or recover local drafts before applying cloud changes.',
      );
    }
  }

  WorkspaceStagingStore get _staging {
    _check();
    final store = repository._store;
    if (store is! WorkspaceStagingStore) {
      throw const WorkspaceFailure(
        'Safe sync staging is unavailable on this platform.',
      );
    }
    return store as WorkspaceStagingStore;
  }

  Future<SyncInventory> _inventory() async {
    _check();
    await repository._verifyManifest();
    final result = await captureSyncInventory(
      repository._store,
      workspaceId,
      knownObjects: repository._inventoryObjects,
    );
    _check();
    if (!result.ready) throw WorkspaceFailure(result.issues.join('\n'));
    return result;
  }

  @override
  Future<Map<String, SyncEntry>> inventory() =>
      repository._serial(() async => (await _inventory()).entries);

  Stream<List<int>> _source(String path) async* {
    _check();
    final store = repository._store;
    if (store is! WorkspaceStreamingStore) {
      throw const WorkspaceFailure('Native streamed sync reads are required.');
    }
    await for (final bytes in (store as WorkspaceStreamingStore).openRead(
      path,
    )) {
      _check();
      yield bytes;
    }
  }

  Future<WorkspaceStage> _snapshot(SyncEntry expected) =>
      repository._serial(() async {
        final inventory = await _inventory();
        if (!expected.sameAs(inventory.entries[expected.key])) {
          throw const WorkspaceConflict(
            'Local sync source changed before transfer.',
          );
        }
        return _staging.stage(
          _source(inventory.sourcePaths[expected.key]!),
          expectedHash: expected.hash,
          maxBytes: maxBlobBytes,
        );
      });

  @override
  Stream<List<int>> read(SyncEntry expected) async* {
    final stage = await _snapshot(expected);
    try {
      yield* stage.openRead();
    } finally {
      await stage.close();
    }
  }

  @override
  Future<void> apply(
    SyncEntry incoming,
    Stream<List<int>> bytes, {
    required SyncEntry? expected,
  }) async {
    _check(applying: true);
    validateSyncEntries({incoming.key: incoming});
    final role = syncPathRole(incoming.path);
    final stage = await _staging.stage(
      bytes,
      expectedHash: incoming.hash,
      maxBytes: role == SyncPathRole.attachment
          ? maxBlobBytes
          : maxDocumentBytes,
    );
    try {
      await repository._serial(() async {
        _check(applying: true);
        final inventory = await _inventory();
        final current = inventory.entries[incoming.key];
        // A committed apply with a lost checkpoint is already complete.
        if (incoming.sameAs(current)) return;
        if (expected == null ? current != null : !expected.sameAs(current)) {
          throw const WorkspaceConflict(
            'Local content changed while downloading.',
          );
        }
        validateSyncEntries({...inventory.entries, incoming.key: incoming});
        void guard() => _check(applying: true);
        try {
          if (incoming.deleted) {
            if (role != SyncPathRole.object || current?.deleted == true) {
              throw const WorkspaceConflict('Unsupported deletion transition.');
            }
            final raw = await stage.read(maxBytes: maxDocumentBytes);
            final record = ObjectTombstone.fromJson(
              jsonDecode(utf8.decode(raw)) as Map<String, dynamic>,
            );
            if (record.workspaceId != workspaceId ||
                record.objectId != incoming.key ||
                record.path != incoming.path ||
                (current != null &&
                    (current.path != record.path ||
                        current.hash != record.beforeHash))) {
              throw const WorkspaceConflict(
                'Deletion does not match the local base.',
              );
            }
            await WorkspaceDeletions(
              repository._store,
              workspaceId,
            ).applyRemote(raw, checkCurrent: guard);
          } else if (role == SyncPathRole.object) {
            if (current?.deleted == true) {
              throw const WorkspaceConflict(
                'Restoring a permanent deletion requires explicit review.',
              );
            }
            final raw = await stage.read(maxBytes: maxDocumentBytes);
            final object = repository._codec.decode(
              utf8.decode(raw),
              workspaceId,
              markdown: incoming.path.endsWith('.md'),
            );
            repository._validate(object);
            if (object.id != incoming.key ||
                !_pathMatchesType(incoming.path, object.typeId)) {
              throw const WorkspaceConflict(
                'Remote object identity or owning format differs.',
              );
            }
            final existing = repository._objects[incoming.key];
            if (existing != null &&
                (existing.typeId != object.typeId ||
                    existing.createdAt != object.createdAt)) {
              throw const WorkspaceConflict(
                'Remote content changes immutable object identity.',
              );
            }
            if (object.typeId == 'orbit.file') {
              final ref = object.properties['contentRef'];
              if (ref is! String ||
                  inventory.entries['blob:$ref']?.hash !=
                      object.properties['checksum']) {
                throw const WorkspaceConflict(
                  'Download and verify the attachment before its object.',
                );
              }
            }
            if (current != null && current.path != incoming.path) {
              // Reuse the proven Notes move journal; do not rebase/encode Markdown
              // that already came from the other device's durable move command.
              if (!current.path.startsWith('Notes/') ||
                  !incoming.path.startsWith('Notes/') ||
                  repository._store is! WorkspaceGuardedMoveStore) {
                throw const WorkspaceFailure(
                  'Sync moves for this owning format require recovery support.',
                );
              }
              guard();
              await (repository._store as WorkspaceGuardedMoveStore)
                  .moveSyncPath(current.path, incoming.path, {
                    current.path: FileReplacement(raw, current.hash),
                  }, checkCurrent: guard);
            } else {
              await stage.commit(
                incoming.path,
                expectedHash: current?.hash,
                checkCurrent: guard,
              );
            }
          } else if (role == SyncPathRole.attachment) {
            if (incoming.key != 'blob:${incoming.path}') {
              throw const WorkspaceConflict(
                'Attachment identity differs from its path.',
              );
            }
            if (repository.objects.any(
              (o) =>
                  o.typeId == 'orbit.file' &&
                  o.properties['contentRef'] == incoming.path &&
                  o.properties['checksum'] != incoming.hash,
            )) {
              throw const WorkspaceConflict(
                'Referenced attachments need a new content path before replacement.',
              );
            }
            await stage.commit(
              incoming.path,
              expectedHash: current?.hash,
              checkCurrent: guard,
            );
          } else if (role == SyncPathRole.manifest) {
            final raw = await stage.read(maxBytes: maxDocumentBytes);
            final manifest = jsonDecode(utf8.decode(raw)) as Map;
            if (incoming.key != 'vault:$workspaceId' ||
                manifest['format'] != 'orbit-note-workspace' ||
                manifest['version'] != 1 ||
                manifest['id'] != workspaceId ||
                manifest['name'] is! String) {
              throw const WorkspaceConflict(
                'Remote manifest identity or format differs.',
              );
            }
            await stage.commit(
              incoming.path,
              expectedHash: current?.hash,
              checkCurrent: guard,
            );
            repository._manifestHash = incoming.hash;
            repository._name = manifest['name'] as String;
          } else {
            throw const WorkspaceFailure('Unsupported remote content role.');
          }
        } finally {
          await repository._refresh();
        }
      });
      onApplied?.call();
    } finally {
      await stage.close();
    }
  }

  bool _pathMatchesType(String path, String type) => switch (type) {
    'orbit.note' => path.startsWith('Notes/') && path.endsWith('.md'),
    'orbit.canvas' =>
      path.startsWith('Boards/') && path.endsWith('.board.json'),
    'orbit.drawing' =>
      path.startsWith('Drawings/') && path.endsWith('.drawing.json'),
    _ => path.startsWith('Objects/') && path.endsWith('.object.json'),
  };

  @override
  Future<void> preserveConflict(
    String conflictId,
    SyncEntry? local,
    RemoteSyncEntry remote,
    Stream<List<int>> remoteBytes,
  ) async {
    _check();
    if (local != null && local.key != remote.entry.key) {
      throw const WorkspaceConflict('Conflict identities differ.');
    }
    if (local != null) validateSyncEntries({local.key: local});
    validateSyncEntries({remote.entry.key: remote.entry});
    final remoteStage = await _staging.stage(
      remoteBytes,
      expectedHash: remote.entry.hash,
      maxBytes: maxBlobBytes,
    );
    WorkspaceStage? localStage;
    try {
      if (local != null) localStage = await _snapshot(local);
      final identity = sha256
          .convert(utf8.encode(jsonEncode([local?.toJson(), remote.toJson()])))
          .toString();
      final folder = '.orbit/sync-conflicts/$identity';
      await repository._serial(() async {
        _check();
        Future<void> preserve(String name, WorkspaceStage stage) async {
          final path = '$folder/$name';
          final store = repository._store as WorkspaceStreamingStore;
          final exists = (await repository._store.listFiles()).contains(path);
          if (exists) {
            if ((await sha256.bind(store.openRead(path)).first).toString() !=
                stage.hash) {
              throw const WorkspaceConflict(
                'A conflict recovery copy has changed.',
              );
            }
          } else {
            await stage.commit(path, expectedHash: null, checkCurrent: _check);
          }
        }

        if (localStage != null) await preserve('local', localStage);
        await preserve('remote', remoteStage);
        final descriptor = repository._bytes(
          jsonEncode({
            'format': 'orbit-note-sync-conflict',
            'version': 1,
            'workspaceId': workspaceId,
            'local': local?.toJson(),
            'remote': remote.toJson(),
          }),
        );
        final path = '$folder/conflict.json';
        if (await repository._store.read(path) == null) {
          await repository._store.write(path, descriptor, expectedHash: null);
        }
      });
    } finally {
      await localStage?.close();
      await remoteStage.close();
    }
  }
}

class _ReplicaStateStore implements SyncStateStore {
  _ReplicaStateStore(this.replica, {String path = WorkspaceSyncStateStore.path})
    : delegate = WorkspaceSyncStateStore(
        replica.repository._store,
        storagePath: path,
      );
  final WorkspaceSyncReplica replica;
  final WorkspaceSyncStateStore delegate;
  @override
  Future<Map<String, dynamic>?> load() => replica.repository._serial(() async {
    replica._check();
    return delegate.load();
  });
  @override
  Future<void> save(Map<String, dynamic> state) =>
      replica.repository._serial(() async {
        replica._check();
        await delegate.save(state);
      });
}
