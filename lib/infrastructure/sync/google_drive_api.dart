import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../../application/sync/google_account.dart';
import '../../application/backup_bundle.dart';
import '../../application/sync/sync_provider.dart';
import '../../application/sync/sync_policy.dart';
import '../../domain/sync_entry.dart';
import '../../domain/workspace_failure.dart';
import '../storage/workspace_store.dart';

part 'google_drive_backups.dart';
part 'google_drive_replica.dart';

class GoogleRemoteVault {
  const GoogleRemoteVault({
    required this.folderId,
    required this.workspaceId,
    required this.name,
    required this.accountSubject,
    this.modified,
  });
  final String folderId, workspaceId, name, accountSubject;
  final DateTime? modified;
}

/// Account/discovery adapter. Auth never crosses into the repository or editor.
/// This deliberately does not claim SyncProvider's conditional publication
/// capability: Drive mutation race safety needs its own conformance proof.
class GoogleDriveApi {
  GoogleDriveApi({
    required this.auth,
    required this.client,
    required this.localMetadata,
    Future<void> Function(Duration)? wait,
  }) : wait = wait ?? Future<void>.delayed;
  final GoogleAccountAuth auth;
  final http.Client client;
  final GoogleCredentialStore localMetadata;
  final Future<void> Function(Duration) wait;
  Future<void> _rootOperations = Future<void>.value();
  static const folderMime = 'application/vnd.google-apps.folder';
  static const fileFields =
      'id,name,mimeType,parents,appProperties,trashed,modifiedTime,size,ownedByMe,md5Checksum';
  void _account(String subject) {
    if (auth.account?.subject != subject) {
      throw const GoogleCloudError(
        'account',
        'The Google account changed. Start this action again.',
      );
    }
  }

  String _subject() =>
      auth.account?.subject ??
      (throw const GoogleCloudError(
        'reauth',
        'Connect Google Drive to continue.',
      ));

