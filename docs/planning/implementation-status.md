# Implementation status — CURRENT

## M6 sync audit — 2026-09-12

Completed a [current-code audit](sync-audit-2026-09-12.md),
[provider-neutral design proposal](../architecture/sync-design.md), proposed
ADR-0016, and Google developer setup/example configuration. Google Drive now
precedes WebDAV; older Supabase-first preferences are superseded. No auth, sync
engine, provider or cloud UI has been implemented. The owner's received brief
ends at `ARCHIVED CONTENT`; the missing requirements have been requested.

Verified current baseline: analyzer clean, 237 tests passed, Windows release build
passed in 7.1 seconds. Logs: `.local/sync-audit-tests.log` and
`.local/sync-audit-build.log`. Documentation links/example JSON/diff check passed.
Existing PDF edits are preserved. No application source was changed in this audit
phase. Next: settle the missing requirements, then implement local coordination,
deletion/recovery and durable sync state before enabling provider writes.

## Earlier implementation record

Updated 2026-09-11. This is the single current capability/completion map.
The [backlog](feature-backlog.md) owns requirement IDs and release classifications;
the [roadmap](roadmap.md) owns milestone gates. Implemented subsets do not mean an
entire milestone is complete. No cloud, plugin runtime or AI subsystem was added.

## Current capabilities and boundaries

| Area | Working now | Still unfinished |
|---|---|---|
| Local foundation | Flutter/Riverpod, Windows desktop, conditional browser adapters, Universal Object UUIDs, no account | Android/iOS device testing and production browser persistence |
| Durable files | Markdown/YAML notes, versioned JSON boards/tasks, original attachments, rebuildable Drift index, hash preconditions and recoverable saves | Multi-process locking, history browser and hardware power-loss certification |
| Backup import/export | Separate staged-folder restore, raw/unknown bytes preserved, mixed-content warnings, archive journals quarantined, empty Notes folders round-trip | Streaming large archives, recovery-review UI, browser folder import |
| Vaults | New/Open/Recent/remember last/close/startup chooser/switch; named header control/current-Vault marker; rename display name with same workspace ID | Physical Vault-directory rename, OS file associations, multiple app windows |
| Real folders | Nested Notes folders, create/rename/move folders, move notes, collapse/reveal active ancestors; six note sort orders, title filter and safe internal note/folder drop | Folder Trash/undo UI, custom manual sort, automatic adoption of ordinary Markdown |
| Notes | Directly editable Rich paragraphs/headings/lists plus Source/Read/Split; formatting with Right-arrow escape, block insert/copy/duplicate/delete, shared undo/redo, outline, literal find/replace, attachments and per-pane restoration; resizable Source/preview divider | Cross-block native selection, rich HTML paste conversion, complete CommonMark editing parity and long-document layout virtualization |
| Smart lists | Bullet/number/checklist continuation, unchecked next checklist item, empty-item exit, Tab/Shift+Tab nesting; formatted paragraph split/join | Multi-block Rich selection/nesting; Source supports selected list lines |
| Visual tables | Editable cells, Tab/Shift+Tab, final-cell Tab creates row, row/column add/remove, alignment, TSV paste, plain paste at caret, shared undo | Rectangular pipe tables only; no merged cells, formula engine, rectangular multi-cell selection or HTML/CSV conversion; 1,000-row/50-column bounds are safety limits, not a performance guarantee |
| Code and math | Editable highlighted fenced code with language/Copy code; local inline/block TeX in Rich/Read, visual fraction/script slots, searchable renderer symbol registry and templates, source/live preview, bounded visual matrix/aligned grids, academic callouts, invalid-source fallback | Highlighting is plain above 50,000 code characters; unsupported languages stay editable; inline math uses separate prose segments with limited cross-segment selection/formatting |
| References | Authored Markdown remains exact on autosave; readable links bind to UUID metadata; explicit ID links, title aliases, backlinks and rename-safe PDF page anchors | Ambiguity repair UI, general block fragment anchors and inbound ordinary path-link repair after moves |
| Source files | Strict UTF-8 read-only previews, C/C++ and other mapped language highlighting, exact Copy Code, original-file fallback | 1 MiB preview bound; plain text above 50,000 characters; unsupported encodings and code editing/execution deferred |
| PDF research | Local PDFium reader, page/zoom restoration per pane, outline/thumbnails, literal search, text selection/copy, persistent bookmarks, UUID page references, quote-to-note and source-versioned highlight notes with editable comments; changed-source and missing/corrupt recovery | Freehand ink, underline/strikeout, threaded comments, precise annotation navigation, re-anchoring, OCR, forms, redaction, signatures, page editing/export; mobile/web validation |
| Search | Native FTS5 trigram title/body/property/Canvas-text search, title-first/BM25 ranking, bounded results and unsaved-draft overlay | Boolean query language, OCR, semantic search and full indexing benchmarks; queries shorter than three characters use escaped LIKE |
| External edits | Native filesystem hints with debounced targeted hash checks; startup/resume/full reconciliation; clean reload and dirty-draft protection | Binary attachment cache invalidation, atomic handling of arbitrary external multi-file edits, cross-process exclusion |
| Canvas | Existing shared spatial grid/culling, pan/zoom, referenced cards, text/stickies/shapes/frames, images, vector ink, selection/move/resize, gesture undo; persistent columns with member movement/tidying, safe container deletion and copy/paste; website link cards with safe title/URL editing | Anchored connectors, semantic relations, nested columns/general groups, interactive embedded views and standalone freeform/PDF annotation consumers |
| Canvas performance | O(1) new stacking order, delta undo history, cached stroke points, bounded text/image caches, selective repaint comparisons, shared immutable object data | Full-board JSON checkpoints still scale with board size; release frame/memory profile on representative hardware |
| Tasks/Calendar | Universal Event objects, month/day agenda, shared safe event form, local timed input/UTC storage, exclusive all-day intervals, task deadlines/schedules and context references; Task date/search views and quick due-date editing | Recurrence, named time zones, drag rescheduling and external providers |
| Desktop shell/design | Explicit graphite/violet surface tokens, shared typography/control states, restrained rounded tabs/menus/selectors, bounded Home/Settings, grouped Notes toolbar and aligned split Notes; split-aware shortcuts/middle-click close, resizable panes, Focus/reset, inspector, reduced motion | Full docking, multi-window/tab-group drag, light/system themes and complete native window restoration |
| Graph | Cached small-graph layout, large-graph grid, linear edge counts, UUID-safe links, local focus/depth, object list and fit | Frame-time profiling, saved views, semantic relation editing and motion redesign |
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

