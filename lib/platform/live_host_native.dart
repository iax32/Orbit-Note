import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../infrastructure/collaboration/server.dart';
import '../infrastructure/collaboration/host_worker.dart';
import 'collaboration_http.dart';
import 'windows_child_lifetime.dart';

/// Only accept the HTTPS address emitted by the pinned vendor helper.
Uri? orbitTunnelAddress(String line) {
  final match = RegExp(
    r'https://[a-z0-9]+(?:-[a-z0-9]+)+\.trycloudflare\.com(?![A-Za-z0-9.-])',
  ).firstMatch(line);
  return match == null ? null : Uri.parse(match[0]!);
}

/// Explicit, temporary hosting. No service, firewall rule, router changes or
/// automatic sharing on startup. Durable room data stays outside every Vault.
class OrbitLiveHost extends ChangeNotifier {
  OrbitLiveHost({
    Future<Directory> Function()? directory,
    http.Client Function()? client,
    Future<Process> Function(String, List<String>)? launch,
    void Function() Function(Process)? contain,
    this.helperDigest =
        'db4e4c413612a0916f3e1679d3caaf376f94911952d163028fb726fb2e0516a9',
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _client = client ?? createCollaborationHttpClient,
       _contain = contain ?? containOrbitChild,
       _launch =
           launch ??
           ((exe, args) => Process.start(exe, args, runInShell: false));
  final Future<Directory> Function() _directory;
  final http.Client Function() _client;
  final Future<Process> Function(String, List<String>) _launch;
  final void Function() Function(Process) _contain;
  final String helperDigest;
  static const helperVersion = '2026.10.5';
  static final helperUrl = Uri.parse(
    'https://github.com/cloudflare/cloudflared/releases/download/$helperVersion/cloudflared-windows-amd64.exe',
  );
  bool get supported => Platform.isWindows;
  bool busy = false;
  Uri? endpoint, localEndpoint;
  String? ownerToken;
  String status = 'Start on this PC, then paste the invitation on your tablet.';
  CollaborationHostWorker? _server;
  Process? _process;
  void Function()? _releaseProcess;
  http.Client? _transfer;
  int _generation = 0;
  bool _disposed = false;
  final _logs = <StreamSubscription<String>>[];
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _check(int generation) {
    if (generation != _generation || _disposed) {
      throw StateError('Live sharing was cancelled.');
    }
  }

  Future<File> _helper(Directory root, int generation) async {
    final exe = File(p.join(root.path, 'cloudflared-$helperVersion.exe'));
    Future<bool> verified() async =>
        await exe.exists() &&
        (await sha256.bind(exe.openRead()).first).toString() == helperDigest;
    if (await verified()) return exe;
    _check(generation);
    status = 'Preparing secure connection · downloading verified helper…';
    _notify();
    final part = File('${exe.path}.$generation.download');
    final client = _transfer = _client();
    IOSink? output;
    try {
      final response = await client
          .send(http.Request('GET', helperUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError(
          'Could not download the connection helper. Check internet access and retry.',
        );
      }
      output = part.openWrite();
      var received = 0, lastReported = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        _check(generation);
        received += chunk.length;
        if (received > 80 * 1024 * 1024) {
          throw StateError('Connection helper exceeded its size limit.');
        }
        output.add(chunk);
        if (received - lastReported >= 1024 * 1024) {
          lastReported = received;
          status =
              'Preparing secure connection · ${received ~/ (1024 * 1024)} MB downloaded';
          _notify();
        }
      }
      await output.flush();
      await output.close();
      output = null;
      _check(generation);
      if ((await sha256.bind(part.openRead()).first).toString() !=
          helperDigest) {
        throw StateError(
          'Connection helper verification failed. Nothing was executed. Retry later.',
        );
      }
      if (await exe.exists()) await exe.delete();
      await part.rename(exe.path);
      return exe;
    } finally {
      await output?.close();
      client.close();
      if (identical(_transfer, client)) _transfer = null;
      if (await part.exists()) await part.delete();
    }
  }

  Completer<void>? _cancelStart;

  Future<void> start() async {
    if (!supported) {
      throw StateError('Start live sharing on a Windows PC, then join here.');
    }
    if (busy || endpoint != null) return;
    final generation = ++_generation;
    final cancelled = _cancelStart = Completer<void>();
    busy = true;
    status = 'Preparing live sharing…';
    _notify();
    try {
      final root = Directory(p.join((await _directory()).path, 'LiveSharing'));
      await validateCollaborationDirectory(root);
      await root.create(recursive: true);
      _check(generation);
      final helper = await _helper(root, generation);
      _check(generation);
      final owner = collaborationToken();
      final server = await CollaborationHostWorker.start(
        // A new session never reloads old grants under a new public address.
        // Previous journals remain private for recovery; authored Vault data
        // continues to be stored through the normal local repository.
        Directory(p.join(root.path, 'rooms', collaborationToken())),
        owner,
      );
      final port = server.port;
      if (generation != _generation || _disposed) {
        await server.close();
        _check(generation);
      }
      _server = server;
      localEndpoint = Uri.parse('http://127.0.0.1:$port');
      unawaited(
        server.done.then((_) async {
          if (generation != _generation || _disposed) return;
          await stop();
          status =
              'The local sharing server stopped. Start live sharing again; local work is preserved.';
          _notify();
        }),
      );
      status = 'Creating a secure invitation address…';
      _notify();
      await File(p.join(root.path, 'empty.yml')).writeAsString('{}\n');
      _check(generation);
      final process = await _launch(helper.path, [
        'tunnel',
        '--no-autoupdate',
        '--config',
        p.join(root.path, 'empty.yml'),
        '--protocol',
        'http2',
        '--url',
        '$localEndpoint',
      ]);
      if (generation != _generation || _disposed) {
        process.kill();
        _check(generation);
      }
      _process = process;
      _releaseProcess = _contain(process);
      var exited = false;
      final address = Completer<Uri>();
      void line(String value) {
        final uri = orbitTunnelAddress(value);
        if (uri != null && !address.isCompleted) address.complete(uri);
      }

      // Explicit config prevents a user's unrelated cloudflared settings from
      // being loaded. File is private, contains no credentials.
      _logs.add(
        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(line, onError: (Object _) {}),
      );
      _logs.add(
        process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(line, onError: (Object _) {}),
      );
      unawaited(
        process.exitCode.then((_) async {
          exited = true;
          if (generation != _generation || _disposed) return;
          if (!address.isCompleted) {
            address.completeError(
              StateError(
                'The secure connection stopped. Check internet access and retry.',
              ),
            );
          }
          if (endpoint != null) {
            await stop();
            status =
                'Live connection stopped. Start again and send a new invitation.';
            _notify();
          }
        }),
      );
      final uri = await Future.any<Uri>([
        address.future.timeout(const Duration(seconds: 60)),
        cancelled.future.then<Uri>(
          (_) => throw StateError('Live sharing was cancelled.'),
        ),
      ]);
      _check(generation);
      if (exited) {
        throw StateError(
          'The secure connection stopped. Start live sharing again.',
        );
      }
      final probe = _client();
      var ready = false;
      try {
        final deadline = DateTime.now().add(const Duration(seconds: 50));
        while (DateTime.now().isBefore(deadline)) {
          _check(generation);
          if (exited) {
            throw StateError(
              'The secure connection stopped. Check internet access and retry.',
            );
          }
          try {
            final response = await probe
                .get(uri.resolve('/healthz'))
                .timeout(const Duration(seconds: 3));
            if (response.statusCode == 200 &&
                (jsonDecode(response.body) as Map)['service'] ==
                    'orbit-collaboration') {
              ready = true;
              break;
            }
          } catch (_) {
            /* DNS/TLS propagation can take a few seconds. */
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      } finally {
        probe.close();
      }
      _check(generation);
      if (!ready || exited) {
        throw StateError(
          'The secure link is not reachable yet. Check internet access and retry.',
        );
      }
      endpoint = uri;
      ownerToken = owner;
      status = 'Ready · keep Orbit open on this PC';
    } catch (error) {
      if (generation == _generation) {
        await stop();
        status = error is StateError
            ? error.message.toString()
            : 'Could not start live sharing. Check internet access and retry.';
      }
      rethrow;
    } finally {
      if (generation == _generation) busy = false;
      _notify();
    }
  }

  Future<void> stop() async {
    ++_generation;
    final cancelled = _cancelStart;
    _cancelStart = null;
    if (cancelled != null && !cancelled.isCompleted) cancelled.complete();
    _transfer?.close();
    _transfer = null;
    final process = _process;
    _process = null;
    final release = _releaseProcess;
    _releaseProcess = null;
    release?.call();
    process?.kill();
    for (final subscription in _logs) {
      await subscription.cancel();
    }
    _logs.clear();
    final server = _server;
    _server = null;
    await server?.close();
    endpoint = localEndpoint = null;
    ownerToken = null;
    busy = false;
    status = 'Live sharing stopped · local files are saved';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
