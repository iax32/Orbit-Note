# Table and callout search navigation — 2026-10-01–02

Owner requests continuing directly with the next useful change after the
find/replace pass. Scope: EDT-04/06/11/12/13 exact table/callout search navigation,
source-preserving replacement and shared undo. Spec map, EDT backlog rows and
Markdown editing contract consulted. No desktop automation, packages, storage
changes or migrations.

## Changes

- Rich/Read search table editing-cell text rather than alignment rows or boundary
  pipes. Decode escaped literal pipes with UTF-16 source boundaries, preserving
  complete backslash runs. Source/Split retain literal whole-source search.
- Table navigation selects the exact cell range and scrolls the selected row/cell
  into view, then returns focus to Find. Existing pipe/backtick cell boundaries
  are reused; cell Markdown delimiters remain literal, as in its editing field.
- Callout search indexes authored titles and body text, excluding type syntax and
  quote prefixes. Source coordinates retain CRLF and per-line prefixes. Matches
  can span body lines. Header matches receive a visible highlight; body matches
  select exact field text.
- Find captures the live cell/callout selection, rather than a stale prose caret.
  Selected cell text seeds the visible query, and multiline callout selections
  establish source-bounded scope without including the title or following prose.
- Structured replacements verify resulting visible text and use shared history.
  Cell replacements escape literal pipes. Callout body replacements preserve
  unknown type names, header spacing, body whitespace and untouched line endings.
  Unsafe newline insertion into cells/titles refuses the whole batch with the
  existing Source fallback; it never emits a partial replacement.
- Callout typing/type changes now splice their owning source instead of rewriting
  the whole block through canonical Markdown encoding. New body lines use the
  callout's LF/CRLF convention. Inserting complete lines retains an existing
  line's original quote prefix. Header-only callouts can accept new body text.
  Editing/deleting an authored unquoted blank line retains quote ownership for
  newly nonempty body lines, including the leading-line Backspace case.
- Callout keyboard undo/redo joins document history and protects composition.
  External/history updates synchronize focused fields, and local acknowledgements
  preserve ongoing typing. Clear the acknowledgement on external updates so redo
  cannot be mistaken for the last local emission.
- Preserve table/callout block/controller identity on compatible source reloads,
  as previously done for equations. Retained structured fields keep their focus
  and clamp selection through history; prose jumps cannot move the caret to an
  unrelated paragraph or the first table cell. Structural removal retains the
  existing valid fallback.
- Long callout titles use the available header width and wrap with their type
  control reachable in narrow notes.

## Validation

New test file covers pure source mapping and widgets: exact cell/body/title
selection, escaped pipes/backslash parity, boundary scope, multiline callout
mapping, no-op/unknown-data preservation, atomic refusal, source-exact shared
undo/redo, focused history beside other paragraphs, distant-row scrolling and
narrow header layout.

Intermediate tests caught and corrected quote-prefix movement, callout local undo
routing and leading blank-line deletion detaching the body. The first full suite
passed 1,129 tests; analyzer found four style issues, now corrected. The normal
Windows build succeeded (126.8s). Final source adds the blank-line ownership and
live selection checks and is verified again below.

- New file: 22 pure/widget regressions.
- Expanded Rich/widget/visual/clipboard/search/callout checks: 109 passed.
- Final full suite: **1,133 passed** (3m28s), recorded in
  `.local/structured-search-final-full-tests.log`.
- Three remaining brace-only lint warnings were corrected after the full suite.
  Final analyzer: clean (28.7s), `.local/structured-search-clean-analyze.log`.
  `dart format lib test` and strict no-change formatting: clean (354 files).
- The full-suite source built successfully for Windows (176.0s),
  `.local/structured-search-final-windows-build.log`. Final brace-only source
  rebuild also succeeded (96.5s), `.local/structured-search-clean-windows-build.log`.
  The final new-file rerun passes all 22 tests (12s),
  `.local/structured-search-clean-focused.log`. These brace changes do not alter
  behavior; the full suite above verifies the final functional implementation.
- A final retry refreshed dependencies and removed generated Windows plugin
  links; tests reported missing symlink support and CMake reported missing plugin
  sources. Restored workspace-local junctions to the existing cached packages
  and retried with `--no-pub`. No system setting or dependency version changed.
- Scoped `git diff --check`: clean. Task completed 2026-10-02.

## Follow-up validation — local structured source authority, 2026-10-07

Table/callout selection and edit callbacks now use the structured child's latest
local emission when the parent widget has not rebuilt yet. This closes a race
where changing a callout type and immediately typing body text could restore the
old type or use old source coordinates. The new regression exercises that exact
sequence and preserves the authored title, spacing, body, and CRLF ending.

- Structured table/callout suite: **23 tests passed**.
- Full Flutter suite: **1,345 tests passed**.
- Strict formatting, `flutter analyze --no-pub`, and `git diff --check`: clean.

## Limits

Native clipboard/IME acceptance remains unverified; user requests no desktop
automation. Read navigation is approximate and does not select rendered matches.
Table/callout inline Markdown is searched literally, matching their editing
fields; this is not a new inline-rich table/callout editor. Equations and unfamiliar
raw blocks keep literal source search. Cell/title newline replacement is refused
atomically; ordinary editing and Source remain available. Unknown callout types
keep their authored source and use the existing generic visual fallback.

Suggested next task: exact search navigation inside code blocks, retaining fences
and source. No implementation of that additional scope in this evidence.
