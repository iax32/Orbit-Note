import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_theme.dart';

/// Detailed statistics computed from note text.
class DocumentStats {
  const DocumentStats({
    required this.words,
    required this.characters,
    required this.charactersNoSpaces,
    required this.sentences,
    required this.paragraphs,
    required this.headings,
    required this.readingMinutes,
    required this.readingSeconds,
    required this.speakingMinutes,
    required this.speakingSeconds,
    this.fleschReadingEase = 0.0,
    this.fleschKincaidGrade = 0.0,
    this.averageSentenceLength = 0.0,
    this.averageWordLength = 0.0,
    this.syllables = 0,
  });

  final int words;
  final int characters;
  final int charactersNoSpaces;
  final int sentences;
  final int paragraphs;
  final int headings;
  final int readingMinutes;
  final int readingSeconds;
  final int speakingMinutes;
  final int speakingSeconds;
  final double fleschReadingEase;
  final double fleschKincaidGrade;
  final double averageSentenceLength;
  final double averageWordLength;
  final int syllables;

  String get readingEaseLabel {
    if (words == 0) return 'N/A';
    if (fleschReadingEase >= 90) return 'Very Easy';
    if (fleschReadingEase >= 80) return 'Easy';
    if (fleschReadingEase >= 70) return 'Fairly Easy';
    if (fleschReadingEase >= 60) return 'Standard';
    if (fleschReadingEase >= 50) return 'Fairly Difficult';
    if (fleschReadingEase >= 30) return 'Difficult';
    return 'Very Difficult (Academic)';
  }

  String get gradeLevelLabel {
    if (words == 0) return 'N/A';
    final g = fleschKincaidGrade.round();
    if (g <= 5) return 'Elementary';
    if (g <= 8) return 'Middle School (Grade $g)';
    if (g <= 12) return 'High School (Grade $g)';
    if (g <= 16) return 'College';
    return 'Graduate';
  }

  String get readingTimeFormatted {
    if (readingMinutes == 0 && readingSeconds == 0) return '< 1 min';
    if (readingMinutes == 0) return '${readingSeconds}s';
    if (readingSeconds == 0) return '$readingMinutes min';
    return '$readingMinutes min ${readingSeconds}s';
  }

  String get speakingTimeFormatted {
    if (speakingMinutes == 0 && speakingSeconds == 0) return '< 1 min';
    if (speakingMinutes == 0) return '${speakingSeconds}s';
    if (speakingSeconds == 0) return '$speakingMinutes min';
    return '$speakingMinutes min ${speakingSeconds}s';
  }

  static int _countSyllables(String word) {
    final clean = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (clean.isEmpty) return 0;
    if (clean.length <= 3) return 1;
    var w = clean.replaceAll(RegExp(r'(?:es|ed|e)$'), '');
    if (w.isEmpty) w = clean;
    final matches = RegExp(r'[aeiouy]{1,2}').allMatches(w);
    return math.max(1, matches.length);
  }

