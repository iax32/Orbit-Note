import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../application/grammar_analysis_execution.dart';
import '../../domain/grammar/spell_grammar_engine.dart';

/// Per editable field: unchanged text is analyzed once. Long documents are
/// complete background snapshots, never paragraph estimates or stale offsets.
/// At most one job and one latest request are retained while the user types.
class GrammarAnalysisCache extends ChangeNotifier {
  GrammarAnalysisCache({
    this.debounce = const Duration(milliseconds: 300),
    this.synchronousLimit = 2048,
    GrammarAnalyzer Function()? createAnalyzer,
  }) : _createAnalyzer = createAnalyzer ?? createGrammarAnalyzer;
  final Duration debounce;
  final int synchronousLimit;
  final GrammarAnalyzer Function() _createAnalyzer;
  GrammarAnalyzer? _analyzer;
  Timer? _timer;
  String? _source;
  EnglishSpellGrammarEngine? _engine;
  Set<String> _dictionary = {}, _ignored = {};
  List<TextIssue> _issues = const [];
  GrammarAnalysisRequest? _queued;
  int _generation = 0;
  bool _busy = false, _disposed = false;

  List<TextIssue> issuesFor(String source, EnglishSpellGrammarEngine engine) {
    if (_source == source &&
        identical(_engine, engine) &&
        setEquals(_dictionary, engine.userDictionary) &&
        setEquals(_ignored, engine.ignoredWords)) {
      return _issues;
    }
    _source = source;
    _engine = engine;
    _dictionary = Set.of(engine.userDictionary);
    _ignored = Set.of(engine.ignoredWords);
    _issues = const [];
    final generation = ++_generation;
    _timer?.cancel();
    _queued = null;
    if (source.length <= synchronousLimit) {
      _issues = List.unmodifiable(engine.analyze(source));
    } else {
      final request = (
        text: source,
        dictionary: _dictionary.toList(),
        ignored: _ignored.toList(),
      );
      _timer = Timer(debounce, () {
        if (_disposed || generation != _generation) return;
        _queued = request;
        unawaited(_drain());
      });
    }
    return _issues;
  }

  Future<void> _drain() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      while (!_disposed && _queued != null) {
        final request = _queued!;
        _queued = null;
        final generation = _generation;
        try {
          final result = await (_analyzer ??= _createAnalyzer()).analyze(
            request,
          );
          if (!_disposed &&
              generation == _generation &&
              request.text == _source &&
              setEquals(_dictionary, _engine?.userDictionary) &&
              setEquals(_ignored, _engine?.ignoredWords)) {
            _issues = List.unmodifiable(result);
            notifyListeners();
          }
        } catch (_) {
          // Source editing remains available. A later refresh retries analysis.
          if (!_disposed && generation == _generation) _source = null;
        }
      }
    } finally {
      _busy = false;
    }
  }

  void invalidate() {
    _generation++;
    _timer?.cancel();
    _queued = null;
    _source = null;
    _issues = const [];
  }

  @override
  void dispose() {
    _disposed = true;
    invalidate();
    unawaited(_analyzer?.close());
    super.dispose();
  }
}
