import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_note/app/google_cloud_controller.dart';
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'google_account_test.dart' show TestGoogleCredentials;
import 'google_drive_account_test.dart' show FakeGoogleAuth;

void main() {
  http.Response response(Object value) => http.Response(jsonEncode(value), 200);
  http.Response listing(http.Request request) => response({
    'files': request.url.queryParameters['q']!.contains("value='backup'")
        ? [
            {
              'id': 'backup-1',
              'name': 'Study backup',
              'size': '123',
              'appProperties': {
                'orbitProtocol': '1',
                'orbitVaultId': 'vault-1',
                'orbitSha256': 'a' * 64,
              },
            },
          ]
        : [],
  });
  GoogleCloudController controller(
    FakeGoogleAuth auth,
    Future<http.Response> Function(http.Request) handler,
  ) => GoogleCloudController(
    auth,
    GoogleDriveApi(
      auth: auth,
      client: MockClient(handler),
      localMetadata: TestGoogleCredentials(),
    ),
  );

  for (final restore in [false, true]) {
    test(
      '${restore ? 'restore' : 'sign-in'} loads backups without writes',
      () async {
        final auth = FakeGoogleAuth();
        if (!restore) auth.current = null;
        final cloud = controller(auth, (request) async {
          expect(request.method, 'GET');
          return request.url.path.endsWith('/about')
              ? response({
                  'storageQuota': {'limit': '1000', 'usage': '100'},
                })
              : listing(request);
        });
        addTearDown(cloud.dispose);
        await (restore ? cloud.restore() : cloud.connect());
        expect(cloud.account?.subject, 'subject-1');
        expect(cloud.quota?.remaining, BigInt.from(900));
        expect(cloud.backups.single.id, 'backup-1');
        expect(cloud.message, isNull);
        expect(cloud.busy, isFalse);
        expect(cloud.signingIn, isFalse);
      },
    );
  }

  test(
    'partial refresh keeps useful backups and can retry immediately',
    () async {
      var unavailable = true, quotaRequests = 0;
      final cloud = controller(FakeGoogleAuth(), (request) async {
        if (request.url.path.endsWith('/about')) {
          quotaRequests++;
          return unavailable
              ? http.Response('{}', 503)
              : response({
                  'storageQuota': {'usage': '100'},
                });
        }
        return listing(request);
      });
      addTearDown(cloud.dispose);
      await cloud.restore();
      expect(cloud.backups.single.id, 'backup-1');
      expect(cloud.message, contains('unavailable'));
      expect(cloud.reconnectRequired, isFalse);
      unavailable = false;
      await cloud.refresh();
      expect(quotaRequests, 2);
      expect(cloud.quota, isNotNull);
      expect(cloud.message, isNull);
      await cloud.refresh();
      expect(quotaRequests, 2);
    },
  );

  for (final failure in [false, true]) {
    test(
      'cancel discards late quota ${failure ? 'failure' : 'success'}',
      () async {
        final entered = Completer<void>(), resume = Completer<void>();
        var requests = 0;
        final cloud = controller(FakeGoogleAuth(), (request) async {
          requests++;
          entered.complete();
          await resume.future;
          return failure
              ? http.Response('{}', 503)
              : response({
                  'storageQuota': {'usage': '100'},
                });
        });
        addTearDown(cloud.dispose);
        final loading = cloud.restore();
        await entered.future;
        cloud.cancel();
        resume.complete();
        await loading;
        expect(requests, 1);
        expect(cloud.quota, isNull);
        expect(cloud.backups, isEmpty);
        expect(cloud.message, isNull);
      },
    );
  }

  test(
    'account change during backup listing cannot publish old results',
    () async {
      final auth = FakeGoogleAuth();
      final cloud = controller(auth, (request) async {
        auth.current = const GoogleAccount(subject: 'other');
        return listing(request);
      });
      addTearDown(cloud.dispose);
      await cloud.refreshBackups();
      expect(cloud.backups, isEmpty);
      expect(cloud.message, contains('account changed'));
    },
  );
}
