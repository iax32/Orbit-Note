import 'dart:convert';
import 'document_anchors.dart';
import 'object_reference.dart';
import 'universal_object.dart';

/// A readable quoted snapshot follows metadata; the referenced note owns live text.
class LinkedSection {
  const LinkedSection(this.target, this.fallback, {this.section = false});
  final ObjectReference target;
  final String fallback;
  final bool section;
  static final opening = RegExp(r'^<!-- orbit:section (\{.*\}) -->$');
  static const closing = '<!-- /orbit:section -->';

  static LinkedSection? parse(String source) {
    if (!source.startsWith('<!-- orbit:section ')) return null;
    final lines = source.split(RegExp(r'\r\n|\n|\r'));
    final match = opening.firstMatch(lines.first);
    if (match == null) return null;
    try {
      final data = jsonDecode(match[1]!);
      if (data is! Map ||
          data.keys.any((k) => !['target', 'section'].contains(k)) ||
          data['target'] is! String ||
          data['section'] is! bool) {
        return null;
      }
      final target = ObjectReference.parse(data['target'] as String);
      if (target.anchorType != 'block' && target.anchorType != 'heading') {
        return null;
      }
      final end = lines.indexOf(closing, 1);
      if (end < 0 || lines.skip(end + 1).any((l) => l.trim().isNotEmpty)) {
        return null;
      }
      final quoted = lines.sublist(1, end);
      if (quoted.any((l) => !l.startsWith('> '))) return null;
      return LinkedSection(
        target,
        quoted.map((l) => l.substring(2)).join('\n'),
        section: data['section'] as bool,
      );
    } catch (_) {
      return null;
    }
  }

  String encode({String eol = '\n'}) => [
    '<!-- orbit:section ${jsonEncode({'target': target.target, 'section': section})} -->',
    for (final line in fallback.split(RegExp(r'\r\n|\n|\r'))) '> $line',
    closing,
    '',
  ].join(eol);

  static int? endLine(List<String> lines, int start) {
    for (var i = start + 1; i < lines.length && i - start < 10000; i++) {
      if (lines[i].trimRight() == closing) return i;
      if (!lines[i].startsWith('> ')) return null;
    }
    return null;
  }
}

String withoutBlockAnchor(String text) {
  String? fence;
  return text.replaceAllMapped(RegExp(r'[^\n]*\n|[^\n]+$'), (line) {
    final value = line[0]!;
    final marker = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)').firstMatch(value);
    if (marker != null) {
      if (fence == null) {
        fence = marker[1];
      } else if (marker[1]!.startsWith(fence![0]) &&
          marker[1]!.length >= fence!.length &&
          marker[2]!.trim().isEmpty) {
        fence = null;
      }
      return value;
    }
    if (fence != null || value.startsWith('    ') || value.startsWith('\t')) {
      return value;
    }
    return value.replaceFirst(
      RegExp(r'[ \t]+\^[A-Za-z0-9][A-Za-z0-9_-]*(?=\r?\n?$)'),
      '',
    );
  });
}

bool isLinkableFragment(DocumentFragment fragment) =>
    !RegExp(r'^\s*(?:>|<|\$|\||:::|\\)').hasMatch(fragment.text);

/// Explicit detach snapshots nested references too; fenced examples remain literal.
String snapshotLinkedSection(
  LinkedSection link,
  List<UniversalObject> objects,
  Set<String> ancestors,
) {
  var remaining = 24;
  String expand(LinkedSection current, Set<String> chain) {
    final resolved = resolveLinkedSection(current, objects, chain);
    final text = resolved.text;
    final lines = RegExp(
      r'[^\n]*\n|[^\n]+$',
    ).allMatches(text).map((m) => m[0]!).toList();
    final result = StringBuffer();
    String? fence;
    for (var i = 0; i < lines.length; i++) {
      final value = lines[i].trimRight();
      final delimiter = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$').firstMatch(value);
      if (delimiter != null) {
        if (fence == null) {
          fence = delimiter[1];
        } else if (delimiter[1]!.startsWith(fence[0]) &&
            delimiter[1]!.length >= fence.length &&
            delimiter[2]!.trim().isEmpty) {
          fence = null;
        }
      }
      if (fence == null && LinkedSection.opening.hasMatch(value)) {
        final end = LinkedSection.endLine(lines, i);
        final nested = end == null
            ? null
            : LinkedSection.parse(lines.sublist(i, end + 1).join());
        if (nested != null) {
          final copy = remaining-- > 0 && resolved.warning == null
              ? expand(nested, {...chain, current.target.id})
              : nested.fallback.replaceAll(
                  RegExp(r'^<!-- /?orbit:section.*-->$', multiLine: true),
                  '',
                );
          result.writeln(copy);
          i = end!;
          continue;
        }
      }
      result.write(lines[i]);
    }
    return result.toString();
  }

  return expand(link, ancestors);
}

DocumentFragment? linkedFragment(String body, LinkedSection link) {
  final fragment = resolveDocumentFragment(body, link.target);
  if (fragment == null) return null;
  if (!link.section || fragment.heading == null) return fragment;
  final heading = RegExp(r'^ {0,3}(#{1,6})\s').firstMatch(fragment.text);
  final level = heading?[1]?.length ?? (fragment.text.contains('=') ? 1 : 2);
  var end = body.length;
  for (final next in documentFragments(body)) {
    if (next.start <= fragment.start || next.heading == null) continue;
    final match = RegExp(r'^ {0,3}(#{1,6})\s').firstMatch(next.text);
    final nextLevel = match?[1]?.length ?? (next.text.contains('=') ? 1 : 2);
    if (nextLevel <= level) {
      end = next.start;
      break;
    }
  }
  return DocumentFragment(
    fragment.start,
    end,
    body.substring(fragment.start, end),
    heading: fragment.heading,
    blockId: fragment.blockId,
  );
}

({String text, String? warning}) resolveLinkedSection(
  LinkedSection link,
  List<UniversalObject> objects,
  Set<String> ancestors,
) {
  if (ancestors.contains(link.target.id) || ancestors.length >= 5) {
    return (
      text: link.fallback,
      warning: 'Circular or deeply nested reference. Showing saved snapshot.',
    );
  }
  final note = objects
      .where((o) => o.id == link.target.id && !o.isDeleted)
      .firstOrNull;
  if (note == null ||
      note.typeId != 'orbit.note' ||
      note.properties['documentFormat'] == 'latex') {
    return (
      text: link.fallback,
      warning: 'Source note unavailable. Showing saved snapshot.',
    );
  }
  final fragment = linkedFragment(note.body, link);
  if (fragment == null) {
    return (
      text: link.fallback,
      warning: 'Section missing or ambiguous. Showing saved snapshot.',
    );
  }
  if (fragment.text.length > 100000) {
    return (
      text: link.fallback,
      warning: 'Section exceeds preview limit. Open the source.',
    );
  }
  return (text: withoutBlockAnchor(fragment.text), warning: null);
}
