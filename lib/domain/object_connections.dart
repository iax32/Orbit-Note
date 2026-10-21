import 'life_workspace.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'universal_object.dart';
import 'object_reference.dart';
import 'wiki_links.dart';
import 'note_composition.dart';
import 'linked_section.dart';
import 'calendar_planning.dart';
import 'study_card.dart';
import 'research_workspace.dart';
import 'project_context.dart';

class ObjectConnection {
  const ObjectConnection({
    required this.source,
    required this.target,
    required this.label,
    required this.location,
    this.offset,
    this.authoredId,
  });
  final UniversalObject source;
  final ObjectReference target, location;
  final String label;
  final int? offset;
  final String? authoredId;
}

/// A derived, bounded-lifetime cache. Portable documents/metadata remain owners.
/// Only changed source objects are reparsed while the target registry is stable.
class ObjectConnectionResolver {
  final _cache =
      <
        String,
        ({
          UniversalObject source,
          String? path,
          String registry,
          List<ObjectConnection> edges,
        })
      >{};
  int parsedSources = 0;
  List<ObjectConnection> resolve(
    List<UniversalObject> objects, {
    String? Function(String)? pathFor,
  }) {
    final byId = {for (final o in objects) o.id: o};
    final targets = [
      for (final o in objects)
        if (!o.isDeleted)
          NoteLinkTarget(
            id: o.id,
            title: o.title,
            aliases: o.properties['aliases'] is List
                ? (o.properties['aliases'] as List).whereType<String>().toList()
                : const [],
          ),
    ];
    final files = <String, List<String>>{};
    for (final object in objects) {
      if (object.isDeleted || object.typeId != 'orbit.file') continue;
      final ref = object.properties['contentRef'];
      if (ref is String) files.putIfAbsent(ref, () => []).add(object.id);
    }
    final registry = jsonEncode([
      for (final o in objects)
        [
          o.id,
          o.title,
          o.isDeleted,
          o.properties['aliases'],
          o.properties['contentRef'],
        ],
    ]);
    _cache.removeWhere((key, _) => byId[key]?.isDeleted != false);
    final edges = <ObjectConnection>[];
    for (final source in objects) {
      if (source.isDeleted) continue;
      final path = pathFor?.call(source.id);
      var cached = _cache[source.id];
      if (cached == null ||
          !identical(cached.source, source) ||
          cached.registry != registry ||
          cached.path != path) {
        parsedSources++;
        cached = (
          source: source,
          path: path,
          registry: registry,
          edges: _extract(source, targets, byId, files, path),
        );
        _cache[source.id] = cached;
      }
      edges.addAll(cached.edges);
    }
    return List.unmodifiable(edges);
  }

