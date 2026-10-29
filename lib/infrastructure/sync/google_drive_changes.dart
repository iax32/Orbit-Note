part of 'google_drive_api.dart';

/// Drive's account change feed replaces repeated history listings, not the
/// immutable revision graph or the engine's conflict/draft checks. Its checkpoint
/// and complete inventory are saved together; engine observations remain reset
/// snapshots so a crash between the two checkpoints cannot skip remote content.
extension _DriveChangeFeed on GoogleDriveSyncProvider {
  Future<SyncDelta> _fetchChanges() async {
    _inspected = null;
    await _load();
    final feed = _journal['changeFeed'];
    final now = _now().toUtc();
    if (feed is! Map ||
        !_validToken(feed['token']) ||
        feed['ids'] is! List ||
        (feed['ids'] as List).length > 10000 ||
        feed['fullScanAt'] is! int ||
        now.millisecondsSinceEpoch < (feed['fullScanAt'] as int) ||
        now.millisecondsSinceEpoch - (feed['fullScanAt'] as int) >=
            const Duration(minutes: 15).inMilliseconds) {
      return _fullInventory();
    }
    final ids = List<String>.from(feed['ids'] as List).toSet();
    if (ids.length != (feed['ids'] as List).length ||
        ids.any((id) => !_cache.containsKey(id))) {
      return _fullInventory();
    }
    await api.verifySyncVault(vault);
    _check();
    _records.clear();
    for (final id in ids) {
      _records[id] = _DriveRevision.parse(
        id,
        Map<String, dynamic>.from((_cache[id] as Map)['record'] as Map),
        workspaceId,
      );
    }
    var token = feed['token'] as String;
    final seen = <String>{token};
    var count = 0;
    for (var page = 0; page < 100; page++) {
      Map<String, dynamic> response;
      try {
        response = await api._request(
          vault.accountSubject,
          'GET',
          'changes',
          query: {
            'pageToken': token,
            'pageSize': '1000',
            'spaces': 'drive',
            'includeRemoved': 'true',
            'includeCorpusRemovals': 'true',
            'restrictToMyDrive': 'true',
            'fields':
                'nextPageToken,newStartPageToken,changes(fileId,removed,file(${GoogleDriveApi.fileFields}))',
          },
        );
      } on GoogleCloudError catch (e) {
        // Never advance past an invalid cursor. A new baseline starts BEFORE
        // listing, so changes racing the listing are replayed on the next pass.
        if (e.code == 'cursor') return _fullInventory();
        rethrow;
      }
      _check();
      // Google may omit an empty repeated field in a partial response.
      final changes = response['changes'] ?? const <dynamic>[];
      if (changes is! List || (count += changes.length) > 100000) {
        throw const GoogleCloudError(
          'listing',
          'Incomplete Drive change feed.',
        );
      }
      final revisions = <Map<String, dynamic>>[], observedIds = <String>{};
      for (final raw in changes) {
        if (raw is! Map || raw['fileId'] is! String) {
          throw const GoogleCloudError('listing', 'Unreadable Drive change.');
        }
        final id = raw['fileId'] as String;
        final known = _cache.containsKey(id) || observedIds.contains(id);
        final f = raw['file'];
        final candidate =
            f is Map &&
            (f['parents'] as List? ?? []).contains(vault.folderId) &&
            (f['appProperties'] as Map?)?['orbitRole'] == 'sync-revision';
        if (known && (raw['removed'] == true || !candidate)) {
          throw const WorkspaceConflict(
            'A retained cloud revision disappeared or moved. Restore it in Drive before syncing again.',
          );
        }
        if (raw['removed'] == true) continue;
        if (f is! Map || f['id'] != id) {
          throw const GoogleCloudError(
            'listing',
            'Incomplete Drive change metadata.',
          );
        }
        if (!candidate) continue;
        revisions.add(Map<String, dynamic>.from(f));
        observedIds.add(id);
      }
      await _acceptRevisions(revisions);
      final next = response['nextPageToken'];
      if (next != null) {
        if (!_validToken(next) || !seen.add(next as String)) {
          throw const GoogleCloudError(
            'listing',
            'Drive change pagination did not finish.',
          );
        }
        token = next;
        continue;
      }
      final completed = response['newStartPageToken'];
      if (!_validToken(completed)) {
        throw const GoogleCloudError(
          'listing',
          'Drive change checkpoint is missing.',
        );
      }
      _journal['changeFeed'] = {
        ...Map<String, dynamic>.from(feed),
        'token': completed,
        'ids': _records.keys.toList()..sort(),
      };
      // Validate all parents/branches before persisting either data or cursor.
      return _buildDelta(
        null,
        persist: completed != feed['token'] || count > 0,
      );
    }
    throw const GoogleCloudError(
      'listing',
      'Drive change feed exceeded its page limit.',
    );
  }

  Future<SyncDelta> _fullInventory() async {
    _check();
    final start = await api._request(
      vault.accountSubject,
      'GET',
      'changes/startPageToken',
      query: {'fields': 'startPageToken'},
    );
    final token = start['startPageToken'];
    if (!_validToken(token)) {
      throw const GoogleCloudError(
        'listing',
        'Drive change checkpoint is missing.',
      );
    }
    final result = await _scan(null);
    _journal['changeFeed'] = {
      'token': token,
      'ids': _records.keys.toList()..sort(),
      'fullScanAt': _now().toUtc().millisecondsSinceEpoch,
    };
    await _save();
    return result;
  }

  static bool _validToken(Object? token) =>
      token is String && token.isNotEmpty && token.length <= 4096;
}
