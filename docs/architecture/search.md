# Implemented search composition

The native rebuildable FTS5 index accelerates literal substring matching over
titles, source, Canvas text and properties. Index triggers/upsert remain unchanged.
`WorkspaceRepository.search` returns candidate objects; a failed native index uses
a background source snapshot. The browser index caches normalized text on upsert.

`projectWorkspaceSearch` merges indexed candidates and current drafts with names
and live Canvas references. `OrbitSearchCoordinator` produces snippets, deterministic
rank and ObjectReference locations. Global Search and Command Palette body results
use the same projection. Quick Switcher uses shared name/context rank and deliberately
does not scan document bodies.

Native work above a 64K source-work estimate is isolated; small projection stays
inline. Browser projection is inline, not a worker. Native FTS/short-query LIKE
and the memory index return complete object candidates. Global Search projects
all locations, applies type/project/folder/tag/match/completion filters and sorting,
then renders pages of 50 lazy rows with totals and previous/next controls. Command
Palette applies its type constraint before showing its compact 12-result preview.
Collection/Space query scopes and a database cursor API remain separate work.

## PDF text search — 2026-10-08

### Recognition overlay — 2026-10-09

The shared indexer verifies portable OCR metadata against actual bytes. It overlays
blank PDF pages/images; explicit corrections override native text. `ocr` is excluded
from raw property indexing/snippets so obsolete text cannot bypass verification.
Results identify recognized text, page, excerpt and normalized line regions;
PDF/image painting verifies displayed bytes. Corrections use page-only navigation.
Native embedded-text cache stays unchanged; OCR search rebuilds from canonical
metadata after restart/cache rebuild. Changed sources discard matches but retain
evidence; explicit recognition stages replacement. Windows jobs are local/serial
with pause/cancel/retry; other platforms read/search/edit saved recognition.
See [ADR 0023](../adr/0023-local-ocr-evidence.md). The extraction-only OCR exclusion
below describes the preceding delivery and is superseded for Windows recognition.

The open Vault owns one serial `PdfSearchIndexer`. Its platform extractor uses
pdfrx's PDFium/wasm worker and structured page text, matching the reader's UTF-16
offset/geometry contract. It receives bytes through the repository, not paths or
original-file write access. Native cache table `pdf_text` in derived schema 4
contains versioned path/checksum/page-text JSON. Browser cache is session memory.
Deleting the index rebuilds search; originals, portable metadata and IDs are unchanged.

Before cache reuse, actual source bytes are hashed. Extraction validates its byte
snapshot, page order/completeness and the source hash again before publication.
Only complete documents become searchable. Attachments changing/relinking/deleting
invalidate old results immediately; focus/manual reload rechecks sources when a
watch event was missed. Interrupted work resumes by rebuilding the affected PDF;
completed other documents remain searchable. Pause, per-document page progress,
retry, failures, no-text pages and partial text coverage are exposed in Search.
Progress notifications are throttled; queries refresh in batches as coverage changes.

Each PDF occurrence carries a canonical file UUID, page, excerpt and ephemeral
offset/length/path/checksum. Opening checks the live source again; the reader checks
its displayed bytes, waits for the progressively loaded page and paints that range.
An already-open reader reloads bytes when a new match requires a changed source
version. Clear match removes transient highlighting. Only page navigation is saved;
text offsets/checksums are not durable reference identities or annotations.

The importer/indexer accept PDFs up to 100 MiB; extracted text has a 32 Mi UTF-16
character guard per document. Oversized, corrupt, locked or copying-restricted
documents report failures; scanned pages report that OCR is needed. OCR is not
implemented. Cache write failures retain session search with a visible warning.
Complete results and cached text are materialized, not streamed database pages;
native large projections run in an isolate. There is no claim of unbounded Vault
memory or worker-backed browser query execution.

See [ADR 0021](../adr/0021-checksum-bound-pdf-search.md),
[current delivery evidence](../tasks/current.md), and
[ADR 0020](../adr/0020-precise-reference-composition.md).
