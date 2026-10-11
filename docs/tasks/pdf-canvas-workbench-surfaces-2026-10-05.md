# PDF and Canvas workbench surfaces — 2026-10-05

## Scope

The PDF reader and Canvas editor already had the required navigation, reading,
drawing, selection, import/export, and research actions. This pass gives those
controls a shared visual surface so the two workbenches feel like part of the
same Orbit product instead of separate toolkits.

## Delivered

- Added `OrbitWorkbenchToolbar`, a semantic graphite toolbar surface with quiet
  top/bottom dividers, consistent minimum height, and theme-aware secondary
  labels.
- Applied the surface to the PDF reader with a `PDF reader` context label and
  document icon. The existing horizontal scrolling toolbar, keyboard shortcuts,
  page controls, zoom, search, annotations, forms, and research actions are
  unchanged.
- Applied the same surface to Canvas with a `Canvas` context label and the
  existing horizontally scrollable tool groups. Selection, authoring, drawing,
  search, insertion, history, and arrangement actions remain unchanged.
- Labels collapse below 560 logical pixels so narrow panes retain the full
  control strip and do not force a second horizontal layout.

## Validation

- Focused PDF/Canvas regressions: 38 tests passed.
- Full Flutter suite: 1,259 tests passed.
- `flutter analyze --no-pub`: clean.
- Strict formatting for the changed files: clean.
- Windows release build succeeded in 87.3 seconds:
  `build/windows/x64/runner/Release/orbit_note.exe`.

## Boundary

This is a toolbar and document-surface pass. PDF side panels, Canvas inspector
composition, and deeper responsive pane choreography remain separate follow-up
work so this change stays reversible and does not alter stored data or object
identity.
