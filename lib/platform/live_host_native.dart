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
    Future<ProcessResult> Function(String, List<String>)? run,
    this.helperDigest =
        'db4e4c413612a0916f3e1679d3caaf376f94911952d163028fb726fb2e0516a9',
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _client = client ?? createCollaborationHttpClient,
       _contain = contain ?? containOrbitChild,
       _run = run ?? ((exe, args) => Process.run(exe, args, runInShell: false)),
       _launch =
           launch ??
           ((exe, args) => Process.start(exe, args, runInShell: false));
  final Future<Directory> Function() _directory;
  final http.Client Function() _client;
  final Future<Process> Function(String, List<String>) _launch;
  final void Function() Function(Process) _contain;
  final Future<ProcessResult> Function(String, List<String>) _run;
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
  Uri? setupAddress;
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

  Future<void> start({String route = 'relay', Uri? publicAddress}) async {
    if (!supported) {
      throw StateError('Start live sharing on a Windows PC, then join here.');
    }
    if (busy || endpoint != null) return;
    final generation = ++_generation;
    final cancelled = _cancelStart = Completer<void>();
    if (!{'relay', 'tailscale', 'own-address'}.contains(route) ||
        (route == 'own-address' &&
            (publicAddress == null ||
                publicAddress.scheme != 'https' ||
                publicAddress.host.isEmpty ||
                publicAddress.userInfo.isNotEmpty ||
                publicAddress.hasQuery ||
                publicAddress.hasFragment ||
                !{'', '/'}.contains(publicAddress.path)))) {
      throw const FormatException(
        'Enter your HTTPS address without a path, password or query.',
      );
    }
    busy = true;
    setupAddress = null;
    status = 'Preparing live sharing…';
    _notify();
    try {
      final root = Directory(p.join((await _directory()).path, 'LiveSharing'));
      await validateCollaborationDirectory(root);
      await root.create(recursive: true);
      _check(generation);
      String? tailscale;
      Uri? privateAddress;
      if (route == 'tailscale') {
        tailscale = p.join(
          Platform.environment['ProgramFiles'] ?? r'C:\Program Files',
          'Tailscale',
          'tailscale.exe',
        );
        status = 'Checking your private device network…';
        _notify();
        final result = await _run(tailscale, [
          'status',
          '--json',
        ]).timeout(const Duration(seconds: 8));
        _check(generation);
        if (result.exitCode != 0) {
          throw StateError(
            'Open Tailscale on this PC and sign in, then retry. Install and sign in to the same Tailscale network on your tablet too.',
          );
        }
        final state = jsonDecode(result.stdout as String) as Map;
        final hostname = (state['Self'] as Map?)?['DNSName'];
        if (state['BackendState'] != 'Running' ||
            hostname is! String ||
            !RegExp(
              r'^[a-z0-9][a-z0-9.-]*\.ts\.net\.?$',
              caseSensitive: false,
            ).hasMatch(hostname)) {
          throw StateError(
            'Connect Tailscale on this PC and tablet first, then retry.',
          );
        }
        privateAddress = Uri(
          scheme: 'https',
          host: hostname.replaceFirst(RegExp(r'\.$'), ''),
          port: 8443,
        );
        final configuration = await _run(tailscale, [
          'serve',
          'status',
          '--json',
        ]).timeout(const Duration(seconds: 8));
        _check(generation);
        if (configuration.exitCode != 0) {
          throw StateError(
            'Tailscale could not check its sharing settings. Open Tailscale and retry.',
          );
        }
        final config = jsonDecode(configuration.stdout as String) as Map;
        if ((config['TCP'] as Map?)?.containsKey('8443') == true ||
            (config['Web'] as Map?)?.keys.any(
                  (key) => '$key'.endsWith(':8443'),
                ) ==
                true) {
          throw StateError(
            'Tailscale port 8443 is already used. Stop that sharing session first; Orbit will not replace it.',
          );
        }
      }
      final helper = route == 'relay' ? await _helper(root, generation) : null;
      _check(generation);
      final owner = collaborationToken();
      final server = await CollaborationHostWorker.start(
        // A new session never reloads old grants under a new public address.
        // Previous journals remain private for recovery; authored Vault data
        // continues to be stored through the normal local repository.
        Directory(p.join(root.path, 'rooms', collaborationToken())),
        owner,
        port: route == 'own-address' ? 47831 : 0,
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
      if (route == 'own-address') {
        status = 'Checking your HTTPS address reaches this PC on port 47831…';
        _notify();
        await _verifyAddress(publicAddress!, generation, cancelled);
        endpoint = publicAddress.replace(path: '');
        ownerToken = owner;
        status = 'Ready · your own HTTPS address · keep Orbit open on this PC';
        return;
      }
      if (route == 'relay') {
        await File(p.join(root.path, 'empty.yml')).writeAsString('{}\n');
      }
      _check(generation);
      final process = await _launch(
        tailscale ?? helper!.path,
        route == 'tailscale'
            ? ['serve', '--https=8443', '--yes', '$localEndpoint']
            : [
                'tunnel',
                '--no-autoupdate',
                '--config',
                p.join(root.path, 'empty.yml'),
                '--protocol',
                'http2',
                '--url',
                '$localEndpoint',
              ],
      );
      if (generation != _generation || _disposed) {
        process.kill();
        _check(generation);
      }
      _process = process;
      _releaseProcess = _contain(process);
      var exited = false;
      final address = Completer<Uri>();
      void line(String value) {
        if (route == 'tailscale') {
          final setup = RegExp(
            r'https://login\.tailscale\.com/f/serve\?[^\s]+',
          ).firstMatch(value);
          if (setup != null) {
            setupAddress = Uri.tryParse(setup[0]!);
            status =
                'Enable HTTPS in Tailscale, then return here. Both devices must be signed in to the same Tailscale network.';
            _notify();
          }
        }
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
          if (route == 'relay' && !address.isCompleted) {
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
        privateAddress != null
            ? Future.value(privateAddress)
            : address.future.timeout(const Duration(seconds: 60)),
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
      await _verifyAddress(uri, generation, cancelled);
      _check(generation);
      if (exited) {
        throw StateError(
          'The secure link is not reachable yet. Check internet access and retry.',
        );
      }
      endpoint = uri;
      ownerToken = owner;
      status = route == 'tailscale'
          ? 'Ready · private Tailscale network · keep Orbit and Tailscale open on both devices'
          : 'Ready · keep Orbit open on this PC';
    } catch (error) {
      if (generation == _generation) {
        await stop();
        status = error is StateError
            ? error.message.toString()
            : error is ProcessException && route == 'tailscale'
            ? 'Install Tailscale on this PC and tablet, sign in to the same network, then retry.'
            : error is TimeoutException
            ? 'The secure address did not become ready. Retry, use your private Tailscale network, or use your own HTTPS address.'
            : 'Could not start live sharing. Check internet access and retry.';
      }
      rethrow;
    } finally {
      if (generation == _generation) busy = false;
      _notify();
    }
  }

  Future<void> _verifyAddress(
    Uri uri,
    int generation,
    Completer<void> cancelled,
  ) async {
    final probe = _client();
    _transfer = probe;
    try {
      final localRequest = http.Request(
        'GET',
        localEndpoint!.resolve('/healthz'),
      )..followRedirects = false;
      final local = await probe
          .send(localRequest)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 3));
      final localState = jsonDecode(local.body) as Map;
      final instance = localState['instance'];
      if (local.statusCode != 200 ||
          localState['ready'] != true ||
          instance is! String ||
          instance.length != 43) {
        throw StateError(
          'The local sharing server is not ready. Stop sharing and retry.',
        );
      }
      final deadline = DateTime.now().add(const Duration(seconds: 50));
      while (DateTime.now().isBefore(deadline)) {
        _check(generation);
        try {
          // Compare the fresh non-secret host incarnation from loopback. The
          // owner credential never leaves the PC, including through a relay.
          final request = http.Request('GET', uri.resolve('/healthz'))
            ..followRedirects = false;
          final response = await Future.any<http.Response>([
            probe
                .send(request)
                .then(http.Response.fromStream)
                .timeout(const Duration(seconds: 3)),
            cancelled.future.then<http.Response>(
              (_) => throw StateError('Live sharing was cancelled.'),
            ),
          ]);
          _check(generation);
          if (response.statusCode == 200) {
            final body = jsonDecode(response.body) as Map;
            if (body['service'] == 'orbit-collaboration' &&
                body['ready'] == true &&
                body['instance'] == instance) {
              return;
            }
          }
        } catch (_) {
          _check(generation);
        }
        await Future.any([
          Future<void>.delayed(const Duration(milliseconds: 500)),
          cancelled.future,
        ]);
      }
      throw TimeoutException('Sharing address did not become ready.');
    } finally {
      probe.close();
      if (identical(_transfer, probe)) _transfer = null;
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
