# Interface colors and Bookshelf — 2026-09-30

Owner request: customize UI colors in Settings and overhaul the heavy Bookshelf.

## Scope and design

Use the existing semantic theme, local session preferences and PDF objects. No
packages, identity migrations, content copies or storage authority changes.

- Fifteen UI roles: workspace, panels, cards, hover, accents/focus, three text
  levels, borders/dividers and status colors. Hex, hue/saturation/brightness,
  swatches and a preview. Apply/cancel, per-role default and all-color reset.
- Old sessions retain the default palette. Valid unknown color roles round-trip;
  malformed and transparent values do not enter the rendered palette. Recovery
  controls retain a neutral palette. Accent presets reset only custom accent/focus.
- Bookshelf: restrained heading, real book titles, shelf/search, sort, card/list
  presentation, compact genuine resume, room menu, favorites and reading notes.
  No fabricated book, placeholder cover or oversized ambient-room section.
- Reading rooms reach the PDF reader; reading notes load linked annotations and
  saved pages open the reader at their page. Session reading positions inform
  library metadata without copying or rewriting attachment content.
- Narrow/large-text layouts wrap, and bookmark dialogs use compact navigation.

Document ink, canvas item colors and PDF paper tones keep their existing controls.
This is customization of shared UI roles, not a replacement of content palettes.
The recovery section/editor deliberately retain readable neutral colors.

## Validation

- Full suite: 1,012 passed (`.local/colors-bookshelf-full-tests.log`).
- Final focused color/Bookshelf checks: six passed, including narrow 180% text,
  malformed metadata, saved rooms, linked notes and readable reset recovery.
- Final analyzer: no issues (7.3s). Formatting: 336 files, no changes.
- Normal `lib/main.dart` Windows release built successfully (77.0s), then launched.
  The shipped executable uses the normal app entry point, not the review fixture.
- Native review fixture opened successfully. Further screen interactions and
  final production screenshot verification were interrupted by detected user
  activity; no completed native Bookshelf/color-picker visual review is claimed.
- Android was not rebuilt: the preceding task verified that its SDK is missing.
- Existing unrelated workspace changes were retained. No new packages or migration.

Next suggested task: real first-page thumbnails with bounded asynchronous caching,
after profiling and a fallback for unreadable/encrypted documents.
