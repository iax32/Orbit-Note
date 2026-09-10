# Audit/folder delivery — historical snapshot (2026-09-09)

Updated 2026-09-09. Historical evidence only; implementation-status.md owns the current map.
The [backlog](feature-backlog.md) owns requirement IDs and release classifications;
the [roadmap](roadmap.md) owns milestone gates. Implemented subsets do not mean an
entire milestone is complete. No cloud, plugin runtime or AI subsystem was added.

## Current capabilities and boundaries

| Area | Working now | Still unfinished |
|---|---|---|
| Local foundation | Flutter/Riverpod, Windows desktop, conditional browser adapters, Universal Object UUIDs, no account | Android/iOS device testing and production browser persistence |
| Durable files | Markdown/YAML notes, versioned JSON boards/tasks, original attachments, rebuildable Drift index, hash preconditions and recoverable saves | Multi-process locking, history browser and hardware power-loss certification |
| Backup import/export | Separate staged-folder restore, raw/unknown bytes preserved, mixed-content warnings, archive journals quarantined, empty Notes folders round-trip | Streaming large archives, recovery-review UI, browser folder import |
| Vaults | New/Open/Recent/remember last/close/startup chooser/switch; rename display name with same workspace ID | Physical Vault-directory rename, OS file associations, multiple app windows |
| Real folders | Nested Notes folders, create/rename/move folders, move notes, collapse/reveal active ancestors; six note sort orders and title filter | Internal drag/drop organization, folder Trash/undo UI, custom manual sort, automatic adoption of ordinary Markdown |
| Notes | Source Write/Read/Split, formatting, undo/redo, outline, literal find/replace including Ctrl+H, attachment insertion/preview and per-pane caret/scroll/mode restoration | Rich block editing, smart list Enter/Tab, visual table editing, highlighted copyable code blocks, resizable internal source/preview divider; outline scroll is approximate |
| References | Authored Markdown remains exact on autosave; readable links bind to UUID metadata; explicit ID links, title aliases and backlinks | Ambiguity repair UI, fragment anchors and inbound ordinary path-link repair after moves |
| Search | Indexed title/body/property/Canvas-text search, title-first ranking, bounded results and unsaved-draft overlay | FTS5/query language, OCR, semantic search and full indexing benchmarks |
| External edits | Native filesystem hints with debounced targeted hash checks; startup/resume/full reconciliation; clean reload and dirty-draft protection | Binary attachment cache invalidation, atomic handling of arbitrary external multi-file edits, cross-process exclusion |
| Canvas | Existing shared spatial grid/culling, pan/zoom, referenced cards, text/stickies/shapes/frames, images, vector ink, selection/move/resize, gesture undo | Anchored connectors, semantic relations, real groups/columns, interactive embedded views and standalone freeform/PDF consumers |
| Canvas performance | O(1) new stacking order, delta undo history, cached stroke points, bounded text/image caches, selective repaint comparisons, shared immutable object data | Full-board JSON checkpoints still scale with board size; release frame/memory profile on representative hardware |
| Tasks/Calendar | Real Task objects, completion/priority/due dates/context | Calendar object type, month/agenda, events and recurrence are not implemented |
| Desktop shell/design | Graphite/violet theme, restrained rounded surfaces, tabs, two resizable side-by-side or stacked panes, Focus/reset, inspector, reduced motion | Full docking, multi-window/tab-group drag, light/system themes and complete native window restoration |
| Native capture | File picker/drop, bounded attachment reads, image paste adapters, Canvas clipboard fallback, simulated pen/touch paths | Physical pen/palm rejection, real clipboard ownership, high-DPI/multi-monitor and hardware drop acceptance |

## Audit resolution

Confirmed and fixed: autosave source rewriting; growth of completed recovery journals;
overly strict mixed-backup rejection; unsafe attachment launch without confirmation;
idle recursive polling; shell search bypassing the index; full-scene history copies;
Canvas text layout churn and unnecessary whole-app rebuilds.

Preserved existing working paths: file-authoritative save/reopen, UUIDs, unknown
fields, hash conflict checks, dirty-draft recovery, culling and conditional platform
adapters. Earlier claims that import, selected-folder persistence, native watchers,
rename-safe bindings or delta history were absent are now outdated.

Autosave does **not** convert title links to ID syntax. It records
`properties.orbitLinkBindings` while keeping the body exact. An explicit note/folder
move may rebase ordinary Markdown destinations; this is an authored command, not
background normalization. See [ADR-0009](../adr/0009-audit-and-incremental-local-state.md)
and [ADR-0010](../adr/0010-notes-folder-moves.md).

## Data-safety limits

- Backup limits: 128 MiB encoded, 80 MiB decoded, 10,000 files and 10,000 optional
  Notes-directory entries. Invalid containers/paths/manifest identities fail before
  writing; malformed objects and ordinary Markdown remain bytes with warnings.
- Completed native history has 200-entry / 64 MiB / 30-day targets, while retaining
  at least the latest prior version for each path and protecting unresolved recovery.
  These exceptions can exceed the targets; pending recovery is never pruned by age.
