# Storage and open file formats

Status: accepted hybrid authority model ([ADR-0004](../adr/0004-markdown-open-formats.md));
broader examples remain targets. The [implemented v1 subset](implemented-formats.md) records current paths and recovery limitations.
This document describes user workspaces, not this source repository's folders.

## Workspace layout

```text
workspace.json                    # manifest: format, version, ID, name
Notes/<readable-name>.md           # text-backed objects + YAML frontmatter
Objects/<id>.object.json           # structured-only objects
Attachments/<id>/<original-name>   # original bytes
Boards/<id>.board.json             # canvas object envelope + elements
Drawings/<id>.drawing.json         # drawing envelope + vector ink
Views/<id>.view.json               # saved query/presentation, no object copies
Relations/<id>.relation.json       # explicit semantic relations
Types/<type-id>.type.json          # custom schema definitions, when supported
.orbit/settings.json              # portable non-secret workspace preferences
.orbit/layouts.json               # named layout presets
.orbit/tombstones/                 # durable logical deletion records
.orbit/history/                    # versioned recovery/history data when introduced
.orbit/recovery/                   # durable multi-file command journals when introduced
.orbit/workspace.sqlite            # derived indexes + operational state
.orbit/cache/                      # disposable previews/thumbnails
.orbit/device/                     # device-specific state, excluded from content sync
```

Folder casing above is canonical. Restrict portable filenames and detect
case-insensitive collisions on import. Display titles may contain characters that
filenames cannot. All content references are workspace-relative, normalized paths;
reject traversal, absolute paths, and escaping symlink targets on writes/import.

## Authority contract

| Data | Durable owner | SQLite role |
|---|---|---|
| Text + object properties | Owning Markdown/frontmatter or specialized JSON file | Parsed object/query index |
| Canvas geometry / ink / explicit relations / views | Owning versioned JSON | Fast queries and working state |
| Attachments | Original bytes | Metadata/checksum index |
| Search/backlinks/thumbnails | Derived from durable sources | Rebuildable cache |
| Preferences/history/tombstones | Documented `.orbit` files | Operational indexes |
| Later sync cursors/retries/device flags | Local operational state | May require reconnect/reconciliation if lost |

Deleting SQLite must not delete the sole copy of user knowledge. Rebuild from
portable files and any committed recovery journals, not SQLite backups alone.
This does not mean deleting SQLite is a normal recovery command while the app is
running. Derived indexes are disposable; pending work and history are not assumed
disposable merely because they are stored near a cache.

## First persistence implementation (M1)

For a single note, validate → write a same-directory temporary file → flush →
atomically replace the owning file → update the SQLite index. Report “Saved locally”
after the durable file operation, independent of whether the index needs rebuilding.
Persist expected content hashes to detect external edits before replacement; if
the source changed, preserve both versions and surface a conflict. On database
failure, mark/rebuild the index from the file. Test crash boundaries and disk-full.

Atomic replacement semantics differ by platform: the adapter must verify actual
behavior and preserve the original on failure. Do not claim that a SQL transaction
also atomically commits filesystem changes. File watchers are hints; reconcile
changes by IDs and hashes, including startup rescan and watcher feedback suppression.

For a command spanning files, introduce a versioned durable journal containing
command ID, preconditions, before/after content references and commit status.
Stage and flush data before recording commitment; replay committed incomplete
operations idempotently on startup. Keep recovery data until files and indexes
are checkpointed. Design and fault-test that protocol before shipping multi-file
mutation; do not implement a speculative journal in M0.

## Large canvas persistence

Use incremental local updates and batch completed gestures rather than rewrite a
large board per pointer sample. Small-board JSON checkpointing is acceptable first.
Before large boards rely on SQLite between checkpoints, add a durable open recovery
log outside the database so accepted edits survive index loss. The exact journal,
chunking, compaction, and save-state semantics require a follow-up ADR and crash tests.
Keep a complete documented JSON export regardless of internal acceleration.

## Draft wire shapes

Manifest:

```json
{"format":"orbit-note-workspace","version":1,"id":"11111111-1111-4111-8111-111111111111","name":"My Knowledge","createdAt":"2026-09-07T12:00:00Z"}
```

Markdown owner (the ID remains stable across renames):

```markdown
---
orbit:
  id: 22222222-2222-4222-8222-222222222222
  typeId: orbit.note
  schemaVersion: 1
  title: Architecture
  createdAt: 2026-09-07T12:00:00Z
  updatedAt: 2026-09-07T12:00:00Z
  revision: 1
  deletedAt: null
properties:
  tags: [design]
---
# Architecture

Ordinary readable Markdown. See [[Related note]].
```

The workspace manifest supplies `workspaceId`; SQL repeats it for indexing.
The title in the envelope owns the object title; a Markdown heading is body text
and need not match. A plain Markdown import without frontmatter remains readable;
assign identity through an explicit, recoverable import/adoption step. Preserve
unrecognized frontmatter and Markdown rather than reserialize away user formatting.

Structured formats use a top-level `format`, `version`, common `object` envelope
(`id`, `typeId`, `schemaVersion`, `title`, timestamps, revision, deletion, properties)
and format-specific `data`. A board's `data` contains `preset`, `elements`, and
`connectors`; elements reference IDs. Drawings contain vector samples (x/y, elapsed
time, optional pressure/tilt), style, and bounds. A view definition uses `id`,
`kind`, `scope`, and `configuration` rather than copying content envelopes.

JSON schemas and round-trip fixtures must accompany each implemented format.
Use UTF-8, stable ordering where practical, explicit schema versions, safe YAML
parsing, and finite numeric geometry. Retain unknown fields. Open newer unsupported
versions read-only with a clear reason; never downgrade or overwrite them silently.

## Compatibility and export

Baseline text is standard Markdown; wiki links/frontmatter are documented extensions.
Rich embeds must have readable fallback references. Do not invent a full new Markdown
dialect or promise lossless rich-block conversion before choosing/testing the editor.

Attach arbitrary file types without executing them. Planned preview formats include
text/code, images/SVG, PDF, audio/video, CSV/JSON/YAML, and sanitized HTML. Office files
can initially open externally; native editing is not implied. Preserve original
attachments and annotation sidecars; SVG/PNG/PDF exports complement editable ink.

A complete workspace export includes manifest, owning files, attachments, relations,
types, drawings, views, portable settings, and available history/tombstones. Exclude
credentials, device state and regenerable cache. Checkpoint pending changes before
export and validate reference completeness. CSV is a convenient view export, not a
lossless replacement for the whole workspace. Restore/migration must preserve a
pre-migration backup and recover from interruption.

The [compatibility contract](compatibility-and-migrations.md) adds explicit version,
migration, backup and old-fixture requirements. File-first authority is unchanged;
multi-file transactions and incremental Canvas journals still require design proof.
