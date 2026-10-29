part of 'google_drive_api.dart';

extension GoogleDrivePersonalVaults on GoogleDriveApi {
  Future<List<GoogleRemoteVault>> listSyncVaults() async {
    final subject = _subject();
    final files = await _list(
      subject,
      "trashed = false and 'me' in owners and mimeType = '${GoogleDriveApi.folderMime}' and appProperties has { key='orbitRole' and value='sync-vault' }",
    );
    return files.map((f) {
      final p = f['appProperties'] as Map;
      if (!{'2', '3'}.contains(p['orbitProtocol']) ||
          (p['orbitProtocol'] == '3' &&
              p['orbitRetention'] != 'head-blobs-v1') ||
          p['orbitVaultId'] is! String) {
        throw const GoogleCloudError(
          'protocol',
          'A cloud Vault requires a newer sync format.',
        );
      }
      return GoogleRemoteVault(
        folderId: f['id'] as String,
        workspaceId: p['orbitVaultId'] as String,
        name: f['name'] as String,
        accountSubject: subject,
      );
    }).toList();
  }

  Future<void> verifySyncVault(GoogleRemoteVault vault) async {
    final f = await _request(
      vault.accountSubject,
      'GET',
      'files/${Uri.encodeComponent(vault.folderId)}',
      query: {'fields': GoogleDriveApi.fileFields},
    );
    final p = f['appProperties'] as Map?;
    if (f['ownedByMe'] != true ||
        f['trashed'] == true ||
        f['mimeType'] != GoogleDriveApi.folderMime ||
        p?['orbitRole'] != 'sync-vault' ||
        !{'2', '3'}.contains(p?['orbitProtocol']) ||
        (p?['orbitProtocol'] == '3' &&
            p?['orbitRetention'] != 'head-blobs-v1') ||
        p?['orbitVaultId'] != vault.workspaceId) {
      throw const GoogleCloudError(
        'identity',
        'This cloud Vault is missing or its identity changed. Local files are preserved.',
      );
    }
  }

  Future<GoogleRemoteVault> ensureSyncVault(
    String workspaceId,
    String name, {
    String? pendingId,
    required Future<void> Function(String) rememberId,
  }) async {
    final subject = _subject();
    final matches = (await listSyncVaults())
        .where((v) => v.workspaceId == workspaceId)
        .toList();
    if (matches.length > 1) {
      throw const GoogleCloudError(
        'ambiguous',
        'More than one synced folder has this Vault identity. Choose a folder explicitly.',
      );
    }
    if (matches.isNotEmpty) return matches.single;
    final root = await ensureRoot();
    final id =
        pendingId ??
        (await _request(
              subject,
              'GET',
              'files/generateIds',
              query: {'count': '1', 'space': 'drive', 'type': 'files'},
            ))['ids'].single
            as String;
    await rememberId(id);
    _account(subject);
    final vault = GoogleRemoteVault(
      folderId: id,
      workspaceId: workspaceId,
      name: name,
      accountSubject: subject,
    );
    try {
      await verifySyncVault(vault);
      return vault;
    } on GoogleCloudError catch (e) {
      if (e.code != 'missing') rethrow;
    }
    try {
      await _request(
        subject,
        'POST',
        'files',
        query: {'fields': 'id'},
        body: {
          'id': id,
          'name': name
              .replaceAll(RegExp(r'[\r\n]'), ' ')
              .substring(0, name.length.clamp(0, 100)),
          'mimeType': GoogleDriveApi.folderMime,
          'parents': [root],
          'appProperties': {
            'orbitRole': 'sync-vault',
            'orbitProtocol': '2',
            'orbitVaultId': workspaceId,
          },
        },
      );
    } on Object {
      // A lost create acknowledgement retries the same pre-generated identity.
      await verifySyncVault(vault);
    }
    await verifySyncVault(vault);
    return vault;
  }
}

