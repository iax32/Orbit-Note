# Optional sync and collaboration

## Live shared delivery — 2026-10-22

New rooms created with the updated app/host negotiate live owning-object creation,
Trash/restore, permanent tombstones and verified resumable attachments. Authenticated
change waits wake clients, with bounded local scheduling and a heartbeat fallback.
Acknowledged bases and uncertain edit/create operations survive client restart in
device-only guarded journals. Independent text edits merge; overlaps require review.
Rich/Source note selections and named carets are checked against source hashes;
stale positions show navigation/status rather than inaccurate highlights. Canvas
pointer changes wake promptly. Optional secure reconnect runs on launch/resume.

Existing rooms retain legacy behavior until a new shared snapshot is created.
Live rooms refuse unaware clients. Deploy the matching host/client and preserve
the whole private server directory before upgrade; new journal kinds require the
updated server. Authored storage and universal IDs are unchanged. See
[ADR-0032](../adr/0032-live-shared-vault-replication.md) and
[validation/limits](../tasks/live-shared-sync-2026-10-22.md).

No closed-app/mobile worker or arbitrary-overlap CRDT is provided. Physical
Windows-to-Android, deployed HTTPS and mobile runtime acceptance remain outstanding.
Personal Drive and shared editing remain mutually exclusive per Vault. The dated
sections below record earlier delivery boundaries, not the current live scope.

## Current delivery — 2026-10-22

Personal native Drive sync now uses validated incremental change tracking and
five-second active-Vault checks, retaining durable outbox, immutable branches,
resumable uploads, explicit conflict review and tombstones. Continuous typing no
longer delays an already scheduled local sync. Full local/cloud audits remain;
Settings distinguishes last cloud check from completed full synchronization.
See [cloud delivery status](cloud-sync.md) for scope, limits and validation.

At the earlier Drive-only milestone, shared sessions were a separate existing-document/Canvas preview over 500-ms
HTTP polling, with named pointers, placement selections, known-base merges and
roles. This task does not add shared new-object/deletion/attachment streaming,
character-level CRDT/carets, OS background execution, public OAuth verification
or physical-device acceptance. Personal Drive and shared editing remain mutually
exclusive for a Vault. OneNote-level parity is **not verified or claimed**.

## Host restart and foreground recovery — 2026-10-21

Shared sessions read server state before publishing local proposals. Protocol 1
has an optional ephemeral server `epoch`; a changed epoch returns full state even
when the old delta cursor is ahead of a restored journal. Different or absent
shared documents require review, retaining local work and recovery history.
Unchanged documents resume. Uncertain acknowledgements are not blindly replayed
across a host incarnation change. Reused/rolled-back document versions also stop
for review. Server identity/protocol changes pause automatic requests.

Foreground checks retain access blocks; a check requested during a poll is
coalesced. The current server role is applied before sending edits. Shared
settings add explicit checking, host/access/acknowledgement details and a host →
HTTPS → invitation guide with validated proxy snippets. Update the standalone
server alongside the client for epoch/cursor recovery. Old protocol-1 fields and
authored storage remain compatible. Live shared new-object/attachment/deletion
streaming and physical two-device/TLS acceptance remain outstanding.
[Evidence and limits](../tasks/device-sync-recovery-2026-10-21.md).


## Shared Canvas placement review — 2026-10-20

In Shared Vault settings, a Canvas conflict with a known session base offers
**Review overlapping Canvas items**. The comparison shows local/shared placement
alternatives and the common base, including edit-versus-removal. Each overlapping
placement needs an explicit choice; genuinely competing stacking orders have a
separate choice. Independent placements/fields continue to merge automatically.
Choosing a whole placement retains that alternative's unknown fields and stable
ID. Removing a placement never deletes the referenced knowledge object.

Comparison snapshots are immutable. Local content, workspace/session identity,
permissions and the latest fetched server version are rechecked before applying.
A stale comparison must be reloaded. Normal repository saves retain the complete
before-image; a failed save keeps the conflict and does not publish the draft.
After saving locally, the normal idempotent known-base protocol publishes the
resolution. Later overlapping server edits still conflict, including edits that
arrive while local saving is in progress; this is not a force overwrite. Lost
acknowledgements use the existing operation replay boundary.

An unknown common base after reconnect, unsupported metadata conflicts and
non-placement document conflicts retain the existing recovery/adopt-server flow.
The app does not invent an ancestor or promise a persistent CRDT review session.
No protocol or durable format migration is required for this review UI.
[Implementation and validation](../tasks/canvas-review-templates-2026-10-20.md).

## Canvas awareness and session reliability — 2026-10-20

