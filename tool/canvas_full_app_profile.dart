// Native-only diagnostic entry point. Ordinary release builds use lib/main.dart.
// The private service endpoint is written only to the caller's ignored local
// output file and must never be included in source/release artifacts.
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:orbit_note/main.dart' as app;

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('Supply a private local diagnostics file.');
  }
  await app.main(const []);
  final info = await developer.Service.controlWebServer(
    enable: true,
    silenceOutput: true,
  ).timeout(const Duration(seconds: 10));
  final uri = info.serverUri;
  if (uri == null ||
      !const {'127.0.0.1', 'localhost', '::1'}.contains(uri.host)) {
    await developer.Service.controlWebServer(
      enable: false,
      silenceOutput: true,
    );
    await File(args.single).writeAsString(jsonEncode({'available': false}));
    return;
  }
  await File(
    args.single,
  ).writeAsString(jsonEncode({'available': true, 'uri': uri.toString()}));
}