class _DriveRevision {
  _DriveRevision(
    this.id,
    this.entry,
    this.blob,
    this.size,
    this.parents,
    this.operation,
  );
  final String id, blob, operation;
  final SyncEntry entry;
  final int size;
  final List<String> parents;
  RemoteSyncEntry get remote => RemoteSyncEntry(entry, blob, id);
  Map<String, dynamic> toJson(String workspace) => {
    'format': 'orbit-drive-revision',
    'version': 2,
    'workspaceId': workspace,
    'entry': entry.toJson(),
    'blob': blob,
    'size': size,
    'parents': parents,
    'operation': operation,
  };
  static _DriveRevision parse(
    String id,
    Map<String, dynamic> v,
    String workspace,
  ) {
    final entry = SyncEntry.fromJson(
      Map<String, dynamic>.from(v['entry'] as Map),
    );
    validateSyncEntries({entry.key: entry});
    final parents = List<String>.from(v['parents'] as List);
    if (v['format'] != 'orbit-drive-revision' ||
        v['version'] != 2 ||
        v['workspaceId'] != workspace ||
        v['size'] is! int ||
        (v['size'] as int) < 0 ||
        (v['size'] as int) > 2 * 1024 * 1024 * 1024 ||
        v['operation'] is! String ||
        (v['operation'] as String).length > 80 ||
        !_driveId.hasMatch(v['blob'] as String) ||
        !_driveId.hasMatch(id) ||
        parents.length > 64 ||
        parents.toSet().length != parents.length ||
        parents.any((p) => p == id || !_driveId.hasMatch(p))) {
      throw const WorkspaceConflict(
        'Unsupported or damaged cloud revision. No local files were replaced.',
      );
    }
    return _DriveRevision(
      id,
      entry,
      v['blob'] as String,
      v['size'] as int,
      parents,
      v['operation'] as String,
    );
  }
}

final _driveId = RegExp(r'^[A-Za-z0-9_-]{1,180}$');