- Folder commands preserve IDs and stage recoverable content changes. Unexpected
  edits/collisions stop recovery and open the Vault read-only. Unknown Markdown and
  symlink-containing folders cannot be moved automatically. Move failures retain
  journals and before/after bytes for review; there is no recovery browser yet.
- Common inline/reference Markdown destinations are rebased; code stays exact.
  Complex HTML/Markdown link syntax and incoming path links from outside the moved
  tree need manual review. UUID/wiki references survive moves without cross-file edits.
- No proof of atomicity across arbitrary external applications or sudden device
  power loss. Tests inject application/storage failures and compare preserved bytes.

## Validation evidence

| Check | Final result, 2026-09-09 |
|---|---|
| `dart format lib test tool` and zero-change check | Passed; 71 Dart files, no remaining changes |
| `flutter analyze` | Passed, no issues |
| `flutter test --no-pub` | Passed, all 77 tests; includes nine added folder/recovery/UI tests and Ctrl+H coverage |
| Windows debug intermediate gate | Passed after folder integration |
| `flutter build windows --release --no-pub` | Passed; final rebuild including recovery-directory guard, 43.4 seconds |
| Windows release startup | Final Orbit Note native window created, process responsive, no stderr errors; normal WM_CLOSE completed with exit code 0; physical interaction acceptance not claimed |
| `flutter build web --no-pub` | Passed, 56.7 seconds; WASM dry run succeeded |
| Visual fixtures | Desktop two-pane/Canvas/Settings test passed with refreshed screenshots; Notes split and Canvas inspected |
| Documentation | Local links resolve, five schemas parse, 264 unique requirements match 264 backlog rows without duplication |

The web build retains a non-blocking CupertinoIcons font advisory. The app uses
Material icons; no analyzer/test/build error is hidden. Android/iOS builds and
physical pen, clipboard, drag/drop, high-DPI and multi-monitor acceptance remain unverified.

Windows EXE:
`C:\Users\iax\Desktop\Orbit Note\build\windows\x64\runner\Release\orbit_note.exe`

Complete runnable folder:
`C:\Users\iax\Desktop\Orbit Note\build\windows\x64\runner\Release`

Keep the entire folder together: Flutter, SQLite and plugin DLLs plus `data` are
required. This is a locally built release, not a signed installer/public distribution.

## Canvas model measurements

Final Windows x64 / Dart 3.12.2 JIT run of `tool/canvas_benchmark.dart` after builds
finished. Sparse rectangles, 100 warm-up and 1,000 sampled viewport queries.

| Elements | Query p95 | Insert 1,000 | Full JSON snapshot |
|---|---|---|---|
| 10,000 | 142 microseconds | 3.44 ms | 55.5 ms |
| 100,000 | 147 microseconds | 2.94 ms | 433.0 ms |

Results vary with host load/JIT conditions and are not controlled release-rendering
comparisons or FPS claims. Queries returned only 80/90 visible items. The full
snapshot remains a significant large-board cost; viewport culling does not remove
that persistence cost. Hardware frame/memory profiling and incremental checkpoint
design remain required before declaring large-board performance complete.

## Main files changed in the consolidated pass

- `lib/application/workspace_repository.dart`, `backup_bundle.dart`: commands,
  reference bindings, folders, import/export and indexed query integration.
- `lib/infrastructure/storage/`: native save/history/watch/selection, folder move
  recovery, portable path checks and index schema v2.
- `lib/app/workspace_controller.dart`, `session_state.dart`, `orbit_app.dart`:
  save/draft coordination, Vault lifecycle, pane/folder preferences and selectors.
- `lib/domain/note_path_links.dart`, `wiki_links.dart`, `universal_object.dart`,
  `object_sort.dart`, `attachment_safety.dart`: portable domain behavior.
- `lib/features/workspace/note_folder_explorer.dart`, `workspace_shell.dart`,
  `lib/features/notes/note_editor.dart`: usable folder/Vault/Notes workflows.
- `lib/canvas/scene.dart`, `lib/features/canvas/`: delta history and bounded caches.
- `lib/platform/import_backup*`, `vault_folder*`: native publication and selection.
- `test/audit_safety_test.dart`, `folder_organization_test.dart`, backup, Notes,
  Canvas, index and controller tests; `tool/canvas_benchmark.dart`.

## Continuation

Next recommended batch: Notes editing comfort, beginning with tested smart
list/checklist Enter and Tab/Shift+Tab behavior, accurate outline navigation and
per-pane editing restoration. Then visual table/code editing, Calendar objects and
shared Canvas groups/anchored connectors, in that order after green gates. Complete
folder recovery-review and native hardware acceptance alongside those local tasks.
Cloud, plugins and AI remain later.

Historical evidence (not current capability maps):
[initial local core](local-core-snapshot-2026-09-09.md),
[earlier local hardening](local-hardening-report.md).
The repository still has no committed baseline; existing untracked work was preserved.


