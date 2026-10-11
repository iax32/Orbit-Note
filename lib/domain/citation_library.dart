import 'document_citations.dart';

class CitationLibrary {
  const CitationLibrary(this.id, this.title, this.source);
  final String id, title, source;
}

enum CitationImportPolicy { keepExisting, renameIncoming, replaceExisting }

class CitationImportPlan {
  CitationImportPlan(
    String source,
    List<Map<String, dynamic>> records,
    CitationImportPolicy policy,
  ) {
    final model = DocumentCitations(source);
    final active = {...model.sources};
    final updates = <String, Map<String, dynamic>>{};
    final seen = <String>{};
    for (final record in records) {
      final incoming = CitationSource.fromJson(record);
      if (!seen.add(incoming.id)) {
        throw FormatException(
          'Duplicate incoming key: ${incoming.id}. Import one record at a time or repair the file.',
        );
      }
      if (model.duplicates.contains(incoming.id)) {
        throw FormatException(
          'Ambiguous existing key: ${incoming.id}. Repair it before importing.',
        );
      }
      final existing = active[incoming.id];
      final doiMatches = normalizeDoi(incoming.doi).isEmpty
          ? <CitationSource>[]
          : active.values
                .where((s) => normalizeDoi(s.doi) == normalizeDoi(incoming.doi))
                .toList();
      if (doiMatches.length > 1 ||
          (existing != null &&
              doiMatches.isNotEmpty &&
              doiMatches.first.id != existing.id)) {
        throw FormatException(
          'Ambiguous identifier/DOI for ${incoming.id}. Repair the conflicting records before importing.',
        );
      }
      final doiMatch = normalizeDoi(incoming.doi).isEmpty
          ? null
          : active.values
                .where((s) => normalizeDoi(s.doi) == normalizeDoi(incoming.doi))
                .firstOrNull;
      if (existing != null || doiMatch != null) {
        final conflict = existing ?? doiMatch!;
        conflicts.add(
          '${incoming.id} matches ${conflict.id}${doiMatch == null ? ' by identifier' : ' by identifier or DOI'}.',
        );
        if (policy == CitationImportPolicy.keepExisting) {
          skipped++;
          continue;
        }
        if (policy == CitationImportPolicy.replaceExisting) {
          final replacement = {
            ...model.record(conflict.id),
            ...?updates[conflict.id],
            ...record,
            'id': conflict.id,
          };
          updates[conflict.id] = replacement;
          active[conflict.id] = CitationSource.fromJson(replacement);
          replaced++;
          continue;
        }
        var suffix = 2;
        final base = incoming.id.length > 70
            ? incoming.id.substring(0, 70)
            : incoming.id;
        var key = '$base-$suffix';
        while (active.containsKey(key)) {
          suffix++;
          key = '$base-$suffix';
        }
        updates[key] = {...record, 'id': key};
        active[key] = CitationSource.fromJson(updates[key]!);
      } else {
        updates[incoming.id] = record;
        active[incoming.id] = incoming;
      }
      added++;
    }
    result = DocumentCitations(
      model.saveRecords(updates.values.toList()),
    ).refresh(addBibliography: false);
  }
  late final String result;
  int added = 0, replaced = 0, skipped = 0;
  final conflicts = <String>[];
}

String normalizeDoi(String doi) => doi.trim().toLowerCase().replaceFirst(
  RegExp(r'^(?:https?://(?:dx\.)?doi\.org/|doi:\s*)'),
  '',
);

String sourceLibraryBody(DocumentCitations sources) {
  if (sources.duplicates.isNotEmpty) {
    throw const FormatException(
      'Repair duplicate source identifiers before creating a library.',
    );
  }
  var body =
      '# Source library\n\nManage these sources through Writing tools → Citations & bibliography.\n';
  return DocumentCitations(body).saveRecords([
    for (final source in sources.sources.values) sources.record(source.id),
  ]);
}
