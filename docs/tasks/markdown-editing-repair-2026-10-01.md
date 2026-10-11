# Markdown editing repair — 2026-10-01

## Scope and changes

Owner requested repairs to clunky rich Markdown input, especially an inserted
empty paragraph that Backspace could not remove. This pass keeps the current
source-preserving editor and portable storage contract; no packages or migrations.

- Shared boundary edits remove focused empty paragraphs, including after code
  and tables; insertion avoids redundant separator lines. Backspace removes list,
  quote and heading formatting before merging. Delete can join the next prose block.
- Enter preserves balanced inline marks, continues quotes and ordered/check lists,
  inserts prose before a heading when at its start, and preserves CRLF boundaries.
- Joins preserve final line endings and a single prose anchor. Separately linked
  blocks cannot silently lose identities through a merge.
- Formatting keeps selections, toggles partial/nested marks, supports Ctrl+B/I,
  and stores collapsed typing styles only when text is actually entered. Mixed
  selections choose readable delimiters; ambiguous combinations remain unchanged
  with a smaller-selection/Source fallback.
- Insertions replace selected text and position the caret. Clipboard reads and
  link dialogs cannot overwrite edits or selection changes made while awaiting them.
  Clipboard whitespace is preserved. IME composition is guarded before structural keys.
- Returning to an atomic block does not select it for accidental repeated-key deletion.

## Evidence

- Six boundary/formatting groups executed directly with Dart and passed. Added
  `test/markdown_boundary_editing_test.dart` for durable coverage; mixed formatting
  adds a seventh group. Widget cases cover selected formatting, pending bold,
  Delete-to-join and undo in `test/rich_editor_widget_test.dart`.
- Direct Dart sweep: 2,505 selected-range cases preserve visible text; 165
  ambiguous requests deliberately preserve source unchanged. This is preservation
  evidence, not proof every Markdown combination supports the requested style.
- Full Flutter test suite attempted: Windows Application Control blocks
  `flutter_tester.exe` before test execution. No passing Flutter test count claimed.
- Static analysis clean before final focus correction; final checks recorded below.
- Normal Windows release built in 91.8 seconds before final corrections.
- Native review was stopped with Escape in the preceding turn. No user vault
  contents were changed for acceptance testing; native behavior remains unverified.

## Remaining limits / next task

Do not claim all hidden bugs are fixed. IME typing-style commits, cross-block
selection and equation-adjacent text still need interactive acceptance. Next task:
verify paragraph insertion/deletion, mixed formatting, IME and undo in a temporary
native sample vault once Flutter test execution is available.

## Final validation

Final analyzer: no issues (10.6s). Final normal Windows release build: passed
(65.2s), `build/windows/x64/runner/Release/orbit_note.exe`; its Flutter bundle
contains the final repairs. Seven pure Dart regression groups passed. Formatting
and the zero-change check cover lib/test. Full widget/native acceptance remains
blocked/unverified as described above. No claim of a fully passing Flutter suite.
