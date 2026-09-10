import 'dart:convert';
import 'universal_object.dart';

String searchableText(UniversalObject object) => [
  object.title,
  object.body,
  jsonEncode(object.properties),
  if (object.data['elements'] is List)
    for (final element in object.data['elements'] as List)
      if (element is Map && element['text'] is String)
        element['text'] as String,
].join('\n');

int searchRank(UniversalObject object, String query) {
  final title = object.title.toLowerCase(), term = query.toLowerCase();
  return title == term
      ? 0
      : title.startsWith(term)
      ? 1
      : title.contains(term)
      ? 2
      : 3;
}
