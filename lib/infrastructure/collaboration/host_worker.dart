import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'server.dart';

/// Owns the HTTP server, merge engine and durable server journal off the UI
/// isolate. Only startup metadata and a stop command cross this boundary.
class CollaborationHostWorker {
  CollaborationHostWorker._() {
    _messages = _events.listen((message) {
      if (message is List && message.length == 2 && message[0] is SendPort) {
        _commands = message[0] as SendPort;
        if (!_ready.isCompleted) _ready.complete(message[1] as int);
      } else if (message is String && !_ready.isCompleted) {
        _ready.completeError(StateError(message));
      }
    });
    _errorEvents = _errors.listen((_) => _failed());
    _exitEvents = _exits.listen((_) {
      _failed();
      if (!_done.isCompleted) _done.complete();
    });
  }

  final _events = ReceivePort(),
      _errors = ReceivePort(),
      _exits = ReceivePort();
  final _ready = Completer<int>(), _done = Completer<void>();
  late final StreamSubscription<dynamic> _messages, _errorEvents, _exitEvents;
  Isolate? _isolate;
  SendPort? _commands;
  Future<void>? _closing;
  late final int port;
  Future<void> get done => _done.future;

  void _failed() {
    if (!_ready.isCompleted) {
      _ready.completeError(
        StateError(
          'The local sharing server stopped. Start live sharing again.',
        ),
      );
    }
  }

  static Future<CollaborationHostWorker> start(
    Directory directory,
    String owner, {
    int port = 0,
  }) async {
    final worker = CollaborationHostWorker._();
    // Attach an early handler even if spawn itself has not completed when the
    // child reports a startup error. The await below still receives that error.
    unawaited(
      worker._ready.future.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      ),
    );
    try {
      worker._isolate = await Isolate.spawn(
        _serve,
        [worker._events.sendPort, directory.path, owner, port],
        onError: worker._errors.sendPort,
        onExit: worker._exits.sendPort,
        errorsAreFatal: true,
        debugName: 'Orbit live server',
      );
      worker.port = await worker._ready.future.timeout(
        const Duration(seconds: 20),
      );
      return worker;
    } catch (_) {
      await worker.close();
      rethrow;
    }
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _commands?.send('stop');
    try {
      // Server.close drains its serial journal before releasing its file lease.
      if (_isolate != null && _commands != null) {
        await done.timeout(const Duration(seconds: 10));
      }
    } on TimeoutException {
      _isolate?.kill(priority: Isolate.immediate);
    } finally {
      _isolate?.kill(priority: Isolate.immediate);
      await _messages.cancel();
      await _errorEvents.cancel();
      await _exitEvents.cancel();
      _events.close();
      _errors.close();
      _exits.close();
      if (!_done.isCompleted) _done.complete();
    }
  }

  static Future<void> _serve(List<Object> args) async {
    final parent = args[0] as SendPort;
    final commands = ReceivePort();
    final server = CollaborationServer(
      Directory(args[1] as String),
      args[2] as String,
    );
    String? failure;
    try {
      final port = await server.start(port: args[3] as int);
      parent.send([commands.sendPort, port]);
      await commands.firstWhere((message) => message == 'stop');
    } catch (_) {
      failure =
          'The local sharing server could not start. Check available storage and retry.';
    } finally {
      commands.close();
      await server.close();
    }
    if (failure != null) parent.send(failure);
  }
}
