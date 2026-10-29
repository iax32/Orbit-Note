import 'dart:async';
import 'dart:isolate';
import '../../domain/universal_object.dart';
import 'object_encoding_types.dart';

/// Native CPU work only; the repository retains authority and ordered writes.
Future<T> runObjectEncoding<T>(T Function() work, {required int size}) =>
    size >= 65536 ? Isolate.run(work) : Future.value(work());

ObjectSaveExecutor createObjectSaveExecutor(
  ObjectSaveEncoder encoder,
  ObjectSeedDecoder decoder,
) => _SnapshotEncoder(encoder, decoder);

Future<ObjectEncoding> _encodeFull(
  ObjectSaveEncoder encoder,
  UniversalObject object,
  String? previousSource,
) => Isolate.run(() => encoder(object, previousSource));

/// One derived board cache per codec/repository. The normal file codec and
/// repository still own validation, exact bytes and ordered durable writes.
class _SnapshotEncoder implements ObjectSaveExecutor {
  _SnapshotEncoder(this.encoder, this.decoder);
  final ObjectSaveEncoder encoder;
  final ObjectSeedDecoder decoder;
  Future<void> _queue = Future.value();
  Isolate? _worker;
  bool _dead = false;
  SendPort? _commands;
  ReceivePort? _errors;
  StreamSubscription<dynamic>? _errorListener;
  Completer<List<dynamic>>? _active;
  (String, String)? _key;
  Expando<int> _ids = Expando<int>();
  final _known = <int>{};
  int _next = 0;

