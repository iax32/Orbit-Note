// Manual, opt-in acceptance against real Google Drive. Never part of CI.
// See docs/development/google-drive-sync-setup.md before running.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/application/sync/sync_engine.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/sync_entry.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/sync/google_auth_native.dart';
import 'package:orbit_note/infrastructure/sync/google_desktop_auth.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';

class _MemoryCredentials implements GoogleCredentialStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> delete() async => value = null;
}

/// Sends every request to Google, with controlled connection failures only.
/// Request headers, response bodies and session URLs are never logged.
class _Connection extends http.BaseClient {
  final _client = http.Client();
  bool offline = false, interruptChunk = false, loseRecordReply = false;
  int interruptedChunks = 0, lostRecordReplies = 0, sessions = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (offline) throw const SocketException('Acceptance connection offline');
    final resumable =
        request.method == 'POST' &&
        request.url.queryParameters['uploadType'] == 'resumable';
    final revision =
        request.method == 'POST' &&
        request.url.queryParameters['uploadType'] == 'multipart' &&
        request is http.Request &&
        request.body.contains('"orbitRole":"sync-revision"');
    final response = await _client.send(request);
    if (resumable && response.statusCode == 200) sessions++;
    if (interruptChunk &&
        request.method == 'PUT' &&
        response.statusCode == 308) {
      await response.stream.drain<void>();
      interruptChunk = false;
      interruptedChunks++;
      throw const SocketException('Acceptance interrupted upload');
    }
    if (loseRecordReply && revision && response.statusCode == 200) {
      await response.stream.drain<void>();
      loseRecordReply = false;
      lostRecordReplies++;
      throw const SocketException('Acceptance lost publication reply');
    }
    return response;
  }

  @override
  void close() => _client.close();
}

