import 'dart:async';

abstract interface class LabProtocolConnection {
  Stream<String> get lines;
  Future<void> send(String line);
  Future<void> close();
}

class SmqpSession {
  String phase = 'greeting';
  bool subscribed = false;
  String? pending;
  final log = <String>[];
  void client(String line) {
    if (log.length >= 1000 ||
        line.length > 8192 ||
        line.contains(RegExp(r'[\r\n\x00]'))) {
      throw const FormatException(
        'Use a single command line; maximum 1000 observations.',
      );
    }
    if (pending != null || phase == 'greeting' || phase == 'closed') {
      throw const FormatException(
        'Wait for the greeting/response, or open a new connection.',
      );
    }
    final parts = line.trim().split(RegExp(r'\s+')), command = parts.first;
    final count = switch (command) {
      'exchange' => 3,
      'queue' => 2,
      'bind' => 2,
      'subscribe' => 1,
      'publish' => 3,
      'exit' => 1,
      _ => 0,
    };
    if (count == 0 || parts.length != count) {
      throw const FormatException('Invalid SMQP command or argument count.');
    }
    final permitted = switch (command) {
      'exchange' => phase == 'exchange',
      'queue' => phase == 'queue',
      'bind' => phase == 'bind',
      'subscribe' || 'publish' => phase == 'ready',
      'exit' => true,
      _ => false,
    };
    if (!permitted) {
      throw FormatException('$command is not valid in phase $phase.');
    }
    if (command == 'exchange' &&
        !{'default', 'direct', 'fanout', 'topic'}.contains(parts[1])) {
      throw const FormatException('Unknown exchange type.');
    }
    pending = command;
    log.add('C> $line');
  }

  void server(String line) {
    if (log.length >= 1000 || line.length > 8192) {
      throw const FormatException('Protocol log limit reached.');
    }
    log.add('S> $line');
    if (phase == 'greeting') {
      if (line != 'ok SMQP') {
        throw const FormatException('Expected ok SMQP greeting.');
      }
      phase = 'exchange';
      return;
    }
    final p = pending;
    if (p == null) {
      if (!subscribed) {
        throw const FormatException(
          'Unsolicited response without subscription.',
        );
      }
      return;
    }
    if (line.startsWith('error')) {
      pending = null;
      return;
    }
    if (line != (p == 'exit' ? 'ok bye' : 'ok')) {
      throw const FormatException('Unexpected command acknowledgment.');
    }
    phase = switch (p) {
      'exchange' => 'queue',
      'queue' => 'bind',
      'bind' => 'ready',
      'exit' => 'closed',
      _ => phase,
    };
    if (p == 'subscribe') subscribed = true;
    pending = null;
  }
}

SmqpSession checkProtocolTranscript(String text) {
  if (text.length > 500000) {
    throw const FormatException('Transcript exceeds 500 KB.');
  }
  final session = SmqpSession();
  for (final raw in text.split(RegExp(r'\r\n|\r|\n'))) {
    if (raw.trim().isEmpty) continue;
    if (raw.startsWith('C> ')) {
      session.client(raw.substring(3));
    } else if (raw.startsWith('S> ')) {
      session.server(raw.substring(3));
    } else {
      throw const FormatException('Prefix every line with C> or S>.');
    }
  }
  return session;
}