/// Append-only graph publication: concurrent heads are retained, never elected by
/// time. Authored revision metadata is never patched or deleted. Explicit
/// retention may expire obsolete payloads after protocol negotiation/review.
class GoogleDriveSyncProvider implements ImmutableRevisionSyncProvider {
  GoogleDriveSyncProvider({
    required this.api,
    required this.vault,
    required this.journal,
    required this.stage,
    required this.isCurrent,
    this.onProgress,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final GoogleDriveApi api;
  final GoogleRemoteVault vault;
  final SyncStateStore journal;
  final Future<WorkspaceStage> Function(Stream<List<int>>, String) stage;
  final bool Function() isCurrent;
  final void Function(int, int)? onProgress;
  final DateTime Function() _now;
  Map<String, dynamic> _journal = {};
  final _records = <String, _DriveRevision>{};
  final _heads = <String, List<_DriveRevision>>{};
  (String, DateTime)? _inspected;
  @override
  String get workspaceId => vault.workspaceId;
  @override
  String get bindingId =>
      'drive-revisions-v2:${vault.accountSubject}:${vault.folderId}:$workspaceId';
  @override
  bool get supportsConditionalPublication => false;
  void _check() {
    if (!isCurrent()) {
      throw const WorkspaceConflict(
        'Sync was paused or the Vault opening changed.',
      );
    }
    api._account(vault.accountSubject);
  }

  Future<void> _load() async {
    _check();
    _journal =
        await journal.load() ??
        {
          'format': 'orbit-drive-uploads',
          'version': 1,
          'bindingId': bindingId,
          'operations': <String, dynamic>{},
          'records': <String, dynamic>{},
        };
    if (_journal['format'] != 'orbit-drive-uploads' ||
        _journal['version'] != 1 ||
        _journal['bindingId'] != bindingId) {
      throw const WorkspaceConflict(
        'Drive upload history belongs to another account or folder. Keep it for recovery.',
      );
    }
    _check();
  }

  Future<void> _save() async {
    _check();
    await journal.save(_journal);
    _check();
  }

  Map get _operations => _journal['operations'] as Map;
  Map get _cache => _journal['records'] as Map;
  Future<http.Response> _request(http.Request r) async {
    _check();
    final response = await api._backupRequest(vault.accountSubject, r);
    _check();
    return response;
  }

  http.Request _get(String id, {bool media = false}) => http.Request(
    'GET',
    Uri.https(
      'www.googleapis.com',
      '/drive/v3/files/${Uri.encodeComponent(id)}',
      media ? {'alt': 'media'} : {'fields': GoogleDriveApi.fileFields},
    ),
  );

  Future<Uint8List> _smallMedia(String id) async {
    final output = BytesBuilder(copy: false);
    await for (final chunk in _download(id)) {
      if (output.length + chunk.length > 64 * 1024) {
        throw const WorkspaceFailure('Cloud revision exceeds 64 KiB.');
      }
      output.add(chunk);
    }
    return output.takeBytes();
  }

  Stream<List<int>> _download(String id) async* {
    _check();
    http.StreamedResponse? response;
    for (var attempt = 0; attempt < 2; attempt++) {
      final r = _get(id, media: true)..followRedirects = false;
      GoogleDriveApi._compressionHeaders(r);
      r.headers['Authorization'] =
          'Bearer ${await api.auth.accessToken(refresh: attempt > 0)}';
      _check();
      response = await api.client.send(r).timeout(const Duration(seconds: 45));
      if (response.statusCode == 401 && attempt == 0) {
        await response.stream
            .take(1)
            .drain<void>()
            .timeout(const Duration(seconds: 45));
        continue;
      }
      if (response.statusCode != 200) {
        await response.stream
            .take(1)
            .drain<void>()
            .timeout(const Duration(seconds: 45));
        throw api._responseError(http.Response('{}', response.statusCode));
      }
      break;
    }
    await for (final chunk in response!.stream.timeout(
      const Duration(seconds: 45),
    )) {
      _check();
      yield chunk;
    }
    _check();
  }

  Future<_DriveRevision> _readRecord(
    String id, {
    Map<String, dynamic>? metadata,
  }) async {
    final f =
        metadata ??
        jsonDecode((await _request(_get(id))).body) as Map<String, dynamic>;
    final p = f['appProperties'] as Map?;
    if (f['ownedByMe'] != true ||
        f['trashed'] == true ||
        !(f['parents'] as List? ?? []).contains(vault.folderId) ||
        p?['orbitRole'] != 'sync-revision' ||
        p?['orbitProtocol'] != '2' ||
        p?['orbitVaultId'] != workspaceId ||
        (int.tryParse('${f['size']}') ?? 65537) > 65536) {
      throw const WorkspaceConflict('Cloud revision identity changed.');
    }
    final cached = (_journal['records'] as Map?)?[id] as Map?;
    if (cached != null && cached['checksum'] != f['md5Checksum']) {
      throw const WorkspaceConflict('Cloud revision checksum changed.');
    }
    _DriveRevision record;
    if (cached != null) {
      record = _DriveRevision.parse(
        id,
        Map<String, dynamic>.from(cached['record'] as Map),
        workspaceId,
      );
    } else {
      final bytes = await _smallMedia(id);
      if (md5.convert(bytes).toString() != f['md5Checksum']) {
        throw const WorkspaceConflict('Cloud revision checksum changed.');
      }
      record = _DriveRevision.parse(
        id,
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
        workspaceId,
      );
    }
    if (record.operation != p?['orbitOp'] ||
        p?['orbitKey'] !=
            sha256.convert(utf8.encode(record.entry.key)).toString()) {
      throw const WorkspaceConflict('Cloud operation identity changed.');
    }
    return record;
  }

  @override
  Future<SyncDelta> fetchChanges(String? cursor) => _fetchChanges();

  Future<SyncDelta> _scan(String? key) async {
    _inspected = null;
    await _load();
    late List<Map<String, dynamic>> files;
    await Future.wait<void>([
      api.verifySyncVault(vault),
      api
          ._list(
            vault.accountSubject,
            "trashed = false and 'me' in owners and '${api._quoted(vault.folderId)}' in parents and appProperties has { key='orbitRole' and value='sync-revision' }${key == null ? '' : " and appProperties has { key='orbitKey' and value='${sha256.convert(utf8.encode(key))}' }"}",
          )
          .then<void>((value) {
            files = value;
          }),
    ]);
    _check();
    if (files.length > 10000 ||
        files.map((f) => f['id']).toSet().length != files.length) {
      throw const WorkspaceFailure(
        'Cloud revision listing is oversized or ambiguous.',
      );
    }
    final ids = files.map((f) => f['id'] as String).toSet();
    final unlisted = _cache.keys
        .where(
          (id) =>
              (key == null ||
                  ((_cache[id] as Map)['record'] as Map)['entry']['key'] ==
                      key) &&
              !ids.contains(id),
        )
        .toList();
    // Drive's property query index may lag a successful create. Do not mistake
    // an indexed omission for deletion: prove the retained identity directly.
    // A real missing/moved/changed file still stops the pass before any apply.
    for (var start = 0; start < unlisted.length; start += 4) {
      files.addAll(
        await Future.wait([
          for (final id in unlisted.skip(start).take(4))
            (() async {
              try {
                final metadata =
                    jsonDecode((await _request(_get(id))).body)
                        as Map<String, dynamic>;
                if (metadata['id'] != id) {
                  throw const WorkspaceConflict(
                    'A retained cloud revision identity changed.',
                  );
                }
                return metadata;
              } on GoogleCloudError catch (e) {
                if (e.code != 'missing') rethrow;
                throw const WorkspaceConflict(
                  'A retained cloud revision disappeared. Restore it in Drive before syncing again.',
                );
              }
            })(),
        ]),
      );
    }
    if (key == null) {
      _records.clear();
    } else {
      _records.removeWhere((_, r) => r.entry.key == key);
    }
    await _acceptRevisions(files, key: key);
    return _buildDelta(key);
  }

  Future<void> _acceptRevisions(
    List<Map<String, dynamic>> files, {
    String? key,
  }) async {
    // Bound media reads; repeated identities retain their observation order.
    // Wait for every started read before reporting failure. Never checkpoint a
    // partially validated page/graph, including on cancellation or account swap.
    for (var start = 0; start < files.length; start += 4) {
      final batch = files.skip(start).take(4).toList();
      if (batch.map((f) => f['id']).toSet().length != batch.length) {
        for (final f in batch) {
          await _acceptRevision(f, key: key);
        }
      } else {
        await Future.wait([
          for (final f in batch) _acceptRevision(f, key: key),
        ]);
      }
      if (_records.length > 10000) {
        throw const WorkspaceFailure(
          'Cloud revision inventory exceeds 10,000 records.',
        );
      }
    }
  }

  Future<void> _acceptRevision(Map<String, dynamic> f, {String? key}) async {
    final id = f['id'] as String, cached = _cache[id] as Map?;
    final properties = f['appProperties'] as Map?;
    if (f['ownedByMe'] != true ||
        f['trashed'] == true ||
        !(f['parents'] as List? ?? []).contains(vault.folderId) ||
        properties?['orbitRole'] != 'sync-revision' ||
        properties?['orbitProtocol'] != '2' ||
        properties?['orbitVaultId'] != workspaceId) {
      throw const WorkspaceConflict(
        'Retained cloud revision metadata changed.',
      );
    }
    if (cached != null && cached['checksum'] != f['md5Checksum']) {
      throw const WorkspaceConflict(
        'An immutable cloud revision was modified externally.',
      );
    }
    final record = cached == null
        ? await _readRecord(id, metadata: f)
        : _DriveRevision.parse(
            id,
            Map<String, dynamic>.from(cached['record'] as Map),
            workspaceId,
          );
    if (properties?['orbitKey'] !=
            sha256.convert(utf8.encode(record.entry.key)).toString() ||
        properties?['orbitOp'] != record.operation ||
        (key != null && record.entry.key != key)) {
      throw const WorkspaceConflict('Cloud revision routing metadata changed.');
    }
    _records[id] = record;
    _cache[id] = {
      'checksum': f['md5Checksum'],
      'record': record.toJson(workspaceId),
    };
  }

  Future<SyncDelta> _buildDelta(String? key, {bool persist = true}) async {
    final children = <String, List<String>>{};
    final degrees = <String, int>{};
    final referenced = <String>{};
    final working = {
      for (final r in _records.values)
        if (key == null || r.entry.key == key) r.id: r,
    };
    for (final r in working.values) {
      degrees[r.id] = r.parents.length;
      for (final parent in r.parents) {
        if (working[parent]?.entry.key != r.entry.key) {
          throw const WorkspaceConflict(
            'Cloud revision history has a missing or foreign parent.',
          );
        }
        referenced.add(parent);
        (children[parent] ??= []).add(r.id);
      }
    }
    final queue = degrees.keys.where((k) => degrees[k] == 0).toList();
    for (var i = 0; i < queue.length; i++) {
      for (final child in children[queue[i]] ?? <String>[]) {
        degrees[child] = degrees[child]! - 1;
        if (degrees[child] == 0) queue.add(child);
      }
    }
    if (queue.length != working.length) {
      throw const WorkspaceConflict('Cloud revision history is cyclic.');
    }
    if (key == null) {
      _heads.clear();
    } else {
      _heads.remove(key);
    }
    for (final r in working.values.where((r) => !referenced.contains(r.id))) {
      (_heads[r.entry.key] ??= []).add(r);
    }
    for (final heads in _heads.values) {
      heads.sort((a, b) => a.id.compareTo(b.id));
    }
    if (persist) await _save();
    final sorted = _records.keys.toList()..sort();
    return SyncDelta(
      entries: [
        for (final heads in _heads.values)
          if (heads.length == 1) heads.single.remote,
      ],
      forks: {
        for (final pair in _heads.entries)
          if (pair.value.length > 1)
            pair.key: pair.value.map((r) => r.remote).toList(),
      },
      removedKeys: {},
      cursor: sha256.convert(utf8.encode(jsonEncode(sorted))).toString(),
      reset: true,
    );
  }

  @override
  Future<RemoteSyncEntry?> inspect(String key) async {
    await _scan(key);
    final heads = _heads[key] ?? [];
    if (heads.length > 1) {
      throw const WorkspaceConflict(
        'Concurrent cloud revisions need review. Sync again to load the alternatives.',
      );
    }
    _inspected = (key, _now());
    return heads.isEmpty ? null : heads.single.remote;
  }

  @override
  Stream<List<int>> download(RemoteSyncEntry remote) async* {
    final record = await _readRecord(remote.version);
    if (!record.entry.sameAs(remote.entry) || record.blob != remote.remoteId) {
      throw const WorkspaceConflict('Remote version identity changed.');
    }
    var count = 0;
    await for (final chunk in _download(record.blob)) {
      count += chunk.length;
      if (count > record.size) {
        throw const WorkspaceConflict('Cloud bytes exceed the recorded size.');
      }
      yield chunk;
    }
    if (count != record.size) {
      throw const WorkspaceConflict('Cloud file is incomplete.');
    }
    // WorkspaceSyncReplica stages and verifies exact SHA-256 before applying.
  }

  @override
  Future<RemoteSyncEntry> upload(
    SyncEntry entry,
    Stream<List<int>> bytes, {
    required String operationId,
    required String? expectedVersion,
  }) => _publish(
    entry,
    bytes,
    operationId,
    expectedVersion == null ? [] : [expectedVersion],
  );
  @override
  Future<RemoteSyncEntry> publishResolution(
    SyncEntry entry,
    Stream<List<int>> bytes, {
    required String operationId,
    required List<String> parents,
  }) => _publish(entry, bytes, operationId, parents);

  Future<RemoteSyncEntry> _publish(
    SyncEntry entry,
    Stream<List<int>> bytes,
    String operation,
    List<String> parents,
  ) async {
    validateSyncEntries({entry.key: entry});
    if (operation.isEmpty ||
        operation.length > 80 ||
        parents.length > 64 ||
        parents.toSet().length != parents.length) {
      throw const WorkspaceFailure('Invalid Drive publication operation.');
    }
    final inspected = _inspected;
    _inspected = null;
    final elapsed = inspected == null ? null : _now().difference(inspected.$2);
    // The engine just refreshed this exact key. Repeating the same read cannot
    // make append-only publication atomic; races still remain visible branches.
    // Expire tickets promptly, and never reuse one across another observation.
    if (inspected?.$1 != entry.key ||
        elapsed == null ||
        elapsed.isNegative ||
        elapsed > const Duration(seconds: 2)) {
      await _scan(entry.key);
    }
    final sortedParents = List<String>.from(parents)..sort();
    Map<String, dynamic>? plan = _operations[operation] == null
        ? null
        : Map<String, dynamic>.from(_operations[operation] as Map);
    if (plan != null) {
      if (!SyncEntry.fromJson(
            Map<String, dynamic>.from(plan['entry'] as Map),
          ).sameAs(entry) ||
          jsonEncode(plan['parents']) != jsonEncode(sortedParents)) {
        throw const WorkspaceConflict(
          'Publication operation was reused for different content.',
        );
      }
      final existing = _records[plan['record']];
      if (existing != null) {
        if (existing.operation != operation || !existing.entry.sameAs(entry)) {
          throw const WorkspaceConflict('Publication identity changed.');
        }
        return existing.remote;
      }
    }
    final heads = (_heads[entry.key] ?? []).map((r) => r.id).toList()..sort();
    if (jsonEncode(heads) != jsonEncode(sortedParents)) {
      throw const WorkspaceConflict(
        'Cloud content changed. Refresh and review before publishing.',
      );
    }
    final freshPlan = plan == null;
    if (plan == null) {
      if (_operations.length >= 10000 || _cache.length >= 10000) {
        throw const WorkspaceFailure(
          'Drive publication journal needs maintenance before more uploads.',
        );
      }
      final ids =
          (await api._request(
                vault.accountSubject,
                'GET',
                'files/generateIds',
                query: {'count': '2', 'space': 'drive', 'type': 'files'},
              ))['ids']
              as List;
      plan = {
        'entry': entry.toJson(),
        'parents': sortedParents,
        'blob': ids[0],
        'record': ids[1],
      };
      _operations[operation] = plan;
      await _save();
    }
    _operations[operation] = plan;
    final snapshot = await stage(bytes, entry.hash);
    try {
      await _uploadBlob(snapshot, plan, operation, fresh: freshPlan);
      final record = _DriveRevision(
        plan['record'] as String,
        entry,
        plan['blob'] as String,
        snapshot.length,
        sortedParents,
        operation,
      );
      final payload = utf8.encode(jsonEncode(record.toJson(workspaceId)));
      if (payload.length > 65536) {
        throw const WorkspaceFailure('Cloud revision is too large.');
      }
      const boundary = 'orbit-revision-boundary';
      final metadata = jsonEncode({
        'id': record.id,
        'name': '${record.id}.revision.json',
        'mimeType': 'application/json',
        'parents': [vault.folderId],
        'appProperties': {
          'orbitRole': 'sync-revision',
          'orbitProtocol': '2',
          'orbitVaultId': workspaceId,
          'orbitOp': operation,
          'orbitKey': sha256.convert(utf8.encode(entry.key)).toString(),
        },
      });
      final r = http.Request(
        'POST',
        Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
          'uploadType': 'multipart',
          'fields': GoogleDriveApi.fileFields,
        }),
      );
      r.headers['Content-Type'] = 'multipart/related; boundary=$boundary';
      r.bodyBytes = [
        ...utf8.encode(
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n--$boundary\r\nContent-Type: application/json\r\n\r\n',
        ),
        ...payload,
        ...utf8.encode('\r\n--$boundary--\r\n'),
      ];
      _DriveRevision? verified;
      try {
        final acknowledgement =
            jsonDecode((await _request(r)).body) as Map<String, dynamic>;
        if (acknowledgement['md5Checksum'] is String &&
            acknowledgement['appProperties'] is Map &&
            acknowledgement['parents'] is List &&
            acknowledgement['ownedByMe'] is bool &&
            acknowledgement['size'] != null) {
          final props = acknowledgement['appProperties'] as Map;
          if (acknowledgement['id'] != record.id ||
              acknowledgement['ownedByMe'] != true ||
              acknowledgement['trashed'] == true ||
              !(acknowledgement['parents'] as List).contains(vault.folderId) ||
              acknowledgement['md5Checksum'] !=
                  md5.convert(payload).toString() ||
              '${acknowledgement['size']}' != '${payload.length}' ||
              props['orbitRole'] != 'sync-revision' ||
              props['orbitProtocol'] != '2' ||
              props['orbitVaultId'] != workspaceId ||
              props['orbitOp'] != operation ||
              props['orbitKey'] !=
                  sha256.convert(utf8.encode(entry.key)).toString()) {
            throw const WorkspaceConflict(
              'Cloud publication acknowledgement changed.',
            );
          }
          // Google's checksum is over the stored payload. Combined with the
          // returned immutable identity this proves the same bytes as readback.
          verified = record;
        }
      } on Object {
        // A successful create with a lost reply is recovered by the same ID.
        final found = await _readRecord(record.id);
        if (jsonEncode(found.toJson(workspaceId)) !=
            jsonEncode(record.toJson(workspaceId))) {
          rethrow;
        }
        verified = found;
      }
      verified ??= await _readRecord(record.id);
      if (jsonEncode(verified.toJson(workspaceId)) !=
          jsonEncode(record.toJson(workspaceId))) {
        throw const WorkspaceConflict('Cloud publication verification failed.');
      }
      _cache[record.id] = {
        'checksum': md5.convert(payload).toString(),
        'record': verified.toJson(workspaceId),
      };
      final feed = _journal['changeFeed'];
      if (feed is Map && feed['ids'] is List) {
        // This is a verified immutable publication receipt, not a guessed
        // remote winner. Keep it even before Google's change feed indexes it.
        feed['ids'] = {
          ...List<String>.from(feed['ids'] as List),
          record.id,
        }.toList()..sort();
      }
      await _save();
      return verified.remote;
    } finally {
      await snapshot.close();
    }
  }

