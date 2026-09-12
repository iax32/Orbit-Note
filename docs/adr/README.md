# Architecture decisions

Accepted means selected direction, not implemented capability. The user requested
these six initial decisions from the product conversation. Date: 2026-09-07.

| ID | Decision | Status |
|---|---|---|
| [0001](0001-flutter.md) | Flutter, Windows first, retain mobile/web compatibility | Accepted |
| [0002](0002-riverpod.md) | Riverpod for application/UI state and dependency injection | Accepted |
| [0003](0003-drift-sqlite.md) | Drift/SQLite for local indexed/operational state | Accepted |
| [0004](0004-markdown-open-formats.md) | Markdown/open formats with explicit durable authority | Accepted |
| [0005](0005-universal-objects.md) | Stable universal objects, reference-based views | Accepted |
| [0006](0006-spatial-canvas-reuse.md) | Shared spatial/ink engine across canvas consumers | Accepted |

Use [the template](TEMPLATE.md). Number new ADRs sequentially. Record context,
alternatives, consequences, scope, and validation required. For a changed accepted
decision, add a superseding ADR and link both directions; do not erase the reason
for the earlier decision. Routine files, widgets and bug fixes do not need ADRs.

- [0007 — First local core persistence](0007-local-core-storage.md): accepted bounded native implementation and temporary browser adapter.


- [0008 — Backup import and workspace selection](0008-backup-import-and-workspaces.md): accepted restore publication, device selection and external-change boundaries.
- [0009 — Audit and incremental local state](0009-audit-and-incremental-local-state.md): authored source, mixed backups, recovery retention, native events and Canvas deltas; partially supersedes 0008.
- [0010 — Notes folder moves](0010-notes-folder-moves.md): real directories, staged roll-forward move recovery and empty-folder backup extension.
- [0011 — Source-preserving Rich Markdown](0011-source-preserving-rich-markdown.md): transient editable blocks, shared splice history and portable local math/code rendering.
- [0012 — FTS5 derived search](0012-fts5-derived-search.md): trigram substring indexing, literal query handling and rebuildable schema 3.
- [0013 — Local PDF reader](0013-local-pdf-reader.md): repository-owned bytes, local PDFium viewing, portable page references and quote notes.

- [0014 — PDF highlight notes](0014-pdf-highlight-notes.md): source-versioned regions using Canvas rectangles and linkable Markdown notes.
- [0015 — PDF form drafts](0015-pdf-form-drafts.md): source-versioned field drafts, isolated native editing and separate filled copies.
