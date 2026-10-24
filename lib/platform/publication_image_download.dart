import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Explicit, anonymous export-only reads. No Vault uploads, cookies, credentials
/// or persistent web cache. Owning clients close on cancel, timeout and disposal.
class PublicationImageDownload {
  PublicationImageDownload({
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 20),
  }) : _clientFactory = clientFactory ?? http.Client.new;
  static const maxBytes = 20 * 1024 * 1024;
  final http.Client Function() _clientFactory;
  final Duration timeout;
  final _active = <http.Client>{};
  bool _disposed = false;
  int _generation = 0;

  static bool allows(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      uri.toString().length <= 8192;

  Future<Uint8List> read(Uri uri) async {
    if (_disposed || !allows(uri)) {
      throw const FormatException(
        'Use an HTTPS image address without credentials.',
      );
    }
    final client = _clientFactory();
    _active.add(client);
    final generation = _generation;
    var active = true;
    bool current() => active && !_disposed && generation == _generation;
    try {
      return await _read(client, uri, current).timeout(timeout);
    } finally {
      active = false;
      _active.remove(client);
      client.close();
    }
  }

  Future<Uint8List> _read(
    http.Client client,
    Uri uri,
    bool Function() current,
  ) async {
    for (var redirects = 0; redirects <= 3; redirects++) {
      if (!current() || !allows(uri)) {
        throw const FormatException('Unsupported image redirect.');
      }
      final response = await client.send(
        http.Request('GET', uri)..followRedirects = false,
      );
      if (!current()) {
        await response.stream.listen((_) {}).cancel();
        throw const FormatException('Image loading cancelled.');
      }
      if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final location = response.headers['location'];
        // Cancel rather than draining an arbitrary redirect response body.
        await response.stream.listen((_) {}).cancel();
        if (location == null || redirects == 3) {
          throw const FormatException('Image redirect limit reached.');
        }
        uri = uri.resolve(location);
        continue;
      }
      final type = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > maxBytes ||
          (type != null &&
              !type.startsWith('image/') &&
              type != 'application/octet-stream')) {
        await response.stream.listen((_) {}).cancel();
        throw const FormatException(
          'Image unavailable, unsupported or larger than 20 MiB.',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        if (!current() || bytes.length + chunk.length > maxBytes) {
          throw const FormatException('Image cancelled or larger than 20 MiB.');
        }
        bytes.add(chunk);
      }
      if (!current()) throw const FormatException('Image loading cancelled.');
      return bytes.takeBytes();
    }
    throw const FormatException('Image redirect limit reached.');
  }

  void cancel() {
    _generation++;
    for (final client in _active.toList()) {
      client.close();
    }
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
