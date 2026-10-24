# Attachments, media and research

## Folder imports and unified Explorer — 2026-10-24

FILE-01 / ORG-05 / NAV-02: desktop folder menus offer **Import PDFs here…** and
**Import files here…**, with multiple selection and the existing 100 MiB per-file
import bound. A failed file does not discard successful imports. The chosen logical folder is
stored in the first durable file-object save; original bytes remain under the
existing content-addressed `Attachments/` storage. Repeating an import in that
folder reuses its identity. Importing identical bytes into a different folder
creates a separate owned file record sharing those bytes, without moving the
existing record. Missing/unsafe destinations fail before writing attachment bytes;
retired Vault selections cannot import into a different opening.

All-items and type-filtered Explorer views use the same folder hierarchy. Items
assigned to subfolders stay there. Unfiled objects at the Notes root are grouped
into Notes, Canvases, PDFs, Images, Code, 3D assets, Audio, Video, Files, Tasks,
Events and Views as applicable. Grouping is display-only; original filenames/MIME
identify files even after title changes, and the selected sort applies within
each group. The existing attachment visibility preference applies to the Notes
filter ("Show attachments in Notes"); All items and explicit file-type filters
always include their matching files. Search, tags and Space filters feed the tree instead of reintroducing
unmatched objects. Existing moves, references, folder archive/collapse and
keyboard/multi-selection continue through the same object commands. No migration,
new dependency or automatic adoption of arbitrary loose filesystem files.

## Large PDF navigation and annotation lookup — 2026-10-24

FILE-04/05/11/12/13: comfort fitting keeps one cancellable native measurement and
the latest requested page, deduplicates work and retries failures; completed
measurements use a 32-page LRU scoped to document identity. Replacement/remount
retires pending work. Dense highlight hit testing uses bounded, lazy page bands
with unchanged paint-order selection; comment bounds decode once per immutable
snapshot. Original bytes and annotation storage are unchanged.
[Synthetic native workloads, validation and hardware limits](../tasks/pen-pdf-performance-2026-10-24.md).

## Source/model preview and external-open quality — 2026-10-19

Code previews offer Retry for failed/missing reads and apply known 1 MiB metadata
bounds before loading, while still validating actual bytes. Attachment versions
include Vault generation, reference/checksum and the existing attachment-change
signal. Pending versions retire old content rather than presenting it under the
new filename. Stable versions preserve source selection/model camera through
unrelated rebuilds. Model decoding captures its filename before awaiting bytes
and skips obsolete pending decodes; Retry uses synchronous state updates.

External-open confirmations and delayed reads retain their original Vault,
location and attachment version. Switching Vault, deleting/replacing the source
or invalidating attachment bytes retires the action before platform launch. File
pickers also refuse retired context before reading large incoming files. Original
bytes remain authoritative; nothing is executed by attachment or preview itself.
No new watcher, storage format or dependency is introduced.
[Actual tests, builds and hardware limits](../tasks/file-workflow-quality-2026-10-19.md).

## PDF review form protection — 2026-10-17

Review comments, color, style and resolution changes ask before discarding
unapplied edits on Cancel, Escape, back or outside-click. Save prevents duplicate
submission and dismissal while the existing save command is pending. Failure
retains the form for retry/copy; successful save closes it. Temporary form values
remain in memory until saved to the original note through normal history.

Verified alongside enlarged-text layout and failed-save behavior; see
[editor quality evidence](../tasks/editor-quality-2026-10-17.md).

## PDF review workspace — 2026-10-17

Highlights and comments can expand into the PDF reading area while retaining the
same review state. Checkboxes support individual and Shift-range selection;
Select all filtered, Clear selection and keyboard focus are explicit controls.
With review navigation focused, arrows move through source passages, Shift+arrows
extend a range, Space selects, Ctrl/Cmd+A selects filtered items, Enter opens
the source and Delete asks before moving selected notes to Trash. Escape clears
selection first. Search text editing retains ordinary text-field shortcuts.
Filtering clears hidden selections; pagination shows 50 results per page while
selection and export still cover the full filtered set.

Selected-only copy, Markdown export, linked review-summary notes and derivative
annotated PDFs reuse the existing exporters. With no selection these actions use
the filtered set. Create Canvas review board places references to the original
PDF and selected annotation notes on a new ordinary board, opening it beside the
PDF. Notes/attachments are not duplicated, and deleting the board keeps evidence.

