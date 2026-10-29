part of 'google_drive_api.dart';

class GoogleDriveBackup {
  const GoogleDriveBackup(
    this.id,
    this.name,
    this.workspaceId,
    this.subject,
    this.size,
    this.checksum,
  );
  final String id, name, workspaceId, subject, checksum;
  final int size;
}

extension GoogleDriveBackups on GoogleDriveApi {
  Future<List<GoogleDriveBackup>> listBackups() async {
    final subject = _subject();
    final entries = await _list(
      subject,
      "trashed = false and 'me' in owners and appProperties has { key='orbitRole' and value='backup' }",
    );
    return entries
        .where((v) => (v['appProperties'] as Map?)?['orbitProtocol'] == '1')
        .map((v) {
          final properties = v['appProperties'] as Map;
          final size = int.tryParse('${v['size']}');
          if (size == null ||
              size < 0 ||
              size > BackupBundle.maxEncodedBytes ||
              properties['orbitSha256'] is! String ||
              properties['orbitVaultId'] is! String) {
            throw const GoogleCloudError(
              'backup',
              'A Drive backup has invalid metadata. No local files were changed.',
            );
          }
          return GoogleDriveBackup(
            v['id'] as String,
            v['name'] as String,
            properties['orbitVaultId'] as String,
            subject,
            size,
            properties['orbitSha256'] as String,
          );
        })
        .toList()
      ..sort((a, b) => b.name.compareTo(a.name));
  }

  Future<http.Response> _backupRequest(
    String subject,
    http.Request request,
  ) async {
    _account(subject);
    for (var attempt = 0; attempt < 2; attempt++) {
      final outgoing = http.Request(request.method, request.url)
        ..followRedirects = false
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      outgoing.headers['Authorization'] =
          'Bearer ${await auth.accessToken(refresh: attempt > 0)}';
      GoogleDriveApi._compressionHeaders(outgoing);
      _account(subject);
      final response = await http.Response.fromStream(
        await client.send(outgoing).timeout(const Duration(seconds: 45)),
      ).timeout(const Duration(seconds: 45));
      _account(subject);
      if (response.statusCode == 401 && attempt == 0) continue;
      if (response.statusCode == 404 || response.statusCode == 410) {
        throw const GoogleCloudError(
          'missing',
          'This Drive transfer is no longer available. Start it again.',
        );
      }
      if (response.statusCode >= 400) {
        throw _responseError(response);
      }
      return response;
    }
    throw const GoogleCloudError(
      'reauth',
      'Reconnect Google Drive to continue.',
    );
  }

