# Observatory visual pass — 2026-09-11

This is a delivered incremental pass, not completion of every item in the owner's
larger visual brief. Existing architecture, data formats, save behavior and product
features are preserved. No new dependency or ADR is necessary.

## Audit and visible result

The remaining default-looking areas were Notes' segmented selector and narrow
dropdown, Canvas filled-tonal tool buttons, generic dialog title/content layout,
Graph choice chips and bright circular markers, and repeated form-like search.
Theme colors alone did not fix their composition.

Shared Orbit controls now use tone-based hover/press feedback, visible keyboard
focus, an anchored selection mark, deliberate spacing and a compact text hierarchy.
They use standard Flutter semantics/focus/activation underneath without ink splash.
The Notes document stays centered; its formatting toolbar remains compact at left.
Narrow panes keep every mode reachable through a compact menu.

Canvas retains its grid, culling, immediate gestures and persistence. The creation
tools now match the Notes and rail controls. Existing link/object dialogs receive
the new floating layout. No artificial drop settling changes pointer coordinates.

Graph markers are hollow graphite rings with a restrained violet center; Canvas
nodes use square silhouettes. Relationships recede outside the hovered/local
neighborhood. Labels fade at far zoom and avoid growing huge at close zoom. Fit
caps automatic zoom at 1.25; manual zoom remains available. Surviving node positions
remain stable when filtering, avoiding a sudden rearrangement of familiar content.
No typed relation data or new graph-layout system is invented.

## Shared components and tokens

- OrbitControl: default/hover/press/focus/selected/disabled, pointer and keyboard.
- OrbitModeControl: Notes modes, Graph scope and Settings motion preference.
- OrbitDialog: bounded floating surface, title marker, scrollable content and
  wrapping actions. Applied to Vault, Calendar, Canvas and graph-object dialogs.
- OrbitSearchField: graph and command search with an integrated icon/focus edge.
- OrbitEntrance: finite opacity reveal; used for Graph entry.
- OrbitMotionScope: Normal/Reduced/Off plus the operating-system cap.
- OrbitSpace, OrbitSize, OrbitDepth and OrbitMotion.ease complement existing
  graphite/violet colors, radii, durations and typography. Floating/selected
  surface aliases use existing colors rather than introducing another palette.

## Motion and input contract

Normal uses 110 ms micro, 180 ms panel and 200 ms dialog/camera transitions.
Reduced uses 110 ms opacity/state feedback and no spatial camera travel; Off uses
zero-duration custom transitions. OS reduction caps Normal at Reduced. Changing
preference mid-camera-animation lands immediately at the target. A manual camera
gesture interrupts programmatic motion.

Graph fit and local-focus changes use finite ease-out interpolation. Layout still
runs its bounded synchronous calculation, never a perpetual force ticker. Stable
nodes retain coordinates across filters rather than being animated unnecessarily.
No spring overshoot or decorative orbiting animation.

Other additions: Calendar heading crossfade, Task title completion styling, tab
selection boundary, Copy Code confirmation and shared control states. Command
palette route duration uses the shared policy. Saves and callbacks do not wait
for animations. This does not claim that every inherited Material animation now
obeys all three preference levels.

## Requested area coverage

| Area | This pass | Still needs work |
|---|---|---|
| Notes | Custom mode/header control; narrow menu; Copy Code feedback | Table/equation field chrome, slash/context menus, image controls |
| Canvas | Creation controls and dialog consistency | Floating selection toolbar, contextual menus, richer semantic zoom |
| Graph | Markers, edges, labels, filtering continuity, fit/focus easing, reveal | Typed-edge legend, measured hardware frame budgets, node-entry transitions |
| Rail/sidebar | Custom active rail; Vault dialog | Folder row redesign, drag target feedback, explorer search |
| Tabs | Selection transition; existing reorder/middle-click preserved | Tab insertion/removal and split-group motion |
| Dialogs/menus | Four major dialog consumers; command search | System date/file pickers, remaining rich/PDF dialogs, generic popup rows |
| Tasks/Calendar | Completion text transition, month heading, event dialog | Custom checkbox/event cards, agenda transitions |
| Home/Settings | Existing bounded Home preserved; custom motion selector | Home widgets and remaining settings switches |
| Panels | Existing behavior preserved | Collapse/inspector/split motion with focus retention |
| Status/loading | Existing behavior preserved | Unified compact toasts, contextual loading and recovery UI |

## Validation and limits

Functional tests remain intact. Added three component tests; expanded Graph
interaction coverage checks that camera motion changes over time and stops.
Existing narrow Notes tests and a new 480px dialog at 150% text cover scaling.
Screenshots are reviewed for Notes, Canvas, Graph and Home; local captures live
under work/ui. Full-suite/build/startup evidence is in implementation-status.

Native startup is not a full manual interaction audit. Real high-DPI/multi-monitor,
touch/pen, screen-reader acceptance and rendering frame measurements remain unverified.
No claim of full Notion/Milanote/Obsidian parity or universal custom-widget coverage.

## Explorer follow-up — 2026-09-11

The next bounded slice adds OrbitExplorerRow, a shared right-click/keyboard/more
menu, clear focus/selection states, folder Left/Right navigation, a stable-ID Copy
note reference action and read-only mutation guards. It retains existing drag/drop
wrappers, object identity and repository commands. Folder dialogs use OrbitDialog.
This supersedes the explorer-row deferral above; slash menus and panel transitions
remain unfinished. The integration test exercises UI actions plus reopen/source
preservation; evidence is recorded in the current task and implementation status.
