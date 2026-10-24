part of 'workspace_repository.dart';

/// Shared transport never writes authored files itself. These commands share the
/// repository queue, ownership, history and compare-before-write boundaries.
extension SharedVaultReplica on WorkspaceRepository {
  SyncStateStore sharedSessionStore(
    String binding, {
    required bool Function() isCurrent,
  }) => _ReplicaStateStore(
    WorkspaceSyncReplica(this, canApply: () => true, isCurrent: isCurrent),
    path: '.orbit/device/shared/${sha256.convert(utf8.encode(binding))}.json',
  );
  Future<Map<String, ObjectTombstone>> sharedDeletions() => _serial(() async {
    _requireOpen();
    final result = <String, ObjectTombstone>{};
    for (final path in (await _store.listFiles()).where(
      (p) => p.startsWith('.orbit/tombstones/') && p.endsWith('.json'),
    )) {
      final bytes = await _store.read(path);
      if (bytes == null) continue;
      final record = ObjectTombstone.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
      if (record.workspaceId != workspaceId || record.storagePath != path) {
        throw const WorkspaceConflict('Shared deletion identity changed.');
      }
      result[record.objectId] = record;
    }
    return result;
  });

  Future<UniversalObject> applySharedObject(
    UniversalObject remote, {
    required UniversalObject? expected,
    required bool Function() isCurrent,
    String? path,
  }) => _ownedOrganization(() async {
    void guard() {
      _requireWritable();
      if (!isCurrent()) {
        throw const WorkspaceConflict('Shared opening or draft changed.');
      }
    }

    guard();
    await _verifyManifest();
    final current = _objects[remote.id];
    if (expected == null
        ? current != null
        : current == null ||
              !collaborationContentEqual(
                collaborationSnapshot(current),
                collaborationSnapshot(expected),
              )) {
      throw const WorkspaceConflict(
        'Local shared object changed before saving.',
      );
    }
    _validate(remote);
    if (current != null &&
        (current.typeId != remote.typeId ||
            current.createdAt != remote.createdAt)) {
      throw const WorkspaceConflict(
        'Shared object immutable identity changed.',
      );
    }
    if (await _store.read('.orbit/tombstones/${remote.id}.json') != null) {
      throw const WorkspaceConflict(
        'A permanent deletion cannot be resurrected by shared editing.',
      );
    }
    final target = path ?? _paths[remote.id] ?? _newPath(remote);
    if (_paths.entries.any(
      (entry) =>
          entry.key != remote.id &&
          entry.value.toLowerCase() == target.toLowerCase(),
    )) {
      throw const WorkspaceConflict('Another object owns this shared path.');
    }
    validateSyncEntries({
      remote.id: SyncEntry(key: remote.id, path: target, hash: '0' * 64),
    });
    if (!WorkspaceSyncReplica(
      this,
      canApply: () => true,
    )._pathMatchesType(target, remote.typeId)) {
      throw const WorkspaceConflict(
        'Shared owning path does not match its type.',
      );
    }
    if (current != null && target != _paths[remote.id]) {
      throw const WorkspaceConflict(
        'Shared physical moves require explicit reconciliation.',
      );
    }
    if (remote.typeId == 'orbit.file') {
      final ref = remote.properties['contentRef'];
      if (ref is! String ||
          await sharedAttachmentHash(ref) != remote.properties['checksum']) {
        throw const WorkspaceConflict(
          'Verify shared attachment bytes before saving its object.',
        );
      }
    }
    guard();
    final isNew = current == null;
    if (isNew) _paths[remote.id] = target;
    try {
      return await _save(
        remote.copyWith(revision: current?.revision ?? 0),
        checkCurrent: guard,
      );
    } catch (_) {
      if (isNew && !_objects.containsKey(remote.id)) _paths.remove(remote.id);
      rethrow;
    }
  });

  Future<void> applySharedRemoval(
    String id, {
    required UniversalObject? expected,
    required ObjectTombstone tombstone,
    required bool Function() isCurrent,
  }) => _ownedOrganization(() async {
    _requireWritable();
    await _verifyManifest();
    if (!isCurrent() ||
        tombstone.workspaceId != workspaceId ||
        tombstone.objectId != id) {
      throw const WorkspaceConflict('Shared deletion opening changed.');
    }
    final current = _objects[id];
    if (current == null) {
      if (await _store.read(tombstone.storagePath) == null) {
        await WorkspaceDeletions(_store, workspaceId).applyRemote(
          _bytes(jsonEncode(tombstone.toJson())),
          checkCurrent: () {
            if (!isCurrent()) {
              throw const WorkspaceConflict('Shared opening changed.');
            }
          },
        );
      }
      return;
    }
    if (expected == null ||
        !collaborationContentEqual(
          collaborationSnapshot(current),
          collaborationSnapshot(expected),
        )) {
      throw const WorkspaceConflict(
        'Local edits conflict with shared deletion.',
      );
    }
    await WorkspaceDeletions(
      _store,
      workspaceId,
    ).delete(id, _paths[id]!, _hashes[id]!);
    await _refresh();
  });

