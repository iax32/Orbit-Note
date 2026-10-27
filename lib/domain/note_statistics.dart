import 'universal_object.dart';

final _statistics = Expando<String>();

/// Immutable snapshots let view/presence updates reuse counts without retaining
/// whole old notes. Real edits create a new snapshot and invalidate the cache.
String noteStatistics(UniversalObject note) => _statistics[note] ??= () {
  final body = note.body;
  if (note.properties['documentFormat'] == 'latex') {
    return 'LaTeX document · ${body.length} characters';
  }
  final words = RegExp(r'\S+').allMatches(body).length;
  return '$words ${words == 1 ? 'word' : 'words'} · '
      '${body.length} ${body.length == 1 ? 'character' : 'characters'} · '
      '${(words / 200).ceil()} min read';
}();
