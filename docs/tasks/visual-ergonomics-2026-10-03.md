# Visual ergonomics delivery — 2026-10-03

The owner's attached major product-design prompt authorizes this pass in the
current worktree. Its stop rule permits a coherent subsystem delivery when scope
is large. This delivery covers shared readability/density, tabs, Explorer, note
toolbar, tasks and selected planning surfaces. It is not completion of every
screen in the major prompt. No unrelated work was reset; no packages, storage
schema, object identity, sync protocol or canvas/ink engine were replaced.

## Requested report

| # | Area | Findings and delivered behavior |
|---|---|---|
| 1 | UI audit | Audited source and realistic 1920×1080 headless Windows renders with 15 note tabs, 30 production tasks and five populated milestone groups. Found tiny metadata, clipped task titles, noisy Explorer actions, status aliases and text-scale overflows. |
| 2 | Typography problems | Some metadata was 9–11px; independent TextStyles dropped the interface font in Explorer rows, animated task titles and board selectors. Fixed those paths. Remaining isolated small labels are tracked below. |
| 3 | Typography system | Keep existing semantic roles and chosen fonts: body 14, object 15, section 16, metadata/caption 12. Task/board titles 14.5 with 1.45 leading; Explorer 13.5 with 1.4 leading. Note typography stays editor-owned. No blanket font-size rewrite. |
| 4 | Contrast | Default secondary text is #C2BECE and muted text #918C9D. Default secondary-on-panel contrast exceeds 7:1 in the regression check. User color overrides remain authoritative; this does not claim every custom palette passes contrast checks. |
| 5 | Density | OrbitDensity centralizes row/control/icon/card/tab/board geometry, composed with app zoom. Existing density preference remains the source of truth. |
| 6 | Comfortable/Compact | Comfortable rows/controls 36, small controls 32, board columns 304, tabs 220; Compact rows/controls 30, small controls 28, columns 272, tabs 188. Compact reduces spacing rather than body/metadata fonts. Task row padding also responds to density. Not every legacy surface has adopted these tokens. |
| 7 | Tabs | Keep readable widths and active document visible; explicit overflow opens searchable open/recent tabs. Close others, close to right and reopen closed are available. Pin/bookmark, dirty indicators, drag reorder and middle-click close remain. |
| 8 | Explorer | Actions appear on hover, keyboard focus or selection; right-click and keyboard menu access remain. Rows inherit the chosen font, readable titles and density geometry. Selected rows retain their action target. |
| 9 | Note editor | Toolbar remains aligned with content, uses density sizing and 32px comfortable button targets. Formatting scrolls when needed; Undo/Redo stay visible. Breadcrumb labels increase selectively. Source, selection, composition, history and existing paragraph controls remain. |
| 10 | Task List | Titles 14.5, readable priority/project/date labels, roomier comfortable rows; Compact keeps legible text. Animated titles now inherit the interface font. Existing inline title editing, completion undo, filtering and ordering remain. The widest list layout still needs refinement. |
| 11 | Task Board | Both board implementations use readable title/metadata sizes and bounded columns instead of shrinking all columns to fit. Collection cards limit titles to two lines; task-board titles may grow for long content. Collection boards optionally hide empty columns. |
| 12 | Status/grouping | Confirmed todo was absent from Game Dev's backlog/planned/in-progress/review/testing/done preset. Shared pure alias mapping sends todo to Planned where available; explicit matching statuses win. Generic boards intentionally include non-task objects; this is now labelled and optionally filtered. New Game Project boards default to tasks only. |
| 13 | Task Detail | Bounded 980px working surface; long titles wrap. Priority/status/due date remain immediate. Description has 16px text and six-line minimum. Estimate/discipline/dependencies/build fields move behind Properties. Related context is bounded to 420px; Trash moves into More actions. |
| 14 | Dashboard | Game project health metrics lose four separate card borders, use readable labels/values and responsive columns. Research section headers wrap their actions. Existing project/task/material surfaces remain; this is a targeted refinement, not a full dashboard replacement. |
| 15 | Current Focus | Gains shared TaskRow improvements. A complete dedicated focus composition is deferred. |
| 16 | Milestones | Centered maximum width 1080 and clearer metadata; existing canonical task groups, expansion and creation remain. |
| 17 | Timeline | Purposeful empty heading, explanation and one create action; filtered empty state is distinct. Existing populated timeline remains a dated list; a genuine time-axis redesign is deferred. |
| 18 | Canvas | Engine, gestures and animations preserved. No new Canvas toolbar/layout redesign in this delivery. |
| 19 | Empty states | Timeline distinguishes no scheduled content from no filter matches. Boards distinguish tasks/items and keep empty board columns available for creation. |
| 20 | Visual noise | Remove four project metric card boundaries; hide idle Explorer ellipses; collapse advanced task fields; move destructive task action to a menu. No ornamental gradients or new shadows. |
| 21 | Responsive | Tab overflow at 600px; dashboards and function table checked at 200% text/zoom. Dashboard columns respond to text size, action headers wrap and function action cells reserve actual button widths. Long task titles wrap. |
| 22 | Windows DPI | Semantic app zoom preserves actual viewport/DPR/insets and native hit coordinates; composes nonlinear OS text scaling. Automated geometry/selection checks pass. Actual 125/150/200% Windows monitor DPI review remains unverified. |
| 23 | Accessibility | Brighter default secondary text, readable metadata, larger shared hit targets, hover controls also exposed on focus/selection, labelled overflow and preserved keyboard menu/navigation. Full screen-reader and custom-color audit remains separate. |
| 24 | Performance | Lazy tab result/card lists remain; no new parsing, polling, image assets, database layers or per-row looping animations. Existing reduced/off motion policy retained. No new performance benchmark result is claimed. |
| 25 | Tests | Six new ergonomics tests cover alias mapping, density/contrast, crowded tab overflow/search, independent board filters/identity, task/planning rendering and narrow tabs. Existing zoom/layout tests updated for semantic geometry; Explorer interaction test now hovers before opening its idle-hidden menu. |
| 26 | Total tests | 1,208 passed in the final full run (1m55s). |
| 27 | Analyzer | No issues found (10.3s). Strict formatting: 382 files, zero changes. |
| 28 | Windows build | Normal Windows release built successfully in 62.3s, with the existing private build configuration. |
| 29 | Smoke launch | Fresh EXE ran for eight seconds and responded; its hidden window had title Orbit Note. Sent a close request only to that launched process; it exited normally. This is startup validation, not native interaction/DPI review. |
| 30 | EXE | C:\Users\isa\Desktop\Orbit Note\build\windows\x64\runner\Release\orbit_note.exe |
| 31 | Screens reviewed | Manually inspected generated PNGs: Notes/Explorer/15 tabs, collection Board, Task List, task-specific Board, Task Detail, Game Dashboard, Milestones and empty Timeline. These are headless rendered fixtures, not native desktop interaction acceptance. |
| 32 | Rough edges | Some legacy labels still below the new floors; task list is too wide on large windows, dashboard inner cards retain badges, Canvas/focus/view switcher need dedicated passes. Populated timeline lacks a time axis. Native DPI and screen-reader behavior need human review. |
| 33 | Next milestone | Refine planning navigation and the populated Timeline into a real week/month time-axis view, with shared scope/date controls and responsive task context. Stop before implementing it. |

