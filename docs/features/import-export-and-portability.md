# Import, export and portability

## Image/table layouts and page-aware contents — 2026-10-12

Publish document now offers per-block print width (25–100%), left/center/right
placement, a print caption and Start on a new page for standalone images and
top-level pipe tables. Table header repetition is configurable. Long tables span
PDF pages without dropping rows; caption placement follows the block width.
Inline images and nested tables retain their existing flow instead of receiving
an ambiguous block layout. The Markdown Export as PDF button opens this workspace.
LaTeX retains its separate exporter.

The searchable contents panel shows actual PDF heading pages and navigates the
preview. Page positions regenerate with document/layout settings; stale positions
are disabled while generating. Lists paginate in groups of 20. PDF contents also
include page numbers. HTML shows clearly labelled PDF page references; Word uses
refreshable PAGEREF/TOC fields. Browser pagination and Word font substitution can
change positions; these differences appear in Export details.

Save settings to note retains the document style and block layouts in a bounded,
versioned Markdown comment through the existing note undo/save/history path.
Reopening restores settings. Changed notes, owners, Vaults, read-only state and
composition refuse stale saves. Missing or duplicate content keys never silently
receive another block's layout; unmatched settings remain recoverable and produce
warnings. Unknown fields remain preserved. Source exposes the record; Rich/Read
hide recognized leading metadata. Publishing still previews a captured source
snapshot, not an editable Word page surface. All three formats share the same
style/layout options; identical pagination across different renderers is not claimed.
Saving preserves the current Source/Rich writing selection; the metadata change
is one existing undo operation. Frontmatter remains omitted from exports even
when the saved print-settings line precedes it.

## Reviewed BibTeX interchange — 2026-10-11

Citation tools import pasted/UTF-8 `.bib` data with source selection and explicit
identifier/DOI conflict policies. Bounded nested/quoted/braced fields, numeric values
and literal concatenation are supported; unresolved macros skip their entry with
warnings. Extra fields and original TeX survive metadata storage and unchanged
export. Edits update mapped fields; source IDs become export keys, with import
normalization warnings. Export uses existing native save/web download adapters.
Cancel, malformed input and stale source reject mutations; a reviewed import is
one normal recoverable note edit. This is not full BibLaTeX, CSL or TeX execution.
See the [implemented format](../architecture/implemented-formats.md).

## Document publishing workspace — 2026-10-11

PORT-05/06/08/09: Publish document in the Markdown toolbar/Writing tools opens
an immutable presentation snapshot. A4/Letter, 24–90 pt margins, 9–18 pt body
text, bundled Lato/Crimson Text typography, heading numbering, author, title page,
Report/Academic/Design brief style presets and Reset style,
running header, contents and page-number controls regenerate an actual PDF
preview. Page break inserts `<!-- orbit:pagebreak -->` through ordinary editor
history; publishing itself does not save or rewrite the source. Settings are
local to the open dialog. Narrow layouts use Pages/Document style tabs.

Offline citation addition: recognized note-owned source records and citation
locators generate a refreshed compact author–year or numbered References section
in the export snapshot. Recognized metadata comments are removed from presentation,
while the source note remains unchanged. Missing/duplicate source warnings remain
visible. Unknown versions stay literal; ambiguous generated bibliography regions
refuse refresh instead of overwriting authored content. Full CSL/APA/MLA and
external metadata lookup are not included.

Export PDF, standalone HTML and editable OOXML Word (.docx) through existing
platform save adapters. Common Markdown prose, formatting, headings, lists,
tables, local image/caption content, equations and linked-section snapshots are
supported. Contents link to headings; Word also has a refreshable contents field,
native footnotes and page fields. PDF/HTML use linked endnotes. Word prose and
tables are editable; equations are rendered PNGs with TeX alternative text.
HTML browser print controls govern running headers/page numbering. Word/HTML
font substitution and pagination can differ from the PDF preview.

Local images are normalized to bounded PNG previews (1600 px maximum dimension),
retaining aspect ratio; animated images use their first frame. Original bytes
remain untouched. No network image/font fetch occurs during publishing. Broken,
external or unsupported images retain labelled fallbacks; invalid equations retain
TeX. Live section references resolve at snapshot creation, with missing/circular
sources retaining their existing fallback. Image-and-text sections use stacked
print layout. Raw HTML/unknown widgets remain literal text without execution.
Frontmatter and supported review metadata are omitted from presentations.

