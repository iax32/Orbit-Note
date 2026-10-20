import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../domain/source_browser.dart';

class SourceSearchHit {
  const SourceSearchHit(
    this.file,
    this.line,
    this.preview,
    this.sourceSha256,
    this.query,
  );
  final SourceFileEntry file;
  final int line;
  final String preview, sourceSha256, query;
}

class SourceSearchResult {
  const SourceSearchResult(
    this.hits,
    this.processed,
    this.total, {
    this.skipped = const [],
    this.truncated = false,
    this.cancelled = false,
  });
  final List<SourceSearchHit> hits;
  final List<String> skipped;
  final int processed, total;
  final bool truncated, cancelled;
}

/// Sequential bounded reads keep large checkouts responsive and cancellable.
/// The caller owns its folder scope; no files are written or indexed durably.
Future<SourceSearchResult> searchSourceFiles({
  required List<SourceFileEntry> files,
  required Future<String> Function(String) read,
  required String query,
  bool caseSensitive = false,
  bool wholeWord = false,
  String pathFilter = '',
  int maxHits = 500,
  int maxCharacters = 16 * 1024 * 1024,
  bool Function()? cancelled,
  void Function(int processed, int total, int hits)? progress,
}) async {
  if (query.trim().isEmpty ||
      query.contains(RegExp(r'[\r\n]')) ||
      query.length > 300 ||
      maxHits < 1 ||
      maxCharacters < 1) {
    throw const FormatException(
      'Enter a one-line search up to 300 characters.',
    );
  }
  final candidates = files
      .where((f) => f.path.toLowerCase().contains(pathFilter.toLowerCase()))
      .toList();
  final pattern = RegExp(
    RegExp.escape(query),
    caseSensitive: caseSensitive,
    unicode: true,
  );
  final word = RegExp(r'[\p{L}\p{N}_]', unicode: true);
  String neighbor(String line, int offset, bool before) {
    if (before) {
      final low = line.codeUnitAt(offset - 1);
      final pair =
          offset >= 2 &&
          low >= 0xdc00 &&
          low <= 0xdfff &&
          line.codeUnitAt(offset - 2) >= 0xd800 &&
          line.codeUnitAt(offset - 2) <= 0xdbff;
      return line.substring(offset - (pair ? 2 : 1), offset);
    }
    final high = line.codeUnitAt(offset);
    final pair =
        offset + 1 < line.length &&
        high >= 0xd800 &&
        high <= 0xdbff &&
        line.codeUnitAt(offset + 1) >= 0xdc00 &&
        line.codeUnitAt(offset + 1) <= 0xdfff;
    return line.substring(offset, offset + (pair ? 2 : 1));
  }

  final hits = <SourceSearchHit>[], skipped = <String>[];
  var processed = 0, characters = 0, truncated = false;
  bool stop() => cancelled?.call() ?? false;
  for (final file in candidates) {
    if (stop()) break;
    String text;
    try {
      text = await read(file.path);
    } on Object {
      if (stop()) break;
      skipped.add(file.path);
      processed++;
      progress?.call(processed, candidates.length, hits.length);
      continue;
    }
    if (stop()) break;
    if (characters + text.length > maxCharacters) {
      truncated = true;
      break;
    }
    characters += text.length;
    final lines = text.split(RegExp(r'\r\n|\r|\n'));
    String? digest;
    for (var i = 0; i < lines.length; i++) {
      if (i % 2048 == 0) {
        await Future<void>.delayed(Duration.zero);
        if (stop()) break;
      }
      final line = lines[i];
      final match = pattern
          .allMatches(line)
          .where(
            (m) =>
                !wholeWord ||
                (m.start == 0 ||
                        !word.hasMatch(neighbor(line, m.start, true))) &&
                    (m.end == line.length ||
                        !word.hasMatch(neighbor(line, m.end, false))),
          );
      if (match.isEmpty) continue;
      if (hits.length == maxHits) {
        truncated = true;
        break;
      }
      int edge(int offset) =>
          offset > 0 &&
              offset < line.length &&
              line.codeUnitAt(offset) >= 0xdc00 &&
              line.codeUnitAt(offset) <= 0xdfff
          ? offset - 1
          : offset;
      final start = edge((match.first.start - 60).clamp(0, line.length));
      final end = edge((start + 240).clamp(0, line.length));
      digest ??= sha256.convert(utf8.encode(text)).toString();
      hits.add(
        SourceSearchHit(
          file,
          i + 1,
          '${start > 0 ? '…' : ''}${line.substring(start, end)}${end < line.length ? '…' : ''}',
          digest,
          query,
        ),
      );
    }
    if (stop()) break;
    processed++;
    progress?.call(processed, candidates.length, hits.length);
    if (truncated) break;
    // Yield even for immediately completed adapters/fakes.
    await Future<void>.delayed(Duration.zero);
  }
  return SourceSearchResult(
    List.unmodifiable(hits),
    processed,
    candidates.length,
    skipped: List.unmodifiable(skipped),
    truncated: truncated,
    cancelled: stop(),
  );
}
