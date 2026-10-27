part of 'google_drive_api.dart';

/// A reviewed snapshot, scoped to this exact account/Vault. Graph metadata is
/// never removed: only old, superseded payloads can expire. No automatic GC.
class DriveRetentionPlan {
  DriveRetentionPlan._(
    this.binding,
    this.fingerprint,
    this.created,
    this.items, {
    this.receipt,
  });
  final String binding, fingerprint, created;
  final List<Map<String, dynamic>> items;
  final String? receipt;
  int get files => items.length;
  int get bytes => items.fold(0, (total, v) => total + (v['size'] as int));
  Map<String, dynamic> _json() => {
    'binding': binding,
    'fingerprint': fingerprint,
    'created': created,
    'items': items,
    if (receipt != null) 'receipt': receipt,
  };
}

extension GoogleDriveRetention on GoogleDriveSyncProvider {
  String _retentionFingerprint() {
    final ids = _records.keys.toList()..sort();
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              bindingId,
              for (final id in ids) [id, _cache[id]['checksum']],
            ]),
          ),
        )
        .toString();
  }

  /// Preserve at least 20 revisions per object and all payloads for any object
  /// changed in the last 90 days. An incomplete/untrusted listing cannot prune.
  Future<DriveRetentionPlan> previewRetention() async {
    await _scan(null);
    if (_heads.values.any((heads) => heads.length != 1)) {
      throw const WorkspaceConflict(
        'Review cloud conflicts before cleaning history.',
      );
    }
    final pending = _journal['retentionPending'];
    if (pending != null) {
      final plan = _parseRetention(pending);
      _validateRetention(plan);
      return plan;
    }
    final files = await api._list(
      vault.accountSubject,
      "trashed = false and 'me' in owners and '${api._quoted(vault.folderId)}' in parents and appProperties has { key='orbitRole' and value='sync-revision' }",
    );
    final listed = {for (final f in files) f['id']: f};
    if (listed.length != files.length ||
        listed.length != _records.length ||
        !_records.keys.every(listed.containsKey)) {
      throw const WorkspaceConflict(
        'Cloud history changed. Review a fresh cleanup preview.',
      );
    }
    for (final f in files) {
      await _acceptRevision(
        f,
      ); // Recheck immutable checksums on the second listing.
    }
    final cutoff = _now().toUtc().subtract(const Duration(days: 90));
    final grouped = <String, List<_DriveRevision>>{};
    for (final record in _records.values) {
      (grouped[record.entry.key] ??= []).add(record);
    }
    final items = <Map<String, dynamic>>[];
    for (final records in grouped.values) {
      final dates = <String, DateTime>{};
      for (final r in records) {
        final date = DateTime.tryParse('${listed[r.id]?['modifiedTime']}');
        if (date != null) dates[r.id] = date.toUtc();
      }
      if (dates.length != records.length ||
          dates.values.any((d) => !d.isBefore(cutoff))) {
        continue;
      }
      records.sort((a, b) {
        final c = dates[b.id]!.compareTo(dates[a.id]!);
        return c == 0 ? a.id.compareTo(b.id) : c;
      });
      final protected = records.take(20).map((r) => r.id).toSet()
        ..addAll(_heads[records.first.entry.key]!.map((r) => r.id));
      for (final r in records) {
        if (protected.contains(r.id) ||
            r.size == 0 ||
            items.length >= 200 ||
            _records.values.any(
              (other) => other.id != r.id && other.blob == r.blob,
            )) {
          continue;
        }
        try {
          final f =
              jsonDecode((await _request(_get(r.blob))).body)
                  as Map<String, dynamic>;
          _validateRetentionBlob(r, f);
          items.add(
            Map.unmodifiable({
              'record': r.id,
              'blob': r.blob,
              'size': r.size,
              'hash': r.entry.hash,
              'checksum': _cache[r.id]['checksum'],
            }),
          );
        } on GoogleCloudError catch (e) {
          if (e.code != 'missing') rethrow;
        }
      }
    }
    return DriveRetentionPlan._(
      bindingId,
      _retentionFingerprint(),
      _now().toUtc().toIso8601String(),
      List.unmodifiable(items),
    );
  }

  DriveRetentionPlan _parseRetention(dynamic value) {
    if (value is! Map ||
        value['binding'] != bindingId ||
        value['fingerprint'] is! String ||
        value['created'] is! String ||
        DateTime.tryParse(value['created']) == null ||
        value['receipt'] is! String ||
        !_driveId.hasMatch(value['receipt']) ||
        value['items'] is! List ||
        (value['items'] as List).length > 200) {
      throw const WorkspaceConflict(
        'Saved cleanup needs recovery. No cloud files were removed.',
      );
    }
    final items = <Map<String, dynamic>>[];
    for (final v in value['items'] as List) {
      if (v is! Map ||
          v['record'] is! String ||
          v['blob'] is! String ||
          v['size'] is! int ||
          v['hash'] is! String ||
          v['checksum'] is! String) {
        throw const WorkspaceConflict(
          'Saved cleanup is damaged. No cloud files were removed.',
        );
      }
      items.add(Map.unmodifiable(Map<String, dynamic>.from(v)));
    }
    return DriveRetentionPlan._(
      bindingId,
      value['fingerprint'],
      value['created'],
      List.unmodifiable(items),
      receipt: value['receipt'],
    );
  }

  void _validateRetention(DriveRetentionPlan plan) {
    final protected = {
      for (final heads in _heads.values)
        for (final r in heads) r.blob,
    };
    final seen = <String>{};
    for (final item in plan.items) {
      final r = _records[item['record']];
      if (r == null ||
          r.blob != item['blob'] ||
          r.size != item['size'] ||
          r.entry.hash != item['hash'] ||
          _cache[r.id]['checksum'] != item['checksum'] ||
          !seen.add(r.blob) ||
          protected.contains(r.blob) ||
          _records.values.any(
            (other) => other.id != r.id && other.blob == r.blob,
          )) {
        throw const WorkspaceConflict(
          'Cleanup no longer matches the retained history. No current content was removed.',
        );
      }
    }
  }

  void _validateRetentionBlob(_DriveRevision r, Map<String, dynamic> f) {
    final properties = f['appProperties'] as Map?;
    if (f['id'] != r.blob ||
        f['ownedByMe'] != true ||
        f['trashed'] == true ||
        !(f['parents'] as List? ?? []).contains(vault.folderId) ||
        properties?['orbitRole'] != 'sync-blob' ||
        properties?['orbitProtocol'] != '2' ||
        properties?['orbitVaultId'] != workspaceId ||
        properties?['orbitOp'] != r.operation ||
        properties?['orbitSha256'] != r.entry.hash ||
        '${f['size']}' != '${r.size}') {
      throw const WorkspaceConflict(
        'An old payload changed identity. Cleanup stopped.',
      );
    }
  }

  Future<void> _publishRetentionReceipt(DriveRetentionPlan plan) async {
    final id = plan.receipt!;
    final body = utf8.encode(
      jsonEncode({
        'format': 'orbit-drive-retention',
        'version': 1,
        'workspaceId': workspaceId,
        ...plan._json(),
      }),
    );
    if (body.length > 128 * 1024) {
      throw const WorkspaceFailure('Cleanup receipt is too large.');
    }
    Future<bool> verified() async {
      Map<String, dynamic> f;
      try {
        f = jsonDecode((await _request(_get(id))).body) as Map<String, dynamic>;
      } on GoogleCloudError catch (e) {
        if (e.code == 'missing') return false;
        rethrow;
      }
      final properties = f['appProperties'] as Map?;
      if (f['ownedByMe'] != true ||
          f['trashed'] == true ||
          f['id'] != id ||
          !(f['parents'] as List? ?? []).contains(vault.folderId) ||
          properties?['orbitRole'] != 'sync-retention' ||
          properties?['orbitVaultId'] != workspaceId ||
          f['md5Checksum'] != md5.convert(body).toString() ||
          '${f['size']}' != '${body.length}') {
        throw const WorkspaceConflict(
          'Cleanup receipt identity changed. Nothing further was removed.',
        );
      }
      return true;
    }

    if (await verified()) return;
    const boundary = 'orbit-retention-boundary';
    final metadata = jsonEncode({
      'id': id,
      'name': '$id.retention.json',
      'mimeType': 'application/json',
      'parents': [vault.folderId],
      'appProperties': {
        'orbitRole': 'sync-retention',
        'orbitProtocol': '3',
        'orbitVaultId': workspaceId,
      },
    });
    final request = http.Request(
      'POST',
      Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
        'uploadType': 'multipart',
      }),
    );
    request.headers['Content-Type'] = 'multipart/related; boundary=$boundary';
    request.bodyBytes = [
      ...utf8.encode(
        '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n--$boundary\r\nContent-Type: application/json\r\n\r\n',
      ),
      ...body,
      ...utf8.encode('\r\n--$boundary--\r\n'),
    ];
    try {
      await _request(request);
    } on Object {
      if (!await verified()) {
        rethrow;
      }
    }
    if (!await verified()) {
      throw const WorkspaceConflict('Cleanup receipt was not retained.');
    }
  }

  /// Explicit reviewed action. A durable plan + immutable cloud receipt precede
  /// protocol upgrade and every delete. Retry uses the same receipt and IDs.
  Future<int> applyRetention(DriveRetentionPlan reviewed) async {
    if (reviewed.binding != bindingId) {
      throw const WorkspaceConflict('Account or Vault changed.');
    }
    await _scan(null);
    if (_heads.values.any((heads) => heads.length != 1)) {
      throw const WorkspaceConflict('Review conflicts before cleanup.');
    }
    final pending = _journal['retentionPending'];
    DriveRetentionPlan plan;
    if (pending != null) {
      plan = _parseRetention(pending);
      if (jsonEncode(plan._json()) != jsonEncode(reviewed._json())) {
        throw const WorkspaceConflict('Another cleanup must be resumed first.');
      }
    } else {
      if (reviewed.fingerprint != _retentionFingerprint()) {
        throw const WorkspaceConflict(
          'Cloud changed. Review a fresh cleanup preview.',
        );
      }
      _validateRetention(reviewed);
      if (reviewed.items.isEmpty) return 0;
      final ids = await api._request(
        vault.accountSubject,
        'GET',
        'files/generateIds',
        query: {'count': '1', 'space': 'drive', 'type': 'files'},
      );
      plan = DriveRetentionPlan._(
        bindingId,
        reviewed.fingerprint,
        reviewed.created,
        reviewed.items,
        receipt: (ids['ids'] as List).single as String,
      );
      _journal['retentionPending'] = plan._json();
      await _save();
    }
    _validateRetention(plan);
    await _publishRetentionReceipt(plan);
    // Older clients cannot sync a Vault whose obsolete payloads have expired.
    await api._request(
      vault.accountSubject,
      'PATCH',
      'files/${Uri.encodeComponent(vault.folderId)}',
      body: {
        'appProperties': {
          'orbitProtocol': '3',
          'orbitRetention': 'head-blobs-v1',
        },
      },
      query: {'fields': GoogleDriveApi.fileFields},
    );
    await api.verifySyncVault(vault);
    var reclaimed = 0;
    for (final item in plan.items) {
      _check();
      final r = _records[item['record']]!;
      try {
        final f =
            jsonDecode((await _request(_get(r.blob))).body)
                as Map<String, dynamic>;
        _validateRetentionBlob(r, f);
        await _request(
          http.Request(
            'DELETE',
            Uri.https(
              'www.googleapis.com',
              '/drive/v3/files/${Uri.encodeComponent(r.blob)}',
            ),
          ),
        );
      } on GoogleCloudError catch (e) {
        if (e.code != 'missing') rethrow;
      }
      reclaimed += r.size;
    }
    _journal['retentionCompleted'] = {
      'receipt': plan.receipt,
      'finished': _now().toUtc().toIso8601String(),
      'bytes': reclaimed,
    };
    _journal.remove('retentionPending');
    await _save();
    return reclaimed;
  }
}
