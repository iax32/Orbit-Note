import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class DriveTestFile {
  DriveTestFile(this.metadata, List<int> bytes)
    : bytes = Uint8List.fromList(bytes);
  final Map<String, dynamic> metadata;
  Uint8List bytes;
  Map<String, dynamic> get json => {
    ...metadata,
    'size': '${bytes.length}',
    'md5Checksum': md5.convert(bytes).toString(),
    'ownedByMe': true,
  };
}

/// Exercises the production HTTP adapter; no SyncProvider behavior is faked.
class DriveSyncService {
  DriveSyncService(this.workspaceId) {
    files['root'] = DriveTestFile({
      'id': 'root',
      'name': 'Orbit',
      'mimeType': 'application/vnd.google-apps.folder',
      'parents': [],
      'appProperties': {'orbitRole': 'root', 'orbitProtocol': '1'},
    }, []);
    files['sync-vault'] = DriveTestFile({
      'id': 'sync-vault',
      'name': 'Synced Vault',
      'mimeType': 'application/vnd.google-apps.folder',
      'parents': ['root'],
      'appProperties': {
        'orbitRole': 'sync-vault',
        'orbitProtocol': '2',
        'orbitVaultId': workspaceId,
      },
    }, []);
    client = MockClient(handle);
  }
  final String workspaceId;
  late MockClient client;
  final files = <String, DriveTestFile>{};
  final sessions = <String, DriveTestFile>{};
  int sequence = 0, requests = 0, recordCreates = 0, blobCreates = 0;
  bool offline = false, loseBlobReply = false, loseRecordReply = false;
  bool partialList = false;
  bool failFolderCreateOnce = false;
  int? rejectStatus;
  Future<void> Function()? beforeRecord;
  List<DriveTestFile> get revisions => files.values
      .where(
        (f) =>
            (f.metadata['appProperties'] as Map?)?['orbitRole'] ==
            'sync-revision',
      )
      .toList();
  Future<http.Response> handle(http.Request r) async {
    requests++;
    if (offline) throw http.ClientException('Offline test');
    if (rejectStatus != null) return http.Response('{}', rejectStatus!);
    if (!r.headers.containsKey('Authorization')) {
      throw StateError('Missing account authorization');
    }
    final path = r.url.path;
    if (path.endsWith('/generateIds')) {
      final count = int.parse(r.url.queryParameters['count'] ?? '1');
      return http.Response(
        jsonEncode({
          'ids': List.generate(count, (_) => 'generated-${++sequence}'),
        }),
        200,
      );
    }
    if (path == '/drive/v3/files' && r.method == 'GET') {
      final q = r.url.queryParameters['q'] ?? '';
      var matches = files.values.where((f) => f.metadata['trashed'] != true);
      final role = RegExp(
        "key='orbitRole' and value='([^']+)'",
      ).firstMatch(q)?.group(1);
      if (role != null) {
        matches = matches.where(
          (f) => (f.metadata['appProperties'] as Map?)?['orbitRole'] == role,
        );
      }
      final key = RegExp(
        "key='orbitKey' and value='([^']+)'",
      ).firstMatch(q)?.group(1);
      if (key != null) {
        matches = matches.where(
          (f) => (f.metadata['appProperties'] as Map?)?['orbitKey'] == key,
        );
      }
      final parent = RegExp("'([^']+)' in parents").firstMatch(q)?.group(1);
      if (parent != null) {
        matches = matches.where(
          (f) => (f.metadata['parents'] as List? ?? []).contains(parent),
        );
      }
      return http.Response(
        jsonEncode({
          'files': matches.map((f) => f.json).toList(),
          'incompleteSearch': partialList,
        }),
        200,
      );
    }
    if (path.startsWith('/drive/v3/files/') && r.method == 'GET') {
      final id = r.url.pathSegments.last, f = files[id];
      if (f == null || f.metadata['trashed'] == true) {
        return http.Response('{}', 404);
      }
      return r.url.queryParameters['alt'] == 'media'
          ? http.Response.bytes(f.bytes, 200)
          : http.Response(jsonEncode(f.json), 200);
    }
    if (path == '/drive/v3/files' && r.method == 'POST') {
      if (failFolderCreateOnce) {
        failFolderCreateOnce = false;
        throw http.ClientException('Folder setup interrupted');
      }
      final metadata = jsonDecode(r.body) as Map<String, dynamic>;
      final id = metadata['id'] as String;
      if (files.containsKey(id)) return http.Response('{}', 409);
      files[id] = DriveTestFile(metadata, []);
      return http.Response(jsonEncode({'id': id}), 200);
    }
    if (path == '/upload/drive/v3/files' && r.method == 'POST') {
      if (r.url.queryParameters['uploadType'] == 'resumable') {
        final metadata = jsonDecode(r.body) as Map<String, dynamic>;
        final id = metadata['id'] as String;
        if (files.containsKey(id)) return http.Response('{}', 409);
        final location =
            'https://www.googleapis.com/upload/drive/v3/files?upload_id=$id';
        sessions[location] = DriveTestFile(metadata, []);
        blobCreates++;
        return http.Response('{}', 200, headers: {'location': location});
      }
      final chunks = utf8
          .decode(r.bodyBytes)
          .split('--orbit-revision-boundary');
      final metadata =
          jsonDecode(chunks[1].split('\r\n\r\n')[1].trim())
              as Map<String, dynamic>;
      final payload = chunks[2].split('\r\n\r\n')[1];
      final bytes = utf8.encode(payload.substring(0, payload.length - 2));
      final id = metadata['id'] as String;
      if (files.containsKey(id)) return http.Response('{}', 409);
      final revision =
          (metadata['appProperties'] as Map)['orbitRole'] == 'sync-revision';
      if (revision) await beforeRecord?.call();
      files[id] = DriveTestFile(metadata, bytes);
      if (revision) {
        recordCreates++;
      } else {
        blobCreates++;
      }
      if (revision && loseRecordReply) {
        loseRecordReply = false;
        offline = true;
        throw http.ClientException('Lost record acknowledgement');
      }
      return http.Response(jsonEncode({'id': id}), 200);
    }
    if (path == '/upload/drive/v3/files' && r.method == 'PUT') {
      final session = sessions['${r.url}'];
      if (session == null) return http.Response('{}', 404);
      final id = session.metadata['id'] as String;
      if (files.containsKey(id)) {
        return http.Response(jsonEncode({'id': id}), 200);
      }
      if (r.bodyBytes.isEmpty) {
        return http.Response(
          '',
          308,
          headers: {
            if (session.bytes.isNotEmpty)
              'range': 'bytes=0-${session.bytes.length - 1}',
          },
        );
      }
      final match = RegExp(
        r'^bytes (\d+)-(\d+)/(\d+)$',
      ).firstMatch(r.headers['Content-Range']!)!;
      final start = int.parse(match[1]!),
          end = int.parse(match[2]!),
          total = int.parse(match[3]!);
      if (start != session.bytes.length ||
          end - start + 1 != r.bodyBytes.length) {
        return http.Response('{}', 400);
      }
      session.bytes = Uint8List.fromList([...session.bytes, ...r.bodyBytes]);
      if (session.bytes.length == total) {
        files[id] = session;
        if (loseBlobReply) {
          loseBlobReply = false;
          throw http.ClientException('Lost blob acknowledgement');
        }
        return http.Response(jsonEncode({'id': id}), 200);
      }
      return http.Response('', 308, headers: {'range': 'bytes=0-$end'});
    }
    throw StateError('Unexpected test request: ${r.method} ${r.url.path}');
  }
}
