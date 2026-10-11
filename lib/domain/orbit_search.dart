import '../canvas/canvas_search.dart';
import '../canvas/scene.dart';
import 'document_anchors.dart';
import 'object_discovery.dart';
import 'object_reference.dart';
import 'search_text.dart';
import 'universal_object.dart';

class OrbitSearchResult {
  const OrbitSearchResult({
    required this.object,
    required this.location,
    required this.matchKind,
    required this.matchedText,
    required this.score,
    this.sourceOffset,
    this.matchLength = 0,
    this.sourceChecksum,
    this.sourcePath,
    this.excerptOffset,
    this.excerptLength,
    this.sourceRegions = const [],
  });
  final UniversalObject object;
  final ObjectReference location;
  final String matchKind, matchedText;
  final int score;
  // Ephemeral source navigation; only valid against this object's body revision.
  final int? sourceOffset;
  final int matchLength;
  final String? sourceChecksum, sourcePath;
  final List<Map<String, double>> sourceRegions;

  /// Display range in an extracted excerpt; source navigation uses its own range.
  final int? excerptOffset, excerptLength;
  String get context => objectContextLabel(object);
}

/// Deterministic, provider-neutral ranking over index candidates and live drafts.
/// FTS remains the accelerator; this projection never becomes canonical data.
class OrbitSearchCoordinator {
  const OrbitSearchCoordinator();

  List<OrbitSearchResult> project(
    Iterable<UniversalObject> candidates,
    String query, {
    Map<String, UniversalObject> objects = const {},
    List<String> recent = const [],
    String? project,
    int? limit = 100,
    List<OrbitSearchResult> additional = const [],
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final results = <OrbitSearchResult>[...additional];
    for (final object in candidates) {
      if (object.isDeleted) continue;
      final before = results.length;
      final nameRank = quickOpenRank(object, q);
      if (nameRank != null && nameRank <= 4) {
        results.add(
          OrbitSearchResult(
            object: object,
            location: ObjectReference(object.id),
            matchKind: nameRank <= 3 ? 'Name' : 'Context',
            matchedText: object.title,
            score: nameRank * 10,
          ),
        );
      }
      if (object.typeId == 'orbit.canvas') {
        final scene = CanvasScene.fromJson(object.data);
        for (final match in searchCanvasElements(
          scene: scene,
          objectLookup: MapCanvasObjectLookup(objects),
          query: q,
        )) {
          results.add(
            OrbitSearchResult(
              object: object,
              location: ObjectReference(
                object.id,
                anchorType: 'element',
                anchorId: match.elementId,
              ),
              matchKind:
                  'Canvas ${match.elementType.isEmpty ? 'element' : match.elementType}',
              matchedText: match.snippet,
              score: 55,
            ),
          );
        }
      } else if (object.body.isNotEmpty) {
        final latex = object.properties['documentFormat'] == 'latex';
        final fragments = documentFragments(object.body, latex: latex);
        var matched = false;
        for (final fragment in fragments) {
          final at = fragment.text.toLowerCase().indexOf(q);
          if (at < 0) continue;
          matched = true;
          final location = fragment.blockId != null
              ? ObjectReference(
                  object.id,
                  anchorType: 'block',
                  anchorId: fragment.blockId,
                )
              : fragment.label != null
              ? ObjectReference(
                  object.id,
                  anchorType: 'label',
                  anchorId: fragment.label,
                )
              : fragment.heading != null
              ? ObjectReference(
                  object.id,
                  anchorType: 'heading',
                  anchorId: fragment.heading,
                )
              : ObjectReference(object.id);
          final absolute = fragment.start + at;
          final start = (absolute - 45).clamp(0, object.body.length);
          final end = (absolute + q.length + 65).clamp(
            start,
            object.body.length,
          );
          results.add(
            OrbitSearchResult(
              object: object,
              location: location,
              matchKind: fragment.heading != null
                  ? 'Heading'
                  : latex
                  ? 'LaTeX source'
                  : 'Paragraph',
              matchedText: object.body
                  .substring(start, end)
                  .replaceAll(RegExp(r'\s+'), ' '),
              score: fragment.heading != null ? 45 : 60,
              sourceOffset: absolute,
              matchLength: q.length,
            ),
          );
        }
        // Raw source/code stays searchable without pretending it has a stable anchor.
        if (!matched) {
          final at = object.body.toLowerCase().indexOf(q);
          if (at >= 0) {
            results.add(
              OrbitSearchResult(
                object: object,
                location: ObjectReference(object.id),
                matchKind: 'Source',
                matchedText: extractSearchSnippet(object, q)?.text ?? q,
                score: 65,
                sourceOffset: at,
                matchLength: q.length,
              ),
            );
          }
        }
      }
      if (results.length == before) {
        final snippet = extractSearchSnippet(object, q);
        if (snippet != null) {
          results.add(
            OrbitSearchResult(
              object: object,
              location: ObjectReference(object.id),
              matchKind: 'Property',
              matchedText: snippet.text,
              score: 70,
            ),
          );
        }
      }
    }
    results.sort((a, b) {
      var order = a.score.compareTo(b.score);
      if (order != 0) return order;
      if (project != null) {
        order = (b.object.properties['project'] == project ? 1 : 0).compareTo(
          a.object.properties['project'] == project ? 1 : 0,
        );
        if (order != 0) return order;
      }
      final ar = recent.indexOf(a.object.id), br = recent.indexOf(b.object.id);
      order = (ar < 0 ? recent.length : ar).compareTo(
        br < 0 ? recent.length : br,
      );
      if (order != 0) return order;
      order = a.object.title.toLowerCase().compareTo(
        b.object.title.toLowerCase(),
      );
      if (order != 0) return order;
      order = a.object.id.compareTo(b.object.id);
      if (order != 0) return order;
      return (a.sourceOffset ?? 0).compareTo(b.sourceOffset ?? 0) != 0
          ? (a.sourceOffset ?? 0).compareTo(b.sourceOffset ?? 0)
          : a.location.target.compareTo(b.location.target);
    });
    return limit == null ? results : results.take(limit).toList();
  }
}
