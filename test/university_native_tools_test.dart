import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/platform/university_tools_native.dart';
import 'package:orbit_note/domain/university/protocol_lab.dart';

void main() {
  test(
    'real local TCP preserves fragmented Unicode frames and stateful SMQP exchange',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final received = <String>[], session = SmqpSession();
      final peerDone = Completer<void>();
      server.listen((socket) {
        socket.add(utf8.encode('ok SM'));
        socket.add(utf8.encode('QP\r\n'));
        socket
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
              received.add(line);
              socket.add(utf8.encode(line == 'exit' ? 'ok bye\n' : 'ok\n'));
              if (line == 'exit') {
                socket.close();
                peerDone.complete();
              }
            });
      });
      final client = await connectUniversityProtocol('127.0.0.1', server.port);
      addTearDown(client.close);
      final lines = StreamIterator(client.lines);
      expect(await lines.moveNext(), true);
      session.server(lines.current);
      for (final command in [
        'exchange fanout animals',
        'queue cats',
        'bind none',
        'publish none Grüße_中文',
        'exit',
      ]) {
        session.client(command);
        await client.send(command);
        expect(await lines.moveNext(), true);
        session.server(lines.current);
      }
      expect(received[3], contains('Grüße_中文'));
      expect(session.phase, 'closed');
      await peerDone.future;
      await lines.cancel();
    },
  );
  test('overlong peer frames terminate with a bounded error', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((socket) {
      socket.add(List<int>.filled(9000, 65));
    });
    final client = await connectUniversityProtocol('127.0.0.1', server.port);
    addTearDown(client.close);
    await expectLater(client.lines, emitsError(isA<FormatException>()));
  });
  test('missing verifier fails without inventing a result', () async {
    await expectLater(
      verifyUniversityDafny('orbit-no-such-verifier-12345', 'method M() {}'),
      throwsA(isA<ProcessException>()),
    );
  });
}