Bulk resolve/reopen, color, highlight/underline/strikeout and Trash use guarded
per-note commands, up to 1,000 distinct items per edit batch. Progress and Cancel
remain visible; cancellation stops between saves, retaining the completed prefix.
Each result identifies saved, unchanged and failed items; failed writes retain
their originals. Later edits, competing drafts, read-only/future review formats,
wrong files and stale PDF versions refuse mutation. Stale marks can still be
trashed for cleanup. Page comments support color/state, not text-markup conversion.

Undo batch restores only exact committed snapshots, retaining newer edits and
reporting skipped items. Partial/cancelled Undo can retry its remaining items.
Receipts/selections are private in-memory review state; after reopening the app,
ordinary note history and Trash provide recovery. Batches are sequential per-note
commits, not a global transaction. Unknown fields, source anchors, note bodies
and original PDF bytes are preserved. No new annotation schema, PDF engine,
package, remote service or native embedded-annotation import is added.

## PDF linked-note lifecycle fixes — 2026-10-16

Connected notes and the Markdown note's PDF-source banner expose Move note to
Trash, including plain page/quote notes without highlight geometry. Deletion
uses ordinary durable saves, keeps original PDF bytes and offers revision-checked
Undo. Busy state is local to the affected note; failure retains the note and
shows retry guidance. Source-banner actions wrap at narrow widths/enlarged text.

Shared tab cleanup no longer mutates immutable session defaults or generates
close snapshots for deleted notes. Removing the primary note promotes the PDF
beside it and removes deleted tab/pin/reopen entries. Session list defaults are
owned mutable copies, fixing the same failure in pin/close/archive commands.
Competing drafts, failed saves and stale snapshots refuse deletion with feedback;
late keystrokes retain their content in the same recoverable Trash note.

Quote extraction now checks persistence before reporting success, retains failed
drafts/selections, rejects invalid/read-only/LaTeX destinations, preserves Markdown
whitespace/line endings and writes Canvas scene data without replacing board
properties or existing elements. Quote/highlight creation cannot inject completed
old-Vault writes into the current Vault. New plain quote notes retain optional
`pdfSource.quote` text for connected-note citation dragging. No migration or
original-file rewriting is required.

## PDF highlighting and recoverable deletion — 2026-10-15

FILE-04/05/11/12/13: annotation rendering now decodes immutable Canvas-region
snapshots once and indexes markup/comments by page. Ordinary parent rebuilds reuse
the index; adding/changing a mark reuses unchanged snapshots. Painting and hit
testing use only the relevant page. This cache is disposable reader state, not a
new annotation format or source of truth.

Plain highlight/underline/strikeout saves show temporary markup while persistence
is pending and keep the review panel/camera unchanged. Success clears the text
selection so clicking a mark opens its details. Failure removes only the temporary
preview and retains selected text for retry. Passage comments retain their existing
draft-preserving dialog; Cancel does not report a save failure. Text markup remains
paint-only so selection drags and selected-text context menus remain available.

Right-click a text mark for details, color/style/comment editing, quote copying
or Delete. The details dialog and review rows also offer Delete, including older
source-version items needing cleanup. Deleting moves the same annotation note and
its comments to ordinary Trash; the original PDF and other annotations remain
unchanged. An eight-second Undo restores that exact deleted revision. Later edits,
competing editor drafts, unsupported/read-only notes or a changed Vault refuse
stale mutations rather than replacing current content. Trash remains available
after restart. Closing a deleted note's tab does not create a second auto-snapshot
that would invalidate Undo. Clipboard failures in review rows show a retryable
message rather than an unhandled exception.

Native regression checks cover real PDF text selection/rendering, pending and
failed saves, same-identity Undo, source replacement, read-only changes while a menu
is open, narrow enlarged-text controls and native restart/original-byte retention.
See [current task](../tasks/current.md) for actual runs and the geometry-only
benchmark; neither is a measured desktop frame-rate or full Acrobat-parity claim.

## Reusable source libraries and BibTeX — 2026-10-11

Create source library in the citation manager makes a named ordinary Vault note
containing current metadata. Reuse library sources lets another note review and
select records before copying a bibliographic snapshot. Open source library follows
its canonical UUID; missing libraries keep local snapshots usable. Libraries use
existing note edit/save/history, backup and deletion. Updates do not automatically
propagate into citing documents.

