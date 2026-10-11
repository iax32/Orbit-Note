import 'dart:math' as math;

/// Categorization of writing issues identified by the engine.
enum IssueType { spelling, grammar, style }

/// Represents a detected spelling or grammar issue in a piece of text.
class TextIssue {
  const TextIssue({
    required this.start,
    required this.end,
    required this.originalText,
    required this.message,
    required this.type,
    required this.suggestions,
  });

  final int start;
  final int end;
  final String originalText;
  final String message;
  final IssueType type;
  final List<String> suggestions;

  @override
  String toString() =>
      'TextIssue($type: "$originalText" -> ${suggestions.join(", ")} at [$start, $end])';
}

/// Pure Dart offline English spell-checking and grammar-checking engine.
///
/// Designed to run completely locally in real-time, operating in sub-millisecond
/// speeds on desktop, mobile, and web. Ignores Markdown markup, code blocks,
/// math formulas, URLs, and WikiLinks.
class EnglishSpellGrammarEngine {
  EnglishSpellGrammarEngine({
    Iterable<String>? userDictionary,
    Iterable<String>? ignoredWords,
  }) : userDictionary = {
         ...?userDictionary?.map((e) => e.trim().toLowerCase()),
       },
       ignoredWords = {...?ignoredWords?.map((e) => e.trim().toLowerCase())};

  /// User-defined dictionary of recognized words (persisted across sessions).
  final Set<String> userDictionary;

  /// Words ignored during the current session.
  final Set<String> ignoredWords;

  /// Adds a custom word to the user dictionary so it won't be flagged.
  void addToDictionary(String word) {
    final clean = word.trim().toLowerCase();
    if (clean.isNotEmpty) {
      userDictionary.add(clean);
    }
  }

  /// Alias for addToDictionary
  void addWord(String word) => addToDictionary(word);

  /// Ignores a word for the current session.
  void ignore(String word) {
    final clean = word.trim().toLowerCase();
    if (clean.isNotEmpty) {
      ignoredWords.add(clean);
    }
  }

  /// Alias for ignore
  void ignoreWord(String word) => ignore(word);

  /// Sets all user dictionary words
  void setUserDictionary(Iterable<String> words) {
    userDictionary.clear();
    for (final w in words) {
      final clean = w.trim().toLowerCase();
      if (clean.isNotEmpty) userDictionary.add(clean);
    }
  }

  /// Removes a word from user dictionary.
  void removeFromDictionary(String word) {
    userDictionary.remove(word.trim().toLowerCase());
  }

  /// Clears the user dictionary.
  void clearUserDictionary() {
    userDictionary.clear();
  }

  /// Checks whether a given word is recognized as valid English.
  bool isValidWord(String word) {
    final clean = word.trim().toLowerCase();
    if (clean.isEmpty) return true;
    if (_commonLexicon.contains(clean)) return true;
    if (userDictionary.contains(clean)) return true;
    if (ignoredWords.contains(clean)) return true;

    // Check inflections (plural -s, -es, -ies, past -ed, gerund -ing, adverb -ly)
    if (_hasValidInflection(clean)) return true;

    return false;
  }

  bool _hasValidInflection(String word) {
    if (word.length <= 3) return false;

    // Plural -s or -es
    if (word.endsWith('s')) {
      if (word.endsWith('ies') && word.length > 4) {
        final stem = '${word.substring(0, word.length - 3)}y';
        if (_commonLexicon.contains(stem)) return true;
      }
      if (word.endsWith('es') && word.length > 4) {
        final stem = word.substring(0, word.length - 2);
        if (_commonLexicon.contains(stem)) return true;
      }
      final stem = word.substring(0, word.length - 1);
      if (_commonLexicon.contains(stem)) return true;
    }

    // Past tense -ed
    if (word.endsWith('ed') && word.length > 4) {
      final stem1 = word.substring(0, word.length - 2);
      if (_commonLexicon.contains(stem1)) return true;
      final stem2 = word.substring(0, word.length - 1); // e.g. like -> liked
      if (_commonLexicon.contains(stem2)) return true;
      if (word.endsWith('ied') && word.length > 4) {
        final stemY = '${word.substring(0, word.length - 3)}y';
        if (_commonLexicon.contains(stemY)) return true;
      }
      // Doubled consonant (e.g. planned -> plan)
      if (stem1.length >= 3 &&
          stem1[stem1.length - 1] == stem1[stem1.length - 2]) {
        final stemDouble = stem1.substring(0, stem1.length - 1);
        if (_commonLexicon.contains(stemDouble)) return true;
      }
    }

    // Gerund -ing
    if (word.endsWith('ing') && word.length > 5) {
      final stem = word.substring(0, word.length - 3);
      if (_commonLexicon.contains(stem)) return true;
      final stemE = '${stem}e';
      if (_commonLexicon.contains(stemE)) return true;
      if (stem.length >= 3 && stem[stem.length - 1] == stem[stem.length - 2]) {
        final stemDouble = stem.substring(0, stem.length - 1);
        if (_commonLexicon.contains(stemDouble)) return true;
      }
    }

    // Adverb -ly
    if (word.endsWith('ly') && word.length > 4) {
      final stem = word.substring(0, word.length - 2);
      if (_commonLexicon.contains(stem)) return true;
      if (word.endsWith('ily') && word.length > 5) {
        final stemY = '${word.substring(0, word.length - 3)}y';
        if (_commonLexicon.contains(stemY)) return true;
      }
    }

    return false;
  }