  Future<void> _uploadBlob(
    WorkspaceStage snapshot,
    Map<String, dynamic> plan,
    String operation, {
    required bool fresh,
  }) async {
    final id = plan['blob'] as String;
    final preparedDigest = snapshot is WorkspaceStageChecksums
        ? (snapshot as WorkspaceStageChecksums).md5Hash
        : null;
    final digest =
        preparedDigest ??
        (await md5.bind(snapshot.openRead()).first).toString();
    Future<bool> verified() async {
      Map<String, dynamic> f;
      try {
        f = jsonDecode((await _request(_get(id))).body) as Map<String, dynamic>;
      } on GoogleCloudError catch (e) {
        if (e.code == 'missing') return false;
        rethrow;
      }
      final p = f['appProperties'] as Map?;
      if (f['ownedByMe'] != true ||
          f['trashed'] == true ||
          !(f['parents'] as List? ?? []).contains(vault.folderId) ||
          p?['orbitRole'] != 'sync-blob' ||
          p?['orbitVaultId'] != workspaceId ||
          p?['orbitSha256'] != snapshot.hash ||
          '${f['size']}' != '${snapshot.length}' ||
          f['md5Checksum'] != digest) {
        throw const WorkspaceConflict(
          'Immutable cloud file verification failed.',
        );
      }
      return true;
    }

    // Fresh generated IDs have not been used by this operation. Create-only
    // uploads cannot replace another file. Replayed plans still inspect first.
    if (!fresh && await verified()) return;
    if (snapshot.length == 0) {
      final metadata = jsonEncode({
        'id': id,
        'name': '$id.blob',
        'mimeType': 'application/octet-stream',
        'parents': [vault.folderId],
        'appProperties': {
          'orbitRole': 'sync-blob',
          'orbitProtocol': '2',
          'orbitVaultId': workspaceId,
          'orbitSha256': snapshot.hash,
          'orbitOp': operation,
        },
      });
      const boundary = 'orbit-revision-boundary';
      final request = http.Request(
        'POST',
        Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
          'uploadType': 'multipart',
        }),
      );
      request.headers['Content-Type'] = 'multipart/related; boundary=$boundary';
      request.body =
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n--$boundary\r\nContent-Type: application/octet-stream\r\n\r\n\r\n--$boundary--\r\n';
      try {
        await _request(request);
      } on Object {
        if (!await verified()) rethrow;
      }
      if (!await verified()) {
        throw const WorkspaceConflict('Empty cloud file verification failed.');
      }
      return;
    }
    Uri? session = plan['session'] == null
        ? null
        : Uri.parse(plan['session'] as String);
    if (session != null) _session(session);
    var offset = 0;
    if (session != null) {
      try {
        final probe = http.Request('PUT', session)
          ..headers['Content-Range'] = 'bytes */${snapshot.length}';
        final response = await _request(probe);
        if (response.statusCode == 200 || response.statusCode == 201) {
          if (!await verified()) {
            throw const WorkspaceConflict(
              'Drive did not retain the completed file.',
            );
          }
          return;
        }
        offset = _offset(response, snapshot.length);
      } on GoogleCloudError catch (e) {
        if (e.code != 'missing') rethrow;
        session = null;
        plan.remove('session');
        await _save();
      }
    }
    if (session == null) {
      final r = http.Request(
        'POST',
        Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
          'uploadType': 'resumable',
        }),
      );
      r.headers.addAll({
        'Content-Type': 'application/json',
        'X-Upload-Content-Type': 'application/octet-stream',
        'X-Upload-Content-Length': '${snapshot.length}',
      });
      r.body = jsonEncode({
        'id': id,
        'name': '$id.blob',
        'mimeType': 'application/octet-stream',
        'parents': [vault.folderId],
        'appProperties': {
          'orbitRole': 'sync-blob',
          'orbitProtocol': '2',
          'orbitVaultId': workspaceId,
          'orbitSha256': snapshot.hash,
          'orbitOp': operation,
        },
      });
      final response = await _request(r);
      session = Uri.parse(response.headers['location'] ?? '');
      _session(session);
      plan['session'] = '$session';
      await _save();
    }
    var chunkBytes = 1024 * 1024;
    // Grow only after a quick acknowledged range; slow links shrink again.
    // Sizes stay 256-KiB aligned and bounded at 8 MiB, with original resume probes.
    await for (final chunk in _chunks(
      snapshot.openRead(),
      offset,
      () => chunkBytes,
    )) {
      final end = offset + chunk.length;
      final r = http.Request('PUT', session)..bodyBytes = chunk;
      r.headers.addAll({
        'Content-Type': 'application/octet-stream',
        'Content-Range': 'bytes $offset-${end - 1}/${snapshot.length}',
      });
      final watch = Stopwatch()..start();
      final response = await _request(r);
      watch.stop();
      if (end < snapshot.length) {
        if (_offset(response, snapshot.length) != end) {
          throw const WorkspaceConflict(
            'Drive upload offset changed. Retry from its status probe.',
          );
        }
      } else if (response.statusCode != 200 && response.statusCode != 201) {
        throw const WorkspaceConflict(
          'Drive did not acknowledge the final range.',
        );
      }
      offset = end;
      _check();
      onProgress?.call(offset, snapshot.length);
      if (watch.elapsed < const Duration(seconds: 2)) {
        chunkBytes = (chunkBytes * 2).clamp(256 * 1024, 8 * 1024 * 1024);
      } else if (watch.elapsed > const Duration(seconds: 8)) {
        chunkBytes = (chunkBytes ~/ 2).clamp(256 * 1024, 8 * 1024 * 1024);
      }
    }
    if (snapshot.length == 0) {
      final r = http.Request('PUT', session)
        ..headers['Content-Range'] = 'bytes */0';
      await _request(r);
    }
    if (!await verified()) {
      throw const WorkspaceConflict('Drive file verification is incomplete.');
    }
  }

  static void _session(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host != 'www.googleapis.com' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !uri.path.startsWith('/upload/drive/v3/files')) {
      throw const WorkspaceConflict('Invalid Drive upload session.');
    }
  }

  static int _offset(http.Response r, int total) {
    if (r.statusCode != 308) {
      throw const WorkspaceConflict('Unexpected resumable upload response.');
    }
    final range = r.headers['range'];
    final match = range == null
        ? null
        : RegExp(r'^bytes=0-(\d+)$').firstMatch(range);
    if (range != null && match == null) {
      throw const WorkspaceConflict('Invalid Drive upload range.');
    }
    final offset = match == null ? 0 : int.parse(match[1]!) + 1;
    if (offset < 0 || offset >= total) {
      throw const WorkspaceConflict('Invalid Drive upload range.');
    }
    return offset;
  }

  static Stream<List<int>> _chunks(
    Stream<List<int>> source,
    int start,
    int Function() chunkSize,
  ) async* {
    var skip = start;
    var buffer = BytesBuilder(copy: false);
    await for (var part in source) {
      if (skip >= part.length) {
        skip -= part.length;
        continue;
      }
      if (skip > 0) {
        part = part.sublist(skip);
        skip = 0;
      }
      var index = 0;
      while (index < part.length) {
        final target = chunkSize();
        final end = (index + target - buffer.length).clamp(index, part.length);
        buffer.add(part.sublist(index, end));
        index = end;
        if (buffer.length == target) {
          yield buffer.takeBytes();
          buffer = BytesBuilder(copy: false);
        }
      }
    }
    if (buffer.length > 0) yield buffer.takeBytes();
  }
}