void main() {
  const enabled = bool.fromEnvironment('ORBIT_LIVE_DRIVE');
  test(
    'real Google account: isolated native replicas, conflicts and recovery',
    () async {
      final resultFile = File('.local/drive-live-result.json');
      final checks = <String>[];
      final result = <String, dynamic>{
        'started': DateTime.now().toUtc().toIso8601String(),
        'status': 'running',
        'physicalDevices': 1,
        'replicas': 2,
        'credentials': 'memory only; not the app credential store',
        'checks': checks,
      };
      Future<void> report(String phase) async {
        result['phase'] = phase;
        await resultFile.parent.create(recursive: true);
        await resultFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(result),
        );
        // Only harness-defined labels; no provider payloads or account details.
        // ignore: avoid_print
        print('LIVE_DRIVE: $phase');
      }

      Future<void> passed(String phase) async {
        checks.add(phase);
        await report(phase);
      }

      final ca = _Connection(), cb = _Connection();
      final credentials = _MemoryCredentials();
      GoogleDesktopAuth? aa, ab;
      WorkspaceRepository? a, b;
      try {
        if (!Platform.isWindows) {
          throw const GoogleCloudError(
            'platform',
            'This manual acceptance harness currently uses Windows sign-in.',
          );
        }
        final config =
            jsonDecode(
                  await File('config/google-drive.local.json').readAsString(),
                )
                as Map;
        GoogleDesktopAuth authentication(_Connection connection) =>
            GoogleDesktopAuth(
              clientId: config['ORBIT_GOOGLE_DESKTOP_CLIENT_ID'] as String,
              clientSecret:
                  config['ORBIT_GOOGLE_DESKTOP_CLIENT_SECRET'] as String? ?? '',
              credentials: credentials,
              client: connection,
              receive: LoopbackGoogleReceiver.bind,
              timeout: const Duration(minutes: 10),
              openBrowser: (uri) async {
                await report('waiting for Google consent in system browser');
                await Process.start('rundll32.exe', [
                  'url.dll,FileProtocolHandler',
                  uri.toString(),
                ], mode: ProcessStartMode.detached);
                return true;
              },
            );
        aa = authentication(ca);
        await aa.signIn();
        ab = authentication(cb);
        expect((await ab.restore())?.subject, aa.account!.subject);
        await ab.accessToken(refresh: true);
        await passed('Google consent, identity, session restore and refresh');

        final root = await Directory(
          '.local/drive-live-vaults',
        ).create(recursive: true);
        final run = await root.createTemp('acceptance-');
        result['localFixtures'] = run.absolute.path;
        final sa = NativeWorkspaceStore(), sb = NativeWorkspaceStore();
        a = WorkspaceRepository(store: sa, index: MemoryObjectIndex());
        b = WorkspaceRepository(store: sb, index: MemoryObjectIndex());
        final pathA = '${run.path}/a', pathB = '${run.path}/b';
        await a.initialize(path: pathA);
        final apiA = GoogleDriveApi(
          auth: aa,
          client: ca,
          localMetadata: _MemoryCredentials(),
        );
        final apiB = GoogleDriveApi(
          auth: ab,
          client: cb,
          localMetadata: _MemoryCredentials(),
        );
        final name = 'Orbit Sync Acceptance ${a.workspaceId.substring(0, 8)}';
        result['cloudFixtureName'] = name;
        final vault = await apiA.ensureSyncVault(
          a.workspaceId,
          name,
          rememberId: (_) async {},
        );
        expect(
          (await apiB.listSyncVaults())
              .where((v) => v.workspaceId == a!.workspaceId)
              .single
              .folderId,
          vault.folderId,
        );
        await apiB.verifySyncVault(vault);
        await passed('isolated cloud Vault created and discovered by client B');

        var ra = WorkspaceSyncReplica(a, canApply: () => true);
        GoogleDriveSyncProvider provider(
          WorkspaceSyncReplica replica,
          GoogleDriveApi api,
        ) => GoogleDriveSyncProvider(
          api: api,
          vault: vault,
          journal: replica.createDriveJournalStore(),
          stage: replica.stageTransfer,
          isCurrent: () => true,
        );
        SyncEngine engine(WorkspaceSyncReplica replica, GoogleDriveApi api) =>
            SyncEngine(
              replica: replica,
              provider: provider(replica, api),
              stateStore: replica.createStateStore(),
            );
        final note = await a.create(
          typeId: 'orbit.note',
          title: 'Synthetic acceptance note',
          body: '# Synthetic only\r\n\r\nUnicode 😀 — **exact source**.\n',
        );
        final board = await a.create(
          typeId: 'orbit.canvas',
          title: 'Synthetic acceptance Canvas',
          data: {
            'elements': [],
            'acceptanceUnknownData': {'keep': true},
          },
        );
        final payload = Uint8List.fromList(
          List.generate(2 * 1024 * 1024 + 37, (i) => i % 251),
        );
        final attachment = await a.importAttachment(
          name: 'synthetic-transfer.bin',
          bytes: payload,
        );
        expect((await engine(ra, apiA).sync()).upToDate, isTrue);
        await passed('real Drive upload of note, Canvas and multi-chunk file');

        // Bootstrap client B from the verified remote manifest, not a local copy.
        final manifestRemote = (await provider(ra, apiB).fetchChanges(
          null,
        )).entries.singleWhere((e) => e.entry.path == 'workspace.json');
        final manifest = await provider(
          ra,
          apiB,
        ).download(manifestRemote).expand((chunk) => chunk).toList();
        expect(sha256.convert(manifest).toString(), manifestRemote.entry.hash);
        await Directory(pathB).create();
        await File('$pathB/workspace.json').writeAsBytes(manifest);
        await b.initialize(path: pathB);
        var rb = WorkspaceSyncReplica(b, canApply: () => true);
        expect((await engine(rb, apiB).sync()).upToDate, isTrue);
        expect(b.objects.singleWhere((o) => o.id == note.id).body, note.body);
        expect(b.objects.singleWhere((o) => o.id == board.id).data, board.data);
        final ref = attachment.properties['contentRef'] as String;
        expect(
          sha256.convert((await b.readAttachment(ref))!).toString(),
          sha256.convert(payload).toString(),
        );
        await passed(
          'remote bootstrap, exact Markdown, Canvas and file hashes',
        );

        final added = await b.create(
          typeId: 'orbit.note',
          title: 'From client B',
          body: 'bidirectional',
        );
        await engine(rb, apiB).sync();
        await engine(ra, apiA).sync();
        expect(a.objects.any((o) => o.id == added.id), isTrue);
        await passed('new objects transfer from B back to A');

        await a.save(
          a.objects
              .firstWhere((o) => o.id == note.id)
              .copyWith(body: 'cloud draft A'),
        );
        await b.save(
          b.objects
              .firstWhere((o) => o.id == note.id)
              .copyWith(body: 'offline draft B'),
        );
        cb.offline = true;
        await expectLater(engine(rb, apiB).sync(), throwsA(anything));
        cb.offline = false;
        await engine(ra, apiA).sync();
        final eb = engine(rb, apiB);
        expect((await eb.sync()).conflicts, 1);
        expect(
          b.objects.singleWhere((o) => o.id == note.id).body,
          'offline draft B',
        );
        final retained = await sb.listFiles();
        expect(
          retained.where(
            (p) =>
                p.startsWith('.orbit/sync-conflicts/') && p.endsWith('/local'),
          ),
          isNotEmpty,
        );
        expect(
          retained.where(
            (p) =>
                p.startsWith('.orbit/sync-conflicts/') && p.endsWith('/remote'),
          ),
          isNotEmpty,
        );
        final state = await rb.createStateStore().load();
        final remote =
            ((state!['conflicts'] as Map)[note.id]['remote'] as Map)['version']
                as String;
        expect(
          (await eb.resolve(note.id, remoteVersion: remote)).upToDate,
          isTrue,
        );
        expect(
          b.objects.singleWhere((o) => o.id == note.id).body,
          'cloud draft A',
        );
        await engine(ra, apiA).sync();
        await passed(
          'offline edits preserve both drafts; explicit resolution converges',
        );

        final transfer = SyncEntry(
          key: 'blob:Attachments/acceptance/resume.bin',
          path: 'Attachments/acceptance/resume.bin',
          hash: sha256.convert(payload).toString(),
        );
        ca.interruptChunk = true;
        await expectLater(
          provider(ra, apiA).upload(
            transfer,
            Stream.value(payload),
            operationId: 'acceptance-resume',
            expectedVersion: null,
          ),
          throwsA(anything),
        );
        expect(ca.interruptedChunks, 1);
        final sessions = ca.sessions;
        await a.close();
        await a.initialize(path: pathA);
        ra = WorkspaceSyncReplica(a, canApply: () => true);
        final resumed = await provider(ra, apiA).upload(
          transfer,
          Stream.value(payload),
          operationId: 'acceptance-resume',
          expectedVersion: null,
        );
        expect(ca.sessions, sessions);
        final downloaded = await provider(
          rb,
          apiB,
        ).download(resumed).expand((chunk) => chunk).toList();
        expect(sha256.convert(downloaded).toString(), transfer.hash);
        await passed(
          'interrupted real resumable upload survives repository restart',
        );

        await a.save(
          a.objects
              .singleWhere((o) => o.id == note.id)
              .copyWith(body: 'publication reply lost; recover same revision'),
        );
        ca.loseRecordReply = true;
        expect((await engine(ra, apiA).sync()).upToDate, isTrue);
        expect(ca.lostRecordReplies, 1);
        await engine(rb, apiB).sync();
        expect(
          b.objects.singleWhere((o) => o.id == note.id).body,
          'publication reply lost; recover same revision',
        );
        await passed(
          'lost real publication acknowledgement recovers by stable ID',
        );

        await a.trash(added.id);
        await engine(ra, apiA).sync();
        await engine(rb, apiB).sync();
        await a.deletePermanently(added.id);
        await engine(ra, apiA).sync();
        await engine(rb, apiB).sync();
        expect(b.objects.any((o) => o.id == added.id), isFalse);
        expect((await rb.inventory())[added.id]!.deleted, isTrue);
        await passed('trash and permanent-deletion tombstone propagate');

        await b.close();
        await b.initialize(path: pathB);
        rb = WorkspaceSyncReplica(b, canApply: () => true);
        expect((await engine(rb, apiB).sync()).upToDate, isTrue);
        expect((await engine(ra, apiA).sync()).upToDate, isTrue);
        expect((await provider(ra, apiA).fetchChanges(null)).forks, isEmpty);
        await passed(
          'both persisted replicas restart and reach a clean checkpoint',
        );
        result['status'] = 'passed';
        await report(
          'complete; synthetic cloud fixtures retained for inspection',
        );
      } on GoogleCloudError catch (error) {
        result['status'] = 'failed';
        result['errorCode'] = error.code;
        await report('Google acceptance stopped; local fixtures preserved');
        fail('Google acceptance: ${error.code}: ${error.message}');
      } on TestFailure {
        result['status'] = 'failed';
        await report('acceptance assertion failed; fixtures preserved');
        rethrow;
      } on Object {
        result['status'] = 'failed';
        await report(
          'acceptance stopped unexpectedly; no raw provider data logged',
        );
        fail(
          'Live acceptance stopped in the recorded phase. Credentials were not logged.',
        );
      } finally {
        await a?.close();
        await b?.close();
        await aa?.signOut();
        await ab?.signOut();
        ca.close();
        cb.close();
      }
    },
    skip: !enabled
        ? 'Manual Google account consent and synthetic uploads required.'
        : false,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