  /// Generates ranked suggestions for a misspelled word.
  List<String> getSuggestions(String word) {
    final clean = word.trim().toLowerCase();
    if (clean.isEmpty) return const [];

    final results = <String>[];

    // 1. Direct match in common typo table
    final typoMatch = _commonTypos[clean];
    if (typoMatch != null) {
      for (final s in typoMatch) {
        results.add(_matchCase(word, s));
      }
    }

    // 2. Damerau-Levenshtein edit-distance suggestions against lexicon
    if (results.length < 3) {
      final candidates = <_ScoredCandidate>[];
      final wordLen = clean.length;

      for (final dictWord in _commonLexicon) {
        // Skip words with large length differences
        if ((dictWord.length - wordLen).abs() > 2) continue;

        // Skip words if first letter differs and length > 4 (unless transposed)
        if (wordLen > 4 && dictWord[0] != clean[0] && dictWord[0] != clean[1]) {
          continue;
        }

        final dist = _damerauLevenshtein(clean, dictWord, maxDistance: 2);
        if (dist <= 2) {
          candidates.add(_ScoredCandidate(dictWord, dist));
        }
      }

      candidates.sort((a, b) {
        final distComp = a.distance.compareTo(b.distance);
        if (distComp != 0) return distComp;
        // Prefer common prefix
        final aPrefix =
            a.word.startsWith(clean.substring(0, math.min(2, clean.length)))
            ? 0
            : 1;
        final bPrefix =
            b.word.startsWith(clean.substring(0, math.min(2, clean.length)))
            ? 0
            : 1;
        return aPrefix.compareTo(bPrefix);
      });

      for (final cand in candidates) {
        final formatted = _matchCase(word, cand.word);
        if (!results.contains(formatted)) {
          results.add(formatted);
          if (results.length >= 4) break;
        }
      }
    }

    return results;
  }

  /// Analyzes a text document and returns all detected spelling and grammar issues.
  List<TextIssue> analyze(String text) {
    if (text.trim().isEmpty) return const [];

    final issues = <TextIssue>[];
    final mask = _buildExclusionMask(text);

    // 1. Rule-based grammar analysis
    _checkGrammarRules(text, mask, issues);

    // 2. Spell check analysis
    _checkSpelling(text, mask, issues);

    // Sort issues by start offset
    issues.sort((a, b) => a.start.compareTo(b.start));

    // Deduplicate overlapping issues (keep earlier/longer)
    final deduplicated = <TextIssue>[];
    for (final issue in issues) {
      if (deduplicated.isEmpty) {
        deduplicated.add(issue);
        continue;
      }
      final last = deduplicated.last;
      if (issue.start < last.end) {
        // Overlap: prefer grammar rule over spelling if conflicting
        if (issue.type == IssueType.grammar &&
            last.type == IssueType.spelling) {
          deduplicated.removeLast();
          deduplicated.add(issue);
        }
      } else {
        deduplicated.add(issue);
      }
    }

    return deduplicated;
  }

  /// Checks for grammar and agreement rules.
  void _checkGrammarRules(
    String text,
    List<bool> mask,
    List<TextIssue> issues,
  ) {
    // 1. Repeated words: "the the", "in in", "and and", "that that", etc.
    final repeatedWordRegex = RegExp(
      r'\b([a-zA-Z]+)[ \t]+(\1)\b',
      caseSensitive: false,
    );
    for (final match in repeatedWordRegex.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      if (mask.getRange(start, end).any((excluded) => excluded)) continue;

      final word1 = match.group(1)!;
      final word2 = match.group(2)!;
      if (word1.toLowerCase() == word2.toLowerCase()) {
        issues.add(
          TextIssue(
            start: start,
            end: end,
            originalText: text.substring(start, end),
            message: 'Repeated word: "$word1"',
            type: IssueType.grammar,
            suggestions: [word1],
          ),
        );
      }
    }

    // 2. Indefinite article agreement (a vs an)
    final articleRegex = RegExp(
      r'\b(a|an)\s+([a-zA-Z]+)\b',
      caseSensitive: false,
    );
    for (final match in articleRegex.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      if (mask.getRange(start, end).any((excluded) => excluded)) continue;

      final article = match.group(1)!;
      final nextWord = match.group(2)!;
      final nextLower = nextWord.toLowerCase();

      final needsAn = _startsWithVowelSound(nextLower);
      final isAn = article.toLowerCase() == 'an';

      if (needsAn && !isAn) {
        final replacementArticle = _matchCase(article, 'an');
        issues.add(
          TextIssue(
            start: start,
            end: end,
            originalText: text.substring(start, end),
            message:
                'Use "an" before vowel sounds ("$replacementArticle $nextWord")',
            type: IssueType.grammar,
            suggestions: ['$replacementArticle $nextWord'],
          ),
        );
      } else if (!needsAn && isAn) {
        final replacementArticle = _matchCase(article, 'a');
        issues.add(
          TextIssue(
            start: start,
            end: end,
            originalText: text.substring(start, end),
            message:
                'Use "a" before consonant sounds ("$replacementArticle $nextWord")',
            type: IssueType.grammar,
            suggestions: ['$replacementArticle $nextWord'],
          ),
        );
      }
    }

    // 3. Common phrase and homophone grammar rules
    for (final rule in _grammarPhrases) {
      for (final match in rule.pattern.allMatches(text)) {
        final start = match.start;
        final end = match.end;
        if (mask.getRange(start, end).any((excluded) => excluded)) continue;

        final original = text.substring(start, end);
        var rep = rule.replacement;
        for (var g = 1; g <= match.groupCount; g++) {
          final val = match.group(g);
          if (val != null) {
            rep = rep.replaceAll('\$$g', val);
          }
        }
        final replacement = _matchCase(original, rep);
        final extra = rule.extraSuggestions.map((s) {
          var res = s;
          for (var g = 1; g <= match.groupCount; g++) {
            final val = match.group(g);
            if (val != null) res = res.replaceAll('\$$g', val);
          }
          return _matchCase(original, res);
        }).toList();

        issues.add(
          TextIssue(
            start: start,
            end: end,
            originalText: original,
            message: rule.message,
            type: IssueType.grammar,
            suggestions: [replacement, ...extra],
          ),
        );
      }
    }

    // 4. Standalone lowercase "i", "i'm", "i've", "i'll", "i'd"
    final pronounRegex = RegExp(r'(^|\s|\()([i]|i\x27[mvedl]{1,2})\b');
    for (final match in pronounRegex.allMatches(text)) {
      final token = match.group(2)!;
      final tokenStart = match.start + match.group(1)!.length;
      final tokenEnd = tokenStart + token.length;
      if (mask[tokenStart] || mask[tokenEnd - 1]) continue;

      final replacement = token[0].toUpperCase() + token.substring(1);
      issues.add(
        TextIssue(
          start: tokenStart,
          end: tokenEnd,
          originalText: token,
          message: 'The pronoun "I" should be capitalized',
          type: IssueType.grammar,
          suggestions: [replacement],
        ),
      );
    }
  }