  static DocumentStats compute(String text, {bool isLatex = false}) {
    if (text.trim().isEmpty) {
      return const DocumentStats(
        words: 0,
        characters: 0,
        charactersNoSpaces: 0,
        sentences: 0,
        paragraphs: 0,
        headings: 0,
        readingMinutes: 0,
        readingSeconds: 0,
        speakingMinutes: 0,
        speakingSeconds: 0,
      );
    }

    final words = RegExp(r'\S+').allMatches(text).length;
    final characters = text.runes.length;
    final charactersNoSpaces = text.replaceAll(RegExp(r'\s'), '').runes.length;

    // Estimate sentences
    final sentenceMatches = RegExp(r'[^.!?]+[.!?](\s|$)').allMatches(text);
    final sentences = sentenceMatches.isEmpty
        ? (text.trim().isEmpty ? 0 : 1)
        : sentenceMatches.length;

    // Paragraphs: separated by double linebreaks or non-empty lines
    final paragraphList = text
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final paragraphs = paragraphList.isEmpty
        ? (text.trim().isEmpty ? 0 : 1)
        : paragraphList.length;

    // Headings
    int headings = 0;
    if (isLatex) {
      headings = RegExp(
        r'\\(part|chapter|section|subsection|subsubsection)\*?\{',
      ).allMatches(text).length;
    } else {
      headings = RegExp(r'(^|\n)#{1,6}\s+\S+').allMatches(text).length;
    }

    // Reading time at 200 wpm
    final totalReadSec = (words / 200.0 * 60.0).round();
    final readingMinutes = totalReadSec ~/ 60;
    final readingSeconds = totalReadSec % 60;

    // Speaking time at 130 wpm
    final totalSpeakSec = (words / 130.0 * 60.0).round();
    final speakingMinutes = totalSpeakSec ~/ 60;
    final speakingSeconds = totalSpeakSec % 60;

    // Readability and syllable counting
    int totalSyllables = 0;
    final wordList = RegExp(r'[a-zA-Z]+').allMatches(text);
    for (final match in wordList) {
      totalSyllables += _countSyllables(match.group(0)!);
    }
    if (totalSyllables == 0 && words > 0) totalSyllables = words;

    final avgSentenceLen = sentences > 0 ? (words / sentences) : 0.0;
    final avgWordLen = words > 0 ? (charactersNoSpaces / words) : 0.0;

    double ease = 0.0;
    double grade = 0.0;
    if (words > 0 && sentences > 0) {
      ease =
          206.835 -
          (1.015 * avgSentenceLen) -
          (84.6 * (totalSyllables / words));
      ease = ease.clamp(0.0, 100.0);
      grade =
          (0.39 * avgSentenceLen) + (11.8 * (totalSyllables / words)) - 15.59;
      if (grade < 0) grade = 0;
    }

    return DocumentStats(
      words: words,
      characters: characters,
      charactersNoSpaces: charactersNoSpaces,
      sentences: sentences,
      paragraphs: paragraphs,
      headings: headings,
      readingMinutes: readingMinutes,
      readingSeconds: readingSeconds,
      speakingMinutes: speakingMinutes,
      speakingSeconds: speakingSeconds,
      fleschReadingEase: ease,
      fleschKincaidGrade: grade,
      averageSentenceLength: avgSentenceLen,
      averageWordLength: avgWordLen,
      syllables: totalSyllables,
    );
  }

  String formatSummary({String? title, DocumentStats? selection}) {
    final buffer = StringBuffer();
    if (title != null && title.isNotEmpty) {
      buffer.writeln('Statistics for: $title');
      buffer.writeln('---');
    }
    if (selection != null) {
      buffer.writeln('Selection:');
      buffer.writeln('  Words: ${selection.words}');
      buffer.writeln(
        '  Characters: ${selection.characters} (${selection.charactersNoSpaces} without spaces)',
      );
      buffer.writeln('  Reading time: ${selection.readingTimeFormatted}');
      buffer.writeln(
        '  Readability: ${selection.fleschReadingEase.toStringAsFixed(1)} / 100 (${selection.readingEaseLabel})',
      );
      buffer.writeln();
      buffer.writeln('Full Document:');
    }
    buffer.writeln('  Words: $words');
    buffer.writeln(
      '  Characters: $characters ($charactersNoSpaces without spaces)',
    );
    buffer.writeln('  Paragraphs: $paragraphs');
    buffer.writeln('  Sentences: $sentences');
    buffer.writeln('  Headings: $headings');
    buffer.writeln(
      '  Readability: ${fleschReadingEase.toStringAsFixed(1)} / 100 ($readingEaseLabel)',
    );
    buffer.writeln(
      '  Grade level: $gradeLevelLabel (Grade ${fleschKincaidGrade.toStringAsFixed(1)})',
    );
    buffer.writeln(
      '  Average sentence: ${averageSentenceLength.toStringAsFixed(1)} words',
    );
    buffer.writeln('  Estimated reading time: $readingTimeFormatted (200 wpm)');
    buffer.writeln(
      '  Estimated speaking time: $speakingTimeFormatted (130 wpm)',
    );
    return buffer.toString();
  }
}

