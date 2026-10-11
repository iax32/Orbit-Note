# Precise code-block search — 2026-10-02

Owner accepts the suggested code-block search task. Scope: EDT-02/03/04/06/13
code-body search, exact selection and scrolling, live selection scope, fence-safe
replacement and shared history. Markdown editing contract and preceding
table/callout evidence consulted. No desktop automation, packages, migrations or
storage changes; preserve prior structured-field/performance work.

## Changes

- Rich/Read index literal fenced code contents, excluding opening/closing fences
  and language/info labels. Source/Split continue to search complete raw source.
  Unclosed fences remain recoverable literal raw blocks. UTF-16 source positions,
  Unicode whole-word boundaries and selection filtering use the existing index.
- Rich Find selects the exact code range, including across multiple code blocks.
  The selected caret scrolls both the horizontal code viewport and note viewport;
  Find keeps focus for Enter/Previous/Next. Live code selections seed queries and
  capture scopes, including notes with preceding prose.
- Code edits and search replacement share a pure fence-preserving operation.
  Keep info labels, indentation, spaces and LF/CRLF. Grow only fence runs when a
  body line would close the block; keep an already-longer closing fence. Ordinary
  delimiters inside code remain literal. Surrounding blocks are unchanged.
- Single Replace computes the actual replacement endpoint, excluding closing
  fence growth after it. Navigation waits for Rich to receive the new source
  when block identity changes, then selects the next range and restores Find.
  Deferred navigation ignores a changed source/query/mode or closed Find.
- The replacement field accepts multiline text (shows up to three lines), rather
  than silently deleting pasted newlines. Code replacement remains one shared
  history operation. Existing unsupported table/title batches still refuse
  atomically and offer Source.
- Retain compatible ordinary code fields on source/history reload and preserve
  both selection endpoints, including backward ranges. Fence shape changes restore
  a valid code selection/focus; composition guards remain in place. Embedded
  view/snapshot fences retain their existing widget lifecycle.

## Validation

- New `test/code_search_test.dart`: 16 pure/widget regressions for source mapping,
  Unicode/scope, metadata exclusion across modes, CRLF and fence preservation,
  delimiter-line replacement/typing, exact undo/redo, backward selections,
  multi-block navigation and distant-line/horizontal scrolling.
- First run: 11 passed, two failed. Corrected the multiline field's automatic
  newline stripping. A mixed fixture also inserted a new fence into plain prose;
  changed that fixture to test untouched prose alongside code-owned replacement.
- Expanded focused suite: 106 passed (32s),
  `.local/code-search-complete-focused.log`.
- Initial full suite: 1,148 passed (4m04s), analyzer/strict formatting clean;
  normal Windows build succeeded (209.2s). A subsequent dedicated test reproduced
  invalid next-match selection after fence growth. Corrected stale-layout
  navigation and replacement caret accounting; the final focused suite above
  includes that regression. No final-source change after its completion other
  than equivalent arithmetic simplification and formatting.
- Final analyzer: clean (51.6s), `.local/code-search-complete-analyze.log`.
  `dart format lib test` and strict no-change formatting: clean (356 files).
- Final normal Windows release rebuilt successfully (253.0s), original local
  build configuration retained, `.local/code-search-complete-windows-build.log`.
- Final full suite: **1,149 passed** (4m19s),
  `.local/code-search-complete-full-tests.log`.
- Scoped `git diff --check`: clean. Task completed 2026-10-02.

## Follow-up validation — structural callback race, 2026-10-07

Fenced-code callbacks now recover the current code block by stable document
position after a delimiter edit grows the fence and replaces the parsed block.
This preserves a second input event delivered before the next parent rebuild,
including the new body line, fence shape, language info, and source-exact undo.

- Code-search suite: **18 tests passed**.
- Full Flutter suite: **1,346 tests passed**.
- Strict formatting, `flutter analyze --no-pub`, and `git diff --check`: clean.

## Limits / next task

No native keyboard/IME/clipboard automation was performed. Tests exercise Flutter
widgets and source behavior. Read navigation remains approximate without precise
rendered-match selection. Dynamic view/snapshot fences can be searched as source
contents, but do not expose an ordinary code editing field for exact Rich selection.
Unclosed/raw blocks retain literal search and existing fallback navigation.

Suggested next task: rendered-match highlighting and precise Read-mode scrolling.
That additional scope is not implemented here.
