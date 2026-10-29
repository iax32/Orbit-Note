import '../../application/grammar_analysis_types.dart';
import '../../domain/grammar/spell_grammar_engine.dart';
import '../workers/native_task_worker.dart';

GrammarAnalyzer createGrammarAnalyzer() => _NativeGrammarAnalyzer();

class _NativeGrammarAnalyzer implements GrammarAnalyzer {
  final _worker = NativeTaskWorker<GrammarAnalysisRequest, List<TextIssue>>(
    analyzeGrammarRequest,
  );
  @override
  Future<List<TextIssue>> analyze(GrammarAnalysisRequest request) =>
      _worker.run(request);
  @override
  Future<void> close() => _worker.close();
}
