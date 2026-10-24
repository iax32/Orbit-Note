# Searchable settings workspace

Owner-authorized LAY-01/06/08/10 subset, validated 2026-10-23.

## Use and scope

Settings now has nine categories: Appearance; Writing & reading; Code editor;
Canvas; Workspace; Focus & audio; Files & recovery; Sync & sharing; Tools.
There are **43 searchable entries** (some expose a complete existing advanced
panel/action rather than a single toggle). This is not 43 newly invented switches.

Wide layouts use category navigation; compact/enlarged-text layouts use a selector
and one scrollable page. Search matches all words against setting/group/category
names and useful aliases. Results are grouped with counts, no-match recovery and
clear search. Ctrl+F within Settings focuses search; Escape clears an active
search. Search submit and dragging dismiss the keyboard. Category scroll positions
are retained, and clearing search returns to the prior category. Advanced theme
controls expand on demand. Existing public SettingsView imports remain supported.

### Additional controls

- Display: explicit rounded/subtle corners alongside existing palette, font/zoom.
- Code: font family, independent 10–26 px font size, line-number default and
  wrapping default. Real code blocks/source workspaces/IDE controls use these
  styles; font changes preserve source/focus/selection. Existing panes retain
  their local wrap/number choices; defaults apply to new panes.
- Workspace: explorer width, split direction and primary pane ratio, note sort,
  attachment visibility and calendar folding, alongside panel/density/motion.
- Canvas: all **15** supported paper choices, adding the five previously omitted
  options (classic blueprint, Cornell, music, ledger and triangular).
- Writing: more line-spacing choices and a proper custom dictionary editor with
  bounded validation, case-insensitive deduplication and stale-draft protection.
  Dictionary clearing asks for confirmation and supports guarded Undo.
- Focus/recovery: more work/break and autosave choices. Existing saved custom
  values show their actual value instead of falsely displaying a nearby preset.
- Files/recovery: real backup/import/manage/reload actions remain. The former
  Optimize button only displayed a success toast; it is removed. Reload reports
  the actual outcome and preserves existing draft/failure boundaries. Local object
  counts replace scanning every note body whenever Settings is opened.

The advanced appearance entry has its own readable base-palette surface, even
when all custom roles are set to black. Recovery therefore remains discoverable
while the controls are folded. Section resets preserve unknown color roles;
the existing explicit Reset all custom colors action retains its full clearing
behavior.

Seven local-preference sections provide confirmed **Reset section** with Undo.
They capture values at confirmation time, preserve unrelated edits, unknown roles,
custom theme libraries and documents, and refuse Undo after a touched setting or
owning Vault/session changes. Sync/account connections are never reset by this
control. Resetting focus durations updates the timer consistently.

## Persistence and compatibility

The existing device-local flat session adds defaultCodeWrap=false and
codeFontSize=14 (finite, clamped 10–26). monoFontFamily/showLineNumbers were already
stored; they now reach actual code controls. Classic blueprint is recognized by
the existing paper validator. Unknown fields, custom values and old JSON survive;
there is no storage migration/dependency or authority change. Authored document
formatting, selected text, object identity, saved boards and account permissions
are unaffected. Search/navigation state is transient rather than synced content.

## Validation

- **14 new behavior regressions** cover search/category selection, actual preference
  persistence and malformed/old/unknown JSON, reset/Undo/cancel/ownership guards,
  dictionary editing/staleness, real file actions, Ctrl+F/Escape and code defaults
  with source/focus/selection retention.
- Focused existing/new settings, spelling, typography, large-text, palette/system
  and semantic-color suites: **103 passed** (18 sec).
- Final new-settings + real-font visual check: **14 passed** (4 sec), including
  320×640 and 568×320 layouts at **250% text**, with keyboard insets reserved.
- Headless actual UI rendered with real Segoe UI/Material icons at 1.5x; desktop
  dark Appearance/Code and compact Sage light search were visually reviewed.
  Previews: build/previews/orbit-settings-appearance.png, orbit-settings-code.png,
  orbit-settings-compact.png. The initial capture was transparent because its
  boundary excluded the parent background; the harness now includes the actual
  palette background. Interaction tests caught and fixed an ink-surface issue;
  older tests now navigate/search rather than assuming one giant settings list.

- Format/strict formatting: **740 files**, no outstanding changes. Analysis:
  **no issues** (7.2 sec on the final analysis).
- Recovery integration + settings regressions: **16 passed** (4 sec). The initial
  full run passed **2,958**, with **2 existing skips** and one older recovery
  test still assuming advanced controls were always expanded. It now exercises
  Settings search and the correct content scroll container. A complete rerun
  passed **2,959 tests, 2 existing skips** in **10:50**. No production behavior
  was relaxed to hide that test failure.
- **886** source/test/asset/platform/tool/config inputs frozen for final validation.

The clean full run preceded the final localized readable-entry protection above.
After that change, the settings/theme/typography/spelling/large-text/recovery
suites and real-font render passed **108 checks** (21 sec), including the new
all-black-role recovery case. No additional full-suite run is claimed after that
localized hardening; the complete run and final focused evidence are separate.

## Release verification

Configured Windows app and matching standalone host built successfully; Windows
compilation took **75.0 sec**. **886** frozen inputs remain exact, seven required
runtime/host files are present, all **13** bundled font hashes match, and registered
Google desktop client presence was verified in the AOT payload without printing
configuration values. The app and host were not launched.

Standard JavaScript web release built successfully in **72.9 sec**. Existing
Google Identity SDK Wasm dry-run incompatibility and missing Cupertino font
warnings remain; this validates the standard JavaScript target, not WebAssembly.
The frozen-input/runtime/font/configuration verification also passed after the
web build.

Run `build/windows/x64/runner/Release/orbit_note.exe` with its sibling runtime/data
files. No ZIP or external release publication was created.

## Limits and next task

This does not implement every future customization requirement, arbitrary docking,
keymap editing or new cloud/account behavior. Native/mobile visual and screen-reader
acceptance remain unverified; headless layout/keyboard tests are not a substitute.
No private Vault/account work, application/server launch, publication, ZIP or
shutdown belongs to this task. Existing web SDK/font warnings may remain.

Suggested next task: user-defined settings profiles with preview and recoverable
apply, reusing saved Spaces rather than introducing a second preference store.
Stop before implementing that feature.
