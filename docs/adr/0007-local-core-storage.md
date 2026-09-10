# ADR-0007 — First local core persistence implementation

Status: Accepted for the current implementation subset. Date: 2026-09-09.
Refines ADR-0003/0004/0006; their ownership and reuse decisions remain unchanged.

Later extensions: [ADR-0009](0009-audit-and-incremental-local-state.md) refines
retention and incremental local work; [ADR-0010](0010-notes-folder-moves.md) adds
a bounded journal protocol for explicit Notes moves. The deferred general-purpose
transaction and Canvas operation-stream discussion below remains historical context.

## Context

Usable Notes and Canvas need durable local saving now. The full roadmap's multi-file
transactions, database-backed Canvas operation stream and browser SQLite runtime
are not implemented. Treating all of them as delivered would hide recovery gaps.

## Decision

Native user files own committed knowledge. Each native write checks the expected
file hash, retains prior bytes, writes and flushes a temporary sibling, records a
versioned recovery journal and replaces the target. Recovery replays only when
before/after hashes agree; conflicts preserve bytes for explicit recovery. The
repository serializes local commands, validates object revisions and rebuilds a
Drift/SQLite query index from canonical files. Index failure must not lose a save.

The initial board saves a versioned JSON scene after a completed gesture; text
drafts are also published while editing. Undo holds bounded scene snapshots in
memory. This is a small-board foundation, not the eventual incremental large-board
storage/performance design. Cards contain object IDs, not copied object content.

On web, a conditional localStorage store and memory index keep compilation and
basic local functionality available. This is an explicitly temporary adapter:
quota/eviction, browser storage clearing and lack of filesystem durability prevent
claiming native parity. Adopt a dedicated browser persistence ADR and tests before
shipping production web support. Native Drift remains the accepted local database.

Backups use a versioned JSON bundle of relative paths and base64 file bytes;
canonical Markdown/JSON/attachments remain directly readable on disk. Export
excludes device/cache data and verifies a stable file snapshot. Import is deferred
until path validation, size limits and failure recovery are implemented together.

## Alternatives and consequences

Database-only content was rejected because open-file ownership is an invariant.
A complete CRDT/multi-file transaction framework was deferred because it does not
serve this bounded first local editing slice. Single-file journaling does not prove
cross-process atomic compare-and-swap or multi-file atomicity. No schema migration
silently rewrites unknown data; unsupported versions are read-only, and unknown
fields are retained by codecs. Native history is retained without automatic GC.

## Validation and follow-up

Repository tests cover reopen, external changes, stale revisions, failed writes,
unknown data, attachment/export bytes, index failure and journal replay. Controller
tests cover concurrent drafts, layout shutdown and failed workspace switching.
Add whole-backup import/reopen tests next. Hardware power-loss, browser eviction,
large-board latency and multi-process editing still require dedicated validation.

See [the implemented file subset](../architecture/implemented-formats.md).

Follow-up: [ADR-0008](0008-backup-import-and-workspaces.md) implements the previously deferred bounded desktop backup import and records its safety contract.
