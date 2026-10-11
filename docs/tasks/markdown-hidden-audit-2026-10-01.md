# Markdown hidden-issue audit — 2026-10-01

Owner: continue searching for issues and potential hidden bugs. Focus: editing
operations that can change source, invalidate links, or race with delayed input.
This is a bounded continuation of the Markdown repair, not complete CommonMark
or Word parity. Existing unrelated workspace changes are preserved.

## Confirmed findings and fixes

- Duplicating prose copied its explicit `^block-id`, making references ambiguous.
  Duplication now keeps that ID on the original only. The copy gets a new anchor
  lazily when requested through the existing reference command. Literal IDs in code
  and unknown source remain untouched. Single/multiple duplication shares tested
  boundary handling and preserves CRLF and final-newline conventions.
- Turn-into commands discarded alignment metadata and prose anchors. Recognized
  conversions retain alignment; operations that would invalidate a linked prose
  identity or flatten unsupported source are refused with a Source-mode fallback.
- Code conversion used a fixed triple-backtick fence. It now chooses a delimiter
  longer than every payload backtick run, keeping the entire payload in one block.
- Alignment moved the caret and discarded selections. Rich and Source preserve
  reversed selections; marker insertion/removal maps Source positions correctly.
  A last paragraph without a newline now uses the document's CRLF convention.
- Delayed attachment callbacks inserted into changed positions. Both modes guard
  note identity, text, mode/selection and offer an explicit Insert here retry.
  Rich catches callback failures and prevents overlapping imports; the note toolbar
  consistently tracks an in-progress request. Unchanged/cancelled requests preserve text.
- The block menu copied `orbit://note#slug` without the note's identity. It now
  delegates to the existing validated reference command with the exact source
  offset. Unsupported/empty blocks cannot emit bogus references. Known alignment
  comments are accepted for prose-anchor creation without discarding their bytes.
- Menus could act on obsolete blocks after replacement. They now validate note,
  source, membership and the selected range after awaiting a choice; duplication
  targets the clicked block. Removed targets cannot reach a negative-index operation.
- Moving a range whose first/last paragraphs had identical text selected the wrong
  end block. The moved source offsets now define the selection instead of searching
  by content, so subsequent range actions retain every moved block.

## Validation

Ten structural/source-preservation regression groups added in
`test/markdown_structure_safety_test.dart`, including a 2,505-range sweep over
mixed marks and links. The sweep verifies visible text and all unrelated styles,
including outside the selected range. Nine widget cases cover repeated-text moves, changed-range menus, Rich/Source
alignment, delayed insertion, callback failure/overlap, precise-copy delegation,
and stale menus. Widget coverage is added, not claimed executed.

Full Flutter suite attempted in `.local/markdown-audit-tests.log`: Windows
Application Control blocks `flutter_tester.exe` before execution. Do not claim a
passing widget suite. Direct Dart checks run from the same structural test bodies;
final analysis/format/release evidence will be recorded below. No native interaction
acceptance is claimed; the prior Escape interruption is preserved as a validation gap.

## Remaining limits and suggested next task

IME, cross-block/equation selection and native undo still need interactive
acceptance. Unknown extension metadata is preserved, not automatically remapped.
Suggested next task: sample-vault acceptance for links, duplicate/convert, delayed
attachments and undo using a temporary native sample vault; keep blocked Flutter coverage explicit. Stop before that task.

## Final evidence

- Ten structural regression groups executed directly with Dart: passed
  (`.local/markdown-audit-domain.log`). The 2,505-case formatting sweep verifies
  text and unrelated styles; unsupported combinations preserve source unchanged.
- `flutter analyze --no-pub`: no issues (7.7s).
- `dart format lib test` and the zero-change check: 345 files, clean.
- Final normal Windows release build passed (62.0s):
  `build/windows/x64/runner/Release/orbit_note.exe`. Restart the running app to load
  the new release. No test-vault executable was left in that path.
- Full Flutter execution remains blocked by Windows Application Control before
  execution; the nine new widget cases have not been run. Native acceptance remains
  unverified. No packages, security settings, migrations or user note files changed.
