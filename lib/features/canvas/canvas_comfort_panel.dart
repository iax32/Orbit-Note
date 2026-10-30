import 'package:flutter/material.dart';
import '../../app/canvas_comfort.dart';

class CanvasComfortPanel extends StatelessWidget {
  const CanvasComfortPanel({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final comfort = CanvasComfort(value);
    void change(Map<String, dynamic> values) =>
        onChanged(comfort.withValues(values));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal controls for this device. Your drawing and PDF appearance stay unchanged.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Larger drawing controls'),
          subtitle: const Text('More room to tap: 56-pixel drawing buttons.'),
          value: comfort.largeControls,
          onChanged: (v) => change({'largeControls': v}),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Softer Canvas grid'),
          subtitle: const Text(
            'Quieter paper lines while drawing. Keeps the original grid in exports.',
          ),
          value: comfort.softGrid,
          onChanged: (v) => change({'softGrid': v}),
        ),
        const Text('Place focus controls within easy reach'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => change({'x': 0.0, 'y': 1.0}),
              icon: const Icon(Icons.south_west),
              label: const Text('Left side'),
            ),
            OutlinedButton.icon(
              onPressed: () => change({'x': 1.0, 'y': 1.0}),
              icon: const Icon(Icons.south_east),
              label: const Text('Right side'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () =>
                  change({'largeControls': true, 'softGrid': true}),
              child: const Text('Use tablet comfort'),
            ),
            TextButton(
              onPressed: () => onChanged(comfort.reset),
              child: const Text('Reset comfort options'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Tip: use Focus on drawing for more space. With palm rejection on, the pen draws and your fingers move the Canvas.',
        ),
      ],
    );
  }
}