  List<ObjectConnection> _extract(
    UniversalObject source,
    List<NoteLinkTarget> targets,
    Map<String, UniversalObject> byId,
    Map<String, List<String>> files,
    String? path,
  ) {
    final edges = <ObjectConnection>[];
    final seen = <String>{};
    void add(
      ObjectReference target,
      String label, {
      ObjectReference? location,
      int? offset,
      String? authoredId,
    }) {
      if (target.id.isEmpty || target.id == source.id) return;
      final at = location ?? ObjectReference(source.id);
      if (!seen.add('${target.target}|$label|${at.target}|$offset')) return;
      edges.add(
        ObjectConnection(
          source: source,
          target: target,
          label: label,
          location: at,
          offset: offset,
          authoredId: authoredId,
        ),
      );
    }

    for (final link in parseWikiLinks(source.body)) {
      final resolved = resolveWikiLink(
        link,
        targets,
        bindings: source.linkBindings,
      ).target;
      if (resolved != null) {
        add(
          ObjectReference.parse(link.target).withId(resolved.id),
          'Mention',
          offset: link.start,
        );
      }
    }
    final lines = RegExp(r'[^\n]*\n|[^\n]+$').allMatches(source.body).toList();
    final rawLines = lines.map((m) => m[0]!).toList();
    final fence = NoteLayoutFence();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i][0]!.replaceFirst(RegExp(r'\r?\n$'), '');
      if (!fence.outside(line) ||
          line.startsWith('    ') ||
          line.startsWith('\t')) {
        continue;
      }
      if (NoteObjectBlock.opening.hasMatch(line) && i + 2 < lines.length) {
        final block = NoteObjectBlock.parse(
          lines.sublist(i, i + 3).map((l) => l[0]!).join(),
        );
        if (block != null) {
          add(block.reference, 'Live card', offset: lines[i].start);
          i += 2;
          continue;
        }
      }
      if (LinkedSection.opening.hasMatch(line)) {
        final end = LinkedSection.endLine(rawLines, i);
        final block = end == null
            ? null
            : LinkedSection.parse(
                lines.sublist(i, end + 1).map((l) => l[0]!).join(),
              );
        if (block != null) {
          add(block.target, 'Live section', offset: lines[i].start);
          i = end!;
          continue;
        }
      }
      for (final match in RegExp(
        r'!?\[[^\]\r\n]*\]\((?:<([^>\r\n]+)>|([^ )\r\n]+))\)',
      ).allMatches(line)) {
        if (_inCode(line, match.start) || _escaped(line, match.start)) continue;
        final raw = match[1] ?? match[2]!;
        if (raw.startsWith('orbit-object:')) {
          add(
            ObjectReference.parse(raw.substring(13)),
            'Reference',
            offset: lines[i].start + match.start,
          );
        } else if (Uri.tryParse(raw)?.hasScheme == false) {
          String decoded;
          try {
            decoded = Uri.decodeFull(raw);
          } on FormatException {
            continue;
          }
          final resolved = decoded.startsWith('Attachments/')
              ? decoded
              : path == null
              ? decoded
              : p.posix.normalize(p.posix.join(p.posix.dirname(path), decoded));
          final ids = files[resolved];
          if (ids?.length == 1) {
            add(
              ObjectReference(ids!.single),
              'Attachment',
              offset: lines[i].start + match.start,
            );
          }
        }
      }
    }
    if (source.typeId == 'orbit.canvas' && source.data['elements'] is List) {
      for (final element in source.data['elements'] as List) {
        if (element is! Map || element['id'] is! String) continue;
        final location = ObjectReference(
          source.id,
          anchorType: 'element',
          anchorId: element['id'] as String,
        );
        final raw =
            element['referenceTarget'] ??
            (element['data'] is Map
                ? element['data']['referenceTarget']
                : null);
        final id = element['objectId'] ?? element['targetId'];
        if (id is String) {
          add(
            raw is String && ObjectReference.parse(raw).id == id
                ? ObjectReference.parse(raw)
                : ObjectReference(id),
            'Canvas placement',
            location: location,
          );
        }
        final content = element['contentRef'];
        if (content is String && files[content]?.length == 1 && id == null) {
          add(
            ObjectReference(files[content]!.single),
            'Canvas attachment',
            location: location,
          );
        }
        final view = element['viewConfig'];
        if (view is Map &&
            (view['view'] ?? view['viewId']) is String &&
            id == null) {
          add(
            ObjectReference((view['view'] ?? view['viewId']) as String),
            'Live view',
            location: location,
          );
        }
      }
    }
    void field(String key, String label, {bool explicit = false}) {
      final value = source.properties[key];
      if (value is String &&
          value.isNotEmpty &&
          (explicit || byId.containsKey(value) || _uuid.hasMatch(value))) {
        add(ObjectReference(value), label);
      }
    }

    for (final pair in {
      'lifeGoalId': 'Life action',
      'lifeSourceId': 'Life schedule',
      'templateSourceId': 'Personal template',
      'courseId': 'Course',
      'project': 'Project',
      'contextId': 'Context',
      'context': 'Context',
      'linkedId': 'Context',
      'courseBoardId': 'Study board',
      'mechanicId': 'Mechanic',
      'playtestId': 'Playtest',
      'taskId': 'Implementation task',
      'findingId': 'Finding',
      'briefId': 'Brief',
      'sourceId': 'Source',
    }.entries) {
      field(pair.key, pair.value);
    }
    for (final key in [
      'memberIds',
      'resources',
      'gameplayResourceIds',
      'evidenceIds',
      'assumptionIds',
    ]) {
      final raw = source.properties[key];
      if (raw is List) {
        for (final id in raw.whereType<String>()) {
          if (byId.containsKey(id) || _uuid.hasMatch(id)) {
            add(
              ObjectReference(id),
              key == 'memberIds' ? 'Collection member' : 'Linked resource',
            );
          }
        }
      }
    }
    for (final id in lifeReferences(source)) {
      add(ObjectReference(id), 'Life link');
    }
    for (final id in calendarResources(source)) {
      add(ObjectReference(id), 'Planning resource');
    }
    for (final relation in researchRelations(source)) {
      add(ObjectReference(relation.id), relation.relation);
    }
    final pdf = source.properties['pdfSource'];
    if (pdf is Map && (pdf['objectId'] ?? pdf['sourceId']) is String) {
      add(
        ObjectReference(
          (pdf['objectId'] ?? pdf['sourceId']) as String,
          page: pdf['page'] is int && pdf['page'] > 0
              ? pdf['page'] as int
              : null,
        ),
        'PDF source',
      );
    }
    if (StudyCard.supported(source)) {
      final origin = StudyCard(source).source;
      if (origin?['objectId'] is String) {
        add(
          ObjectReference(
            origin!['objectId'] as String,
            page: origin['page'] is int && origin['page'] > 0
                ? origin['page'] as int
                : null,
          ),
          'Study source',
        );
      }
    }
    for (final relation in ProjectConnection.read(
      source.properties['orbitConnections'],
    )) {
      add(relation.target, relation.kind, authoredId: relation.id);
    }
    return edges;
  }

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
  );
  bool _escaped(String value, int at) {
    var count = 0;
    while (at > 0 && value[--at] == '\\') {
      count++;
    }
    return count.isOdd;
  }

  bool _inCode(String line, int at) {
    for (var i = 0; i < at; i++) {
      if (line[i] != '`' || _escaped(line, i)) continue;
      var end = i;
      while (end < line.length && line[end] == '`') {
        end++;
      }
      final delimiter = line.substring(i, end);
      var close = -1;
      for (var k = end; k < line.length; k++) {
        if (line[k] != '`') continue;
        var runEnd = k;
        while (runEnd < line.length && line[runEnd] == '`') {
          runEnd++;
        }
        if (runEnd - k == delimiter.length) {
          close = k;
          break;
        }
        k = runEnd - 1;
      }
      if (close < 0) {
        i = end - 1;
        continue;
      }
      if (at < close + delimiter.length) return true;
      i = close + delimiter.length - 1;
    }
    return false;
  }
}
