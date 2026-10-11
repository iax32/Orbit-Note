# Apple modern theme foundation — 2026-10-05

## Scope

Orbit's existing semantic theme system now carries a consistent modern product
language across framework-owned controls. This is the foundation layer for the
larger app-wide visual refinement: calm surfaces, clear hierarchy, deliberate
touch targets, and restrained focus feedback while keeping Orbit's own graphite,
violet, and theme-family identity.

## Delivered

- Added shared app-bar tokens with flat, content-first surfaces and no automatic
  elevation tint.
- Added consistent NavigationBar and NavigationRail tokens for selected,
  unselected, label, and indicator states.
- Added a common bottom-sheet language with the same panel surface, border,
  dialog radius, and restrained scrim.
- Added shared divider and progress-indicator tokens so framework controls do not
  introduce unrelated colors or thicknesses on individual screens.
- Kept all user-created theme packs, color overrides, typography choices,
  compact density, and UI zoom behavior intact.

## Validation

- Full Flutter suite: 1,259 tests passed.
- `flutter analyze --no-pub`: clean.
- Strict Dart formatting: clean.
- Windows release build succeeded in 113.0 seconds:
  `build/windows/x64/runner/Release/orbit_note.exe`.

## Boundary

This pass establishes the shared framework language. Feature-specific inspector
and side-panel composition remains the next focused pass so existing workflows,
stored data, and object identity stay unchanged.
