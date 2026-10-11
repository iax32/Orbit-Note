import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_note/application/backup_bundle.dart';
import 'package:orbit_note/app/google_cloud_controller.dart';
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'support/memory_store.dart';
import 'google_drive_account_test.dart' show FakeGoogleAuth;
import 'google_account_test.dart' show TestGoogleCredentials;

void main() {
  late FakeGoogleAuth auth;
  late TestGoogleCredentials credentials;
  late String source;
  test(
    'account change while preparing a backup never uploads to another account',
    () async {
      var requests = 0;
      final api = GoogleDriveApi(
        auth: auth,
        localMetadata: credentials,
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      final controller = GoogleCloudController(auth, api);
      addTearDown(controller.dispose);
      await controller.uploadBackup(() async {
        auth.current = const GoogleAccount(subject: 'another-user');
        return source;
      });
      expect(requests, 0);
      expect(controller.message, contains('account changed'));
      expect(controller.transferProgress, isNull);
    },
  );
  setUp(() async {
    auth = FakeGoogleAuth();
    credentials = TestGoogleCredentials()
      ..value = '{"subject-1":{"id":"root","pending":false}}';
    final store = MemoryStore();
    final repository = WorkspaceRepository(
      store: store,
      index: MemoryObjectIndex(),
    );
    await repository.initialize();
    await repository.create(
      typeId: 'orbit.note',
      title: 'Saved',
      body: 'Original 😀 content',
    );
    // Larger than a chunk, to verify continuation and progress.
    store.files['Attachments/large.bin'] = Uint8List(1200000);
    source = await repository.exportBundle();
    await repository.close();
  });
  GoogleDriveApi api(Future<http.Response> Function(http.Request) handler) =>
      GoogleDriveApi(
        auth: auth,
        client: MockClient(handler),
        localMetadata: credentials,
      );
  test(
    'resumable upload retains exact backup bytes and verifies server checksum',
    () async {
      final sent = <int>[];
      final progress = <int>[];
      Map? created;
      final drive = api((request) async {
        expect(request.headers['Authorization'], 'Bearer test-access');
        if (request.url.path.endsWith('/root')) {
          return http.Response(
            '{"id":"root","ownedByMe":true,"mimeType":"application/vnd.google-apps.folder","appProperties":{"orbitRole":"root"}}',
            200,
          );
        }
        if (request.url.path.endsWith('/generateIds')) {
          return http.Response('{"ids":["backup-id"]}', 200);
        }
        if (request.method == 'POST') {
          created = jsonDecode(request.body) as Map;
          expect(created!['parents'], ['root']);
          expect(created!['appProperties']['orbitRole'], 'backup');
          return http.Response(
            '{}',
            200,
            headers: {
              'location':
                  'https://www.googleapis.com/upload/drive/v3/files?upload_id=session',
            },
          );
        }
        if (request.method == 'PUT') {
          expect(request.bodyBytes.length, lessThanOrEqualTo(1024 * 1024));
          sent.addAll(request.bodyBytes);
          final total = utf8.encode(source).length;
          if (sent.length < total) {
            return http.Response(
              '',
              308,
              headers: {'range': 'bytes=0-${sent.length - 1}'},
            );
          }
          return http.Response('{"id":"backup-id"}', 200);
        }
        return http.Response(
          jsonEncode({
            'id': 'backup-id',
            'ownedByMe': true,
            'size': '${sent.length}',
            'md5Checksum': md5.convert(sent).toString(),
            'appProperties': created!['appProperties'],
          }),
          200,
        );
      });
      final result = await drive.uploadBackup(
        source,
        onProgress: (sent, total) => progress.add(sent),
      );
      expect(sent, utf8.encode(source));
      expect(progress.length, 2);
      expect(result.checksum, sha256.convert(sent).toString());
      expect(result.workspaceId, (jsonDecode(source) as Map)['workspaceId']);
      expect(result.subject, 'subject-1');
    },
  );
  test(
    'lost final acknowledgement probes the same session instead of duplicating upload',
    () async {
      var lost = false;
      var starts = 0;
      final sent = <int>[];
      Map? properties;
      final drive = api((r) async {
        if (r.url.path.endsWith('/root')) {
          return http.Response(
            '{"id":"root","ownedByMe":true,"mimeType":"application/vnd.google-apps.folder","appProperties":{"orbitRole":"root"}}',
            200,
          );
        }
        if (r.url.path.endsWith('/generateIds')) {
          return http.Response('{"ids":["id"]}', 200);
        }
        if (r.method == 'POST') {
          starts++;
          properties = jsonDecode(r.body)['appProperties'] as Map;
          return http.Response(
            '{}',
            200,
            headers: {
              'location':
                  'https://www.googleapis.com/upload/drive/v3/files?upload_id=one',
            },
          );
        }
        if (r.method == 'PUT') {
          if (r.bodyBytes.isEmpty) {
            expect(r.headers['Content-Range'], startsWith('bytes */'));
            return http.Response('{"id":"id"}', 200);
          }
          sent.addAll(r.bodyBytes);
          if (sent.length < utf8.encode(source).length) {
            return http.Response(
              '',
              308,
              headers: {'range': 'bytes=0-${sent.length - 1}'},
            );
          }
          lost = true;
          throw Exception('response lost');
        }
        return http.Response(
          jsonEncode({
            'id': 'id',
            'ownedByMe': true,
            'size': '${sent.length}',
            'md5Checksum': md5.convert(sent).toString(),
            'appProperties': properties,
          }),
          200,
        );
      });
      await drive.uploadBackup(source);
      expect(lost, isTrue);
      expect(starts, 1);
      expect(sent, utf8.encode(source));
    },
  );
  test('hostile session redirect never receives an access token', () async {
    final drive = api((r) async {
      expect(r.url.host, 'www.googleapis.com');
      if (r.url.path.endsWith('/root')) {
        return http.Response(
          '{"id":"root","ownedByMe":true,"mimeType":"application/vnd.google-apps.folder","appProperties":{"orbitRole":"root"}}',
          200,
        );
      }
      if (r.url.path.endsWith('/generateIds')) {
        return http.Response('{"ids":["id"]}', 200);
      }
      return http.Response(
        '{}',
        200,
        headers: {'location': 'https://attacker.example/upload/drive/v3/files'},
      );
    });
    await expectLater(
      drive.uploadBackup(source),
      throwsA(isA<GoogleCloudError>().having((e) => e.code, 'code', 'session')),
    );
  });
  test(
    'download validates ownership, SHA-256, size and Vault identity before restore',
    () async {
      final bytes = utf8.encode(source),
          checksum = sha256.convert(utf8.encode(source)).toString();
      final workspace = jsonDecode(source)['workspaceId'] as String;
      final backup = GoogleDriveBackup(
        'id',
        'Backup',
        workspace,
        'subject-1',
        bytes.length,
        checksum,
      );
      var corrupt = false;
      final drive = api((r) async {
        if (r.url.queryParameters['alt'] == 'media') {
          return http.Response.bytes(
            corrupt ? [...bytes.take(bytes.length - 1), 0] : bytes,
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'ownedByMe': true,
            'trashed': false,
            'size': '${bytes.length}',
            'appProperties': {
              'orbitRole': 'backup',
              'orbitProtocol': '1',
              'orbitVaultId': workspace,
              'orbitSha256': checksum,
            },
          }),
          200,
        );
      });
      expect(await drive.downloadBackup(backup), source);
      expect(BackupBundle.parse(source).warnings, isEmpty);
      corrupt = true;
      await expectLater(
        drive.downloadBackup(backup),
        throwsA(
          isA<GoogleCloudError>().having((e) => e.code, 'code', 'checksum'),
        ),
      );
      auth.current = const GoogleAccount(subject: 'another-account');
      await expectLater(
        drive.downloadBackup(backup),
        throwsA(
          isA<GoogleCloudError>().having((e) => e.code, 'code', 'account'),
        ),
      );
    },
  );
  test('cancellation before transfer makes no Drive requests', () async {
    var requests = 0;
    final drive = api((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    await expectLater(
      drive.uploadBackup(source, isCancelled: () => true),
      throwsA(
        isA<GoogleCloudError>().having((e) => e.code, 'code', 'cancelled'),
      ),
    );
    expect(requests, 0);
  });
}
