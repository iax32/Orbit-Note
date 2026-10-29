import 'dart:typed_data';
import '../../domain/universal_object.dart';

typedef ObjectEncoding = ({String source, Uint8List bytes, String hash});
typedef ObjectSaveEncoder = ObjectEncoding Function(UniversalObject, String?);
typedef ObjectSeedDecoder = UniversalObject Function(String, String);

abstract interface class ObjectSaveExecutor {
  Future<ObjectEncoding> encode(
    UniversalObject object, {
    UniversalObject? previousObject,
    String? previousSource,
    required int size,
  });
  Future<void> close();
}
