import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';

class _DigestResult implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest value) => this.value = value;
  @override
  void close() {}
}

Future<({String sha256, String? md5})> _readDigests(
  String path,
  bool includeMd5,
) async {
  final shaResult = _DigestResult(), md5Result = _DigestResult();
  final sha = sha256.startChunkedConversion(shaResult);
  final md = includeMd5 ? md5.startChunkedConversion(md5Result) : null;
  await for (final bytes in File(path).openRead()) {
    sha.add(bytes);
    md?.add(bytes);
  }
  sha.close();
  md?.close();
  return (sha256: shaResult.value.toString(), md5: md5Result.value?.toString());
}

/// Recheck disk bytes, not cached paths. Only compact digests cross isolates;
/// large sync staging/commit checks must not monopolize pen input.
Future<({String sha256, String? md5})?> nativeFileDigests(
  File file, {
  bool includeMd5 = false,
}) async {
  if (!await file.exists()) return null;
  final path = file.path;
  return await file.length() >= 256 * 1024
      ? Isolate.run(() => _readDigests(path, includeMd5))
      : _readDigests(path, includeMd5);
}
