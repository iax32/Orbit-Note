import 'dart:convert';
import 'dart:io';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/document_history.dart';

/// Model-only measurements. Run with the SDK dart executable; no Flutter frame
/// rate or memory claim can be inferred from this benchmark.
void main() {
  final results = <Map<String, Object>>[];
  for (final words in [5000, 10000, 50000]) {
    final source = List.generate(
      words ~/ 10,
      (i) =>
          'Paragraph $i has **bold text** and ordinary words with _emphasis_.',
    ).join('\n\n');
    for (var i = 0; i < 5; i++) {
      MarkdownDocument.parse(source);
    }
    final parse = <int>[], edits = <int>[];
    for (var i = 0; i < 30; i++) {
      final clock = Stopwatch()..start();
      final document = MarkdownDocument.parse(source);
      parse.add(clock.elapsedMicroseconds);
      clock.reset();
      final block = document.blocks.first;
      block.source = block.replaceContent(
        InlineProjection(
          block.content,
        ).edit('Changed ${InlineProjection(block.content).text}'),
      );
      final changed = document.source;
      final history = DocumentHistory()..record(source, changed);
      if (history.undo(changed) != source) {
        throw StateError('Round-trip changed');
      }
      edits.add(clock.elapsedMicroseconds);
      clock.stop();
    }
    parse.sort();
    edits.sort();
    results.add({
      'approxWords': words,
      'sourceCharacters': source.length,
      'parseP95Microseconds': parse[(parse.length * .95).floor()],
      'editJoinHistoryP95Microseconds': edits[(edits.length * .95).floor()],
    });
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
}
