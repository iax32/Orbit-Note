import 'dart:convert';
import '../../domain/object_reference.dart';
import '../../domain/note_composition.dart';
import '../../domain/linked_section.dart';
import 'rich/markdown_document.dart';
import 'rich/media_section_source.dart';

const canvasClipboardPrefix = 'orbit-canvas/1\n';

/// Complete image blocks become placements; images in code examples stay text.
List<Map<String, dynamic>> markdownCanvasItems(String source) {
  final result = <Map<String, dynamic>>[];
  var text = '';
  void flush() {
    if (text.trim().isNotEmpty) {
      result.add({'type': 'sticky', 'text': text.trim()});
    }
    text = '';
  }

  for (final block in MarkdownDocument.parse(source).blocks) {
    final live = NoteObjectBlock.parse(block.source);
    final section = LinkedSection.parse(block.source);
    if (live != null || section != null) {
      flush();
      final reference = live?.reference ?? section!.target;
      result.add({
        'type': 'card',
        'objectId': reference.id,
        'referenceTarget': reference.target,
        'presentation': section == null ? 'preview' : 'transclusion',
        'text': live?.label ?? section!.fallback.split('\n').first,
      });
      continue;
    }
    final objectLink = block.kind == MarkdownBlockKind.text
        ? RegExp(
            r'^\[\[([^\]|\r\n]+)(?:\|([^\]\r\n]*))?\]\]$',
          ).firstMatch(block.content.trim())
        : null;
    if (objectLink != null) {
      flush();
      result.add({
        'type': 'card',
        'objectId': ObjectReference.parse(objectLink[1]!).id,
        'referenceTarget': ObjectReference.parse(objectLink[1]!).target,
        'text': objectLink[2] ?? objectLink[1]!,
      });
      continue;
    }
    final media = block.kind == MarkdownBlockKind.media
        ? MediaSectionSource.parse(block.source)
        : null;
    if (media != null) {
      flush();
      result.add({
        'type': 'image',
        'text': media.alt,
        'contentRef': media.image,
      });
      text = media.body;
      flush();
      continue;
    }
    final match = block.kind == MarkdownBlockKind.image
        ? RegExp(
            r'^!\[([^\]]*)\]\((?:<([^>]+)>|([^ )]+))(?: +"[^"]*")?\)',
          ).firstMatch(block.content)
        : null;
    if (match == null) {
      text += block.source;
    } else {
      flush();
      result.add({
        'type': 'image',
        'text': match[1]!,
        'contentRef': match[2] ?? match[3]!,
      });
    }
  }
  flush();
  return result;
}

/// Resolve note-relative paths before transferring a selection to another owner.
String portableClipboardMarkdown(
  String source,
  String Function(String)? resolve,
) {
  if (resolve == null) return source;
  return MarkdownDocument.parse(source).blocks.map((block) {
    if (block.kind != MarkdownBlockKind.image &&
        block.kind != MarkdownBlockKind.media) {
      return block.source;
    }
    return block.source.replaceFirstMapped(
      RegExp(r'(!\[[^\]]*\]\()(?:(<)([^>]+)>|([^ )]+))'),
      (m) => '${m[1]}<${resolve(m[3] ?? m[4]!)}>',
    );
  }).join();
}

/// Reuse Canvas's existing representation without duplicating shared objects.
String? canvasClipboardMarkdown(String source) {
  if (!source.startsWith(canvasClipboardPrefix) ||
      source.length > 8 * 1024 * 1024) {
    return null;
  }
  try {
    final data = jsonDecode(source.substring(canvasClipboardPrefix.length));
    if (data is! Map || data['elements'] is! List) return null;
    final elements = data['elements'] as List;
    if (elements.length > 10000) return null;
    final blocks = <String>[];
    for (final value in elements) {
      if (value is! Map) return null;
      final title = value['text'] is String ? value['text'] as String : '';
      final ref = value['contentRef'];
      final id = value['objectId'];
      if (value['type'] == 'image' &&
          ref is String &&
          ref.isNotEmpty &&
          !ref.contains(RegExp(r'[<>\r\n]'))) {
        blocks.add(
          '![${title.replaceAll(RegExp(r'[\[\]\\\r\n]'), ' ')}](<$ref>)',
        );
      } else if (id is String &&
          const {'card', 'image', 'link'}.contains(value['type']) &&
          id.isNotEmpty &&
          !id.contains(RegExp(r'[\[\]\r\n]'))) {
        final precise = value['referenceTarget'];
        final reference =
            precise is String && ObjectReference.parse(precise).id == id
            ? ObjectReference.parse(precise)
            : ObjectReference(id);
        blocks.add(reference.markdown(title));
      } else if (title.isNotEmpty &&
          const {'text', 'sticky', 'section'}.contains(value['type'])) {
        blocks.add(title);
      } else {
        // Drawings have no Markdown representation: retain the literal payload.
        return null;
      }
    }
    return blocks.isEmpty ? null : blocks.join('\n\n');
  } on FormatException {
    return null;
  }
}