  /// An immutable backup, not a last-write-wins replica of live owning files.
  Future<GoogleDriveBackup> uploadBackup(
    String source, {
    void Function(int sent, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final subject = _subject();
    final bundle = BackupBundle.parse(source);
    if (isCancelled?.call() == true) {
      throw const GoogleCloudError(
        'cancelled',
        'Upload cancelled before transfer.',
      );
    }
    final bytes = Uint8List.fromList(utf8.encode(source));
    if (bytes.length > BackupBundle.maxEncodedBytes) {
      throw const GoogleCloudError(
        'size',
        'This backup exceeds the 128 MiB transfer limit.',
      );
    }
    final root = await ensureRoot();
    _account(subject);
    final workspace =
        (jsonDecode(utf8.decode(bundle.files['workspace.json']!)) as Map)['id']
            as String;
    final checksum = sha256.convert(bytes).toString();
    final cleanName = bundle.name.replaceAll(RegExp(r'[\r\n]'), ' ');
    final name =
        '${cleanName.substring(0, cleanName.length.clamp(0, 100))} ${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.orbit-backup.json';
    final generated = await _request(
      subject,
      'GET',
      'files/generateIds',
      query: {'count': '1', 'space': 'drive', 'type': 'files'},
    );
    final id = (generated['ids'] as List).single as String;
    final start = http.Request(
      'POST',
      Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
        'uploadType': 'resumable',
        'fields': GoogleDriveApi.fileFields,
      }),
    );
    start.headers.addAll({
      'Content-Type': 'application/json',
      'X-Upload-Content-Type': 'application/json',
      'X-Upload-Content-Length': '${bytes.length}',
    });
    start.body = jsonEncode({
      'id': id,
      'name': name,
      'mimeType': 'application/json',
      'parents': [root],
      'appProperties': {
        'orbitRole': 'backup',
        'orbitProtocol': '1',
        'orbitVaultId': workspace,
        'orbitSha256': checksum,
      },
    });
    final response = await _backupRequest(subject, start);
    final session = Uri.tryParse(response.headers['location'] ?? '');
    if (session == null ||
        session.scheme != 'https' ||
        session.host != 'www.googleapis.com' ||
        session.port != 443 ||
        !session.path.startsWith('/upload/drive/v3/files') ||
        session.userInfo.isNotEmpty) {
      throw const GoogleCloudError(
        'session',
        'Drive returned an invalid upload session.',
      );
    }
    var offset = 0, attempts = 0;
    while (offset < bytes.length) {
      if (isCancelled?.call() == true) {
        throw const GoogleCloudError(
          'cancelled',
          'Upload cancelled. Local files are unchanged; an incomplete Drive upload may expire automatically.',
        );
      }
      final end = (offset + 1024 * 1024).clamp(0, bytes.length);
      final chunk = http.Request('PUT', session);
      chunk.headers.addAll({
        'Content-Type': 'application/json',
        'Content-Range': 'bytes $offset-${end - 1}/${bytes.length}',
      });
      chunk.bodyBytes = bytes.sublist(offset, end);
      http.Response received;
      try {
        received = await _backupRequest(subject, chunk);
      } on Object catch (error) {
        if (error is GoogleCloudError &&
            !{'offline', 'rate'}.contains(error.code)) {
          rethrow;
        }
        if (++attempts > 3) {
          throw const GoogleCloudError(
            'offline',
            'Transfer interrupted. Reconnect and retry; your local Vault is safe.',
          );
        }
        while (true) {
          await wait(Duration(seconds: 1 << (attempts - 1)));
          if (isCancelled?.call() == true) {
            throw const GoogleCloudError(
              'cancelled',
              'Upload cancelled. Local files are unchanged.',
            );
          }
          final probe = http.Request('PUT', session)
            ..headers['Content-Range'] = 'bytes */${bytes.length}';
          try {
            received = await _backupRequest(subject, probe);
            break;
          } on Object catch (error) {
            if (error is GoogleCloudError &&
                !{'offline', 'rate'}.contains(error.code)) {
              rethrow;
            }
            if (++attempts > 3) {
              throw const GoogleCloudError(
                'offline',
                'Transfer interrupted. Reconnect and retry; your local Vault is safe.',
              );
            }
          }
        }
      }
      if (received.statusCode == 200 || received.statusCode == 201) {
        if ((jsonDecode(received.body) as Map)['id'] != id) {
          throw const GoogleCloudError(
            'identity',
            'Drive returned an unexpected backup identity.',
          );
        }
        offset = bytes.length;
      } else if (received.statusCode == 308) {
        final range = received.headers['range'];
        final match = range == null
            ? null
            : RegExp(r'^bytes=0-(\d+)$').firstMatch(range);
        final next = match == null ? 0 : int.parse(match[1]!) + 1;
        if (next < offset || next > end || next == bytes.length) {
          throw const GoogleCloudError(
            'range',
            'Drive returned an invalid upload acknowledgement.',
          );
        }
        if (next == offset && ++attempts > 3) {
          throw const GoogleCloudError(
            'transfer',
            'Drive did not accept the upload. Try again later.',
          );
        }
        if (next > offset) attempts = 0;
        offset = next;
      } else {
        throw const GoogleCloudError(
          'transfer',
          'Drive returned an unexpected transfer response.',
        );
      }
      onProgress?.call(offset, bytes.length);
    }
    final verified = await _request(
      subject,
      'GET',
      'files/${Uri.encodeComponent(id)}',
      query: {'fields': GoogleDriveApi.fileFields},
    );
    if (verified['id'] != id ||
        verified['ownedByMe'] != true ||
        '${verified['size']}' != '${bytes.length}' ||
        verified['md5Checksum'] != md5.convert(bytes).toString() ||
        (verified['appProperties'] as Map?)?['orbitSha256'] != checksum) {
      throw const GoogleCloudError(
        'checksum',
        'Drive upload verification failed. Keep your local backup and inspect Drive before retrying.',
      );
    }
    return GoogleDriveBackup(
      id,
      name,
      workspace,
      subject,
      bytes.length,
      checksum,
    );
  }

  Future<String> downloadBackup(
    GoogleDriveBackup backup, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    _account(backup.subject);
    final metadata = await _request(
      backup.subject,
      'GET',
      'files/${Uri.encodeComponent(backup.id)}',
      query: {'fields': GoogleDriveApi.fileFields},
    );
    final properties = metadata['appProperties'] as Map?;
    if (metadata['ownedByMe'] != true ||
        metadata['trashed'] == true ||
        properties?['orbitRole'] != 'backup' ||
        properties?['orbitProtocol'] != '1' ||
        properties?['orbitVaultId'] != backup.workspaceId ||
        properties?['orbitSha256'] != backup.checksum ||
        '${metadata['size']}' != '${backup.size}') {
      throw const GoogleCloudError(
        'identity',
        'This backup changed or belongs to another account. Refresh the list.',
      );
    }
    final request = http.Request(
      'GET',
      Uri.https(
        'www.googleapis.com',
        '/drive/v3/files/${Uri.encodeComponent(backup.id)}',
        {'alt': 'media'},
      ),
    );
    request.followRedirects = false;
    request.headers['Authorization'] = 'Bearer ${await auth.accessToken()}';
    _account(backup.subject);
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw const GoogleCloudError(
        'transfer',
        'The backup could not be downloaded.',
      );
    }
    final output = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 45),
    )) {
      _account(backup.subject);
      if (isCancelled?.call() == true) {
        throw const GoogleCloudError(
          'cancelled',
          'Download cancelled. Your local Vault is unchanged.',
        );
      }
      if (output.length + chunk.length > backup.size ||
          output.length + chunk.length > BackupBundle.maxEncodedBytes) {
        throw const GoogleCloudError(
          'size',
          'The downloaded backup exceeds its declared size.',
        );
      }
      output.add(chunk);
      onProgress?.call(output.length, backup.size);
    }
    final bytes = output.takeBytes();
    _account(backup.subject);
    if (bytes.length != backup.size ||
        sha256.convert(bytes).toString() != backup.checksum) {
      throw const GoogleCloudError(
        'checksum',
        'Backup verification failed. Nothing was restored.',
      );
    }
    final source = utf8.decode(bytes);
    final bundle = BackupBundle.parse(source);
    if ((jsonDecode(utf8.decode(bundle.files['workspace.json']!))
            as Map)['id'] !=
        backup.workspaceId) {
      throw const GoogleCloudError(
        'identity',
        'Backup Vault identity does not match.',
      );
    }
    return source;
  }
}