  /// Checks for individual misspelled words.
  void _checkSpelling(String text, List<bool> mask, List<TextIssue> issues) {
    final wordRegex = RegExp(r"\b[A-Za-z][A-Za-z0-9_'-]*\b");
    for (final match in wordRegex.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      if (mask[start] || mask[end - 1]) continue;

      final rawWord = text.substring(start, end);

      // Skip words containing digits, underscores, or single letters (except A, I)
      if (RegExp(r'[0-9_]').hasMatch(rawWord)) continue;
      if (rawWord.length == 1) {
        final c = rawWord.toLowerCase();
        if (c != 'a' && c != 'i') {
          continue; // Likely variable or initials
        }
      }

      // Strip trailing apostrophe-s for checking
      var checkWord = rawWord;
      if (checkWord.toLowerCase().endsWith("'s")) {
        checkWord = checkWord.substring(0, checkWord.length - 2);
      }

      if (!isValidWord(checkWord)) {
        final suggestions = getSuggestions(rawWord);
        // A small offline lexicon cannot determine that unfamiliar names,
        // specialist terms or non-English prose are mistakes. Only underline
        // known typos or a close correction, never every unknown word.
        if (!_commonTypos.containsKey(checkWord.toLowerCase())) {
          if (rawWord.contains(RegExp(r'[A-Z]')) ||
              suggestions.isEmpty ||
              rawWord.length < 4 ||
              _damerauLevenshtein(
                    checkWord.toLowerCase(),
                    suggestions.first.toLowerCase(),
                    maxDistance: 1,
                  ) >
                  1) {
            continue;
          }
        }
        issues.add(
          TextIssue(
            start: start,
            end: end,
            originalText: rawWord,
            message: 'Possible spelling mistake: "$rawWord"',
            type: IssueType.spelling,
            suggestions: suggestions,
          ),
        );
      }
    }
  }

  /// Builds a boolean exclusion mask of characters that belong to Markdown syntax,
  /// code blocks, math formulas, URLs, or WikiLinks.
  List<bool> _buildExclusionMask(String text) {
    final mask = List<bool>.filled(text.length, false);

    void maskRange(int start, int end) {
      final s = start.clamp(0, text.length);
      final e = end.clamp(0, text.length);
      for (var i = s; i < e; i++) {
        mask[i] = true;
      }
    }

    // Fenced code, including tilde fences and an unfinished block while typing.
    String? fence;
    int fenceStart = 0;
    for (final line in RegExp(r'[^\r\n]*(?:\r\n|\r|\n|$)').allMatches(text)) {
      final value = line.group(0)!;
      if (fence == null) {
        final opening = RegExp(r'^ {0,3}(`{3,}|~{3,})').firstMatch(value);
        if (opening != null) {
          fence = opening.group(1)!;
          fenceStart = line.start;
        }
      } else if (RegExp(
        '^ {0,3}${fence[0]}{${fence.length},}[ \\t]*[\\r\\n]*\$',
      ).hasMatch(value)) {
        maskRange(fenceStart, line.end);
        fence = null;
      }
    }
    if (fence != null) maskRange(fenceStart, text.length);

    // A code span closes with a run of exactly the opening length.
    final runs = RegExp(r'`+').allMatches(text).toList();
    for (var i = 0; i < runs.length; i++) {
      final opening = runs[i];
      if (mask[opening.start]) continue;
      var slashes = 0;
      for (var at = opening.start - 1; at >= 0 && text[at] == '\\'; at--) {
        slashes++;
      }
      if (slashes.isOdd) continue;
      for (var j = i + 1; j < runs.length; j++) {
        if (mask[runs[j].start]) break;
        if (runs[j].group(0)!.length == opening.group(0)!.length) {
          maskRange(opening.start, runs[j].end);
          i = j;
          break;
        }
      }
    }

    // 3. Math blocks & inline math: $$...$$ and $...$
    final mathRegex = RegExp(r'\$\$[\s\S]*?\$\$|\$[^$\n]+\$');
    for (final m in mathRegex.allMatches(text)) {
      maskRange(m.start, m.end);
    }

    // 4. URLs: http:// or https:// or file:// or orbit://
    final urlRegex = RegExp(r'\b[a-z]+://[^\s)\]]+', caseSensitive: false);
    for (final m in urlRegex.allMatches(text)) {
      maskRange(m.start, m.end);
    }

    // 5. WikiLinks: [[...]]
    final wikiLinkRegex = RegExp(r'\[\[[\s\S]*?\]\]');
    for (final m in wikiLinkRegex.allMatches(text)) {
      maskRange(m.start, m.end);
    }

    // 6. Markdown links: [text](url) -> mask the url portion
    final mdLinkRegex = RegExp(r'\[([^\]]*)\]\(([^)]*)\)');
    for (final m in mdLinkRegex.allMatches(text)) {
      final urlStart = m.start + m.group(1)!.length + 3;
      maskRange(urlStart, m.end);
    }

    // 7. HTML tags: <tag>...</tag>
    final htmlTagRegex = RegExp(r'<[^>]+>');
    for (final m in htmlTagRegex.allMatches(text)) {
      maskRange(m.start, m.end);
    }

    return mask;
  }

