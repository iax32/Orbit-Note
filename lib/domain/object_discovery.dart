import 'universal_object.dart';

/// Shared user-facing vocabulary for discovery surfaces. Storage type IDs stay
/// unchanged; a LaTeX document is still the same note object.
String objectKindLabel(UniversalObject object) {
  if (object.typeId == 'orbit.note' &&
      object.properties['documentFormat'] == 'latex') {
    return 'LaTeX document';
  }
  if (object.typeId == 'orbit.file' &&
      (object.properties['mimeType'] == 'application/pdf' ||
          object.title.toLowerCase().endsWith('.pdf'))) {
    return 'PDF';
  }
  return switch (object.typeId) {
    'orbit.note' => 'Note',
    'orbit.canvas' => 'Canvas',
    'orbit.task' => 'Task',
    'orbit.event' => 'Event',
    'orbit.project' => 'Project',
    'orbit.view' => 'View',
    'orbit.collection' => 'Collection',
    'orbit.file' => 'File',
    'orbit.person' => 'Person',
    _ => object.typeId.split('.').last,
  };
}

String objectContextLabel(UniversalObject object) => {
  objectKindLabel(object),
  for (final key in ['project', 'folder'])
    if (object.properties[key] is String &&
        (object.properties[key] as String).trim().isNotEmpty)
      (object.properties[key] as String).trim(),
}.join(' · ');

/// Quick opening deliberately searches names/context, not every document body.
/// Exact and prefix matches outrank token and fuzzy title matches.
int? quickOpenRank(UniversalObject object, String query) {
  if (object.isDeleted) return null;
  final q = query.trim().toLowerCase();
  final title = object.title.toLowerCase();
  if (q.isEmpty || title == q) return 0;
  final aliases = object.properties['aliases'];
  final names = [
    title,
    if (aliases is List)
      ...aliases.whereType<String>().map((a) => a.toLowerCase()),
  ];
  if (names.any((name) => name == q)) return 1;
  if (names.any((name) => name.startsWith(q))) return 2;
  if (names.any((name) => name.contains(q))) return 3;
  final context = [
    ...names,
    objectContextLabel(object),
    if (object.properties['tags'] is List)
      ...(object.properties['tags'] as List).whereType<String>(),
  ].join(' ').toLowerCase();
  if (q.split(RegExp(r'\s+')).every(context.contains)) return 4;
  if (q.length >= 2 && !q.contains(' ')) {
    for (final name in names) {
      var position = 0;
      for (final rune in q.runes) {
        final found = name.indexOf(String.fromCharCode(rune), position);
        if (found < 0) {
          position = -1;
          break;
        }
        position = found + String.fromCharCode(rune).length;
      }
      if (position >= 0) return 5;
    }
  }
  return null;
}
