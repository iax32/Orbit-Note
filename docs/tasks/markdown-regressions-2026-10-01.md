# Markdown regression repairs — 2026-10-01

Owner accepts the four editor failures identified by the previous performance
task. This is a narrow EDT-02/04 paragraph, list and selection repair. Existing
performance caches, features, animations and unrelated work are preserved. No
desktop automation, dependencies, durable format changes or migrations.

## Findings and repairs

- All four original failures were reproduced before repairs.
- Exiting an empty list item/quote returned a caret on the separator line. Typing
  replaced that line and became a continuation of the preceding list. Return the
  caret after the separator, leaving an editable independent paragraph at EOF or
  before following content. Preserve LF/CRLF and the remaining source.
- A prose pointer listener also covered the block handle. Clicking a selected
  handle cleared the range before opening its menu or starting its drag. Limit
  that listener to content: prose clicks enter text editing, handle clicks retain
  the range. Existing source/note/block/selection stale-menu guards remain active.
- The stale-menu test targeted an unselected handle but expected selected-range
  actions. Target the selected handle and assert the selected menu opens before
  changing the range; the old pointer behavior still failed this corrected setup.
- Delete at paragraph end already works once focus is applied. Its test requested
  focus and sent an unmodified key before the deferred focus update. Pump after
  requesting focus; retain the exact join and undo expectations. No unnecessary
  production Delete change was made.

## Validation

- Focused editor, boundary, multi-selection and reorder suite: **61 passed**.
- `flutter analyze --no-pub`: clean (18.9s).
- `dart format lib test` and strict no-change formatting: clean (349 files).
- Scoped `git diff --check`: clean. Unrelated work preserved.
- `flutter test --no-pub`: **1,070 passed, zero failures** (3m29s), including all
  four original failures, long-note cache/controller tests and composition history.
- Normal `lib/main.dart` Windows release rebuilt with the existing local build
  configuration (214.5s): `build/windows/x64/runner/Release/orbit_note.exe`.
  No review build or desktop interaction used. The suite/build ran concurrently;
  these durations are validation times, not app performance measurements.

Additional regression coverage checks empty bullet/number/checklist/quote exit
with LF/CRLF at EOF and before following prose; a Windows-platform test reveals
the handle with mouse hover, taps it, duplicates the exact range, undoes it and
returns to prose focus. List continuation/nesting also checks focus and Source/Rich round-trip.
These are headless Flutter tests, not native OS input acceptance.

Logs: `.local/editor-regressions-baseline.log`,
`.local/editor-regressions-focused.log`, `.local/editor-regressions-analyze.log`,
`.local/editor-regressions-full-tests.log`,
`.local/editor-regressions-windows-build.log`.

Suggested next task: audit Rich table editing boundaries and multiline clipboard
operations with the now-working test runner; stop before implementing that pass.
