import '../canvas/scene.dart';
import '../canvas/diagram_reference.dart';
import '../canvas/uml.dart';
import 'note_composition.dart';
import 'smart_view_query.dart';
import 'universal_object.dart';
import 'writing_structure.dart';
import 'publication_image.dart';

class PublicationCanvasSnapshot {
  PublicationCanvasSnapshot(
    this.key,
    this.object,
    this.block, {
    Map<String, String> paths = const {},
    this.now,
  }) : paths = Map.unmodifiable(paths);
  final String key;
  final UniversalObject object;
  final NoteObjectBlock block;
  final Map<String, String> paths;
  final DateTime? now;
  final warnings = <String>[];
  late final CanvasScene scene = _resolve();
  CanvasScene _resolve() {
    final raw = object.data['elements'];
    if (raw is! List || raw.length > 5000) {
      throw const FormatException(
        'Canvas is unsupported or exceeds 5,000 placements.',
      );
    }
    final source = CanvasScene.fromJson(object.data);
    if (raw.length > source.length) {
      warnings.add(
        '${raw.length - source.length} invalid or duplicate Canvas placements retain their original source: ${object.title}',
      );
    }
    if (source.readOnly) {
      throw const FormatException('Canvas uses an unsupported format.');
    }
    var resolved = source;
    if (block.reference.isPrecise) {
      final ids = block.reference.anchorType == 'element'
          ? [block.reference.anchorId ?? '']
          : diagramElementIds(block.reference);
      if (ids == null || ids.isEmpty) {
        throw const FormatException('Precise Canvas location is unsupported.');
      }
      final selection = ResolvedCanvasDiagram(source, ids);
      if (selection.unavailable > 0) {
        warnings.add(
          '${selection.unavailable} selected Canvas item(s) unavailable: ${object.title}',
        );
      }
      resolved = selection.scene;
    }
    final skipped = resolved.elements
        .where((e) => !e.hidden && !e.renderable)
        .length;
    if (skipped > 0) {
      warnings.add(
        '$skipped unsupported Canvas placement(s) retain their original source: ${object.title}',
      );
    }
    return CanvasScene.fromJson({
      ...object.data,
      'elements': [
        for (final e in resolved.elementsInOrder)
          if (!e.hidden && e.renderable) e.data,
      ],
    });
  }
}

