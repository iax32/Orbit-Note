# Read-mode search highlights — 2026-10-03

Owner requests continuing useful features without controlling the desktop.
Scope: EDT-03/04/13 transient Read highlights and navigation using actual text
geometry. Markdown editing contract and code-search evidence consulted. No
packages, migrations, storage changes or desktop review window.

## Changes

- Keep the full-document Markdown renderer, selectable text, links, images,
  bionic reading and custom builders. A foreground decoration highlights all
  in-scope rendered matches; the active match has stronger fill and an outline.
  Search never inserts markup or saves rendered content.
- Map selectable paragraphs/headings/cells and read-only code fields to source
  search results in document order. Verify both occurrence counts and owning
  segment text (normalizing only whitespace). A mismatch suppresses decoration
  and retains existing approximate navigation; equal counts alone are not enough.
- Next/Previous reveal the active text box through the actual note/code viewports,
  including distant lines and horizontal columns. Find keeps its keyboard focus.
  Inner horizontal scrolling updates painting without parsing/matching again.
  Clip decoration to nested viewport/clip bounds.
- Cache visible segment text and verify each source/rendered segment pair once
  per collection, avoiding repeated whole-paragraph normalization per occurrence.
- Use existing case, Unicode whole-word and selection-scope rules. Clear highlights
  for an empty/missing query, closed Find or mode change. Deferred navigation checks
  source/query/mode and ignores stale requests.

## Validation

- New `test/read_search_test.dart`: ten widget regressions cover formatted prose,
  links/headings, long-note geometry, horizontal/vertical code navigation,
  case/Unicode boundaries, close/zero/mode cleanup, plain tables, custom fallback
  equal-count/different-segment refusal and 1,000 matches in one paragraph.
- Initial checks found zero-match decoration retaining an empty painter; corrected.
  A test also used a nonexistent close tooltip; corrected to the existing control.
- Focused suites before the cache addition: 67, then 69 passed.
- Initial analyzer found one unnecessary test import, removed. A concurrent
  focused-test retry encountered a locked generated `pdfium.dll` while the full
  suite was running. Final checks are sequenced to avoid concurrent test hooks.
- Full suite: **1,159 passed** (3m18s), `.local/read-search-full-tests.log`,
  including the large-match regression added during verification. Final focused
  rerun after cache/import cleanup: **70 passed** (18s),
  `.local/read-search-complete-focused.log`.
- Final analyzer: clean (21.2s), `.local/read-search-complete-analyze.log`.
  `dart format lib test` and strict no-change formatting: clean (358 files).
- Initial normal Windows build succeeded (150.0s). Final release rebuild including
  cached segment verification succeeded (83.3s), original local build configuration
  retained, `.local/read-search-complete-windows-build.log`.
- Scoped `git diff --check`: clean. Task completed 2026-10-03.

## Follow-up validation — Read-mode fenced-code parity, 2026-10-07

Read-only fenced code now carries authored body text into the search overlay.
Multiline queries normalize CRLF to LF only for matching the displayed code;
language/info metadata stays excluded and source text remains unchanged. Find
accepts multiline pasted queries. Unicode folded matches continue to map to
exact code/prose ranges, reveal the active viewport, and retain Find focus.

- Added LF/CRLF multiline code, metadata exclusion, folded Unicode across prose
  and multiple code blocks, source preservation, and focus regressions.
- Read/code focused suite: **63 passed**.
- Full Flutter suite: **1,350 passed** (`.local/read-code-search-final-full.log`).
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-07.

## Limits and next task

Only automated source/widget checks are used; native desktop/IME input is not
tested. Custom builders that hide/reinterpret source, nonselectable text and
unmapped raw/LaTeX output keep approximate search navigation. A mismatch anywhere
in the query's rendered occurrences conservatively disables exact decoration for
that query instead of guessing individual correspondence. Full-paragraph context
can also reject legitimate unusual renderer normalization. Existing heading/
outline navigation remains unchanged.

Suggested next task: reliable link and attachment opening inside Read callouts.
