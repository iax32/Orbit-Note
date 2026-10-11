# Table and multiline clipboard repairs — 2026-10-01

Owner accepts the suggested audit of Rich table editing and multiline clipboard
operations. Scope: EDT-02/03/04/06/11 source preservation, cell/row lifecycle,
keyboard and menu paste, delayed clipboard safety and shared history. Existing
performance improvements, features, animations and unrelated work are retained.
No desktop automation, packages, persistent format changes or migrations.

## Findings and implementation

Seven initial headless reproductions failed before repair:

- Editing one cell normalized every table row's spacing. MarkdownTable now keeps
  the original line and cell spans with each original row. Cell edits splice only
  changed content; row insert/delete retains surviving row spelling. A changed
  column shape uses existing standard Markdown encoding. No-op encoding returns
  original lines; untouched rows avoid new boundary parsing.
  The final correction also preserves each original line ending and the authored
  trailing whitespace, including mixed LF/CRLF tables.
- A literal backslash before a pipe could expose a delimiter, break table parsing
  or lose content on mode changes. Pipe encoding/decoding handles complete runs
  of backslashes. Cell boundaries recognize balanced matching backtick runs and
  leave unmatched backticks literal. Unchanged unknown cell text remains intact.
- Removed rows retained controllers with old text, which reappeared when Tab
  created a row at that coordinate. Synchronize removed cells to empty, unfocus
  invalid targets and clamp row/column state. Keyboard focus updates the active
  cell; deferred focus requests cannot follow a newer table revision.
- Delayed TSV paste checked source but ignored moved selection. Capture the cell
  value, selection, row/column, source, local revision and request number; reject
  stale responses and keyboard paste after focus leaves the cell. Plain cell
  paste keeps caret/selection replacement behavior. Empty clipboard is a no-op.
- Clipboard read failures escaped as unhandled errors. Table read/copy and prose
  paste report a recoverable message and leave content untouched.
- Collapsed and selected multiline prose paste changed source but retained one
  editing field. Reparse the affected block when the edited range changes line
  boundaries, including equal newline counts and newly empty soft lines. Focus
  the resulting caret. This also works in prose beside an inline equation; math
  and surrounding references remain unchanged. Adopt the document's LF/CRLF for
  pasted prose, while raw blocks retain clipboard text.

Additional hardening found during expanded coverage:

- Table redo could match the last locally emitted source and skip synchronization
  after undo. Clear the emission acknowledgement on an external/history update;
  redo restores both the source and cell fields.
- Context-menu Paste now shares keyboard paste behavior in tables and prose.
  Tables accept TSV/line-separated rows with existing 1,000-row/50-column limits;
  oversized input is refused atomically. CRLF and CR-only clipboard rows normalize
  correctly. Prose keeps selected-label URL paste and image fallback; clipboard
  races cannot replace later typing. Composition retains its existing protections.
- Table keyboard commands also recognize Cmd; centered alignment recognizes valid
  longer separator spellings, preserving their authored source.
- A new collapsed-paste route initially dropped a pending typing style. A focused
  regression reproduced it before correction. Clipboard text now uses the same
  text-editing path as typing, preserving pending/inherited marks and explicit
  formatting exits. Selected-label URL insertion keeps its dedicated behavior.

## Validation

- Initial `.local/table-clipboard-baseline.log`: seven reproduced failures.
- New table/clipboard file: **19 passed**, including mixed endings and typing-style
  preservation. Combined rich widget/visual,
  boundary and structural safety suite: **73 passed**.
- Final `flutter analyze --no-pub`: clean (25.8s).
- `dart format lib test` and final strict no-change formatting: clean (350 files).
- Scoped `git diff --check`: clean; unrelated work preserved.
- First full suite: 1,086 passed before the final mixed-ending correction. A later
  run also reproduced the newly added typing-style failure (1,087 passed, one
  failure) before correction. The repaired editor/clipboard group then passed all
  56 tests, followed by all 19 final table/clipboard checks.
- Final `flutter test --no-pub`: **1,089 passed, zero failures** (4m11s).
- Normal `lib/main.dart` Windows release rebuilt with the existing local build
  configuration (259.3s): `build/windows/x64/runner/Release/orbit_note.exe`.
  The build and suite ran concurrently; these are validation durations, not app
  performance measurements. No review fixture or desktop control was used.

Coverage includes exact table spacing/CRLF, unknown surrounding source, odd/even
pipe escape runs, code spans, deleted-row reuse, delayed selection/focus/edit races,
read/copy errors, actual menu callback routing, oversize refusal, undo/redo cell
state, multiline prose/inline math, equal line counts and whitespace separators.
Headless Flutter input tests are not native OS clipboard/IME acceptance.

## Rich table selection and HTML clipboard follow-up — 2026-10-07

Rich tables now support mouse drag selection in addition to Shift-arrow and
Ctrl/Cmd+A. The selected rectangle is rendered while dragging and uses the same
TSV/CSV copy and grid-paste paths. Rich copy publishes an HTML `<table>` payload
alongside TSV fallback text. The Windows runner accepts that payload through the
`orbit_note/clipboard` channel and writes CF_HTML plus CF_UNICODETEXT; hosts
without the bridge fall back to Flutter's ordinary plain clipboard API.

The follow-up adds regression coverage for pointer drag selection and native HTML
payload shape. The focused table/clipboard/model group passes 44 tests, and the
full Flutter suite passes 1,336 tests. Strict formatting and `flutter analyze`
are clean. A Windows packaging attempt stopped before native compilation because
Developer Mode symlink support is disabled on the validation machine.

The platform parity follow-up routes the same payload through Android
`ClipData.newHtmlText`, iOS `UIPasteboard`, Linux GTK `text/html`, and the web
Clipboard API. Rich bridge rejection, missing plugins, malformed results, and
plain fallback failure are covered by the platform test group. Platform/table
tests pass with 31 tests and the full suite passes with 1,342 tests. Web release
build passes; Android, iOS, and Linux native compilation remain unavailable on
the Windows validation host.

Logs: `.local/table-clipboard-baseline.log`, `.local/table-clipboard-focused.log`,
`.local/table-clipboard-final-focused.log`, `.local/table-clipboard-typing-style-baseline.log`,
`.local/table-clipboard-typing-path-tests.log`, `.local/table-clipboard-complete-tests.log`,
`.local/table-clipboard-complete-analyze.log`, `.local/table-clipboard-complete-windows-build.log`.

Suggested next task: audit find/replace across Rich and Source for formatted text,
selection boundaries and exact shared undo; stop before that pass.
