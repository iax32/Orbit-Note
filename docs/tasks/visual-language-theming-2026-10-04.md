# Visual Language Rewrite, Theming & Customization — Evidence & Verification

**Date:** 2026-10-04  
**Milestone:** Visual-Language Rewrite, Theming & Obsidian-Grade Customization  
**Repository:** Orbit Note  

---

## 1. Executive Summary

This milestone executes a major upgrade to Orbit Note's frontend visual language and theming system. It bridges the deep customizability, visual personality, and workspace ownership seen in personalized Obsidian vaults with Orbit's native observatory design philosophy ("A quiet observatory for your thoughts") and Universal Object architecture.

The interaction language remains strictly owned by Orbit (universal object identities, validated undoable commands, clean navigation boundaries, local-first offline storage). The visual layer is now fully user-owned through a strongly-typed semantic token system and five distinct theme packs.

---

## 2. Key Architecture & Features Delivered

### 2.1. Semantic Theme Engine & Tokens (`lib/app/orbit_theme.dart`)
- **Semantic Color Tokens**: Expanded `OrbitColors` ThemeExtension covering all architectural layers:
  - Surfaces: `background`, `workspace`, `panel`, `panelSecondary`, `raised`, `floating`, `input`
  - States: `hover`, `pressed`, `selected`, `selectedMuted`, `focus`
  - Structural: `border`, `divider`
  - Accents: `accent`, `secondary`, `accentHover`
  - Typography: `text` (`textPrimary`), `subtle` (`textSecondary`), `muted` (`textMuted`), `textDisabled`
  - Feedback: `success`, `warning`, `danger`
  - Links: `link`, `linkVisited`
  - Canvas & Graphs: `canvasBackground`, `canvasGrid`, `graphEdge`
- **Dynamic Corner System (`OrbitCorners`)**:
  - `rounded`: 8px control radius, 12px card radius, 16px dialog radius
  - `subtle`: 4px control radius, 6px card radius, 8px dialog radius
- **Typography Tokens (`OrbitTypography`)**:
  - Complete hierarchical font scale: `workspaceTitle`, `pageTitle`, `h1`, `h2`, `h3`, `body`, `bodySecondary`, `metadata`, `caption`, `toolbar`, `code`.

### 2.2. Five First-Party Theme Packs
1. **Orbit Graphite + Violet (`orbit`)**: Default dark observatory theme with deep neutral graphite backgrounds and violet highlights.
2. **Observatory Deep Space + Cyan (`observatory`)**: Deep space indigo background with high-contrast electric cyan and violet accents.
3. **Paper Warm Light (`paper`)**: Warm parchment cream light theme (`#F8F5EE`), deep charcoal text, and warm editorial serif typography.
4. **Midnight OLED (`midnight`)**: Pure OLED black (`#000000`), maximum contrast, and crisp neon purple accents.
5. **Aurora Forest (`aurora`)**: Deep twilight pine and spruce with luminous emerald and mint highlights.

### 2.3. Theme Serialization & Resilience
- Typed JSON serialization/deserialization for theme packs (`toJson()`, `fromJson()`).
- Full support for hex strings (`#RRGGBB`, `#AARRGGBB`) and fallback defaults on corrupted input.

### 2.4. Generic Heatmap View (`lib/features/workspace/heatmap_view.dart`)
- Year Heatmap view rendering all 12 months with day cells mapped across 5 activity intensity levels.
- Interactive hover tooltips displaying date and Universal Object details.
- Tap navigation directly into date context notes.
- Metric summary badge (items, active days, streak).
- Responsive `Wrap` layout preventing horizontal overflow in constrained panes.
- Registered in `SavedViewHost` under `viewType == 'heatmap'`.
- Integrated directly into `HomeView`.

### 2.5. Visual Banners & Covers (`lib/features/workspace/orbit_cover_banner.dart`)
- Reusable banner component supporting gradient presets (`ocean`, `twilight`, `sunset`, `aurora`, `obsidian`), solid theme colors, and custom images.
- Height presets: `compact` (110px), `standard` (180px), `hero` (260px).
- Integrated darken gradient overlay ensuring text readability in all lighting conditions.

