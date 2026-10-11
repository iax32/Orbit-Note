import 'object_reference.dart';

/// Data transfer container for dragging or extracting a cited quote from a PDF
/// into a Note or Canvas.
class PdfQuoteDragData {
  const PdfQuoteDragData({
    required this.objectId,
    required this.title,
    required this.page,
    required this.text,
    this.checksum,
  });

  final String objectId;
  final String title;
  final int page;
  final String text;
  final String? checksum;

  /// Markdown quote block with backlink and page citation.
  String get markdownQuote =>
      ObjectReference(objectId, page: page).quoteMarkdown(title, text);

  /// Compact single-line summary of source and page.
  String get citation => '$title · p. $page';

  /// Reference target for jumping to the exact page.
  String get referenceTarget => '$objectId#page=$page';

  Map<String, dynamic> toJson() => {
    'objectId': objectId,
    'title': title,
    'page': page,
    'text': text,
    if (checksum != null) 'checksum': checksum,
  };

  factory PdfQuoteDragData.fromJson(Map<String, dynamic> json) =>
      PdfQuoteDragData(
        objectId: json['objectId'] as String,
        title: json['title'] as String,
        page: (json['page'] as num?)?.toInt() ?? 1,
        text: json['text'] as String? ?? '',
        checksum: json['checksum'] as String?,
      );
}
