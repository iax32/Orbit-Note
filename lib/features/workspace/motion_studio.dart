import 'package:flutter/material.dart';

import '../../app/orbit_components.dart';
import '../../app/orbit_motion_effects.dart';
import '../../app/orbit_theme.dart';
import '../../domain/motion_preferences.dart';

Future<void> showMotionStudio(
  BuildContext context, {
  Map<String, dynamic>? options,
  ValueChanged<Map<String, dynamic>>? onChanged,
  String? text,
}) => showOrbitDialog<void>(
  context: context,
  builder: (_) => _MotionStudio(
    options: options ?? OrbitMotionScope.settings(context).data,
    onChanged: onChanged,
    text: text,
  ),
);

class _MotionStudio extends StatefulWidget {
  const _MotionStudio({required this.options, this.onChanged, this.text});
  final Map<String, dynamic> options;
  final ValueChanged<Map<String, dynamic>>? onChanged;
  final String? text;
  @override
  State<_MotionStudio> createState() => _MotionStudioState();
}

class _MotionStudioState extends State<_MotionStudio>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> options = Map.of(widget.options);
  late final player = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: (900 / MotionPreferences(options).speed).round(),
    ),
    value: 1,
  );
  final search = TextEditingController();
  final previewKey = GlobalKey();
  MotionFamily? family;
  late MotionInspiration selected = motionInspirations.firstWhere(
    (e) => e.style == MotionPreferences(options).textStyle,
    orElse: () => motionInspirations.first,
  );
  int replay = 0;
  bool paused = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OrbitMotionScope.isOff(context) ||
        OrbitMotionScope.isReduced(context)) {
      player.stop();
      player.value = 1;
    }
  }

  @override
  void dispose() {
    player.dispose();
    search.dispose();
    super.dispose();
  }

  void change(Map<String, dynamic> patch) {
    final next = {...options, ...patch};
    player.stop();
    player.value = 1;
    setState(() {
      options = next;
      paused = false;
    });
    widget.onChanged?.call(next);
  }

  void play() {
    setState(() {
      replay++;
      paused = false;
    });
    player.duration = Duration(
      milliseconds: (900 / MotionPreferences(options).speed).round(),
    );
    if (OrbitMotionScope.isOff(context) ||
        OrbitMotionScope.isReduced(context)) {
      player.value = 1;
    } else {
      player.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = MotionPreferences(options), colors = OrbitColors.of(context);
    final matches = motionInspirations
        .where(
          (e) =>
              (family == null || e.family == family) &&
              '${e.title} ${e.family.name}'.toLowerCase().contains(
                search.text.trim().toLowerCase(),
              ),
        )
        .toList();
    final sample =
        widget.text ??
        'Capture a thought. Connect it to a source.\n\nYour notes, drawings and research belong together. Motion helps explain the connection while your work stays local.';
    final shown = sample.characters.take(4000).join();
    return OrbitDialog(
      maxWidth: 960,
      title: Text(widget.text == null ? 'Motion studio' : 'Text presentation'),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.onChanged == null
                    ? 'Preview controls only; your note and saved preferences are unchanged.'
                    : 'Choose a motion personality. Every effect respects Normal, Reduced and Off.',
                style: TextStyle(color: colors.subtle),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: prefs.profile,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Motion personality',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'fluid',
                    child: Text('Fluid · precise and quiet'),
                  ),
                  DropdownMenuItem(
                    value: 'paper',
                    child: Text('Paper & Ink · tactile'),
                  ),
                  DropdownMenuItem(
                    value: 'experimental',
                    child: Text('Experimental · expressive'),
                  ),
                ],
                onChanged: (v) => change({'profile': v}),
              ),
              const SizedBox(height: 12),
              Text('Playback speed · ${prefs.speed.toStringAsFixed(2)}×'),
              Slider(
                value: prefs.speed,
                min: .5,
                max: 2,
                divisions: 6,
                label: '${prefs.speed}×',
                onChanged: (v) => change({'speed': v}),
              ),
              if (widget.onChanged != null)
                ExpansionTile(
                  key: const ValueKey('motion-advanced-controls'),
                  title: const Text('Interaction & reading controls'),
                  subtitle: const Text('Categories, focus and PDF options'),
                  tilePadding: EdgeInsets.zero,
                  expansionAnimationStyle: AnimationStyle(
                    duration: OrbitMotionScope.duration(
                      context,
                      OrbitMotion.panel,
                      spatial: true,
                    ),
                  ),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (key, label) in [
                          ('navigation', 'Navigation & surfaces'),
                          ('editing', 'Editing feedback'),
                          ('drawing', 'Drawing feedback'),
                          ('reading', 'PDF navigation'),
                          ('smart', 'Review feedback'),
                        ])
                          FilterChip(
                            label: Text(label),
                            selected: prefs.enabled(key),
                            onSelected: (v) => change({key: v}),
                          ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Focus typing'),
                      subtitle: const Text(
                        'Gently dim inactive paragraphs; never hide selected text.',
                      ),
                      value: prefs.focusTyping,
                      onChanged: (v) => change({'focusTyping': v}),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reading spotlight'),
                      subtitle: const Text(
                        'Emphasize the selected PDF annotation.',
                      ),
                      value: prefs.readingSpotlight,
                      onChanged: (v) => change({'readingSpotlight': v}),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Optional PDF progress'),
                      subtitle: const Text(
                        'Page position feedback. Disabled by default.',
                      ),
                      value: prefs.readingProgress,
                      onChanged: (v) => change({'readingProgress': v}),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: prefs.pageStyle,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'PDF page transition',
                      ),
                      items: [
                        for (final s in MotionPreferences.pageStyles)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => change({'pageStyle': v}),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                selected.title,
                key: previewKey,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Concept preview · no model or recognition job is running.',
                style: TextStyle(color: colors.subtle, fontSize: 12),
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.workspace,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: OrbitMotionScope(
                  preference: OrbitMotionScope.isOff(context)
                      ? 'off'
                      : OrbitMotionScope.isReduced(context)
                      ? 'reduced'
                      : 'normal',
                  osReduced: OrbitMotionScope.isReduced(context),
                  options: options,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: AnimatedBuilder(
                      animation: player,
                      builder: (context, _) {
                        if (selected.family == MotionFamily.drawing ||
                            selected.style == 'constellation' ||
                            selected.style == 'diagram') {
                          return SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: OrbitMotionSketch(
                              progress: player.value,
                              style: selected.style,
                            ),
                          );
                        }
                        return OrbitEffect(
                          trigger: replay,
                          paused: paused,
                          style: selected.style,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 160),
                            child: OrbitTextReplay(
                              text: shown,
                              style:
                                  MotionPreferences.textStyles.contains(
                                    selected.style,
                                  )
                                  ? selected.style
                                  : 'none',
                              replay: replay,
                              paused: paused,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (sample.characters.length > 4000)
                const Text(
                  'Preview shows the first 4,000 characters. The complete source stays in the editor.',
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: play,
                    icon: const Icon(Icons.replay),
                    label: const Text('Replay'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => paused = !paused);
                      if (paused) {
                        player.stop();
                      } else {
                        player.forward();
                      }
                    },
                    icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                    label: Text(paused ? 'Resume' : 'Pause'),
                  ),
                  if (widget.onChanged != null &&
                      MotionPreferences.textStyles.contains(selected.style))
                    TextButton(
                      onPressed: () => change({'textStyle': selected.style}),
                      child: const Text('Use for text presentations'),
                    ),
                ],
              ),
              if (widget.onChanged != null)
                TextButton(
                  onPressed: () => change(MotionPreferences.quietDefaults),
                  child: const Text('Restore quiet motion defaults'),
                ),
              const SizedBox(height: 20),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Search animation ideas',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Clear animation search',
                    onPressed: () {
                      search.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: family == null,
                    onSelected: (_) => setState(() => family = null),
                  ),
                  for (final f in MotionFamily.values)
                    ChoiceChip(
                      label: Text(f.name),
                      selected: family == f,
                      onSelected: (_) => setState(() => family = f),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${matches.length} of ${motionInspirations.length} ideas'),
              SizedBox(
                height: 200,
                child: matches.isEmpty
                    ? const Center(
                        child: Text(
                          'No animations match. Clear the search or change the category.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, i) {
                          final e = matches[i];
                          return ListTile(
                            dense: true,
                            selected: selected.id == e.id,
                            title: Text(e.title),
                            subtitle: Text(e.family.name),
                            trailing: const Icon(Icons.play_circle_outline),
                            onTap: () {
                              setState(() => selected = e);
                              play();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted ||
                                    previewKey.currentContext == null) {
                                  return;
                                }
                                Scrollable.ensureVisible(
                                  previewKey.currentContext!,
                                  duration: OrbitMotionScope.duration(
                                    context,
                                    OrbitMotion.panel,
                                    spatial: true,
                                  ),
                                  alignment: .1,
                                );
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
