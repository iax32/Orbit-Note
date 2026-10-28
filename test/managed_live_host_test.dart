import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_note/platform/live_host_native.dart';
import 'package:orbit_note/platform/collaboration_http_native.dart';
import 'package:orbit_note/app/collaboration_controller.dart';
import 'canvas_shared_presence_test.dart' show CanvasSessions;

class _Tunnel extends Fake implements Process {
  final output = StreamController<List<int>>();
  final errors = StreamController<List<int>>();
  final exited = Completer<int>();
  bool killed = false;
  @override
  Stream<List<int>> get stdout => output.stream;
  @override
  Stream<List<int>> get stderr => errors.stream;
  @override
  Future<int> get exitCode => exited.future;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!exited.isCompleted) exited.complete(0);
    unawaited(output.close());
    unawaited(errors.close());
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => HttpOverrides.global = null);
  test(
    'only valid temporary HTTPS hostnames are accepted from helper logs',
    () {
      expect(
        orbitTunnelAddress(
          'URL https://my-test-link.trycloudflare.com ready',
        )?.scheme,
        'https',
      );
      for (final line in [
        'http://my-test-link.trycloudflare.com',
        'https://evil.example',
        'https://my-test-link.trycloudflare.com.evil.example',
      ]) {
        final uri = orbitTunnelAddress(line);
        if (line.contains('.evil.')) {
          // A hostname suffix must never be treated as a trusted address.
          expect(uri, isNull);
        } else {
          expect(uri, isNull);
        }
      }
    },
  );
  test(
    'verified helper starts isolated host and stop releases process and endpoint',
    () async {
      if (!Platform.isWindows) return;
      final directory = await Directory.systemTemp.createTemp(
        'orbit-livehost-test-',
      );
      final process = _Tunnel();
      var launches = 0;
      final host = OrbitLiveHost(
        directory: () async => directory,
        helperDigest: sha256.convert([1, 2, 3]).toString(),
        contain: (_) => () {},
        client: () => MockClient(
          (request) async => request.url.path == '/healthz'
              ? http.Response(
                  '{"service":"orbit-collaboration","ready":true}',
                  200,
                )
              : http.Response.bytes([1, 2, 3], 200),
        ),
        launch: (path, args) async {
          launches++;
          expect(args, contains('--no-autoupdate'));
          expect(args, contains('http2'));
          expect(await File(path).readAsBytes(), [1, 2, 3]);
          Timer(
            const Duration(milliseconds: 5),
            () => process.output.add(
              utf8.encode('https://unit-test-link.trycloudflare.com\n'),
            ),
          );
          return process;
        },
      );
      try {
        await host.start();
        expect(launches, 1);
        expect(host.localEndpoint!.host, '127.0.0.1');
        expect(host.endpoint!.scheme, 'https');
        expect(host.ownerToken, isNotEmpty);
        await host.stop();
        expect(process.killed, true);
        expect(host.endpoint, isNull);
        expect(host.ownerToken, isNull);
        expect(host.busy, false);
      } finally {
        await host.stop();
        host.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  test('unverified downloaded helper is never executed', () async {
    if (!Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp(
      'orbit-livehost-test-',
    );
    var launched = false;
    final host = OrbitLiveHost(
      directory: () async => directory,
      client: () =>
          MockClient((_) async => http.Response.bytes([1, 2, 3], 200)),
      launch: (_, _) async {
        launched = true;
        return _Tunnel();
      },
    );
    try {
      await expectLater(host.start(), throwsA(isA<StateError>()));
      expect(launched, false);
      expect(host.endpoint, isNull);
      expect(host.busy, false);
      expect(host.status, contains('verification failed'));
    } finally {
      await host.stop();
      host.dispose();
      await directory.delete(recursive: true);
    }
  });
  test('a new managed session cannot reuse the previous room grants', () async {
    if (!Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp(
      'orbit-livehost-test-',
    );
    final host = OrbitLiveHost(
      directory: () async => directory,
      helperDigest: sha256.convert([1, 2, 3]).toString(),
      contain: (_) => () {},
      client: () => MockClient(
        (request) async => request.url.path == '/healthz'
            ? http.Response('{"service":"orbit-collaboration"}', 200)
            : http.Response.bytes([1, 2, 3], 200),
      ),
      launch: (_, _) async {
        final process = _Tunnel();
        Timer(
          const Duration(milliseconds: 5),
          () => process.output.add(
            utf8.encode('https://new-session-test.trycloudflare.com\n'),
          ),
        );
        return process;
      },
    );
    final f = CanvasSessions();
    await f.open();
    try {
      await host.start();
      final old = await f.first.createRoom(
        host.localEndpoint!,
        host.ownerToken!,
        'Synthetic session',
      );
      await host.stop();
      await host.start();
      await expectLater(
        f.first.inspectRoom(
          host.localEndpoint!,
          old['room'] as String,
          old['token'] as String,
        ),
        throwsA(isA<CollaborationAccessDenied>()),
      );
    } finally {
      await host.stop();
      host.dispose();
      await f.close();
      await directory.delete(recursive: true);
    }
  });
  test(
    'real HTTPS relay transfers synthetic changes and attachments between clients',
    () async {
      final host = OrbitLiveHost(
        directory: () async =>
            Directory('.local/live-tunnel-acceptance').absolute,
      );
      final f = CanvasSessions();
      await f.open();
      f.second.dispose();
      f.second = CollaborationController(
        f.secondWorkspace,
        createCollaborationHttpClient(),
        automaticPolling: false,
        now: () => f.now,
      );
      try {
        await host.start();
        final room = await f.first.createRoom(
          host.localEndpoint!,
          host.ownerToken!,
          'Synthetic PC',
        );
        await f.first.connect(
          host.localEndpoint!,
          room['room'] as String,
          room['token'] as String,
        );
        final invitation = await f.first.invite('Synthetic tablet', 'editor');
        await f.second.connect(
          host.endpoint!,
          room['room'] as String,
          invitation,
        );
        f.edit(f.firstWorkspace, 0, 222);
        f.firstStore.files['Attachments/connection-check.bin'] =
            Uint8List.fromList([1, 2, 3, 4]);
        await f.first.pump();
        await f.second.pump();
        expect(
          (f.secondWorkspace.find(f.id)!.data['elements'] as List).first['x'],
          222,
        );
        expect(f.secondStore.files['Attachments/connection-check.bin'], [
          1,
          2,
          3,
          4,
        ]);
        expect(f.second.conflicts, isEmpty);
      } finally {
        await host.stop();
        host.dispose();
        await f.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
    skip: Platform.environment['ORBIT_LIVE_TUNNEL_ACCEPTANCE'] != 'true',
  );
}
