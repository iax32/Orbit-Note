import '../../app/orbit_components.dart';
import '../../app/orbit_motion_effects.dart';
import 'package:flutter/material.dart';
import 'note_find_index.dart';

Future<List<NoteFindMatch>?> showReplacementReview(
  BuildContext context,
  NoteFindIndex index,
  List<NoteFindMatch> matches,
  String replacement,
) async {
  final selected = matches.toSet();
  var page = 0;
  return showOrbitDialog<List<NoteFindMatch>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => Dialog(
        child: SizedBox(
          width: 760,
          height: MediaQuery.sizeOf(context).height * .8,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Review replacements',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${selected.length} of ${matches.length} selected. Changes apply together with undo.',
                    ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () =>
                              update(() => selected.addAll(matches)),
                          child: const Text('Select all'),
                        ),
                        TextButton(
                          onPressed: () => update(selected.clear),
                          child: const Text('Select none'),
                        ),
                      ],
                    ),
                    for (final match in matches.skip(page * 30).take(30))
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: selected.contains(match),
                                onChanged: (value) => update(() {
                                  value == true
                                      ? selected.add(match)
                                      : selected.remove(match);
                                }),
                                title: Text(
                                  'Source position ${match.start + 1}',
                                ),
                              ),
                              _MatchPreview(
                                index: index,
                                match: match,
                                replacement: replacement,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: page > 0 ? () => update(() => page--) : null,
                      child: const Text('Previous'),
                    ),
                    Text('Page ${page + 1} of ${(matches.length / 30).ceil()}'),
                    TextButton(
                      onPressed: (page + 1) * 30 < matches.length
                          ? () => update(() => page++)
                          : null,
                      child: const Text('Next'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () => Navigator.pop(
                              context,
                              matches.where(selected.contains).toList(),
                            ),
                      child: Text('Apply ${selected.length} changes'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MatchPreview extends StatelessWidget {
  const _MatchPreview({
    required this.index,
    required this.match,
    required this.replacement,
  });
  final NoteFindIndex index;
  final NoteFindMatch match;
  final String replacement;
  @override
  Widget build(BuildContext context) {
    final text = index.segmentText(match);
    final start = match.from.clamp(0, text.length),
        end = match.to.clamp(0, text.length);
    int boundary(int offset, {required bool end}) {
      offset = offset.clamp(0, text.length);
      if (offset > 0 &&
          offset < text.length &&
          text.codeUnitAt(offset - 1) >= 0xd800 &&
          text.codeUnitAt(offset - 1) <= 0xdbff &&
          text.codeUnitAt(offset) >= 0xdc00 &&
          text.codeUnitAt(offset) <= 0xdfff) {
        return offset + (end ? 1 : -1);
      }
      return offset;
    }

    final left = text.substring(boundary(start - 100, end: false), start);
    final right = text.substring(end, boundary(end + 100, end: true));
    final theme = Theme.of(context);
    return OrbitEffect(
      trigger: (match.from, match.to, replacement),
      family: 'smart',
      style: 'morph',
      onMount: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Before', style: theme.textTheme.labelMedium),
          SelectableText.rich(
            TextSpan(
              children: [
                TextSpan(text: left),
                TextSpan(
                  text: text.substring(start, end),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    backgroundColor: theme.colorScheme.errorContainer,
                  ),
                ),
                TextSpan(text: right),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('After', style: theme.textTheme.labelMedium),
          SelectableText.rich(
            TextSpan(
              children: [
                TextSpan(text: left),
                TextSpan(
                  text: replacement.isEmpty ? '(delete match)' : replacement,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
                ),
                TextSpan(text: right),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
