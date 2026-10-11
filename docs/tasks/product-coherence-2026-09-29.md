# Product coherence milestone — 2026-09-29

Source: owner's attached **MAJOR PRODUCT COHERENCE + NATIVE POWER + DESIGN
QUALITY** prompt. Audit the working tree, not historical feature counts. The
previous performance work remains part of this milestone; retain its evidence in
[canvas performance](canvas-performance-2026-09-28.md).

## Architecture discovered

Flutter/Riverpod shell → WorkspaceController → application repository/commands →
portable Markdown/JSON/attachments, with a derived SQLite/native or memory index.
UniversalObject owns identity. Canvas elements reference object IDs; scene/ink
engine is pure Dart with Flutter painters. Views query existing objects. Native
adapters separate file access, PDF, account identity and sync transport. No new
storage type, migration, networking or runtime package is warranted here.

## Audit classification, before this pass

No surface is certified **ALREADY EXCELLENT** solely from source inspection.
The current implementation-status document still leads with September 15 work,
whereas the working tree contains later math, library, views and task features.

| Requested area | Classification | Evidence and remaining concern |
|---|---|---|
| Home / Today | WORKING BUT INCONSISTENT | `workspace_views.dart`: real due tasks, daily note, recent items, resume rows; many permanent cards/actions compete with writing. |
| Notes / Markdown | WORKING BUT INCONSISTENT | `note_editor.dart`, `rich_markdown_editor.dart`: rich/source modes, alignment, block movement, templates, tables; crowded header and popup overflow. |
| LaTeX | PARTIAL | Same note identity via `documentFormat`, rich/math/source modes; metadata regression failing and cross-block selection incomplete. |
| Canvas | WORKING BUT INCONSISTENT | Scene/history, reference cards, transclusion, contextual actions; minimap/connector hot paths optimized in preceding pass. |
| Handwriting | PARTIAL | Shared pen/highlighter/eraser/lasso, pressure data, assist/recognizers; real pen/mobile validation and general handwriting-to-math missing. |
| Explorer / folders | WORKING BUT INCONSISTENT | Real folder commands, filter menus, bookmarks; extra controls overflow narrow toolbar. |
| Universal Objects | WORKING BUT INCONSISTENT | One object identity survives placement/view changes; project context is often a name property, not uniformly an ID relation. |
| Tasks | WORKING BUT INCONSISTENT | Universal tasks, status/due/priority/subtasks/dependencies/recurrence/context; capture routes and detail controls vary. |
| Saved Views / collections | WORKING BUT INCONSISTENT | `saved_view_host.dart`: table/board/calendar/timeline; dedicated specialist dashboards have parallel presentation code. |
| Inline Dynamic Views | PARTIAL | `dynamic_view_block.dart`: existing visual/configurable live queries and snapshot distinction; config overlaps saved-view queries. |
| Calendar / Timeline | WORKING BUT INCONSISTENT | Existing date-based views over same objects; repeated date-picker wiring. |
| Graph | PARTIAL | `graph_view.dart`, `local_context_graph.dart`: relation/local views; not evidence of universal precise anchors or performance certification. |
| PDF | WORKING BUT INCONSISTENT | Reader, annotations, source-note callbacks, bookmarks, export, library/rooms; library and reader controls create competing navigation. |
| Backlinks / links | WORKING BUT INCONSISTENT | `backlinks.dart` models source/snippet/type; inspector has linked/unlinked/outbound tabs. Preserve IDs and original unresolved text. |
| Precise references | PARTIAL | PDF page/highlight and existing note anchors; arbitrary selections/equations need stable anchor contracts. |
| Properties / Inspector | WORKING BUT INCONSISTENT | Shared inspector supports typed properties and links; separate feature dialogs repeat pickers. |
| Search | PARTIAL | Indexed universal search + dirty drafts + snippets; no visual scope controls, loading incorrectly looks like no matches, type context weak. |
| Quick Switcher | PARTIAL | Ctrl+O/Ctrl+E, open/recent/favorites, keyboard; title/folder/tag substring only, every hover recomputes, all files shown as PDFs. |
| Command Palette | WORKING BUT INCONSISTENT | Ctrl+P commands, objects, contextual actions; type filters omit projects/views/events and labels differ from switcher. |
| Templates | WORKING BUT INCONSISTENT | Markdown/LaTeX catalogs and insertion already exist; do not add another template engine. |
| Archive / Trash | WORKING BUT INCONSISTENT | Object/folder archive and recoverable deletion exist; archive concepts are split between folder session state and object status. |
| History / snapshots | PARTIAL | Repository history and note/snapshot dialogs exist; integration test stalls, distinct from resume/navigation state. |
| Resume Context | PARTIAL | Session stores tabs, active/secondary IDs, note positions/views, cameras, inspector; full graph/filter/active-focus restoration unproven. |
| Project context | PARTIAL | `project_dashboard_view.dart` aggregates tasks/notes/files/canvases/activity; title-based matching needs a dedicated compatible identity pass. |
| Google Drive | PARTIAL | Account/authorization/discovery adapters plus separate tested sync foundation; no claim of proven end-to-end automatic Drive sync. |
| WebDAV | MISSING | No concrete WebDAV adapter found. Do not invent a settings toggle. |
| Android/mobile | PARTIAL | Android target/platform adapters and responsive layouts exist; native-device offline/pen/share acceptance outstanding. |
| Plugin runtime / automation | SHOULD NOT BUILD | Architecture direction only; no isolated permissioned runtime. Core commands must not become plugins to complete this pass. |
| Attachment offloading / broad OCR | SHOULD NOT BUILD | Requires proven transfer/recovery or recognition contracts; unsafe to bolt onto this milestone. |

