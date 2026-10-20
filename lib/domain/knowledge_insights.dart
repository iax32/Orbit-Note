import 'universal_object.dart';
import 'object_connections.dart';
import 'object_reference.dart';
import 'wiki_links.dart';
import 'writing_structure.dart';
import 'document_footnotes.dart';

/// Deterministic checks only. An isolated object or repeated title is not an error.
class DocumentFinding {
  const DocumentFinding(this.kind, this.message, this.start, this.end);
  final String kind, message;
  final int start, end;
}

/// Replace one authored mention, keeping its label and exact fragment spelling.
String repairDocumentLink(
  String source,
  DocumentFinding finding,
  String targetId,
) {
  if (targetId.isEmpty || RegExp(r'[\[\]|#\s]').hasMatch(targetId)) {
    throw const FormatException('Choose a valid object identity.');
  }
  final link = parseWikiLinks(
    source,
  ).where((l) => l.start == finding.start && l.end == finding.end).firstOrNull;
  if (finding.kind != 'Links' || link == null) {
    throw const FormatException('The link changed. Run Document Checks again.');
  }
  final fragment = link.target.indexOf('#');
  final target =
      '$targetId${fragment < 0 ? '' : link.target.substring(fragment)}';
  final original = source.substring(link.start + 2, link.end - 2);
  final separator = original.indexOf('|');
  final label = separator < 0 ? link.label : original.substring(separator + 1);
  return source.replaceRange(link.start, link.end, '[[$target|$label]]');
}

/// Index title/alias resolution once for a report, without guessing equal names.
class InsightLinkCatalog {
  InsightLinkCatalog(Iterable<UniversalObject> objects) {
    for (final object in objects.where((o) => !o.isDeleted)) {
      ids.add(object.id);
      final labels = {object.title.trim().toLowerCase()};
      if (object.properties['aliases'] is List) {
        labels.addAll(
          (object.properties['aliases'] as List).whereType<String>().map(
            (s) => s.trim().toLowerCase(),
          ),
        );
      }
      for (final label in labels) {
        names.putIfAbsent(label, () => {}).add(object.id);
      }
    }
  }
  final ids = <String>{};
  final names = <String, Set<String>>{};
  WikiLinkStatus status(WikiLink link, Map<String, String> bindings) {
    final id = ObjectReference.parse(link.target).id;
    if (ids.contains(id)) return WikiLinkStatus.resolved;
    final bound = bindings[link.target] ?? bindings[id];
    if (bound != null) {
      return ids.contains(bound)
          ? WikiLinkStatus.resolved
          : WikiLinkStatus.unresolved;
    }
    final count = names[id.toLowerCase()]?.length ?? 0;
    return count == 1
        ? WikiLinkStatus.resolved
        : count == 0
        ? WikiLinkStatus.unresolved
        : WikiLinkStatus.ambiguous;
  }
}

List<DocumentFinding> checkDocument(
  String source, {
  InsightLinkCatalog? catalog,
  Map<String, String> bindings = const {},
}) {
  final findings = <DocumentFinding>[];
  final literal = writingLiteralRanges(source);
  bool hidden(int offset) =>
      literal.any((r) => offset >= r.$1 && offset < r.$2);
  if (catalog != null) {
    for (final link in parseWikiLinks(source)) {
      if (hidden(link.start)) continue;
      final status = catalog.status(link, bindings);
      if (status != WikiLinkStatus.resolved) {
        findings.add(
          DocumentFinding(
            'Links',
            status == WikiLinkStatus.ambiguous
                ? '“${link.target}” matches several objects. Choose a specific source.'
                : '“${link.target}” has no active source in this Vault.',
            link.start,
            link.end,
          ),
        );
      }
    }
  }
  final footnotes = DocumentFootnotes(source);
  final definitions = <String, int>{};
  final used = footnotes.references.map((r) => r.id).toSet();
  for (final definition in footnotes.definitions) {
    final count = (definitions[definition.id] ?? 0) + 1;
    definitions[definition.id] = count;
    if (count > 1) {
      findings.add(
        DocumentFinding(
          'Footnotes',
          'Duplicate definition [^${definition.id}].',
          definition.start,
          definition.end,
        ),
      );
    }
    if (!used.contains(definition.id)) {
      findings.add(
        DocumentFinding(
          'Footnotes',
          'Definition [^${definition.id}] is not referenced.',
          definition.start,
          definition.end,
        ),
      );
    }
  }
  for (final reference in footnotes.references) {
    if (!definitions.containsKey(reference.id)) {
      findings.add(
        DocumentFinding(
          'Footnotes',
          'Missing definition for [^${reference.id}].',
          reference.start,
          reference.end,
        ),
      );
    }
  }
  final headings = <String>{};
  var previous = 0;
  for (final section in writingSections(source)) {
    if (!headings.add(section.title.trim().toLowerCase())) {
      findings.add(
        DocumentFinding(
          'Structure',
          'Repeated heading “${section.title}”. Title-based section links may be ambiguous; stable block anchors are still usable.',
          section.start,
          section.headingEnd,
        ),
      );
    }
    if (previous > 0 && section.level > previous + 1) {
      findings.add(
        DocumentFinding(
          'Structure',
          'Heading jumps from level $previous to ${section.level}. Check the document hierarchy.',
          section.start,
          section.headingEnd,
        ),
      );
    }
    previous = section.level;
  }
  findings.sort((a, b) => a.start.compareTo(b.start));
  return List.unmodifiable(findings);
}

