# ADR-0014 — PDF highlights as source-versioned notes

Status: accepted, 2026-09-11. Extends ADR-0013 and the spatial reuse contract.

## Decision

A text highlight is an ordinary orbit.note with a stable UUID, Markdown quote,
page reference and optional comment. pdfHighlightVersion: 1 identifies this
annotation capability. pdfSource records the file UUID, checksum, one-based page,
selected quote and regions. Regions reuse CanvasElement rectangles with normalized
top-left page coordinates and one-based page fields. Conversion uses PDFium's page
rotation adapter, then divides x/width and y/height independently.

The reader paints regions only when the attachment checksum matches. A changed
version retains the note but suppresses overlays and asks for source review.
Creation validates source version, bounds and writable state before one repository
create. Original PDF bytes never change. Notes already provide editing, UUID
references, Canvas cards, search, Trash/restore and durable Markdown comments.
This avoids a competing comment store or an additional database schema.

## Alternatives and boundaries

A separate annotation object type is deferred until it provides behavior that
ordinary notes cannot represent safely. Embedded PDF mutations were rejected for
this batch because they would change authoritative attachment bytes. No general
ink tool, rectangle drawing engine or alternative history system was introduced.
Arbitrary page/image ink should reuse the existing spatial input/history engine.

This slice supports text highlights and editable note comments. It does not include
underline/strikeout, threaded comments, manual re-anchoring, annotation fragment
navigation, OCR, PDF rewriting/export or full Acrobat parity. Opening a highlight
note shows the PDF alongside it; its source reference navigates to the page.
Regions retain unknown fields. Unsupported annotation versions remain ordinary
notes without overlays. Source properties are not silently upgraded or normalized.

## Validation

Native PDF tests select actual multi-page text, invoke the selection comment action,
save a comment, inspect normalized regions, open the linked note action and detect
source replacement. Controller tests cover save/reopen, original-byte preservation,
invalid/stale geometry rejection, failed creation and Trash/restore. Physical mouse
selection and rotated-document acceptance remain manual follow-up work.
