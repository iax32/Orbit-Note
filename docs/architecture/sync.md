# Sync architecture — implementation contract

2026-10-15 continuity extension: [ADR-0031](../adr/0031-device-sync-continuity.md)
adds an account-bound secure-device schedule for explicitly selected inactive
Vaults. DriveVaultScheduler acquires the same active-controller batch lease,
checks existing per-Vault opt-in before binding, and opens/closes native locked
repositories sequentially. Startup reads local opt-in before account services.
Shared create/connect activity suspends Drive before awaiting network work.
Secure per-Vault room profiles support explicit reconnect only; server roles and
divergence checks remain authoritative. Server readiness diagnostics and the
standalone Windows launcher do not install a background service or configure TLS.

2026-10-15 bulk transfer extension: an explicit DriveVaultBatch coordinates
sequential per-Vault operations through the same binding helper, SyncEngine and
provider. Active-Vault polling is suspended under a guarded controller lease;
its replica retains draft/apply guards. Inactive native repositories acquire
their normal OS locks, use the existing-only identity gate and close after each
job. Downloads bootstrap verified manifests into new folders. No second sync
protocol, authored migration or global background service is introduced. Durable
per-Vault upload/outbox state supports retry; batch UI choices are ephemeral.
Cancellation preserves valid saves and prior opt-ins, while a first connection
enables automatic sync only after a completed reconciliation. Existing graph,
conflict and account/opening guards remain unchanged.

2026-10-15: [ADR-0030](../adr/0030-immutable-drive-revisions.md) adds native personal
Drive synchronization through the existing engine and replica. Atomic mutable
publication remains required for ordinary providers. An explicit
ImmutableRevisionSyncProvider may instead prove append-only branch preservation:
immutable blobs precede immutable records with parent IDs, complete listings expose
all graph heads, and concurrent heads are durable conflicts rather than winners.
The engine preserves each alternative (including when no local object exists)
before checkpointing. Resolution journals an operation/entry/parents intent before
publication and rechecks reviewed local hashes; all prior cloud revisions remain.
The old conditional-publication-only gate below is superseded only for this
explicit contract. Google Drive PATCH is not treated as compare-and-swap.

DriveSyncController owns one active account/folder/Vault opening. Opt-in and upload
plans use separate guarded device state files, never FTS. Normal application
changes schedule coalesced foreground passes; account failures stop automatic
requests, transient failures back off, and manual retry remains available. Startup
reads only local opt-in before creating account services. Switching Vaults,
disconnecting, pausing or joining Shared Vault invalidates provider reads, stages,
applies and acknowledgements through the additional replica opening guard.
Provider uploads read verified native stages in approximately 1 MiB chunks;
per-key publication checks avoid re-reading every object's cloud history for each
upload. Full listings are paginated and immutable record payloads are hash-cached.
Cache/operation checkpoint size remains bounded by the existing 16 MiB store.
See current task for automated and real-account evidence, and remaining physical
device/application acceptance. Empty-folder replication, native non-Notes moves,
revision GC and
public/mobile rollout remain outside this delivered slice.

2026-10-11: [ADR 0027](../adr/0027-shared-vault-preview-and-drive-backups.md) adds
separate self-hosted shared editing and immutable Drive backup transfers. Neither
claims the personal SyncProvider conditional-publication capability described here.

Updated 2026-09-13. **Foundation and native account slice implemented; no end-user
Vault transfers yet.** Account adapters, secure credential storage, quota UI and
root/discovery are described in [ADR 0019](../adr/0019-google-account-adapters.md).
The foundation table below records the earlier transfer-layer state. No second
SyncEngine was added; its conditional-publication requirement remains enforced.
The full owner brief has now been received. Archive keeps content and synchronizes;
offload is deferred. Active, Archive, Orbit Trash, permanent deletion and provider
Trash remain separate. The missing-brief gate in the historical audit is resolved.

## Current code

Concurrent feature work added saved `orbit.view` objects during this milestone;
they use the normal `Objects/*.object.json` owner and are included/tested. It also
added `SessionState.archivedFolders`, currently device-only. Inventory reports a
blocking issue when this contains Archive metadata: migrate it explicitly at sync
setup before claiming cross-device Archive behavior. Content inside those folders
is still included; device settings themselves must never be uploaded wholesale.

| Component | Implemented behavior | Remaining boundary |
|---|---|---|
| Native ownership | OS lock before recovery, release on close/switch, guarded mutation | External programs can still race; no filesystem-wide atomic CAS claim |
| WorkspaceDeletions | Hash-checked, journaled permanent deletion and durable tombstone | User-facing recovery review; no automatic tombstone GC |
| SyncInventory | Real repository inventory, exact hashes, streamed native blobs, empty Notes folders, unsupported-file blockers | File-stat hash cache, background parsing/profile |
| SyncProvider | Provider-neutral delta/inspect/streamed transfer interface, stable IDs, required conditional publication capability | Account/Vault discovery and resumable-session API extensions during Drive work |
| SyncEngine | Common-base comparison, coalesced pending work, per-instance serialization, explicit missing/conflict states, delayed cursor acknowledgement | Not wired to application triggers or Settings |
| WorkspaceSyncReplica | Native stage/verify/apply, repository serialization, generation/draft guards, exact object bytes, Notes move recovery, conflict copies and tombstone apply | Non-Notes physical moves, permanent-delete restore review and conflict UI |
| WorkspaceSyncStateStore | Durable versioned device file, CAS and existing write recovery, excluded from backup/FTS | Whole-state write cost/16 MiB bound; corruption recovery UI |
| Installation identity | Lazy application-support UUID; current platform/app version | Settings naming and auth composition |
| FakeSyncProvider | Three-replica offline/conflict/idempotency conformance tests | Test infrastructure, never a production provider |

