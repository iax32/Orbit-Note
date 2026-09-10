# Local core — HISTORICAL snapshot, 2026-09-09

This archived evidence is superseded by [CURRENT implementation status](implementation-status.md).
Statements below describe the initial 46-test checkpoint only.

Current update: [local hardening batch](local-hardening-report.md) supersedes the
remaining-work and test-count entries below. The following is the preserved initial
local-core snapshot; use the linked report for current capabilities and limits.


This was the initial implementation-completion map. The [backlog](feature-backlog.md)
remains the single requirement/classification map. A working subset does not mark
an entire feature family or roadmap milestone complete.

## Working local features

| Area | Implemented subset | Remaining boundary |
|---|---|---|
| Foundation | Flutter app, Riverpod composition, native and conditional browser adapters; no account required | Mobile runners retained; device validation pending |
| Storage/M1 | Stable UUID objects, Markdown/YAML notes, documented JSON boards/tasks, ordinary attachments, native Drift index, file hash checks, history and interrupted-write recovery | No multi-file transaction protocol, continuous file watcher or production multi-process locking |
| Notes/M2 | Create/rename/edit, autosave, source/read/split Markdown, formatting shortcuts, undo/redo, find, wiki-link chooser, backlinks, local attachment preview | Source-oriented editor, no WYSIWYG block engine; title-only links can break on rename; chooser inserts stable IDs |
| Search/M2 | Local title/body/property filtering and repository search/index | No ranked full-text query language, OCR or semantic search |
| Attachments/M2 | File selection/drop, image clipboard capture, checksum deduplication, file objects, note image links, open original/show in folder | No PDF annotation, OCR, audio pipeline or attachment garbage collection |
| Canvas/M3 | Pan/anchored zoom, spatial culling, cards referencing live objects, sticky/text/shapes/lines/arrows/frames, selection/move/resize, undo/redo, image insert/drop/paste | Frames are visual; connectors are not bound semantic relations; no nested groups or measured large-board rendering budget |
| Ink/M4 | Editable vector strokes, pressure samples and stroke eraser on the shared board engine | No device-certified palm rejection, recognition, PDF annotation or complete freeform-page consumer |
| Tasks/M5 subset | Create, edit, complete, priority, due date and context reference | No recurrence, Kanban, calendar or full custom-property/type editor |
| Shell NAV-03/04/07 | Open/close/reopen/reorder tabs, right/down split with draggable ratio, same note in two panes, per-pane source scroll, Focus and reset | Two panes only; no tab dragging between groups, pinned tabs, independent pane focus model or full docking |
| Home/context | Real recent objects and continuation; saved tabs, cameras, layout and reading preferences | No named Spaces/session snapshots; explicit folder selection is not remembered globally |
| Recovery/portability | Trash/restore without physical deletion, retained failed drafts with retry/recovered copy, open-format backup bundle export | No bundle import UI, history browser, permanent-delete UI or bounded history retention |
| Visual design | Graphite/violet dark theme, semantic radii, desktop shell, readable empty states, optional inspector, motion settings honoring OS reduction | Light/system theme variants and every planned micro-interaction remain future work |

## Finished integration and stability work

Preserved the existing project and joined storage, Notes and Canvas through the
application repository. Fixed task priority/schema mismatches, misplaced widget
code, missing Material ancestry, save races that could replace newer drafts,
refresh/trash overwriting unrelated dirty notes, split navigation/state, Canvas
text drafts on leaving an editor, image references/previews, and semantic theme
interpolation. Layout saves now drain before exit; a failed workspace switch
reopens the previous workspace. Canvas placements now receive UUIDs.

## Validation

Final command results are recorded below after the final build. Unit/widget tests
exercise data and UI boundaries, not full hardware or distribution readiness.
Screenshot fixtures are deliberately created by tests, never seeded into the app.

## Main implementation files

- `lib/app/`: composition, theme, session state and save coordination.
- `lib/application/workspace_repository.dart`: validated local mutations and export.
- `lib/domain/`: universal objects and wiki-link parsing/resolution.
- `lib/infrastructure/storage/`: native/browser stores, codec and rebuildable index.
- `lib/features/notes/`: source editing, preview, formatting and link insertion.
- `lib/canvas/` and `lib/features/canvas/`: shared geometry/scene/history and board UI.
- `lib/features/workspace/`: shell, two panes, tasks, search, attachment and settings UI.
- `lib/platform/`: export and native attachment actions behind platform boundaries.
- `test/`: persistence/recovery, editing, controller, Canvas and responsive UI regressions.

The worktree has no committed baseline: its files are untracked. This run preserved
that state and did not create a commit, rewrite history or discard user work.

## Next priorities

1. Safe backup import into a new workspace with complete round-trip tests.
2. Remember selected workspace across launches and add external-file change detection.
3. Improve Notes outline/find-and-replace and per-pane caret/preview restoration.
4. Profile Canvas on real Windows hardware; test pen, clipboard images and large boards.
5. Extend the shared engine to a real freeform page and then PDF annotations.

Cloud sync, plugin execution and AI remain separate later architecture tasks.
License selection, signing, installer packaging and production release are pending.

### Final verification results (2026-09-09)

| Check | Result |
|---|---|
| `dart format lib test` | Passed; 49 Dart files formatted |
| Zero-change format check | Passed; 0 changes |
| `flutter analyze` | Passed; no issues |
| `flutter test --no-pub` | Passed; all 46 tests |
| Windows debug build | Passed; `build/windows/x64/runner/Debug/orbit_note.exe` |
| Web build | Passed; `build/web`; WASM dry run also succeeded |
| Visual fixture check | Passed; Home/Canvas/Settings screenshots generated and inspected; split/Focus UI test passes |
| Documentation checks | 71 Markdown files: local links resolve; 264 unique requirements retain exact backlog coverage; five JSON schemas parse |

The web build emits a non-blocking CupertinoIcons font advisory inherited from
Flutter's icon references; this UI uses Material icons. Android/iOS builds, browser
runtime durability, hardware stylus/clipboard workflows, installer/signing and
release performance measurements were not validated. Windows output is a debug
build; run it with its adjacent DLL/data files, not as a copied standalone EXE.

Native smoke launch: `flutter run -d windows --no-pub` built and started the final
app, connected its VM service and reported no startup exceptions during observation.
The smoke process was then closed normally. This is a startup check, not a claim
of complete manual testing of all native workflows.
