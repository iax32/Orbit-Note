# ADR-0015 — PDF form drafts and filled copies

Status: accepted, 2026-09-11.

Ordinary AcroForm text and checkbox fields are edited through a native PDFium
adapter. Run native calls on PdfrxEntryFunctions.compute, PDFium's owning worker;
using the live native handle on the UI isolate triggers unsafe font callbacks.
The adapter opens a separate in-memory copy and never edits the viewer document.
No document JavaScript environment or form action execution is installed.

Draft values are source-versioned properties on the existing file object, saved
through controller/repository commands. Values use page:annotation-index keys and
are valid only with the matching source checksum. Unknown versions and mismatched
sources are preserved and rejected for editing. Failed persistence retains the
existing recoverable dirty draft; it does not falsely report success.

Save filled copy applies values to a separate PDF, verifies the resulting field
values, encodes it and imports it as a new ordinary PDF attachment. Originals stay
unchanged. This is not an overwrite, digital signature or flattening workflow.

Protected, signed, XFA, read-only, password and file-select fields are unsupported.
Only text/checkbox types are exposed; dropdowns, radios, scripted calculations and
signatures are deferred. Bounds: 64 MiB encoded input, 80 MiB output, 2,000 fields
per page/draft and 10,000 characters per edited text value. These are safety limits,
not large-document performance guarantees. Native desktop is tested; browser form
editing is disabled. Device-specific mobile form acceptance is still required.

Comfort reading is a disposable current-page text projection with adjustable font
size, not OCR, semantic multi-column reconstruction or Adobe Liquid Mode parity.
It respects extraction permission and retains a route to original pages.
