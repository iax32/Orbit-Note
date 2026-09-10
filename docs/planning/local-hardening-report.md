# Local hardening batch — HISTORICAL snapshot, 2026-09-09

Superseded by [CURRENT implementation status](implementation-status.md). The
polling and autosave source-conversion behavior below was replaced in the later
consolidated audit pass. Preserve this report as historical evidence only.

Continues the existing green 46-test baseline. No rewrite, cloud sync, plugin or AI
implementation. This report records the earlier delta to the initial implementation map.

## Completed

- **Backup import:** Settings → Import backup previews validated name/file count/size,
  then chooses a parent directory and publishes a separate restored folder. Stable
  identities, canonical bytes and unknown fields survive. Archive recovery journals
  are preserved for review without being replayed. Partial writes leave staging
  evidence and never overwrite the existing workspace.
- **Workspace persistence:** successful native selection is remembered outside the
  workspace; a new app/store instance reopens it. Missing folders are not silently
  recreated, and startup failure leaves the replacement-folder flow available.
- **External changes:** five-second polling and app-resume checks compare canonical
  paths/hashes. Clean notes reload; dirty notes retain their drafts and conflict-copy
  recovery. Changes to the manifest block writes until reopening.
- **Notes:** ATX/setext heading outline excluding fenced code, jump to source heading,
  literal case-insensitive Replace/Replace all, and saved per-pane mode/caret/preview
  position alongside existing source scroll. Carets clamp safely after content changes.
- **References:** uniquely resolved title links become `[[id|readable label]]` when
  saved. Rename retains old titles as aliases. Existing code examples, ambiguous
  links and unknown property data are preserved; no cross-file rename rewrite occurs.
- **Canvas:** new-element stacking order no longer scans all existing elements.
  Indexed culling remains intact. Image decoding admits a stable working set of 24
  references with four concurrent decodes, avoiding repeated eviction/redecode loops.
- **Windows interactions:** Canvas Ctrl+V falls back to image insertion when text is
  absent. Touch pans while pen/eraser mode is active; stylus strokes still draw and
  ordinary sticky placement remains functional. File capture checks a 64 MiB limit
  before reading; note drops report errors instead of leaking unhandled exceptions.

## Safety and tests

Added native export/import round-trip, portable-path collision, partial-write failure,
remembered-location/reconnect, initial-failure recovery, external-edit conflict,
rename/reference, outline, literal replacement, pane restoration, dense image-cache,
pen/touch and clipboard-fallback tests. Original storage, editor and responsive-shell
regressions remain in the suite. Capture/pen tests use simulated events and adapters,
not a physical Windows pen or real clipboard ownership.

Validation results are recorded below after final checks. The source worktree
remains uncommitted; no files were discarded or unrelated history changed.

## Canvas model measurements

Windows x64, Dart 3.12.2 JIT, direct Dart execution of `tool/canvas_benchmark.dart`.
One before/after run per version; 100 warm-up and 1,000 sampled viewport queries.
Sparse rectangles spaced 180×120, viewport 1600×1000. These measure pure model/index
work, not Flutter frame timing, image decode, pen latency or production FPS.

| Scene | Query p95 before → after | Insert 1,000 before → after | Snapshot after |
|---|---|---|---|
| 10,000 elements | 77 → 73 µs | 66.3 → 2.7 ms | 27.3 ms |
| 100,000 elements | 75 → 70 µs | 580.4 → 2.2 ms | 156.4 ms |

Visible query results remained 80/90 elements. Full-scene JSON snapshots still scale
with total size and are a real remaining large-board cost. This does not declare
the roadmap's large-board rendering or incremental-persistence gates complete.

## Remaining limitations and next recommended batch

1. Native hardware acceptance: real stylus pressure/palm rejection, Snipping Tool
   clipboard images, Explorer multi-file drops, high-DPI and multi-monitor behavior.
2. Canvas release/profile frame and memory measurements, then bounded incremental
   history/checkpoint work guided by those results; currently only 24 visible image
   references get decoded previews, and excess references retain placeholders.
3. External-file reconciliation refinement: metadata/watcher-assisted scheduling,
   attachment preview invalidation and measured cost on large workspace folders.
4. Import recovery inspection/cleanup and larger streamed backups. Current import
   is desktop-only, in memory with explicit size limits; unsupported or malformed
   canonical objects require review instead of being silently repaired.
5. Notes outline uses a compact Markdown heading parser and approximate source-scroll
   positioning, not a full syntax-tree navigator. Replacement is literal, without
   regex/case options; it is not a WYSIWYG editor. Independent pane state is not
   named sessions, nested docking or cross-window tab movement.

No cloud, plugins or AI work should displace these local quality tasks.

## Major files

`lib/application/backup_bundle.dart`, `workspace_repository.dart`;
`lib/platform/import_backup*`; `lib/infrastructure/storage/native_workspace_store.dart`;
`lib/app/workspace_controller.dart`, `session_state.dart`;
`lib/features/notes/note_editor.dart`, `note_outline.dart`;
`lib/domain/wiki_links.dart`; `lib/canvas/scene.dart`;
`lib/features/canvas/canvas_images.dart`, `canvas_editor.dart`;
workspace shell/settings, new regression tests and `tool/canvas_benchmark.dart`.
