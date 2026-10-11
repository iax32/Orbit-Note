# ADR 0023 — Local OCR evidence and editable recognition

Date: 2026-10-09. Status: accepted for the Windows-first FILE-08 batch.

## Context

PDF text search has checksum-bound disposable caching. Scans/images need offline
recognition with durable user corrections. SQLite cannot own the sole copy of
corrections; OCR ranges cannot be interpreted as PDFium native-text offsets.

## Decision

Use Windows Media OCR behind a byte-only method channel. One background worker
per window returns on the window thread; teardown waits for current work. Serial
PDFium rendering bounds raster memory. No account, network, subprocess, bundled
model or language-pack installation. Other platforms fail recognition explicitly
while keeping saved evidence usable.

Canonical file `properties.ocr` stores version/path/actual SHA-256/language,
per-page original text, UTF-16 line ranges, normalized top-left rectangles and
optional correction. Validated recoverable repository saves provide history.
Unknown sibling/page keys survive supported edits; future records remain untouched.
Same-source re-recognition preserves corrections. Changed bytes require explicit
new recognition, retaining prior evidence through ordinary history.

Shared indexing verifies source bytes before OCR publication. Native text is
preferred unless blank or explicitly corrected. Raw metadata indexing/snippets
exclude OCR to prevent stale-text leakage. Evidence rebuilds search after restart
or index deletion. Results label recognized text and carry transient line regions;
painting verifies displayed bytes. Corrections navigate by page only. Extracted
Markdown notes retain UUID page links/checksum provenance.

## Consequences and bounds

No SQLite migration or original-file mutation. Ordinary metadata/backup carries
recognition and corrections. Stale/read-only/changed-source/partial/invalid output
fails before commit. Serial jobs allow pause/cancel at page boundaries; completed
earlier files remain saved. No confidence score is invented for this API.

100 MiB source, 500 pages, 2 Mi UTF-16 characters including corrections and 20,000
lines per record. 2,600px raster long edge and 100MP original-image guard. Installed
profile languages/Windows codecs govern availability. Other-platform engines,
partial-page resume, semantic layout/equation conversion and handwriting accuracy
are separate. Validation evidence belongs in the current task.
