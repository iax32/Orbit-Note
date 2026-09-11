import 'object_reference.dart';

/// A lightweight link target, independent of UI and persistence libraries.
class NoteLinkTarget {
  const NoteLinkTarget({
    required this.id,
    required this.title,
    this.aliases = const [],
  });

  final String id;
  final String title;
  final List<String> aliases;
}

class WikiLink {
  const WikiLink({
    required this.target,
    required this.label,
    required this.start,
    required this.end,
  });

  final String target;
  final String label;
  final int start;
  final int end;
}

enum WikiLinkStatus { resolved, unresolved, ambiguous }

class WikiLinkResolution {
  const WikiLinkResolution(this.status, this.candidates);

  final WikiLinkStatus status;
  final List<NoteLinkTarget> candidates;
  NoteLinkTarget? get target =>
      status == WikiLinkStatus.resolved ? candidates.single : null;
}

/// Parses references in prose, leaving code examples and escaped text alone.
/// Offsets refer to the unchanged source and can be used for deliberate repair.
List<WikiLink> parseWikiLinks(String source) {
  final links = <WikiLink>[];
  var offset = 0;
  String? fenceCharacter;
  var fenceLength = 0;
  for (final line in source.split('\n')) {
    final fence = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$').firstMatch(line);
    if (fenceCharacter != null) {
      if (fence != null &&
          fence[1]!.startsWith(fenceCharacter) &&
          fence[1]!.length >= fenceLength &&
          fence[2]!.trim().isEmpty) {
        fenceCharacter = null;
      }
      offset += line.length + 1;
      continue;
    }
    if (fence != null) {
      fenceCharacter = fence[1]![0];
      fenceLength = fence[1]!.length;
      offset += line.length + 1;
      continue;
    }
    if (line.startsWith('    ') || line.startsWith('\t')) {
      offset += line.length + 1;
      continue;
    }
    var cursor = 0;
    while (cursor < line.length) {
      if (line[cursor] == '\\') {
        cursor += 2;
        continue;
      }
      if (line[cursor] == '`') {
        var count = 1;
        while (cursor + count < line.length && line[cursor + count] == '`') {
          count++;
        }
        final delimiter = '`' * count;
        var closing = line.indexOf(delimiter, cursor + count);
        while (closing >= 0 &&
            ((closing > 0 && line[closing - 1] == '`') ||
                (closing + count < line.length &&
                    line[closing + count] == '`'))) {
          closing = line.indexOf(delimiter, closing + count);
        }
        cursor = closing < 0 ? cursor + count : closing + count;
        continue;
      }
      if (line.startsWith('[[', cursor)) {
        final end = line.indexOf(']]', cursor + 2);
        if (end >= 0) {
          final content = line.substring(cursor + 2, end);
          final separator = content.indexOf('|');
          final target =
              (separator < 0 ? content : content.substring(0, separator))
                  .trim();
          final label = separator < 0
              ? target
              : content.substring(separator + 1).trim();
          if (target.isNotEmpty && !target.contains('[')) {
            links.add(
              WikiLink(
                target: target,
                label: label.isEmpty ? target : label,
                start: offset + cursor,
                end: offset + end + 2,
              ),
            );
          }
          cursor = end + 2;
          continue;
        }
      }
      cursor++;
    }
    offset += line.length + 1;
  }
  return List.unmodifiable(links);
}

/// ID matches take precedence; duplicate titles/aliases never pick arbitrarily.
WikiLinkResolution resolveWikiLink(
  WikiLink link,
  Iterable<NoteLinkTarget> targets, {
  Map<String, String> bindings = const {},
}) {
  final available = targets.toList();
  final reference = ObjectReference.parse(link.target);
  final byId = available.where((target) => target.id == reference.id).toList();
  if (byId.length == 1) {
    return WikiLinkResolution(WikiLinkStatus.resolved, byId);
  }
  final boundId = bindings[link.target];
  if (boundId != null) {
    final bound = available.where((t) => t.id == boundId).toList();
    return WikiLinkResolution(
      bound.length == 1 ? WikiLinkStatus.resolved : WikiLinkStatus.unresolved,
      bound,
    );
  }
  final query = link.target.toLowerCase();
  final matches = available
      .where(
        (target) =>
            target.title.trim().toLowerCase() == query ||
            target.aliases.any((alias) => alias.trim().toLowerCase() == query),
      )
      .toList();
  return WikiLinkResolution(
    matches.isEmpty
        ? WikiLinkStatus.unresolved
        : matches.length == 1
        ? WikiLinkStatus.resolved
        : WikiLinkStatus.ambiguous,
    List.unmodifiable(matches),
  );
}

/// Produces display Markdown only. Never write this rendering back to the note.
String stabilizeWikiLinks(String source, Iterable<NoteLinkTarget> targets) {
  var result = source;
  for (final link in parseWikiLinks(source).reversed) {
    final target = resolveWikiLink(link, targets).target;
    if (target != null && target.id != link.target) {
      result = result.replaceRange(
        link.start,
        link.end,
        '[[${target.id}|${link.label}]]',
      );
    }
  }
  return result;
}

/// Produces display Markdown only. Never write this rendering back to the note.
String wikiLinksToMarkdown(
  String source,
  Iterable<NoteLinkTarget> targets, {
  Map<String, String> bindings = const {},
}) {
  final result = StringBuffer();
  var cursor = 0;
  for (final link in parseWikiLinks(source)) {
    result.write(source.substring(cursor, link.start));
    final resolution = resolveWikiLink(link, targets, bindings: bindings);
    final label = link.label
        .replaceAll('\\', '\\\\')
        .replaceAll('[', '\\[')
        .replaceAll(']', '\\]');
    final String destination;
    final String suffix;
    switch (resolution.status) {
      case WikiLinkStatus.resolved:
        final reference = ObjectReference.parse(link.target);
        destination =
            'orbit-object:${Uri.encodeComponent(resolution.target!.id)}'
            '${reference.id == resolution.target!.id && reference.page != null ? '#page=${reference.page}' : ''}';
        suffix = '';
      case WikiLinkStatus.unresolved:
        destination = 'orbit-missing:${Uri.encodeComponent(link.target)}';
        suffix = ' · missing';
      case WikiLinkStatus.ambiguous:
        destination = 'orbit-ambiguous:${Uri.encodeComponent(link.target)}';
        suffix = ' · choose target';
    }
    result.write('[$label$suffix]($destination)');
    cursor = link.end;
  }
  result.write(source.substring(cursor));
  return result.toString();
}
