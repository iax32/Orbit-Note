# Architecture decisions

- [0017 — Local sync safety foundation](0017-sync-foundation-safety.md): accepted
  native ownership, deletion recovery, exact-byte reconciliation and device state;
  does not claim a complete cloud provider.

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
- [0016 — Provider-neutral sync](0016-provider-neutral-sync.md): proposed protocol, Google Drive/WebDAV priority, audit and production release gates.
- [0018 — Recoverable folder commands](0018-recoverable-folder-commands.md): accepted native mixed-object command capability, staged recovery and safe refusal by unsupported adapters.
- [0019 — Google account adapters](0019-google-account-adapters.md): native account authorization, secure sessions, quota semantics and explicit transfer safety gate.
- [0020 — Precise-reference composition](0020-precise-reference-composition.md): lazy prose anchors, typed targets, shared search projection and compatible preference ownership.
- [0021 — Checksum-bound PDF search](0021-checksum-bound-pdf-search.md): disposable page text, verified source navigation, complete candidates and pagination after filtering.
- [0022 — Smart Views, Spaces and task planning](0022-smart-views-spaces-and-task-planning.md): shared validated queries, device-local contexts/dashboard descriptors and recoverable same-identity planning commands.
- [0023 — Local OCR evidence](0023-local-ocr-evidence.md): Windows background recognition, portable corrections and verified source/page search.
- [0024 — Portable study cards](0024-portable-study-cards.md): same-identity Markdown cards, deterministic offline scheduling, source snapshots and durable review history.
- [0025 — Rolling event occurrences](0025-rolling-event-occurrences.md): same-identity events, explicit history and device-clock recurrence policy.
- [0026 — Calendar occurrence projection](0026-calendar-occurrence-projection.md): stable occurrence keys, bounded future schedules and recoverable individual overrides.
- [0027 — Shared Vault preview and Drive backups](0027-shared-vault-preview-and-drive-backups.md): self-hosted capability grants, conservative live merges, ordinary local history, independent Drive backups and explicit activation gates.
- [0028 — Scoped code workspace](0028-scoped-code-workspace.md): native UTF-8 authority, independent recovery, guarded saves, explicit local tooling and validated LSP proposals.
- [0029 — Code launch and loopback preview](0029-code-launch-and-loopback-preview.md): recoverable project command profiles, ordered cancellation, scoped HTTP assets and ephemeral preview lifecycle.
- [0030 — Immutable personal Drive revisions](0030-immutable-drive-revisions.md): append-only branch preservation, durable upload IDs/sessions, explicit conflict resolution and opt-in native foreground coordination.
- [0031 — Device sync continuity](0031-device-sync-continuity.md): opt-in inactive-Vault scheduling, secure explicit shared reconnect, authority handover and standalone server readiness.
- [0032 — Live shared Vault replication](0032-live-shared-vault-replication.md): negotiated lifecycle/blob replication, durable device outbox, authenticated wakeups and source-checked note awareness.
- [0033 — Background Drive and payload retention](0033-background-drive-and-payload-retention.md): explicit OS scheduling over existing locks/outbox, silent account-bound authorization and reviewed payload expiration with immutable receipts; graph metadata retained.
- [0034 — Derived routing workers](0034-derived-routing-workers.md): exact source-bound publication of local canonical geometry, single-worker/latest-request scheduling and guarded loading without authored state changes.
- [0035 — Portable Vault preferences](0035-portable-vault-preferences.md): allowlisted, independently merged device-writer records over existing durable objects and Drive/live replication, with local outbox recovery.
