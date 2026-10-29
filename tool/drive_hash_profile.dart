// Local read-only probe. Outputs timings/counts only, never file contents/paths.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:orbit_note/infrastructure/storage/native_file_digests.dart';

typedef Digests = ({String sha256, String? md5});

Future<({Digests digests, Map<String, int> metrics})> measure(
  Future<Digests> Function() action,
) async {
  final clock = Stopwatch()..start();
  var previous = 0, maximum = 0, ticks = 0;
  void record() {
    final now = clock.elapsedMicroseconds, gap = now - previous;
    if (gap > maximum) maximum = gap;
    previous = now;
  }

  final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
    ticks++;
    record();
  });
  try {
    final digests = await action();
    record();
    return (
      digests: digests,
      metrics: {
        'wallUs': clock.elapsedMicroseconds,
        'maximumCallerGapUs': maximum,
        'timerTicks': ticks,
      },
    );
  } finally {
    timer.cancel();
  }
}

Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('Supply an isolated file fixture.');
  final file = File(args.single);
  final before = await measure(
    () async => (
      sha256: (await sha256.bind(file.openRead()).first).toString(),
      md5: (await md5.bind(file.openRead()).first).toString(),
    ),
  );
  final after = await measure(
    () async => (await nativeFileDigests(file, includeMd5: true))!,
  );
  if (before.digests != after.digests) throw StateError('Digest mismatch.');
  stdout.writeln(
    jsonEncode({
      'bytes': await file.length(),
      'exactDigests': true,
      'foregroundTwoPass': before.metrics,
      'nativeCombined': after.metrics,
    }),
  );
}