The controller's `createSyncReplica()` supplies a live guard for drafts, failed or
in-flight saves, loading and disposal. Use the replica's `createStateStore()` with
its engine: that wrapper serializes checkpoints with repository commands and rejects
late acknowledgements after a Vault switch, even reopening the same UUID.

Incoming streams stage under `.orbit/device/sync/incoming/*.part` outside the command
queue. Hash-verified native publication uses the existing file-save journal/history,
with a last-moment local hash and draft check. Uploads read a verified snapshot, not
a changing source file. Exact Markdown/JSON is decoded/validated but never re-encoded.
Derived objects/index refresh after apply; controller merging retains local drafts.

Attachment recovery uses a separate native stage under
`.orbit/device/recovery/attachments/attachment-<id>.part` with a matching JSON
manifest. The manifest is device-local and records the target, operation,
expected checksum, source name, and saved byte offset. A process interruption
leaves this stage discoverable; the recovery dialog can append the remaining
source stream after the user selects the same file, or explicitly discard it.
Native startup removes only well-formed stages whose durable progress is older
than the 30-day retention window; malformed stages and unsupported newer
workspace formats are preserved. The complete staged hash is verified before
normal guarded publication. These manifests and partial bytes are excluded
from sync and portable export.

Conflict alternatives and a descriptor are kept at `.orbit/sync-conflicts/<digest>/`;
they are recovery data, excluded from sync but retained in portable backups. They do
not create duplicate live object IDs. Remote deletion also retains a before-image.
Its local intent stores `tombstoneSource` so startup preserves the exact remote hash,
including whitespace/unknown optional fields, instead of reserializing the payload.

Current native limits: 32 MiB per structured document, 2 GiB per blob; no resumable
network session or sync-stage cleanup policy yet. Local snapshot/hash work can
occupy the repository queue; network download does not. Same-Vault physical Notes
moves reuse existing recovery. Other owning-format moves reject safely. Replacing
bytes underneath a referenced checksummed attachment rejects: publish a new content
path and then its owning file object, matching the current importer. No automatic
restore over a permanent tombstone. These limits remain explicit before release.

## Authority and inclusion

Markdown/frontmatter and versioned JSON own objects; ordinary attachments own
binary payloads. Native SQLite remains disposable search/index state. Existing
Notes/Objects/Boards/Drawings files are included regardless of Archive/Trash UI
visibility. Tombstones are explicit deletion payloads. Inventory maps a deleted
object's identity/logical old path to its actual tombstone source path.
Manifest stays the same UUID. Empty Notes folders are captured separately;
the engine does not yet transmit that directory metadata.

Exclude `.orbit/device`, FTS/WAL/SHM, cache, history, local recovery, generated temps
and provider-control metadata from authored transfers. Unsupported user files
block a complete-sync claim instead of being silently dropped. PDF bookmarks/forms
and highlight notes follow their existing owning objects; PDF page/zoom/caches stay
device-local. Native attachment hashing streams bytes; no giant base64 sync bundle.

## Engine safety

Compare bytes/path/deletion with a common base, never clocks. A changed local and
changed remote entry conflicts unless both exact results match. Remote missing
without a tombstone is an attention state, not permission to delete or resurrect.
Require conditional remote publication after refreshing metadata; provider adapters
must prove their atomic mutation contract. The API does not presume Drive v3 PATCH
implements this merely because a version field exists.

Persist outbox observations before network calls. Retain the old cursor until each
delta is applied or captured durably as conflict. Replayed identical bytes can be
acknowledged after an interrupted response/checkpoint. New local edits during upload
remain pending. Stream binary payloads first, object records next, explicit deletes
after them and manifest last. This ordering is not a multi-file remote transaction.

State contains opaque provider/account/Vault binding, replica UUID, base entries,
remote IDs/versions, cursor, pending operation UUIDs and conflict descriptors. No
tokens. Installation UUID is separate. Future auth credentials need OS-protected
storage; no auth dependency has been installed in the foundation.

## Remaining milestone

Implement Drive auth/provider with proven write-race
safety, initial/new-device flows and UI. Only after real Drive end-to-end acceptance
start WebDAV. No CRDT, team sharing, AI, telemetry, offloading or E2EE claim.

[Audit](../planning/sync-audit-2026-09-12.md),
[broader design](sync-design.md), [ADR-0017](../adr/0017-sync-foundation-safety.md),
[delivery status](../features/cloud-sync.md).
