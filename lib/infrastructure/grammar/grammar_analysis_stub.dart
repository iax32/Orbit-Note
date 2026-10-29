import '../../application/grammar_analysis_types.dart';
import '../../domain/grammar/spell_grammar_engine.dart';

GrammarAnalyzer createGrammarAnalyzer() => _LocalGrammarAnalyzer();

class _LocalGrammarAnalyzer implements GrammarAnalyzer {
  @override
  Future<List<TextIssue>> analyze(GrammarAnalysisRequest request) =>
      Future(() => analyzeGrammarRequest(request));
  @override
  Future<void> close() async {}
}
