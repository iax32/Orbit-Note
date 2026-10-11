# Obsidian visual language expansion — 2026-10-05

This pass strengthens the shared Orbit shell and makes theme choice a first-class
part of the product rather than a single dark-mode switch. The goal is an
Obsidian-like workspace language—quiet graphite surfaces, readable hierarchy,
compact tab chrome, and strong vault context—while keeping Orbit's semantic
tokens, offline behavior, and observatory identity.

## Delivered

- Expanded the first-party theme library from five packs to thirteen curated
  families: Orbit Graphite, Observatory Space, Paper Warm Light, Midnight OLED,
  Aurora Forest, Obsidian Ember, Nord Mist, Dracula Velvet, Catppuccin Mocha,
  Rosé Pine, Solarized Paper, Gruvbox Night, and Coastal Light.
- New packs use the same complete semantic token contract as imported and
  generated themes, so notes, canvas, graph, PDF, settings, and shell surfaces
  change together and retain contrast guarantees.
- Applying a theme now applies its intended interface font, document font,
  monospace font, and corner style as one reversible preset action.
- Workspace header now uses a quiet raised workbench strip with a destination /
  document breadcrumb and a discoverable command-palette action (`Ctrl+P`).
- Home now has an editorial period hierarchy on desktop, a compact navigation
  treatment on small screens, and a separate review action when 200% text makes
  the header too narrow.
- Theme cards include miniature workspace previews, making the palette and
  surface hierarchy legible before applying a pack.
- Existing tab, rail, Explorer, gallery, palette-generator, import/export, and
  reduced-motion behavior remain intact.

## Validation

- Theme engine and workspace UI suites pass: **29 checks**.
- Full Flutter suite passes: **1,259 tests**.
- `flutter analyze --no-pub`: no issues found.
- Strict format across `lib` and `test`: clean.
- Headless shell capture reviewed at desktop size; compact and large-text
  workspace layout checks pass without overflow.
- Windows release build succeeded at
  `build/windows/x64/runner/Release/orbit_note.exe`.

## Next boundary

Apply the same visual grammar to the PDF and Canvas toolbars and inspector
surfaces, then review narrow phone layouts. Keep content input immediate and
avoid adding decorative animation.