  /// Determines whether a word begins with a vowel sound.
  static bool _startsWithVowelSound(String word) {
    if (word.isEmpty) return false;
    final lower = word.toLowerCase();

    // Exceptions that start with consonant sound despite starting with vowel letter
    const consonantSoundExceptions = {
      'university',
      'universe',
      'universal',
      'uniform',
      'union',
      'unique',
      'unit',
      'united',
      'unity',
      'euphemism',
      'eunuch',
      'euphoria',
      'european',
      'eulogy',
      'one',
      'once',
      'user',
      'usual',
      'usually',
      'utility',
      'utensil',
      'utopia',
      'ufo',
    };
    if (consonantSoundExceptions.contains(lower)) return false;

    // Exceptions that start with silent 'h' (vowel sound)
    const vowelSoundExceptions = {
      'hour',
      'hours',
      'hourly',
      'honest',
      'honesty',
      'honestly',
      'honor',
      'honors',
      'honorable',
      'honorably',
      'heir',
      'heiress',
    };
    if (vowelSoundExceptions.contains(lower)) return true;

    // Standard rule: starts with a, e, i, o, u
    return 'aeiou'.contains(lower[0]);
  }

  /// Matches the casing of [original] onto [replacement].
  static String _matchCase(String original, String replacement) {
    if (original.isEmpty || replacement.isEmpty) return replacement;

    // ALL CAPS: e.g. "TEH" -> "THE"
    if (original == original.toUpperCase() && original.length > 1) {
      return replacement.toUpperCase();
    }

    // Title Case: e.g. "Teh" -> "The"
    if (original[0] == original[0].toUpperCase()) {
      return replacement[0].toUpperCase() + replacement.substring(1);
    }

    // Lowercase
    return replacement.toLowerCase();
  }

  /// Damerau-Levenshtein distance supporting transposition, insertion, deletion, and substitution.
  static int _damerauLevenshtein(
    String s1,
    String s2, {
    required int maxDistance,
  }) {
    final len1 = s1.length;
    final len2 = s2.length;
    if ((len1 - len2).abs() > maxDistance) return maxDistance + 1;

    final d = List.generate(len1 + 1, (_) => List<int>.filled(len2 + 1, 0));

    for (var i = 0; i <= len1; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= len2; j++) {
      d[0][j] = j;
    }

    for (var i = 1; i <= len1; i++) {
      for (var j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = math.min(
          d[i - 1][j] + 1, // deletion
          math.min(
            d[i][j - 1] + 1, // insertion
            d[i - 1][j - 1] + cost, // substitution
          ),
        );

        // Transposition
        if (i > 1 &&
            j > 1 &&
            s1[i - 1] == s2[j - 2] &&
            s1[i - 2] == s2[j - 1]) {
          d[i][j] = math.min(d[i][j], d[i - 2][j - 2] + 1);
        }
      }
    }

    return d[len1][len2];
  }
}

class _ScoredCandidate {
  _ScoredCandidate(this.word, this.distance);
  final String word;
  final int distance;
}

class _GrammarPhraseRule {
  _GrammarPhraseRule({
    required this.pattern,
    required this.replacement,
    required this.message,
    this.extraSuggestions = const [],
  });
  final RegExp pattern;
  final String replacement;
  final String message;
  final List<String> extraSuggestions;
}

