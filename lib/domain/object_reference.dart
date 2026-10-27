/// Portable precise targets. Unknown fragments are retained, never retargeted.
class ObjectReference {
  const ObjectReference(this.id, {this.page, this.anchorType, this.anchorId});
  final String id;
  final int? page;
  final String? anchorType, anchorId;

  factory ObjectReference.parse(String value) {
    final separator = value.indexOf('#');
    if (separator < 1) return ObjectReference(value);
    final id = value.substring(0, separator);
    final fragment = value.substring(separator + 1);
    final page = RegExp(r'^page=([1-9][0-9]{0,5})$').firstMatch(fragment);
    if (page != null) return ObjectReference(id, page: int.parse(page[1]!));
    if (fragment.startsWith('^') && fragment.length > 1) {
      return ObjectReference(
        id,
        anchorType: 'block',
        anchorId: fragment.substring(1),
      );
    }
    for (final type in ['element', 'elements', 'label', 'annotation']) {
      if (fragment.startsWith('$type=') && fragment.length > type.length + 1) {
        try {
          return ObjectReference(
            id,
            anchorType: type,
            anchorId: Uri.decodeComponent(fragment.substring(type.length + 1)),
          );
        } on FormatException {
          return ObjectReference(id, anchorType: 'unknown', anchorId: fragment);
        }
      }
    }
    if (fragment.isEmpty || fragment.contains('=')) {
      return ObjectReference(id, anchorType: 'unknown', anchorId: fragment);
    }
    try {
      return ObjectReference(
        id,
        anchorType: 'heading',
        anchorId: Uri.decodeComponent(fragment),
      );
    } on FormatException {
      return ObjectReference(id, anchorType: 'unknown', anchorId: fragment);
    }
  }

  String get fragment => page != null
      ? 'page=$page'
      : switch (anchorType) {
          'block' => '^$anchorId',
          'heading' => Uri.encodeComponent(anchorId ?? ''),
          'element' || 'elements' || 'label' || 'annotation' =>
            '$anchorType=${Uri.encodeComponent(anchorId ?? '').replaceAll('(', '%28').replaceAll(')', '%29')}',
          'unknown' => anchorId ?? '',
          _ => '',
        };
  bool get isPrecise => page != null || anchorType != null;
  String get target => '$id${isPrecise ? '#$fragment' : ''}';
  ObjectReference withId(String value) => ObjectReference(
    value,
    page: page,
    anchorType: anchorType,
    anchorId: anchorId,
  );
  String markdown(String title) {
    final label = title.replaceAll(RegExp(r'[\[\]|\r\n]'), ' ');
    return '[[$target|$label${page == null ? '' : ' · p. $page'}]]';
  }

  String quoteMarkdown(String title, String quote) =>
      '${quote.replaceAll(RegExp(r'\r\n|\r'), '\n').split('\n').map((line) => '> $line').join('\n')}\n\n${markdown(title)}\n';
}