Import BibTeX accepts a bounded UTF-8 file or pasted text, previews sources/warnings
and permits selection. Key and normalized-DOI conflicts offer keep existing, new
incoming key or explicit replacement retaining existing citation keys. Duplicate
and contradictory matches refuse ambiguous writes. Export BibTeX uses the platform
save/download adapter, preserving unknown fields and unchanged raw TeX in imported
records. Cancellation and stale-note/workspace changes leave authored data intact.
Nested/quoted/braced fields, numeric values and literal concatenation are supported;
unresolved macros and skipped directives are warned, never executed. Import limits,
display mapping and export fidelity are documented in
[formats](../architecture/implemented-formats.md). Native file-dialog/device
acceptance is separate from automated parser/layout/storage validation.

## Citation management and bibliographies — 2026-10-11

FILE-10/14 has an offline document-local subset: Writing tools → Citations &
bibliography adds/edits/searches manual source metadata (title, author, year,
publisher/journal, DOI, ISBN, URL), inserts citations at the captured writing
position with page/section locators, and generates compact author–year or
first-use numbered References from cited sources only. Unused sources can be
removed; cited source removal requires removing its citations first. Duplicate
and missing identifiers show warnings. All mutations use existing note undo/save
and reject stale/read-only edits. Rich/Read retain readable citations while hiding
recognized metadata. PDF/HTML/Word publishing refreshes a source snapshot.

Source metadata and generated text survive external Markdown editing/reopening;
unknown fields and unsupported records are preserved. Code examples are literal,
and insertion refuses code/metadata/generated regions. Narrow layouts and enlarged
text use scrollable forms and wrapping actions. Styles are compact conventions,
not full APA/MLA/CSL. This does not fetch metadata, turn citations into separate
objects or integrate Zotero. Reusable library notes and reviewed BibTeX are delivered
above. See
[portable formats](../architecture/implemented-formats.md) and current task evidence.

## Local 3D model previews — 2026-10-11

Import OBJ or GLB files through the ordinary attachment workflow. The offline
viewer provides drag/arrow-key orbit, Front/Side/Top orthographic views, zoom,
Fit/Home and shaded or wireframe presentation. Original bytes are unchanged.
Native parsing runs in an isolate; web parsing uses the same bounded parser.

OBJ supports slash and relative face indices and fan triangulation; export
concave polygons as triangles. GLB 2 supports embedded triangle geometry,
indexed/nonindexed meshes, scene instances, matrix/TRS transforms and material
base-colour tint. Textures, animation, skinning and OBJ material libraries are
not rendered. Draco/Meshopt compression, sparse/quantized accessors, invalid
bounds and missing geometry report useful preview errors with Retry and Open
original. Limits are 32 MiB, 100,000 vertices and 50,000 triangles, with bounded
scene traversal.

Add to Canvas searches editable boards and creates a fresh ordinary placement
referencing the canonical attachment. Existing drop and placement actions also
apply. Removing a placement preserves the source asset. Canvas displays a linked
model card that opens the viewer, rather than an interactive mesh in every card.

Status: partially implemented; see dated delivery sections and current validation.
Stage: M2 basic files; M4 annotations; richer viewers later.
Sources: S01, S03, S04, S07, S08 in the [source map](../product/conversation-extraction.md).
Architecture: [storage](../architecture/storage-formats.md),
[annotation engine](../architecture/canvas-engine.md).

## Extracted PDF text in workspace search — 2026-10-08

### Local OCR and review — 2026-10-09

FILE-08 now includes Windows-local recognition of scans/image attachments. Search
scanner, PDF Document tools and image previews open review with bulk jobs,
progress/pause/cancel, failures/retry, correction save/reset and selected-passage
Markdown notes with UUID page links/checksum provenance. Profile language support
is required; files never upload. Portable versioned metadata retains original
recognition and corrections without modifying attachments.

Verified OCR overlays blank pages/images; explicit corrections override embedded
text. Matches mark original source lines; corrections return by page only. Changed
sources invalidate search while retaining old evidence; explicit re-recognition
stages complete replacement and preserves same-source corrections. Cancelled/
failed files retain previous records. Other platforms search/edit saved evidence
but do not yet recognize new sources. Printed text is primary; handwriting,
equations/layout/rotation accuracy is not promised. No confidence score is invented.
See [formats](../architecture/implemented-formats.md), [ADR 0023](../adr/0023-local-ocr-evidence.md)
and [current evidence](../tasks/current.md). The extraction-only OCR exclusion
below is historical and superseded by this Windows-local delivery.

