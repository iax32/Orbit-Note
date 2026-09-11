# ADR-0013 — Local PDF reading and portable page references

Status: accepted, 2026-09-11. Extends ADR-0004/0007/0011 without an object-envelope migration.

## Context

The owner requests PDF research alongside Notes and Canvas, including navigation,
search and cross-references. Opening an external reader alone cannot return from
a research note to its source page. Original attachments must stay authoritative.

## Decision

Use the MIT-licensed [pdfrx 2.4.8](https://pub.dev/packages/pdfrx/versions/2.4.8)
viewer/PDFium adapter, compatible with the installed Flutter/Dart toolchain. The
UI obtains bounded original bytes through `WorkspaceRepository.readAttachment`;
it does not receive a native Vault path and never rewrites the PDF. Engine search,
text selection, thumbnails and rendering run locally. PDF document copy permissions
apply to quote extraction. External PDF links accept HTTP, HTTPS and mailto only.

Stable page references use `[[object-uuid#page=2|Readable title · p. 2]]`.
The existing resolver resolves the UUID for backlinks/graph and preserves the page
fragment for navigation. Authored notes are not normalized. The page is one-based;
malformed anchors stay unresolved rather than guessing another destination.

Bookmarks are ordinary `pdfBookmarks` file-object properties. Quote extraction
creates one ordinary note through a single repository create operation, with the
quoted text, source link and `pdfSource` metadata including original checksum.
Reading page/zoom is disposable per-pane session state. No new object type,
database authority, cloud service, secondary ink engine or PDF-writing path.

## Boundaries and consequences

Windows release and real-document integration tests are required. Other platforms
retain adapters but have not received device/browser acceptance in this batch.
PDFium adds native distribution assets; ship the complete release directory and
upstream license notices. Local generated plugin junctions avoid changing machine
Developer Mode; these are ignored artifacts, not committed source.

This reader is not Acrobat parity: persisted highlights/ink/comments, annotation
objects, region-level anchors, re-anchoring after PDF replacement, OCR, forms,
signatures, redaction, page editing and annotated exports remain future work.
Scanned pages render but do not acquire selectable/searchable text without OCR.
Later annotations must follow FILE-12/13 and the shared spatial engine contract.

## Validation

A generated two-page PDF exercises native rendering, page navigation, text search,
bookmarks and source-link copying. Controller tests verify durable quote creation,
original-byte preservation and failed-create safety. Resolver tests cover renamed
IDs and malformed page fragments. Final evidence is recorded in implementation status.

Follow-up: [ADR-0014](0014-pdf-highlight-notes.md) adds persisted text highlights
and editable comments as ordinary source-versioned notes. The initial reader's
highlight deferral above is historical; freehand ink and advanced PDF tools remain
unfinished.
