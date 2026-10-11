import 'markdown_document.dart';

class MarkdownSourceEdit {
  const MarkdownSourceEdit(this.source, this.offset, {this.notice});
  final String source;
  final int offset;
  final String? notice;
}

class MarkdownDuplicateEdit extends MarkdownSourceEdit {
  const MarkdownDuplicateEdit(super.source, super.offset, this.endOffset);
  final int endOffset;
}

/// Boundary operations over lossless source slices, independent of UI focus.
abstract final class MarkdownBlockEditing {
  static const _prose = {
    MarkdownBlockKind.text,
    MarkdownBlockKind.heading,
    MarkdownBlockKind.list,
    MarkdownBlockKind.quote,
  };
  static String eol(MarkdownDocument doc) =>
      doc.source.contains('\r\n') ? '\r\n' : '\n';
  static String _ending(String source) => source.endsWith('\r\n')
      ? '\r\n'
      : source.endsWith('\n')
      ? '\n'
      : '';
  static String _anchor(MarkdownBlock b) =>
      RegExp(r' \^[A-Za-z0-9][A-Za-z0-9_-]*').firstMatch(b.suffix)?.group(0) ??
      '';

  /// Copy content while keeping the original paragraph's reference unique.
  static MarkdownDuplicateEdit duplicate(
    MarkdownDocument doc,
    int first,
    int last,
  ) {
    final blocks = doc.blocks.sublist(first, last + 1), line = eol(doc);
    final original = blocks.map((b) => b.source).join();
    final copy = blocks.map((b) {
      final anchor = _anchor(b);
      return anchor.isEmpty
          ? b.source
          : b.source.substring(0, b.source.length - b.suffix.length) +
                b.suffix.replaceFirst(anchor, '');
    }).join();
    final at = doc.offsetOf(last) + doc.blocks[last].source.length;
    bool siblings(MarkdownBlock a, MarkdownBlock b) =>
        a.kind == b.kind &&
        (a.kind == MarkdownBlockKind.list || a.kind == MarkdownBlockKind.quote);
    String separator(String before, String after, int count) {
      final trailing =
          RegExp(r'(?:\r?\n)+$').firstMatch(before)?.group(0) ?? '';
      final leading = RegExp(r'^(?:\r?\n)+').firstMatch(after)?.group(0) ?? '';
      final existing = '\n'.allMatches(trailing + leading).length;
      return List.filled((count - existing).clamp(0, count), line).join();
    }

    final prefix = separator(
      original,
      copy,
      siblings(blocks.last, blocks.first) ? 1 : 2,
    );
    final remainder = doc.source.substring(at);
    final suffix = remainder.isEmpty
        ? ''
        : separator(
            copy,
            remainder,
            siblings(blocks.last, doc.blocks[last + 1]) ? 1 : 2,
          );
    final inserted = '$prefix$copy$suffix';
    return MarkdownDuplicateEdit(
      doc.source.replaceRange(at, at, inserted),
      at + prefix.length,
      at + prefix.length + copy.length,
    );
  }

  static MarkdownSourceEdit? convert(
    MarkdownDocument doc,
    int index,
    String type,
  ) {
    final b = doc.blocks[index], line = eol(doc), start = doc.offsetOf(index);
    final prefix = switch (type) {
      'Text' => '',
      'Heading 1' => '# ',
      'Heading 2' => '## ',
      'Heading 3' => '### ',
      'Bullet list' => '- ',
      'Numbered list' => '1. ',
      'Checklist' => '- [ ] ',
      'Quote' => '> ',
      'Callout' => '> [!NOTE]$line> ',
      'Code block' => '',
      _ => null,
    };
    if (prefix == null) return null;
    if (!_prose.contains(b.kind) && b.kind != MarkdownBlockKind.code) {
      return MarkdownSourceEdit(
        doc.source,
        start,
        notice:
            'Use Source to change this block while preserving its contents.',
      );
    }
    final anchor = _anchor(b);
    if (anchor.isNotEmpty && type != 'Text') {
      return MarkdownSourceEdit(
        doc.source,
        start + b.prefix.length,
        notice:
            'This paragraph has a block link. Use Source to change its structure while keeping the reference.',
      );
    }
    final content = b.content, ending = _ending(b.source);
    var replacement = '${b.alignmentPrefix}$prefix$content$anchor$ending';
    var caret = b.alignmentPrefix.length + prefix.length + content.length;
    if (type == 'Code block') {
      final ticks = RegExp(r'`{3,}')
          .allMatches(content)
          .fold(2, (n, m) => n > m[0]!.length ? n : m[0]!.length);
      final fence = List.filled(ticks + 1, '`').join();
      replacement =
          '${b.alignmentPrefix}${fence}text$line$content$line$fence$ending';
      caret =
          b.alignmentPrefix.length +
          fence.length +
          4 +
          line.length +
          content.length;
    }
    return MarkdownSourceEdit(
      doc.source.replaceRange(start, start + b.source.length, replacement),
      start + caret,
    );
  }

