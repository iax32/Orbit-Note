# Custom-font clarity and reading comfort — 2026-10-03

## Request / observed causes

User reports fonts such as Times New Roman looking low quality and requests a
more comfortable reading/editing experience. Code inspection found that Rich block
cache invalidation omitted fontFamily, so live switches could leave stale fonts;
Rich ignored the line-height preference; table/callout/aligned Read text used
different fixed styles. Serif headings/controls inherited semibold/medium weights
and compressed heading letter spacing chosen for Segoe UI.

These are confirmed application-level issues. Native monitor glyph rasterization,
ClearType, DPI driver behavior and the user's exact visual symptom are unverified;
this pass does not replace Flutter's renderer or claim a native visual comparison.

## Delivered behavior

- Font-family and line-height changes invalidate Rich block widgets without
  reparsing source or resetting retained prose controllers/selections.
- Shared NoteTypography supplies explicit regular body weight, zero tracking,
  family-appropriate fallback fonts, selected size/spacing, all six heading levels,
  table and quote/list styles. Serif headings use bold (700), sans headings retain
  semibold (600). Heading line-height is 1.3; body preserves the user's preference.
- Rich prose, inline-math prose, table fields and callouts receive the shared
  document style. Source uses the same body style. Read includes aligned blocks,
  callouts, tables and every heading level rather than inheriting unrelated UI
  heading sizes/fonts. Code/math keep their specialist fonts and engines.
- App theme respects selected families but uses regular control weights and normal
  heading tracking for Times New Roman/Georgia, avoiding requests for intermediate
  serif weights. Existing Segoe controls, semantic colors and animations remain.
- Callout accent uses positioned decoration around naturally sized content rather
  than an IntrinsicHeight/stretch row; long headers at narrow widths no longer
  constrain the body incorrectly when typography changes.
- Settings shows a live reading preview at the selected family/size/spacing and
  recommends trying 18–20 px for serif reading. No automatic size rewrite or bitmap
  scaling, sharpening filter, font download or glyph-outline trick is introduced.
- Persistent Markdown, object metadata and preference formats are unchanged.

## Validation

- `dart format lib test` completed; strict check: 364 files, zero changes
  (`.local/font-strict-format.log`).
- `flutter analyze --no-pub`: no issues, 11.0s
  (`.local/font-final-analyze.log`).
- `flutter test --no-pub`: all **1,186 passed**, 1m29s
  (`.local/font-full-tests.log`).
- Normal Windows release rebuilt successfully (53.6s,
  `.local/font-windows-build.log`), `build/windows/x64/runner/Release/orbit_note.exe`.
  Not launched; no native visual inspection claimed.
- Scoped diff check clean apart from CRLF normalization notices; three existing
  trailing spaces in unrelated workspace-view template source are preserved.

Focused font/notes/layout/Read search/callout/table/settings run: **77 passed**
(`.local/font-focused.log`), including three new behavior checks for live family/
spacing changes with selection preservation, all Read/structured styles, and
high-DPI + enlarged-accessibility layout. Existing font selection test also checks
the Settings preview. Ahem/headless test fonts do not prove native Times glyph
raster quality on the user's display.

Initial test harness mistakes (wrong NoteEditor parameters/missing test filename)
were corrected. Enlarged callout text exposed an intrinsic-layout overflow; repaired
and rerun. Settings tests now scroll to lazy analytics children before asserting
them because the reading preview adds content. No assertion was weakened.

No desktop/computer-use automation; no screenshot of the user's apps, test window
or native review session. Full suite and rebuilt executable are recorded below.

## Next task

Improve long code-block/table readability at enlarged text sizes without changing
source or adding a competing editor renderer.
