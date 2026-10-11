# UI refinement review — 2026-09-21

Request: refine the current application into a calmer, content-first workspace,
preserving existing editing, Canvas, PDF, local storage and sync capabilities.

## Audit and implementation

The audit used the working tree, current task notes, visual/motion design docs,
and relevant shell, Home, editor, Canvas, Inspector, palette and test code. The
tree already contained substantial uncommitted features. Changes extend those
features; this is not a replacement application or a new storage architecture.

| Area | Result |
| --- | --- |
| Design system | Reused `OrbitColors`, `OrbitRadius`, `OrbitMotion`, `OrbitControl`, `OrbitModeControl` and existing Material component themes. |
| Typography | Retained semantic Segoe UI hierarchy and user-controlled note typography. Removed promotional headings; contextual labels use plain language. |
| Spacing | Completed shared 4/8/12/16/24/32/48 spacing scale. Existing feature-specific sizing remains where it controls content geometry. |
| Surfaces and radius | Graphite surfaces, existing 8/12/16 radii; Home resume and idle focus sections use dividers instead of ornamental cards. |
| Color | Neutral hover/pressed overlays; violet remains focus/selection. Removed gold tab-card decoration. Semantic warning/error colors remain. |
| Home | Date navigation leads; compact period controls, quick capture, essential note/task creation, quieter resume sections, due tasks, upcoming and recent work. Review, inbox, project and work-session features remain accessible. |
| Home empty state | Short factual descriptions, no marketing hero. Idle focus collapses to its start action; prior session summary remains when available. |
| Sidebar calendar | New/default sessions show a compact current date. Expansion and prior explicit preferences are preserved. Month arrows appear when expanded. |
| Explorer | Permanent creation buttons and type chip strip replaced by New/import and type menus. Mixed-type filtering, folders, sorting, searching and file drops remain. |
| Row actions | Secondary actions reveal on hover/focus, remain keyboard reachable, and stay visible for selected rows and touch platforms. |
| Creation | Notes, canvases, tasks, events, PDF/image opening and file import remain in New. Existing shortcuts and global import are retained. |
| Tabs | Quiet active underline, small bookmark indicator, preserved close/pin/bookmark/reorder/middle-click/context-menu behavior. Fixed bookmark menu label overflow. |
| Panes | Restored two simultaneous views of the same note; PDF duplicate-view guard remains. Shared minimum note-header height keeps split titles aligned. |
| Inspector | Properties/links first; graph starts collapsed and can be revealed. Quieter identity/header; close callback connected; existing resizing/session controls retained. |
| Canvas toolbar | Grouped text/sticky, pen/highlighter/eraser, and object/image insertion flyouts. Existing shape and board-content menus preserved. |
| Canvas selection | Contextual selection menu: edit/open, duplicate, lock/unlock, focus, remove placement. Arrangement/layer/group controls appear only for relevant selections. |
| Canvas appearance | Existing drawing settings remain contextual. Color changes now skip locked elements. No scene, culling, ink, camera or durable-format rewrite. |
| Canvas chrome | Existing zoom/fit, title, minimap, focus/presentation controls retained; primary toolbar has fewer permanent controls. |
| Editor | Header wraps on narrow panes; content/formatting-column alignment retained. Rich/Source/Split/Read and LaTeX controls preserved. |
| Editing bug | First Ctrl+A in a paragraph selects its text; the next selects document blocks. The paragraph handler now consumes the first event instead of allowing the parent to steal it. |
| Palette | Initial/cleared search ranks actual recent objects first, deduplicates, and excludes deleted objects. Existing commands and debounce remain. |
| Menus/dialogs | Shared theme retained; new menus use native Flutter keyboard/focus behavior. Type menu avoids a Flutter checked-menu ink assertion. |
| Fields/status | Existing field, error, tooltip, save status, local-first and read-only styling preserved. No new credential or persistence controls. |
| Motion | Existing Normal/Reduced/Off and OS reduced-motion cap retained. No repeating decorative animation added. Current local graph implementation is static. |
| Accessibility | Text/shape indicators accompany color; controls retain labels/tooltips and keyboard paths. Home resume actions stack at large text sizes. |
| Responsiveness | Fixed 200% text / phone-width Home overflow, note-header overflow, split-title misalignment and saved-view tab overflow. |
| Performance | No new dependencies, timers, polling or canvas-engine work. Hover state rebuilds one row. No frame-time benchmark claim. |
| Compatibility | Explicit old calendar preferences, object identities, note bytes, unknown metadata and repository save contracts preserved. PDF secondary zoom isolation remains intentional. |

## Validation

- `dart format lib test tool`, then no-change formatting check.
- `flutter analyze --no-pub`.
- UI refinement snapshot: full `flutter test --no-pub` passed 764 tests;
  focused UI acceptance passed 18 tests and the split-view regression passed.
- Follow-up against the combined Canvas changes: 774 tests passed; analysis
  found no issues and formatting reported no changes. This check caught and
  fixed the new formula context-menu label overflowing: it now wraps within
  the available width. Existing menu interaction tests cover this regression.
- Native Windows release preview built from `tool/ui_review.dart`. This uses an
  in-memory repository and never opens the user's vault. F1–F7 cover Home, note,
  Canvas, tasks, calendar, settings and Inspector.
- Native screenshots reviewed at ordinary and maximized desktop sizes. Latest
  widget captures cover final layout changes, empty/populated Home, notes in
  two panes, Canvas, tasks, calendar and Settings.
- Production build from `lib/main.dart` succeeded in 60.2 seconds and the
  regular Windows application launched successfully. This build predates
  subsequent Canvas math and minimap work in the shared repository.
- A subsequent production Windows build including the combined changes and
  menu overflow fix succeeded in 54.1 seconds (`.local/ui-combined-build.log`).
  The native screenshots and launch review above cover the earlier UI build.

Final command results are recorded in `docs/tasks/current.md`. Local logs are in
`.local/ui-final-*.log`; screenshots are in `work/ui/`.

## Screenshots

- `home-empty.png`, `home.png`: final empty/populated Home.
- `notes-split.png`, `canvas.png`, `tasks.png`, `calendar.png`, `settings.png`:
  final widget-rendered UI captures.
- `native-home.png`, `native-note.png`, `native-canvas.png`,
  `native-inspector.png`, `native-tasks.png`, `native-calendar.png`,
  `native-settings.png`: native Windows review. These precede the final compact
  date, hover-action and large-text adjustments; use widget captures for those.
- `production-home.png`: successful regular application launch after the UI build.

## Practical limits and next visual milestone

This pass does not claim a new renderer, exhaustive device coverage or measured
GPU performance. Native review used a small sample vault and a study board with
six cards plus a note placement, not a stress-scale mathematical canvas. The
Canvas transclusion preview showed raw display-math Markdown during that review;
subsequent Canvas math changes are not represented in these captures.
Specialized project/dashboard cards and advanced
connector controls retain their existing structure. No storage migration, cloud
change, package installation or architecture ADR was needed.

Suggested next visual task: stress-review the newer mathematical Canvas rendering
with dense boards and complex equations, checking fidelity to the original
Markdown and renderer performance.
