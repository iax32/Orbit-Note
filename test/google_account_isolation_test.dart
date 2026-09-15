import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'google_account_test.dart' show TestGoogleCredentials;
import 'google_drive_account_test.dart' show FakeGoogleAuth;

class _PausedStore extends TestGoogleCredentials {
  _PausedStore({this.pauseRead = false, this.pauseWrite = false});
  final bool pauseRead, pauseWrite;
  final entered = Completer<void>(), resume = Completer<void>();
  @override
  Future<String?> read() async {
    if (pauseRead) {
      entered.complete();
      await resume.future;
    }
    return super.read();
  }

  @override
  Future<void> write(String value) async {
    if (pauseWrite) {
      entered.complete();
      await resume.future;
    }
    await super.write(value);
  }
}

void main() {
  final accountError = throwsA(
    isA<GoogleCloudError>().having((e) => e.code, 'code', 'account'),
  );
  http.Response jsonResponse(Object value) =>
      http.Response(jsonEncode(value), 200);
  Map<String, Object> folder(String role) => {
    'id': 'folder',
    'ownedByMe': true,
    'mimeType': GoogleDriveApi.folderMime,
    'appProperties': {
      'orbitRole': role,
      'orbitProtocol': '1',
      'orbitVaultId': 'vault-uuid',
    },
  };

  for (final pauseRead in [true, false]) {
    test(
      'account switch during root metadata ${pauseRead ? 'read' : 'write'} stops requests',
      () async {
        final auth = FakeGoogleAuth();
        final store = _PausedStore(
          pauseRead: pauseRead,
          pauseWrite: !pauseRead,
        );
        var requests = 0;
        final api = GoogleDriveApi(
          auth: auth,
          localMetadata: store,
          client: MockClient((r) async {
            requests++;
            expect(r.method, 'GET');
            return r.url.path.endsWith('generateIds')
                ? jsonResponse({
                    'ids': ['original-account-root'],
                  })
                : jsonResponse({'files': []});
          }),
        );
        final result = api.ensureRoot();
        final checked = expectLater(result, accountError);
        await store.entered.future;
        auth.current = const GoogleAccount(subject: 'other-user');
        store.resume.complete();
        await checked;
        expect(requests, pauseRead ? 0 : 2);
        if (!pauseRead) {
          final metadata = jsonDecode(store.value!) as Map;
          expect(metadata.keys, ['subject-1']);
          expect(metadata['subject-1']['pending'], isTrue);
        }
      },
    );
  }

  test('concurrent root setup creates one folder and retries safely', () async {
    final auth = FakeGoogleAuth(), store = TestGoogleCredentials();
    var creates = 0, allocations = 0;
    final api = GoogleDriveApi(
      auth: auth,
      localMetadata: store,
      client: MockClient((r) async {
        if (r.method == 'POST') {
          creates++;
          return jsonResponse({'id': 'folder'});
        }
        if (r.url.path.endsWith('generateIds')) {
          allocations++;
          return jsonResponse({
            'ids': ['folder'],
          });
        }
        if (r.url.path.endsWith('/folder')) return jsonResponse(folder('root'));
        return jsonResponse({'files': []});
      }),
    );
    expect(await Future.wait([api.ensureRoot(), api.ensureRoot()]), [
      'folder',
      'folder',
    ]);
    expect(creates, 1);
    expect(allocations, 1);
  });

  test(
    'Vault selection from a previous account cannot issue new requests',
    () async {
      final auth = FakeGoogleAuth();
      var requests = 0;
      final api = GoogleDriveApi(
        auth: auth,
        localMetadata: TestGoogleCredentials(),
        client: MockClient((r) async {
          requests++;
          return jsonResponse({
            'files': [folder('vault')],
          });
        }),
      );
      final selected = (await api.listVaults()).single;
      expect(selected.accountSubject, 'subject-1');
      auth.current = const GoogleAccount(subject: 'other-user');
      await expectLater(api.inspectVault(selected), accountError);
      expect(requests, 1);
    },
  );

  for (final owned in [true, false]) {
    test(
      'Vault inspection rechecks ownership before reading manifest ($owned)',
      () async {
        var requests = 0;
        final api = GoogleDriveApi(
          auth: FakeGoogleAuth(),
          localMetadata: TestGoogleCredentials(),
          client: MockClient((r) async {
            requests++;
            expect(r.method, 'GET');
            if (r.url.path.endsWith('/folder')) {
              return jsonResponse({...folder('vault'), 'ownedByMe': owned});
            }
            if (r.url.path.endsWith('/files')) {
              expect(r.url.queryParameters['q'], contains("'me' in owners"));
              return jsonResponse({
                'files': [
                  {'id': 'manifest', 'size': '120'},
                ],
              });
            }
            return jsonResponse({
              'format': 'orbit-note-workspace',
              'version': 1,
              'id': 'vault-uuid',
              'name': 'Study',
              'unknown': 'preserved',
            });
          }),
        );
        const selected = GoogleRemoteVault(
          folderId: 'folder',
          workspaceId: 'vault-uuid',
          name: 'Study',
          accountSubject: 'subject-1',
        );
        if (owned) {
          expect((await api.inspectVault(selected))['unknown'], 'preserved');
          expect(requests, 3);
        } else {
          await expectLater(
            api.inspectVault(selected),
            throwsA(isA<GoogleCloudError>()),
          );
          expect(requests, 1);
        }
      },
    );
  }
}
