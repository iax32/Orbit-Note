import 'dart:convert';
import 'dart:math' as math;
import 'universal_object.dart';

class SearchSnippet {
  final String text;
  final int matchStart;
  final int matchLength;
  final String source; // 'body', 'canvas', 'property'

  const SearchSnippet({
    required this.text,
    required this.matchStart,
    required this.matchLength,
    this.source = 'body',
  });
}

String cleanMarkdownNoise(String raw) => raw
    .replaceAll(RegExp(r'^[#>\s*\-+]+', multiLine: true), '')
    .replaceAll(RegExp(r'[*`_~\[\]]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

SearchSnippet? extractSearchSnippet(
  UniversalObject object,
  String query, {
  int maxRadius = 45,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return null;

  // 1. Search in canvas text elements (if canvas object)
  if (object.typeId == 'orbit.canvas') {
    List? elements;
    if (object.data['elements'] is List) {
      elements = object.data['elements'] as List;
    } else if (object.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(object.body);
        if (decoded is Map && decoded['elements'] is List) {
          elements = decoded['elements'] as List;
        }
      } catch (_) {}
    }
    if (elements != null) {
      for (final element in elements) {
        if (element is Map && element['text'] is String) {
          final text = cleanMarkdownNoise(element['text'] as String);
          final idx = text.toLowerCase().indexOf(q);
          if (idx >= 0) {
            return _window(text, idx, q.length, maxRadius, 'canvas');
          }
        }
      }
    }
  }

  // 2. Search in body (for non-canvas objects, or fallback)
  if (object.typeId != 'orbit.canvas' && object.body.isNotEmpty) {
    final cleaned = cleanMarkdownNoise(object.body);
    final idx = cleaned.toLowerCase().indexOf(q);
    if (idx >= 0) {
      return _window(cleaned, idx, q.length, maxRadius, 'body');
    }
  }

  // Also check canvas data elements if object was not typed orbit.canvas
  if (object.typeId != 'orbit.canvas' && object.data['elements'] is List) {
    for (final element in object.data['elements'] as List) {
      if (element is Map && element['text'] is String) {
        final text = cleanMarkdownNoise(element['text'] as String);
        final idx = text.toLowerCase().indexOf(q);
        if (idx >= 0) {
          return _window(text, idx, q.length, maxRadius, 'canvas');
        }
      }
    }
  }

  // 3. Search in object properties
  if (object.properties.isNotEmpty) {
    for (final entry in object.properties.entries) {
      if (entry.value == null) continue;
      final propVal = entry.value.toString();
      final idx = propVal.toLowerCase().indexOf(q);
      if (idx >= 0) {
        final text = '${entry.key}: $propVal';
        final adjustedIdx = entry.key.length + 2 + idx;
        return _window(text, adjustedIdx, q.length, maxRadius, 'property');
      }
    }
  }

  return null;
}

SearchSnippet _window(
  String fullText,
  int matchIndex,
  int matchLength,
  int radius,
  String source,
) {
  final start = math.max(0, matchIndex - radius);
  final end = math.min(fullText.length, matchIndex + matchLength + radius);

  final prefix = start > 0 ? '…' : '';
  final suffix = end < fullText.length ? '…' : '';

  final snippetPart = fullText.substring(start, end);
  final offsetInSnippet = (start > 0 ? 1 : 0) + (matchIndex - start);

  return SearchSnippet(
    text: '$prefix$snippetPart$suffix',
    matchStart: offsetInSnippet,
    matchLength: matchLength,
    source: source,
  );
}

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