/// Displays the document analytics dialog.
Future<void> showDocumentStatsDialog(
  BuildContext context, {
  required String title,
  required String text,
  String? selectedText,
  required bool isLatex,
  int? targetWords,
  ValueChanged<int?>? onTargetWordsChanged,
}) async {
  final fullStats = DocumentStats.compute(text, isLatex: isLatex);
  final hasSelection = selectedText != null && selectedText.trim().isNotEmpty;
  final selStats = hasSelection
      ? DocumentStats.compute(selectedText, isLatex: isLatex)
      : null;

  await showDialog<void>(
    context: context,
    builder: (ctx) => _DocumentStatsDialogView(
      title: title,
      isLatex: isLatex,
      fullStats: fullStats,
      selStats: selStats,
      targetWords: targetWords,
      onTargetWordsChanged: onTargetWordsChanged,
    ),
  );
}

class _DocumentStatsDialogView extends StatefulWidget {
  const _DocumentStatsDialogView({
    required this.title,
    required this.isLatex,
    required this.fullStats,
    this.selStats,
    this.targetWords,
    this.onTargetWordsChanged,
  });

  final String title;
  final bool isLatex;
  final DocumentStats fullStats;
  final DocumentStats? selStats;
  final int? targetWords;
  final ValueChanged<int?>? onTargetWordsChanged;

  @override
  State<_DocumentStatsDialogView> createState() =>
      _DocumentStatsDialogViewState();
}

class _DocumentStatsDialogViewState extends State<_DocumentStatsDialogView> {
  bool _copied = false;
  int _activeTab = 0; // 0 = Document, 1 = Selection
  Timer? _copyTimer;
  late int? _targetWords = widget.targetWords;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = OrbitColors.of(context);
    final showSelectionTab = widget.selStats != null;
    final currentStats = (_activeTab == 1 && showSelectionTab)
        ? widget.selStats!
        : widget.fullStats;

