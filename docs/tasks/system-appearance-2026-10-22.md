# System appearance for paired palettes — 2026-10-22

## Authorized scope

Owner accepted the preceding palette task's suggestion: optional automatic
system light/dark switching. LAY-01/04/06/09/10 subset, building on the 50 matched
families. No new dependency, knowledge migration, scheduled mode or arbitrary
custom-theme pairing. Existing manual defaults and prior dirty work remain.

## Operation

1. Settings → Appearance → Customize interface colors → Theme packs, or Theme
   Gallery: choose a matched family such as Sage Garden, Atlantic or Clay.
2. Enable **Follow system appearance** in Settings → Appearance or Theme Gallery.
   The control names both members and the currently visible member.
3. Changing the OS appearance changes Orbit while it runs; initial launch also
   resolves the current OS mode. The saved family anchor does not change.
4. Turning following off pins the currently visible member. Selecting a palette
   manually, importing, applying/saving a generated palette or deleting the active
   custom theme returns to manual mode.

Original/custom themes without a matched catalog companion retain their exact
look. The switch explains how to choose a pair and is disabled for them; a
previously saved unsupported automatic choice still allows turning it off.
Unknown IDs retain the existing Orbit fallback without rewriting the saved ID.
Fonts, corners, explicit accents, custom role overrides, independent document
surfaces and knowledge content are preserved. Explicit overrides can reduce
contrast in either mode; existing readable recovery/reset controls remain.

## State and consistency

`followSystemAppearance` is an opt-in Boolean in the existing flat device-local
session format, defaulting to false for old/invalid values. Unknown session fields
and role overrides survive. OS brightness is observed through Flutter's inherited
MediaQuery; it does not trigger a settings save, object mutation or editor reload.
The app, palette status/selection, workspace summary, live preview, generator's
initial mode and theme export share the same effective-palette resolution.
Export snapshots the visible member plus actual explicit accent/overrides and
fonts; it does not export an automatic pair policy in the existing theme format.
An in-progress export name is retained when OS appearance changes.

Spaces with remembered appearance save/restore this preference. Older fixed
appearance descriptors and older base snapshots default to manual; layouts without
remembered appearance preserve the current preference. Saved OS-driven appearances retain their family,
not whichever member happened to be visible at save time. No architecture change.

## Validation

**11 new regressions; 64 focused passed** (6 sec). All 100 paired members resolve
both platform modes without mutating saved identity; old/invalid/unknown/custom
preferences, explicit accents/roles and defaults survive. The actual app switches
repeatedly while Source text is selected: controller, keyboard focus, selection,
note/session identity and durable bytes remain unchanged. Disabled motion stays
instant. Gallery/status, manual/import/generator exits, preview/export including
an edited export name, saved-Space close/reopen and legacy fixed appearances pass.
The control/preview fit 360 px with 200% text. Real Segoe UI/icon headless renders
of both controls/previews were visually reviewed; see
`build/previews/orbit-system-appearance.png`. Existing settings recovery/canvas
tests now scroll before locating or tapping offscreen controls.

Format and strict formatting are clean across **736 files**. Analysis is clean
(8.1 sec). Full rerun: **2,937 passed, 2 existing skips** (11:54, concurrency 2).
The initial full run exposed an existing Drive deadline check under load and an
offscreen settings tap after adding the new row. The settings test was corrected
to scroll; all 22 settings tests pass. The unchanged Drive check passes in isolation
(6 sec); it also passes in the complete reduced-concurrency rerun. No Drive product
code was changed for this task.

Configured Windows app + matching standalone host passed (**75.9 sec** for the app),
preserving the registered Google desktop client. Standard JS web release passed
(**74.1 sec**). Existing Google SDK Wasm dry-run incompatibility and Cupertino font
warnings remain; this is not a Wasm release. **882** frozen source/test/platform/
asset/config inputs remained unchanged, seven runtime/host files were verified,
all **13** packaged font hashes match, and the registered client is in the AOT.
Verification report: `.local/system-appearance-release-verification.json`.

Tests use synthetic local repositories and simulated platform brightness; no
desktop-control testing, private Vault/account work or real OS preference changes.
Native/mobile visual acceptance is not claimed; no APK was rebuilt. No app/host
launch, persistent service installation, GitHub publication, archive or shutdown.
All prior dirty work remains. Run `build/windows/x64/runner/Release/orbit_note.exe`
with sibling runtime files. Logs use `.local/system-appearance-*`.

Suggested next task after validation: allow separate preferred light and dark
palettes, with explicit choices and recovery, for original/custom themes.
