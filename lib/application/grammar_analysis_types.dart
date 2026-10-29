import '../domain/grammar/spell_grammar_engine.dart';

typedef GrammarAnalysisRequest = ({
  String text,
  List<String> dictionary,
  List<String> ignored,
});

List<TextIssue> analyzeGrammarRequest(GrammarAnalysisRequest request) =>
    EnglishSpellGrammarEngine(
      userDictionary: request.dictionary,
      ignoredWords: request.ignored,
    ).analyze(request.text);

abstract interface class GrammarAnalyzer {
  Future<List<TextIssue>> analyze(GrammarAnalysisRequest request);
  Future<void> close();
}