  @override
  Future<ObjectEncoding> encode(
    UniversalObject object, {
    UniversalObject? previousObject,
    String? previousSource,
    required int size,
  }) {
    final result = Completer<ObjectEncoding>();
    _queue = _queue.then((_) async {
      try {
        final elements = object.data['elements'];
        if (size < 65536) {
          result.complete(encoder(object, previousSource));
        } else if ((object.typeId == 'orbit.canvas' ||
                object.typeId == 'orbit.drawing') &&
            elements is List) {
          result.complete(
            await _encodeBoard(
              object,
              elements,
              previousObject,
              previousSource,
            ),
          );
        } else {
          // Strings/byte buffers are cheap to hand off; this path also retains
          // compatibility for non-Canvas object shapes.
          result.complete(await _encodeFull(encoder, object, previousSource));
        }
      } catch (error, stack) {
        await _stop();
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  int _slot(Object? value) {
    if (value is Map<String, dynamic> && isImmutableObjectData(value)) {
      return _ids[value] ??= ++_next;
    }
    return ++_next;
  }

  Future<ObjectEncoding> _encodeBoard(
    UniversalObject object,
    List elements,
    UniversalObject? previous,
    String? previousSource,
  ) async {
    await _start();
    final key = (object.workspaceId, object.id);
    final reset = _key != key;
    List<int>? seedSlots;
    if (reset) {
      _ids = Expando<int>();
      _next = 0;
      _known.clear();
      final old = previous?.data['elements'];
      if (previousSource != null &&
          old is List &&
          previous?.id == object.id &&
          previous?.workspaceId == object.workspaceId) {
        seedSlots = [for (final value in old) _slot(value)];
        _known.addAll(seedSlots);
      }
    }
    final order = <int>[];
    final updates = <int, dynamic>{};
    for (final value in elements) {
      final slot = _slot(value);
      order.add(slot);
      if (!_known.contains(slot)) updates[slot] = value;
    }
    final message = <String, dynamic>{
      'reset': reset,
      'object': object.toJson(),
      'body': object.body,
      'formatVersion': object.formatVersion,
      'documentExtra': object.documentExtra,
      'data': {...object.data}..remove('elements'),
      'order': order,
      'updates': updates,
      if (seedSlots != null) 'seed': previousSource,
      'seedSlots': ?seedSlots,
    };
    var reply = await _request(message);
    if (reply.first == 'seed') {
      // A caller may supply an unrelated previous source. Structured encoding
      // historically ignored it; preserve that behavior with a full reseed.
      message.remove('seed');
      message.remove('seedSlots');
      message['reset'] = true;
      message['updates'] = {
        for (var i = 0; i < order.length; i++) order[i]: elements[i],
      };
      reply = await _request(message);
    }
    if (reply.first != 'ok') throw StateError(reply[1] as String);
    _key = key;
    _known
      ..clear()
      ..addAll(order);
    return (
      source: reply[1] as String,
      bytes: (reply[2] as TransferableTypedData).materialize().asUint8List(),
      hash: reply[3] as String,
    );
  }

  Future<void> _start() async {
    if (_commands != null && !_dead) return;
    if (_dead) await _stop();
    final ready = ReceivePort();
    final started = Completer<SendPort>();
    ready.listen((value) {
      if (!started.isCompleted) started.complete(value as SendPort);
    });
    _errors = ReceivePort();
    _errorListener = _errors!.listen((value) {
      _dead = true;
      final error = StateError(
        'The local file encoder stopped; the editor draft is retained.',
      );
      if (!started.isCompleted) started.completeError(error);
      if (_active?.isCompleted == false) _active!.completeError(error);
    });
    try {
      _worker = await Isolate.spawn(
        _encodingWorker,
        [ready.sendPort, encoder, decoder],
        onError: _errors!.sendPort,
        onExit: _errors!.sendPort,
      );
      _commands = await started.future.timeout(const Duration(seconds: 30));
    } finally {
      ready.close();
    }
  }

  Future<List<dynamic>> _request(Map<String, dynamic> message) async {
    final response = ReceivePort();
    final completed = Completer<List<dynamic>>();
    _active = completed;
    response.listen((value) {
      if (!completed.isCompleted) completed.complete(value as List<dynamic>);
    });
    try {
      _commands!.send([message, response.sendPort]);
      return await completed.future.timeout(const Duration(minutes: 2));
    } finally {
      response.close();
      if (identical(_active, completed)) _active = null;
    }
  }

  Future<void> _stop() async {
    await _errorListener?.cancel();
    _errorListener = null;
    _errors?.close();
    _errors = null;
    _worker?.kill(priority: Isolate.immediate);
    _worker = null;
    _commands = null;
    _dead = false;
    _key = null;
    _ids = Expando<int>();
    _next = 0;
    _known.clear();
  }

  @override
  Future<void> close() async {
    await _queue;
    await _stop();
  }
}

void _encodingWorker(List<dynamic> arguments) {
  final parent = arguments[0] as SendPort;
  final encoder = arguments[1] as ObjectSaveEncoder;
  final decoder = arguments[2] as ObjectSeedDecoder;
  final commands = ReceivePort();
  final records = <int, dynamic>{};
  parent.send(commands.sendPort);
  commands.listen((request) {
    final message = request[0] as Map;
    final reply = request[1] as SendPort;
    try {
      if (message['reset'] == true) records.clear();
      if (message['seed'] is String) {
        try {
          final seed = decoder(
            message['seed'] as String,
            message['object']['workspaceId'] as String,
          );
          final elements = seed.data['elements'];
          final slots = message['seedSlots'] as List;
          if (elements is! List ||
              elements.length != slots.length ||
              seed.id != message['object']['id']) {
            throw const FormatException('Previous source does not match.');
          }
          for (var i = 0; i < slots.length; i++) {
            records[slots[i] as int] = elements[i];
          }
        } catch (_) {
          records.clear();
          reply.send(['seed']);
          return;
        }
      }
      records.addAll(Map<int, dynamic>.from(message['updates'] as Map));
      final order = (message['order'] as List).cast<int>();
      final live = order.toSet();
      records.removeWhere((key, _) => !live.contains(key));
      if (!order.every(records.containsKey)) {
        throw StateError('Incomplete local encoding snapshot.');
      }
      final object = UniversalObject.fromJson(
        Map<String, dynamic>.from(message['object'] as Map),
        body: message['body'] as String,
        formatVersion: message['formatVersion'] as int,
        documentExtra: Map<String, dynamic>.from(
          message['documentExtra'] as Map,
        ),
        data: {
          ...Map<String, dynamic>.from(message['data'] as Map),
          'elements': [for (final slot in order) records[slot]],
        },
      );
      final encoded = encoder(object, null);
      reply.send([
        'ok',
        encoded.source,
        TransferableTypedData.fromList([encoded.bytes]),
        encoded.hash,
      ]);
    } catch (error) {
      records.clear();
      reply.send(['error', error.toString()]);
    }
  });
}
