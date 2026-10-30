// Isolated synthetic probe; no personal Vault or network access.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:orbit_note/platform/shared_checkpoint_native.dart';

Future<Map<String, int>> measure(Future<void> Function() action) async {
  final clock = Stopwatch()..start();
  var previous = 0, maximum = 0, ticks = 0;
  void sample() {
    final gap = clock.elapsedMicroseconds - previous;
    if (gap > maximum) maximum = gap;
    previous = clock.elapsedMicroseconds;
  }

  final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
    sample();
    ticks++;
  });
  try {
    await action();
    sample();
    return {
      'wallUs': clock.elapsedMicroseconds,
      'callerGapUs': maximum,
      'ticks': ticks,
    };
  } finally {
    timer.cancel();
  }
}

Future<void> main() async {
  final points = [
    for (var i = 0; i < 96000; i++)
      {
        'x': i * .13,
        'y': i % 200 * .7,
        'pressure': (i % 100) / 100,
        'timeMs': i * 2,
      },
  ];
  final snapshot = {
    'id': 'synthetic',
    'data': {
      'elements': [
        {'id': 'ink', 'type': 'ink', 'points': points},
      ],
    },
  };
  final state = <String, dynamic>{
    'documents': {
      'board': {'snapshot': snapshot},
    },
    'inflight': {
      'board': {'snapshot': snapshot, 'operation': 'synthetic-op'},
    },
  };
  var oldLength = 0, compressedLength = 0;
  final before = await measure(() async {
    final bytes = utf8.encode(jsonEncode(state));
    sha256.convert(bytes).toString();
    oldLength = utf8.encode(jsonEncode(state)).length;
  });
  final after = await measure(() async {
    compressedLength = (await encodeSharedCheckpoint(state)).length;
  });
  stdout.writeln(
    jsonEncode({
      'points': points.length,
      'decodedBytes': oldLength,
      'storedBytes': compressedLength,
      'foregroundBefore': before,
      'workerAfter': after,
      'note': 'Synthetic checkpoint work only; not physical stylus latency.',
    }),
  );
}
