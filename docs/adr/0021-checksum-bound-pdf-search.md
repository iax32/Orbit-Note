# ADR 0021 — Checksum-bound PDF search and complete discovery candidates

Status: accepted direction, 2026-10-08. Delivery evidence is in the current task.
Extends ADRs 0012, 0013 and 0020; source authority and reference syntax are unchanged.

## Context

Searching only the first 100 indexed objects/locations could hide a matching
project after filtering. PDF reading extracted text locally, but workspace search
did not include page text. Search cannot safely reuse offsets after bytes change.

## Decision

Return complete substring candidates from existing native FTS/LIKE and browser
memory indexes. The shared search projection merges names, current drafts, tasks,
Canvas content and PDF occurrences; Global Search filters/sorts before 50-row UI
pagination. Keep compact previews explicitly limited after their own filters.
Do not replace repositories or introduce a new search engine/package.

Add an optional disposable PDF text cache capability to ObjectIndex. Native
Drift schema 4 adds one JSON text table without changing objects, source formats,
FTS triggers or object IDs. Browser uses memory. Each completed document records
cache version, attachment path, actual SHA-256 and ordered page text. Cache parse
rejects unsupported/incomplete data; extraction-format changes must bump cache
version before old offsets are reused. Cache loss/corruption rebuilds from original
files. This is derived text, not a new authoritative object or history snapshot.

One serial worker per open Vault extracts structured page text through pdfrx's
existing worker. Repository-owned byte reads/hashing enforce path and size bounds.
Token/source checks prevent publication after replacement, relink, deletion,
pause or close. Cache writes are atomic statements; partial page progress is never
a searchable document. Actual bytes are verified before cache reuse, after
extraction and before publication. Cache write failure leaves searchable session
text with an honest warning. Originals and declared attachment metadata are never
rewritten by extraction. Search surfaces expose pending/progress/failure/partial
coverage, pause/resume and retry. Focus and reload reverify after missed watch events.

PDF results carry stable UUID/page and ephemeral text offsets/path/actual checksum.
The controller verifies current bytes before navigation; the reader verifies its
loaded snapshot and waits for progressive page loading before mapping a range.
Changed source matches refresh an already-open reader. Offsets are never written
to portable notes or session settings; the existing page reference stays portable.

## Consequences and limits

No account/network service is needed for PDF extraction/search. Original attachments
remain accessible if indexing fails. Text extraction does not imply OCR, unlock
password retention, copied annotation knowledge or completeness for scanned pages.
100 MiB source and 32 Mi-character extracted-text bounds fail visibly, without
silently truncated search. Only completed caches survive native restart.

Native heavy search projection runs in an isolate. PDF page strings and complete
results are materialized in memory; UI pagination is not a database cursor or an
unlimited-size performance guarantee. Browser query projection remains inline,
with session-only cache and pdfrx's web extraction adapter. Platform builds/tests
are reported separately from runtime validation on other devices.

Compatibility checks cover schema 3→4 migration, old FTS queries, cache restart,
index deletion/rebuild, malformed cache, complete result sets beyond 100, original
byte/metadata preservation, interrupted extraction and real PDF page navigation.