  static MarkdownSourceEdit insertAfter(
    MarkdownDocument doc,
    int index,
    String syntax, {
    bool sibling = false,
  }) {
    final b = doc.blocks[index], line = eol(doc);
    final start = doc.offsetOf(index) + b.source.length;
    // The existing line ending already supplies the first boundary newline.
    final boundary = b.source.endsWith('\n')
        ? (sibling ? '' : line)
        : (sibling ? line : '$line$line');
    final inserted = '$boundary$syntax$line';
    return MarkdownSourceEdit(
      doc.source.replaceRange(start, start, inserted),
      start + boundary.length + syntax.length,
    );
  }

  static MarkdownSourceEdit split(
    MarkdownDocument doc,
    int index,
    int start,
    int end,
  ) {
    final b = doc.blocks[index], line = eol(doc);
    final p = InlineProjection(b.content);
    start = start.clamp(0, p.text.length);
    end = end.clamp(start, p.text.length);
    final left = p.edit(
      p.text.substring(0, start),
      selectionStart: start,
      selectionEnd: p.text.length,
    );
    final right = p.edit(
      p.text.substring(end),
      selectionStart: 0,
      selectionEnd: end,
    );
    final originalEnding = _ending(b.source);
    final anchor = _anchor(b);
    // At the start of a heading, keep the heading on the right and insert prose.
    if (b.kind == MarkdownBlockKind.heading && start == 0 && end == 0) {
      final replacement = '$line$line${b.source}';
      return MarkdownSourceEdit(
        doc.source.replaceRange(
          doc.offsetOf(index),
          doc.offsetOf(index) + b.source.length,
          replacement,
        ),
        doc.offsetOf(index),
      );
    }
    if ((b.kind == MarkdownBlockKind.list ||
            b.kind == MarkdownBlockKind.quote) &&
        b.content.trim().isEmpty) {
      final replacement = '$line$originalEnding';
      return MarkdownSourceEdit(
        doc.source.replaceRange(
          doc.offsetOf(index),
          doc.offsetOf(index) + b.source.length,
          replacement,
        ),
        // Leave the separator intact and type in the paragraph after it.
        doc.offsetOf(index) + line.length,
      );
    }
    var nextPrefix = b.alignmentPrefix;
    if (b.kind == MarkdownBlockKind.list) {
      nextPrefix = b.prefix.replaceFirst(RegExp(r'\[[xX]\]'), '[ ]');
      nextPrefix = nextPrefix.replaceFirstMapped(
        RegExp(r'\d+(?=[.)])'),
        (m) => '${int.parse(m[0]!) + 1}',
      );
    } else if (b.kind == MarkdownBlockKind.quote) {
      nextPrefix = b.prefix;
    }
    final separator =
        b.kind == MarkdownBlockKind.list || b.kind == MarkdownBlockKind.quote
        ? line
        : '$line$line';
    // A lazy prose anchor follows the original text when splitting at its start.
    final firstTail = anchor.isNotEmpty
        ? (left.isEmpty ? '' : anchor)
        : b.suffix.replaceFirst(RegExp(r'\r?\n$'), '');
    final first = '${b.prefix}$left$firstTail';
    final secondTail =
        '${anchor.isNotEmpty && left.isEmpty ? anchor : ''}$originalEnding';
    final replacement = '$first$separator$nextPrefix$right$secondTail';
    return MarkdownSourceEdit(
      doc.source.replaceRange(
        doc.offsetOf(index),
        doc.offsetOf(index) + b.source.length,
        replacement,
      ),
      doc.offsetOf(index) + first.length + separator.length + nextPrefix.length,
    );
  }

