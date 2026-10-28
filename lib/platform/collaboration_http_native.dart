import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

bool isOrbitTemporaryHost(String host) =>
    RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)+\.trycloudflare\.com$').hasMatch(host);

final _relayDnsCache =
    <String, ({InternetAddress address, DateTime expires})>{};

/// Cloudflare DNS fallback is limited to the user's temporary relay host. TLS
/// still authenticates the original hostname; no bad-certificate override.
http.Client createCollaborationHttpClient() {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final cache = _relayDnsCache;
  Future<InternetAddress> resolve(String host) async {
    final prior = cache[host];
    if (prior != null && prior.expires.isAfter(DateTime.now())) {
      return prior.address;
    }
    try {
      final native = await InternetAddress.lookup(
        host,
        type: InternetAddressType.IPv4,
      ).timeout(const Duration(seconds: 3));
      if (native.isNotEmpty) return native.first;
    } on SocketException {
      /* ISP DNS may negatively cache new relay names. */
    } on TimeoutException {
      /* Use the same provider's authenticated resolver. */
    }
    final dns = http.Client();
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        final response = await dns
            .get(
              Uri.https('cloudflare-dns.com', '/dns-query', {
                'name': host,
                'type': 'A',
              }),
              headers: {
                'Accept': 'application/dns-json',
                'Cache-Control': 'no-cache',
              },
            )
            .timeout(const Duration(seconds: 5));
        if (response.statusCode != 200 || response.bodyBytes.length > 65536) {
          throw const SocketException('Secure relay DNS unavailable.');
        }
        final body = jsonDecode(response.body) as Map;
        if (body['Status'] != 0 || body['Answer'] is! List) {
          if (attempt < 2) {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            continue;
          }
          throw const SocketException('Secure relay hostname is not ready.');
        }
        for (final record in body['Answer'] as List) {
          if (record is! Map ||
              record['type'] != 1 ||
              record['data'] is! String ||
              !{host, '$host.'}.contains(record['name'])) {
            continue;
          }
          final address = InternetAddress.tryParse(record['data'] as String);
          if (address == null || address.type != InternetAddressType.IPv4) {
            continue;
          }
          final b = address.rawAddress;
          if (b[0] == 0 ||
              b[0] == 10 ||
              b[0] == 127 ||
              b[0] >= 224 ||
              (b[0] == 169 && b[1] == 254) ||
              (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
              (b[0] == 192 && b[1] == 168)) {
            continue;
          }
          if (cache.length >= 32) cache.remove(cache.keys.first);
          final ttl = record['TTL'] is int
              ? (record['TTL'] as int).clamp(1, 60)
              : 30;
          cache[host] = (
            address: address,
            expires: DateTime.now().add(Duration(seconds: ttl)),
          );
          return address;
        }
        throw const SocketException(
          'Secure relay DNS did not return a public address.',
        );
      }
      throw const SocketException('Secure relay DNS unavailable.');
    } finally {
      dns.close();
    }
  }

  client.connectionFactory = (uri, proxyHost, proxyPort) async {
    if (proxyHost != null) return Socket.startConnect(proxyHost, proxyPort!);
    if (uri.scheme == 'https' && isOrbitTemporaryHost(uri.host)) {
      final address = await resolve(uri.host);
      final task = await Socket.startConnect(address, uri.port);
      return ConnectionTask.fromSocket(
        task.socket.then(
          (socket) => SecureSocket.secure(socket, host: uri.host),
        ),
        task.cancel,
      );
    }
    if (uri.scheme == 'https') {
      return SecureSocket.startConnect(uri.host, uri.port);
    }
    return Socket.startConnect(uri.host, uri.port);
  };
  return IOClient(client);
}