FILE-08 text extraction now contributes page excerpts to Global Search alongside
notes, tasks and Canvas. Local background extraction is bound to actual bytes;
complete caches survive native restart, while browser caches are session memory.
Changed/relinked sources invalidate prior results; opening a match verifies bytes
and highlights the exact page range. Clear match removes transient highlighting.
Extraction never writes the original, object metadata, durable offsets or annotations.

Search coverage exposes page progress, failed PDFs with retry, pause/resume,
scanned/no-text pages and partial coverage. Corrupt/locked/copying-restricted files
and size limits fail visibly without hiding the original file. Sources are bounded
to 100 MiB and extracted text to 32 Mi characters per document. Cache failures
retain session search with a warning. OCR and retained unlock passwords are not
part of this delivery. See [search architecture](../architecture/search.md) and
[current evidence](../tasks/current.md).

## Bookshelf redesign — 2026-09-30

The library prioritizes titles and reading: shelf/search controls, recent/title/
progress sorting, card/list presentation and a compact resume for genuinely
started books. Reading rooms are selected through a menu and passed to the reader.
Favorites, bookmarks, linked PDF notes and export remain on the existing objects;
saved pages navigate to the reader using session context. No fabricated cover or
resume item is shown. Current session pages supplement library reading metadata;
unknown page totals do not imply completed books. Narrow and large-text layouts
and malformed bookmark values have regression coverage. See the
[task report](../tasks/colors-bookshelf-2026-09-30.md) for validation.

## Reading tools addition — 2026-09-22

Saved pages now supports optional names, case-insensitive search by name/page,
and a preview of the selected page (2026-09-24). Rename is disabled in read-only
readers; blank names use the page number. Out-of-range bookmarks remain visible
but cannot be opened. Existing page-number bookmarks stay compatible.

Bookmark browsing supports page order in either direction and name A–Z/Z–A.
Sorting retains the selected page. Up/Down while the filter is focused selects
and reveals results; Enter opens the selection. Sort order is local to the dialog
and does not change durable bookmark metadata.

The PDF outline opens in a searchable dialog with parent-section context, page
numbers, lazy results, arrow-key selection and Enter activation. All nesting
levels are searchable; section jumps preserve full PDF destinations and integrate
with previous/next visited pages. Missing and unreadable outlines have distinct
messages; this feature does not generate headings for PDFs without an outline.

At enlarged text sizes and narrow widths, outline/bookmark titles and parent/page
context wrap in lazy variable-height rows (2026-10-08). Keyboard selection reveals
the actual row bounds. Headings, filters, and lists share a scroll surface; Close
and Open page remain in the footer. The selected bookmark preview precedes the
list so it remains reachable in a large bookmark collection. Bookmark rename
help/errors and custom zoom validation wrap completely, keeping failed input.

The zoom menu supports a 400% preset and validated custom fractional percentages.
Document tools offers first/last page, previous/next visited page and document
information (page count, current page dimensions, encryption and copying permission).
Page-jump history is local to the reader session, capped at 100 prior jumps and
reset on source replacement. It tracks explicit page navigation/internal links,
not ordinary scrolling or text-search results, and restores pages rather than
exact scroll/zoom positions. Original PDF bytes and permissions stay unchanged.

## Purpose and workflow

A researcher keeps a PDF alongside notes, highlights a claim, links it to a
decision and adds handwritten context. A developer attaches source code and a
diagram; a student captures audio. Original files remain available even if an
in-app viewer or extraction tool is unavailable.

## Requirements

