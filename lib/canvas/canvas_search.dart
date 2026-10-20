import 'geometry.dart';
import 'scene.dart';
import 'uml.dart';
import '../domain/object_reference.dart';
import '../domain/document_anchors.dart';

enum CanvasSearchCategory { all, cards, text, shapes, media }

class CanvasSearchResult {
  const CanvasSearchResult({
    required this.elementId,
    required this.elementType,
    required this.title,
    required this.snippet,
    required this.bounds,
    this.category = CanvasSearchCategory.all,
  });

  final String elementId;
  final String elementType;
  final String title;
  final String snippet;
  final CanvasBounds bounds;
  final CanvasSearchCategory category;

  @override
  String toString() =>
      'CanvasSearchResult($elementId, $elementType, "$title", "$snippet")';
}

/// Interface for looking up referenced objects on cards.
abstract class CanvasObjectLookup {
  String? getTitle(String objectId);
  String? getBody(String objectId);
  List<String> getTags(String objectId);
  String? getProject(String objectId);
  String? getFolder(String objectId);
  String? getStatus(String objectId);
  String? getPriority(String objectId);
}

/// A simple map-backed implementation of [CanvasObjectLookup].
class MapCanvasObjectLookup implements CanvasObjectLookup {
  const MapCanvasObjectLookup(this.objects);

  final Map<String, dynamic> objects;

  dynamic _get(String objectId) => objects[objectId];

  @override
  String? getTitle(String objectId) {
    final obj = _get(objectId);
    if (obj == null) return null;
    try {
      return obj.title as String?;
    } catch (_) {
      if (obj is Map) return obj['title'] as String?;
      return null;
    }
  }

  @override
  String? getBody(String objectId) {
    final obj = _get(objectId);
    if (obj == null) return null;
    try {
      return obj.body as String?;
    } catch (_) {
      if (obj is Map) return obj['body'] as String?;
      return null;
    }
  }

  @override
  List<String> getTags(String objectId) {
    final obj = _get(objectId);
    if (obj == null) return const [];
    try {
      final t = obj.tags;
      if (t is List) return t.map((e) => e.toString()).toList();
      return const [];
    } catch (_) {
      if (obj is Map && obj['tags'] is List) {
        return (obj['tags'] as List).map((e) => e.toString()).toList();
      }
      return const [];
    }
  }

  @override
  String? getProject(String objectId) {
    final obj = _get(objectId);
    if (obj == null) return null;
    try {
      return obj.project as String?;
    } catch (_) {
      if (obj is Map) return obj['project'] as String?;
      return null;
    }
  }

  @override
  String? getFolder(String objectId) {
    final obj = _get(objectId);
    if (obj == null) return null;
    try {
      return obj.folder as String?;
    } catch (_) {
      if (obj is Map) return obj['folder'] as String?;
      return null;
    }
  }

  @override
  String? getStatus(String objectId) {
    final obj = _get(objectId);
    if (obj == null) return null;
    try {
      final p = obj.properties;
      if (p is Map) return p['status'] as String?;
      return null;
    } catch (_) {
      if (obj is Map) return obj['status'] as String?;
      return null;
    }
  }

  @override
  String? getPriority(String objectId) {
    final obj = _get(objectId);
    if (obj == null) return null;
    try {
      final p = obj.properties;
      if (p is Map) return p['priority'] as String?;
      return null;
    } catch (_) {
      if (obj is Map) return obj['priority'] as String?;
      return null;
    }
  }
}

/// Pure-Dart search function scanning [scene] elements for [query].
List<CanvasSearchResult> searchCanvasElements({
  required CanvasScene scene,
  required CanvasObjectLookup objectLookup,
  required String query,
  CanvasSearchCategory category = CanvasSearchCategory.all,
}) {
  final cleanQuery = query.trim().toLowerCase();
  if (cleanQuery.isEmpty) return const [];

  // Sort elements in top-to-bottom, left-to-right reading order
  final sortedElements = List<CanvasElement>.from(scene.elements)
    ..sort((a, b) {
      final cmpY = a.y.compareTo(b.y);
      if (cmpY != 0) return cmpY;
      return a.x.compareTo(b.x);
    });

  final results = <CanvasSearchResult>[];

  for (final element in sortedElements) {
    if (element.hidden) continue;

    final elementCategory = _classifyElement(element);

    // Apply category filter
    if (category != CanvasSearchCategory.all && category != elementCategory) {
      continue;
    }

    final match = _evaluateElementMatch(
      element: element,
      category: elementCategory,
      query: cleanQuery,
      objectLookup: objectLookup,
    );

    if (match != null) {
      results.add(match);
    }
  }

  return results;
}

