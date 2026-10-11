## Shared Vault preview and Drive backups — 2026-10-11

SYNC-02/03/04/05/09/10 subset: self-hosted existing-note/Canvas sessions with
named pointers, role-checked invitations/revocation, known-base merges, durable
append/flush acknowledgement, restart repair, failed-storage mutation refusal,
idempotent proposal retry, delta polling and ordinary local save/history. Viewer
notes remain scrollable and Canvas remains navigable. Portable IDs/unknown data
are retained; sharing explicitly includes a whole-Vault initial copy.
Google Drive has manual immutable resumable backups, verified downloads and
reviewed import into a new folder with account isolation/progress/cancellation.
These are separate from the still-gated automatic personal sync provider.
OAuth registration is unconfigured; actual Google transfers, remote HTTPS
deployment and two-device acceptance are unperformed. Existing notes/Canvas only;
continuous attachment/new-object/deletion sync, text carets/selections, CRDT and
E2EE remain absent. A native Windows server binary is compiled and locally running.
The Windows app release is rebuilt and packaged with that server; all 1,871 tests,
analysis and strict formatting pass. Saved-account restore/sign-in automatically
load backup listings and partial refresh failures remain retryable. Google app
registration is still absent, so the packaged release is local-only. See current
task for validation evidence.

## Source libraries and BibTeX — 2026-10-11

FILE-10/14 / PORT-05 subset: reusable canonical Markdown library notes, selected
metadata snapshots with library UUID navigation, reviewed BibTeX file/paste import,
explicit identifier/DOI collision policies and export with retained extra fields.
Bulk source updates preserve unknown data and cite keys; stale plans refuse writes.
Native dialog acceptance, automatic propagation, full BibLaTeX/CSL and online lookup
remain unimplemented. See current task for validation.

## Document publishing workspace — 2026-10-11

Citation addition: FILE-10/14 now has manual note-owned bibliographic metadata,
search/edit/source removal guards, locator citation insertion, compact author–year
and numbered generated References, lossless Rich projection and Read presentation.
Publishing refreshes citations/bibliography without rewriting the note. Unknown
fields/versions remain portable. Reusable library notes/BibTeX extend this above;
CSL, full APA/MLA and metadata lookup remain unimplemented. See current task for validation.

PORT-05/06/08/09 / EDT-02/08/12: immutable Markdown publication snapshots, actual
PDF preview, page size/margins/fonts, author/title/header/page-number controls,
heading numbering and linked contents; PDF, standalone safe HTML and editable
OOXML Word exports. Native Word footnotes, linked PDF/HTML endnotes, tables,
bounded local images, rendered equations and linked-section snapshots are wired.
Fidelity warnings expose fallback resources, font coverage and format differences.
Original notes/assets remain unchanged; save cancellation/failure uses existing
platform boundaries. Bundled font licenses accompany assets. No device acceptance
or printer integration is claimed. See current task for final validation evidence.

## Model assets and narrative templates — 2026-10-11

FILE-02/03, CAN-02/03/04, GAME-01 and EDT-09 now include offline OBJ/GLB static
geometry inspection, orbit/orthographic controls, zoom/Fit, shaded/wireframe
presentation and GLB scene transforms/base-colour tint. Bounded parsing preserves
original bytes and reports missing, malformed or unsupported geometry with
retry/open-original fallback. Canonical linked Canvas cards use ordinary scene
placements/history; removing cards preserves attachments. Six searchable story
and game-writing templates create ordinary editable Markdown.

Focused parser, viewer, template, persistence and clipboard checks pass, including
narrow 200% text layout. See [task evidence](../tasks/current.md) for final counts.
No new dependency or durable schema. Texture/rig/animation rendering and model
thumbnails remain future work; native/device acceptance is unperformed.

## Playtest and release workspace — 2026-10-10

GAME-01–03/DEV-02 extension connects build comparison, regression/task queues,
finding evidence and release coverage in the gameplay workbench. Reusable Markdown
test plans have five presets and separate build-specific runs; checked items and
explicit outcomes drive conservative coverage, with plan-revision invalidation.
Original objects/history remain; unknown metadata survives and failed writes are
recoverable. Manual review only, without engine execution or automated certification.
37 focused regression tests pass, including persistence and 200% text layouts.
The full 1,781-test suite, analysis and strict formatting pass. No native acceptance
or refreshed Windows release is claimed; the installed app was running.

## Gameplay source capture — 2026-10-10

Local source ranges now copy exact bytes as text or safe Markdown code fences,
and prefill existing mechanic code-reference forms. Captures clear unrelated
revision claims; immutable commit verification remains manual. Read-only keyboard
cut preserves external files; clipboard errors have visible feedback. Additional
Unreal/Godot/Luau extensions use existing source browser language mappings.
No Git/IDE execution, external source editing or new storage format.
All 1,776 regression tests pass, with clean analysis and strict formatting.
Native clipboard acceptance and release replacement are not performed in this batch.

## Note / Canvas clipboard transfers — 2026-10-10

Rich image selection and menus now support copy/cut; complete image-block paths
are portable from Rich/Source selections. Canvas pastes image/media rows and
standalone object links as placements; notes accept Canvas image/object/text data
as Markdown in Rich and Source. Cuts await clipboard success and reject intervening
changes; Canvas paste remaps groups/connectors/ink coordinates. Shared attachments
remain intact and mutations use existing undo. Same-Vault scope; inline images,
cross-Vault bytes and arbitrary drawing conversion remain outside this batch.
Validation evidence: [current task](../tasks/current.md).

## Code editing tools — 2026-10-10

The subsequent studio batch adds rendered, wrap-aware viewport line numbers and
gutter selection/caret reveal, responsive captured-original/draft comparison,
safe HTML/XML/CSS/SCSS comment wrappers, literal selection wrapping, line deletion,
explicit whitespace cleanup and undoable reset. Original comparison remains read-only;
line ranges/width estimates are cached. This is not Git diffing, code execution or
a language server. Current validation evidence is in the task document.

Expanded Markdown code drafts add Unicode-aware literal find/replace, previous/
next navigation, case/whole-word options, go-to-line, selected-line duplication/
movement, supported line-comment toggles, configurable indentation and smart Enter.
Keyboard and toolbar undo/redo reuse bounded splice history with selection recovery;
read-only, composition and stale-source guards remain. Controls scroll at compact
widths/enlarged text. No code execution, language server or external source writing.
Validation evidence is recorded in [current task](../tasks/current.md).

## Structured writing workspace — 2026-10-10

The latest authorized editor batch adds searchable whole-section planning, focus,
outline-only editing and restored focus view state; on/off/mixed typing formats,
cross-block prose formatting and Rich/Source/Split source-selection transfer;
marker-click/multiline footnote management with safe renames and diagnostics;
and incoming/outgoing section-use impact previews, navigation and explicit repair.
This supersedes historical claims below that collapsed formatting inserts a sample,
footnote editing is absent, or only segmented math paragraphs can be edited.
Continuous math editing retains authored TeX in one native field and rendered
editable previews; seamless native selection across rendered widgets is not claimed.
No storage migration/package was added; edits use normal recoverable Markdown saves.
All 1,744 regression tests and the final 64 focused checks pass; analysis and
strict formatting are clean. Windows and web JavaScript release builds pass.
Detailed validation evidence and existing web warnings are recorded in current task. Full CommonMark/Word parity
and native IME/real-device acceptance remain separate limits.

# Implementation status — CURRENT

## Offline document review — 2026-10-10

