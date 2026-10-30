# Tablet explorer scrolling, space and traversal — 2026-10-30

## Behavior

OrbitScrollSafeDrag reuses Flutter immediate/delayed multi-drag pointer states.
Actual mouse input drags immediately even on Android; touch and pen must hold,
including on a Windows touchscreen. Early movement rejects item dragging so the
scrollable wins. Pointer timers are owned/disposed by the active recognizer.
Tap, mouse right click, keyboard menus and arrows remain unchanged. Read-only and
root-folder drag guards remain. Long-press tooltip triggering no longer competes
with dragging; hover tips remain and Android/iOS action menus are always visible.

A compact header applies on Android/iOS and short desktop windows. New, Find and
Show explorer tools remain visible; the latter reveals the original calendar and
all auxiliary tools. Its device-session extra key survives reopen and stays out
of the portable preference allowlist. Header scroll height is capped at 48% of
its pane, leaving items at least 52%. Drawer width is bounded by 86% of the view
and 400 px. A single header instance serves either layout. Filter text/controller
and Clear stay consistent through tools/layout changes. No feature is deleted.

Object-to-folder and parent-to-child indexes are built once per render. Each
folder sorts once, reused for keyboard and row traversal; archived/collapsed and
loose-type group rules are retained. This removes repeated full-list/folder scans;
no source, history, import, cloud or storage format changes. Physical tablet FPS
is not inferred from these tests.

Folder input dialogs had an exit-lifetime error: their future resolves before the
reverse animation ends, so a disposed controller could still be used. Optional
showOrbitDialog.onDisposed transfers cleanup to the mounted route owner. Folder
names no longer wait 250 ms; project controllers use the same cleanup boundary.
It does not delay modal results, saves or commands. Existing folder and project
creation checks now pass without disposed-controller errors.

## Validation and limits

28 targeted checks pass (7 s), including real touch/stylus and mouse gesture
sequences, deliberate hold-drag, ordinary tap, compact sizes, tool toggling,
settings round trip, filter clear, organized mixed files, folder creation and
collapse/reveal, bulk selection/Vault safety, attachments and exact pen pixels.
Actual-font captures inspected. Early failed/interrupted runs and fixture fixes
are recorded in current.md; final native/analyzer/release evidence goes there.
Existing explorer_interactions_test was in an early interrupted batch; its
failure-boundary coverage is supplemented by the focused checks above, not claimed
as a new pass. No full-suite or physical-device acceptance claim.

Next suggested task: real Lenovo scroll/fling and large-Vault profiling after
installing the update. Do not start that hardware-dependent task implicitly.

## Publication evidence

1.0.16+17 / source bc0f5ba4e688d3f110e9ea991765cf9e21e8c5f5 is published at
https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.16-2026-10-30.
Windows built in 97.6 s, Android 116.7 s, installer packaging 14.5 s. Analyzer
lib/test/tool clean (25.2 s); strict 925 files unchanged (7.91 s). 28 final checks
pass in 7 s; phone/tablet captures inspected. Windows AOT/version and Android
package/version/original signature verified. All six uploaded hashes/sizes and
source tag match; zero GitHub workflows. The normal Windows run folder is updated,
and the signed APK is available for the tablet. Physical tablet FPS and fling
acceptance remain the next task; this update does not claim all app lag is gone.
