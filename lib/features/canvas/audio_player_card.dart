import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';

/// Interactive audio voice memo & playback card with animated waveform visualization.
class OrbitAudioPlayerCard extends StatefulWidget {
  const OrbitAudioPlayerCard({
    super.key,
    this.title = 'Voice Memo',
    this.duration = const Duration(minutes: 1, seconds: 45),
    this.initialPosition = Duration.zero,
    this.initialSpeed = 1.0,
    this.transcript,
    this.onPlayPause,
    this.onSeek,
    this.width = 340,
  });

  final String title;
  final Duration duration;
  final Duration initialPosition;
  final double initialSpeed;
  final String? transcript;
  final ValueChanged<bool>? onPlayPause;
  final ValueChanged<Duration>? onSeek;
  final double width;

  @override
  State<OrbitAudioPlayerCard> createState() => _OrbitAudioPlayerCardState();
}

class _OrbitAudioPlayerCardState extends State<OrbitAudioPlayerCard>
    with SingleTickerProviderStateMixin {
  late Duration _currentPosition;
  bool _isPlaying = false;
  double _speed = 1.0;
  bool _isMuted = false;
  bool _showTranscript = false;
  Timer? _playbackTimer;
  late final AnimationController _waveAnim;

  // 28 normalized base bar amplitudes for the voice memo audio track
  static const List<double> _baseAmplitudes = [
    0.28,
    0.42,
    0.65,
    0.38,
    0.82,
    0.95,
    0.64,
    0.48,
    0.72,
    0.86,
    0.54,
    0.32,
    0.62,
    0.78,
    0.92,
    0.44,
    0.35,
    0.58,
    0.84,
    0.68,
    0.52,
    0.74,
    0.88,
    0.42,
    0.66,
    0.46,
    0.34,
    0.22,
  ];

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
    _speed = widget.initialSpeed;
    _waveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _waveAnim.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        if (_currentPosition >= widget.duration) {
          _currentPosition = Duration.zero;
        }
        _startTimer();
        _waveAnim.repeat(reverse: true);
      } else {
        _playbackTimer?.cancel();
        _waveAnim.stop();
      }
    });
    widget.onPlayPause?.call(_isPlaying);
  }

  void _startTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        final stepMs = (100 * _speed).round();
        final newMs = _currentPosition.inMilliseconds + stepMs;
        if (newMs >= widget.duration.inMilliseconds) {
          _currentPosition = widget.duration;
          _isPlaying = false;
          _playbackTimer?.cancel();
          _waveAnim.stop();
        } else {
          _currentPosition = Duration(milliseconds: newMs);
        }
      });
    });
  }

  void _cycleSpeed() {
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.25;
      } else if (_speed == 1.25) {
        _speed = 1.5;
      } else if (_speed == 1.5) {
        _speed = 2.0;
      } else {
        _speed = 1.0;
      }
      if (_isPlaying) _startTimer();
    });
  }

  void _seekToFraction(double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    final targetMs = (widget.duration.inMilliseconds * clamped).round();
    setState(() {
      _currentPosition = Duration(milliseconds: targetMs);
    });
    widget.onSeek?.call(_currentPosition);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final isReduced = OrbitMotionScope.isReduced(context);
    final isOff = OrbitMotionScope.isOff(context);

    final progress = widget.duration.inMilliseconds > 0
        ? (_currentPosition.inMilliseconds / widget.duration.inMilliseconds)
              .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: widget.width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(OrbitRadius.card),
        border: Border.all(color: colors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Title & Badges
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mic_outlined, size: 14, color: colors.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Speed Pill
              GestureDetector(
                key: const ValueKey('audio-speed-button'),
                onTap: _cycleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.raised,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    '${_speed}x',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: colors.subtle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Mute Toggle
              IconButton(
                key: const ValueKey('audio-mute-button'),
                tooltip: _isMuted ? 'Unmute' : 'Mute',
                icon: Icon(
                  _isMuted
                      ? Icons.volume_off_outlined
                      : Icons.volume_up_outlined,
                  size: 16,
                  color: _isMuted ? colors.muted : colors.subtle,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 26,
                  height: 26,
                ),
                padding: EdgeInsets.zero,
                splashRadius: 13,
                onPressed: () => setState(() => _isMuted = !_isMuted),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Waveform & Play Control Row
          Row(
            children: [
              // Tactile Play/Pause Button
              GestureDetector(
                key: const ValueKey('audio-play-button'),
                onTap: _togglePlayPause,
                child: AnimatedContainer(
                  duration: OrbitMotionScope.duration(
                    context,
                    OrbitMotion.micro,
                  ),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: OrbitColors.of(context).onAccent,
                      size: 20,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Interactive Animated Waveform Visualizer
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final local = details.localPosition;
                      _seekToFraction(local.dx / 220.0);
                    }
                  },
                  onTapDown: (details) {
                    _seekToFraction(details.localPosition.dx / 220.0);
                  },
                  child: SizedBox(
                    height: 38,
                    child: AnimatedBuilder(
                      animation: _waveAnim,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _WaveformPainter(
                            amplitudes: _baseAmplitudes,
                            progress: progress,
                            accentColor: colors.accent,
                            barColor: colors.border,
                            isPlaying: _isPlaying && !isReduced && !isOff,
                            animationPhase: _waveAnim.value,
                          ),
                          size: const Size(double.infinity, 38),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Duration Info Row & Transcript Expander
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatDuration(_currentPosition)} / ${_formatDuration(widget.duration)}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  color: colors.subtle,
                ),
              ),
              if (widget.transcript != null && widget.transcript!.isNotEmpty)
                GestureDetector(
                  key: const ValueKey('audio-transcript-toggle'),
                  onTap: () =>
                      setState(() => _showTranscript = !_showTranscript),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: 13,
                        color: _showTranscript ? colors.accent : colors.subtle,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _showTranscript ? 'Hide transcript' : 'Transcript',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: _showTranscript
                              ? colors.accent
                              : colors.subtle,
                          fontWeight: _showTranscript
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Expandable Transcript Section with OrbitDisclosure
          OrbitDisclosure(
            expanded: _showTranscript,
            child: widget.transcript != null && widget.transcript!.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.raised,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TRANSCRIPTION',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: colors.subtle,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: widget.transcript!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Transcript copied to clipboard',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Copy',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.transcript!,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: colors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering vertical audio waveform bars with playing jitter.
class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.amplitudes,
    required this.progress,
    required this.accentColor,
    required this.barColor,
    required this.isPlaying,
    required this.animationPhase,
  });

  final List<double> amplitudes;
  final double progress;
  final Color accentColor;
  final Color barColor;
  final bool isPlaying;
  final double animationPhase;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty || size.width <= 0) return;

    final n = amplitudes.length;
    final totalSpacing = size.width;
    final barWidth = math.max(2.0, (totalSpacing / n) - 2.5);
    final gap = (totalSpacing - (n * barWidth)) / (n - 1);

    final playedPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final unplayedPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < n; i++) {
      final x = i * (barWidth + gap);
      final fraction = (i + 1) / n;
      final isPlayed = fraction <= progress;

      // Base amplitude
      double amp = amplitudes[i];

      // Subtle dynamic modulation when playing
      if (isPlaying) {
        final phaseOffset = (i * 0.25) + (animationPhase * 2 * math.pi);
        final modulation = math.sin(phaseOffset) * 0.18;
        amp = (amp + modulation).clamp(0.15, 1.0);
      }

      final barHeight = math.max(4.0, size.height * amp);
      final y = (size.height - barHeight) / 2;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(rrect, isPlayed ? playedPaint : unplayedPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.animationPhase != animationPhase ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.barColor != barColor;
  }
}
