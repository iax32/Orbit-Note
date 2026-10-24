# One hundred coordinated palettes — 2026-10-22

## Request and provenance

Owner requested reading **UI Color Rules Explained**, then adding 100 light/dark
design colors. The app reader exposes the question about professional UI palette
composition; its answer remains only a `chatgpt-content-reference`, including
after requesting the full available turn. Its exact rules were **not available**.
We do not claim to have read or reproduced them. No messages were sent to that
chat and no desktop/browser control was used to obtain private content.

Implementation instead uses these primary references:

- [Apple: Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
  for semantic surfaces and mode-specific elevation/contrast.
- [Apple: Color](https://developer.apple.com/design/human-interface-guidelines/color)
  for restrained accents and consistent semantic meanings.
- [W3C: text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
  and [non-text contrast](https://www.w3.org/WAI/WCAG21/understanding/non-text-contrast.html)
  for readable foregrounds and identifiable focus/control states.

These guidelines inform this implementation, not a certification of all app
content, legacy/custom themes or user-authored document colours.

## Scope and use

LAY-01/06/09/10 subset. **50 families × light/dark = 100 new complete palettes**,
with all 13 prior packs retained (113 built-ins total). Eight collections cover
Studio, Ocean, Forest, Earth, Botanical, Sky, Warmth and Creative styles.
Named recipes specify different neutral paper/night foundations and accents;
the modes are independently contrast-adjusted, not RGB inversions. All existing
semantic roles resolve together, including Canvas/graph backgrounds. Knowledge
ink, PDF paper and independent writing-surface designs retain their own settings.

Settings → Appearance → Customize interface colors → Theme packs, or Theme Gallery:
search name/description, filter light/dark and collection, page through at most
six cards, Show active, and switch directly to a family's other mode. Empty
results and long/large text keep controls reachable in the existing scroll owner.
Gallery custom-theme management/import/export remains available. Existing IDs,
theme JSON and custom themes remain compatible; no knowledge migration/package.

The real app previously replaced any pack accent with its separate accent preset.
New selection sets **Follow theme**; a saved `theme` value now survives session
reload. Existing explicit accent choices keep working. Filled Material controls,
selected checks and preview badges choose black/white ink by actual contrast.
New families preserve document/UI fonts and corners; original/custom style-pack
behavior remains. Legacy default preferences are unchanged.

Explicit custom color overrides remain visible and preserved in the small
selector. **Use palette colors** removes recognized overrides, retains unknown
roles and offers guarded Undo. Full Gallery **Apply** uses the chosen pack's
colors, preserving unknown override roles. No user's live preferences were changed
by development/tests; all repositories used synthetic memory or isolated fixtures.

## Contrast and compatibility boundaries

For each new palette, ordinary/subtle/muted text, links, accent/secondary/hover and
status foregrounds are tested at ≥4.5:1 against 11 actual surfaces, including
selection, input, hover, pressed and floating. Main text meets ≥7:1; focus ≥3:1.
Filled primary/secondary/error ink meets ≥4.5:1. Decorative separators, grids,
edges and disabled controls have distinct subdued tokens; they are not all
required to meet the text criterion. Status is still conveyed by existing labels
and icons, not exclusively colour.

All generated tokens use opaque 8-bit values so portable JSON round-trips exactly,
including values near contrast thresholds. Old default IDs/values and unknown
override roles retain compatibility. Individual exported theme files contain all
role values and explicit brightness; older clients can read those existing fields.
Pair/collection metadata is catalog presentation, not a new authored format.

## Validation

Final focused matrix: **42 passed** (5 sec), including **11 new regressions**.
`dart format lib test` and strict no-change formatting pass across **734 files**;
`flutter analyze --no-pub`: **no issues**, 8.5 sec.
`flutter test --no-pub`: **2,926 passed, 2 existing skips**, 5:49.
Configured Windows app and matching standalone host built successfully
(`tool/build_windows.ps1`, **81.1 sec** for the app). Standard JS web release
built successfully (**79.2 sec**). Existing SDK Wasm dry-run interop and missing
Cupertino-font warnings remain; this does not claim Wasm compatibility. Android
was not rebuilt for this appearance update; its SDK remains unavailable.
Focused checks
cover all 100 palettes and 50 pairs, 13,500 foreground/focus/filled-control contrast
comparisons, JSON/session restart, actual app accent resolution, custom accent
choices, bounded paging/search/collections, reset/Undo with unknown roles,
Gallery application and 200% text at 360 px. Existing import/export/generation/
custom-theme recovery tests remain included. Real-font headless palette sample
rendering is reviewed locally; no desktop-control testing or app launch.

Eight real-font semantic samples (Sage, Atlantic, Clay and Lavender, both modes)
rendered successfully in a separate headless harness with Segoe UI and Material
icons. The inspected preview is `.local/palette-audit/palette-preview.png`.
It shows actual ThemeData/semantic token samples, not a desktop screenshot or a
claim of physical-display testing. A convenient copy is
`build/previews/orbit-palette-preview.png`.

**880 frozen implementation/test/platform/asset inputs remained unchanged**
through packaging. Seven runtime/host files are present and hashed; all **13**
authored fonts match their packaged bytes; the registered Google desktop client
remains in AOT. New catalog/browser strings (Porcelain, Silverline, Sage Garden,
Mulberry, Follow theme, Find a palette) were verified in the compiled payload.
`git diff --check` passed. No app/host launch, desktop control, account transfer,
private Vault changes, publication, dependency addition or shutdown occurred.
All prior uncommitted work remains.

Runnable Windows release: `build/windows/x64/runner/Release/orbit_note.exe`, with
its sibling runtime files. Logs: `.local/palette-focused-final.log`,
`.local/palette-full-final.log`, `.local/palette-analyze-final.log`,
`.local/palette-format-strict.log`, `.local/palette-visual-audit.log`,
`.local/palette-windows-build.log`, `.local/palette-web-build.log` and
`.local/palette-release-verification.json`.

Next suggested task: optional system-driven light/dark switching between paired
palettes. Do not implement it as part of this catalog task.
