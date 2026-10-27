import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_draft_guard.dart';
import '../../canvas/scene.dart';
import '../../canvas/brainstorm.dart';

class WorkshopDialog extends StatefulWidget {
  const WorkshopDialog({
    super.key,
    required this.notes,
    required this.onLocate,
    this.canSave,
  });
  final List<CanvasElement> notes;
  final ValueChanged<String> onLocate;
  final bool Function()? canSave;
  @override
  State<WorkshopDialog> createState() => _WorkshopDialogState();
}

class _WorkshopDialogState extends State<WorkshopDialog> {
  bool ranked = false;
  String? saveError;
  late final scores = {for (final e in widget.notes) e.id: brainstormVotes(e)};
  void changeScore(String id, int delta) => setState(() {
    scores[id] = (scores[id]! + delta).clamp(0, 999);
  });
  @override
  Widget build(BuildContext context) {
    final ordered = [...widget.notes];
    if (ranked) {
      ordered.sort((a, b) {
        final result = scores[b.id]!.compareTo(scores[a.id]!);
        return result != 0 ? result : a.id.compareTo(b.id);
      });
    }
    final indices = {
      for (final (index, note) in ordered.indexed) note.id: index,
    };
    return OrbitDraftGuard(
      dirty: widget.notes.any((e) => scores[e.id] != brainstormVotes(e)),
      builder: (context, requestClose) => OrbitDialog(
        title: const Text('Workshop tools'),
        contentSlivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Run the timer on this device. Add votes on behalf of your group and save the tally when finished. The timer stops when this panel closes.',
                ),
                const SizedBox(height: 12),
                const _WorkshopCountdown(),
                const Divider(),
                if (saveError != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      saveError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show highest votes first'),
                  value: ranked,
                  onChanged: (v) => setState(() => ranked = v),
                ),
                Text(
                  '${widget.notes.length} editable sticky notes · save all changed tallies as one Undo step.',
                ),
                if (widget.notes.isEmpty)
                  const Text(
                    'Add sticky notes or select ungrouped, unlocked notes to prioritize.',
                  ),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final note = ordered[i], score = scores[note.id]!;
                return Padding(
                  key: ValueKey(note.id),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: () => widget.onLocate(note.id),
                        child: Text(
                          note.text.isEmpty ? 'Untitled idea' : note.text,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.start,
                        ),
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Remove vote from idea ${i + 1}',
                            onPressed: score == 0
                                ? null
                                : () => changeScore(note.id, -1),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$score ${score == 1 ? 'vote' : 'votes'}'),
                          IconButton(
                            tooltip: 'Add vote to idea ${i + 1}',
                            onPressed: score >= 999
                                ? null
                                : () => changeScore(note.id, 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              childCount: ordered.length,
              findChildIndexCallback: (key) =>
                  key is ValueKey<String> ? indices[key.value] : null,
            ),
          ),
        ],
        actions: [
          TextButton(onPressed: requestClose, child: const Text('Close')),
          FilledButton(
            onPressed: () {
              if (widget.canSave?.call() == false) {
                setState(
                  () => saveError =
                      'The board changed. Your tally is still here; close and reopen this panel before applying changes.',
                );
                return;
              }
              Navigator.pop(context, {
                for (final e in widget.notes)
                  if (scores[e.id] != brainstormVotes(e)) e.id: scores[e.id]!,
              });
            },
            child: const Text('Save vote tallies'),
          ),
        ],
      ),
    );
  }
}

class _WorkshopCountdown extends StatefulWidget {
  const _WorkshopCountdown();
  @override
  State<_WorkshopCountdown> createState() => _WorkshopCountdownState();
}

class _WorkshopCountdownState extends State<_WorkshopCountdown> {
  final watch = Stopwatch();
  Timer? tick;
  int minutes = 5;
  Duration remaining = const Duration(minutes: 5);
  Duration get left => remaining - watch.elapsed;
  void pause() {
    remaining = left.isNegative ? Duration.zero : left;
    watch
      ..stop()
      ..reset();
    tick?.cancel();
  }

  void start() {
    if (watch.isRunning) return;
    if (remaining == Duration.zero) remaining = Duration(minutes: minutes);
    watch.start();
    tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (left <= Duration.zero) pause();
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  @override
  void dispose() {
    tick?.cancel();
    watch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final milliseconds = left.inMilliseconds.clamp(0, 86400000);
    final seconds = (milliseconds + 999) ~/ 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Semantics(
            liveRegion: seconds == 0,
            child: Text(
              seconds == 0
                  ? "Time's up"
                  : '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in [1, 3, 5, 10, 15, 25, 45])
              ChoiceChip(
                label: Text('${n}m'),
                selected: minutes == n,
                onSelected: watch.isRunning
                    ? null
                    : (_) => setState(() {
                        minutes = n;
                        remaining = Duration(minutes: n);
                      }),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: watch.isRunning ? () => setState(pause) : start,
              child: Text(watch.isRunning ? 'Pause timer' : 'Start timer'),
            ),
            TextButton(
              onPressed: () => setState(() {
                pause();
                remaining = Duration(minutes: minutes);
              }),
              child: const Text('Reset timer'),
            ),
          ],
        ),
      ],
    );
  }
}
