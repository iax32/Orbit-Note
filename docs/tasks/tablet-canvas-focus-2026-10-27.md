# Tablet Canvas drawing focus — 2026-10-27

Owner tested Orbit on a Lenovo tablet and reports that focus mode still reserves
too much space for UI. Scope LAY-01/08/10 and existing Canvas interaction recovery:
give drawing the usable viewport, with reversible controls and unchanged content.
This addresses that feedback, not completion of all native-input acceptance.

## Delivered behavior

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