### 2.6. Appearance & Customization Settings (`lib/features/workspace/theme_color_settings.dart`)
- `LiveThemePreviewCard`: Mini window mockup rendering typography hierarchy, live wiki-links, buttons, and corner indicators.
- `ThemePresetSelector`: Grid of cards with mini 4-color swatches for all 5 themes.
- `CornerStyleSelector`: Segmented switch between Rounded (8px) and Subtle (4px).
- Streamlined integration inside `ThemeColorSettings` (`ExpansionTile` with key `settings-custom-colors`), preserving initial scroll metrics in `SettingsView`.

### 2.7. Theme Interchange Dialogs (`lib/features/workspace/theme_interchange_dialog.dart`)
- `showOrbitThemeExportDialog`: Configures custom theme name and description, previews effective palette and specs, and exports to `.orbit-theme.json` via platform `exportFile`.
- `showOrbitThemeImportDialog`: File-picker based import using `openFile` (`*.json`), validates JSON format, displays theme preview dialog (name, description, swatches, badges), applies tokens live to workspace session, and persists custom themes to `session.customThemes`.
- Seamlessly accessible from `ThemeColorSettings` via `Export Theme...` and `Import Theme...` action buttons.

### 2.8. Theme Gallery & Custom Themes Manager (`lib/features/workspace/theme_interchange_dialog.dart`)
- `showOrbitThemeGalleryDialog`: Complete modal gallery view displaying built-in and imported theme packs.
- Inspects and renders swatch palettes (`background`, `panel`, `raised`, `accent`, `text`), theme specs (`Light`/`Dark`, corner style, typography), and active state.
- One-tap "Apply" button dynamically activating themes.
- Custom theme lifecycle management: in-place "Rename" prompt updating `customThemes` in session, and "Delete" confirmation that cleanly purges custom theme JSON and resets to `orbit` default if currently active.
- Quick toolbar shortcuts to "Import Theme...", "Export Active...", and "Generate...".
- Dedicated launcher button in `ThemeColorSettings` with key `theme-gallery-button`.

### 2.9. Harmonized Color Palette Generator & WCAG Accessibility (`lib/features/workspace/harmonized_palette_dialog.dart`)
- **`OrbitContrast` Engine (`lib/app/orbit_theme.dart`)**: Computes standard WCAG 2.1 relative luminance and contrast ratios (`ratio(Color, Color)`, `isWcagAa`, `isWcagAaa`).
- **`OrbitColors.fromSeed`**: Algorithmic generation of all semantic tokens from a single seed color. Guarantees WCAG AAA contrast ratio ($\ge 7.0:1$) for primary text and WCAG AA ($\ge 4.5:1$) for secondary subtle text on all generated surface tiers across both Dark and Light modes.
- **`OrbitThemePack.fromSeed`**: Constructs fully valid, serializable theme packs with automated naming, descriptions, and corner geometry.
- **`showHarmonizedPaletteDialog`**: Interactive generator modal offering curated seed swatches (Violet, Cyan, Emerald, Sapphire, Amber, Rose, Coral, Teal), hex code input, Dark/Light mode segmented switcher, live WCAG contrast ratio badges (`AAA`, `AA`), live UI mockup card, instant session application, gallery persistence, and `.orbit-theme.json` file export.
- Integrated into `ThemeColorSettings` (`theme-generate-palette-button`) and `showOrbitThemeGalleryDialog` (`theme-gallery-generate-button`).

### 2.10. Explorer Color Identity (`lib/features/workspace/orbit_explorer_row.dart`)
- Folder and note visual accents with left edge border indicator and subtle icon tinting.

---

## 3. Verification & Evidence

### 3.1. Formatting
```
dart format --output=none --set-exit-if-changed lib test tool
Formatted 387 files (0 changed) in 3.77 seconds.
Result: Clean (exit code 0).
```

### 3.2. Static Analysis
```
flutter analyze --no-pub
Analyzing Orbit Note...
No issues found! (ran in 5.4s)
Result: Clean (0 issues, exit code 0).
```

### 3.3. Test Suite
```
flutter test --no-pub
02:06 +1239: All tests passed!
Result: 1,239 tests passed, 0 failures, 0 skipped.
```

### 3.4. Windows Release Executable
- Flutter Windows build blocked on symlink privileges (`Building with plugins requires symlink support. Please enable Developer Mode in your system settings. Run start ms-settings:developers to open settings`).
- Pre-existing verified Windows release runner verified present at `build\windows\x64\runner\Release\orbit_note.exe` (272,384 bytes).