| ID | Observable behavior |
|---|---|
| FILE-01 | Attach or reference arbitrary file types with filename/type/size and an explicit external-open option; attaching never executes a file. |
| FILE-02 | Store original bytes separately from object metadata and previews, retaining source filename, checksum and ownership/reference information. |
| FILE-03 | Image viewing supports suitable resolution, thumbnails and later crop/regions/annotations; destructive transformations preserve originals or explicit history. |
| FILE-04 | PDF viewing navigates pages, previews only needed pages and supports later text highlights, ink, comments and deep links to a page/region/annotation. |
| FILE-05 | Highlights/regions can become linkable knowledge with tags/comments/relations and a navigable source; selecting them elsewhere returns to their context. |
| FILE-06 | Text/code previews preserve raw text and add syntax highlighting where supported; code execution requires a separately authorized extension capability. |
| FILE-07 | Audio/video playback and voice capture can retain time-based source references; transcription is optional and linked to its original media. |
| FILE-08 | OCR/extracted text can participate in search with source attribution and recognition-quality limits; extraction failure does not make the original inaccessible. |
| FILE-09 | Unsupported/corrupt/missing media has a usable fallback and recovery/relink path; shared references do not duplicate bytes for each card/view. |
| FILE-10 | Future citation/bookmark integrations preserve source URL, capture context and extracted metadata with review/correction of uncertain values. |
| FILE-11 | First-class PDF reading provides page navigation, thumbnails and in-document search, with Continue Reading restoring page/zoom/highlight context. |
| FILE-12 | PDF highlights, underline, strikeout, comments, sticky notes and shared-ink annotations retain stable anchors. Selected text can be extracted to a note with exact page/highlight provenance and backlinks. |
| FILE-13 | PDF highlights are linkable Universal Objects when created as knowledge annotations; ordinary ink samples remain local stroke data. Canvas can display the PDF and its referenced highlights together. |
| FILE-14 | Citation properties can include DOI, ISBN, author, year and source metadata; Zotero integration and annotated-PDF export are later adapters with declared fidelity. |

## Format support ladder

| Family from the chat | Initial treatment | Later intended enhancement |
|---|---|---|
| `.md`, `.txt`, source code | Text/open-file support appropriate to the object | Preview, syntax highlighting and linked snippets |
| `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.svg` | Original attachment plus supported preview | Regions, annotations, safe SVG rendering, thumbnails |
| `.pdf` | Original attachment and planned viewer | Highlights, comments, linked regions and shared ink |
| `.mp3`, `.wav`, `.m4a`, `.mp4`, `.webm` | Original attachment, platform-capable playback later | Voice notes, timestamps, transcription |
| `.csv`, `.json`, `.yaml`, `.yml`, `.html` | Preserve original / safe text or import preview | Structured import and sanitized saved-page view |
| `.docx`, `.xlsx`, `.pptx` | Original attachment/external open | Evaluated import or viewer; native editing is not promised |
| `.obj`, `.glb` | Offline bounded static geometry preview and linked Canvas cards | Texture, rigging and animation support remains future |
| Other files: archives, `.blend`, project assets, executables | Metadata/reference/external-open choice | Plugin-provided preview where supported |

“First-class file object” does not mean every codec or proprietary format has an
editable native implementation at launch. Each supported preview must name its
platform/fidelity limits. External-open uses an explicit user gesture and respects
OS choices; HTML/SVG/remote embeds do not inherit arbitrary script privileges.

The original PDF stays unmodified by default. Annotations live in documented
sidecars/objects referencing its version. An exported annotated PDF is a derivative
with explicit overwrite choice, not a silent replacement. Reading Workspace layout,
reading sessions and Continue Reading share CTX restoration/session behavior.
Windows screenshot paste, resize/aspect ratio, replace, open original and Show in
Explorer are defined once in [desktop interactions](desktop-interactions.md).

## States and acceptance scenarios

- FILE-02/09: attach one PDF, reference it in several notes/boards, remove one
  placement and verify original bytes remain for other references.
- FILE-04/05: open a linked highlight after restart and return to the same page
  region. Replace the PDF with a different revision and show a re-anchor state.
- FILE-03: import large photos and verify bounded decoding/thumbnail memory at low zoom.
- FILE-07/08: deny microphone/remote extraction access and keep local file viewing usable.
- FILE-09: simulate corrupt content and missing bytes without crashing the workspace
  or losing annotation metadata. Removing the last reference does not silently
  authorize permanent byte deletion; retention follows the recovery policy.

## Delivery

### Attachment relinking and source recovery — 2026-10-07

Missing attachment previews open a recovery dialog with three explicit paths:
restore checksum-matching bytes at the original path, relink a stable file
object to a new immutable source, or restore a retained source version. A
relink records the previous source in `attachmentSourceHistory` while keeping
the Universal Object ID stable. Existing Markdown paths are never silently
rewritten; failed or stale recovery commands preserve the current source and
surface the reason. Retained source bytes are ordinary attachment files and can
be opened before choosing a version.