## Selected implementation scope

P0/P1: coherent discovery and responsive existing controls. Shared object labels
and context, better quick-open matching and keyboard behavior, truthful search
loading/error/retry and optional visual filters. Fix existing menu/Explorer
overflow without removing actions. Keep all advanced features available. Do not
blindly implement every category from the brief.

Search filters apply to the existing bounded result set; the UI explicitly marks
the first 100 matches. Extending indexed structured filtering/pagination is a
separate repository query task, not a disguised full-vault scan on every key.

## Deliberate boundaries

Do not add another picker engine before refactoring actual callers; no invented
Object Lens storage. Existing document→canvas object placements/transclusion and
PDF references remain; arbitrary selected-range live placements and canvas→note
composition are deferred until stable fragment identities are specified. No sync,
storage, history-format, migration, plugin, OCR or attachment-offload changes.

## Implemented changes

- Shared pure-Dart kind/context labels; separate PDF, generic file and LaTeX
  documents. Object titles are not repeated as title-only search snippets.
- Ranked quick-open title/alias/context matching, conservative fuzzy title
  matching, cached results and text-scale-correct keyboard scrolling.
- Search debouncing/generation guards, distinct loading/error/retry/empty states,
  optional type/project filters and explicit first-100-result coverage.
- Project/view/event command-palette type filters.
- Project dashboards show their own completion totals; remove the competing
  generic Vault-wide progress strip observed during native review.
- Explorer controls wrap; navigation rail scrolls when short. Existing actions
  remain reachable. Editor, creation and snapshot menus fit available width.
- Snapshot headers/actions wrap; a failed reading-summary save stays retryable
  instead of closing the dialog and falsely reporting success.
- Regression harnesses await actual save intervals and asynchronous persistence;
  scroll to off-screen controls; use bounded frames for ongoing animations. No
  assertions removed. No user-facing animation removed.

## Validation and final report

On 2026-09-30: **1,006 full-suite tests passed** (88 seconds), analyzer clean
(8.8 seconds). All 44 focused remaining layout/interaction tests passed, including
1366×768 through 3840×2160 at 100–200% scaling. Previous 983-pass/19-failure run
was not treated as a clean baseline; hangs, responsive overflows, save timing and
off-screen interactions were investigated and corrected.

Nineteen collection/dynamic-view integration tests also passed after the native
review's project header correction. Native sample review build passed (60.7s).
Normal `lib/main.dart` Windows release built successfully (59.1s), then launched
and displayed the persisted local Home/Explorer. Final analyzer clean (4.8s),
format check: 333 files, no changes. Android release build attempted but stopped
with **No Android SDK found**; its configured path belongs to the old machine.
No SDK installation or configuration rewrite was performed.
`git diff --check` reports three pre-existing trailing spaces inside the weekly
review Markdown template string (`workspace_views.dart`); these were preserved
because they are authored template content, not changes to this pass's layout.

### Native screen evidence