Selected Rich/Source passages support local comments and explicit replacement
suggestions. The dock/sheet review panel filters unresolved entries, comments,
suggestions or all receipts; it navigates/selects exact passages and supports
resolve/reopen, accept/reject, remove and explicit reattachment. Stable block
anchors and conservative quote/context matching prevent silent retargeting.
Ambiguous/changed passages disable acceptance; stale composer drafts cannot
overwrite later note changes. Accepted wording and receipt undo together.
Versioned Markdown JSON comments preserve portable annotations and unknown fields;
Rich/Read hide supported records, while Source exposes them. Normal repository
save/history remains authoritative, with failed-save/reopen regression evidence.
No shared comment threads, automatic review service or persistent inline review
decoration is claimed. Thirteen focused tests pass; full validation evidence is
recorded in [current task](../tasks/current.md).

## Live linked note sections — 2026-10-10

Insert/slash **Linked section** searches Markdown notes and previews a paragraph,
heading section or list/checklist. Source block anchors are saved through normal
recoverable commands, including ATX/setext headings; source-save failures and
stale picker/host state prevent insertion. Rich/Read share live selectable previews
and precise source navigation, with explicit saved-snapshot fallback for missing,
duplicate, cyclic or oversized targets. Rich can remove only the embed or detach
current nested content through existing host undo/save. Cached Rich previews refresh
on workspace source changes. Markdown comment metadata plus quoted fallback remains
portable; unknown data remains literal. Nested previews/copies are bounded, preserve
fenced examples and never execute source. Same-note embeds are conservatively
excluded. Read controls remain reading-only; section backlink/impact indexing is
not delivered. Nine focused tests pass; final full checks/release evidence is in
[current task](../tasks/current.md).

## Read-only local source-file browser — 2026-10-10

Game dashboard folder selection, source path filtering, lazy numbered/highlighted
lines, selected-file search and match navigation, case toggle, exact copy, reload
and refresh are delivered. Native adapters bound scan depth/count and source read
size, exclude generated folders/links and report incomplete/error states. Narrow
enlarged layouts have bounded scrollable headers and switchable file/source panes;
stale async results are discarded. No writes/execution/import, Git history/diff,
automatic revision capture, persistent access grant or cross-file content search.
Native folder browsing is unavailable on web. Plain-text fallback for >50,000 chars
and unknown syntax grammars is explicit. Four focused tests pass; full validation
evidence is recorded in [current task](../tasks/current.md).

## Connected gameplay development workbench — 2026-10-10

Game dashboards open a mechanics workbench with specification/evidence comparison,
explicit canonical resource links, missing-link removal, source text/build filters
and 30-item pagination. Manual repository citations retain exact commit/path/lines/
excerpt and distinguish captured branches. Build playtests retain expectations,
observations and linked evidence; converted fix tasks inherit mechanic/build and
source UUID. Verification adds independent passed/failed/blocked notes with linked
task and implementation evidence; the latest result appears beside the current task.
Older results and manual task status remain intact. Revision warnings preserve
captured evidence. Device-local gameplay continuation restores related open tabs,
positions/cameras and next step, preserving unrelated state and skipping/resetting
missing/changed sources. Unfinished work is queried from current canonical tasks.

GAME-01–03/DEV-02–04 local workflow subsets; no Git/IDE/engine adapter, automatic
test execution, repository rewrite, shared sessions or atomic multi-file finding
conversion is claimed. Partial backlink failure retains the task and reports recovery
needed. Existing Markdown save/history and context formats are reused; no migration
or dependency. Six focused tests pass, including native restart, unknown property
preservation, invalid/failed/stale records, exact code excerpts, context isolation,
form save/stale rejection and 390px/200% layouts. Analysis is clean; full-suite and
release evidence tracked in [current task](../tasks/current.md).

## Figure captions and linked sources — 2026-10-10

