import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/orbit_theme.dart';
import 'reading_room_model.dart';
import 'ambient_sound_mixer.dart';

/// Modal dialog for tuning virtual reading room environment, sounds, and session timer.
class ReadingRoomAmbienceSheet extends StatefulWidget {
  const ReadingRoomAmbienceSheet({
    super.key,
    required this.initialRoom,
    required this.activeColorFilter,
    required this.onRoomChanged,
    required this.onColorFilterChanged,
    this.onStartSession,
  });

  final ReadingRoom initialRoom;
  final String activeColorFilter; // 'normal', 'sepia', 'dark', 'editorial'
  final ValueChanged<ReadingRoom> onRoomChanged;
  final ValueChanged<String> onColorFilterChanged;
  final void Function(int minutes, ReadingRoom room)? onStartSession;

  static Future<void> show(
    BuildContext context, {
    required ReadingRoom initialRoom,
    required String activeColorFilter,
    required ValueChanged<ReadingRoom> onRoomChanged,
    required ValueChanged<String> onColorFilterChanged,
    void Function(int minutes, ReadingRoom room)? onStartSession,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ReadingRoomAmbienceSheet(
        initialRoom: initialRoom,
        activeColorFilter: activeColorFilter,
        onRoomChanged: onRoomChanged,
        onColorFilterChanged: onColorFilterChanged,
        onStartSession: onStartSession,
      ),
    );
  }

  @override
  State<ReadingRoomAmbienceSheet> createState() =>
      _ReadingRoomAmbienceSheetState();
}

class _ReadingRoomAmbienceSheetState extends State<ReadingRoomAmbienceSheet> {
  late ReadingRoom _currentRoom;
  late String _currentColorFilter;
  int _selectedSessionMinutes = 25;

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.initialRoom;
    _currentColorFilter = widget.activeColorFilter;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitColors.of(context);

    return Dialog(
      backgroundColor: colors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _currentRoom.accentTone.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _currentRoom.icon,
                      size: 20,
                      color: _currentRoom.accentTone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentRoom.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _currentRoom.tagline,
                          style: TextStyle(fontSize: 12, color: colors.subtle),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: colors.border),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Virtual Room Selector
                      Text(
                        'Virtual Reading Environment',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.subtle,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final r in ReadingRoomCatalog.all)
                            ChoiceChip(
                              key: ValueKey('room-chip-${r.id}'),
                              avatar: Icon(
                                r.icon,
                                size: 15,
                                color: _currentRoom.id == r.id
                                    ? r.accentTone
                                    : colors.subtle,
                              ),
                              label: Text(r.name),
                              selected: _currentRoom.id == r.id,
                              selectedColor: r.accentTone.withValues(
                                alpha: 0.18,
                              ),
                              backgroundColor: colors.raised,
                              side: BorderSide(
                                color: _currentRoom.id == r.id
                                    ? r.accentTone
                                    : colors.border,
                              ),
                              onSelected: (_) {
                                setState(() => _currentRoom = r);
                                widget.onRoomChanged(r);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Ambient Sound Channels Mixer
                      AmbientSoundMixer(
                        room: _currentRoom,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // Reader Paper Tone / Color Theme
                      Text(
                        'Reading Paper Tone',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.subtle,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildToneChip(
                            'normal',
                            'Original',
                            Icons.image_outlined,
                            colors,
                          ),
                          const SizedBox(width: 8),
                          _buildToneChip(
                            'sepia',
                            'Cozy Sepia',
                            Icons.wb_sunny_outlined,
                            colors,
                          ),
                          const SizedBox(width: 8),
                          _buildToneChip(
                            'editorial',
                            'Editorial Warm',
                            Icons.article_outlined,
                            colors,
                          ),
                          const SizedBox(width: 8),
                          _buildToneChip(
                            'dark',
                            'Dark Mode',
                            Icons.dark_mode_outlined,
                            colors,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Focus Reading Session
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.raised,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: _currentRoom.accentTone,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Focus Reading Session',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Timed reading session with ambient audio and progress tracking.',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.subtle,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                for (final mins in [15, 25, 30, 45, 60])
                                  ChoiceChip(
                                    label: Text('${mins}m'),
                                    selected: _selectedSessionMinutes == mins,
                                    selectedColor: _currentRoom.accentTone
                                        .withValues(alpha: 0.2),
                                    backgroundColor: colors.panel,
                                    onSelected: (_) => setState(
                                      () => _selectedSessionMinutes = mins,
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                FilledButton.icon(
                                  key: const ValueKey(
                                    'start-focus-reading-btn',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _currentRoom.accentTone,
                                    foregroundColor: OrbitContrast.inkOn(
                                      _currentRoom.accentTone,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Start'),
                                  onPressed: () {
                                    widget.onStartSession?.call(
                                      _selectedSessionMinutes,
                                      _currentRoom,
                                    );
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToneChip(
    String id,
    String label,
    IconData icon,
    OrbitColors colors,
  ) {
    final isSelected = _currentColorFilter == id;
    return Expanded(
      child: InkWell(
        key: ValueKey('paper-tone-$id'),
        onTap: () {
          setState(() => _currentColorFilter = id);
          widget.onColorFilterChanged(id);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? _currentRoom.accentTone.withValues(alpha: 0.15)
                : colors.raised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? _currentRoom.accentTone : colors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? _currentRoom.accentTone : colors.subtle,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? _currentRoom.accentTone : colors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
