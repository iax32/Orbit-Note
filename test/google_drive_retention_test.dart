import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/sync/sync_provider.dart';
import 'package:orbit_note/domain/sync_entry.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'google_account_test.dart' show TestGoogleCredentials;
import 'google_drive_account_test.dart' show FakeGoogleAuth;
import 'support/drive_sync_service.dart';

class _Journal implements SyncStateStore {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> load() async => value == null
      ? null
      : jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  @override
  Future<void> save(Map<String, dynamic> state) async {
    value = jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
  }
}

void main() {
  late DriveSyncService server;
  late FakeGoogleAuth auth;
  late _Journal journal;
  const key = 'file:notes/course.md';
  GoogleDriveSyncProvider provider() => GoogleDriveSyncProvider(
    api: GoogleDriveApi(
      auth: auth,
      client: server.client,
      localMetadata: TestGoogleCredentials(),
    ),
    vault: const GoogleRemoteVault(
      folderId: 'sync-vault',
      workspaceId: 'vault-test',
      name: 'Course',
      accountSubject: 'subject-1',
    ),
    journal: journal,
    stage: (_, _) async => throw UnimplementedError(),
    isCurrent: () => true,
    now: () => DateTime.utc(2026, 10, 25),
  );
  void add(int index, {String? parent}) {
    final id = 'record-$index',
        blob = 'blob-$index',
        operation = 'operation-$index';
    final bytes = utf8.encode('version-$index 😀');
    final entry = SyncEntry(
      key: key,
      path: 'notes/course.md',
      hash: sha256.convert(bytes).toString(),
    );
    server.files[blob] = DriveTestFile({
      'id': blob,
      'parents': ['sync-vault'],
      'appProperties': {
        'orbitRole': 'sync-blob',
        'orbitProtocol': '2',
        'orbitVaultId': 'vault-test',
        'orbitSha256': entry.hash,
        'orbitOp': operation,
      },
    }, bytes);
    server.files[id] = DriveTestFile(
      {
        'id': id,
        'parents': ['sync-vault'],
        'modifiedTime': DateTime.utc(
          2020,
          1,
          1,
        ).add(Duration(days: index)).toIso8601String(),
        'appProperties': {
          'orbitRole': 'sync-revision',
          'orbitProtocol': '2',
          'orbitVaultId': 'vault-test',
          'orbitOp': operation,
          'orbitKey': sha256.convert(utf8.encode(key)).toString(),
        },
      },
      utf8.encode(
        jsonEncode({
          'format': 'orbit-drive-revision',
          'version': 2,
          'workspaceId': 'vault-test',
          'entry': entry.toJson(),
          'blob': blob,
          'size': bytes.length,
          'parents': parent != null
              ? [parent]
              : index == 0
              ? []
              : ['record-${index - 1}'],
          'operation': operation,
        }),
      ),
    );
  }

  setUp(() {
    server = DriveSyncService('vault-test');
    auth = FakeGoogleAuth();
    journal = _Journal();
    for (var i = 0; i < 25; i++) {
      add(i);
    }
  });
  tearDown(() => server.client.close());
  test(
    'reviewed cleanup retains graph, 20 versions and latest downloadable content',
    () async {
      final p = provider(), preview = await provider().previewRetention();
      expect(preview.files, 5);
      server.beforeDelete = (_) async {
        expect(
          server.files.values.any(
            (f) =>
                (f.metadata['appProperties'] as Map?)?['orbitRole'] ==
                'sync-retention',
          ),
          true,
        );
        expect(
          (server.files['sync-vault']!.metadata['appProperties']
              as Map)['orbitProtocol'],
          '3',
        );
      };
      expect(await p.applyRetention(preview), preview.bytes);
      expect(server.revisions.length, 25);
      for (var i = 0; i < 25; i++) {
        expect(server.files.containsKey('blob-$i'), i >= 5);
      }
      final next = provider();
      final delta = await next.fetchChanges(null);
      expect(delta.entries.single.version, 'record-24');
      final content = await next
          .download(delta.entries.single)
          .expand((e) => e)
          .toList();
      expect(utf8.decode(content), 'version-24 😀');
      expect(journal.value!['retentionPending'], null);
    },
  );
  test(
    'lost delete acknowledgement resumes across provider restart with one receipt',
    () async {
      final p = provider(), preview = await provider().previewRetention();
      server.loseDeleteReply = true;
      await expectLater(p.applyRetention(preview), throwsA(anything));
      expect(journal.value!['retentionPending'], isNotNull);
      server.offline = false;
      final restarted = provider(),
          pending = await provider().previewRetention();
      expect(await restarted.applyRetention(pending), preview.bytes);
      expect(
        server.files.values
            .where(
              (f) =>
                  (f.metadata['appProperties'] as Map?)?['orbitRole'] ==
                  'sync-retention',
            )
            .length,
        1,
      );
      expect(server.files.containsKey('blob-24'), true);
    },
  );
  test(
    'changed graph invalidates review before protocol upgrade or deletion',
    () async {
      final p = provider(), preview = await provider().previewRetention();
      add(25);
      await expectLater(
        p.applyRetention(preview),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(server.files.containsKey('blob-0'), true);
      expect(
        (server.files['sync-vault']!.metadata['appProperties']
            as Map)['orbitProtocol'],
        '2',
      );
    },
  );
  test(
    'forks block cleanup; recent or unknown server dates retain payloads',
    () async {
      add(26, parent: 'record-3');
      await expectLater(
        provider().previewRetention(),
        throwsA(isA<WorkspaceConflict>()),
      );
      server.files.remove('record-26');
      server.files.remove('blob-26');
      journal = _Journal();
      server.files['record-24']!.metadata['modifiedTime'] = DateTime.utc(
        2026,
        10,
        25,
      ).toIso8601String();
      expect((await provider().previewRetention()).files, 0);
      server.files['record-24']!.metadata.remove('modifiedTime');
      expect((await provider().previewRetention()).files, 0);
    },
  );
  test(
    'incomplete listing and changed payload ownership metadata fail closed',
    () async {
      server.partialList = true;
      await expectLater(provider().previewRetention(), throwsA(anything));
      server.partialList = false;
      (server.files['blob-0']!.metadata['appProperties']
              as Map)['orbitVaultId'] =
          'other-vault';
      await expectLater(
        provider().previewRetention(),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(server.files.containsKey('blob-0'), true);
    },
  );
  test('unknown protocol 3 variant is rejected instead of guessed', () async {
    (server.files['sync-vault']!.metadata['appProperties']
            as Map)['orbitProtocol'] =
        '3';
    await expectLater(provider().fetchChanges(null), throwsA(anything));
  });
}
