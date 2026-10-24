part of 'collaboration_controller.dart';

class _SharedRecoveryBlocked extends StateError {
  _SharedRecoveryBlocked(super.message);
}

extension SharedVaultReplication on CollaborationController {
  Future<void> reconnectAutomatically() async {
    if (_disposed ||
        secrets == null ||
        !workspace.hasWorkspace ||
        workspace.loading ||
        connecting ||
        profileBusy ||
        accessBlocked ||
        _manualDisconnectOpening == workspace.workspaceGeneration) {
      return;
    }
    if (connected) {
      if (_validWorkspace) return;
      disconnect(userInitiated: false);
    }
    final opening = workspace.workspaceGeneration;
    try {
      await loadSavedConnection();
      if (_disposed ||
          opening != workspace.workspaceGeneration ||
          !autoReconnectSaved ||
          _manualDisconnectOpening == opening) {
        return;
      }
      await reconnectSaved();
      await pump();
    } catch (_) {
      if (!_disposed && opening == workspace.workspaceGeneration) {
        status = 'Saved server needs attention · reconnect from Sync settings';
        _notify();
      }
    }
  }

  Future<Map<String, dynamic>?> _restoreSharedJournal() async {
    final generation = _generation;
    final binding = '$endpoint|$room|${sha256.convert(utf8.encode(_token!))}';
    _sessionBinding = binding;
    _sessionJournal = workspace.repository.sharedSessionStore(
      binding,
      isCurrent: () => _current(generation),
    );
    final state = await _sessionJournal!.load();
    if (!_current(generation)) throw StateError('Connection opening changed.');
    if (state == null) return null;
    if (state['format'] != 'orbit-shared-outbox' ||
        state['version'] != 1 ||
        state['binding'] != binding ||
        state['workspaceId'] != _workspaceId) {
      throw StateError(
        'Shared recovery journal belongs to another connection or format.',
      );
    }
    if (state['epoch'] != _serverEpoch) return null;
    _checkpointDigest = sha256
        .convert(utf8.encode(jsonEncode(state)))
        .toString();
    _inflight.addAll(
      Map<String, dynamic>.from(
        state['inflight'] as Map,
      ).map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map))),
    );
    _newPlans.addAll(
      Map<String, dynamic>.from(
        state['creations'] as Map,
      ).map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map))),
    );
    return state;
  }

  Future<void> _checkpointShared() async {
    final store = _sessionJournal;
    if (store == null) return;
    final state = <String, dynamic>{
      'format': 'orbit-shared-outbox',
      'version': 1,
      'binding': _sessionBinding,
      'workspaceId': _workspaceId,
      'epoch': _serverEpoch,
      'documents': _documents,
      'inflight': _inflight,
      'creations': _newPlans,
    };
    final bytes = utf8.encode(jsonEncode(state));
    if (bytes.length > 16 * 1024 * 1024) {
      throw _SharedRecoveryBlocked(
        'Shared recovery journal exceeds 16 MiB · use a smaller shared Vault · local work preserved',
      );
    }
    final digest = sha256.convert(bytes).toString();
    if (digest == _checkpointDigest) return;
    try {
      await store.save(state);
    } catch (_) {
      throw _SharedRecoveryBlocked(
        'Cannot save shared recovery journal · check Vault storage, then retry · local work preserved',
      );
    }
    if (identical(store, _sessionJournal)) _checkpointDigest = digest;
  }

  void localChanged() {
    if (!automaticPolling || !connected || accessBlocked || !_validWorkspace) {
      return;
    }
    if (_localDebounce?.isActive == true) return;
    _localDebounce = Timer(const Duration(milliseconds: 120), () {
      if (connected && !_disposed) unawaited(pump());
    });
  }

  Future<void> _watchChanges(int watch) async {
    while (!_disposed &&
        connected &&
        _liveReplication &&
        watch == _watchGeneration) {
      if (accessBlocked) return;
      if (retryAt != null && _now().isBefore(retryAt!)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        continue;
      }
      try {
        final event = await request(
          endpoint!,
          _token!,
          'GET',
          '/v1/rooms/$room/events?${Uri(queryParameters: {'since': '$_sequence', 'epoch': _serverEpoch ?? '', 'awareness': '$_awarenessSequence'}).query}',
        );
        if (watch != _watchGeneration || !connected || _disposed) return;
        _awarenessSequence = event['awareness'] as int;
        if (event['sequence'] != _sequence ||
            event['epoch'] != _serverEpoch ||
            _awarenessSequence > 0) {
          await pump();
        }
      } on CollaborationAccessDenied {
        if (watch == _watchGeneration) {
          accessBlocked = true;
          status = 'Shared access was revoked · local files preserved';
          _notify();
        }
        return;
      } catch (_) {
        if (watch != _watchGeneration) return;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  bool _safeSharedApply(int generation, String id, UniversalObject? expected) {
    if (!_current(generation) ||
        workspace.loading ||
        workspace.dirty.contains(id) ||
        workspace.failures.containsKey(id) ||
        workspace.editorDraftConflicts.values.any((d) => d.objectId == id)) {
      return false;
    }
    final current = workspace.find(id);
    return expected == null
        ? current == null
        : current != null &&
              collaborationContentEqual(
                collaborationSnapshot(current),
                collaborationSnapshot(expected),
              );
  }

  Future<void> _saveSharedObject(
    UniversalObject object,
    UniversalObject? expected,
    String? path,
    int generation,
  ) async {
    if (expected != null) await workspace.flush(object.id);
    try {
      await workspace.repository.applySharedObject(
        object,
        expected: expected,
        path: path,
        isCurrent: () => _safeSharedApply(generation, object.id, expected),
      );
    } catch (e) {
      throw CollaborationConflict('local shared saving: $e');
    }
    if (!_current(generation)) return;
    workspace.mergeRepositoryObjects();
    workspace.notify();
  }

  Future<void> _receiveShared(
    String id,
    Map<String, dynamic>? prior,
    Map<String, dynamic> next,
    int generation,
  ) async {
    final local = workspace.find(id);
    if (next['removed'] == true) {
      if (local != null &&
          (prior?['snapshot'] is! Map ||
              !collaborationContentEqual(
                collaborationSnapshot(local),
                Map<String, dynamic>.from(prior!['snapshot'] as Map),
              ))) {
        throw const CollaborationConflict(
          'local edits versus permanent deletion',
        );
      }
      if (local != null) await workspace.flush(id);
      try {
        await workspace.repository.applySharedRemoval(
          id,
          expected: local,
          tombstone: ObjectTombstone.fromJson(
            Map<String, dynamic>.from(next['tombstone'] as Map),
          ),
          isCurrent: () => _safeSharedApply(generation, id, local),
        );
      } catch (e) {
        throw CollaborationConflict('shared removal: $e');
      }
      if (!_current(generation)) return;
      workspace.mergeRepositoryObjects();
      workspace.closeTab(id);
      workspace.notify();
      _documents[id] = next;
      return;
    }
    final snapshot = Map<String, dynamic>.from(next['snapshot'] as Map);
    if (local == null) {
      final deleted = (await workspace.repository.sharedDeletions())
          .containsKey(id);
      if (prior != null && deleted) {
        if (next['version'] != prior['version']) {
          throw const CollaborationConflict(
            'local deletion versus a newer shared edit',
          );
        }
        return;
      }
      if (prior != null && !deleted) {
        throw const CollaborationConflict(
          'a missing local source without a deletion record',
        );
      }
      await _saveSharedObject(
        collaborationObject(snapshot, allowDeleted: true),
        null,
        next['path'] as String?,
        generation,
      );
    } else if (!collaborationContentEqual(
      collaborationSnapshot(local),
      snapshot,
    )) {
      if (prior == null) {
        throw const CollaborationConflict(
          'an unknown common base for a new shared object',
        );
      }
      await _adopt(
        id,
        Map<String, dynamic>.from(prior['snapshot'] as Map),
        next,
      );
    }
    if (_current(generation)) _documents[id] = next;
  }

  Future<void> _captureAttachments(int generation) async {
    final owners = workspace.objects
        .where((o) => o.typeId == 'orbit.file')
        .map(
          (o) =>
              '${o.id}:${o.properties['contentRef']}:${o.properties['checksum']}',
        )
        .join('|');
    if (_attachmentRevision == workspace.attachmentRevision &&
        owners == _attachmentOwners) {
      return;
    }
    final revision = workspace.attachmentRevision;
    final inventory = await workspace.repository.sharedAttachments();
    if (!_current(generation)) return;
    _localAttachments = inventory;
    _attachmentRevision = revision;
    _attachmentOwners = owners;
  }

  Future<void> _receiveAttachments(Map state, int generation) async {
    await _captureAttachments(generation);
    final entries = Map<String, dynamic>.from(
      state['attachments'] as Map? ?? {},
    );
    for (final entry in entries.entries) {
      if (!_current(generation)) return;
      final info = Map<String, dynamic>.from(entry.value as Map);
      final hash = info['hash'] as String, size = info['size'] as int;
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ||
          size < 0 ||
          size > 2 * 1024 * 1024 * 1024) {
        throw const FormatException('Invalid shared attachment metadata.');
      }
      if (_localAttachments[entry.key]?['hash'] == hash) continue;
      await workspace.repository.applySharedAttachment(
        entry.key,
        hash,
        _downloadBlob(hash, size, generation),
        isCurrent: () => _current(generation),
        resumeRead: (offset) =>
            _downloadBlob(hash, size, generation, start: offset),
        size: size,
      );
      if (!_current(generation)) return;
      _localAttachments[entry.key] = info;
    }
  }

  Stream<List<int>> _downloadBlob(
    String hash,
    int size,
    int generation, {
    int start = 0,
  }) async* {
    var offset = start;
    while (offset < size) {
      if (!_current(generation)) throw StateError('Shared opening changed.');
      final bytes = await _blobHttp('GET', hash, offset, size);
      if (bytes.isEmpty ||
          bytes.length > 1024 * 1024 ||
          offset + bytes.length > size) {
        throw const FormatException('Incomplete attachment chunk.');
      }
      offset += bytes.length;
      yield bytes;
    }
  }

  Future<Uint8List> _blobHttp(
    String method,
    String hash,
    int offset,
    int size, [
    List<int>? chunk,
  ]) async {
    final generation = _generation;
    final uri = Uri.parse('$endpoint/v1/rooms/$room/blob').replace(
      queryParameters: {'hash': hash, 'offset': '$offset', 'size': '$size'},
    );
    final outgoing = http.Request(method, uri)..followRedirects = false;
    outgoing.headers['Authorization'] = 'Bearer $_token';
    outgoing.headers['X-Orbit-Client'] = '2';
    if (chunk != null) {
      outgoing.headers['Content-Type'] = 'application/octet-stream';
      outgoing.bodyBytes = chunk;
    }
    final response = await httpClient
        .send(outgoing)
        .timeout(const Duration(seconds: 30));
    final result = BytesBuilder(copy: false);
    await for (final bytes in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (!_current(generation)) throw StateError('Shared opening changed.');
      if (result.length + bytes.length > 1024 * 1024 + 1024) {
        throw const FormatException('Oversized attachment chunk.');
      }
      result.add(bytes);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const CollaborationAccessDenied();
    }
    if (response.statusCode != 200) {
      throw StateError('Attachment transfer failed; local bytes preserved.');
    }
    return result.takeBytes();
  }

  Future<void> _uploadAttachment(
    String path,
    Map<String, dynamic> info,
    int generation,
  ) async {
    final hash = info['hash'] as String, size = info['size'] as int;
    final probe = await request(
      endpoint!,
      _token!,
      'GET',
      '/v1/rooms/$room/blob-status?hash=$hash&size=$size',
    );
    var offset = probe['offset'] as int;
    if (offset < 0 || offset > size) {
      throw const FormatException('Invalid resumable offset.');
    }
    if (probe['complete'] != true) {
      if (size == 0) {
        await _blobHttp('PUT', hash, 0, 0, []);
      }
      await for (final chunk in _attachmentChunks(
        workspace.repository.sharedAttachmentRead(path, start: offset),
      )) {
        if (!_current(generation)) throw StateError('Connection changed.');
        final reply =
            jsonDecode(
                  utf8.decode(
                    await _blobHttp('PUT', hash, offset, size, chunk),
                  ),
                )
                as Map;
        if (reply['offset'] != offset + chunk.length) {
          throw StateError(
            'Attachment offset advanced elsewhere; retry its status probe.',
          );
        }
        offset += chunk.length;
      }
      if (offset != size) {
        throw StateError('Attachment source changed during transfer.');
      }
    }
    if (!_current(generation)) return;
    await request(endpoint!, _token!, 'POST', '/v1/rooms/$room/attachment', {
      'epoch': _serverEpoch,
      'path': path,
      ...info,
    });
  }

  Future<void> _publishShared(int generation, Map state) async {
    await _captureAttachments(generation);
    // Query the current index after incoming transfers. Publish bytes before
    // any object/Canvas reference which depends on them.
    if (!_current(generation)) return;
    final remoteAttachments = state['attachments'] as Map? ?? {};
    for (final entry in _localAttachments.entries.toList()) {
      if (!_current(generation)) return;
      if ((remoteAttachments[entry.key] as Map?)?['hash'] ==
          entry.value['hash']) {
        continue;
      }
      await _uploadAttachment(entry.key, entry.value, generation);
    }
    final deletions = await workspace.repository.sharedDeletions();
    for (final record in deletions.values) {
      if (!_current(generation)) return;
      final prior = _documents[record.objectId];
      if (prior?['removed'] == true || conflicts.containsKey(record.objectId)) {
        continue;
      }
      try {
        final result = await request(
          endpoint!,
          _token!,
          'POST',
          '/v1/rooms/$room/remove',
          {
            'epoch': _serverEpoch,
            'version': prior?['version'],
            'tombstone': record.toJson(),
          },
        );
        if (!_current(generation)) return;
        _documents[record.objectId] = result;
      } on CollaborationConflict catch (e) {
        conflicts[record.objectId] = e.toString();
      }
    }
    for (final object in workspace.objects.toList()) {
      if (!_current(generation)) return;
      if (object.isReadOnly ||
          _documents.containsKey(object.id) ||
          conflicts.containsKey(object.id)) {
        continue;
      }
      await workspace.flush(object.id);
      if (!_current(generation) ||
          workspace.dirty.contains(object.id) ||
          workspace.failures.containsKey(object.id)) {
        continue;
      }
      final saved = workspace.find(object.id);
      if (saved == null) continue;
      final plan = _newPlans.putIfAbsent(
        object.id,
        () => {
          'epoch': _serverEpoch,
          'snapshot': collaborationSnapshot(saved),
          'path': workspace.repository.objectPath(object.id),
          'operation': const Uuid().v4(),
        },
      );
      await _checkpointShared();
      try {
        final result = await request(
          endpoint!,
          _token!,
          'POST',
          '/v1/rooms/$room/put',
          plan,
        );
        if (!_current(generation)) return;
        // The proposal may have changed while awaiting acknowledgement.
        _documents[object.id] = {
          'version': result['version'],
          'snapshot': plan['snapshot'],
          'path': result['path'],
        };
        _newPlans.remove(object.id);
        await _adopt(
          object.id,
          Map<String, dynamic>.from(plan['snapshot'] as Map),
          result,
        );
      } on CollaborationConflict catch (e) {
        conflicts[object.id] = e.toString();
      }
    }
  }
}

Stream<List<int>> _attachmentChunks(Stream<List<int>> source) async* {
  var buffer = BytesBuilder(copy: false);
  await for (final part in source) {
    var index = 0;
    while (index < part.length) {
      final end = (index + 1024 * 1024 - buffer.length).clamp(
        index,
        part.length,
      );
      buffer.add(part.sublist(index, end));
      index = end;
      if (buffer.length == 1024 * 1024) {
        yield buffer.takeBytes();
        buffer = BytesBuilder(copy: false);
      }
    }
  }
  if (buffer.length > 0) yield buffer.takeBytes();
}