The in-memory Windows review app launched successfully. Inspected Home/Today,
Markdown note, rich LaTeX document, Canvas with a referenced note, Tasks, project
dashboard, illustrated two-page PDF, Graph, Settings, Search empty and result
states, Quick Switcher and Command Palette. Explorer was visible throughout.
An additional empty-Vault build (55.4s) was launched and its Home, Notes and
Explorer empty states inspected. No user Vault was opened during these reviews.
Both restored (~1266×713) and maximized (~2560×1392) windows were observed.
Screenshots are retained locally in `.local/coherence-review/`.

Observed limitations: project membership still uses names; project fixture has no
tagged members. The generic completion strip was corrected after this observation.
The PDF test fixture is synthetic, not proof of all real-PDF compatibility.
Computer-use literal text injection did not enter text in this Flutter field;
normal key injection did, and native query results were inspected. This is not a
claim of physical keyboard, touchscreen, pen or Android-device acceptance.

## Requested outcome report

| # | Area | Outcome of this scoped pass |
|---:|---|---|
| 1 | Repository audit | Actual implementation classified above; historical counts not used as proof. |
| 2 | Product priorities | Discovery clarity, responsive controls and failure truthfulness first. |
| 3 | Architecture | Existing controller/repository, UniversalObject and spatial engine retained. |
| 4 | Product strengths | Portable local knowledge, referenced placements and existing native tools preserved. |
| 5 | Fragmentation risks | Parallel query configuration, project-name matching and competing library navigation documented. |
| 6 | UI complexity | Optional search filters, clearer context, wrapped controls and scrollable short rail; no actions removed. |
| 7 | Search | Loading/retry/filter/context behavior above; bounded coverage explicitly shown. |
| 8 | Quick Switcher | Ranked aliases/context/fuzzy titles, correct kinds, reuse and scaled keyboard scrolling. |
| 9 | Today | Existing real daily-note/task/resume workflows audited; short-window rail fixed. No new dashboard cards. |
| 10 | Resume Context | Existing tabs/cameras/document modes preserved; full graph/filter restore deferred. |
| 11 | Projects | Existing project dashboard audited, duplicate generic progress removed and palette filters exposed; stable project relation migration deferred. |
| 12 | Dynamic Views | Existing live/snapshot distinction retained; shared query refactor deferred. |
| 13 | Canvas ↔ Note | Referenced cards/transclusion retained; arbitrary selected-range live placements require stable anchors. |
| 14 | Handwriting | Shared ink retained; no separate engine or unverified recognition claims. |
| 15 | PDF/references | Correct discovery labels and truthful reading-summary export failure; original bytes untouched. |
| 16 | Backlinks/unresolved | Existing source/snippet repair audited; no rewritten unresolved text or link-format change. |
| 17 | Tasks | Existing object-based tasks remain available through discovery and existing views. |
| 18 | Mobile | Responsive fixes benefit small layouts; device/pen acceptance still outstanding. |
| 19 | Performance | Indexed connector dependencies, revision bounds, bounded rich parsing and vector minimap cache; measured evidence in linked task. |
| 20 | Extensibility | Stabilize shared commands/query interfaces first; no runtime/plugin subsystem added. |
| 21 | Deliberate deferrals | Sync/offloading/OCR/runtime, stable fragment/project migration, full indexed filters, broad picker rewrite. |
| 22 | Tests added | Three discovery tests and five canvas performance regressions, plus existing integration/layout harness fixes. |
| 23 | Full suite | 1,006 passed. |
| 24 | Analyzer | No issues found. |
| 25 | Windows | Normal `lib/main.dart` release passed (59.1s), replacing review fixture. |
| 26 | Android | Attempted; blocked by missing Android SDK and stale old-machine path. |
| 27 | Smoke test | Sample and empty-Vault apps navigated; normal production EXE launched and rendered local Home/Explorer. |
| 28 | EXE | `C:\Users\isa\Desktop\Orbit Note\build\windows\x64\runner\Release\orbit_note.exe`; built with normal entry point, smoke-launched and left open. |
| 29 | Screens reviewed | Home, Note, LaTeX, Canvas, Tasks, Project, PDF, Graph, Settings, Search, Quick Switcher, Palette, empty Vault/Notes and Explorer. Screens in `.local/coherence-review/`; responsive widget checks passed. |
| 30 | Next milestone | Stable project/fragment identity and shared visual query configuration, with compatible recovery. |

Next recommended milestone: stable project/fragment identity and shared visual
query configuration, with compatibility/recovery tests, after baseline defects.
