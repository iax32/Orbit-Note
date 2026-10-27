import 'document_publication.dart';

/// Presentation recipes only; choosing one never rewrites authored content.
enum PublicationPreset {
  report(
    'Report',
    'Balanced pages for everyday documents.',
    PublicationStyle(),
  ),
  academic(
    'Academic',
    'Serif text, numbered headings, title page and contents.',
    PublicationStyle(
      serif: true,
      fontSize: 12,
      margin: 72,
      numberHeadings: true,
      titlePage: true,
    ),
  ),
  brief(
    'Design brief',
    'More room for images and project summaries.',
    PublicationStyle(margin: 48),
  ),
  compact(
    'Compact handout',
    '10 pt text, smaller margins, no separate contents page.',
    PublicationStyle(fontSize: 10, margin: 36, contents: false),
  ),
  reading(
    'Large-print reading',
    '16 pt text and clear headings with page navigation.',
    PublicationStyle(fontSize: 16, margin: 48),
  ),
  technical(
    'Technical report',
    '12 pt text, numbered sections and a contents page.',
    PublicationStyle(fontSize: 12, margin: 48, numberHeadings: true),
  );

  const PublicationPreset(this.label, this.description, this.recipe);
  final String label, description;
  final PublicationStyle recipe;

  PublicationStyle apply(PublicationStyle current) =>
      PublicationStyle.fromJson({
        ...recipe.toJson(),
        'letter': current.letter,
        'author': current.author,
        'header': current.header,
        'canvasDetails': current.canvasDetails,
        'h1PageBreaks': current.h1PageBreaks,
      });

  bool matches(PublicationStyle current) {
    final expected = apply(current).toJson(), actual = current.toJson();
    return expected.keys.every((key) => expected[key] == actual[key]);
  }
}
