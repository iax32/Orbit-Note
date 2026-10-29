import '../../domain/universal_object.dart';
import 'object_encoding_types.dart';

/// Browser-compatible fallback. No native isolate API enters shared code.
Future<T> runObjectEncoding<T>(T Function() work, {required int size}) =>
    Future.value(work());

ObjectSaveExecutor createObjectSaveExecutor(
  ObjectSaveEncoder encoder,
  ObjectSeedDecoder decoder,
) => _DirectEncoder(encoder);

class _DirectEncoder implements ObjectSaveExecutor {
  _DirectEncoder(this.encoder);
  final ObjectSaveEncoder encoder;
  @override
  Future<ObjectEncoding> encode(
    UniversalObject object, {
    UniversalObject? previousObject,
    String? previousSource,
    required int size,
  }) async => encoder(object, previousSource);
  @override
  Future<void> close() async {}
}