    return Dialog(
      backgroundColor: c.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.analytics_outlined,
                      size: 18,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Document Analytics',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        Text(
                          widget.title.isEmpty ? 'Untitled note' : widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Selector if selection is active
              if (showSelectionTab) ...[
                Container(
                  height: 34,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: c.raised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _activeTab == 0
                                  ? c.accent.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Full Document',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _activeTab == 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: _activeTab == 0 ? c.accent : c.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 1),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _activeTab == 1
                                  ? c.accent.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Selected Text',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _activeTab == 1
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: _activeTab == 1 ? c.accent : c.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Metric Cards Grid
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Words',
                              value: currentStats.words.toString(),
                              icon: Icons.text_snippet_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              label: 'Characters',
                              value: currentStats.characters.toString(),
                              subtitle:
                                  '${currentStats.charactersNoSpaces} without spaces',
                              icon: Icons.font_download_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Paragraphs',
                              value: currentStats.paragraphs.toString(),
                              icon: Icons.segment_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              label: 'Sentences',
                              value: currentStats.sentences.toString(),
                              icon: Icons.short_text_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              label: 'Headings',
                              value: currentStats.headings.toString(),
                              icon: Icons.title_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Reading Time',
                              value: currentStats.readingTimeFormatted,
                              subtitle: 'at ~200 words / min',
                              icon: Icons.menu_book_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              label: 'Speaking Time',
                              value: currentStats.speakingTimeFormatted,
                              subtitle: 'at ~130 words / min',
                              icon: Icons.record_voice_over_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _ReadabilityCard(stats: currentStats),
                      const SizedBox(height: 8),
                      _TargetGoalCard(
                        currentWords: currentStats.words,
                        targetWords: _targetWords,
                        onTargetChanged: (newTarget) {
                          setState(() => _targetWords = newTarget);
                          widget.onTargetWordsChanged?.call(newTarget);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      final summary = widget.fullStats.formatSummary(
                        title: widget.title,
                        selection: widget.selStats,
                      );
                      Clipboard.setData(ClipboardData(text: summary));
                      _copyTimer?.cancel();
                      setState(() => _copied = true);
                      _copyTimer = Timer(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _copied = false);
                      });
                    },
                    icon: Icon(
                      _copied ? Icons.check : Icons.copy_rounded,
                      size: 16,
                      color: _copied ? OrbitColors.of(context).success : null,
                    ),
                    label: Text(_copied ? 'Copied' : 'Copy Stats'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: c.border),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: OrbitColors.of(context).onAccent,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: c.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: c.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: c.muted.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TargetGoalCard extends StatelessWidget {
  const _TargetGoalCard({
    required this.currentWords,
    required this.targetWords,
    required this.onTargetChanged,
  });

  final int currentWords;
  final int? targetWords;
  final ValueChanged<int?> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    final theme = Theme.of(context);
    final target = targetWords;

    if (target == null || target <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(Icons.flag_outlined, size: 14, color: c.muted),
            const SizedBox(width: 8),
            Text(
              'Target Goal:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: c.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            _GoalPresetChip(label: '500', value: 500, onTap: onTargetChanged),
            const SizedBox(width: 4),
            _GoalPresetChip(label: '1k', value: 1000, onTap: onTargetChanged),
            const SizedBox(width: 4),
            _GoalPresetChip(label: '2k', value: 2000, onTap: onTargetChanged),
            const SizedBox(width: 4),
            _GoalPresetChip(label: '5k', value: 5000, onTap: onTargetChanged),
          ],
        ),
      );
    }

    final percent = ((currentWords / target) * 100).clamp(0, 999).toInt();
    final isReached = currentWords >= target;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReached
              ? OrbitColors.of(context).success.withValues(alpha: 0.4)
              : c.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isReached ? Icons.check_circle_outline : Icons.flag_rounded,
                size: 14,
                color: isReached ? OrbitColors.of(context).success : c.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Writing Goal: $currentWords / $target words',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isReached ? OrbitColors.of(context).success : c.accent,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onTargetChanged(null),
                child: Icon(Icons.close, size: 14, color: c.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (currentWords / target).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: c.border,
              valueColor: AlwaysStoppedAnimation(
                isReached ? OrbitColors.of(context).success : c.accent,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isReached
                ? 'Goal achieved! (+${currentWords - target} words over target)'
                : '${target - currentWords} words remaining to target',
            style: TextStyle(
              fontSize: 10,
              color: isReached
                  ? OrbitColors.of(context).success
                  : c.muted.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalPresetChip extends StatelessWidget {
  const _GoalPresetChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final int value;
  final ValueChanged<int?> onTap;

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.panel,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
        ),
      ),
    );
  }
}

class _ReadabilityCard extends StatelessWidget {
  const _ReadabilityCard({required this.stats});

  final DocumentStats stats;

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);

    final scoreColor = stats.fleschReadingEase >= 60
        ? OrbitColors.of(context)
              .success // Emerald
        : (stats.fleschReadingEase >= 40
              ? OrbitColors.of(context)
                    .warning // Amber
              : OrbitColors.of(context).danger); // Rose

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_stories_outlined, size: 16, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Readability & Complexity',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${stats.fleschReadingEase.toStringAsFixed(0)} / 100',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reading Ease',
                      style: TextStyle(fontSize: 10, color: c.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats.readingEaseLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Level',
                      style: TextStyle(fontSize: 10, color: c.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats.gradeLevelLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Avg sentence: ${stats.averageSentenceLength.toStringAsFixed(1)} words',
                  style: TextStyle(fontSize: 10, color: c.subtle),
                ),
              ),
              Expanded(
                child: Text(
                  'Avg word: ${stats.averageWordLength.toStringAsFixed(1)} chars',
                  style: TextStyle(fontSize: 10, color: c.subtle),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