  static MarkdownSourceEdit? backspace(MarkdownDocument doc, int index) {
    final b = doc.blocks[index], start = doc.offsetOf(index);
    if (b.kind == MarkdownBlockKind.list) {
      final replacement = b.level > 0
          ? b.source.replaceFirst(RegExp(r'^ {1,2}'), '')
          : '${b.content}${b.suffix}';
      return MarkdownSourceEdit(
        doc.source.replaceRange(start, start + b.source.length, replacement),
        start +
            (b.level > 0 ? b.prefix.length - (b.level < 2 ? b.level : 2) : 0),
      );
    }
    if (b.kind == MarkdownBlockKind.heading ||
        b.kind == MarkdownBlockKind.quote) {
      final replacement =
          '${b.alignmentPrefix}${b.content}${_ending(b.source)}';
      return MarkdownSourceEdit(
        doc.source.replaceRange(start, start + b.source.length, replacement),
        start + b.alignmentPrefix.length,
      );
    }
    if (b.kind == MarkdownBlockKind.blank ||
        b.kind == MarkdownBlockKind.text && b.content.isEmpty) {
      return _removeEmpty(doc, index);
    }
    var prev = index - 1;
    while (prev >= 0 && doc.blocks[prev].kind == MarkdownBlockKind.blank) {
      prev--;
    }
    if (prev < 0 ||
        !_prose.contains(b.kind) ||
        !_prose.contains(doc.blocks[prev].kind)) {
      return null;
    }
    return _join(doc, prev, index);
  }

  static MarkdownSourceEdit? deleteForward(MarkdownDocument doc, int index) {
    if (!_prose.contains(doc.blocks[index].kind)) return null;
    var next = index + 1;
    while (next < doc.blocks.length &&
        doc.blocks[next].kind == MarkdownBlockKind.blank) {
      next++;
    }
    if (next >= doc.blocks.length || !_prose.contains(doc.blocks[next].kind)) {
      return null;
    }
    if (doc.blocks[next].content.isEmpty) return _removeEmpty(doc, next);
    return _join(doc, index, next);
  }

  static MarkdownSourceEdit _removeEmpty(MarkdownDocument doc, int index) {
    final b = doc.blocks[index];
    var start = doc.offsetOf(index), end = start + b.source.length;
    var prev = index - 1;
    if (prev >= 0 && doc.blocks[prev].kind == MarkdownBlockKind.blank) {
      start -= doc.blocks[prev].source.length;
      prev--;
      if (b.source.isEmpty &&
          prev >= 0 &&
          doc.blocks[prev].kind != MarkdownBlockKind.blank) {
        start -= _ending(doc.blocks[prev].source).length;
      }
    } else if (index + 1 < doc.blocks.length &&
        doc.blocks[index + 1].kind == MarkdownBlockKind.blank) {
      end += doc.blocks[index + 1].source.length;
    }
    final source = doc.source.replaceRange(start, end, '');
    final offset = prev >= 0
        ? doc.offsetOf(prev) +
              doc.blocks[prev].prefix.length +
              doc.blocks[prev].content.length
        : 0;
    return MarkdownSourceEdit(source, offset.clamp(0, source.length));
  }

  static MarkdownSourceEdit _join(
    MarkdownDocument doc,
    int leftIndex,
    int rightIndex,
  ) {
    final a = doc.blocks[leftIndex], b = doc.blocks[rightIndex];
    final aId = _anchor(a), bId = _anchor(b);
    final start = doc.offsetOf(leftIndex);
    if (aId.isNotEmpty && bId.isNotEmpty ||
        bId.isNotEmpty && a.kind != MarkdownBlockKind.text) {
      return MarkdownSourceEdit(
        doc.source,
        start + a.prefix.length + a.content.length,
        notice:
            'These paragraphs have separate block links. Keep them separate or edit their references in Source.',
      );
    }
    var left = a.content, right = b.content;
    final visibleCaret = InlineProjection(left).text.length;
    for (final (marker, mark) in [
      ('**', 'bold'),
      ('__', 'bold'),
      ('~~', 'strike'),
      ('==', 'highlight'),
      ('*', 'italic'),
      ('_', 'italic'),
      ('`', 'code'),
    ]) {
      final p = InlineProjection(left), q = InlineProjection(right);
      if (left.endsWith(marker) &&
          right.startsWith(marker) &&
          p.styles.isNotEmpty &&
          q.styles.isNotEmpty &&
          p.styles.last.contains(mark) &&
          q.styles.first.contains(mark)) {
        left = left.substring(0, left.length - marker.length);
        right = right.substring(marker.length);
      }
    }
    final joined = '$left$right';
    // Heading closing syntax belongs to the left; line ending belongs to the right.
    final tail = a.kind == MarkdownBlockKind.heading
        ? '${a.suffix.replaceFirst(RegExp(r'\r?\n$'), '')}${_ending(b.source)}'
        : '${aId.isNotEmpty ? aId : bId}${_ending(b.source)}';
    final replacement = '${a.prefix}$joined$tail';
    return MarkdownSourceEdit(
      doc.source.replaceRange(
        start,
        doc.offsetOf(rightIndex) + b.source.length,
        replacement,
      ),
      start +
          a.prefix.length +
          InlineProjection(joined).sourceOffset(visibleCaret, end: true),
    );
  }
}
