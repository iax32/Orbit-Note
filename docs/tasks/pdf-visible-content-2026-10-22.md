# Complete visible PDF content — 2026-10-22

Owner request: fully improve Markdown PDF export and keep content visible.
Scoped PORT-05/06/09; preserves previous image recovery and unrelated sync work.

## Changes

- Opt formatted prose, list items, headings and contents into real page-spanning
  layout. Preserve nested list paragraph/code/list order and cap indentation.
- Paginate code using bundled Space Mono, including long unbroken lines/URLs.
- Measure table cells and use labelled records for too-wide/too-tall grids,
  retaining every cell and explaining the format-specific fallback.
- Fit figure width/height with aspect ratio, separate captions so long captions
  can flow at their configured width, and add print spacing around figures/math.
- Capture full natural equation extents rather than a fixed 1000×400 viewport.
  Bound allocation, dispose detached render surfaces, retain complete TeX for
  oversized/unsupported formulas, and include source beside greatly scaled math.
- Keep heading/endnote destinations on the first page, prevent duplicate matching
  title headings, let title pages continue, and separate running text/footers.
- Use bundled Lato symbol fallback for serif publishing; unsupported glyphs remain
  explicitly reported. All original Unicode stays in owning Markdown/HTML/Word.
- Normalize static SVG diagrams through the existing SVG renderer. No scripts,
  remote/embedded subimages, foreign HTML, external CSS/fonts, entities, filters
  or animated content. Bounded output is shared by PDF/HTML/Word. flutter_svg was
  already installed transitively at 2.3.0; now a direct dependency at that version.
- Enforce the 500-page cap in release, reject oversized generation before any
  output save, and propagate a useful error through the publishing workspace.

## Validation

New coverage: 9 native rendering/content tests plus a local-SVG publishing-widget
regression. Includes A4/Letter at 18 pt/90 pt margins; every long prose/list/cell/
quotation/footnote token; page-coordinate bounds; nested ordering; code final lines;
title/contents destinations; bottom-of-figure pixel checks; full equation dimensions;
real bundled math fonts; mixed sans/serif reports; refused SVG active sources; and
501-page failure without output. Existing image/style/HTML/Word tests also run.

Evidence files are synthetic intermediates under tmp/pdfs/ and logs under .local/.
- Focused publishing checks: **42 passed**, including **10 new regressions**.
- Full suite: **2,858 passed, 2 existing skips**, 4 min 37 sec. No new skips.
- `dart format lib test`: 721 files. Strict format: 721 files, no changes.
- `flutter analyze --no-pub`: no issues. `git diff --check`: passed.
- Native PDFium extracts all expected long-content tokens inside page bounds;
  pixel checks confirm the bottom of a tall figure and the local SVG survive.
- Poppler rendering: 14 pages reviewed across serif/sans mixed reports, five-page
  code/nested-list/long-URL stress, four-page portrait figure/caption/math stress,
  and static SVG. Formula fixtures load real bundled math fonts.
- 782 source/test/assets/build inputs frozen; unchanged after final tests.
- Configured Windows release: app compile passed (70.6 sec); standalone host
  rebuilt without launching it or packaging keys. Standard JS web build passed
  (66.3 sec). Existing Google SDK Wasm dry-run/Cupertino-font warnings remain;
  this is not a Wasm acceptance claim.
- Verified seven Windows runtime/host files, fresh AOT and host payloads, and
  33 unchanged font hashes (13 authored faces, 20 bundled KaTeX faces).
- All 782 frozen inputs unchanged after builds. No signing/version/publication
  change. Runtime: build/windows/x64/runner/Release/orbit_note.exe with siblings.

Logs: .local/pdf-visibility-{format,strict-format,analyze,focused,full,windows,web}.log;
input/runtime evidence: .local/pdf-visibility-{source-snapshot,build-verification}.json.

## Limits and next task

This is a presentation snapshot, not a Vault backup. Local originals are unchanged.
Web images still require Load web images and can fail for expired/protected/CORS
sources. Complex SVG, unsupported font glyphs and live workspace controls retain
explicit fallbacks/warnings; full browser/Word/TeX fidelity is not promised. No
private Vault/account, live website, desktop control, app launch or publication.
No Android build requested. Keep all unrelated uncommitted work.

Suggested next task: export resolved Canvas/live-object previews beside their
source links; stop before implementing it.
