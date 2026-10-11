# App zoom and development workspace readability — 2026-10-03

## Changes

- Whole Navigator zoom scales panels, controls, icons, text and dialogs while
  laying out the smaller logical viewport. Insets/effective pixel density follow
  zoom; OS text scaling remains independent. Stable subtree preserves selection.
- Ctrl +/=, numpad plus enlarge; Ctrl minus/numpad minus reduce; Ctrl 0/numpad
  zero reset. Meta equivalents supported. Early keyboard handling prevents a
  focused editor/canvas from also consuming these shortcuts. Local wheel/pinch
  canvas and PDF gestures remain unchanged.
- Settings offers 75%, 90%, 100%, 110%, 125%, 150%, 175%, 200%. Flat device-local
  `uiZoom` defaults to 1 for old sessions, bounds persisted values and retains
  unknown fields. Document font size/source/history are unaffected.
- Game dashboard gains a bounded reading width, wrapping GDD action, responsive
  metrics and stacked production/material sections. Task/bug dialogs scroll,
  reject blank Enter submissions and dispose controllers after route completion.
- Research dashboard gains a calmer wrapping header, responsive metrics/actions,
  wrapping hypothesis chips and stacked sections. Missing metadata is unrecorded
  rather than invented; function count excludes other address-bearing records;
  empty hypothesis status falls back to Open.
- Function/finding/hypothesis creation shares the validated form with optional
  build/address context and evidence, without fake addresses or module names.
- Function browser exposes status/confidence/module filters including imported
  values and a result count. Toolbar wraps; readable table columns retain lazy
  vertical rows and a draggable horizontal scrollbar for copy/open actions.

## Validation

68 focused checks passed; six zoom/layout checks passed again after scrollbar
refinement. All 1,192 tests passed (1m37s); analyzer clean (10.1s); strict
formatting checked 368 files with zero changes. Normal Windows release build
passed (56.0s), using the existing build configuration and `--no-pub`.
Logs: `.local/zoom-focused.log`, `.local/zoom-layout.log`,
`.local/zoom-full-tests.log`, `.local/zoom-final-analyze.log`,
`.local/zoom-strict-format.log`, `.local/zoom-windows-build.log`.
New checks cover physical scaling/hit testing, selection/dialog/reset behavior,
accessibility scale/insets, old/invalid settings and 200% development layouts.
Headless checks do not establish native monitor raster quality. No desktop
control, live launch or review window was used.

Scoped diff whitespace check is clean. Existing unrelated whitespace in
`workspace_views.dart` is retained; no whole-file cleanup was performed.

## Boundaries / next task

Local readability refinement of LAY-01/10, GAME-01–03 and REV-02–04 subsets.
Custom registries, authenticated team sharing and live tool connectors remain
separately scoped. Suggested next: validated editing of existing research
build/address/evidence fields in the inspector.
