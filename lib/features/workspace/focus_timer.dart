import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';

enum FocusMode {
  focus('Focus (25m)', 'Focus', 25, Icons.center_focus_strong_rounded),
  shortBreak('Short Break (5m)', 'Break', 5, Icons.coffee_rounded),
  longBreak('Long Break (15m)', 'Rest', 15, Icons.park_rounded);

  const FocusMode(this.label, this.shortLabel, this.minutes, this.icon);

  final String label;
  final String shortLabel;
  final int minutes;
  final IconData icon;

  int get totalSeconds => minutes * 60;
}

/// Controller managing focus / Pomodoro timer state, cycles, and streak.
class FocusTimerController extends ChangeNotifier {
  FocusTimerController({FocusMode initialMode = FocusMode.focus})
    : _mode = initialMode,
      _totalSeconds = initialMode.totalSeconds,
      _remainingSeconds = initialMode.totalSeconds;

  FocusMode _mode;
  int _totalSeconds;
  int _remainingSeconds;
  bool _isRunning = false;
  int _completedSessions = 0;
  Timer? _ticker;
  int _focusMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;

  FocusMode get mode => _mode;
  int get totalSeconds => _totalSeconds;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  int get completedSessions => _completedSessions;
  int get streakInCycle => _completedSessions % 4;
  int get focusMinutes => _focusMinutes;
  int get shortBreakMinutes => _shortBreakMinutes;
  int get longBreakMinutes => _longBreakMinutes;

  int _minutesForMode(FocusMode mode) {
    switch (mode) {
      case FocusMode.focus:
        return _focusMinutes;
      case FocusMode.shortBreak:
        return _shortBreakMinutes;
      case FocusMode.longBreak:
        return _longBreakMinutes;
    }
  }

  void configureDurations({int? focus, int? shortBreak, int? longBreak}) {
    if (focus != null) _focusMinutes = focus;
    if (shortBreak != null) _shortBreakMinutes = shortBreak;
    if (longBreak != null) _longBreakMinutes = longBreak;
    if (!_isRunning) {
      _totalSeconds = _minutesForMode(_mode) * 60;
      _remainingSeconds = _totalSeconds;
      notifyListeners();
    }
  }

  double get progress => _totalSeconds > 0
      ? ((_totalSeconds - _remainingSeconds) / _totalSeconds).clamp(0.0, 1.0)
      : 0.0;

  String get formattedTime {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    notifyListeners();
  }

