import 'object_reference.dart';

class DocumentFragment {
  const DocumentFragment(
    this.start,
    this.end,
    this.text, {
    this.heading,
    this.blockId,
    this.label,
  });
  final int start, end;
  final String text;
  final String? heading, blockId, label;
}

/// Derived source ranges, never durable identities. Explicit Markdown anchors
/// and LaTeX labels remain user-owned source; code fences are not interpreted.
List<DocumentFragment> documentFragments(String source, {bool latex = false}) {
  final result = <DocumentFragment>[];
  final lines = RegExp(r'[^\n]*\n|[^\n]+$').allMatches(source).toList();
  String? fence;
  var start = -1;
  void flush(int end) {
    if (start < 0) return;
    final text = source.substring(start, end);
    final block =
        RegExp(r'(?:^|\s)\^([A-Za-z0-9][A-Za-z0-9_-]*)\s*$').firstMatch(text) ??
        RegExp(
          r'[ \t]+\^([A-Za-z0-9][A-Za-z0-9_-]*)\r?\n {0,3}(?:=+|-+)\s*$',
        ).firstMatch(text);
    final heading = latex
        ? RegExp(r'\\(?:sub)*section\*?\{([^}]+)\}').firstMatch(text)?.group(1)
        : RegExp(
                r'^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$',
                multiLine: true,
              ).firstMatch(text)?.group(1) ??
              RegExp(
                r'^([^\r\n]+)\r?\n {0,3}(?:=+|-+)\s*$',
              ).firstMatch(text)?.group(1);
    final label = latex
        ? RegExp(r'\\label\{([^}]+)\}').firstMatch(text)?.group(1)
        : null;
    result.add(
      DocumentFragment(
        start,
        end,
        text,
        heading: heading?.replaceFirst(
          RegExp(r'[ \t]+\^[A-Za-z0-9][A-Za-z0-9_-]*$'),
          '',
        ),
        blockId: block?[1],
        label: label,
      ),
    );
    start = -1;
  }

  for (final line in lines) {
    final value = line[0]!;
    final delimiter = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)').firstMatch(value);
    if (!latex && delimiter != null) {
      if (fence == null) {
        flush(line.start);
        fence = delimiter[1]!;
      } else if (delimiter[1]!.startsWith(fence[0]) &&
          delimiter[1]!.length >= fence.length &&
          delimiter[2]!.trim().isEmpty) {
        fence = null;
      }
      continue;
    }
    if (fence != null) continue;
    if (!latex && (value.startsWith('    ') || value.startsWith('\t'))) {
      flush(line.start);
      continue;
    }
    if (value.trim().isEmpty) {
      flush(line.start);
      continue;
    }
    final isHeading = latex
        ? RegExp(r'^\s*\\(?:sub)*section').hasMatch(value)
        : RegExp(r'^ {0,3}#{1,6}\s').hasMatch(value);
    if (isHeading) flush(line.start);
    start = start < 0 ? line.start : start;
    // A heading is its own target; ordinary following prose forms another block.
    if (isHeading) flush(line.end);
    if (!latex && RegExp(r'^ {0,3}(?:=+|-+)\s*$').hasMatch(value)) {
      flush(line.end);
    }
  }
  flush(source.length);
  return result;
}

DocumentFragment? resolveDocumentFragment(
  String source,
  ObjectReference reference, {
  bool latex = false,
}) {
  if (latex && reference.anchorType == 'label') {
    final prose = source.replaceAllMapped(
      RegExp(r'(?<!\\)%[^\r\n]*'),
      (m) => ' ' * m[0]!.length,
    );
    final labels = RegExp(
      r'\\label\{([^}]+)\}',
    ).allMatches(prose).where((m) => m[1] == reference.anchorId).toList();
    if (labels.length != 1) return null;
    final at = labels.single.start;
    final fragments = documentFragments(source, latex: true);
    return fragments.where((f) => at >= f.start && at < f.end).firstOrNull;
  }
  final matches = documentFragments(source, latex: latex)
      .where(
        (fragment) => switch (reference.anchorType) {
          'block' => fragment.blockId == reference.anchorId,
          'heading' =>
            fragment.heading?.toLowerCase() ==
                reference.anchorId?.toLowerCase(),
          'label' => fragment.label == reference.anchorId,
          _ => false,
        },
      )
      .toList();
  // Duplicate anchors/headings are ambiguous; never silently choose the first.
  return matches.length == 1 ? matches.single : null;
}

class AnchoredDocument {
  const AnchoredDocument(this.source, this.reference);
  final String source;
  final ObjectReference reference;
}

/// Lazily assigns an explicit anchor to one prose block. Caller generates an ID
/// and saves this through normal recoverable document commands.
AnchoredDocument anchorDocumentBlock(
  String source,
  String objectId,
  int offset,
  String newId, {
  bool structured = false,
}) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$').hasMatch(newId)) {
    throw ArgumentError('Invalid block anchor');
  }
  final fragments = documentFragments(source);
  final matches = fragments
      .where((f) => offset >= f.start && offset < f.end)
      .toList();
  if (matches.length != 1) {
    throw StateError('Select a prose block outside code');
  }
  final fragment = matches.single;
  final prose = fragment.text.replaceFirst(
    RegExp(r'^<!-- orbit:align=(left|center|right) -->\r?\n'),
    '',
  );
  if (structured && RegExp(r'^\s*(?:>|<|\$|\||:::|\\)').hasMatch(prose)) {
    throw StateError('Choose a paragraph, heading or list');
  }
  if (!structured &&
      (fragment.heading != null ||
          RegExp(
            r'^\s*(?:>|[-+*]\s|\d+[.)]\s|<|\$|\||:::|\\)',
          ).hasMatch(prose))) {
    throw StateError('Choose an ordinary prose paragraph');
  }
  final id = fragment.blockId ?? newId;
  if (fragments.where((f) => f.blockId == id).length >
      (fragment.blockId == null ? 0 : 1)) {
    throw StateError('Duplicate block anchor');
  }
  if (fragment.blockId != null) {
    return AnchoredDocument(
      source,
      ObjectReference(objectId, anchorType: 'block', anchorId: id),
    );
  }
  final eol = source.contains('\r\n') ? '\r\n' : '\n';
  final setext =
      fragment.heading != null &&
      !RegExp(r'^ {0,3}#{1,6}\s').hasMatch(fragment.text);
  final contentEnd = setext
      ? fragment.start +
            fragment.text.indexOf('\n') -
            (fragment.text.contains('\r\n') ? 1 : 0)
      : fragment.end - (fragment.text.endsWith(eol) ? eol.length : 0);
  final updated = source.replaceRange(contentEnd, contentEnd, ' ^$id');
  return AnchoredDocument(
    updated,
    ObjectReference(objectId, anchorType: 'block', anchorId: id),
  );
}