Start with durable attachment objects and explicit open/fallback. Add viewers one
at a time, then annotations and extraction. Choose packages based on actual target
platform support in the corresponding task, not a speculative all-format dependency list.

### Recovery verification and retained-source cleanup — 2026-10-07

The recovery chooser previews the selected filename, byte length, and SHA-256.
Restoring a missing original requires the recorded checksum; a mismatch keeps
the restore action disabled while still allowing an intentional relink as a new
source. Recovery reads are capped at 100 MiB on this path and explain the limit
when exceeded. Retained history entries can be forgotten after confirmation.
Cleanup refuses the active source and refuses a path still used by another live
file object, then removes the history record and deletes only bytes whose hash
was verified through a streamed read. The recovery dialog reports verification
progress for large retained sources. If bytes are missing or changed, cleanup
fails before changing history. Existing Markdown references and the active
source remain untouched.

The recovery dialog paginates retained source history in groups of eight and
offers a visible cancellation action while any source is being verified or
staged. Cancellation is checked between streamed chunks. Retained-source
cancellation leaves the history and immutable bytes untouched, while native
attachment transfers retain their durable partial stage so the user can resume
later. The active reference is not changed until the complete checksum-guarded
commit succeeds.

The recovery dialog is keyboard and screen-reader friendly: source history and
progress are live semantic regions, each source is announced with its path and
size, and focus follows a stable traversal order. Escape cancels an active
operation or closes the idle dialog; Ctrl+Page Up/Down changes history pages.
Cancellation announces that references and retained bytes remain preserved and
prevents duplicate cancellation requests.

High-contrast palettes receive a visible dialog outline, outlined source
records, larger action targets, and a thicker progress bar. Reduced-motion
settings stop progress animation ticking while retaining deterministic progress
values and live status text.

Recovery also hardens the dialog's effective color scheme before rendering:
custom surface palettes with unreadable text, outline, or progress tokens use
deterministic high-contrast fallbacks while preserving the chosen surface. The
same rule applies to light and dark themes, so recovery choices remain legible
without requiring users to reset their palette.

Recovery and source-cleanup confirmations scroll their titles with the content,
keeping footer actions reachable in compact windows and with large text. History
page labels wrap between fixed navigation buttons. Filenames, paths, checksums,
and status messages remain fully available without capping accessibility text
scaling. Keyboard insets and runtime text-size changes do not restart verification
or remove its cancellation action.

### Streamed recovery hashing and progress — 2026-10-08

Recovery reads the selected XFile twice from independent streams: the first pass
verifies byte length and SHA-256 for the confirmation surface, and the second
pass commits only after the user accepts. Native Vaults use disk-backed staging
with incremental hashing and progress callbacks, avoiding a second full byte
buffer for large files. Browser stores use the existing bounded fallback. A
changed stream, checksum mismatch, or 100 MiB limit failure leaves the active
source and authored references untouched.

### Resumable recovery after interrupted staging — 2026-10-08

Native restore and relink stages retain a device-local manifest beside their
partial bytes. The manifest records the operation, target, expected SHA-256,
source name, and byte offset. On the next Vault open, recovery lists matching
stages and lets the user choose the same source to continue from that offset
or discard the stage. Resume appends only the remaining source stream and
verifies the complete checksum before the guarded commit. A failed resume
keeps the stage available for another attempt; discard removes only the
device-local stage. Browser storage remains bounded and non-resumable.

Native Vault startup cleanup applies the same recovery policy to abandoned
stages: a well-formed stage whose durable `updatedAt` is older than 30 days is
removed with its `.part` bytes and temporary manifest. Recent stages remain
available to resume, malformed manifests are left for explicit inspection, and
unsupported newer workspace formats are not modified. Users can still discard
any listed stage immediately from the recovery dialog.

## Delivered reader subset — 2026-09-11

PDF file objects now open in the local reader: page input/previous/next, zoom,
fit, virtualized thumbnails, PDF outline, text selection/copy, literal in-document
search and page bookmarks. Page/zoom restore per pane. Copy Page Reference produces
a UUID wiki link; selected-text context actions copy a quote with source or create
a durable linked note beside the PDF. Original bytes stay unchanged.

See ADR-0013 and implemented-formats for file properties and page fragments.
Missing files offer Retry/external-open. On Windows the PDF engine can report a
damaged file as password-related; the dialog explains this and Cancel leads to
recovery. No password is persisted. Password-protected documents are supported by
the local prompt but encrypted-file fidelity has not been exhaustively tested.

