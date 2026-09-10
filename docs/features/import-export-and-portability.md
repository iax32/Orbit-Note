# Import, export and portability

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
