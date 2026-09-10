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