Still planned: persisted highlights/underlines/strikeout/comments, annotation
objects, shared ink, OCR, citation adapters, revision re-anchoring, forms, signatures,
redaction, page editing and annotated export. This is a research reader, not full
Acrobat parity. Scanned PDFs can be viewed but have no text search without OCR.

### Highlight and source-preview follow-up — 2026-09-11

Supersedes the initial reader's deferred text-highlights/comments boundary.
Select PDF text and choose Highlight or Highlight and comment. The Highlights
panel returns to the source page or opens a linkable Markdown note beside the PDF.
Comments are edited in that note; ordinary Trash/restore removes/restores overlays.
Checksum mismatch suppresses old overlays and preserves the note for source review.
Normalized regions reuse Canvas rectangles; freehand PDF ink is still deferred.

Attached source/text files now open read-only with syntax highlighting and Copy
Code: C/C++, C#, Python, JavaScript/TypeScript, Dart, Java, Kotlin, Rust, Go, Swift,
Ruby, PHP, shells, SQL, JSON/YAML/XML/HTML/CSS and additional mapped extensions.
This is source text, not execution or an HTML browser. Unsupported grammars remain
plain text. Strict UTF-8 previews are limited to 1 MiB; invalid/binary/oversized
files retain an external-open fallback. Tests verify C++ highlighting and exact copy.

### PDF documentation workflow — 2026-09-11

The PDF reader's Create document action offers Research note, Game design decision
and Playtest finding. Each creates an ordinary editable Markdown note beside the
PDF, with a stable current-page link and checksum provenance. A permitted text
selection is quoted with its first page. No original attachment is modified.
Saved highlights can be filtered by title, quote and note/comment body; the filter
is local to the reader session. Read-only workspaces disable document creation;
failed saves leave the source and existing notes intact.

These are document starters, not automatic evidence extraction, a template registry
or a complete project preset. Precise region return and revision re-anchoring remain
planned; multi-page selections retain first-page provenance.

### PDF work mode and phone reading — 2026-09-11

Fill PDF forms exposes ordinary AcroForm checkboxes and text fields on their page.
A checkbox toggles on tap; a text field opens a local editor. Field drafts persist
in Orbit. Save filled copy creates a separate PDF attachment with real filled field
values; the source PDF is unchanged. Protected/signed/XFA documents and other form
field types remain unsupported. Browser form editing is disabled. A checksum change
blocks stale drafts; manual draft-review/reset UI remains future work.

Comfort reading presents extracted text at adjustable 14–36 pt on a narrow reading
surface. It starts automatically below 600 logical pixels and has an Original page
switch. It is page-based text reading, not automatic cropping or OCR. Scans and
complex diagrams retain the original-page view; text order follows PDF extraction.
Font size/mode are session-local and not yet restored across launches. Physical
phone validation remains required; a 390×844 widget test covers the narrow layout.
See ADR-0015 and implemented-formats for the safety contract.

### Visual comfort reading and reader tools — 2026-09-12

Supersedes the text-only default described above. Below 600 logical pixels, comfort
reading now retains the live PDF page: embedded images, tables, equations, scans,
links and annotation painting remain available. Content-width fitting samples a
bounded preview of all rendered content, with 3% padding and at most 20% blank-margin
reduction on each side. Blank/failed previews fall back to full-page width. This
changes only the viewport; original page content remains accessible by panning or
Original page. It is not a destructive crop or semantic multi-column reflow.

Text-only reading remains an explicit separate action with adjustable font size.
Visual comfort refits for a new page or viewport width. Measurement futures are
bounded to 32 pages, previews to 640 pixels on the longer axis, and render buffers
are disposed. No storage format or migration changes.

The zoom menu offers Fit content, Fit entire page, Fit page width, and 50/75/100/150/
200% presets. The live percentage follows zoom changes. Keyboard shortcuts within
the focused reader: Ctrl+0 whole page, Ctrl+1 100%, Ctrl+2 page width, Alt+Left/Right
page navigation, F3/Shift+F3 search matches. Narrow-screen controls scroll horizontally.
Physical phone/high-DPI gesture validation and advanced Acrobat tools remain future
acceptance work. Dense multi-column pages can still require pinch zoom and panning.

### PDF review workspace — 2026-09-14