/// Curated grammar rules for common English errors and homophone confusions.
final _grammarPhrases = <_GrammarPhraseRule>[
  // could of / should of / would of -> could have / should have / would have
  _GrammarPhraseRule(
    pattern: RegExp(
      r'\b(could|should|would|must|might)\s+of\b',
      caseSensitive: false,
    ),
    replacement: r'$1 have',
    message: r'Did you mean "$1 have"?',
    extraSuggestions: [r"$1've"],
  ),

  // their are -> there are
  _GrammarPhraseRule(
    pattern: RegExp(r'\btheir\s+(is|are|was|were)\b', caseSensitive: false),
    replacement: r'there $1',
    message: 'Use "there" to indicate existence or location',
  ),

  // they're book -> their book
  _GrammarPhraseRule(
    pattern: RegExp(
      r"\bthey're\s+(book|notes|ideas|work|car|house|names|eyes|way|own)\b",
      caseSensitive: false,
    ),
    replacement: r'their $1',
    message: 'Use "their" for possession',
  ),

  // its a -> it's a
  _GrammarPhraseRule(
    pattern: RegExp(
      r'\bits\s+(a|an|the|not|too|really|very)\b',
      caseSensitive: false,
    ),
    replacement: r"it's $1",
    message: 'Use "it\'s" as a contraction for "it is"',
  ),

  // it's color -> its color
  _GrammarPhraseRule(
    pattern: RegExp(
      r"\bit's\s+(color|size|shape|name|weight|height|length|owner|title)\b",
      caseSensitive: false,
    ),
    replacement: r'its $1',
    message: 'Use "its" for possessive form',
  ),

  // your welcome -> you're welcome
  _GrammarPhraseRule(
    pattern: RegExp(
      r'\byour\s+(welcome|right|wrong|correct|going|doing|invited)\b',
      caseSensitive: false,
    ),
    replacement: r"you're $1",
    message: 'Use "you\'re" as a contraction for "you are"',
  ),

  // you're book -> your book
  _GrammarPhraseRule(
    pattern: RegExp(
      r"\byou're\s+(book|notes|ideas|work|car|house|phone|computer)\b",
      caseSensitive: false,
    ),
    replacement: r'your $1',
    message: 'Use "your" for possession',
  ),

  // better then -> better than
  _GrammarPhraseRule(
    pattern: RegExp(
      r'\b(better|more|less|greater|faster|slower|bigger|smaller|rather)\s+then\b',
      caseSensitive: false,
    ),
    replacement: r'$1 than',
    message: 'Use "than" for comparisons',
  ),

  // to much -> too much
  _GrammarPhraseRule(
    pattern: RegExp(
      r'\bto\s+(much|many|late|early|hot|cold|fast|slow|bad|far)\b',
      caseSensitive: false,
    ),
    replacement: r'too $1',
    message: 'Use "too" to mean "excessively" or "also"',
  ),

  // they is -> they are
  _GrammarPhraseRule(
    pattern: RegExp(r'\b(they|we|you)\s+is\b', caseSensitive: false),
    replacement: r'$1 are',
    message: 'Subject-verb agreement: use "are" with plural subjects',
  ),

  // he are -> he is
  _GrammarPhraseRule(
    pattern: RegExp(r'\b(he|she|it)\s+are\b', caseSensitive: false),
    replacement: r'$1 is',
    message: 'Subject-verb agreement: use "is" with singular subjects',
  ),

  // I is -> I am
  _GrammarPhraseRule(
    pattern: RegExp(r'\bI\s+is\b', caseSensitive: false),
    replacement: 'I am',
    message: 'Subject-verb agreement: use "I am"',
  ),

  // Double punctuation: ,, or ;;
  _GrammarPhraseRule(
    pattern: RegExp(r',,'),
    replacement: ',',
    message: 'Repeated comma',
  ),
  _GrammarPhraseRule(
    pattern: RegExp(r';;'),
    replacement: ';',
    message: 'Repeated semicolon',
  ),
];

/// High-frequency typo lookup dictionary covering common spelling slips.
final _commonTypos = <String, List<String>>{
  'teh': ['the'],
  'taht': ['that'],
  'thier': ['their', 'there'],
  'recieve': ['receive'],
  'recieved': ['received'],
  'recieving': ['receiving'],
  'seperate': ['separate'],
  'seperated': ['separated'],
  'seperation': ['separation'],
  'definately': ['definitely'],
  'wierd': ['weird'],
  'occured': ['occurred'],
  'occurance': ['occurrence'],
  'untill': ['until'],
  'alot': ['a lot'],
  'truely': ['truly'],
  'goverment': ['government'],
  'neccessary': ['necessary'],
  'necesary': ['necessary'],
  'embarass': ['embarrass'],
  'embarassed': ['embarrassed'],
  'accomodate': ['accommodate'],
  'tommorow': ['tomorrow'],
  'tomorow': ['tomorrow'],
  'beleive': ['believe'],
  'beleived': ['believed'],
  'freind': ['friend'],
  'freinds': ['friends'],
  'peice': ['piece'],
  'peices': ['pieces'],
  'acheive': ['achieve'],
  'acheived': ['achieved'],
  'acheivement': ['achievement'],
  'calender': ['calendar'],
  'adress': ['address'],
  'adresses': ['addresses'],
  'begining': ['beginning'],
  'realy': ['really'],
  'alright': ['all right', 'alright'],
  'wich': ['which'],
  'whith': ['with'],
  'becuase': ['because'],
  'becasue': ['because'],
  'baisc': ['basic'],
  'baiscly': ['basically'],
  'diffrent': ['different'],
  'succesful': ['successful'],
  'successfuly': ['successfully'],
  'enviroment': ['environment'],
  'knowlege': ['knowledge'],
  'knowlegeable': ['knowledgeable'],
  'noticable': ['noticeable'],
  'arguement': ['argument'],
  'publically': ['publicly'],
  'writting': ['writing'],
  'familar': ['familiar'],
  'appologize': ['apologize'],
  'fourty': ['forty'],
  'gaurantee': ['guarantee'],
  'guarentee': ['guarantee'],
  'happend': ['happened'],
  'interupt': ['interrupt'],
  'liason': ['liaison'],
  'milennium': ['millennium'],
  'mispell': ['misspell'],
  'mispelled': ['misspelled'],
  'ocassion': ['occasion'],
  'ocasionally': ['occasionally'],
  'paralell': ['parallel'],
  'persue': ['pursue'],
  'posession': ['possession'],
  'prefered': ['preferred'],
  'pronounciation': ['pronunciation'],
  'questionaire': ['questionnaire'],
  'recommand': ['recommend'],
  'religous': ['religious'],
  'rember': ['remember'],
  'resistence': ['resistance'],
  'rythm': ['rhythm'],
  'sieze': ['seize'],
  'sence': ['sense', 'since'],
  'suprise': ['surprise'],
  'tendancy': ['tendency'],
  'threshhold': ['threshold'],
  'twelth': ['twelfth'],
  'tyrany': ['tyranny'],
  'vaccum': ['vacuum'],
  'vehical': ['vehicle'],
  'visable': ['visible'],
  'wether': ['whether', 'weather'],
  'yeild': ['yield'],
};

