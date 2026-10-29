// Deterministic synthetic content only; no accounts, Vaults or UI mutations.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:orbit_note/application/grammar_analysis_execution.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/snap_index.dart';
import 'package:orbit_note/domain/text_digest_cache.dart';

CanvasAxisSnap? _oldAlignment(
  List<CanvasSnapTarget> targets,
  CanvasBounds moving,
  bool vertical,
) {
  List<double> coordinates(CanvasBounds b) =>
      vertical ? [b.top, b.center.y, b.bottom] : [b.left, b.center.x, b.right];
  final from = coordinates(moving);
  CanvasAxisSnap? best;
  for (final target in targets) {
    final to = coordinates(target.bounds);
    for (final a in from) {
      for (final b in to) {
        final delta = b - a;
        if (delta.abs() <= 6 &&
            (best == null || delta.abs() < best.delta.abs())) {
          best = (delta: delta, position: b);
        }
      }
    }
  }
  return best;
}

Future<Map<String, int>> _measure(Future<void> Function() work) async {
  final watch = Stopwatch()..start();
  var last = 0, gap = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
    final now = watch.elapsedMicroseconds;
    if (now - last > gap) gap = now - last;
    last = now;
  });
  try {
    await work();
    final tail = watch.elapsedMicroseconds - last;
    return {
      'wallUs': watch.elapsedMicroseconds,
      'maxLoopGapUs': tail > gap ? tail : gap,
    };
  } finally {
    timer.cancel();
  }
}

Future<void> main() async {
  final targets = [
    for (var i = 0; i < 2500; i++)
      CanvasSnapTarget(
        '$i',
        CanvasBounds((i % 50) * 80, (i ~/ 50) * 80, 60, 40),
      ),
  ];
  final moves = [
    for (var i = 0; i < 400; i++)
      CanvasBounds((i * 73 % 4000) + .25, (i * 37 % 4000) + .125, 35.5, 20),
  ];
  final create = Stopwatch()..start();
  final index = CanvasSnapIndex(targets);
  final indexUs = create.elapsedMicroseconds;
  // Parity is checked outside the timed runs, including tie ordering.
  for (final moving in moves) {
    for (final vertical in [false, true]) {
      if (_oldAlignment(targets, moving, vertical) !=
          index.alignment(moving, vertical: vertical, tolerance: 6)) {
        throw StateError('Alignment changed');
      }
    }
  }
  var sink = 0;
  final oldSnap = await _measure(() async {
    for (final moving in moves) {
      for (final vertical in [false, true]) {
        sink += _oldAlignment(targets, moving, vertical)?.position.toInt() ?? 0;
      }
    }
  });
  final newSnap = await _measure(() async {
    for (final moving in moves) {
      for (final vertical in [false, true]) {
        sink +=
            index
                .alignment(moving, vertical: vertical, tolerance: 6)
                ?.position
                .toInt() ??
            0;
      }
    }
  });
  final text = 'The document contains text α 😀.\n' * 8000;
  final oldDigest = await _measure(() async {
    for (var i = 0; i < 100; i++) {
      sink += sha256.convert(utf8.encode(text)).hashCode;
    }
  });
  final digest = TextDigestCache();
  final newDigest = await _measure(() async {
    for (var i = 0; i < 100; i++) {
      sink += digest.hash(text).hashCode;
    }
  });
  final analyzer = createGrammarAnalyzer();
  final request = (
    text: 'This is a example. The the cat reads a book.\n' * 500,
    dictionary: <String>[],
    ignored: <String>[],
  );
  final foreground = await _measure(() async {
    sink += analyzeGrammarRequest(request).length;
  });
  late Map<String, int> cold, repeated;
  try {
    cold = await _measure(() async {
      sink += (await analyzer.analyze(request)).length;
    });
    repeated = await _measure(() async {
      sink += (await analyzer.analyze(request)).length;
    });
  } finally {
    await analyzer.close();
  }
  stdout.writeln(
    jsonEncode({
      'targets': targets.length,
      'moves': moves.length,
      'snapIndexBuildUs': indexUs,
      'oldSnapping': oldSnap,
      'indexedSnapping': newSnap,
      'caretMoves': 100,
      'documentCharacters': text.length,
      'oldDigest': oldDigest,
      'cachedDigest': newDigest,
      'grammarCharacters': request.text.length,
      'grammarForeground': foreground,
      'grammarColdWorker': cold,
      'grammarRepeatedWorker': repeated,
      'sink': sink,
    }),
  );
}