CanvasSearchCategory _classifyElement(CanvasElement element) {
  switch (element.type) {
    case 'card':
      return CanvasSearchCategory.cards;
    case 'text':
    case 'sticky':
    case 'frame':
    case 'column':
      return CanvasSearchCategory.text;
    case 'rectangle':
    case 'ellipse':
    case 'diamond':
    case 'arrow':
    case 'line':
    case 'connector':
      return CanvasSearchCategory.shapes;
    case 'image':
    case 'link':
    case 'swatch':
      return CanvasSearchCategory.media;
    default:
      if (element.objectId != null) {
        return CanvasSearchCategory.cards;
      }
      return CanvasSearchCategory.text;
  }
}

CanvasSearchResult? _evaluateElementMatch({
  required CanvasElement element,
  required CanvasSearchCategory category,
  required String query,
  required CanvasObjectLookup objectLookup,
}) {
  String? matchedTitle;
  String? matchedSnippet;

  // 1. Check direct element text/url/label fields
  final directText = isUmlClass(element)
      ? UmlClass(element).searchableText
      : [
          element.text,
          for (final key in [
            'startMultiplicity',
            'endMultiplicity',
            'startRole',
            'endRole',
          ])
            if (element.data[key] is String) element.data[key] as String,
        ].join('\n');
  if (directText.isNotEmpty && directText.toLowerCase().contains(query)) {
    matchedTitle = _defaultTitleForElement(element);
    matchedSnippet = _extractSnippet(directText, query);
  }

  if (matchedTitle == null && element.url.isNotEmpty) {
    if (element.url.toLowerCase().contains(query)) {
      matchedTitle = element.data['title']?.toString() ?? 'Link';
      matchedSnippet = element.url;
    }
  }

  // Check data['label'] or data['title'] or data['description']
  if (matchedTitle == null) {
    final details =
        [
              'referenceCaption',
              'referenceSourceUrl',
              'referenceStatus',
              'referenceTags',
            ]
            .map((key) {
              final value = element.data[key];
              return value is List
                  ? value.whereType<String>().join(' ')
                  : (value is String ? value : '');
            })
            .join('\n');
    if (details.toLowerCase().contains(query)) {
      matchedTitle = _defaultTitleForElement(element);
      matchedSnippet = _extractSnippet(details, query);
    }
  }
  if (matchedTitle == null) {
    final label = element.data['label']?.toString();
    if (label != null && label.toLowerCase().contains(query)) {
      matchedTitle = 'Connector: $label';
      matchedSnippet = label;
    }
  }

  if (matchedTitle == null) {
    final title = element.data['title']?.toString();
    if (title != null && title.toLowerCase().contains(query)) {
      matchedTitle = title;
      matchedSnippet = title;
    }
  }

  if (matchedTitle == null) {
    final desc = element.data['description']?.toString();
    if (desc != null && desc.toLowerCase().contains(query)) {
      matchedTitle = _defaultTitleForElement(element);
      matchedSnippet = _extractSnippet(desc, query);
    }
  }

  // Check recognized ink text
  if (matchedTitle == null) {
    final ocr = element.data['recognizedText']?.toString();
    if (ocr != null && ocr.toLowerCase().contains(query)) {
      matchedTitle = 'Ink Stroke';
      matchedSnippet = _extractSnippet(ocr, query);
    }
  }

  // 2. If it is a card referencing an object, check the referenced object
  if (element.objectId != null) {
    final objectId = element.objectId!;
    final objTitle = objectLookup.getTitle(objectId) ?? '';
    var objBody = objectLookup.getBody(objectId) ?? '';
    final precise = element.data['referenceTarget'];
    if (precise is String) {
      final reference = ObjectReference.parse(precise);
      objBody = reference.id == objectId
          ? resolveDocumentFragment(
                  objBody,
                  reference,
                  latex: reference.anchorType == 'label',
                )?.text ??
                ''
          : '';
    }
    final tags = objectLookup.getTags(objectId);
    final project = objectLookup.getProject(objectId) ?? '';
    final folder = objectLookup.getFolder(objectId) ?? '';
    final status = objectLookup.getStatus(objectId) ?? '';
    final priority = objectLookup.getPriority(objectId) ?? '';

    if (objTitle.isNotEmpty && objTitle.toLowerCase().contains(query)) {
      matchedTitle = objTitle;
      matchedSnippet = objBody.isNotEmpty
          ? _extractSnippet(objBody, query)
          : 'Title match';
    } else if (objBody.isNotEmpty && objBody.toLowerCase().contains(query)) {
      matchedTitle = objTitle.isNotEmpty ? objTitle : 'Referenced Note';
      matchedSnippet = _extractSnippet(objBody, query);
    } else {
      // Check tags
      for (final tag in tags) {
        if (tag.toLowerCase().contains(query)) {
          matchedTitle = objTitle.isNotEmpty ? objTitle : 'Referenced Card';
          matchedSnippet = 'Tag: #$tag';
          break;
        }
      }
      // Check project / folder / status
      if (matchedTitle == null) {
        if (project.isNotEmpty && project.toLowerCase().contains(query)) {
          matchedTitle = objTitle.isNotEmpty ? objTitle : 'Card';
          matchedSnippet = 'Project: $project';
        } else if (folder.isNotEmpty && folder.toLowerCase().contains(query)) {
          matchedTitle = objTitle.isNotEmpty ? objTitle : 'Card';
          matchedSnippet = 'Folder: $folder';
        } else if (status.isNotEmpty && status.toLowerCase().contains(query)) {
          matchedTitle = objTitle.isNotEmpty ? objTitle : 'Card';
          matchedSnippet = 'Status: $status';
        } else if (priority.isNotEmpty &&
            priority.toLowerCase().contains(query)) {
          matchedTitle = objTitle.isNotEmpty ? objTitle : 'Card';
          matchedSnippet = 'Priority: $priority';
        }
      }
    }
  }

  if (matchedTitle == null) return null;

  return CanvasSearchResult(
    elementId: element.id,
    elementType: element.type,
    title: matchedTitle,
    snippet: matchedSnippet ?? matchedTitle,
    bounds: element.bounds,
    category: category,
  );
}

