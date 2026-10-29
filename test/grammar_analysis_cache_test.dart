import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/grammar_analysis_execution.dart';
import 'package:orbit_note/domain/grammar/spell_grammar_engine.dart';
import 'package:orbit_note/features/notes/grammar_analysis_cache.dart';

class _Engine extends EnglishSpellGrammarEngine {
  int calls = 0;
  @override
  List<TextIssue> analyze(String text) {
    calls++;
    return super.analyze(text);
  }
}

class _Analyzer implements GrammarAnalyzer {
  final requests = <GrammarAnalysisRequest>[];
  final results = <Completer<List<TextIssue>>>[];
  bool closed = false;
  @override
  Future<List<TextIssue>> analyze(GrammarAnalysisRequest request) {
    requests.add(request);
    final result = Completer<List<TextIssue>>();
    results.add(result);
    return result.future;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

TextIssue _issue(String text) => TextIssue(
  start: 0,
  end: text.length,
  originalText: text,
  message: 'Synthetic result',
  type: IssueType.spelling,
  suggestions: const ['fixed'],
);
void main() {
  test(
    'selection and repaint reuse exact source analysis; direct dictionary changes invalidate',
    () {
      final engine = _Engine();
      final cache = GrammarAnalysisCache();
      addTearDown(cache.dispose);
      final first = cache.issuesFor('teh cat', engine);
      for (var i = 0; i < 100; i++) {
        expect(identical(cache.issuesFor('teh cat', engine), first), isTrue);
      }
      expect(engine.calls, 1);
      engine.userDictionary.add('teh');
      expect(
        cache
            .issuesFor('teh cat', engine)
            .where((i) => i.originalText == 'teh'),
        isEmpty,
      );
      expect(engine.calls, 2);
      engine.ignoredWords.add('cat');
      cache.issuesFor('teh cat', engine);
      expect(engine.calls, 3);
    },
  );
  test(
    'large edits keep one active plus latest request, never publish stale offsets',
    () async {
      final analyzer = _Analyzer();
      final cache = GrammarAnalysisCache(
        debounce: Duration.zero,
        synchronousLimit: 0,
        createAnalyzer: () => analyzer,
      );
      final engine = _Engine();
      var notifications = 0;
      cache.addListener(() => notifications++);
      cache.issuesFor('old document', engine);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      cache.issuesFor('intermediate document', engine);
      cache.issuesFor('new document', engine);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(analyzer.requests.length, 1);
      analyzer.results.first.complete([_issue('old')]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(notifications, 0);
      expect(analyzer.requests.last.text, 'new document');
      expect(analyzer.requests.length, 2);
      analyzer.results.last.complete([_issue('new')]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        cache.issuesFor('new document', engine).single.originalText,
        'new',
      );
      expect(notifications, 1);
      expect(engine.calls, 0);
      cache.dispose();
      expect(analyzer.closed, isTrue);
    },
  );
  test(
    'native worker preserves complete Markdown exclusions and custom dictionaries',
    () async {
      final analyzer = createGrammarAnalyzer();
      addTearDown(analyzer.close);
      final request = (
        text:
            '${'This is a example. The the cat.\n' * 100}```\nteh code\n```\n customword',
        dictionary: ['customword'],
        ignored: ['cat'],
      );
      final expected = analyzeGrammarRequest(request);
      final result = await analyzer.analyze(request);
      List<Object> values(List<TextIssue> issues) => [
        for (final issue in issues)
          [
            issue.start,
            issue.end,
            issue.originalText,
            issue.message,
            issue.type.name,
            issue.suggestions,
          ],
      ];
      expect(values(result), values(expected));
      expect(result.where((i) => i.originalText == 'customword'), isEmpty);
    },
  );
  test(
    'dispose ignores in-flight results and cancels scheduled analysis',
    () async {
      final analyzer = _Analyzer();
      final cache = GrammarAnalysisCache(
        debounce: Duration.zero,
        synchronousLimit: 0,
        createAnalyzer: () => analyzer,
      );
      cache.issuesFor('pending', _Engine());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      cache.dispose();
      analyzer.results.single.complete([_issue('pending')]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(analyzer.closed, isTrue);
    },
  );
}