Media sections support a caption and up to 20 labelled sources. A local note picker
stores stable UUID links; manual links cover HTTP(S) and relative attachments with
page fragments. Caption/source editing, ordering and removal use the owning note's
save/undo and check stale figure/note identity. Rich/Read render responsive captions
and source chips; ordinary Markdown remains readable outside Orbit. Invalid/future
details stay literal. No remote metadata, bibliography generation or attachment
ownership changes. [Evidence](../tasks/current.md),
[format](../architecture/implemented-formats.md#markdown-image-and-text-sections--2026-10-10).

## Markdown image-and-text sections — 2026-10-10

Rich insert/slash commands and existing-image actions create editable media sections
with rounded images, left/right placement and three width presets. Inline rich
headings/lists/prose use existing note save/undo; image replacement/removal and
stacked conversion retain attachment ownership. Read uses the same responsive
layout and original-source action. Ordinary Markdown plus comment markers provides
a portable vertical fallback; unfamiliar/incomplete forms remain source-editable.
Evidence and limitations: [current task](../tasks/current.md),
[format](../architecture/implemented-formats.md#markdown-image-and-text-sections--2026-10-10).

## Working-day project scheduling — 2026-10-10

Reusable canonical calendar notes define working weekdays and named dated
exceptions. Gantt view defaults and explicit task bindings support inclusive effort,
forward/backward date calculation, calendar-aware moves and blocker suggestions.
Existing dates never reflow on calendar edits. A paginated audit exposes unscheduled
work, dependency warnings, non-working endpoints and effort mismatches for reviewed
single-task saves with guarded undo. Unknown calendar fields survive restart;
unsupported/missing sources and stale save conflicts remain visible. Calendar days
remain available for legacy scheduling. Hours/capacity, automatic propagation and
critical-path analysis remain unimplemented. Evidence: [current task](../tasks/current.md).

## Dependency-aware task Gantt — 2026-10-10

Saved Gantt views, shared Smart View filters and live note embeds show explicit
work ranges, independent deadline markers, one-day milestones, visible dependency
connectors and missing/unscheduled/overlapping blocker warnings. Existing cycles
are flagged. Drag moves require a reviewed schedule form; range editing and
after-blocker suggestions use guarded single-task saves/undo. Calendar scheduled
moves preserve duration. Folder and command palette creation reuse canonical IDs.
50-row pages and 14/28/56-day windows bound the chart. Automatic propagation,
critical paths and cross-object transactions are not claimed. Working-day calendars
are delivered in the subsequent scheduling batch above.
Validation is recorded in the current task.

## Research collections and evidence-based decisions — 2026-10-10

Implemented: reusable manual reference collections, gallery/table/comparison,
persistent filters, live board commentary with local overrides, project brief
alongside evidence, and live orbit-view embeds. Structured decision/assumption
notes retain reasoning, confidence/importance, typed source dependencies,
deterministic changed/missing/disproved-source review reasons and note checkpoints.
Backlinks/graph reuse canonical UUID relations. New creative projects include a
research view; existing folders and command palette expose creation. All core
work is local without new dependencies. See the feature specs and current task
for limits and validation. Citation scraping, semantic analysis, automatic board
membership, full workspace history and state-field restoration are not claimed.


## Creative reference capture — 2026-10-09

Creative boards capture dropped original files as canonical sources, spaced preview
cards and column membership. Every Canvas offers multi-file capture. Captions,
manual source URLs, tags and review states belong to placements; bulk state edits,
metadata search and linked Markdown summary snapshots reuse existing boundaries.
Partial failures retain saved sources; insertion and curation use Canvas undo.
Validation and limits are recorded in [current task](../tasks/current.md).
## Connected creative planning and Canvas removal — 2026-10-09

New Creative Project creates linked briefs, decisions, references/production boards,
canonical tasks, task lists and custom-stage milestone views. Shared scope is the
brief UUID. Validated saves survive native restart; partial setup keeps saved
knowledge and reports failure. Automatic setup resume is not implemented.
Selected Canvas cards/sections have visible removal, including the interior
context menu; sources and column children remain available and undo restores them.
See [current task](../tasks/current.md) for validation evidence and limitations.
## Future calendar occurrences — 2026-10-09

Month/week calendars and planning agenda/day/week grids project bounded future
events with stable occurrence keys and canonical UUIDs. Individual date/time moves,
cancellations and Restore use portable overrides on the original event, guarded
saves/undo and document history. Moved windows and same-series timed overlaps are
handled; current completion records actual dates while preserving cadence.
Current ICS snapshots apply supported current changes. No RRULE sync, notifications,
named-zone recurrence or historical occurrence editing is claimed. Bounds and
validation evidence are in [current task](../tasks/current.md) and
[ADR 0026](../adr/0026-calendar-occurrence-projection.md).

Validation: 32 focused and 1,622 full tests pass; clean analysis/strict formatting
(456 files unchanged), docs links and diff whitespace pass. Native restart retains
overrides; UI controls, stale writes, undo and final cancellation are covered.
Windows release and web JavaScript release compile. Existing Wasm dry-run and
Cupertino-font warnings remain; no signed installer or mobile build is claimed.

## Rolling event recurrence — 2026-10-09

Local EVT-01–03 now includes same-identity rolling event repeats, daily/weekly/
monthly/yearly intervals, count/end limits, pause, explicit completed/skipped
history, six-start preview and device-clock overlap/gap policy. The active event
advances one occurrence with guarded recoverable saves and undo. Future projection
and individual changes are extended by the section above; named-zone recurrence
and RRULE exchange remain separate.
See [ADR 0025](../adr/0025-rolling-event-occurrences.md) and
[current task](../tasks/current.md) for validation and remaining boundaries.

Validation: 23 focused and 1,613 full tests passed; clean analysis and strict
formatting (454 files unchanged), documentation links/diff whitespace pass.
Native empty-index restart preserves schedule/history and unknown/future fields.
Clock gap/overlap behavior uses deterministic test fixtures, not desktop control.
Windows debug/web JavaScript release compile; existing Wasm/font warnings remain.

## Calendar and linked course planning — 2026-10-09

Local STUDY-01 planning/TASK-03–06/EVT-01–03 subsets now include timed day/week,
30-day agenda, course/type/text/completed filters, unscheduled effort queue,
remembered views, assignment/exam/lecture/meeting/study presets, canonical resource
links/backlinks, linked study sessions, exam review workload/horizon, interval
conflicts, existing undo/recurrence/dependencies and filtered ICS snapshots.
Portable metadata and device settings reuse repository/view boundaries. Current
task records validation/limits; no provider sync, notifications, event RRULE,
named-zone ambiguity handling or time-grid drag/resize is claimed.

Validation: **1,604 full tests and 67 focused checks pass**, clean analysis and
strict formatting (450 files, zero changes). Native restart, guarded writes,
portable metadata, calendar export and enlarged-text layouts are covered.
Windows debug and web JavaScript release compile. Existing Wasm dry-run and
Cupertino font warnings remain; no signed release or mobile build is claimed.

## Study Resume — 2026-10-09

Manual STUDY-04 course continuation is delivered through Study & Review. Save
course tabs/view positions and a written next step, resume with missing/changed
source fallbacks, inspect current unfinished tasks, and dismiss reason-labelled
uncertain course material. Existing device-local Space descriptors and reader
state are reused; current content remains authoritative. Validation evidence and
limits are in [current task](../tasks/current.md). This does not deliver broader
learning maps, automatic context tracking or cross-device continuity.
Validation: 1,590 full tests and 41 focused checks pass; clean analysis and
strict formatting. Native device-settings restart retains the continuation,
positions, dismissals and unknown fields; compact 200% text is covered.
Windows debug and web JavaScript release compile. Existing Wasm dry-run and
Cupertino font warnings remain; see current task for exact logs and boundaries.

## Study cards and offline review — 2026-10-09

STUDY-05 and manual STUDY-03 states: Markdown cards, source snapshots/page return,
fixed offline scheduling/history, course and exam-horizon workload, editable
answers, pause/resume, guarded undo and archival JSON export. Home/course, note
selection and OCR review entry points use current canonical objects/repository.
No separate study database or dependency. **1,585 full tests and 67 focused checks
pass**, including native recovery/restart, source backlinks and compact text.
Analysis/strict formatting are clean; evidence is tracked in
[current task](../tasks/current.md). Automatic continuity and learning-map
renderers, adaptive scheduling and dedicated interchange imports remain separate.
Windows debug and web release compile; existing web Wasm/Cupertino-font warnings
remain. No signed Windows release, mobile build or device acceptance is claimed.
See [ADR 0024](../adr/0024-portable-study-cards.md).

## Local OCR and recognition review — 2026-10-09

FILE-08 Windows recognition, verified PDF/image search overlays, transient source
line navigation, portable original/corrected text and linked passage notes are
implemented with automated validation. Search/PDF/image controls expose
background progress/pause/cancel, failures/retry and correction save/reset. Source
changes hide stale matches and preserve evidence; unsupported formats refuse new
recognition writes. No remote service/new package. Other-platform engines,
partial-page resume and handwriting/equation semantics remain separate. Full
limits/evidence: [current task](../tasks/current.md), [ADR 0023](../adr/0023-local-ocr-evidence.md).

**1,560 full tests passed**, clean analysis/strict formatting, Windows debug and
web release builds pass. Headless native engine recognition/corrupt-input rejection
and real PDF render/navigation checks pass. Web Wasm dry run reports an existing
Google identity dependency incompatibility; production release/device acceptance
and other-platform engines are not claimed. No desktop control/system security
changes. Generated Windows links/wrapper sources were restored locally, and the
clipboard messenger call was updated to the current Flutter API.

## Smart Views, Spaces and advanced planning — 2026-10-08

One versioned query evaluator now feeds list/table/board/gallery/calendar/timeline,
note embeds, Home widgets and Canvas previews. The visual builder supports bounded
AND/OR filters, custom properties, tags, dates/numbers, relation IDs, sort/group and
table columns. Scalar edits and task board transitions retain canonical identity;
unsupported definitions remain preserved. Large view rows build lazily.

Named device-local Spaces/layouts restore view state and scope without cloning or
moving files. Home has explicit widget customization, spans/order, apply/cancel and
reset. Context CRUD, All-Vault restore and optional appearance retain old/unknown
data. Scope now refines explorer/tasks/default calendar/search/Home; explicit
saved queries and canonical references keep their own semantics.

Tasks record date-only recurring occurrences on the same UUID, preserve history
across series edits, clamp month-end anchors and advance missed occurrences one
at a time. Parent/subtask/dependency edges validate new targets and cycles; old
unresolved data remains accessible. Calendar/timeline moves preview fields, retain
separate dates/event duration and offer guarded undo. Failed/stale saves and flush
during a pending command have acceptance checks.

**60 focused tests and 1,540 full Flutter tests passed**. Analysis and strict
formatting are clean across 428 files; documentation links and diff checks pass.
Web release/Wasm dry-run compilation passed; the existing Cupertino font warning
remains. Windows release AOT is blocked by host Application Control for
gen_snapshot (.local/productivity-windows-verbose.log); security settings were
not changed. Final tests ran separately after regenerating native test assets.
Platform/device runtime acceptance is separate. Full evidence is in the
[current task](../tasks/current.md). [ADR 0022](../adr/0022-smart-views-spaces-and-task-planning.md)
and [formats](../architecture/implemented-formats.md) document this additive subset.
No desktop control used. Broader docking/keymaps/import, formula/map/Gantt/AI,
named-zone/RRULE/reminder/provider and query-prefilled creation requirements remain
separate. Canvas is a preview/open-full-view surface; gallery uses available text.
Device context descriptors remain private settings, excluded from knowledge backup.

## PDF workspace search — 2026-10-08

Text-based PDF page occurrences now join notes, tasks, metadata and live Canvas
locations in Global Search. Excerpts identify the matched page and exact text;
opening verifies actual source bytes and highlights the matching reader range.
Filters/sorting run on complete candidates before 50-row UI pagination, removing
the first-100 cutoff. Background extraction exposes page progress, pause/resume,
retry, failures, no-text pages and partial coverage. Attachment watch/focus checks
invalidate obsolete results; relink, deletion and interrupted work cannot publish
old text or navigate to stale offsets.

The disposable native schema-4 page-text cache is checksum/path/version bound;
browser cache is session memory. Original bytes, portable metadata and stable IDs
are preserved. Restart, schema migration, corrupt-cache rebuild, source races,
oversized input, accessibility and real PDFium navigation have automated evidence.
**66 focused tests** and **1,512 full Flutter tests passed**; analysis and strict
formatting are clean across 417 files. Logs: `.local/pdf-search-focused.log`,
`.local/pdf-search-full.log`, and `.local/pdf-search-analyze.log`.

OCR/password retention, database cursor paging and collection/Space scope remain
separate work. Sources above 100 MiB or text above 32 Mi characters fail visibly;
text/results remain materialized. Windows release AOT is blocked by host Application
Control, recorded in `.local/pdf-search-windows-verbose.log`; security settings were
not changed. Web release compilation and its Wasm dry run passed using the existing
short-SDK-path environment (`.local/pdf-search-web-short-path.log`); the existing
Cupertino font warning remains. This is not device/browser runtime acceptance.
Documentation links and diff checks passed. See [delivery evidence](../tasks/current.md) and
[ADR 0021](../adr/0021-checksum-bound-pdf-search.md) for current checks and limits.
No desktop-control testing was used. Earlier dated entries describe their delivery
state at the time; their deferred PDF-indexing statements are superseded here.

## Large-text PDF navigation and Canvas search — 2026-10-08

Outline/bookmark labels and context now wrap in variable-height lazy rows.
Headings, filters, and lists share one scroll surface with footer actions kept
separate. Bookmark previews precede the list so they remain reachable in large
collections. Keyboard navigation reveals measured row geometry and cancels stale
requests. Bookmark rename help/errors and zoom validation wrap without truncation;
failed input and unavailable-page guards remain intact.

Canvas search fits its board viewport, with search/navigation/close controls
above scrolling categories/results. Full labels/snippets wrap, action targets
are larger, and navigating active results reveals them. Keyboard insets preserve
search state and control access. No durable data/schema or animation changes.

Added 10 portrait/landscape cases at 250% text, including long outline traversal,
bookmark rename failure, absent pages, zoom errors, Canvas selection, and 240/80-
pixel keyboard insets. **43 focused tests passed**, **1,430 full Flutter tests
passed**, analysis clean, strict formatting clean across 404 files, and diff check
clean with existing line-ending warnings only. Evidence:
`.local/navigation-large-text-focused.log`, `.local/navigation-large-text-full.log`,
and `.local/navigation-large-text-analyze.log`. No desktop-control testing used.


## Large-text PDF and Canvas panels — 2026-10-08

Panel headings/actions and PDF review filters reflow with enlarged text. Review
item actions stack below readable titles/warnings; connected notes preserve full
labels and source warnings. Citation drag feedback bounds long titles.

Canvas layers share a lazy scroll surface with their heading and retain Close,
Show All, and Unlock All in the footer. Item labels/badges/actions wrap or stack;
selection, visibility, locking, and stacking still use the existing commands.
Card inspectors fit the board viewport and scroll title, source warnings,
details, and footer actions together below wrapping, larger inspector controls.

Added 10 cases at 250% text in 320×640 portrait and 568×320 landscape, including
PDF stale-source controls, connected-note search/Enter and dragging, layer
commands, and task/reference actions. **52 focused tests passed**, **1,420 full
Flutter tests passed**, static analysis clean, and strict formatting clean across
403 files. `git diff --check` passed with existing line-ending warnings only.
Evidence: `.local/panel-large-text-focused.log`, `.local/panel-large-text-full.log`,
and `.local/panel-large-text-analyze.log`. No desktop-control testing was used.


## Large-text history, backup, and settings batch — 2026-10-08

History panes stack for narrow windows/enlarged text; labels and Diff/Preview
controls wrap while document viewports stay bounded. Shared Orbit dialog headings
scroll with content, retaining footer actions above keyboard insets. Recovery
paths wrap and exports remain byte-preserving. Backup import review now exposes
all validation notices before a separate folder-selection decision.

Settings controls move below labels when needed; dropdown values, theme previews,
swatches, corner/motion controls, analytics, badges, and the sync heading adapt.
Gallery/generator secondary tools scroll with their content, leaving the footer
for Close/Cancel/Apply. Snapshot label controllers follow dialog lifetime.

Added 12 widget cases for portrait/landscape at 250%, snapshot labeling at 320%
with keyboard insets, recovery export, backup choices, preference persistence,
theme dialogs, and color validation. **82 focused tests passed**, **1,410 full
Flutter tests passed**, static analysis clean, and strict formatting clean
across 402 files. `git diff --check` passed with existing line-ending warnings
only. Evidence: `.local/dialog-large-text-focused.log`,
`.local/dialog-large-text-full.log`, and `.local/dialog-large-text-analyze.log`.
No desktop-control testing was used.


## Recovery dialog font scaling and overflow — 2026-10-08

Recovery and retained-source cleanup dialogs scroll titles together with content,
keeping the footer actions reachable in short windows and at enlarged text sizes.
Recovery pagination wraps its label rather than pushing arrows outside the dialog.
Smaller outer insets leave room for full paths, source names, and wrapping controls;
cleanup action overflow uses spaced vertical stacking. Text scaling remains native.

New widget regressions cover portrait/landscape at 250% text with long staged
details and history, and an active verification reflowing to 320% text with keyboard
insets. Dialog suite: **7 passed**; full Flutter suite: **1,398 passed**.
Analysis and strict formatting are clean; `git diff --check` passed with existing
line-ending warnings only. Evidence: `.local/recovery-font-scale-full.log`.

## Recovery dialog theme-surface contrast audit — 2026-10-08

Recovery dialogs now sanitize unreadable custom color schemes at the dialog
boundary. Surface text, secondary text, outlines, and progress accents fall
back to the highest-contrast black/white candidate when a supplied token does
not meet its WCAG threshold. This keeps custom palettes intact while ensuring
the recovery route remains readable in light, dark, and user-authored themes.
High-contrast outlines, source-card boundaries, larger action targets, and
reduced-motion progress behavior remain active.

Added widget coverage for default light and dark themes plus a deliberately
low-contrast custom palette. Focused recovery suite: **47 passed**; full
Flutter suite: **1,395 passed**. `flutter analyze`, strict formatting, and
`git diff --check` are clean (the repository retains existing line-ending
normalization warnings only).

## Recovery dialog high-contrast and reduced-motion audit — 2026-10-08

High-contrast recovery dialogs now use stronger outlines and source-card
boundaries, larger action hit targets, and a thicker progress indicator. When
reduced motion is requested, the progress ticker is disabled while percentage
and status announcements remain live.

Added a visual regression for high-contrast and reduced-motion behavior. The
focused recovery suite passes 46 tests; the full Flutter suite passes with
1,394 tests. `flutter analyze`, strict formatting, and `git diff --check` are
clean.

## Recovery dialog accessibility and keyboard feedback — 2026-10-08

The recovery dialog now has a named semantic route, grouped source details,
live announcements for page and progress changes, and deterministic keyboard
traversal. Escape cancels an active operation or closes an idle dialog; Ctrl+
Page Up/Down changes retained-source pages. Cancellation feedback is announced
immediately and repeat cancellation requests are disabled.

Added widget coverage for semantic pagination controls and Escape cancellation.
The focused recovery suite passes 45 tests; the full Flutter suite passes with
1,393 tests. `flutter analyze`, strict formatting, and `git diff --check` are
clean.

## Attachment recovery history pagination and cancellation — 2026-10-08

The attachment recovery dialog now shows retained source history eight entries
per page with previous/next controls. Restore, relink, resume, and forget
commands accept cancellation callbacks that are checked during streamed reads
and staged writes. A cancelled retained-source operation leaves its history
and immutable bytes unchanged; a cancelled native transfer keeps its durable
partial stage resumable.

Added a repository regression for cancellation and resumable-stage retention.
The focused native staging, storage, and read-attachment suite passes 43 tests;
the full Flutter suite passes with 1,391 tests. `flutter analyze`, strict
formatting, and `git diff --check` are clean.

## Recovery verification UX for large files — 2026-10-08

Retained-source restore and cleanup now stream native attachment bytes while
verifying their recorded SHA-256. The recovery dialog reports live verification
progress for restore and forget actions. Cleanup verifies the source before
changing history, so missing or externally changed bytes leave the retained
record and file untouched.

Added regressions for progress reporting and changed-byte protection. The
focused native staging, storage, and read-attachment suite passes 42 tests;
the full Flutter suite passes with 1,390 tests. `flutter analyze`, strict
formatting, and `git diff --check` are clean.

## Recovery-stage retention cleanup — 2026-10-08

Native startup cleanup now removes only well-formed attachment recovery stages
whose last durable progress update is older than the 30-day retention window.
The matching partial bytes, manifest, and temporary manifest are removed
together. Recent stages remain resumable; malformed manifests are preserved for
inspection, and unsupported newer workspace manifests are never mutated.

The native retention regression passes alongside interruption, resume, and
discard coverage. The focused native staging/storage suite contains 26 tests;
the full Flutter suite passes with 1,389 tests. Strict formatting,
`flutter analyze`, and `git diff --check` remain clean release checks.

## Resumable attachment recovery after interrupted staging — 2026-10-08

Native recovery stages now have a device-local manifest and durable `.part`
file. A stopped stream is listed after reopening the Vault with its target,
checksum, source name, and saved offset. The recovery dialog can resume from a
user-selected copy of the same source, or discard the stage. The complete byte
stream is checksum-verified before guarded publication; authored references and
the active file object remain unchanged on failure. Browser storage keeps its
bounded fallback without claiming durable resume.

Added native interruption/reopen/resume/discard coverage and a repository
resume regression. The focused storage/read/native staging suite contains 40
tests after these additions; the full Flutter suite passes with 1,388 tests.
Strict formatting, `flutter analyze`, and `git diff --check` are clean.

## Streamed attachment recovery hashing and progress — 2026-10-08

Recovery verifies selected XFiles through their byte stream and shows progress
for hashing and the subsequent restore/relink. Native Vaults use the existing
durable staging path to hash and write without a second in-memory copy; browser
stores use the bounded fallback. Checksum, size, stable identity, and source
history safeguards remain unchanged.

The focused storage/read/native staging suite passes 37 tests; the full Flutter
suite passes with 1,385 tests. Strict formatting, `flutter analyze`, and
`git diff --check` are clean.

## Recovery verification UX and retained-source cleanup — 2026-10-07

Recovery previews the selected file's size and SHA-256 before committing a
restore or relink. Restore-original is unavailable for mismatched bytes while
relinking remains explicit. Retained source history now has a confirmed cleanup
action with guards for the active source and sources referenced by another file
object; metadata is removed before deleting only the verified immutable bytes.

The focused storage/attachment recovery suite passes 30 tests; the full Flutter
suite passes with 1,383 tests. Strict formatting, `flutter analyze`, and
`git diff --check` are clean.

## Attachment relinking, source history, and recovery choices — 2026-10-07

Missing attachment previews now expose an explicit recovery dialog. Users can
restore checksum-matching bytes at the original path, relink a stable file
object to a new immutable source, open retained source versions, or restore a
retained version. Relinking records the previous source without changing object
identity; failed or stale commands retain the existing source.

The focused storage/attachment recovery suite passes 28 tests; the full Flutter
suite passes with 1,381 tests. Strict formatting, `flutter analyze`, and
`git diff --check` are clean.

## Read-mode media source status for PDF quotes, Canvas embeds, and math-adjacent media — 2026-10-07

Read-mode media now reports source drift as well as storage failures. PDF review
rows show a warning and disable direct navigation when their source checksum no
longer matches. Canvas citation cards show a source-changed badge while keeping
the source-open action available for verification. Attachment previews announce
the replacement revision after refreshed bytes load, including math-adjacent
images.

The focused PDF/Canvas action suite passes 25 tests and the Read attachment
suite passes 15 tests; the full Flutter suite passes with 1,379 tests. Strict
formatting, `flutter analyze`, and `git diff --check` are clean.

## Read-mode media actions for PDF quotes, Canvas embeds, and math-adjacent media — 2026-10-07

Read-mode attachment actions now remain consistent across PDF review cards and
Canvas citation/image previews. PDF quote cards can copy citation text and open
the source page; Canvas previews can copy citations and open the source PDF or
original attachment. Math-adjacent images retain the shared title/alt metadata,
accessible open action, details, and retry/recovery states.

The focused PDF/Canvas action suite passes 24 tests and the Read attachment
suite passes 15 tests; the full Flutter suite passes with 1,378 tests. Strict
formatting, `flutter analyze`, and `git diff --check` are clean.

## Read-mode missing attachment recovery — 2026-10-07

Read attachment previews now distinguish missing bytes, failed Vault reads, and
decode failures. Each state preserves the authored reference and offers Retry;
watcher revisions show a refresh state while replacement bytes load. Decoder
errors use the same recovery affordance instead of leaving a dead image widget.

The focused media/cache tests pass 35 tests; the full Flutter suite passes with
1,378 tests. Strict formatting, `flutter analyze`, and `git diff --check` are
clean.

## Read-mode attachment cache invalidation — 2026-10-07

Native attachment changes are now reported separately from canonical object
changes. The workspace controller batches those events into a media revision,
Read previews reload only when their path or revision changes, and Canvas image
caches invalidate decoded/failed entries with generation fencing so stale
in-flight decodes cannot replace newer attachment bytes.

The focused media/cache tests pass 22 tests; the full Flutter suite passes with
1,365 tests. Strict formatting, `flutter analyze`, and `git diff --check` are
clean.

## Read PDF, Canvas and image recovery parity — 2026-10-07

Read-mode PDF quote links preserve precise page targets and Canvas wiki-links
open stable object IDs through the existing note router. Local image previews now
use a retryable loader with an explicit failure state, recovering from temporary
vault/read failures without changing authored references.

The focused Read/media suite passes 20 tests; the full Flutter suite passes with
1,362 tests. Strict formatting, `flutter analyze`, and `git diff --check` are
clean.

## Read media activation parity — 2026-10-07

Footnote and math-adjacent images now use the shared local attachment preview in
Read mode. Fenced `orbit-view` and `orbit-snapshot` blocks render their real
interactive view/snapshot widgets instead of inert code, without changing
authored Markdown.

The focused Read/callout/editor/footnote suite passes 81 tests; the full Flutter
suite passes with 1,359 tests. Strict formatting, `flutter analyze`, and
`git diff --check` are clean.

## Read attachment activation parity — 2026-10-07

Read-mode attachment images now behave consistently in aligned blocks, tables,
and block quotes. A shared `ReadAttachmentPreview` keeps the existing image
renderer and adds an accessible tap target for local relative attachments;
remote/data images keep ordinary display behavior. Link taps still use the
note-level router.

The focused Read/callout/editor suite passes 67 tests; the full Flutter suite
passes with 1,356 tests. Strict formatting, `flutter analyze`, and
`git diff --check` are clean.

## Read-callout link and attachment activation — 2026-10-07

Read callout bodies now reuse the note-level link router for external, internal,
missing and relative attachment links. Nested callout Markdown receives the
surrounding note image builder, and relative attachment images are wrapped in an
accessible tap target that opens the original through the workspace attachment
handler without changing source Markdown.

The focused Read/callout/editor suite passes 65 tests; the full Flutter suite
passes with 1,353 tests. Strict formatting, `flutter analyze`, and
`git diff --check` are clean.

## Read-mode code search parity — 2026-10-07

Read-only fenced code blocks now carry authored body text metadata into the Read
search overlay. Queries normalize CRLF to LF only for matching the rendered code
display; source ranges and highlights remain exact, while language/info labels
stay excluded. The Find field accepts multiline pasted queries. Unicode folded
matches across prose and code retain exact reveal and Find focus.

The Read/code focused suite passes 63 tests; the full Flutter suite passes with
1,350 tests. Strict formatting, `flutter analyze`, and `git diff --check` are
clean.

## Code search source authority — 2026-10-07

Fenced-code Rich Find callbacks now recover the current code block by stable
document position when a structural edit grows the fence and replaces the
parsed block object. A second input event before the parent rebuild is retained
with the correct fence, info string, line endings, selection, and shared undo.

The code-search suite passes 18 tests; the full suite passes with 1,346 tests.
Strict formatting, `flutter analyze`, and `git diff --check` are clean.

## Structured search source authority — 2026-10-07

Table and callout navigation now resolve source selections and edits from the
structured child editor's latest local emission while a parent rebuild is
pending. This prevents a quick callout type change followed by body input from
reverting the type or selecting against stale offsets. Escaped table-pipe,
CRLF body, title, replacement, and shared-undo behavior remains unchanged.

The structured-search suite passes 23 tests; the full suite passes with 1,345
tests. Strict formatting, `flutter analyze`, and `git diff --check` are clean.

## Find/replace Unicode and selection parity — 2026-10-07

Case-insensitive Find uses the generated Unicode 15.1 full case-fold map and
maps expanded folds back to exact authored UTF-16 ranges. A match cannot start
or end inside one expansion, preventing half of `ß → ss` from becoming a
spurious result. Existing whole-word and selection-scope checks remain based
on the visible segment, while Rich replacement still uses the validated
projection/structured edit path.

Regression coverage includes expanded Latin folds, Greek sigma, Kelvin sign,
half-expansion rejection, exact ranges, and formatted/link replacement. The
focused Find/Replace suite passes with 35 tests; the full suite passes with
1,344 tests, and strict formatting plus `flutter analyze` are clean.

## Cross-platform rich clipboard parity — 2026-10-07

Rich table copy now sends HTML and plain text through one platform boundary.
Android publishes `ClipData.newHtmlText`, iOS publishes one `UIPasteboard`
item with HTML and UTF-8 text, Linux uses GTK `text/html` and text targets, and
web uses the browser Clipboard API with `text/html` and `text/plain` blobs.
When a host cannot accept rich data, the Dart boundary retries ordinary plain
clipboard text and reports failure only if both paths fail. The shared table
HTML payload and conservative HTML paste path are unchanged.

Platform fallback tests cover success, missing/rejected channels, malformed
results, and failure of both clipboard paths. Platform/table tests pass with 31
tests; the full Flutter suite passes with 1,342 tests; strict formatting,
analysis, and the web release build pass. Android,
iOS, and Linux native builds are unavailable on the Windows validation host,
so those runners are source-checked but not claimed as compiled artifacts.

## Previous: Table drag selection and rich clipboard export — 2026-10-07

## Table drag selection and rich clipboard export — 2026-10-07

Rich tables now expose mouse drag, Shift-arrow, and Ctrl/Cmd+A rectangular
selection. Copy publishes TSV/CSV fallback text and a native HTML table payload;
Windows maps that payload to CF_HTML alongside CF_UNICODETEXT. Hosts without
the bridge safely retain plain text copy. HTML paste shares the conservative
HTML conversion path, while CSV parsing handles quoted separators, escaped
quotes, and embedded newlines without splitting cells. Stale requests and table
size limits remain enforced.
Focused table/clipboard/model tests pass with 44 tests; the full suite passes
with 1,336 tests. Dart analysis and strict formatting are clean. Windows build
packaging was blocked before compilation because Developer Mode symlink support
is disabled. No schema or storage authority changed.

## Reference compatibility batch — 2026-10-07

Nested full reference links now keep valid child links visible alongside the
outer reference, while nested inline links retain the existing literal outer
fallback. Selection edits inside link labels escape unmatched brackets so
editing cannot leave a stale delimiter or change the visible paragraph. The
reference lookup path preserves non-breaking spaces and normalizes only
CommonMark whitespace. Malformed definitions roll back without masking later
valid targets or swallowing prose, including mixed LF/CRLF title boundaries.
Regression coverage includes nested child links, escaped and code-contained
brackets, balanced-label edits, UTF-16 caret round-trips, non-breaking
identifiers, malformed definitions, and mixed-ending source preservation.
Focused Markdown/boundary/model tests pass with 81 tests; the full suite passes
with 1,333 tests.
No runtime package, schema, or storage authority changed.

## Release hardening — 2026-10-05

Release tags now have a quality gate for formatting, analysis, PDFium-backed
tests, and the full Flutter suite. The stable 1.0 workflow packages Windows x64
only and publishes a SHA-256 checksum; Android and Web remain validation builds.
The clean-machine acceptance matrix is tracked separately from automated tests.
See [release hardening](../tasks/release-hardening-2026-10-05.md) and the
[Windows 1.0 acceptance matrix](../tasks/windows-1.0-acceptance-2026-10-06.md).

## Visual ergonomics — 2026-10-03

Readable shared typography/density and semantic zoom, searchable tab overflow,
quiet Explorer actions, persistent note Undo/Redo, task title/metadata/detail
hierarchy and both board implementations are refined. Game Dev todo aliases
map to Planned without rewriting content; generic boards expose task/empty-column
filters. Project health metrics, milestone width and Timeline empty state are
refined; enlarged dashboard/table layouts recover from overflows.

All 1,208 tests pass; analyzer and strict formatting are clean (382 files).
Normal Windows release built in 62.3s and passed a hidden startup/close smoke
check. Rendered fixtures were reviewed; native DPI and full interaction review
remain unverified. Canvas/focus/view-switcher composition and a genuine Timeline
axis remain outside this coherent delivery. See the
[33-category report](../tasks/visual-ergonomics-2026-10-03.md).

## Search workspace — 2026-10-01

Saved query/filter/sort recipes, recent opened/saved searches, folder/tag/match
filters, completed-task exclusion, deterministic result sorting, match emphasis,
read-only previews and query-focused keyboard navigation are delivered. The
existing bounded search and precise source navigation remain authoritative.
Device-local settings preserve unknown data; no content schema or packages change.

Analyzer/format clean; pure Dart diagnostic and native sample workflow passed.
Normal Windows release built (58.3s). Eight new automated tests and the full-suite
attempt could not execute because Windows Application Control blocked the Flutter
test runner. Acceptance is incomplete; see the
[report](../tasks/search-workspace-2026-10-01.md). Android SDK unavailable.

## Search and precise-reference composition — 2026-09-30

Shared rich search results open Note blocks, headings, Canvas elements and existing
LaTeX labels. Explicit prose references gain lazy portable anchors; live Canvas
cards resolve their canonical block without copying text. Backlinks retain precise
target/source context. Native heavy search work runs in an isolate. Appearance
defaults have a separate owner behind compatible flat v1 session settings.
The existing Canvas grid remains, with oversized-bound safety improved.

Validation: 1,027 full-suite tests passed; analyzer and formatting clean. Normal
Windows release built (61.0s), launched and observed Saved locally. Native manual
interaction acceptance is partial; Android SDK unavailable. PDF page indexing,
complete controller extraction and ink caching are deferred. See the
[task report](../tasks/architecture-composition-2026-09-30.md).

## Interface colors and Bookshelf — 2026-09-30

Settings exposes fifteen semantic UI color roles with validated hex, sliders,
preview and per-role/all-color reset. Neutral recovery controls remain readable.
Bookshelf now uses compact searchable shelves, sorting and card/list views, real
reading progress, linked reading notes and optional saved reading rooms.
Portable content and object identities are preserved.

Validation: 1,012 full-suite tests; six final focused tests; analyzer and formatting
clean. Normal Windows release built (77.0s) and launched. Native interaction review
was interrupted by user activity. Android SDK remains unavailable. See the
[task report](../tasks/colors-bookshelf-2026-09-30.md).

## Product coherence and canvas performance — 2026-09-30

Shared discovery labels/context, ranked quick-open aliases/context/fuzzy titles,
scaled keyboard scrolling, loading/error/retry search states and optional visual
type/project filters are implemented. Filters refine a bounded first-100 result
set, explicitly disclosed. Explorer, short navigation rail, editor/creation menus
and snapshot controls fit available space. Failed reading-summary creation remains
retryable. Project dashboards no longer show a competing Vault-wide progress strip.
Existing object identities, portable formats, storage and animations are retained.

Canvas connector dependency lookup, revision-cached bounds, bounded rich parsing
and a retained vector minimap reduce measured CPU work; pixel equality is tested.
Measurements describe synthetic CPU workloads, not whole-app FPS guarantees.

Validation: 1,006 full-suite tests passed; 19 collection/view tests passed after
the native-review project correction. Final analyzer clean (4.8s), 333 files
format-clean. Normal `lib/main.dart` Windows release built (59.1s) and launched.
Native review covered the principal screens and empty sample Vault. Android build
attempt stopped at missing SDK. See the [coherence report](../tasks/product-coherence-2026-09-29.md)
and [performance evidence](../tasks/canvas-performance-2026-09-28.md) for scope,
screens, counts, compatibility limits and deliberate future work.

## Annotated PDF copies — 2026-09-15

Native review-panel export creates a separate PDF attachment containing standard
highlight, underline, strikeout and page-comment annotations from the filtered
review. Original bytes, editable notes and existing PDF form values are preserved.
Actual byte checksums, supported-region validation, source/note snapshots and
bounded input protect the export; failed saves remain retryable. Resolution is
included in comment text; native PDF discussion threads/import remain deferred.
Independent pypdf structure/round-trip and Poppler visual checks passed. See
[current task](../tasks/current.md) for final test evidence and acceptance limits.
No runtime package, schema or storage authority changed.

Validation: **575 tests passed**, analyzer clean, 219 files format-clean, web build
passed. Flutter 3.44.8 / Dart 3.12.2 was restored project-locally without dependency
upgrades. On 2026-09-16, with owner approval, C++ Build Tools, Windows SDK and ATL
were restored. Windows release build passed (16.5s); the rebuilt executable stayed
alive and responsive for a five-second startup check, then the test process was
stopped. Native interactive/physical-device acceptance remains unverified. Existing
web WASM/font and Poppler font advisories are recorded in the task.

## PDF review workspace — 2026-09-14

Page comments, direct review-note/style/color editing, open/resolved state,
filtering/sorting, hidden markup and filtered Markdown copy/export/linked summaries
are implemented through existing Universal Objects and local save/history.
Stale edits are rejected; failed drafts retained; original PDF bytes stay unchanged.
See [current task](../tasks/current.md) for validation and boundaries. This is not
full Acrobat parity; interoperable annotated-PDF export remains a separate task.

Validated 2026-09-15: all **569 tests passed** (seven new review regressions), analyzer
clean, 218 files format-clean, Windows release built in 60.3s and passed a five-second
responding startup check. Real-PDF widget tests and desktop screenshot inspection
passed; physical phone/native Save As acceptance remains unverified. The matching
SDK was recovered from its moved backup location; dependencies were not upgraded.

## Math catalog and editing correction — 2026-09-14

The owner rejected the previous reduced palette/typing experience. The original
1,473-entry searchable symbol table now opens beside the directly editable equation
and remains available in Advanced. Insertion retains the caret, ordinary arrow
symbols stay editable, and empty-argument Backspace preserves the other content.
Whole-equation select/copy/cut/paste/delete is implemented with clipboard failure
and stale-edit safeguards. No architecture/storage change. Google remains paused.
See [current task and validation](../tasks/current.md) for current checks and the
remaining cross-part partial-selection/complex-TeX boundaries. Validation: **562
tests passed** (eight new correction regressions), analyzer clean, 216 files
format-clean, Windows release built in 48.7s and passed the five-second responding
startup check. Desktop catalog screenshot inspected; native clipboard/real-phone
typing acceptance remains unverified. Evidence in the previous pass is historical.

## Direct rich math editing — 2026-09-14

Directly editable fractions, roots, powers, indices and operator limits now form
one expression, including nested structures. Keyboard structure insertion,
slot traversal, glyph insertion and immediate focus for new equations integrate
with existing Markdown saves and shared undo. Complex TeX retains the advanced
editor and safe fallback. Google work is paused by the owner. See
[scope, validation and remaining boundaries](../tasks/current.md) and
[editing behavior](../features/markdown-and-editing.md#direct-rich-math-refinement--2026-09-14).
Validation: **554 tests passed** (21 added math tests), analyzer clean, 215 files
format-clean, Windows release built in 50.8s and passed a five-second responding
process startup check. Desktop/narrow visual widget checks passed. Previous build
evidence below is historical; full native typing/real-phone acceptance is pending.

## Google account/Drive integration — 2026-09-13, partial

Windows PKCE/loopback and Android Google identity/authorization adapters, secure
session storage/restoration, account switching/reconnect checks, quota display,
metadata-based Vault sizing, visible root preparation and paginated discovery are
implemented. No live credentials were configured. **Vault transfers and automatic
Drive sync are not enabled.** See [audit and evidence](google-account-milestone-2026-09-13.md).

## Runtime hardening — 2026-09-13

TaskDetail accepts custom statuses and stale blockers without assertion. Native
folder commands coordinate Notes paths and every object's logical membership,
with staged recovery and mixed batch movement. Connector endpoint handles and
explicit compatible geometry are implemented. Rich block moves preserve spacing;
heading collapse survives title edits and matching-session restoration.
Existing label/navigation/search fixes were retained and regression checked.
See [full audit, boundaries and validation](runtime-audit-2026-09-13.md).
Validation: **463 tests passed**, analyzer clean, 189 files format-clean, Windows
release build successful (45.8 seconds), five-second startup smoke passed.
Browser folder commands remain safely unsupported; native interrupted commands
use roll-forward recovery, with read-only review if external content changed.

## M6 native sync adapter — 2026-09-12 continuation

`WorkspaceSyncReplica` now stages/verifies incoming streams, applies exact authored
files through repository serialization/history, preserves conflict alternatives,
recovers remote permanent deletion and reuses Notes move recovery. The controller
supplies live draft/save/loading guards. The replica's state wrapper rejects late
checkpoints after a Vault switch. These flows are tested with real native Vaults
and a fake server; Google OAuth/Drive/WebDAV and sync UI are still unfinished.

20 adapter/staging tests added. Current full suite: **340 passing**; analyzer clean;
format/check passed; Windows release build passed (43.8s) and startup smoke passed.
Android debug APK built successfully (28.3s); existing plugin compatibility warnings remain.
See [current cloud task](../tasks/cloud-sync.md) for evidence and the next task.

## Earlier M6 sync foundation — 2026-09-12

The full owner prompt has been received. Native Vault locking, recoverable checked
permanent deletion and tombstones, canonical sync inventory, separate durable
device sync state, installation identity and a provider-neutral reconciliation
engine are implemented. Offline/restart/conflict/checkpoint behavior is tested
with a fake provider. No real Google Drive/WebDAV provider, OAuth or cloud UI is
delivered; the production repository replica adapter remains the next task.

Final local validation: format/check passed, analyzer clean, **297 tests passed**,
Windows release build passed (31.7 seconds). See the
[current cloud task](../tasks/cloud-sync.md),
[detailed completion/limitations table](../features/cloud-sync.md) and
[implemented contract](../architecture/sync.md). Existing feature work is preserved.
Windows startup smoke passed. Android debug APK also built successfully (201.5s),
with existing clipboard/drop plugin future Kotlin compatibility warnings; no real
phone or Google account acceptance was performed.

## Historical M6 sync audit — 2026-09-12

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
| Durable files | Markdown/YAML notes, versioned JSON boards/tasks, original attachments, rebuildable Drift index, hash preconditions, recoverable saves, OS-level Vault locking, bounded revision history browser and interrupted-save simulations | Hardware power-loss certification |
| Backup import/export | Separate staged-folder restore, raw/unknown bytes preserved, mixed-content warnings, archive journals quarantined, empty Notes folders round-trip, bounded recovery-file review/export dialog, staged publication that leaves existing workspaces untouched | Streaming large archives, browser folder import |
| Vaults | New/Open/Recent/remember last/close/startup chooser/switch; named header control/current-Vault marker; rename display name with same workspace ID | Physical Vault-directory rename, OS file associations, multiple app windows |
| Real folders | Nested Notes folders, create/rename/move folders, move notes, collapse/reveal active ancestors; six note sort orders, title filter and safe internal note/folder drop | Folder Trash/undo UI, custom manual sort, automatic adoption of ordinary Markdown |
| Notes | Directly editable Rich paragraphs/headings/lists plus Source/Read/Split; formatting with Right-arrow escape, block insert/copy/duplicate/delete, shared undo/redo, outline, literal find/replace, attachments and per-pane restoration; resizable Source/preview divider; conservative rich HTML clipboard conversion with plain-text fallback; lazy Rich block layout for very large notes; expanded CommonMark block parsing; variable-length code spans with source-preserving whitespace/line-ending normalization, ASCII-only edge-space normalization, indivisible unmatched runs, even/odd backslash parity, whole-CRLF selection mapping, and source-visible round-trips through reference-label edits; URI/email autolinks; full inline links with punctuation-only escapes, escaped/nested labels, decoded escapes/entities, balanced destinations, optional titles, and one-line-ending spacing; escape-aware source/visible offsets for edits, nested delimiter matching, and code-span-aware link labels; collapsed and definition-gated shortcut reference-link projection with escaped reference-label brackets and whole-document Unicode case-folded definition resolution; validated reference-definition titles, empty/balanced destinations, and nonblank multiline ownership; rectangular table selection; TSV, CSV, and HTML table clipboard interoperability; cross-block native text selection | Unsupported extensions remain literal |
| Smart lists | Bullet/number/checklist continuation, unchecked next checklist item, empty-item exit, Tab/Shift+Tab nesting; formatted paragraph split/join | Multi-block Rich selection/nesting; Source supports selected list lines |
| Visual tables | Editable cells, Tab/Shift+Tab, final-cell Tab creates row, row/column add/remove, alignment, rectangular selection, TSV/CSV/HTML clipboard paste, plain paste at caret, shared undo | Rectangular pipe tables only; no merged cells or formula engine; 1,000-row/50-column bounds are safety limits, not a performance guarantee |
| Code and math | Editable highlighted fenced code with language/Copy code; local inline/block TeX in Rich/Read, visual fraction/script slots, searchable renderer symbol registry and templates, source/live preview, bounded visual matrix/aligned grids, academic callouts, invalid-source fallback | Highlighting is plain above 50,000 code characters; unsupported languages stay editable; inline math uses separate prose segments with limited cross-segment selection/formatting |
| References | Authored Markdown remains exact on autosave; readable links bind to UUID metadata; explicit ID links, title aliases, backlinks and rename-safe PDF page anchors | Ambiguity repair UI, general block fragment anchors and inbound ordinary path-link repair after moves |
| Source files | Strict UTF-8 read-only previews, C/C++ and other mapped language highlighting, exact Copy Code, original-file fallback | 1 MiB preview bound; plain text above 50,000 characters; unsupported encodings and code editing/execution deferred |
| PDF research | Local PDFium reader, page/zoom restoration per pane, outline/thumbnails, literal search, text selection/copy, persistent bookmarks, UUID page references, quote-to-note and source-versioned highlight notes with editable comments; changed-source and missing/corrupt recovery | Freehand ink, underline/strikeout, threaded comments, precise annotation navigation, re-anchoring, OCR, forms, redaction, signatures, page editing/export; mobile/web validation |
| Search | Native FTS5 trigram title/body/property/Canvas-text candidates, draft overlay, checksum-bound PDF page text, exact verified range navigation, full type/project/folder/tag/match/completion filtering before 50-row pagination, background coverage/progress/pause/retry and safe source reindexing | Boolean query language, collection/Space scopes, OCR, semantic search and full indexing benchmarks; short queries use escaped LIKE; PDF source/text safety bounds apply; browser PDF cache is session memory |
| External edits | Native filesystem hints with debounced targeted hash checks; startup/resume/full reconciliation; clean reload and dirty-draft protection; OS-level Vault exclusion | Binary attachment cache invalidation and atomic handling of arbitrary external multi-file edits |
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
  journals and before/after bytes for review; the command palette exposes a
  bounded recovery-file browser/export flow, while applying or deleting retained
  files still requires deliberate work in the Vault folder.
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
locking, Rich block drag reorder and deeper Canvas interactions remain important
tracked boundaries. Preserve exact-source fixtures and original
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
these segments, list folding, captions/resize/replace image controls,
footnote/comment editing and richer clipboard conversion remain unfinished.
Formatting commands wrap selections; a collapsed selection uses an
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

## Product coherence continuation — 2026-10-04

Project, Course and Reverse Engineering dashboards received a focused hierarchy
pass. Repeated framed sections and research metric cards were reduced while
content, object links, actions and status meaning remain. 1,209 tests pass;
analyzer and strict formatting are clean; the Windows release built in 56.6s.
See [the focused report](../tasks/product-coherence-2026-10-04.md).
## Markdown composition and connected blocks — 2026-10-11

Responsive two/three columns with nested Rich editing/Read presentation, column
caret/search mapping and reversible stacking; canonical task/collection/drawing
embeds with shared Canvas editing, source-cache refresh and missing-source fallback;
Source image/text insertion; reviewed paginated document replacement; complete
prose/list conversion and linked Canvas placements are implemented. Existing
Markdown/Canvas JSON authority, stable IDs and recoverable commands remain.
No nested column layouts, arbitrary database widgets or live-object publication
snapshots are claimed. Full validation is tracked in docs/tasks/current.md.