String _defaultTitleForElement(CanvasElement element) {
  if (isUmlClass(element)) {
    return element.text.isEmpty ? 'UML class' : element.text;
  }
  switch (element.type) {
    case 'sticky':
      final firstLine = element.text.trim().split('\n').first;
      return firstLine.isNotEmpty
          ? (firstLine.length > 28
                ? '${firstLine.substring(0, 28)}…'
                : firstLine)
          : 'Sticky Note';
    case 'text':
      final firstLine = element.text.trim().split('\n').first;
      return firstLine.isNotEmpty
          ? (firstLine.length > 28
                ? '${firstLine.substring(0, 28)}…'
                : firstLine)
          : 'Text';
    case 'frame':
      return element.text.isNotEmpty ? element.text : 'Frame';
    case 'column':
      return element.text.isNotEmpty ? element.text : 'Column';
    case 'rectangle':
      return 'Rectangle';
    case 'ellipse':
      return 'Ellipse';
    case 'diamond':
      return 'Diamond';
    case 'arrow':
      return 'Arrow';
    case 'line':
      return 'Line';
    case 'connector':
      return 'Connector';
    case 'image':
      return 'Image';
    case 'link':
      return 'Link';
    default:
      if (element.type.isEmpty) return 'Element';
      return element.type[0].toUpperCase() + element.type.substring(1);
  }
}

String _extractSnippet(String text, String query) {
  final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final lower = clean.toLowerCase();
  final idx = lower.indexOf(query);
  if (idx < 0) return clean.length > 60 ? '${clean.substring(0, 60)}…' : clean;

  final start = (idx - 20).clamp(0, clean.length);
  final end = (idx + query.length + 35).clamp(0, clean.length);

  var snippet = clean.substring(start, end);
  if (start > 0) snippet = '…$snippet';
  if (end < clean.length) snippet = '$snippet…';
  return snippet;
}