| Check | PDF documentation follow-up, 2026-09-11 |
|---|---|
| Format / zero-change check | Passed; 120 Dart files |
| `flutter analyze --no-pub` | Passed; no issues |
| `flutter test --no-pub` | Passed; all 183 tests; PDF document creation, selected/current-page sources, highlight filters, failure/read-only feedback, durable reopen and preserved PDF bytes plus prior regressions |
| Visual checks | Updated PDF highlights/filter panel capture inspected; native document-creation menu behavior verified in widget tests |
| `flutter build windows --release --no-pub` | Passed; final build 42.1 seconds |
| Native Windows startup | Hidden process reached input idle and responded, no stderr; no closable main window exposed. Owned PID 12312 terminated for cleanup; interactive launch/close needs manual acceptance |
| Documentation / diff | Updated task/design/status links checked; git diff --check clean |

Evidence logs: `.local/pdf-documentation-tests.log`, `.local/pdf-documentation-build.log`,
`.local/pdf-documentation-release-smoke.json`;
captures in `work/ui` (ignored local artifacts).
This pass refines visual controls and motion; previous PDF highlight notes, source
previews, Vault switching and Canvas features remain intact. See the
[visual coverage report](../design/observatory-pass-2026-09-11.md),
[open formats](../architecture/implemented-formats.md) and
[visual design](../design/visual-design.md).
The [batch report](audit-polish-batch.md) covers every requested area and deferred
boundary. No user-owned content migration; only derived SQLite index schema 3.
The earlier 151-test repair and intermediate builds are historical evidence.
Web/mobile builds and physical pen/clipboard/multi-monitor acceptance were not
rerun. Native startup is not exhaustive manual testing of all interactions.
Historical Rich-only evidence: 112 tests, Windows/web builds and native startup
passed before Calendar/visual-math/graph additions. The model measurements below
are historical measurements, not benchmarks repeated for this repair.
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

