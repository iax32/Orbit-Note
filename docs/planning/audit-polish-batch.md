# Audit polish batch — 2026-09-10

Baseline: committed ab73def (v0.1.5), analyzer clean, 155 passing tests.
The supplied Gemini audit was read and checked against this baseline. Its source
locations and some blanket guarantees were stale; historical test success does
not prove hardware power-loss or multi-monitor correctness.

## Findings verified

- Confirmed: independent Rich text fields, formatting-boundary ambiguity, no
  process lock/recovery browser, LIKE search, no window placement restoration,
  no recurrence/IANA zones, no folder Trash, no anchored connectors/groups/columns,
  no visual math-grid controls, and no internal folder-tree drag/drop.
- Already present/outdated: Ctrl+W exists (primary pane only); Graph layout is
  cached and has a 300-node physics cutoff, not continuous per-frame simulation;
  inline equations do not break source-level find/replace. Vault switcher, open
  beside, remembered Vault, safe moves, Canvas arrangements and local math slots
  already exist. Do not rebuild them.
- Watcher burst handling already debounces targeted changes with reconciliation;
  dropped native notifications remain a platform limit, not proof of data loss.

## Scope disposition (covers consolidated request)

| Requested area | This batch and remaining boundary |
|---|---|
| Rich correctness / cross-block selection | Right arrow escapes bold/italic/strike/code closing marks without a space; left arrow returns inside. Cross-block drag/keyboard selection and inline prose–math arrow traversal remain deferred to a dedicated projection task. |
| Notes images | Existing embeds preserved; resize/caption/replace/copy controls not added. Requires a documented portable sizing representation. |
| University math / callouts | Visual pmatrix/bmatrix/matrix and aligned grids, 1–8 rows/columns (aligned retains two columns), editable cells, add/remove last row/column, standard TeX output. Existing compatible display grids offer Edit grid in Rich. Nested/irregular/embedded environments stay source-only. Seven academic callout types use existing Markdown callout menus. |
| Vault locking | Not added: ownership must cover initialize, failed-open rollback, recovery, index writes and close/crash. Existing hash preconditions retained; do not claim multi-process exclusion. |
| Recovery / version history | Evidence retained; no new browser/restore/dismiss UI. Restoration needs committed-write and recovery-evidence tests. |
| FTS5 | Native schema 3, trigram literal MATCH for 3+ characters, escaped LIKE below 3, exact-title priority then BM25. Shared search preserves index relevance; dirty drafts are inserted within their title-rank group. No content migration; see ADR-0012. |
| Note/file actions, favorites, merge | Existing open-beside/move/Trash preserved. New duplicate-object/favorites/merge/path submenus not implemented. Block duplication is distinct from copying a Universal Object. |
| Vault switch/manage | Existing switcher and recent/new/open/rename paths retained; no replacement management screen. |
| Block + / drag / slash UX | Existing between-paragraph plus retained. Block menu adds insert above/below, copy Markdown, duplicate and delete, with document undo. Block drag/reorder, move up/down, searchable slash palette and mention extensions remain deferred. No dead commands added. |
| Tasks | Open/completed plus all dates/today/upcoming filters, title search, due-date ordering, clickable row/details and quick due-date picker. Failed creation keeps input; malformed imported due dates sort safely after valid dates. Reminder/recurrence/subtask/dependency systems not added. |
| Collections / views | Existing reusable object views retained; no saved query/table/board/gallery/dashboard/chart engine added. |
| Canvas nested boards / breadcrumbs | Existing object-reference cards can reference boards. No new breadcrumbs or nested-board presentation added. |
| Canvas groups / columns / connectors | Deferred: coordinated transforms, culling, deletion, copy/paste, unknown data and undo require one validated geometry contract. Existing align/distribute remains intact. |
| Canvas toolbar/appearance / cards | Existing tools/colors retained. No new person/property/task-collection/link/GitHub/code/media/comment/table/swatches elements added. |
| Project Home / roadmap | No new templates, dependencies, release planning or derived-progress architecture. Existing primitives remain available. |
| Calendar | Existing local-time/UTC and all-day civil semantics retained; no RRULE expansion or named-zone editor. Avoid a partial recurrence implementation that misdates events. |
| Folder Trash / drag-drop | Internal note→folder/root and folder→folder/root drag/drop uses organize + safe move commands; prevents self/descendant/same-parent targets and keeps context-menu Move. Recursive Trash remains deferred pending atomic recovery design. |
| Graph performance / UI / motion | Edge counts use ID lookup; >300 nodes use stable spaced layout with expanded pan surface. Existing cached small-graph physics, focus/depth/filter/list/fit retained. 5,000-node model regression; no frame-rate claim or motion redesign. |
| Notes mode toolbar | Existing responsive modes retained; no full toolbar redesign in this batch. |
| Windows shortcuts | Ctrl+Tab / Ctrl+Shift+Tab, secondary-pane-aware Ctrl+W, middle-click tab close. Existing primary Ctrl+W/reopen retained. |
| Windows restoration | No native geometry/maximized-state persistence added; monitor/DPI testing remains separate. |
| PDF | No in-app PDF renderer added. Original attachments remain intact. |
| Resume Context | Existing Vault/session/pane/camera persistence retained. No new graph/calendar/PDF restoration schema. |

## Validation

Final: format/zero-change check and analyze pass, all 165 tests pass (155 baseline), Windows release build succeeds in 39.8 seconds. Rebuilt app reaches input-idle, responds, closes normally with exit 0 and no stderr. Added migration/literal-search, controller ranking/draft overlay, formatting escape, block undo,
math-grid structure/rendering, academic callout, pane tab-cycle, 5,000-node graph
and native folder/task workflow regressions. Complete results belong in CURRENT.

No schema migration for user-owned content; the only schema change is disposable
SQLite index version 3. No proprietary rich document or duplicate calendar store.

Windows EXE: 
C:\Users\iax\Desktop\Orbit Note\build\windows\x64\runner\Release\orbit_note.exe

Complete runtime directory: 
C:\Users\iax\Desktop\Orbit Note\build\windows\x64\runner\Release

Keep all DLLs and data with the executable. No signed installer is produced.
Next batch: native Vault ownership/locking and crash/reopen/failed-open tests,
then recovery/history browser; preserve the current green baseline.