The dialog reports fidelity details before exporting, including missing/duplicate
footnotes, unavailable resources and missing PDF font glyphs. Limits: 2 million
source characters, 100 image/equation resources, 20 MiB input per image, 64 MiB
embedded image data, 100 million source pixels, 4,000 characters per rendered
equation and 500 PDF pages. PDF failure leaves HTML/Word export available when
their generation succeeds. Cancelled/failed saves never modify notes or originals.
This is a presentation export, not a complete workspace backup. No new owning
format, migration, printer driver, account or cloud service was introduced.

Status: planned. Stage: complete export for each implemented content type;
importers grow incrementally from M1/M2.
Sources: S01, S02, S04, S07 in the [source map](../product/conversation-extraction.md).
Architecture: [storage/formats](../architecture/storage-formats.md).

## Purpose and workflow

People should be able to bring existing knowledge and take it away again. Import
starts with a preview, preserves source material and reports what could not be
converted. Export produces meaningful files and structure, not a screenshot of a
workspace or a binary blob that only one server can interpret.

## Requirements

| ID | Observable behavior |
|---|---|
| PORT-01 | Import previews source, destination, supported objects/files, duplicates/collisions and known fidelity limits before committing changes. |
| PORT-02 | Markdown folder/Obsidian-style imports preserve text, attachments, recognizable frontmatter/links and unresolved extensions with an explicit reconciliation report. |
| PORT-03 | Later import adapters cover available Notion, OneNote, Evernote ENEX, Joplin, Logseq, Apple Notes and Google Keep exports, plus CSV, HTML and plain text where feasible. |
| PORT-04 | A complete workspace export includes all implemented user-content types, originals, references, schemas, views and portable metadata needed for faithful restoration. |
| PORT-05 | Convenient document/view exports include appropriate Markdown, JSON, CSV, HTML, PDF and later DOCX; drawings offer editable data plus SVG/PNG/PDF derivatives. |
| PORT-06 | Validate references, identity collisions, version compatibility and path safety; report unsupported pieces and preserve originals rather than silently discard them. |
| PORT-07 | Restore into a fresh workspace can reconstruct objects/relations and rebuild local indexes from durable files, independently of an Orbit Note cloud account. |
| PORT-08 | Exports exclude credentials, tokens and device-specific secrets; optional history inclusion and large attachment choices are visible, not hidden omissions. |
| PORT-09 | Interrupted imports/exports are recoverable and do not replace the only original with a partial result; cleanup removes only operation-owned temporary data. |
| PORT-10 | Open an existing Markdown vault/folder without destructive adoption; later Bridge Mode reconciles externally edited content with explicit writer ownership, watcher-loop suppression and collision/conflict behavior. |
| PORT-11 | External object references/connectors can link Google Drive, GitHub, Zotero or other resources through scoped adapters; an external reference remains distinguishable from locally owned bytes or a Canvas portal. |

## Fidelity contract

Define three outcomes for every importer: **preserved**, **converted with limitations**,
and **retained as original/fallback**. A prose note may preserve its text while a
proprietary widget remains an original attachment with a placeholder. The user must
be able to find that report later. No importer should claim lossless support without
representative fixtures for its declared export variants.

Import into an existing workspace must explicitly resolve duplicate IDs, title/path
collisions and reference remapping. Case-insensitive filenames matter on Windows.
User-selected copies of the same source are not always accidental duplicates.
Untrusted archive paths and symlink targets cannot escape the chosen workspace.

## Portable workspace versus presentation export

A CSV table export is useful tabular data but cannot preserve a complete knowledge
graph, editable ink, view definitions and arbitrary attachments. A PDF is a useful
rendered document, not an editable workspace backup. The UI should name these as
different export purposes and make complete-workspace export discoverable.

Checkpoint pending changes before a complete export. Include a versioned manifest,
reference inventory and validation outcome as the implementation matures. Preserve
unknown plugin data and explain when it can only be opened as a fallback. No export
should require installing the absent plugin merely to retrieve its original data.

## Acceptance scenarios

- PORT-02/06: import a Markdown fixture containing equal titles, renamed targets,
  unknown frontmatter and unsupported embeds; inspect the preserved originals/report.
- PORT-04/07: export notes, relations, a board and drawing, restore into a fresh
  workspace, rebuild SQLite and verify supported IDs/content/references/geometry.
- PORT-08/09: interrupt export while writing a large attachment; retain the original
  workspace and do not label the partial output complete or include secrets.

## Delivery

Every new owning format needs its own round-trip/export coverage. Begin with
Markdown and the minimal workspace manifest. Imported proprietary formats and
advanced render exports require dedicated tasks with supported fixture versions.