  void pause() {
    if (!_isRunning) return;
    _isRunning = false;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void reset() {
    _isRunning = false;
    _ticker?.cancel();
    _ticker = null;
    _remainingSeconds = _totalSeconds;
    notifyListeners();
  }

  void setMode(FocusMode newMode) {
    _mode = newMode;
    _totalSeconds = _minutesForMode(newMode) * 60;
    _remainingSeconds = _totalSeconds;
    _isRunning = false;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void skip() {
    _advanceToNextMode();
  }

  void tick() {
    if (_remainingSeconds > 1) {
      _remainingSeconds--;
      notifyListeners();
    } else {
      _remainingSeconds = 0;
      _advanceToNextMode();
    }
  }

  void _advanceToNextMode() {
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;

    if (_mode == FocusMode.focus) {
      _completedSessions++;
      if (_completedSessions % 4 == 0) {
        _mode = FocusMode.longBreak;
      } else {
        _mode = FocusMode.shortBreak;
      }
    } else {
      _mode = FocusMode.focus;
    }
    _totalSeconds = _minutesForMode(_mode) * 60;
    _remainingSeconds = _totalSeconds;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Global shared timer controller instance across workspace navigation.
final globalFocusTimer = FocusTimerController();

/// Shows the Focus / Pomodoro Timer dialog matching MOT-02.
Future<void> showFocusTimerDialog(
  BuildContext context, [
  FocusTimerController? controller,
]) {
  final ctrl = controller ?? globalFocusTimer;
  return showOrbitDialog<void>(
    context: context,
    builder: (ctx) => FocusTimerDialog(controller: ctrl),
  );
}

/// Interactive Focus Timer dialog with radial ring, breathing pulse, and streak dots.
class FocusTimerDialog extends StatefulWidget {
  const FocusTimerDialog({super.key, required this.controller});

  final FocusTimerController controller;

  @override
  State<FocusTimerDialog> createState() => _FocusTimerDialogState();
}

class _FocusTimerDialogState extends State<FocusTimerDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathingAnim;

  @override
  void initState() {
    super.initState();
    _breathingAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.controller.isRunning) {
      _breathingAnim.repeat(reverse: true);
    }
    widget.controller.addListener(_onTimerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTimerUpdate);
    _breathingAnim.dispose();
    super.dispose();
  }

  void _onTimerUpdate() {
    if (!mounted) return;
    if (widget.controller.isRunning && !_breathingAnim.isAnimating) {
      _breathingAnim.repeat(reverse: true);
    } else if (!widget.controller.isRunning && _breathingAnim.isAnimating) {
      _breathingAnim.stop();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final ctrl = widget.controller;
    final isReduced = OrbitMotionScope.isReduced(context);
    final isOff = OrbitMotionScope.isOff(context);

    final modeColor = ctrl.mode == FocusMode.focus
        ? colors.accent
        : colors.success;

    return OrbitDialog(
      title: Row(
        children: [
          Icon(Icons.timer_outlined, size: 20, color: modeColor),
          const SizedBox(width: 8),
          const Text('Focus & Deep Work'),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode Selectors
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: FocusMode.values.map((mode) {
                final isSelected = ctrl.mode == mode;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => ctrl.setMode(mode),
                    child: AnimatedContainer(
                      duration: OrbitMotionScope.duration(
                        context,
                        OrbitMotion.micro,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? modeColor.withValues(alpha: 0.18)
                            : colors.raised,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? modeColor.withValues(alpha: 0.5)
                              : colors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            mode.icon,
                            size: 13,
                            color: isSelected ? modeColor : colors.subtle,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            mode.shortLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? modeColor : colors.subtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Radial Progress Ring
            AnimatedBuilder(
              animation: _breathingAnim,
              builder: (context, _) {
                final pulse = (!isReduced && !isOff && ctrl.isRunning)
                    ? _breathingAnim.value
                    : 0.0;
                return SizedBox(
                  width: 170,
                  height: 170,
                  child: CustomPaint(
                    painter: _RadialRingPainter(
                      progress: ctrl.progress,
                      accentColor: modeColor,
                      trackColor: colors.border,
                      pulse: pulse,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ctrl.formattedTime,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: -0.5,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ctrl.mode == FocusMode.focus
                                ? 'DEEP FOCUS'
                                : 'REST & RECHARGE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: modeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  key: const ValueKey('focus-timer-reset'),
                  tooltip: 'Reset timer',
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: ctrl.reset,
                ),
                const SizedBox(width: 12),
                // Play / Pause Primary Action
                GestureDetector(
                  key: const ValueKey('focus-timer-play-pause'),
                  onTap: () {
                    if (ctrl.isRunning) {
                      ctrl.pause();
                    } else {
                      ctrl.start();
                    }
                  },
                  child: AnimatedContainer(
                    duration: OrbitMotionScope.duration(
                      context,
                      OrbitMotion.micro,
                    ),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: modeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: modeColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        ctrl.isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: OrbitContrast.inkOn(modeColor),
                        size: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  key: const ValueKey('focus-timer-skip'),
                  tooltip: 'Skip to next block',
                  icon: const Icon(Icons.skip_next_rounded, size: 20),
                  onPressed: ctrl.skip,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Completed Sessions Streak in Current Cycle (4 dots)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'CYCLE: ',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(width: 4),
                for (int i = 0; i < 4; i++) ...[
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < ctrl.streakInCycle ? modeColor : colors.border,
                      border: Border.all(
                        color: i < ctrl.streakInCycle
                            ? modeColor
                            : colors.subtle.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Text(
                  '(${ctrl.completedSessions} completed)',
                  style: TextStyle(fontSize: 10, color: colors.subtle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering circular radial progress ring with breathing pulse.
class _RadialRingPainter extends CustomPainter {
  const _RadialRingPainter({
    required this.progress,
    required this.accentColor,
    required this.trackColor,
    required this.pulse,
  });

  final double progress;
  final Color accentColor;
  final Color trackColor;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 8.0;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Progress arc
    final sweepAngle = 2 * math.pi * progress;
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final arcPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth + (pulse * 1.5);

    canvas.drawArc(
      arcRect,
      -math.pi / 2, // Start at 12 o'clock
      sweepAngle,
      false,
      arcPaint,
    );

    // Glowing tip indicator
    final tipAngle = (-math.pi / 2) + sweepAngle;
    final tipCenter = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );

    if (pulse > 0) {
      canvas.drawCircle(
        tipCenter,
        6 + (pulse * 4),
        Paint()..color = accentColor.withValues(alpha: 0.25 * pulse),
      );
    }

    canvas.drawCircle(
      tipCenter,
      4.5,
      Paint()..color = OrbitContrast.inkOn(accentColor),
    );
  }

  @override
  bool shouldRepaint(covariant _RadialRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.pulse != pulse;
  }
}

/// Compact mini button widget for the Workspace header toolbar.
class FocusTimerMiniButton extends StatefulWidget {
  const FocusTimerMiniButton({super.key, required this.controller});

  final FocusTimerController controller;

  @override
  State<FocusTimerMiniButton> createState() => _FocusTimerMiniButtonState();
}

class _FocusTimerMiniButtonState extends State<FocusTimerMiniButton> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final ctrl = widget.controller;
    final isActive = ctrl.isRunning;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: OrbitBreathingGlow(
        active: isActive,
        glowColor: colors.accent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: const ValueKey('focus-timer-button'),
          borderRadius: BorderRadius.circular(6),
          onTap: () => showFocusTimerDialog(context, ctrl),
          child: Semantics(
            label:
                'Focus Timer: ${ctrl.formattedTime} (${ctrl.mode.shortLabel})',
            button: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? colors.accent.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isActive
                      ? colors.accent.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: isActive ? colors.accent : colors.subtle,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ctrl.formattedTime,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive ? colors.accent : colors.subtle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
