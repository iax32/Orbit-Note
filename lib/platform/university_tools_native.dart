import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../domain/code_project.dart';
import '../domain/university/protocol_lab.dart';

bool get universityToolsSupported => !Platform.isAndroid && !Platform.isIOS;

Future<LabProtocolConnection> connectUniversityProtocol(
  String host,
  int port,
) async {
  if (!universityToolsSupported) {
    throw UnsupportedError('TCP lab requires desktop.');
  }
  if (host.trim().isEmpty ||
      host.length > 253 ||
      host.contains(RegExp(r'[\s\x00]')) ||
      port < 1 ||
      port > 65535) {
    throw const FormatException('Enter a valid host and port (1–65535).');
  }
  return _Connection(
    await Socket.connect(host, port, timeout: const Duration(seconds: 8)),
  );
}

class _Connection implements LabProtocolConnection {
  _Connection(this.socket) {
    subscription = socket.listen(
      (bytes) {
        if (closed) return;
        // Bound framing before UTF-8 decoding, including peers without newlines.
        for (final b in bytes) {
          if (b == 10) {
            if (++count > 1000) {
              _fail(const FormatException('TCP log reached 1000 lines.'));
              return;
            }
            try {
              output.add(utf8.decode(buffer).replaceFirst(RegExp(r'\r$'), ''));
            } catch (e) {
              _fail(e);
              return;
            }
            buffer.clear();
          } else {
            buffer.add(b);
            if (buffer.length > 8192) {
              _fail(const FormatException('TCP line exceeds 8 KB.'));
              return;
            }
          }
        }
      },
      onError: _fail,
      onDone: () {
        if (buffer.isNotEmpty && !closed) {
          output.addError(
            const FormatException('Peer closed an incomplete line.'),
          );
        }
        close();
      },
    );
  }
  final Socket socket;
  final buffer = <int>[];
  final output = StreamController<String>();
  late final StreamSubscription<List<int>> subscription;
  int count = 0;
  bool closed = false;
  void _fail(Object error) {
    if (!closed) output.addError(error);
    close();
  }

  @override
  Stream<String> get lines => output.stream;
  @override
  Future<void> send(String line) async {
    if (closed || line.length > 8192 || line.contains(RegExp(r'[\r\n\x00]'))) {
      throw const FormatException('Connection closed or invalid command line.');
    }
    socket.add(utf8.encode('$line\n'));
    await socket.flush();
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    socket.destroy();
    await subscription.cancel();
    unawaited(output.close());
  }
}

Future<CodeToolProcess> verifyUniversityDafny(
  String executable,
  String source,
) async {
  if (!universityToolsSupported) {
    throw UnsupportedError('Dafny requires desktop.');
  }
  if (executable.trim().isEmpty ||
      executable.contains(RegExp(r'[\r\n\x00]')) ||
      source.length > 100000) {
    throw const FormatException(
      'Select a Dafny executable and bounded source.',
    );
  }
  final folder = await Directory.systemTemp.createTemp('orbit-dafny-');
  try {
    final file = File('${folder.path}${Platform.pathSeparator}model.dfy');
    await file.writeAsString(source, flush: true);
    final process = await Process.start(
      executable,
      ['verify', file.path],
      workingDirectory: folder.path,
      runInShell: false,
    );
    return _Verifier(process, folder);
  } catch (_) {
    await folder.delete(recursive: true);
    rethrow;
  }
}

class _Verifier implements CodeToolProcess {
  _Verifier(this.process, this.folder) {
    a = process.stdout
        .transform(utf8.decoder)
        .listen(emit, onError: (Object e) => emit('$e'));
    b = process.stderr
        .transform(utf8.decoder)
        .listen(emit, onError: (Object e) => emit('$e'));
    aDone = a.asFuture<void>();
    bDone = b.asFuture<void>();
    timer = Timer(const Duration(seconds: 45), () {
      timedOut = true;
      emit('\nVerification timed out after 45 seconds.\n');
      process.kill();
    });
    result = process.exitCode.then((code) async {
      timer.cancel();
      await aDone.catchError((Object _) {});
      await bDone.catchError((Object _) {});
      await folder.delete(recursive: true);
      unawaited(outputController.close());
      return timedOut || cancelled || overflow ? -1 : code;
    });
  }
  final Process process;
  final Directory folder;
  final outputController = StreamController<String>();
  late final StreamSubscription<String> a, b;
  late final Future<void> aDone, bDone;
  late final Timer timer;
  late final Future<int> result;
  int bytes = 0;
  bool timedOut = false, cancelled = false, overflow = false;
  void emit(String value) {
    if (bytes + value.length > 200000) {
      if (bytes <= 200000) outputController.add('\nOutput limit reached.\n');
      bytes = 200001;
      overflow = true;
      process.kill();
      return;
    }
    bytes += value.length;
    outputController.add(value);
  }

  @override
  Stream<String> get output => outputController.stream;
  @override
  Future<int> get exitCode => result;
  @override
  Future<void> writeInput(String text) async =>
      throw UnsupportedError('Dafny verification is not interactive.');
  @override
  Future<void> stop() async {
    cancelled = true;
    process.kill();
    await result;
  }
}
