# Custom Category & Folder Color Identity — Evidence & Verification

**Date:** 2026-10-04  
**Milestone:** Custom Category & Folder Color Identity across Orbit Note  
**Repository:** Orbit Note  

---

## 1. Executive Summary

This feature delivers an interactive, quiet, and restrained color identity system allowing users to assign individual accent colors to workspace folders or notes in Orbit Note's Explorer.

Key design goals achieved:
- **Quiet Observatory Restraint**: No gaudy full-row background color flooding or illegible neon text. Folder colors provide calm visual structure through a 2.5px left-edge accent strip and an icon tint, preserving WCAG AAA text contrast.
- **Hierarchical Inheritance**: Contained child notes and subfolders automatically inherit context cues from their parent folder unless explicitly overridden with their own note-level accent color.
- **Persistent Storage**: Folder colors are safely serialized as `Map<String, int> folderColors` in `SessionState` and `AppPreferences`, persisted locally without requiring cloud or server dependencies.
- **Atomic Operations**: Folder moves (`moveFolder`) rewrite color paths, and folder deletions (`deleteFolder`) cleanly prune deleted keys.
- **Tab Integration**: Active tabs in `OrbitTabStrip` subtly tint their top 2px indicator bar with the active object or parent folder's accent color.
- **Modal Dialog**: `showFolderColorDialog` provides 12 curated harmonic color swatches, a custom hex input with `#` validation, an interactive Explorer preview card, and a clear reset action.

---

## 2. Key Architecture & Features Delivered

### 2.1. Persistent Storage (`lib/app/app_preferences.dart` & `lib/app/session_state.dart`)
- **`AppPreferences`**: Added `final Map<String, int> folderColors;` with default `const {}`.
- **`SessionState`**:
  - Added `folderColors` parameter to constructor, forwarding to `AppPreferences`.
  - Added getter and setter for `folderColors`.
  - Implemented safe JSON serialization (`toJson`) and deserialization (`fromJson`) handling string-to-int mapping, invalid inputs, and fallback resilience.

### 2.2. Controller & Folder Hierarchy Inheritance (`lib/app/workspace_controller.dart`)
- **`folderColorValue(String folder)`**:
  - Traverses the folder hierarchy upwards (e.g., `projects/design/ui` -> `projects/design` -> `projects`).
  - Returns the first resolved `int` color value, establishing intuitive inheritance for deeply nested workspaces.
- **`setFolderColor(String folder, int? colorValue)`**:
  - Sets or clears the color value in `session.folderColors`.
  - Debounces session persistence and notifies listeners for immediate UI reactivity.
- **Folder Move & Delete Lifecycle**:
  - `moveFolder(String source, String target)`: Recursively rewrites map keys for the moved folder and all subfolders.
  - `deleteFolder(String folder)`: Recursively deletes color entries for the deleted folder and all subfolders.

### 2.3. Explorer Row Accent Rendering (`lib/features/workspace/orbit_explorer_row.dart`)
- Solved Flutter's `A borderRadius can only be given for a uniform Border` assertion when mixing rounded corners and border sides:
  - Container uses uniform `Border.all(color: _focused ? c.accent.withValues(alpha: .6) : Colors.transparent)`.
  - Renders the 2.5px left-edge accent line via `Stack` + `Positioned(left: 0, top: 3, bottom: 3, width: 2.5, child: Container(decoration: BoxDecoration(color: widget.accentColor, borderRadius: BorderRadius.circular(1.5))))`.
- Tints the row icon with `accentColor.withValues(alpha: 0.85)` when an accent color is present.

### 2.4. Folder Color Dialog (`lib/features/workspace/folder_color_dialog.dart`)
- `showFolderColorDialog(BuildContext context, {required String folderName, bool isNote = false, Color? currentColor, required ValueChanged<Color?> onColorSelected})`:
  - 12 curated harmonic swatches: Violet, Indigo, Sapphire, Cyan, Teal, Emerald, Amber, Orange, Coral, Rose, Lavender, Slate.
  - Custom Hex input field supporting 6-hex and 8-hex inputs with live validation pip.
  - Live interactive Explorer preview card demonstrating how the folder and an inherited child note look with the selected accent.
  - "Reset to default" button to clear color overrides.
  - Keyboard and button dismissal actions.

### 2.5. Note Folder Explorer Integration (`lib/features/workspace/note_folder_explorer.dart`)
- Added `getFolderAccent(String folderPath)` resolving color through the folder hierarchy via `controller.folderColorValue`.
- Passes resolved `folderAccent` to `OrbitExplorerRow(accentColor: folderAccent)` for folder rows.
- Computes note accent (`noteExplicitColor ?? folderAccent`) and passes it to child note rows.
- Context menu enhancements:
  - Folder context menu: "Set folder color…" / "Change folder color…" and "Reset folder color".
  - Note context menu: "Set accent color…" / "Change accent color…" and "Reset color".

### 2.6. Tab Strip Integration (`lib/features/workspace/orbit_tab_strip.dart`)
- Dynamically resolves tab accent color: checks note explicit color or parent folder color via `c.folderColorValue(folder)`.
- Connects the active tab's top 2px indicator bar to the accent color when available.

---

## 3. Automated Test Suite (`test/folder_color_identity_test.dart`)

12 comprehensive unit and widget tests:
1. `SessionState preserves folderColors and defaults to empty`
2. `SessionState toJson and fromJson round-trips folderColors safely`
3. `SessionState handles corrupted or absent folderColors gracefully`
4. `WorkspaceController setFolderColor, folderColorValue, and inheritance work correctly`
5. `WorkspaceController moveFolder preserves and rewrites folderColors keys`
6. `WorkspaceController deleteFolder removes colors of deleted folder and subfolders`
7. `showFolderColorDialog renders swatches, preview, and applies selected preset`
8. `showFolderColorDialog allows typing custom hex code`
9. `showFolderColorDialog reset button clears color`
10. `NoteFolderExplorer Explorer rows and child notes render with inherited accent colors`
11. `OrbitTabStrip reflects active object and folder accent colors`
12. `Folder and note popup menus show color options and handle resetting`

---

## 4. Verification & Quality Gates

- `dart format lib test tool`: Formatted clean (0 changed).
- `dart format --output=none --set-exit-if-changed lib test`: Exit 0.
- `flutter analyze --no-pub`: 0 errors, 0 warnings, 0 issues.
- `flutter test test/folder_color_identity_test.dart --no-pub`: 12/12 passed (100%).
- Full regression test suites: All 1,251 tests passed cleanly.
