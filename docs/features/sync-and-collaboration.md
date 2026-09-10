# Optional sync and future collaboration

Status: sync planned M6; shared/concurrent collaboration exploratory after M6.
Sources: S02, S03, S04 in the [source map](../product/conversation-extraction.md).
Architecture: [local-first/sync](../architecture/local-first-sync.md).

## Purpose and workflow

Orbit Note works locally first. A user can later enable sync, choose a supported
hosted or self-hosted endpoint and use the same knowledge across devices. When
offline edits conflict, the app preserves them and explains the choice. Shared
workspaces are a later extension with actual membership/permissions.

## Requirements

| ID | Observable behavior |
|---|---|
| SYNC-01 | Local creation, editing, reading, search and export require no account/network; enabling/disabling sync does not change object identity or remove local knowledge. |
| SYNC-02 | Setup makes the workspace, endpoint, account and upload/download scope visible; hosted/self-hosted adapters use the same domain and serialization contracts. |
| SYNC-03 | Status distinguishes saved locally, pending sync, transferring, synced, conflict and error; server failure does not relabel a successful local save as lost. |
| SYNC-04 | Durable retries and duplicate delivery handling do not create extra objects or lose acknowledged operations. |
| SYNC-05 | Concurrent edits preserve divergent content and offer compare/merge/recovery; text/ink are not silently discarded by timestamp-only last-write-wins. |
| SYNC-06 | Tombstones and edit-versus-delete handling stop stale offline replicas from silently resurrecting deleted content; cleanup/rejoin policy is explicit. |
| SYNC-07 | Attachments transfer separately with integrity checks, resumable behavior where supported and clear missing/pending states. |
| SYNC-08 | Users can disconnect or change providers through an intentional export/reconciliation flow that preserves local content and explains remote retention. |
| SYNC-09 | Later shared workspaces have server-enforced membership/roles; the chat's Owner/Admin/Editor/Commenter/Viewer roles are candidate roles, not a shipped permission matrix. |
| SYNC-10 | Presence, shared boards/comments and simultaneous text/ink editing require separate collaboration semantics; presence alone is not proof changes are durably saved. |
| SYNC-11 | Orbit Cloud/self-hosted Orbit are deployment choices over the existing Sync Engine/provider boundary. Optional Google sign-in is identity, not required storage; Drive/WebDAV providers are later evaluated adapters. |
| SYNC-12 | Non-conflicting property changes may merge automatically only with a known shared base and tested field/schema rules; actual conflicts still require explicit resolution and recovery. |
| SYNC-13 | Lazy attachment sync and Make Available Offline expose which bytes are local, pin required content and do not evict pending/sole copies; device management and transfer states are visible. |
| SYNC-14 | Sharing a note, Canvas, calendar, collection, project or Space requires an explicit underlying permission scope, reference visibility rules and server enforcement; per-object grants are a later design gate. |
| SYNC-15 | Team collaboration can include mentions, comments/resolved threads, shared resources, assignee inbox/assigned-to-me and changes requiring review; it is not a general-purpose chat replacement. |
| SYNC-16 | Protocol version negotiation, incompatible-client handling and future E2EE/key lifecycle planning precede claims of secure encrypted collaboration. |

## Product details

Supabase is the intended first provider candidate, including self-hosting, but
its client API/change notifications are not the complete sync protocol. Settings
must not present a working sync switch until durable local state and the conflict
path exist. No mandatory sign-in screen precedes local use.

A conflict view should identify object, devices/versions when available, timestamps
as context, and preserved alternatives. “Keep mine,” “Use other” and “Merge” require
understandable results and recovery. A choice made on one device is itself replicated
as a deliberate resolution, not implemented by independently overwriting each replica.

Remote disappearance, expired credentials, quota/storage failure and changed
permissions need distinguishable states. The policy for retained local copies
after shared access revocation is an unresolved product/security decision; do not
promise both guaranteed offline possession and remote erasure without a defined model.
Personal Spaces are not role/ownership boundaries.

## Platform limitations

Mobile background execution can be interrupted. Browser storage/permissions differ
from a desktop folder and may not guarantee the same durability/eviction behavior.
These limitations must be visible where they affect a user choice, and supported
export/backup stays available. Do not assume a cloud-drive folder with an open
SQLite database is a safe replacement for the replication protocol.

## Acceptance scenarios

- SYNC-01/03: edit with network disabled, restart and read the saved note; reconnect
  after an authentication error without losing the local version.
- SYNC-04–06: simulate reordered/duplicate operations, two offline edits, and
  delete-versus-edit; preserve data and converge only through defined resolution.
- SYNC-07: interrupt an attachment upload/download, then resume and verify checksum
  before displaying it as complete.
- SYNC-09/10: reject unauthorized remote mutations server-side; do not treat a
  hidden UI button as access control or a presence event as saved text.

## Delivery

Prepare stable IDs and durable local behavior incrementally; add no auth/outbox
framework in M0. M6 requires a protocol ADR and multi-replica tests before UI promises.
Real-time collaborative editing, encryption/key sharing and role policy need
separate decisions and testable slices.