## Validation evidence

Headless render fixture: `test/visual_ergonomics_test.dart`, optional
`--dart-define=ORBIT_CAPTURE_UI=true`; outputs `.local/ergonomics-review/`.
Uses memory-only repository/store/index and Windows Segoe UI/Material fonts.
Test fixture teardown cancels its timers; it does not flush fake-clock queues
after asynchronous image capture. Production persistence behavior is unchanged.

Focused rendering/layout/collection suite: 16 passed. Explorer/Find/Rich editor
regression suite: 62 passed. Initial full run exposed hidden Explorer menu test
assumptions and offscreen toolbar actions. Undo/Redo were made persistent and
toolbar target sizing corrected; affected regressions now pass, including IME.

Logs: `.local/ergonomics-review.log`, `.local/ergonomics-regressions.log`,
`.local/ergonomics-full-tests.log`, `.local/ergonomics-analyze.log`,
`.local/ergonomics-strict-format.log`, `.local/ergonomics-windows-build.log`.
Flutter commands use `--no-pub` to preserve the established Windows toolchain.

Final full suite: 1,208 passed. Analyzer: no issues. Strict formatting checks all
382 Dart files in `lib test tool` with zero changes. Windows release: success
(62.3s). Smoke metadata: `.local/ergonomics-smoke.json`; the hidden window was
verified by enumerating only the launched process's window metadata. No desktop
screenshots, mouse/keyboard automation or user-window interactions were used.

The release Dart payload `Release/data/app.so` was rebuilt on 2026-10-03 at
17:03:53 local time. The unchanged native runner EXE keeps its earlier timestamp
under Flutter's incremental build. Additional `git diff --check` reports three
trailing spaces in existing Markdown template strings in workspace_views.dart;
they are present in the pre-task baseline and were preserved as unrelated work.
