# Apple and Obsidian workspace language — 2026-10-05

## Intent

Orbit's shell now follows the interaction language the owner described: a calm,
desktop-first workbench with macOS-style deference and Obsidian-style tabs,
sidebars, and command density. The implementation keeps Orbit's own graphite,
violet, local-first identity rather than imitating another product's branding.

The design choices follow Apple's current macOS, buttons, and toolbar guidance
around clear hierarchy, predictable state, and controls that stay close to the
content they affect. Obsidian's documented workspace model informed the tab and
sidebar structure: tabs persist, can be reordered, and sidebars hold contextual
views.

## Delivered

- Icon-only `OrbitControl` states now use a quiet selected surface without a
  second underline, giving the activity rail a cleaner macOS/Linux workbench
  feel while preserving keyboard focus rings and tooltip semantics.
- The activity rail uses the panel surface as a stable navigation spine. Orbit's
  active edge remains the selection cue, so navigation does not depend on color
  alone.
- Open document tabs now read as a unified document strip: active tabs use a
  raised, rounded surface with a subtle identity edge; inactive tabs remain
  quiet and reveal hover/focus state on demand.
- The tab overflow affordance is separated by a divider and sits in the same
  strip surface as the tabs, making the group read like one desktop workbench.
- Existing pinning, reordering, middle-click close, context menus, keyboard
  shortcuts, tab overflow search, and active-object identity remain unchanged.

## Validation

- Focused controls, shell, tab, PDF, and workspace regressions passed.
- Full Flutter suite: 1,259 tests passed.
- `flutter analyze --no-pub`: clean.
- Strict formatting: clean.
- Windows release build succeeded in 96.0 seconds:
  `build/windows/x64/runner/Release/orbit_note.exe`.

## Boundary

This establishes the shell language. Feature-specific dashboards and the note
editor retain their behavior and can receive the same composition treatment in
separate passes without coupling visual changes to storage or editing logic.
