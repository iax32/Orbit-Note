# ADR-0004 — Markdown and documented open formats

- Status: accepted
- Date: 2026-09-07
- Scope: content ownership, portability and persistence
- Supersedes: none

## Context

The conversation explored SQLite-centric examples, then explicitly chose
Markdown-first files, ordinary attachments and open structures to avoid lock-in.
Rich spatial/ink content cannot be represented faithfully as plain Markdown alone.

## Decision

Use Markdown/YAML frontmatter for text-backed objects, original attachment bytes,
and documented versioned JSON for structured-only objects, canvas, ink, views and
relations. Each object has one owning file/envelope. SQLite accelerates access.
At a settled checkpoint, portable files are authoritative and indexes rebuildable.

Start with durable atomic single-file saves followed by index updates. Introduce
multi-file journals only when required. Before relying on SQLite between large
canvas checkpoints, require a durable open recovery log outside the database;
the detailed protocol must be approved in a follow-up ADR and fault-tested.
Never label transient in-memory edits saved or discard uncheckpointed knowledge
as if it were an index. See the [save contract](../architecture/storage-formats.md).

## Alternatives

Database-only content complicates ordinary file ownership; Markdown-only encoding
loses rich data; proprietary rich-document blobs undermine independent tooling.
Independent “file truth” and “SQL truth” would create conflicts inside one device.

## Consequences

Need versioned schemas, faithful round-trip handling, safe paths, external-edit
reconciliation, export/restore tests and migration recovery. Open JSON may be
app-specific but must be documented; it is not promised to be another app's format.

## Validation / follow-up

M1 freezes the minimal note/manifest subset and tests crash boundaries, index
rebuild and edits from another editor. Each richer type ships its own schema,
fixtures and complete export. Exact Markdown embed syntax is still deferred.
