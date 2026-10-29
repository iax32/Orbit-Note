import 'dart:async';
import 'dart:isolate';

/// A lazy serial native worker. Callers own queue bounds and pass a top-level
/// handler, never a repository/controller closure. Failed workers restart on the
/// next request; close drains accepted work before releasing resources.
class NativeTaskWorker<Q, R> {
  NativeTaskWorker(this.handler);
  final R Function(Q) handler;
  Future<void> _tail = Future.value();
  Future<void>? _closing;
  Future<SendPort>? _starting;
  Isolate? _isolate;
  ReceivePort? _responses, _errors, _exits;
  StreamSubscription<dynamic>? _messages, _errorEvents, _exitEvents;
  Completer<R>? _active;
  bool _closed = false;

  Future<R> run(Q request) {
    if (_closed) return Future.error(StateError('Native worker is closed.'));
    final result = Completer<R>();
    _tail = _tail.then((_) async {
      _active = result;
      try {
        final port = await (_starting ??= _start());
        if (!result.isCompleted) port.send(request);
        await result.future;
      } catch (error, stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      } finally {
        if (identical(_active, result)) _active = null;
      }
    });
    return result.future;
  }

  Future<SendPort> _start() async {
    final ready = Completer<SendPort>();
    final responses = _responses = ReceivePort();
    final errors = _errors = ReceivePort();
    final exits = _exits = ReceivePort();
    void failed() {
      if (_responses != responses) return;
      final error = StateError(
        'Native worker stopped; the request did not complete.',
      );
      if (!ready.isCompleted) ready.completeError(error);
      final active = _active;
      _retire();
      if (active != null && !active.isCompleted) active.completeError(error);
    }

    _messages = responses.listen((message) {
      if (_responses != responses) return;
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
      } else if (message is List && message.length == 2) {
        final active = _active;
        if (active == null || active.isCompleted) return;
        if (message[0] == true) {
          active.complete(message[1] as R);
        } else {
          active.completeError(StateError('Native task failed: ${message[1]}'));
        }
      }
    });
    _errorEvents = errors.listen((_) => failed());
    _exitEvents = exits.listen((_) => failed());
    try {
      final isolate = await Isolate.spawn(
        _entry,
        [handler, responses.sendPort],
        onError: errors.sendPort,
        onExit: exits.sendPort,
        errorsAreFatal: true,
      );
      if (_responses != responses) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        _isolate = isolate;
      }
      return await ready.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      if (_responses == responses) _retire();
      rethrow;
    }
  }

  void _retire() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _starting = null;
    unawaited(_messages?.cancel());
    unawaited(_errorEvents?.cancel());
    unawaited(_exitEvents?.cancel());
    _responses?.close();
    _errors?.close();
    _exits?.close();
    _responses = _errors = _exits = null;
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    await _tail;
    _retire();
  }
}

void _entry(List<Object> args) {
  final handler = args[0] as Function;
  final replies = args[1] as SendPort;
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  requests.listen((request) {
    try {
      replies.send([
        true,
        Function.apply(handler, [request]),
      ]);
    } catch (error) {
      replies.send([false, error.toString()]);
    }
  });
}
