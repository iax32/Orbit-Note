# Markdown PDF images — 2026-10-22

Owner request: make local and web images visible in Markdown PDF exports.
Scoped PORT-05/06/08/09 fidelity repair; existing sync work remains untouched.

## Changes

- Keep ImmutableBuffer, ImageDescriptor and Codec alive until frame extraction
  and PNG conversion finish. The prior premature disposal made valid images
  silently fall back to labels. Native rendering regressions reproduce this.
- Resolve canonical Attachments/ references at any note depth, decode one URI
  layer and retain special filenames. Read only through the captured repository;
  reject stale Vault generations and retain all authored notes/attachment bytes.
- Add embedded-image count, missing-image retry, explicit anonymous HTTPS loading
  and cancellation. No automatic remote request, account cookie/token or upload.
  Resources are shared across style changes and repeated sources are deduplicated.
- Bounded redirects, HTTPS-only URLs, streamed/declaration size limits, total
  deadlines and cancellation generations preserve labelled failure fallbacks.

## Validation

11 new regressions; focused **32 passed**. Final full suite: **2,848 passed,
2 existing skips** (Windows link privilege/manual Google consent). Actual PDF output rendered
with PDFium and Poppler, reviewed visually and checked for colored image pixels
and absent fallback labels. Also verified the Markdown Export as PDF toolbar
without a main-shell clipboard resolver, URI-encoded attachment names, missing
image retry, anonymous downloads, HTTPS downgrade/auth/size rejection, timeout,
late cancellation and compact 200% text layout. Synthetic local Vaults/HTTP only.

Format/strict check: **719 files, clean**. Analysis: **no issues**.
781 source/test/build inputs were frozen and verified unchanged during validation.
Configured Windows app + standalone host: **passed** (app compile 91.1s).
Standard JS web release: **passed** (89.8s). Existing Google SDK Wasm dry-run and
missing Cupertino font warnings remain; Wasm support is not claimed. Verified
seven required runtime/host files, fresh `data/app.so`/host payloads, and all 13
authored font hashes. Source/test/build inputs remained unchanged after building.
The runnable is `build/windows/x64/runner/Release/orbit_note.exe` with its complete
sibling runtime. No app, installer or persistent server was launched. Device-local evidence:
`.local/pdf-images-{focused,full,format,analyze-final}.log`, source snapshot,
`markdown-pdf-images-review.pdf`, PDFium PNG and independent Poppler PNG.

## Limits

No authored format, schema, migration, package or alternate PDF engine change.
All existing offline/cancel/save/history contracts remain. Remote opt-in lasts
only for the open publishing dialog and is not saved to the note. Normalization
and existing image/total/resource/page bounds remain. Unsupported image formats,
HTTP-only or authenticated/expired URLs, missing originals, network errors and
browser CORS restrictions remain labelled, retryable fallbacks; no login bypass.
LaTeX figures use their existing separate exporter. No personal Vaults, live
websites/accounts or desktop-control testing were used.

Suggested next task: SVG image normalization for document publishing; stop before
implementing it.
