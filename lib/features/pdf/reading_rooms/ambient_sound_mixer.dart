import 'package:flutter/material.dart';
import '../../../app/orbit_theme.dart';
import 'reading_room_model.dart';

/// Interactive sound mixer for virtual reading room ambient audio channels.
class AmbientSoundMixer extends StatefulWidget {
  const AmbientSoundMixer({super.key, required this.room, this.onChanged});

  final ReadingRoom room;
  final VoidCallback? onChanged;

  @override
  State<AmbientSoundMixer> createState() => _AmbientSoundMixerState();
}

class _AmbientSoundMixerState extends State<AmbientSoundMixer> {
  bool _isPlaying = true;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Master controls & status
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.room.accentTone.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.room.icon,
                  size: 16,
                  color: widget.room.accentTone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atmospheric Ambience',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _isPlaying ? 'Playing in room' : 'Audio paused',
                      style: TextStyle(fontSize: 11, color: colors.subtle),
                    ),
                  ],
                ),
              ),
              // Quiet master play/pause toggle
              IconButton(
                key: const ValueKey('sound-mixer-master-toggle'),
                tooltip: _isPlaying ? 'Pause ambience' : 'Play ambience',
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: widget.room.accentTone,
                  size: 24,
                ),
                onPressed: () {
                  setState(() => _isPlaying = !_isPlaying);
                  widget.onChanged?.call();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 10),

          // Individual Channels
          for (final channel in widget.room.soundChannels)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  IconButton(
                    key: ValueKey('mute-${channel.id}'),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    tooltip: channel.isMuted
                        ? 'Unmute ${channel.name}'
                        : 'Mute ${channel.name}',
                    icon: Icon(
                      channel.isMuted
                          ? Icons.volume_off_rounded
                          : (channel.volume > 0.5
                                ? Icons.volume_up_rounded
                                : Icons.volume_down_rounded),
                      color: channel.isMuted ? colors.muted : colors.subtle,
                    ),
                    onPressed: () {
                      setState(() => channel.isMuted = !channel.isMuted);
                      widget.onChanged?.call();
                    },
                  ),
                  SizedBox(
                    width: 105,
                    child: Text(
                      channel.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: channel.isMuted ? colors.muted : colors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        activeTrackColor: widget.room.accentTone,
                        inactiveTrackColor: colors.border,
                        thumbColor: widget.room.accentTone,
                        overlayColor: widget.room.accentTone.withValues(
                          alpha: 0.12,
                        ),
                      ),
                      child: Slider(
                        value: channel.isMuted ? 0.0 : channel.volume,
                        min: 0.0,
                        max: 1.0,
                        onChanged: channel.isMuted
                            ? null
                            : (val) {
                                setState(() => channel.volume = val);
                                widget.onChanged?.call();
                              },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 32,
                    child: Text(
                      channel.isMuted
                          ? 'Off'
                          : '${(channel.volume * 100).toInt()}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 10,
                        color: channel.isMuted ? colors.muted : colors.subtle,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
