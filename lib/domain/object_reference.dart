/// An optional PDF page anchor on a stable Universal Object ID.
class ObjectReference {
  const ObjectReference(this.id, {this.page});
  final String id;
  final int? page;

  factory ObjectReference.parse(String value) {
    final match = RegExp(r'^(.+)#page=([1-9][0-9]{0,5})$').firstMatch(value);
    return match == null
        ? ObjectReference(value)
        : ObjectReference(match[1]!, page: int.parse(match[2]!));
  }

  String get target => '$id${page == null ? '' : '#page=$page'}';
  String markdown(String title) {
    final label = title.replaceAll(RegExp(r'[\[\]|\r\n]'), ' ');
    return '[[$target|$label${page == null ? '' : ' · p. $page'}]]';
  }

  String quoteMarkdown(String title, String quote) =>
      '${quote.split('\n').map((line) => '> $line').join('\n')}\n\n${markdown(title)}\n';
}
