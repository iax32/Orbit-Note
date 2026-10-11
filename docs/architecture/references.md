# Implemented precise references

Canonical object UUID is always the owner. Optional anchors address an explicit
Markdown prose block, heading, Canvas element UUID, LaTeX label, PDF page or
annotation note UUID. Existing `[[target|label]]` syntax remains unchanged; fragments
are preserved through title/alias resolution and display transformation.

Examples: `[[UUID#^orbit-block]]`, `[[Relations#Equivalence%20Relations]]`,
`[[UUID#element=element-UUID]]`, `[[UUID#label=eq%3Apartition]]`,
`[[PDF-UUID#page=17]]`, `[[PDF-UUID#annotation=annotation-note-UUID]]`.
Unknown fragments survive; missing/duplicate anchors do not choose another source.

Block anchors are lazy, explicit ` ^orbit-UUID` suffixes on an ordinary prose
paragraph. Code/unsupported block source is not modified. Rich prose preserves
the suffix losslessly without displaying it in editable content. Labels/headings
are derived; heading rename needs deliberate link repair.

Canvas card `objectId` plus optional `referenceTarget` resolves current source text.
No duplicate note body/object is created. Removing the card only removes placement.
Backlinks carry source location, target location and surrounding context. Navigation
uses transient requests; snapshot offsets are never durable knowledge identifiers.

Global PDF search carries page text ranges with the actual attachment checksum.
The controller verifies live bytes and the reader verifies its loaded snapshot,
waiting for the page to load before highlighting. Only page navigation is saved;
search text offsets/path/checksum remain transient. Source replacement causes
reindexing and rejects obsolete ranges. See [ADR 0021](../adr/0021-checksum-bound-pdf-search.md).

See [ADR 0020](../adr/0020-precise-reference-composition.md) and
[delivery limits](../tasks/architecture-composition-2026-09-30.md).
