# Shared semantic colors and Orbit defaults

Started 2026-10-22; validated 2026-10-23.
Owner-authorized LAY-01/06/09/10 continuation, in the current worktree.

## What changes

- Orbit Graphite has eleven differentiated surfaces, warm readable text and a
  restrained violet accent. Canonical `OrbitColors()` and the default pack agree:
  background #141418, workspace #19191E, panel #1D1D23, text #F2F0F7,
  accent #B0A0FF. No content migration is involved.
- All 113 built-ins, including the 13 originals, receive the same semantic
  foreground contract. Preserve non-default surface identity, metadata, font
  choices/corners and IDs. Primary text targets 7:1; secondary/muted/accent,
  links/statuses 4.5:1; focus 3:1 on eleven actual state surfaces. Decorative
  lines and disabled states are not ordinary-text targets.
- New/missing/invalid accent preferences use Follow theme. Saved explicit
  violet/rose/etc. stay selected; rendered accent/hover shades adapt within the
  same hue for readability. Exact custom-role overrides still win afterward.
- Shared Material text, input backgrounds, floating menus/dialogs, focus borders,
  filled ink and error/status tints follow the semantic palette. Bare light
  ThemeData fallbacks use light ink/surfaces rather than graphite.
- Collections, tasks, priorities, graphs/local context, calendars, dashboards,
  navigation, history/stats, editor controls and LaTeX screens use shared roles.
- Rich/Read callouts, highlights and warnings use the same role vocabulary.
  Code and LaTeX syntax follow the current family. Code parsing is cached
  independently from color spans so palette animation does not retokenize text.
- Interactive Canvas, PNG previews, minimaps, grid and selection/search markers
  receive the palette. Semantic-only changes invalidate cached pictures and
  trigger repaint. A paper-only publication renderer keeps its explicit scheme.
- Recovery color controls follow the effective base family separately from
  overrides, with a readable fallback. Bright swatches, room/goal buttons,
  checkbox ticks, focus timers and collaborator names use contrasting fill ink.

## Compatibility and boundaries

No schema/dependency, storage authority, cloud/account or document changes.
Explicit theme/role values, unknown fields, old sessions and Spaces remain.
Authored note covers, folder colors, drawing ink/scene colors, PDF highlights,
blueprint paper/white pen, writing designs and publication paper remain explicit
content/design choices. Content may intentionally contain an older accent.
Google's branded sign-in button keeps its external branding; collaborator colors
retain stable identity. Shadows remain neutral.

The UI Color Rules Explained chat exposed only a content-reference placeholder
for its answer. Exact rules could not be read. This task applies the documented
surface hierarchy, restrained accents and measured contrast; it does not claim
that inaccessible text was read. Earlier primary guidance is linked in the
[palette task](appearance-palettes-2026-10-22.md).

## Regression and visual evidence

Nine new behavior regressions cover all built-ins/preset accents, actual Material
roles, default/legacy/custom round-trips, bare light/dark contexts, same-mode code
and LaTeX updates with selection/IME preservation, Rich/Read callouts, recovery,
Canvas/minimap/grid pixel-cache invalidation and actual app/graph palette changes
while durable Markdown bytes remain exact. Existing palette/system/formatting
suites provide additional coverage.

- `dart format lib test`: clean across **737 files**; strict format check also
  clean (0 changes).
- `flutter analyze --no-pub`: **no issues**, 10.3 sec.
- Focused palette/default/system/recovery/callout suites: **94 passed**, 19 sec.
  Initial checks exposed obsolete raw-color expectations and a light/dark test
  that asserted during Theme animation; assertions now check the intended
  readable semantics and settled appearance.
- Complete `flutter test --no-pub --concurrency=2`: **2,946 passed, 2 existing
  skips**, 13:44. Skips: native symlink creation needs OS permission; the real
  Google acceptance test needs interactive consent/synthetic uploads. Neither
  was bypassed or represented as passing.
- Real Segoe UI, Consolas and Material icon fonts loaded into a headless actual-
  component render at 1.5x: default, Sage light and Cobalt dark visually reviewed.
  Buttons, statuses, editable callouts, code tokens, checkboxes, switches and
  Canvas surfaces/grid/selection are readable and fit. Preview:
  `build/previews/orbit-semantic-colors.png`. The initial audit harness was
  enlarged to fit its sample content and given the actual monospace font rather
  than Flutter test glyphs; these were harness issues, not app data mutations.
- Targeted `git diff --check`: clean.

- Configured Windows release and matching standalone host built successfully;
  Flutter Windows compilation took **84.6 sec**. Neither executable was started.
- **883** frozen source/test/asset/platform/tool/config inputs unchanged; seven
  runtime/host files present, all **13** packaged font hashes match, and the
  registered Google desktop client is embedded in the AOT payload. Verification
  prints presence only and does not publish configuration values.
- Standard JavaScript web release built successfully in **83.2 sec**. Existing
  Google Identity SDK Wasm dry-run incompatibility and missing Cupertino font
  warnings remain. This validates the JavaScript target, not WebAssembly.
- Runnable Windows app: `build/windows/x64/runner/Release/orbit_note.exe` with its
  sibling runtime/data files. No ZIP or external publication was produced.

## Remaining limitations and next task

This is not a claim of full-app WCAG certification. Arbitrary custom overrides,
authored text/imagery and independent writing/PDF themes can choose different
contrast. Native platform rendering, physical mobile devices, browser assistive
technology and screen-reader acceptance have not been exercised in this pass.
No desktop control, app/host launch, private Vault/account work, publication,
APK rebuild or shutdown is part of this task.

Suggested next task: audit focus/hover/selected/disabled controls and high-contrast
behavior on actual native Windows and mobile devices. Stop before implementing it.
