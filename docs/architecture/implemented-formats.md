# Implemented open formats — v1 subset

This describes current code, while [storage and formats](storage-formats.md)
describes the broader target. Authority: `ObjectCodec`, `UniversalObject` and
`WorkspaceRepository`; preserve unknown fields when evolving these formats.

| Path | Current representation |
|---|---|
| `workspace.json` | JSON `format: orbit-note-workspace`, integer `version: 1`, UUID `id`, `name`, UTC `createdAt` |
| `Notes/<optional folders>/<title>-<uuid>.md` | UTF-8 Markdown, YAML frontmatter with `orbit` object envelope and `properties`; filename is not identity and stays stable on title rename; explicit folder moves change its path |
| `Objects/<uuid>.object.json` | `format: orbit-note-object`, `version: 1`, `object` envelope, `body`, `data` |
| `Boards/<uuid>.board.json` | Same envelope with `format: orbit-note-board`; `data` has `schemaVersion: 1` and `elements` |
| `Attachments/<checksum>/<name>` | Ordinary original bytes; an `orbit.file` object carries `contentRef`, MIME type, byte length and checksum |
| `.orbit/device/settings.json` | Versioned device layout/preferences; excluded from content export |
| `.orbit/history/`, `.orbit/recovery/` | Retained previous bytes and native interrupted/conflicted write recovery records |

Object envelopes carry stable `id`, `typeId`, `schemaVersion`, `title`, timestamps,
revision, properties and optional deletion timestamp. Workspace membership comes
from the manifest on decode. JSON formats also carry an outer version. Unsupported
versions are read-only. Markdown without an Orbit identity is preserved and reported
for future import/adoption; it is not silently rewritten into an Orbit object.

Canvas elements contain UUID `id`, `type`, world coordinates and dimensions plus
type-specific properties. Cards use `objectId`; images use `contentRef`; ink retains
vector samples. Unknown scene fields/elements survive round-trip. Scene camera and
per-pane reading positions are device state, not duplicated object content.

A backup has `format: orbit-note-backup`, `version: 1`, `workspaceId`, `createdAt`,
`encoding: base64`, a `files` map from safe relative paths to encoded bytes, and
optional `directories` for empty Notes folders (see [ADR-0010](../adr/0010-notes-folder-moves.md)).
It includes implemented canonical files and retained recovery/history, not the
rebuildable index or device preferences. Desktop import into a new folder is implemented; see [ADR-0008](../adr/0008-backup-import-and-workspaces.md) for limits and journal quarantine.
Round-trip import tests verify canonical bytes; do not equate these with hardware power-loss validation.

Saved query views, explicit relation files, custom type definitions, portable
Space/layout presets and standalone annotation consumers remain planned formats.

## Schema references

[Workspace](../schemas/workspace-v1.schema.json),
[object envelope](../schemas/object-envelope-v1.schema.json),
[structured document](../schemas/structured-document-v1.schema.json),
[Canvas data](../schemas/canvas-data-v1.schema.json), and
[backup](../schemas/backup-v1.schema.json) document emitted v1 shapes. They are
interchange documentation, not a runtime schema-validation dependency. Code also
validates type-specific values and safe paths. These broad schemas deliberately
permit unknown fields; future import must validate paths, total size and references
in addition to JSON shape. Round-trip and compatibility fixtures live in the
storage/domain tests. Recognition of a drawing envelope does not mean a standalone
drawing UI has shipped.

Device note views include per-pane mode, selection and preview position, plus
folder collapse paths and note sorting. Renaming adds a readable alias. Authored
wiki links stay exact during autosave; `properties.orbitLinkBindings` maps readable
targets to stable IDs. Explicit ID syntax remains supported. These are additive
v1 fields; unknown fields remain preserved. See [ADR-0009](../adr/0009-audit-and-incremental-local-state.md)
for current mixed-backup, native event and completed-history retention contracts.

Rich editing adds no canonical format or migration. Device note views accept
`mode: rich` (legacy `write` still means Source), `splitRatio` clamped to 0.2–0.8,
and nested `rich` block/base/caret/scroll restoration state. These are disposable local
view preferences. Equations use portable dollar-delimited TeX in the Markdown body.
Visual table commands rewrite only the edited table; unknown constructs elsewhere
remain exact. See [ADR-0011](../adr/0011-source-preserving-rich-markdown.md).

