# Grammar highlighting precision — 2026-10-04

The offline checker was treating normal note vocabulary as spelling errors. The
engine was correct at finding real typos, but its curated lexicon omitted common
words such as “normal”, “sentence”, “highlight”, “working”, and “project”. That
made ordinary prose look continuously marked.

## Delivered

- Added a conservative everyday-prose vocabulary to the shared English lexicon.
- Kept unknown proper nouns, user dictionary support, ignored words, Markdown
  exclusions, spelling suggestions, and grammar rules unchanged.
- Added a regression test covering the prose pattern that exposed the issue.

## Validation

- Focused spell and grammar suite: **16 passed**.
- Full `flutter test --no-pub`: **1,211 passed**.
- `flutter analyze --no-pub`: no issues found.
- Strict format across `lib`, `test`, and `tool`: 382 files, 0 changed.
- Windows release build succeeded at
  `build/windows/x64/runner/Release/orbit_note.exe`.

## Next boundary

The next useful language-quality pass is a small language selector and separate
technical vocabulary packs, so programming and research terms can be recognized
without weakening ordinary prose checking.
