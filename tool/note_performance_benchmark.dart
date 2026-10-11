// Pure Dart bookkeeping benchmark, not a Flutter frame/input-latency measurement.
import 'dart:io';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/markdown_block_index.dart';
import 'package:orbit_note/features/notes/note_text_index.dart';
import 'package:orbit_note/domain/grammar/spell_grammar_engine.dart';
import 'package:orbit_note/domain/grammar/text_issue_cursor.dart';

int checksum = 0;
TextIssue? linearIssueAt(List<TextIssue> issues, int offset) {
  for (final issue in issues) {
    if (offset >= issue.start && offset < issue.end) return issue;
    if (issue.start > offset) break;
  }
  return null;
}

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

({int line, int column}) baselinePosition(String text, int offset) {
  final end = offset.clamp(0, text.length);
  var line = 1, start = 0;
  for (var i = 0; i < end; i++) {
    if (text.codeUnitAt(i) == 10) {
      line++;
      start = i + 1;
    }
  }
  return (line: line, column: end - start + 1);
}

void runChecks() {
  for (final source in [
    '',
    '\n\n',
    'Same\n\nSame\n\n',
    '🙂 café\r\n\r\n第二段\r\n',
    '---\r\nunknown: preserve\r\n---\r\n\r\n# Heading\r\n\r\n'
        '**bold** ^anchor\r\n\r\n```text\r\ncode\r\n```\r\n\r\n'
        '| A | B |\r\n| --- | --- |\r\n| 1 | 2 |\r\n\r\n'
        '\$\$\r\nx^2\r\n\$\$\r\n',
  ]) {
    final doc = MarkdownDocument.parse(source);
    final index = MarkdownBlockIndex(doc.blocks);
    check(index.source == source, 'Lossless source');
    for (var i = 0; i <= doc.blocks.length + 1; i++) {
      check(index.offsetOf(i) == doc.offsetOf(i), 'Block offset $i');
    }
    for (var i = 0; i < doc.blocks.length; i++) {
      check(index.indexOf(doc.blocks[i]) == i, 'Block identity $i');
    }
    for (var offset = -2; offset <= source.length + 2; offset++) {
      check(
        index.blockAt(offset) == doc.blockAt(offset),
        'Block boundary $offset',
      );
    }
    final text = NoteTextIndex(source);
    check(text.words == RegExp(r'\S+').allMatches(source).length, 'Words');
    check(text.characters == source.runes.length, 'Unicode characters');
    check(
      text.charactersNoSpaces == source.replaceAll(RegExp(r'\s+'), '').length,
      'No-space characters',
    );
    for (var offset = -2; offset <= source.length + 2; offset++) {
      check(
        text.lineAndColumn(offset) == baselinePosition(source, offset),
        'Line/column $offset',
      );
    }
  }
  final doc = MarkdownDocument.parse('First\n\nSame\n\nSame');
  final old = MarkdownBlockIndex(doc.blocks);
  doc.blocks[0].source = 'First changed\n';
  var next = MarkdownBlockIndex(doc.blocks);
  check(old.source == 'First\n\nSame\n\nSame', 'Index is a source version');
  check(
    next.source == doc.source && next.offsetOf(2) == doc.offsetOf(2),
    'Edit invalidation',
  );
  doc.blocks.insert(0, doc.blocks.removeLast());
  next = MarkdownBlockIndex(doc.blocks);
  check(
    next.source == doc.source && next.indexOf(doc.blocks[0]) == 0,
    'Reorder invalidation',
  );
  final absent = MarkdownBlock('Absent', MarkdownBlockKind.text);
  check(next.indexOf(absent) == -1, 'Removed/absent block');
  final duplicate = MarkdownBlockIndex([absent, absent]);
  check(duplicate.indexOf(absent) == 0, 'First duplicate identity');
  check(MarkdownBlockIndex([]).blockAt(0) == -1, 'Empty projection');
  final issues = EnglishSpellGrammarEngine().analyze(
    'Thiss is is a sentnce. And anotherr sentnce. `uncheked`',
  );
  check(issues.isNotEmpty, 'Grammar fixture detects issues');
  final cursor = TextIssueCursor(issues);
  for (var offset = -1; offset <= 70; offset++) {
    check(
      identical(cursor.at(offset), linearIssueAt(issues, offset)),
      'Grammar issue $offset',
    );
    check(
      identical(cursor.at(offset), linearIssueAt(issues, offset)),
      'Repeated grammar position $offset',
    );
  }
  for (final offset in [5, 30, 0, 15, 70, 1]) {
    check(
      identical(cursor.at(offset), linearIssueAt(issues, offset)),
      'Backward grammar position $offset',
    );
  }
  check(TextIssueCursor([]).at(0) == null, 'Empty grammar issues');
  stdout.writeln('PASS source/positions/Unicode/edit/reorder/boundary checks');
}

