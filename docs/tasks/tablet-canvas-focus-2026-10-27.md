# Tablet Canvas drawing focus — 2026-10-27

Owner tested Orbit on a Lenovo tablet and reports that focus mode still reserves
too much space for UI. Scope LAY-01/08/10 and existing Canvas interaction recovery:
give drawing the usable viewport, with reversible controls and unchanged content.
This addresses that feedback, not completion of all native-input acceptance.

## Delivered behavior

2026-10-30 layout refinement: when tools are expanded, the complete toolbar is
the top overlay and the compact Undo/tools/focus pill sits right-aligned below
it with an 8-pixel gap. A content-sized overlay column follows actual toolbar
height instead of reserving a full-width blank row above it. Hidden-tools mode
still places only the compact pill at the top right; drawing viewport/camera and
recovery actions remain unchanged. Current validation is recorded in current.md.

Swap validation: landscape/portrait geometry checks and actual-font captures
confirm the toolbar sits above the right-aligned compact pill without shrinking
the drawing viewport. Six existing focus checks pass (4 s), including stylus,
Undo/Redo, enlarged text, recovery warnings and Back/exit. The stylus fixture's
final save previously waited on fake-zone work from Undo/Redo; the bounded wait
now drains fake microtasks and native completions and asserts save success.
Analyzer clean (19.7 s), strict format 917 files unchanged (8.28 s). Local Windows
rebuilt in 82.8 s and AOT freshness verified; Android/GitHub releases unchanged.
Suggested next task: optional draggable toolbar positioning; not implemented.

## Movable focus controls — 2026-10-30

Owner accepts draggable positioning and requests complementary controls/motion.
The focus overlay now has a dedicated 48-pixel drag/menu handle, free normalized
positioning, a 24-pixel edge-snap margin, four accessible corner choices, a drag
lock and reset-to-top-right action. Bottom placement opens the toolbar upward;
resizing keeps the whole group within the safe viewport. Narrow layouts wrap
the handle/control group. The default remains main toolbar above the compact
right-aligned pill; that pill also gains immediately available Redo.

Drag state is isolated in the overlay with a repaint boundary. Parent Canvas
state, camera, point data, history and persistence are not rebuilt/mutated per
drag update. Explicit placement is retained while the same editor remains open,
including leaving/re-entering focus, but is not saved across app restart or
synchronized. Controls are reachable through keyboard menu choices and reset.

Brief Orbit-token transitions explain opening/closing and settling, with a quiet
handle hover/drag tint and pin icon when locked. Direct dragging has no easing;
grabbing during a settling transition starts from the actual visible position.
Reduced/Off/OS reduction remove spatial transitions and the new popup animation.
No looping decoration, physics overshoot, theme replacement or pen filtering is
introduced. Validation/build evidence is recorded in current.md.

Fourteen focused overlay/focus/ink checks pass (5 s). They cover edge clamping,
snap, lock/reset, bottom-up opening, narrow resize, interruption of active motion,
Normal/Reduced/Off/OS reduction, compact Redo, full save/Undo recovery and unchanged
nib pixels. A drag leaves the parent test Canvas build count unchanged. Updated
landscape/portrait actual-font captures inspected. Analyzer clean (18.5 s), strict
format 919 files unchanged (8.20 s). Local Windows rebuilt in 82.5 s and AOT
freshness verified; existing
Android/GitHub packages are unchanged. Next candidate: explicit device-local
placement persistence across app restarts, not added in this batch.

- Primary Canvas focus hides activity rail, header, project context, tabs, global
  status bar and per-object bridge bar. This includes Canvases opened from Notes,
  not only the Canvas destination. Existing explicit split layouts remain split;
  notes and other destinations retain their previous focus behavior.
- Canvas hides its permanent toolbar, title/breadcrumb overlay, zoom panel and
  minimap. Drawing fills the remaining safe area; OS cutout/navigation insets and
  read-only/save/recovery warnings remain. No OS fullscreen mode is requested.
- A 144×48 logical-pixel floating group exposes Undo, Show/Hide Canvas tools and
  Exit Canvas focus. The complete toolbar opens as an overlay, without resizing
  the drawing/camera. Escape dismisses that toolbar; tablet system Back exits
  drawing focus first. The existing global focus shortcut also remains.
- Touch targets are at least 48 logical pixels. Edge-drag opening of the explorer
  drawer is disabled during Canvas focus to avoid interrupting edge drawing.
- No tab, sidebar/inspector preference, minimap choice, selected tool, camera,
  scene, history or draft is cleared to enter/leave focus. Tools start hidden on
  re-entry. Loading diagrams retain a visible Exit control; standalone editors
  without an exit callback retain their normal controls rather than trapping users.
- Same adaptive behavior on Android/iPad-sized/desktop Flutter surfaces. No native
  platform APIs, content schema or new preference migration is introduced.

## Evidence and limits

44 focused integration checks passed: new full-shell tablet fixtures, existing
pen, minimap/transclusion, Canvas performance regression and split-focus suites.
Fixtures use 1024×768 landscape / 820×1180 portrait at pixel ratio 2 and explicit
24/20 logical-pixel safe insets; Canvas occupies the full remaining 1024×724 /
820×1136 viewport. Editor state identity survives both transitions; camera zoom,
saved tab/panel choices and unknown scene metadata remain. Revealing tools does
not reduce the measured drawing surface. Simulated stylus drawing, Undo/Redo,
system Back, source save, short 800×600 layouts at 200% text, recovery warning
visibility and missing-exit callback fallback pass. No real stylus/device latency
or actual Android/iPad runtime acceptance is claimed.

Actual-font captures work/ui/canvas-focus-{1024,820}.png inspected. Logs:
.local/canvas-focus-{tests,integration,analyze,format-check}.log. New tests avoid
fake-clock autosave waits while using normal controller/store boundaries.

Android release attempt explicitly failed: no Android SDK is installed/configured
on this PC; android/local.properties points at a missing prior-machine SDK path.
Existing APKs do not contain this change. No signing key was regenerated, SDK
downloaded or cloud workflow started. Log: .local/canvas-focus-android-build.log.
Windows build outcome is recorded in current.md.

Next task: restore the Android build toolchain, produce a matching signed APK,
then validate this layout and real pen/palm input on the owner's Lenovo tablet.

## Device-local comfort — 2026-10-30

Supersedes the open-editor-only placement limitation above. Position and lock are
stored in session.canvasComfort, excluded from portable Vault preferences. Old
versions retain it as unknown session data; current edits/reset preserve unknown
option fields. Invalid coordinates fall back/clamp without hiding recovery.
Canvas toolbar touch icon, focus position menu and searchable Settings > Canvas
all expose the same options. The preset enables larger drawing controls and a
softer themed grid. Left/right buttons move focus controls to reachable bottom
corners; free dragging, lock, corner presets and reset remain available.
Only view colors change for guides that use the semantic canvasGrid color; special
blueprint artwork and authored ink stay intact. Exports retain the original theme.
Toolbar sizing is local to drawing controls, without enlarging the whole sidebar.
Placement writes happen on drop/menu action, never each pointer move.

Focused acceptance covers session restart/unknown data, portable exclusion,
invalid values, narrow panel scrolling, live placement/lock changes, 56-pixel grip
and drawing buttons, untouched authored object data, stylus/Undo/Redo/Back, and
Normal/Reduced/Off/OS-reduced motion. No medical relief or physical-device latency
claim is made. Final native/release evidence is recorded in current.md.