Rich continuation: `lib/features/notes/rich/` (source projection, splice history,
editable blocks, tables, local math and highlighted code), `note_editor.dart`,
`markdown_editing.dart`, package manifest/lockfile, Rich model/widget/visual tests,
existing Source-mode fixtures, and `tool/note_editor_benchmark.dart`.
[ADR-0011](../adr/0011-source-preserving-rich-markdown.md) records the architecture.
The following earlier consolidated changes are preserved:

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

The owner now prioritizes precise PDF highlight-region navigation and source-version review.
Previously suggested: searchable, keyboard-navigable Rich slash and block
insertion menus preserving source ranges, undo and caret state. Focus-safe panel
transitions, source annotation navigation/re-anchoring and Vault ownership/
locking, Rich cross-block selection/drag reorder and deeper Canvas interactions
remain important tracked boundaries. Preserve exact-source fixtures and original
PDF bytes. Cloud, plugins and AI remain outside this pass.

Historical evidence (not current capability maps):
[initial local core](local-core-snapshot-2026-09-09.md),
[earlier local hardening](local-hardening-report.md).
[audit/folder delivery](audit-folder-snapshot-2026-09-09.md).
The committed baseline, including graph, callouts and document statistics, was preserved. These adjacent features retain existing test coverage but were not exhaustively audited in this repair batch.

## Rich editor boundaries and evidence

The supported Rich subset is directly editable, not a preview. Switching modes
leaves the Markdown body unchanged. Unknown frontmatter/extension blocks retain
source fallbacks. Explicit table edits canonicalize only that table; structure
commands change only their selected blocks. Save/reopen tests preserve unknown
properties, UUID identity and unrelated body bytes. No storage migration was needed.

Rich paragraph selection/caret/scroll and Source/preview state are stored per pane.
Undo is shared across modes and structural edits, retains keyboard focus after
paragraph changes, and uses bounded splices. It is not persisted across launches;
typing events are separate undo entries rather than time-coalesced words. Exact
table/code/equation caret restoration across mode changes remains limited.

Inline math is segmented prose plus clickable rendered equations. Ordinary text
on either side is editable and Enter can create a subsequent paragraph. A single
selection cannot span the equation and adjacent fields. Toolbar formatting in
these segments, full cross-block selection, list folding, captions/resize/replace
image controls, footnote/comment editing and richer clipboard conversion remain
unfinished. Formatting commands wrap selections; a collapsed selection uses an
editable sample rather than a full Word-style typing-format toggle. Unknown inline
extensions remain literal; do not claim full CommonMark or Word/Typora parity.

The document and tables currently mount all block/cell widgets. Unchanged widgets
are cached and inline parsing avoids copying the remaining source per character,
but this is not a virtualized editor. Model-only benchmark, Windows/Dart 3.12.2 JIT,
5 warm-ups and 30 samples per size (host load/JIT influence results):

| Approx. words | Characters | Parse p95 | Edit/join/history/undo p95 |
|---|---|---|---|
| 5,000 | 34,388 | 4.19 ms | 2.47 ms |
| 10,000 | 68,888 | 4.52 ms | 0.24 ms |
| 50,000 | 348,888 | 21.94 ms | 1.69 ms |

These are model costs, not Flutter layout/paint timings, FPS or a large-note UI
capacity guarantee. Hardware IME, pen, drag/drop and clipboard ownership remain
manual acceptance work; widget tests simulate those inputs where relevant.


## Rich math and Calendar repair — 2026-09-10

- Equation symbols insert into the activated fraction argument. Focused visual
  fields reflect undo/redo; the Rich block retains math-field focus on undo.
- Fraction edits preserve surrounding commands/spacing and recognize frac/dfrac/
  tfrac without treating longer command names, escapes or comments as fractions.
  Incomplete braced source remains untouched. Line breaks use an aligned math
  environment and pass rendered-output regression checks.
- Month grids use civil dates across DST. Month navigation moves the selected day
  into the displayed month. Calendar and event details share one date editor.
- Local clock input converts to UTC; unchanged precise instants survive saves.
  Failed saves keep the form open; complete payloads are written through repository
  commands, with revision checks and preserved unknown fields/context IDs.
  Invalid imported dates are preserved rather than replaced with defaults.
- Added four regression tests in `test/feature_repair_test.dart` and one source-
  preservation test in `test/rich_math_editor_test.dart`; strengthened existing
  visual undo and rendered line-break assertions. Total suite: 151 tests.

