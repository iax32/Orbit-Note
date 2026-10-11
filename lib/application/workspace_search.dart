import '../domain/universal_object.dart';
import '../domain/object_discovery.dart';
import '../domain/orbit_search.dart';
import 'search_execution.dart';
import '../domain/pdf_search.dart';

/// Owns candidate/draft merging and background projection. The controller stays
/// the UI facade; this service receives immutable snapshots and no UI state.
Future<List<OrbitSearchResult>> projectWorkspaceSearch({
  required List<UniversalObject> indexed,
  required List<UniversalObject> snapshot,
  required Set<String> drafts,
  required String query,
  List<String> recent = const [],
  String? project,
  List<OrbitSearchResult> additional = const [],
  Map<String, PdfTextDocument> pdfDocuments = const {},
  int? limit = 100,
}) async {
  final candidates = <String, UniversalObject>{
    for (final object in indexed)
      if (!drafts.contains(object.id)) object.id: object,
    for (final object in snapshot)
      if (drafts.contains(object.id) ||
          object.typeId == 'orbit.canvas' ||
          quickOpenRank(object, query) != null)
        object.id: object,
  }.values.toList();
  final lookup = {for (final object in snapshot) object.id: object};
  return runSearchWork(
    () => const OrbitSearchCoordinator().project(
      candidates,
      query,
      objects: lookup,
      recent: recent,
      project: project,
      additional: [
        ...additional,
        for (final entry in pdfDocuments.entries)
          if (lookup[entry.key] case final object?
              when !object.isDeleted &&
                  object.properties['contentRef'] == entry.value.path)
            ...entry.value.search(object, query),
      ],
      limit: limit,
    ),
    size:
        pdfDocuments.values.fold<int>(
          0,
          (n, d) => n + d.pages.fold<int>(0, (n, p) => n + p.length),
        ) +
        candidates.fold<int>(
          0,
          (size, o) =>
              size +
              o.body.length +
              (o.data['elements'] is List
                  ? (o.data['elements'] as List).length * 256
                  : 256),
        ),
  );
}