Shared Canvas pointers can include up to 64 selected placement IDs. Matching
world-coordinate outlines show who is working on visible items; this is awareness,
not a lock or a durable edit. Names remain grant-bound. The server validates
session ownership and bounded input, filters missing IDs and caches placement
membership by snapshot with a bounded cache. Optional `active: false` removes a
member's own presence when leaving a Canvas. A new connection uses a new ephemeral
session ID, avoiding a denial when a previous room still retains its old presence.

Presence updates repaint a separate overlay rather than rebuilding Canvas
controls/gestures. Unchanged positions with only a newer heartbeat do not repaint;
hidden/missing/offscreen selections and malformed coordinates are excluded. Label
truncation preserves Unicode scalar boundaries. These fields are not serialized
to Canvas documents or the server edit journal.

Three-way Canvas merges validate placement identities even for one-sided changes.
Compatible reorders compare surviving common IDs, so independent deletions do not
cause a false order conflict. Different surviving orders and edit/delete races
still require review. Membership/order checks use sets for large boards.

Update the app and standalone server for these additions. Protocol 1, existing
presence payloads and durable formats remain compatible. Older servers ignore
selected IDs and may keep a departed pointer until the existing 15-second expiry.
Disconnect/network loss still uses expiry; clear-on-leave is best effort. This
does not add CRDT editing, live new-object/attachment streaming or physical-device
acceptance. [Actual checks and limits](../tasks/canvas-split-quality-2026-10-20.md).

2026-10-15 continuity extension: completed bulk Drive transfers can opt into
scheduled inactive-Vault checks while Orbit is open, with account binding,
native locks, individual pause preservation, visible results and pause/retry.
Shared connection setup suspends personal Drive work. Shared settings add an
authenticated server test and explicit secure-device Remember/Reconnect/Forget
controls; no owner key is remembered and no automatic room join occurs.
The Windows release includes a standalone server launcher; its private directory
must remain outside every Vault. Health/readiness do not replace TLS deployment
or physical-device acceptance. See [ADR-0031](../adr/0031-device-sync-continuity.md)
and [host setup](../development/shared-vault-setup.md).

2026-10-15 personal sync preview: native opt-in Drive synchronization now composes
the existing engine, durable outbox/common bases and repository staging/history.
An append-only revision provider retains concurrent branches; compare/review
appends a resolution instead of silently choosing timestamps. The account/Vault
binding, pause, interrupted-session retry and conflict choices survive local
restarts. New objects, attachments and explicit tombstones participate in personal
sync. This is independent of the existing shared-session preview (whose live new
object/attachment protocol is still unfinished). Details and platform/release
limits are in [cloud status](cloud-sync.md) and
[ADR-0030](../adr/0030-immutable-drive-revisions.md).

2026-10-15 reliability update: existing-document sessions back off after network
failures (1/2/4/8/16/30 seconds), expose Retry now and pending-document counts, and
pause automatic requests after denied/revoked access. Local saving remains
independent. Uncertain edit acknowledgements retain their operation ID for replay;
newer local edits remain separate proposals. A pending local save is not reported
as acknowledged. Disconnect, a later connection attempt or a different Vault
opening invalidates late replies. Invitations remain private session capabilities;
there is no persistent auto-rejoin or new object/attachment streaming protocol.
Manual Drive backups now add scoped browsing and bounded transfer recovery; see
[cloud status](cloud-sync.md). These improvements do not complete personal sync or
replace real two-device/TLS acceptance.

2026-10-11 authorized preview: self-hosted whole-Vault snapshot sharing with live
editing of existing notes/Canvas boards, server-enforced capability roles,
ephemeral named pointers, known-base merges and explicit conflict recovery.
Manual Drive backup/restore is a separate provider workflow, pending OAuth activation.
Limits and actual delivery evidence: [setup](../development/shared-vault-setup.md),
[ADR 0027](../adr/0027-shared-vault-preview-and-drive-backups.md), and current task.
Presence is not a text selection/caret sync guarantee, a durable save, verified
Google identity or a CRDT. Existing future clauses below still apply.

2026-09-12 owner update: Google Drive is now the primary M6 provider, WebDAV the
second. This supersedes the Supabase-first preference and deferred Drive/WebDAV
ordering in SYNC-11 below, without changing the local-first requirements. See
[audit](../planning/sync-audit-2026-09-12.md) and
[design proposal](../architecture/sync-design.md). Implementation is not delivered.

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

Host-incarnation guards also travel with edit proposals: a restart between the
state check and publication returns a typed conflict before any journal mutation.
Canvas comparisons reject changed hosts before applying choices; existing conflict
bases are invalidated on restart instead of reused across uncertain ancestry.
