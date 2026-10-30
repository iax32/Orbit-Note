import '../../app/orbit_components.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';

/// A compact circular progress ring displaying word goal completion percentage.
class WordGoalProgressRing extends StatelessWidget {
  const WordGoalProgressRing({
    super.key,
    required this.progress,
    this.size = 14.0,
    this.strokeWidth = 2.0,
    this.color,
    this.completedColor,
    this.backgroundColor,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? completedColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final isComplete = progress >= 1.0;
    final activeColor = isComplete
        ? (completedColor ?? colors.success)
        : (color ?? colors.accent);
    final trackColor = backgroundColor ?? colors.border;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ProgressRingPainter(
          progress: progress.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
          color: activeColor,
          backgroundColor: trackColor,
          isComplete: isComplete,
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.backgroundColor,
    required this.isComplete,
  });

  final double progress;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;
  final bool isComplete;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = progress * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.backgroundColor != backgroundColor;
}

/// Modal dialog for quickly viewing and configuring document word count goals with presets.
class WordGoalDialog extends StatefulWidget {
  const WordGoalDialog({
    super.key,
    required this.currentWords,
    this.targetWords,
    this.onTargetWordsChanged,
  });

  final int currentWords;
  final int? targetWords;
  final ValueChanged<int?>? onTargetWordsChanged;

  @override
  State<WordGoalDialog> createState() => _WordGoalDialogState();
}

class _WordGoalDialogState extends State<WordGoalDialog> {
  late final TextEditingController _controller;
  static const List<(int, String)> _presets = [
    (250, 'Draft'),
    (500, 'Short'),
    (1000, 'Article'),
    (1500, 'Essay'),
    (2000, 'Deep Dive'),
    (5000, 'Paper'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.targetWords != null ? '${widget.targetWords}' : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyGoal(int? goal) {
    widget.onTargetWordsChanged?.call(goal);
    Navigator.of(context).pop(goal);
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final theme = Theme.of(context);

    final enteredNum = int.tryParse(_controller.text.trim());
    final effectiveTarget = enteredNum != null && enteredNum > 0
        ? enteredNum
        : null;
    final progress = effectiveTarget != null
        ? (widget.currentWords / effectiveTarget)
        : 0.0;
    final percent = (progress * 100).toInt();

    return Dialog(
      backgroundColor: colors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OrbitRadius.dialog),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Word Count Goal',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          'Current count: ${widget.currentWords} words',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: colors.muted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Live Progress Preview (if target entered)
              if (effectiveTarget != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.raised,
                    borderRadius: BorderRadius.circular(OrbitRadius.control),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      WordGoalProgressRing(
                        progress: progress,
                        size: 22,
                        strokeWidth: 2.5,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              progress >= 1.0
                                  ? 'Goal Reached ($percent%)'
                                  : '$percent% of goal',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: progress >= 1.0
                                    ? colors.success
                                    : colors.accent,
                              ),
                            ),
                            Text(
                              '${widget.currentWords} of $effectiveTarget words',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Presets
              Text(
                'Quick Presets',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.subtle,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final preset in _presets)
                    ActionChip(
                      label: Text('${preset.$1} (${preset.$2})'),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: effectiveTarget == preset.$1
                            ? colors.accent
                            : colors.text,
                        fontWeight: effectiveTarget == preset.$1
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      backgroundColor: effectiveTarget == preset.$1
                          ? colors.accent.withValues(alpha: 0.15)
                          : colors.raised,
                      side: BorderSide(
                        color: effectiveTarget == preset.$1
                            ? colors.accent.withValues(alpha: 0.5)
                            : colors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _controller.text = '${preset.$1}';
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Custom Target Input
              Text(
                'Target Words',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.subtle,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('word-goal-input'),
                controller: _controller,
                keyboardType: TextInputType.number,
                autofocus: widget.targetWords == null,
                style: TextStyle(fontSize: 14, color: colors.text),
                decoration: InputDecoration(
                  hintText: 'e.g. 500 or 1000',
                  hintStyle: TextStyle(color: colors.muted),
                  filled: true,
                  fillColor: colors.raised,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OrbitRadius.control),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OrbitRadius.control),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OrbitRadius.control),
                    borderSide: BorderSide(color: colors.accent),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Actions
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  if (widget.targetWords != null)
                    TextButton(
                      key: const ValueKey('clear-word-goal-button'),
                      onPressed: () => _applyGoal(null),
                      child: Text(
                        'Clear Goal',
                        style: TextStyle(color: colors.danger, fontSize: 13),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: colors.muted, fontSize: 13),
                    ),
                  ),
                  FilledButton(
                    key: const ValueKey('set-word-goal-button'),
                    onPressed: effectiveTarget != null
                        ? () => _applyGoal(effectiveTarget)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          OrbitRadius.control,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Set Goal',
                      style: TextStyle(fontSize: 13),
                    ),
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

/// Helper to show the [WordGoalDialog].
Future<int?> showWordGoalDialog(
  BuildContext context, {
  required int currentWords,
  int? targetWords,
  ValueChanged<int?>? onTargetWordsChanged,
}) {
  return showOrbitDialog<int?>(
    context: context,
    builder: (ctx) => WordGoalDialog(
      currentWords: currentWords,
      targetWords: targetWords,
      onTargetWordsChanged: onTargetWordsChanged,
    ),
  );
}
