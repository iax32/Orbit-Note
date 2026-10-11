# Find/replace repairs — 2026-10-01

Owner accepts the suggested audit across formatted text and editor modes.
Scope: EDT-03/04/06/13 search projection, selection boundaries, navigation and
shared history. No desktop automation, packages, migrations or architecture change.

## Findings and changes

### Unicode case-fold and range parity — 2026-10-07

Case-insensitive matching now uses the generated Unicode 15.1 full case-fold
map rather than a case-insensitive regular expression. The search projection
retains source starts, ends, and rune boundaries, so an expansion such as
`ß → ss` returns the one authored character and cannot produce a match for
only half of that expansion. The mapped visible range then flows through the
existing Rich/Source projection, whole-word, selection-scope, replacement, and
shared-history paths. Regression coverage includes Latin expansion, Greek
sigma, Kelvin sign, half-expansion rejection, and formatted/link replacements.

- Find previously forced Source regardless of mode. Keep Rich, Source, Split and
  Read active. Rich/Read search visible inline prose in text, heading, list and
  quote blocks; Source/Split search literal source. Specialized/raw blocks remain
  literal. Hidden prose link targets are available through Source search.
- A transient index retains source coordinates and inline projections for the
  exact body/mode. Reuse it across navigation and selection changes; invalidate
  only when source or projection mode changes. It does not serialize rendered
  content or change persistence.
- Source Replace All and final multi-block assembly use buffers rather than
  rebuilding the entire document for each result. A synthetic 10,000-result
  source operation fell from 1,400ms to 13ms in one-shot direct Dart VM checks.
  This measures replacement bookkeeping, not native frame/typing latency.
- Replacement uses the existing InlineProjection editing rules and works from
  right to left. Preserve untouched source, heading prefixes, CRLF, formatting
  and link targets, including plain wiki targets through aliases. Each result's
  visible text is verified. Escape punctuation when needed; if it cannot be
  represented safely, refuse the entire operation and report a Source fallback.
- Escaped closing delimiters previously could terminate formatting and interpret
  earlier text as markup. Skip escaped closers, respecting backslash parity;
  retain the literal-code delimiter behavior.
- Whole-word boundaries recognize Unicode letters, combining marks, numbers and
  underscores. Evaluate boundaries before restricting source results to selection
  scope; a selection clipped midway through a word never creates a whole word.
  Single Replace chooses a computed match rather than trusting arbitrary selected
  text outside the scope or whole-word rules.
- Refresh counts after typing, replacement, external source updates and undo/redo.
  Translate captured selection boundaries through source edits/history, so text
  inserted before the selection does not redirect replacement elsewhere.
- Repeated Find preserves the existing query/scope. An absent selection does not
  silently turn the entire document into a scope labelled selection.
  Opening Find after a note switch clears stale match counts even with an empty
  query.
- Rich jumps to the mapped block; Source/Split bring distant matches into view
  without moving typing focus away from Find. Read retains the existing estimated
  preview scrolling. Enter/Shift+Enter navigate repeatedly; mode changes refresh
  search coordinates. Close restores the editable mode's selection/focus.
- Replacement emits one shared document-history change. Undo/redo restore exact
  source, formatting and counts. Replacements containing the query advance past
  rewritten wiki labels instead of selecting themselves again.

## Validation

- New regression file: 22 pure/widget checks. Combined find/statistics, prior
  table/clipboard and Rich editor widget checks: 88 passed.
- Final `.local/find-replace-complete-full-tests.log`: **1,111 passed** (1m38s).
- Final `.local/find-replace-verified-analyze.log`: clean (15.2s).
- `dart format lib test` and strict no-change formatting: clean (352 files).
- Normal Windows release build succeeded (97.1s), with original local build
  configuration: `.local/find-replace-verified-windows-build.log`.
- Scoped `git diff --check`: clean.
- Intermediate regressions caught and corrected the escaped-delimiter case and
  Source Enter losing focus. Read undo uses its keyboard path; its formatting
  toolbar is intentionally absent.
- First full suite: 1,107 passed, one failure. Routing pointer mode controls
  through the shortcut handler collapsed a saved Rich selection. Preserve their
  existing range-restoration behavior while sharing match refresh. The original
  selection test passes in the final focused suite; full verification follows.
- Follow-up full suite before the linear-assembly improvement: all 1,109 passed;
  analyzer/strict format clean and normal Windows build succeeded (98.2s).
  The final source-assembly changes are validated again below.

## Follow-up validation — Unicode case-fold parity, 2026-10-07

- The focused Find/Replace regression suite passes with **35 tests**, including
  full-fold expansion, exact UTF-16 range mapping, half-expansion rejection,
  and Rich emphasis/link replacement.
- The full Flutter suite passes with **1,344 tests**.
- `dart format --output=none --set-exit-if-changed lib test` is clean and
  `flutter analyze --no-pub` reports no issues from the physical Windows
  workspace path.

## Limits and suggested next task

No native clipboard/IME or desktop interaction was performed. Read scroll remains
approximate and has no exact match highlighting. Rich search does not combine
separate structural blocks into one phrase; tables, callouts, math and unfamiliar
blocks retain literal search. Ambiguous literal code replacements are refused
atomically and remain editable in Source.

Suggested next task: semantic search/navigation inside tables and callouts,
including precise cell/line highlighting. The owner's latest continuation request
authorizes continuing directly into that separate task after completion.
