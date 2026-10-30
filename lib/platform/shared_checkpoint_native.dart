import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

const maxSharedCheckpointBytes = 256 * 1024 * 1024;

// Only device recovery state is compressed. Authored Vault bytes, exports and
// cloud formats stay unchanged. Older plain JSON checkpoints still read normally.
Future<Uint8List> encodeSharedCheckpoint(Map<String, dynamic> state) =>
    Isolate.run(() {
      final bytes = utf8.encode(jsonEncode(state));
      if (bytes.length > maxSharedCheckpointBytes) {
        throw const FormatException('Shared recovery state exceeds 256 MiB.');
      }
      if (bytes.length <= 256 * 1024) return Uint8List.fromList(bytes);
      return Uint8List.fromList(gzip.encode(bytes));
    });

Future<Map<String, dynamic>> decodeSharedCheckpoint(Uint8List bytes) =>
    Isolate.run(() {
      if (bytes.length < 2 || bytes[0] != 31 || bytes[1] != 139) {
        return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      }
      final output = _BoundedCheckpointSink();
      final decoder = gzip.decoder.startChunkedConversion(output);
      // Incremental inflation enforces the decoded bound, including zip bombs.
      for (var offset = 0; offset < bytes.length; offset += 1024) {
        decoder.add(
          Uint8List.sublistView(
            bytes,
            offset,
            (offset + 1024).clamp(0, bytes.length),
          ),
        );
      }
      decoder.close();
      return jsonDecode(utf8.decode(output.bytes.takeBytes()))
          as Map<String, dynamic>;
    });

class _BoundedCheckpointSink implements Sink<List<int>> {
  final bytes = BytesBuilder(copy: false);
  @override
  void add(List<int> value) {
    if (bytes.length + value.length > maxSharedCheckpointBytes) {
      throw const FormatException('Shared recovery state exceeds 256 MiB.');
    }
    bytes.add(value);
  }

  @override
  void close() {}
}