The symbol registry covers the installed renderer's math symbols plus templates,
not every macro in arbitrary LaTeX packages. The visual parser supports selected
constructs, not a complete TeX AST; complex equations retain source editing and
safe rendering fallback. Cross-segment selection remains a separate task.

## Incremental audit batch

The [scope and audit report](audit-polish-batch.md) distinguishes completed slices, outdated audit claims and deferred systems. [ADR-0012](../adr/0012-fts5-derived-search.md) records the only new schema decision, a disposable FTS index. No content migration, locking guarantee, recurrence engine or cross-block editor rewrite is claimed.

## Observatory visual delivery — 2026-09-11

The [visual pass audit](../design/observatory-pass-2026-09-11.md) is the detailed
coverage map for the current design task. It adds custom Notes modes, Canvas/rail
controls, floating dialogs, Graph controls and finite camera motion, semantic
label zoom, search composition, tab/Task/Calendar/Copy Code feedback and explicit
Normal/Reduced/Off policy. Earlier product features remain intact. No storage,
package or architecture change. The explorer follow-up now adds shared row states,
right-click/Shift+F10 menus, Left/Right folder navigation, readable stable-ID copy
references and read-only mutation guards. Folder expansion persists through the
existing session contract. Tree-wide Up/Down navigation, multi-selection and
focus-safe panel transitions remain unfinished. Rich slash/block insertion menus
are the next bounded task; annotation re-anchoring remains a product backlog item.

## PDF documentation delivery — 2026-09-11

The reader offers Research note, Game design decision and Playtest finding starters
as ordinary Markdown notes beside the source PDF. Source UUID/page/checksum and
permitted selected quotes retain provenance. Highlight title/quote/comment filtering
is session-local. No new data format or architecture decision. GAME-01 project
presets, precise annotation-region return and source re-anchoring remain planned.
This PDF priority supersedes the earlier Rich insertion-menu recommendation.

## PDF work mode — 2026-09-11

Implemented ordinary AcroForm text/checkbox editing with persistent Orbit drafts
and separate filled PDF copies. Comfort reading automatically uses a narrow text
view below 600 logical pixels, supports adjustable type and Original page return.
The form adapter uses isolated in-memory copies on PDFium's worker (ADR-0015).
Native pointer interaction, filled-copy readback, draft save/reopen/failure safety,
and 390×844 reading layout have regression coverage. Physical phone acceptance,
radios/dropdowns, XFA/signed/protected forms, OCR and semantic reflow remain deferred.

The resumed run also fixed compile/test mismatches in the pre-existing Task/block/
folder changes. Folder removal now preserves trashed note files and refuses unknown
files; block moves restore keyboard focus for undo. No new cloud/plugin/AI work.
Final complete suite: 206 tests passed; analyzer clean; formatting checked for 129
Dart files. Current logs: .local/pdf-work-tests-final.log and .local/pdf-work-build.log.
Earlier validation tables above are historical; Windows build result follows here.

Windows release build passed in 59.3 seconds. Executable:
`build/windows/x64/runner/Release/orbit_note.exe` (keep the Release folder together).
Documentation links and git diff --check pass. No physical phone build/test or
interactive Windows smoke launch was performed in this resumed validation.

## Visual PDF comfort reading — 2026-09-12

Narrow readers now default to live PDF pages fitted to conservative visual content
bounds, retaining images, tables, equations and scans. Text-only reading remains
an explicit option. This supersedes the automatic text view described above.
Added content/page/width fitting, 50–200% zoom presets and focused-reader keyboard
shortcuts. Fixed width fitting and minimum zoom clamping. Original PDF bytes are
unchanged; this is viewport fitting, not OCR or semantic layout reflow.

Regression coverage includes illustrated phone-sized pages, optional text mode,
pixel-bound safety, zoom presets and fitting shortcuts. The 390×844 capture was
visually inspected with its image and table visible. Full suite: 237 tests passed;
analyzer clean; format and zero-change check passed for 133 lib/test/tool files.
Windows release build passed in 42.4 seconds; executable:
`build/windows/x64/runner/Release/orbit_note.exe` (keep Release contents together).
Evidence: `.local/pdf-visual-reading-tests.log`,
`.local/pdf-visual-reading-build.log`, `work/ui/pdf-phone-visual.png`.
Physical phone acceptance is the next task. Dense columns can still require
pinch/pan; precise highlight-region navigation and semantic reflow remain planned.
No interactive Windows smoke launch was performed in this batch.