/// Foundational English core lexicon containing essential English vocabulary.
final _commonLexicon = {
  ...<String>[
    // Articles, pronouns, prepositions, conjunctions
    'a',
    'an',
    'the',
    'this',
    'that',
    'these',
    'those',
    'my',
    'your',
    'his',
    'her',
    'its',
    'our',
    'their',
    'what',
    'which',
    'who',
    'whom',
    'whose',
    'i',
    'you',
    'he',
    'she', 'it', 'we', 'they', 'me', 'him', 'us', 'them', 'myself', 'yourself',
    'himself',
    'herself',
    'itself',
    'ourselves',
    'themselves',
    'someone',
    'anyone',
    'everyone', 'no one', 'something', 'anything', 'everything', 'nothing',
    'in',
    'on',
    'at',
    'by',
    'for',
    'with',
    'about',
    'against',
    'between',
    'into',
    'through',
    'during',
    'before',
    'after',
    'above',
    'below',
    'to',
    'from',
    'up',
    'down',
    'of',
    'off',
    'over',
    'under',
    'again',
    'further',
    'then',
    'once',
    'here',
    'there', 'when', 'where', 'why', 'how', 'all', 'any', 'both', 'each', 'few',
    'more', 'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only', 'own',
    'same', 'so', 'than', 'too', 'very', 'can', 'will', 'just', 'should', 'now',
    'and', 'but', 'if', 'or', 'because', 'as', 'until', 'while',

    // Common contractions
    "don't", "doesn't", "didn't", "can't", "couldn't", "won't", "wouldn't",
    "shouldn't", "isn't", "aren't", "wasn't", "weren't", "hasn't", "haven't",
    "hadn't", "it's", "that's", "what's", "who's", "there's", "here's",
    "i'm", "you're", "he's", "she's", "we're", "they're",
    "i've", "you've", "we've", "they've",
    "i'll", "you'll", "he'll", "she'll", "we'll", "they'll",
    "i'd", "you'd", "he'd", "she'd", "we'd", "they'd",

    // Core verbs (base and irregular forms)
    'be', 'is', 'am', 'are', 'was', 'were', 'been', 'being',
    'have', 'has', 'had', 'having',
    'do', 'does', 'did', 'done', 'doing',
    'say', 'says', 'said', 'saying',
    'go', 'goes', 'went', 'gone', 'going',
    'get', 'gets', 'got', 'gotten', 'getting',
    'make', 'makes', 'made', 'making',
    'know', 'knows', 'knew', 'known', 'knowing',
    'think', 'thinks', 'thought', 'thinking',
    'take', 'takes', 'took', 'taken', 'taking',
    'see', 'sees', 'saw', 'seen', 'seeing',
    'come', 'comes', 'came', 'coming',
    'want', 'wants', 'wanted', 'wanting',
    'look', 'looks', 'looked', 'looking',
    'use', 'uses', 'used', 'using',
    'find', 'finds', 'found', 'finding',
    'give', 'gives', 'gave', 'given', 'giving',
    'tell', 'tells', 'told', 'telling',
    'work', 'works', 'worked', 'working',
    'call', 'calls', 'called', 'calling',
    'try', 'tries', 'tried', 'trying',
    'ask', 'asks', 'asked', 'asking',
    'need', 'needs', 'needed', 'needing',
    'feel', 'feels', 'felt', 'feeling',
    'become', 'becomes', 'became', 'becoming',
    'leave', 'leaves', 'left', 'leaving',
    'put', 'puts', 'putting',
    'mean', 'means', 'meant', 'meaning',
    'keep', 'keeps', 'kept', 'keeping',
    'let', 'lets', 'letting',
    'begin', 'begins', 'began', 'begun', 'beginning',
    'seem', 'seems', 'seemed', 'seeming',
    'help', 'helps', 'helped', 'helping',
    'talk', 'talks', 'talked', 'talking',
    'turn', 'turns', 'turned', 'turning',
    'start', 'starts', 'started', 'starting',
    'show', 'shows', 'showed', 'shown', 'showing',
    'hear', 'hears', 'heard', 'hearing',
    'play', 'plays', 'played', 'playing',
    'run', 'runs', 'ran', 'running',
    'move', 'moves', 'moved', 'moving',
    'like', 'likes', 'liked', 'liking',
    'live', 'lives', 'lived', 'living',
    'believe', 'believes', 'believed', 'believing',
    'hold', 'holds', 'held', 'holding',
    'bring', 'brings', 'brought', 'bringing',
    'happen', 'happens', 'happened', 'happening',
    'write', 'writes', 'wrote', 'written', 'writing',
    'provide', 'provides', 'provided', 'providing',
    'sit', 'sits', 'sat', 'sitting',
    'stand', 'stands', 'stood', 'standing',
    'lose', 'loses', 'lost', 'losing',
    'pay', 'pays', 'paid', 'paying',
    'meet', 'meets', 'met', 'meeting',
    'include', 'includes', 'included', 'including',
    'continue', 'continues', 'continued', 'continuing',
    'set', 'sets', 'setting',
    'learn', 'learns', 'learned', 'learning',
    'change', 'changes', 'changed', 'changing',
    'lead', 'leads', 'led', 'leading',
    'understand', 'understands', 'understood', 'understanding',
    'watch', 'watches', 'watched', 'watching',
    'follow', 'follows', 'followed', 'following',
    'stop', 'stops', 'stopped', 'stopping',
    'create', 'creates', 'created', 'creating',
    'speak', 'speaks', 'spoke', 'spoken', 'speaking',
    'read', 'reads', 'reading',
    'allow', 'allows', 'allowed', 'allowing',
    'add', 'adds', 'added', 'adding',
    'spend', 'spends', 'spent', 'spending',
    'grow', 'grows', 'grew', 'grown', 'growing',
    'open', 'opens', 'opened', 'opening',
    'walk', 'walks', 'walked', 'walking',
    'win', 'wins', 'won', 'winning',
    'offer', 'offers', 'offered', 'offering',
    'remember', 'remembers', 'remembered', 'remembering',
    'love', 'loves', 'loved', 'loving',
    'consider', 'considers', 'considered', 'considering',
    'appear', 'appears', 'appeared', 'appearing',
    'buy', 'buys', 'bought', 'buying',
    'wait', 'waits', 'waited', 'waiting',
    'serve', 'serves', 'served', 'serving',
    'die', 'dies', 'died', 'dying',
    'send', 'sends', 'sent', 'sending',
    'expect', 'expects', 'expected', 'expecting',
    'build', 'builds', 'built', 'building',
    'stay', 'stays', 'stayed', 'staying',
    'fall', 'falls', 'fell', 'fallen', 'falling',
    'cut', 'cuts', 'cutting',
    'reach', 'reaches', 'reached', 'reaching',
    'kill', 'kills', 'killed', 'killing',
    'remain', 'remains', 'remained', 'remaining',
    'suggest', 'suggests', 'suggested', 'suggesting',
    'raise', 'raises', 'raised', 'raising',
    'pass', 'passes', 'passed', 'passing',
    'sell', 'sells', 'sold', 'selling',
    'require', 'requires', 'required', 'requiring',
    'report', 'reports', 'reported', 'reporting',
    'decide', 'decides', 'decided', 'deciding',
    'pull', 'pulls', 'pulled', 'pulling',
    'save', 'saves', 'saved', 'saving',
    'edit', 'edits', 'edited', 'editing',
    'delete', 'deletes', 'deleted', 'deleting',
    'format', 'formats', 'formatted', 'formatting',
    'connect', 'connects', 'connected', 'connecting',
    'select', 'selects', 'selected', 'selecting',
    'display', 'displays', 'displayed', 'displaying',
    'draw', 'draws', 'drew', 'drawn', 'drawing',
    'render', 'renders', 'rendered', 'rendering',
    'export', 'exports', 'exported', 'exporting',
    'import', 'imports', 'imported', 'importing',
    'search', 'searches', 'searched', 'searching',
    'navigate', 'navigates', 'navigated', 'navigating',
    'organize', 'organizes', 'organized', 'organizing',
    'record', 'records', 'recorded', 'recording',
    'capture', 'captures', 'captured', 'capturing',
    'synchronize', 'synchronizes', 'synchronized', 'synchronizing',
    'transclude', 'transcludes', 'transcluded', 'transcluding',

    // Core nouns
    'time',
    'year',
    'people',
    'way',
    'day',
    'man',
    'thing',
    'woman',
    'life',
    'child',
    'world',
    'school',
    'state',
    'family',
    'student',
    'group',
    'country',
    'problem',
    'hand', 'part', 'place', 'case', 'week', 'company', 'system', 'program',
    'question',
    'work',
    'government',
    'number',
    'night',
    'point',
    'home',
    'water',
    'room', 'mother', 'area', 'money', 'story', 'fact', 'month', 'lot', 'right',
    'study', 'book', 'eye', 'job', 'word', 'business', 'issue', 'side', 'kind',
    'head',
    'house',
    'service',
    'friend',
    'father',
    'power',
    'hour',
    'game',
    'line',
    'end',
    'member',
    'law',
    'car',
    'city',
    'community',
    'name',
    'president',
    'team',
    'minute', 'idea', 'kid', 'body', 'information', 'back', 'parent', 'face',
    'others',
    'level',
    'office',
    'door',
    'health',
    'person',
    'art',
    'war',
    'history',
    'party', 'result', 'change', 'morning', 'reason', 'research', 'girl', 'guy',
    'moment', 'air', 'teacher', 'force', 'education',

    // High-frequency prose words. Keep ordinary notes quiet while unknown
    // proper nouns and genuine typos remain useful candidates.
    'normal', 'sentence', 'sentences', 'highlight', 'highlights',
    'highlighted', 'working', 'everything', 'something', 'nothing',
    'project', 'projects', 'feature', 'features', 'problem', 'problems',
    'solution', 'solutions', 'example', 'examples', 'possible', 'actually',
    'already', 'again', 'around', 'because', 'before', 'between', 'both',
    'cannot', 'changes', 'check', 'checks', 'correct', 'currently', 'edit',
    'editing', 'error', 'errors', 'every', 'found', 'general', 'issue',
    'issues', 'keep', 'later', 'maybe', 'missing', 'often', 'once', 'page',
    'pages', 'read', 'reading', 'really', 'review', 'second', 'still', 'sure',
    'text', 'thing', 'things', 'through', 'today', 'together', 'under',
    'useful', 'using', 'want', 'well', 'without', 'words', 'write', 'writing',
    'wrong',

    // Knowledge OS, Notes & Canvas nouns
    'note', 'notes', 'notebook', 'board', 'boards', 'canvas', 'card', 'cards',
    'element', 'elements', 'layer', 'layers', 'workspace', 'vault', 'editor',
    'inspector', 'sidebar', 'palette', 'search', 'folder', 'folders', 'file',
    'files',
    'attachment',
    'attachments',
    'document',
    'documents',
    'tag',
    'tags',
    'link', 'links', 'backlink', 'backlinks', 'wikilink', 'wikilinks', 'quote',
    'quotes', 'block', 'blocks', 'outline', 'graph', 'diagram', 'flowchart',
    'table', 'tables', 'row', 'rows', 'column', 'columns', 'cell', 'cells',
    'markdown', 'heading', 'headings', 'paragraph', 'paragraphs', 'bullet',
    'checklist', 'item', 'items', 'list', 'lists', 'task', 'tasks', 'todo',
    'code', 'formula', 'math', 'equation', 'image', 'images', 'drawing', 'pen',
    'ink', 'stroke', 'strokes', 'brush', 'eraser', 'color', 'colors', 'palette',
    'font', 'fonts', 'typography', 'family', 'serif', 'sans', 'monospace',
    'style', 'styles', 'weight', 'size', 'spacing', 'theme', 'dark', 'light',
    'settings', 'option', 'options', 'view', 'views', 'split', 'focus', 'mode',
    'minimap', 'radar', 'zoom', 'pan', 'selection', 'undo', 'redo', 'history',
    'sync', 'synchronization', 'transclusion', 'transclusions', 'connection',
    'connections',
    'relation',
    'relations',
    'preview',
    'source',
    'title',
    'body',
    'summary', 'overview', 'detail', 'details', 'rule', 'rules', 'grammar',
    'spelling',
    'spellcheck',
    'dictionary',
    'suggestion',
    'suggestions',
    'correction',
    'corrections', 'fix', 'fixes', 'click', 'right-click', 'menu', 'button',
    'dialog', 'prompt', 'modal', 'header', 'footer', 'layout', 'design',

    // Common adjectives & adverbs
    'good', 'new', 'first', 'last', 'long', 'great', 'little', 'own', 'other',
    'old',
    'right',
    'big',
    'high',
    'different',
    'small',
    'large',
    'next',
    'early',
    'young',
    'important',
    'few',
    'public',
    'bad',
    'same',
    'able',
    'fast',
    'slow',
    'easy',
    'hard',
    'clear',
    'simple',
    'clean',
    'quiet',
    'dark',
    'bright',
    'deep',
    'direct',
    'local',
    'global',
    'active',
    'passive',
    'safe',
    'secure',
    'private',
    'offline', 'online', 'live', 'real', 'virtual', 'spatial', 'visual', 'true',
    'false', 'useful', 'helpful', 'ready', 'open', 'closed', 'empty', 'full',
    'unique',
    'central',
    'final',
    'main',
    'major',
    'minor',
    'general',
    'specific',
    'natural', 'social', 'academic', 'technical', 'editorial', 'personal',
    'well', 'also', 'often', 'however', 'too', 'usually', 'really', 'early',
    'never', 'always', 'sometimes', 'together', 'likely', 'simply', 'generally',
    'already', 'actually', 'probably', 'especially', 'almost', 'completely',
    'easily', 'quickly', 'slowly', 'carefully', 'quietly', 'safely', 'directly',

    // Everyday core vocabulary (animals, colors, common actions, nature)
    'quick', 'brown', 'fox', 'foxes', 'jump', 'jumps', 'jumped', 'jumping',
    'lazy', 'dog', 'dogs', 'cat', 'cats', 'bird', 'birds', 'fish', 'horse',
    'red', 'blue', 'green', 'yellow', 'black', 'white', 'orange', 'purple',
    'pink', 'gray', 'grey', 'gold', 'silver', 'check', 'checks', 'checked',
    'checking', 'out', 'in', 'away', 'back', 'up', 'down', 'hello', 'hi',
    'goodbye', 'bye', 'welcome', 'thanks', 'thank', 'please', 'yes', 'no',
    'maybe',
    'today',
    'yesterday',
    'tomorrow',
    'tonight',
    'morning',
    'afternoon',
    'evening', 'week', 'month', 'year', 'package', 'packages', 'letter',
    'letters', 'message', 'messages', 'box', 'boxes', 'bag', 'bags', 'apple',
    'apples', 'banana', 'bananas', 'food', 'water', 'tea', 'coffee', 'bread',
    'fruit',
    'tree',
    'trees',
    'flower',
    'flowers',
    'sun',
    'moon',
    'star',
    'stars',
    'sky',
    'sea',
    'ocean',
    'river',
    'lake',
    'mountain',
    'hill',
    'road',
    'street',
    'town', 'city', 'country', 'world', 'earth', 'wiki', 'test', 'tests',
    'tested', 'testing', 'user', 'users', 'pass', 'passed', 'fail', 'failed',
    'error', 'errors', 'warn', 'warning', 'info', 'success', 'happy', 'sad',
    'brave', 'smart', 'kind', 'fine', 'great', 'awesome', 'cool', 'nice',
    'strong', 'weak', 'warm', 'cold', 'hot', 'rich', 'poor', 'near', 'far',
    'high', 'low', 'short', 'tall', 'wide', 'narrow', 'thick', 'thin', 'heavy',
    'light', 'best', 'better', 'worst', 'worse',
  ],
};
