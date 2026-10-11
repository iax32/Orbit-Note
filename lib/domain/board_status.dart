/// Resolve known task status aliases to a preset without rewriting stored data.
/// Unknown statuses remain visible in the ungrouped column.
String boardStatus(Object? value, Iterable<String> columns) {
  final keys = columns.toSet();
  final raw =
      value?.toString().trim().toLowerCase().replaceAll(
        RegExp(r'[ _]+'),
        '-',
      ) ??
      '';
  if (keys.contains(raw)) return raw;
  final aliases = switch (raw) {
    'to-do' || 'todo' => ['todo', 'planned', 'ready', 'backlog', 'new'],
    'in-progress' || 'inprogress' || 'doing' => ['in-progress'],
    'in-review' || 'review' => ['review', 'in-review'],
    'complete' || 'completed' || 'closed' => ['done', 'closed'],
    'partially-understood' => ['partial'],
    _ => <String>[],
  };
  return aliases.where(keys.contains).firstOrNull ?? 'none';
}