Builds on the existing color highlights, underlines/strikeouts, continuous/single/
two-page layouts and source-region return. Add page comment works without text
selection, including scans and diagrams. It creates an ordinary linked Markdown
note with a versioned marker on the current page; the original PDF is unchanged.
Comments can be opened beside the PDF, linked from Notes/Canvas/graph, or recovered
through ordinary note Trash/restore.

The review panel filters by words, open/resolved status, markup type and current
page, and sorts by source page or creation date. Editing a review item changes its
existing Markdown note, color/type and resolved status, without creating another
object. A stale dialog cannot replace a newer note or apply styling to a changed
PDF version. Failed saves keep local drafts and show a retry/reopen explanation.
Copy reference provides a UUID note link. Hide review markup affects only this view.

Copy/export the filtered items as Markdown, or save a review summary as a new note
beside the PDF. Both annotation and page links retain UUIDs with readable labels;
renaming a file does not break them. Existing quote bodies are not duplicated in
summaries, and obsolete source versions carry a warning. Summaries are snapshots,
not automatically maintained copies of annotations. The plain Markdown export
uses the existing native Save As/browser download adapter and is bounded to avoid
building unbounded strings. Cancellation/failure leaves the Vault unchanged.

No Acrobat account, remote processing, new PDF writer, or storage migration is
introduced. Remaining: interoperable PDF annotation import/export, free-positioned
page comments, shared ink, OCR, true redaction, signatures and page/content editing.
Current page comments use automatic markers; they do not imply an exact user-picked
region. Ordinary notes remain the durable authoring format. See current task for
validation and device limits. Product reference: Adobe's
[comment management](https://helpx.adobe.com/acrobat/desktop/share-and-review-documents/manage-reviews/view-comments.html).

### Annotated PDF copies — 2026-09-15

The review panel's **Save filtered review as annotated PDF** saves a separate PDF
attachment in the Vault on native platforms. It exports exactly the filtered notes
as standard Highlight, Underline, StrikeOut or Text annotations. Each source region
gets one annotation with its note UUID reference, title, Unicode Markdown body and
color. Open/resolved appears in comment text; native threaded review state is not
exported. Existing PDF content and filled field values remain; Orbit form drafts
require the separate Save filled copy workflow. Original bytes and notes are never
overwritten. Repeated unchanged copies may reuse the attachment importer's existing
checksum deduplication. Use Open original on the new attachment for an external reader.

Stale checksums, changed note/source snapshots, unsupported metadata, invalid page
regions, protected/signed/XFA documents and excessive input are rejected. Failed
saves retain review notes for retry; concurrent export clicks are disabled. Native
PDFium converts normalized display geometry including rotation/crop offsets. Web
keeps the existing Markdown export. Annotation import, shared ink, redaction,
signatures and PDF content editing remain deferred. See current task for checks
and post-reset Windows build validation.

### Reader reliability and connected notes — 2026-09-16

Connected notes lists existing source-linked notes and Markdown backlinks to the
PDF, with title/body filtering and a current-page note action. Opening a result
opens the original note beside its source. Returning from a highlight note focuses
its saved region; changed source versions show a warning and do not reuse stale
geometry. Repeated source navigation works even when the PDF is already open.

Layout changes preserve page and zoom. Closing or opening a note flushes the last
reading position. Retry reloads attachment bytes and replacing a source version
reloads the renderer. Page input normalizes to valid bounds. Text highlights no
longer use broad hit-test overlays that obstruct selection; passage taps use the
actual regions. Failed passage-comment saves retain the draft for retry. Quote
and filled-copy saves check that their source has not changed while processing.
Clipboard and form-save exceptions show recoverable feedback.

These are verified fixes for the tested workflows, not a guarantee for every PDF.
OCR, arbitrary embedded annotation editing and native annotation import remain
outside this pass. Original attachment bytes remain unchanged.

## Creative reference capture — 2026-10-09

Local multi-file Canvas capture reuses validated attachment import and saves,
preserving original bytes, filename/type/checksum metadata and canonical identity.
Project/folder attribution comes from the target board; each placement keeps its
own commentary and review details. PDF/image/general file previews use existing
loaders and opening/recovery boundaries. No file execution, web fetching or media
transformation occurs. Failed files are reported without discarding successful
ones. If metadata enrichment or placement fails, already imported sources remain
discoverable. Sources stay available after placement removal or insertion undo.