class VaultInsights {
  VaultInsights(
    List<UniversalObject> objects,
    List<ObjectConnection> references, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    active = objects.where((o) => !o.isDeleted).toList();
    trash = objects.length - active.length;
    final ids = active.map((o) => o.id).toSet();
    final neighbors = {for (final o in active) o.id: <String>{}};
    final titles = <String, List<UniversalObject>>{};
    for (final object in active) {
      types.update(object.typeId, (n) => n + 1, ifAbsent: () => 1);
      final title = object.title.trim().toLowerCase();
      if (title.isNotEmpty) titles.putIfAbsent(title, () => []).add(object);
      if (object.typeId == 'orbit.task') {
        tasks++;
        if (object.isCompleted) completedTasks++;
      }
    }
    final pairs = <String>{};
    final missing = <String>{};
    for (final ref in references) {
      if (!ids.contains(ref.source.id) || ref.source.id == ref.target.id) {
        continue;
      }
      if (!ids.contains(ref.target.id)) {
        if (missing.add('${ref.source.id}:${ref.target.id}')) {
          missingSources.add(ref.source);
        }
        continue;
      }
      referenceCount++;
      neighbors[ref.source.id]!.add(ref.target.id);
      neighbors[ref.target.id]!.add(ref.source.id);
      pairs.add(
        ref.source.id.compareTo(ref.target.id) < 0
            ? '${ref.source.id}:${ref.target.id}'
            : '${ref.target.id}:${ref.source.id}',
      );
    }
    connectionPairs = pairs.length;
    degree = {for (final e in neighbors.entries) e.key: e.value.length};
    isolatedNotes = active
        .where((o) => o.typeId == 'orbit.note' && degree[o.id] == 0)
        .toList();
    duplicateGroups = titles.values.where((g) => g.length > 1).toList();
    busiest = active.where((o) => degree[o.id]! > 0).toList()
      ..sort((a, b) {
        final d = degree[b.id]!.compareTo(degree[a.id]!);
        return d == 0 ? a.id.compareTo(b.id) : d;
      });
    recent =
        active
            .where(
              (o) =>
                  !o.updatedAt.isAfter(clock) &&
                  clock.difference(o.updatedAt) <= const Duration(days: 7),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) continue;
      components++;
      final queue = [id];
      for (var i = 0; i < queue.length; i++) {
        for (final next in neighbors[queue[i]]!) {
          if (seen.add(next)) queue.add(next);
        }
      }
    }
  }
  late final List<UniversalObject> active, isolatedNotes, busiest, recent;
  late final List<List<UniversalObject>> duplicateGroups;
  late final Map<String, int> degree;
  final types = <String, int>{};
  final missingSources = <UniversalObject>[];
  int trash = 0,
      referenceCount = 0,
      connectionPairs = 0,
      components = 0,
      tasks = 0,
      completedTasks = 0;

  /// Aggregate counts only: no titles, IDs, paths, source text or account details.
  Map<String, dynamic> aggregateReport() => {
    'version': 1,
    'scope': 'active Vault objects',
    'objects': active.length,
    'trash': trash,
    'types': types,
    'referenceOccurrences': referenceCount,
    'connectedPairs': connectionPairs,
    'connectedGroups': components,
    'isolatedNotes': isolatedNotes.length,
    'duplicateTitleGroups': duplicateGroups.length,
    'missingTargetPairs': missingSources.length,
    'tasks': tasks,
    'completedTasks': completedTasks,
    'updatedLastSevenDays': recent.length,
  };
}