  Future<Map<String, dynamic>> _request(
    String subject,
    String method,
    String path, {
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
  }) async {
    _account(subject);
    for (var attempt = 0; attempt < 2; attempt++) {
      _account(subject);
      final token = await auth.accessToken(refresh: attempt > 0);
      _account(subject);
      final request = http.Request(
        method,
        Uri.https('www.googleapis.com', '/drive/v3/$path', query),
      );
      request.followRedirects = false;
      request.headers['Authorization'] = 'Bearer $token';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      http.Response response;
      try {
        response = await http.Response.fromStream(
          await client.send(request).timeout(const Duration(seconds: 30)),
        ).timeout(const Duration(seconds: 30));
      } on Object {
        throw const GoogleCloudError(
          'offline',
          'Google Drive is unavailable. Your local Vault remains available.',
        );
      }
      _account(subject);
      if (response.statusCode == 401 && attempt == 0) continue;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _responseError(response);
      }
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } on Object {
        throw const GoogleCloudError(
          'response',
          'Google Drive returned an unreadable response.',
        );
      }
    }
    throw const GoogleCloudError('reauth', 'Reconnect Google Drive.');
  }

  GoogleCloudError _responseError(http.Response response) {
    String reason = '';
    try {
      reason =
          ((jsonDecode(response.body)['error']['errors'] as List).first
                  as Map)['reason']
              as String? ??
          '';
    } on Object {
      /* Sanitized fallback below. */
    }
    if (reason == 'storageQuotaExceeded') {
      return const GoogleCloudError(
        'quota',
        'Google storage is full. Your local files are safe.',
      );
    }
    if (reason == 'accessNotConfigured' || reason == 'serviceDisabled') {
      return const GoogleCloudError(
        'configuration',
        'The Google Drive API is disabled for this app project. Enable Google Drive API in Google Cloud, then use Refresh account. Signing in again will not fix this.',
      );
    }
    if ({
      'rateLimitExceeded',
      'userRateLimitExceeded',
      'dailyLimitExceeded',
    }.contains(reason)) {
      return const GoogleCloudError(
        'rate',
        'Google Drive has reached a request limit. Wait before retrying; signing in again will not fix this.',
      );
    }
    return switch (response.statusCode) {
      401 => const GoogleCloudError(
        'reauth',
        'Google Drive needs to be connected again.',
      ),
      403 => const GoogleCloudError(
        'permission',
        'Orbit no longer has access to these Google Drive files.',
      ),
      404 => const GoogleCloudError(
        'missing',
        'This Google Drive folder is no longer available.',
      ),
      429 => const GoogleCloudError(
        'rate',
        'Google Drive is temporarily busy. Try again shortly.',
      ),
      >= 500 => const GoogleCloudError(
        'offline',
        'Google Drive is temporarily unavailable.',
      ),
      _ => const GoogleCloudError(
        'provider',
        'Google Drive could not complete this action.',
      ),
    };
  }

  Future<GoogleStorageQuota> quota() async => GoogleStorageQuota.fromJson(
    await _request(
      _subject(),
      'GET',
      'about',
      query: {
        'fields':
            'storageQuota(limit,usage,usageInDrive,usageInDriveTrash),maxUploadSize',
      },
    ),
  );

  String _quoted(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
  Future<List<Map<String, dynamic>>> _list(String subject, String query) async {
    final files = <Map<String, dynamic>>[];
    String? page;
    final seen = <String>{};
    do {
      final response = await _request(
        subject,
        'GET',
        'files',
        query: {
          'q': query,
          'spaces': 'drive',
          'pageSize': '1000',
          'fields': 'nextPageToken,incompleteSearch,files($fileFields)',
          'pageToken': ?page,
        },
      );
      if (response['incompleteSearch'] == true) {
        throw const GoogleCloudError(
          'listing',
          'Google Drive returned an incomplete Vault list. Try again.',
        );
      }
      files.addAll(
        (response['files'] as List).map(
          (v) => Map<String, dynamic>.from(v as Map),
        ),
      );
      page = response['nextPageToken'] as String?;
      if (page != null && !seen.add(page)) {
        throw const GoogleCloudError(
          'listing',
          'Google Drive could not finish listing Vaults.',
        );
      }
    } while (page != null);
    return files;
  }

  Future<List<GoogleRemoteVault>> listVaults() async {
    final subject = _subject();
    final files = await _list(
      subject,
      "trashed = false and 'me' in owners and mimeType = '$folderMime' and appProperties has { key='orbitRole' and value='vault' }",
    );
    _account(subject);
    final result = <GoogleRemoteVault>[];
    for (final f in files) {
      final properties = f['appProperties'] as Map? ?? const {};
      final id = properties['orbitVaultId'];
      if (id is! String || id.isEmpty || properties['orbitProtocol'] != '1') {
        continue;
      }
      result.add(
        GoogleRemoteVault(
          folderId: f['id'] as String,
          workspaceId: id,
          name: f['name'] as String? ?? 'Orbit Vault',
          accountSubject: subject,
          modified: DateTime.tryParse('${f['modifiedTime']}'),
        ),
      );
    }
    return result;
  }

  Future<Map<String, dynamic>> inspectVault(GoogleRemoteVault vault) async {
    final subject = vault.accountSubject;
    _account(subject);
    final folder = await _request(
      subject,
      'GET',
      'files/${Uri.encodeComponent(vault.folderId)}',
      query: {'fields': fileFields},
    );
    final properties = folder['appProperties'] as Map?;
    if (folder['ownedByMe'] != true ||
        folder['trashed'] == true ||
        folder['mimeType'] != folderMime ||
        properties?['orbitRole'] != 'vault' ||
        properties?['orbitProtocol'] != '1' ||
        properties?['orbitVaultId'] != vault.workspaceId) {
      throw const GoogleCloudError(
        'identity',
        'This Vault must belong to the connected account and retain its original identity.',
      );
    }
    final files = await _list(
      subject,
      "trashed = false and 'me' in owners and '${_quoted(vault.folderId)}' in parents and name = 'workspace.json'",
    );
    if (files.length != 1 ||
        BigInt.tryParse('${files.single['size']}') == null ||
        BigInt.parse('${files.single['size']}') > BigInt.from(1024 * 1024)) {
      throw const GoogleCloudError(
        'manifest',
        'This cloud Vault has a missing, ambiguous or oversized manifest.',
      );
    }
    final manifest = await _request(
      subject,
      'GET',
      'files/${Uri.encodeComponent(files.single['id'] as String)}',
      query: {'alt': 'media'},
    );
    if (manifest['format'] != 'orbit-note-workspace' ||
        manifest['version'] != 1 ||
        manifest['id'] != vault.workspaceId) {
      throw const GoogleCloudError(
        'identity',
        'This cloud Vault’s identity could not be verified. It will not be merged.',
      );
    }
    return manifest;
  }

  Future<String> ensureRoot() async {
    final subject = _subject();
    // One device must not race its own initial folder creation or overwrite
    // another account's root mapping with a stale metadata snapshot.
    final operation = _rootOperations.then((_) => _ensureRoot(subject));
    _rootOperations = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<String> _ensureRoot(String subject) async {
    _account(subject);
    final raw = await localMetadata.read();
    _account(subject);
    final metadata = raw == null
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    final saved = metadata[subject] as Map?;
    if (saved != null) {
      try {
        final f = await _request(
          subject,
          'GET',
          'files/${Uri.encodeComponent(saved['id'] as String)}',
          query: {'fields': fileFields},
        );
        if (f['trashed'] == true ||
            f['ownedByMe'] != true ||
            f['mimeType'] != folderMime ||
            (f['appProperties'] as Map?)?['orbitRole'] != 'root') {
          throw const GoogleCloudError(
            'root',
            'The Orbit folder must be available and owned by the connected Google account.',
          );
        }
        return f['id'] as String;
      } on GoogleCloudError catch (e) {
        if (e.code != 'missing' || saved['pending'] != true) rethrow;
      }
    }
    final roots = await _list(
      subject,
      "trashed = false and 'me' in owners and mimeType = '$folderMime' and appProperties has { key='orbitRole' and value='root' }",
    );
    if (roots.length > 1) {
      throw const GoogleCloudError(
        'roots',
        'More than one Orbit folder was found. Review the folders in Google Drive before continuing.',
      );
    }
    if (roots.isNotEmpty) {
      _account(subject);
      metadata[subject] = {'id': roots.single['id'], 'pending': false};
      await localMetadata.write(jsonEncode(metadata));
      _account(subject);
      return roots.single['id'] as String;
    }
    // Persist a Google-generated ID before creating: response loss can retry the
    // same ID, instead of creating another folder named Orbit Note.
    final id =
        saved?['id'] as String? ??
        ((await _request(
                      subject,
                      'GET',
                      'files/generateIds',
                      query: {'count': '1', 'space': 'drive', 'type': 'files'},
                    ))['ids']
                    as List)
                .single
            as String;
    _account(subject);
    metadata[subject] = {'id': id, 'pending': true};
    await localMetadata.write(jsonEncode(metadata));
    _account(subject);
    await _request(
      subject,
      'POST',
      'files',
      query: {'fields': 'id'},
      body: {
        'id': id,
        'name': 'Orbit Note',
        'mimeType': folderMime,
        'appProperties': {'orbitRole': 'root', 'orbitProtocol': '1'},
      },
    );
    metadata[subject] = {'id': id, 'pending': false};
    await localMetadata.write(jsonEncode(metadata));
    _account(subject);
    return id;
  }
}