double medianMicros(void Function() work, {int iterations = 20}) {
  for (var i = 0; i < 3; i++) {
    work();
  }
  final samples = <int>[];
  for (var i = 0; i < iterations; i++) {
    final watch = Stopwatch()..start();
    work();
    samples.add(watch.elapsedMicroseconds);
  }
  samples.sort();
  return samples[samples.length ~/ 2].toDouble();
}

void main(List<String> args) {
  runChecks();
  if (args.contains('--checks-only')) return;
  stdout.writeln(
    'Dart ${Platform.version.split(' ').first}; ${Platform.operatingSystem}',
  );
  for (final paragraphs in [200, 1000, 3000]) {
    final buffer = StringBuffer('---\nunknown: retained\n---\n\n');
    for (var i = 0; i < paragraphs; i++) {
      buffer.writeln('Paragraph $i with **bold**, a [[note]] and café 🙂.\n');
      if (i % 25 == 0) {
        buffer.writeln('# Section $i\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n');
        buffer.writeln('\$\$\nx^2 + y^2\n\$\$\n\n```text\nkept code\n```\n');
      }
    }
    final doc = MarkdownDocument.parse(buffer.toString());
    final index = MarkdownBlockIndex(doc.blocks);
    final text = NoteTextIndex(doc.source);
    // Force lazy fields once, just as the initial editor build does.
    checksum += text.words + text.characters + text.charactersNoSpaces;
    text.lineAndColumn(0);
    final baseline = medianMicros(() {
      for (final block in doc.blocks) {
        checksum += doc.blocks.indexOf(block);
        checksum += doc.blocks.indexOf(block);
      }
      for (var i = 0; i < 6; i++) {
        checksum += doc.source.length;
      }
      for (var i = 0; i < 30; i++) {
        checksum += doc.offsetOf(doc.blocks.length - 1 - i);
      }
    });
    final optimized = medianMicros(() {
      for (final block in doc.blocks) {
        checksum += index.indexOf(block);
        checksum += index.indexOf(block);
      }
      for (var i = 0; i < 6; i++) {
        checksum += index.source.length;
      }
      for (var i = 0; i < 30; i++) {
        checksum += index.offsetOf(doc.blocks.length - 1 - i);
      }
    });
    final rebuild = medianMicros(() {
      final fresh = MarkdownBlockIndex(doc.blocks);
      checksum += fresh.source.length + fresh.offsetOf(doc.blocks.length - 1);
    });
    final oldCaret = medianMicros(() {
      for (var i = 0; i < 30; i++) {
        checksum += baselinePosition(text.source, text.source.length - i).line;
        checksum += RegExp(r'\S+').allMatches(text.source).length;
        checksum += text.source.runes.length;
        checksum += text.source.replaceAll(RegExp(r'\s+'), '').length;
      }
    }, iterations: 7);
    final newCaret = medianMicros(() {
      for (var i = 0; i < 30; i++) {
        checksum += text.lineAndColumn(text.source.length - i).line;
        checksum += text.words + text.characters + text.charactersNoSpaces;
      }
    }, iterations: 7);
    stdout.writeln(
      '$paragraphs paragraphs / ${doc.blocks.length} blocks / '
      '${doc.source.length} UTF-16 units: bookkeeping '
      '${baseline.toStringAsFixed(0)} -> ${optimized.toStringAsFixed(0)} us; '
      'fresh index+join ${rebuild.toStringAsFixed(0)} us; '
      '30 caret footer updates ${oldCaret.toStringAsFixed(0)} -> '
      '${newCaret.toStringAsFixed(0)} us',
    );
  }
  stdout.writeln('Checksum $checksum');
  final issues = List.generate(
    1000,
    (i) => TextIssue(
      start: i * 30,
      end: i * 30 + 8,
      originalText: 'misspelt',
      message: 'Fixture',
      type: IssueType.spelling,
      suggestions: const [],
    ),
  );
  final oldIssues = medianMicros(() {
    for (var offset = 0; offset < 30000; offset++) {
      checksum += linearIssueAt(issues, offset)?.start ?? 0;
    }
  }, iterations: 7);
  final newIssues = medianMicros(() {
    final cursor = TextIssueCursor(issues);
    for (var offset = 0; offset < 30000; offset++) {
      checksum += cursor.at(offset)?.start ?? 0;
    }
  }, iterations: 7);
  stdout.writeln(
    '30000-character underline lookup / 1000 issues: '
    '${oldIssues.toStringAsFixed(0)} -> ${newIssues.toStringAsFixed(0)} us',
  );
  stdout.writeln('Final checksum $checksum');
}