  Stream<List<int>> sharedAttachmentRead(String path, {int start = 0}) async* {
    _requireOpen();
    if (syncPathRole(path) != SyncPathRole.attachment || start < 0) {
      throw const WorkspaceFailure('Invalid shared attachment path.');
    }
    final generation = _syncGeneration;
    final store = _store;
    final source = store is WorkspaceStreamingStore
        ? (store as WorkspaceStreamingStore).openRead(path)
        : Stream<List<int>>.value(
            await store.read(path) ??
                (throw const WorkspaceFailure('Missing shared attachment.')),
          );
    var skip = start;
    await for (final part in source) {
      if (generation != _syncGeneration) {
        throw const WorkspaceConflict('Attachment belongs to another opening.');
      }
      if (skip >= part.length) {
        skip -= part.length;
        continue;
      }
      yield skip == 0 ? part : part.sublist(skip);
      skip = 0;
    }
  }

  Future<String?> sharedAttachmentHash(String path) async {
    if (syncPathRole(path) != SyncPathRole.attachment) {
      throw const WorkspaceFailure('Invalid attachment path.');
    }
    if (!(await _store.listFiles()).contains(path)) return null;
    return (await sha256.bind(sharedAttachmentRead(path)).first).toString();
  }

  Future<Map<String, Map<String, dynamic>>> sharedAttachments() async {
    _requireOpen();
    final result = <String, Map<String, dynamic>>{};
    for (final path in (await _store.listFiles()).where(
      (p) => p.startsWith('Attachments/'),
    )) {
      var size = 0;
      final hash = await sha256
          .bind(
            sharedAttachmentRead(path).map((chunk) {
              size += chunk.length;
              return chunk;
            }),
          )
          .first;
      result[path] = {'hash': '$hash', 'size': size};
    }
    return result;
  }

  Future<void> applySharedAttachment(
    String path,
    String hash,
    Stream<List<int>> bytes, {
    required bool Function() isCurrent,
    Stream<List<int>> Function(int)? resumeRead,
    int? size,
  }) async {
    validateSyncEntries({
      'blob:$path': SyncEntry(key: 'blob:$path', path: path, hash: hash),
    });
    if (syncPathRole(path) != SyncPathRole.attachment) {
      throw const WorkspaceFailure('Invalid shared attachment.');
    }
    final generation = _syncGeneration;
    void guard() {
      _requireWritable();
      if (generation != _syncGeneration || !isCurrent()) {
        throw const WorkspaceConflict('Shared attachment opening changed.');
      }
    }

    guard();
    final store = _store;
    if (store is WorkspaceStagingStore) {
      WorkspaceStage stage;
      if (store is WorkspaceAttachmentStagingStore &&
          resumeRead != null &&
          size != null) {
        final staging = store as WorkspaceAttachmentStagingStore;
        final candidates = (await staging.listAttachmentStages())
            .where(
              (s) =>
                  s.operation == 'shared-sync' &&
                  s.target == path &&
                  s.expectedHash == hash &&
                  s.maxBytes == size,
            )
            .toList();
        if (candidates.isNotEmpty) {
          final prior = candidates.first;
          stage = await staging.resumeAttachmentStage(
            prior.id,
            resumeRead(prior.length),
          );
        } else {
          stage = await staging.stageAttachment(
            bytes,
            info: WorkspaceAttachmentStageInfo(
              id: const Uuid().v4(),
              operation: 'shared-sync',
              target: path,
              expectedHash: hash,
              maxBytes: size,
              length: 0,
            ),
          );
        }
      } else {
        stage = await (store as WorkspaceStagingStore).stage(
          bytes,
          expectedHash: hash,
          maxBytes: WorkspaceSyncReplica.maxBlobBytes,
        );
      }
      try {
        await _ownedOrganization(() async {
          guard();
          final old = await sharedAttachmentHash(path);
          if (old == hash) return;
          if (old != null) {
            throw const WorkspaceConflict(
              'A shared attachment path cannot overwrite different bytes.',
            );
          }
          await stage.commit(path, expectedHash: null, checkCurrent: guard);
        });
      } finally {
        await stage.close();
      }
    } else {
      // Bounded compatibility path for in-memory/browser repositories.
      final output = BytesBuilder(copy: false);
      await for (final chunk in bytes) {
        guard();
        if (output.length + chunk.length > 16 * 1024 * 1024) {
          throw const WorkspaceFailure(
            'Streamed attachment staging is required above 16 MiB.',
          );
        }
        output.add(chunk);
      }
      final value = output.takeBytes();
      if (sha256.convert(value).toString() != hash) {
        throw const WorkspaceConflict('Shared attachment checksum differs.');
      }
      await _ownedOrganization(() async {
        guard();
        final old = await sharedAttachmentHash(path);
        if (old == hash) return;
        if (old != null) {
          throw const WorkspaceConflict(
            'Shared attachment path already contains different bytes.',
          );
        }
        await _store.write(path, value, expectedHash: null);
      });
    }
  }
}