/// Presentation-only expansion. No owning object, membership or source is edited.
class PublicationObjectSnapshots {
  PublicationObjectSnapshots(
    String source,
    List<UniversalObject> objects, {
    String ownerId = '',
    Map<String, String> paths = const {},
    DateTime? now,
    bool includeCanvasDetails = false,
  }) {
    final owners = objects
        .where((o) => o.id == ownerId && !o.isDeleted)
        .toList();
    final workspaces = objects.map((o) => o.workspaceId).toSet();
    final workspace = owners.length == 1
        ? owners.single.workspaceId
        : owners.isEmpty && workspaces.length == 1
        ? workspaces.single
        : null;
    final scoped = objects
        .where((o) => !o.isDeleted && o.workspaceId == workspace)
        .toList();
    final byId = <String, List<UniversalObject>>{};
    for (final o in scoped) {
      byId.putIfAbsent(o.id, () => []).add(o);
    }
    final literal = writingLiteralRanges(source);
    final replacements = <({int start, int end, String text})>[];
    var count = 0;
    var expandedLength = source.length;
    for (final match in RegExp(
      r'^<!-- orbit:object v=1 -->\r?$',
      multiLine: true,
    ).allMatches(source)) {
      if (literal.any((r) => match.start > r.$1 && match.start < r.$2)) {
        continue;
      }
      final end = source.indexOf(NoteObjectBlock.closing, match.end);
      if (end < 0) continue;
      final block = NoteObjectBlock.parse(
        source.substring(match.start, end + NoteObjectBlock.closing.length),
      );
      if (block == null) continue;
      final reference = 'orbit-object:${block.reference.target}';
      final candidates = byId[block.id] ?? [];
      final target = candidates.length == 1 ? candidates.single : null;
      var body = '**${escape(block.label)}**\n\nSource: ${escape(reference)}';
      if (++count > 100) {
        warnings.add(
          'Only the first 100 linked object blocks receive snapshots. Remaining source references are retained.',
        );
      } else if (target == null || target.isReadOnly) {
        warnings.add(
          'Linked object unavailable, ambiguous or unsupported: ${block.label} ($reference).',
        );
        body += '\n\nSource unavailable. Original reference retained.';
      } else if (target.typeId == 'orbit.canvas') {
        final key =
            'orbit-publication-canvas:${Uri.encodeComponent(block.reference.target)}';
        final canvas = PublicationCanvasSnapshot(
          key,
          target,
          block,
          paths: paths,
          now: now,
        );
        try {
          final scene = canvas.scene;
          if (scene.length == 0) {
            throw const FormatException(
              'Canvas or selected diagram has no available visible items.',
            );
          }
          canvases[key] = canvas;
          warnings.addAll(canvas.warnings);
          body =
              '**Canvas: ${escape(target.title)}**\n\n![${escape(target.title)}]($key)\n\n';
          if (includeCanvasDetails) {
            body +=
                'Source: ${escape(reference)} · revision ${target.revision}\n\n';
            body += '**Canvas contents (text snapshot)**\n\n';
            final entries = scene.elementsInOrder.toList();
            for (final element in entries.take(200)) {
              final targets = byId[element.objectId] ?? [];
              final card = targets.length == 1 ? targets.single : null;
              var text = isUmlClass(element)
                  ? UmlClass(element).searchableText
                  : element.text;
              if (text.trim().isEmpty) text = card?.title ?? element.type;
              if (text.length > 4000) {
                text = String.fromCharCodes(text.runes.take(4000));
                warnings.add(
                  'Long Canvas text snapshot shortened; original source retained: ${target.title}',
                );
              }
              body +=
                  '- ${escape(text).replaceAll(RegExp(r'\r\n|\n|\r'), ' · ')}${card == null ? '' : ' · ${escape('orbit-object:${card.id}')}'}\n';
            }
            if (entries.length > 200) {
              body +=
                  '\n[First 200 text entries shown; full rendered overview and source retained]\n';
              warnings.add(
                'Canvas text inventory limited to 200 of ${entries.length} placements: ${target.title}',
              );
            }
          }
        } catch (error) {
          warnings.add('Canvas preview unavailable: ${target.title}. $error');
          body +=
              '\n\nCanvas preview unavailable. Original reference retained.';
        }
      } else if (block.reference.isPrecise) {
        warnings.add(
          'Precise linked object location is retained without broadening it to the whole object: $reference',
        );
        body += '\n\nPrecise location preview unavailable.';
      } else {
        final kind =
            const {
              'orbit.task': 'Task',
              'orbit.view': 'Collection',
              'orbit.note': 'Note',
              'orbit.file': 'Attachment',
              'orbit.project': 'Project',
            }[target.typeId] ??
            target.typeId.split('.').last;
        body = '**${escape(kind)}: ${escape(target.title)}**\n\n';
        final properties = target.properties;
        if (target.typeId == 'orbit.task') {
          body +=
              'Status: ${target.isCompleted || properties['status'] == 'done' ? 'Completed' : escape('${properties['status'] ?? 'Open'}')}\n\n';
        }
        for (final field in [
          'status',
          'priority',
          'dueDate',
          'startDate',
          'endDate',
          'project',
          'course',
          'courseId',
          'credits',
          'semester',
          'progress',
          'tags',
        ]) {
          if (field == 'status' && target.typeId == 'orbit.task') continue;
          if (field == 'course' && properties['courseId'] is String) continue;
          var value = properties[field];
          if (value is String &&
              const {'project', 'course', 'courseId'}.contains(field)) {
            final related = byId[value] ?? [];
            if (related.length == 1) value = related.single.title;
          }
          if (value is String ||
              value is num ||
              value is bool ||
              value is List && value.every((v) => v is String)) {
            final label =
                const {
                  'status': 'Status',
                  'priority': 'Priority',
                  'dueDate': 'Due',
                  'startDate': 'Starts',
                  'endDate': 'Ends',
                  'project': 'Project',
                  'course': 'Course',
                  'courseId': 'Course',
                  'credits': 'Credits',
                  'semester': 'Semester',
                  'progress': 'Progress',
                  'tags': 'Tags',
                }[field] ??
                field;
            body +=
                '$label: ${escape(value is List ? value.join(', ') : '$value')}\n\n';
          }
        }
        if (target.typeId == 'orbit.file' &&
            (properties['mimeType'] is String &&
                (properties['mimeType'] as String).startsWith('image/'))) {
          final ref = properties['contentRef'];
          final path = ref is String ? publicationAttachmentPath(ref) : null;
          if (path != null) {
            body += '![${escape(target.title)}](<${Uri(path: path)}>)\n\n';
          } else {
            warnings.add(
              'Linked image attachment has no safe local source: ${target.title}',
            );
            body +=
                'Image source unavailable. Original reference retained.\n\n';
          }
        }
        // An object card is a labelled summary; section embeds remain the route
        // for full rich-note transclusion. Do not expose frontmatter/private data.
        var description = publicationCardBody(target.body);
        if (target.typeId == 'orbit.note' || target.typeId == 'orbit.latex') {
          description = '';
        }
        if (description.length > 10000) {
          description = String.fromCharCodes(description.runes.take(10000));
          warnings.add(
            'Description snapshot limited to 10,000 characters: ${target.title}',
          );
          description += '\n[Description continues in the source]';
        }
        if (description.trim().isNotEmpty) {
          body +=
              '${escape(description).split(RegExp(r'\r\n|\n|\r')).map((l) => '> $l').join('\n')}\n\n';
        }
        if (target.typeId == 'orbit.view') {
          try {
            final members = resolveSmartView(
              target,
              scoped,
              pathFor: (id) => paths[id],
              now: now,
            );
            body += 'Collection snapshot: ${members.length} item(s)\n\n';
            for (final member in members.take(200)) {
              body +=
                  '- ${escape(member.title)}${member.typeId == 'orbit.task' ? ' · ${member.isCompleted ? 'Completed' : 'Open'}' : ''} · ${escape('orbit-object:${member.id}')}\n';
            }
            if (members.length > 200) {
              body +=
                  '\n[First 200 items shown; open the source for the full collection]\n';
              warnings.add(
                'Collection snapshot limited to 200 of ${members.length} items: ${target.title}',
              );
            }
          } catch (_) {
            body +=
                'Collection definition unavailable. Open the source to review it.\n';
            warnings.add(
              'Collection snapshot could not resolve its saved definition: ${target.title}',
            );
          }
        }
        body +=
            '\n\nSource: ${escape(reference)} · revision ${target.revision}\n\n';
      }
      expandedLength +=
          body.length +
          2 -
          (end + NoteObjectBlock.closing.length - match.start);
      if (expandedLength > 2000000) {
        throw const FormatException(
          'Linked object snapshots exceed the publishing size limit.',
        );
      }
      replacements.add((
        start: match.start,
        end: end + NoteObjectBlock.closing.length,
        text: '\n$body\n',
      ));
    }
    for (final edit in replacements.reversed) {
      source = source.replaceRange(edit.start, edit.end, edit.text);
      if (source.length > 2000000) {
        throw const FormatException(
          'Linked object snapshots exceed the publishing size limit.',
        );
      }
    }
    expanded = source;
    objectCount = count;
    this.objects = List.unmodifiable(scoped);
  }
  static String escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAllMapped(RegExp(r'[\\`*_{}\[\]()#+\-.!|$]'), (m) => '\\${m[0]}');
  late final String expanded;
  late final int objectCount;
  late final List<UniversalObject> objects;
  final canvases = <String, PublicationCanvasSnapshot>{};
  final warnings = <String>[];
}

/// Private presentation metadata/comments never appear in card excerpts.
String publicationCardBody(String source) => source
    .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
    .trimLeft()
    .replaceFirst(
      RegExp(r'^---\r?\n[\s\S]*?\r?\n(?:---|\.\.\.)(?:\r?\n|$)'),
      '',
    );
