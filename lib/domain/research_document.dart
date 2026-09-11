import 'object_reference.dart';

/// Editable Markdown starters, not a separate template or project schema.
enum ResearchDocument {
  research('Research note'),
  design('Game design decision'),
  playtest('Playtest finding');

  const ResearchDocument(this.label);
  final String label;

  String markdown(String fileId, String title, int page, String quote) {
    final reference = ObjectReference(fileId, page: page);
    final source = quote.trim().isEmpty
        ? reference.markdown(title)
        : reference.quoteMarkdown(title, quote);
    final sections = switch (this) {
      research =>
        '''## Question

What are you investigating?

## Findings

## Application to the project

## Open questions

## Related notes and tasks''',
      design =>
        '''## Mechanic or system

## Player experience and design goal

## Evidence and constraints

## Options considered

## Decision and tradeoffs

## Implementation notes

Link relevant code, assets, levels and existing tasks here.

## Validation and next playtest''',
      playtest =>
        '''## Build, level and session

## Question or hypothesis

## Observations

Separate observed player behavior from interpretation.

## Reproduction steps

## Expected and actual behavior

## Impact and evidence

## Proposed change

## Linked design decisions and tasks

## Follow-up validation''',
    };
    return '# $label\n\n## Source\n\n$source\n\n$sections\n';
  }
}
