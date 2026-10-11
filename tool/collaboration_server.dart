import 'dart:io';
import 'package:orbit_note/infrastructure/collaboration/server.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help')) {
    stdout.writeln(
      'dart --packages=.dart_tool/package_config.json tool/collaboration_server.dart DATA_DIRECTORY [BIND_ADDRESS] [PORT]\nDefault: 127.0.0.1:47831. Put a TLS reverse proxy in front for remote access.',
    );
    return;
  }
  final directory = Directory(args[0]).absolute;
  await directory.create(recursive: true);
  final secret = File('${directory.path}/owner-key.secret');
  if (!await secret.exists()) {
    await secret.writeAsString(collaborationToken(), flush: true);
  }
  final server = CollaborationServer(
    directory,
    (await secret.readAsString()).trim(),
  );
  final port = await server.start(
    address: InternetAddress(args.length > 1 ? args[1] : '127.0.0.1'),
    port: args.length > 2 ? int.parse(args[2]) : 47831,
  );
  stdout.writeln(
    'Orbit collaboration listening on port $port. Owner key is in ${secret.path}. Keep it private.',
  );
  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    exit(0);
  });
}