## Calendar events

Events use `typeId: orbit.event` in `Objects/<uuid>.object.json`; there is no
separate calendar database or duplicate event content. Existing envelope version 1
is retained. Calendar projects these objects and task `dueDate` / `scheduledDate`
properties; deadlines and scheduled work stay distinct.

Event `properties` contain either:

- `allDay: true`, `startDate: YYYY-MM-DD`, `endDate: YYYY-MM-DD` (exclusive).
- `allDay: false`, `startAt` and `endAt`: UTC ISO timestamps ending in `Z`, with
  seconds and optional fractional seconds. The end must be after the start.

`contextId` optionally references a Universal Object UUID. Unknown properties and
unavailable context IDs survive event form edits. The device's local time zone is
used for timed input/display, never for interpreting all-day dates as instants.
Unchanged timed fields preserve their original sub-minute precision. Nonexistent
local clock times are rejected; new ambiguous fall-back times follow the platform
choice. Explicit IANA time-zone selection, recurrence and external providers are
not implemented. Invalid imported schedules remain intact and available outside
the date projection; the form does not silently initialize them to today.

The controller submits complete create/save operations through the existing
repository, checks the original revision after flushing pending edits, and keeps
the form open on failure. No new storage schema or migration is introduced.

## Derived search index

Native SQLite index schema 3 adds an FTS5 trigram external-content table and transactional triggers. It remains rebuildable from authoritative files; see [ADR-0012](../adr/0012-fts5-derived-search.md). Object/Markdown/Canvas envelope versions are unchanged.

## PDF reading and research links

Original PDF bytes stay in ordinary Attachments files, referenced by `orbit.file`.
`properties.pdfBookmarks` is a list of positive one-based page integers; editing
bookmarks preserves all other properties. `[[uuid#page=N|label]]` resolves the
same object for backlinks/graph and opens page N in Rich/Read. Renaming the file
object does not change the target. Viewer page navigation clamps to actual bounds.
The session's `noteViews['pdf:<pane>:<uuid>']` stores `page` and `zoom` only.

Extracted quotes are ordinary notes with quoted Markdown, a page wiki reference
and `properties.pdfSource: {objectId, page, checksum}`. Source bytes remain exact;
the checksum records provenance but this batch does not implement automatic
revision re-anchoring. See [ADR-0013](../adr/0013-local-pdf-reader.md).

## Canvas columns and website cards

Schema 1 gains `column` and `link` element types using existing IDs/geometry/style.
A column has a `text` heading; direct child placements hold `columnId`. Geometry
remains world coordinates. Columns do not contain copied Universal Object content.
Dragging the header moves children; dropping an item inside arranges members by
vertical position. Columns cannot nest. Locked children block parent moves and
automatic arrangement. Removing a column clears child membership and retains the
items; cutting a column cuts its placements together. Undo restores the whole command.
Copy/paste remaps placement and column IDs while preserving object IDs. Cross-Vault
object remapping is still unsupported. New types remain opaque in older readers.

A `link` element stores `text` and `url`. Creation accepts only HTTP/HTTPS URLs;
opening requires an explicit gesture. No remote preview fetching or embedded scripts.
Links are board-local bookmarks, not new Universal Objects or semantic relations.

## PDF highlight notes — 2026-09-11

An ordinary orbit.note with properties.pdfHighlightVersion: 1 contains a Markdown
quote, stable page reference and optional editable comment. Its properties.pdfSource
has objectId, checksum, page, quote, and regions. Each region uses existing Canvas
rectangle fields id, type: rectangle, x, y, width, height, color plus one-based page.
Geometry is normalized to the displayed page, top-left origin. Bounds must be finite
and inside [0,1]. Creation limits are 10,000 regions and 100,000 selected characters.

Only matching-checksum regions are painted; stale versions retain all metadata and
show source-review status. Unknown versions remain readable ordinary notes.
Deleting/restoring a highlight uses ordinary note Trash/restore. No PDF writes,
object-envelope migration or SQLite schema change. See ADR-0014.

Source-file preview is disposable: extension mapping, strict UTF-8, 1 MiB limit,
binary/invalid-encoding fallback, existing syntax renderer (plain text above 50,000
characters). Copy Code retains decoded source and original line endings. No code
execution, compiler or executable web preview is invoked.
