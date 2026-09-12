# Provider-neutral multi-device sync — design proposal

Status: proposed implementation design, 2026-09-12. **Not shipped sync.**
Read the [current-code audit](../planning/sync-audit-2026-09-12.md) first.
Google Drive is primary; WebDAV is second. No Supabase integration in this milestone.

## Boundaries

Presentation observes a sync application service with local/queued/transferring/
conflicted/needs-sign-in/error status. It never imports Drive or WebDAV APIs.
`SyncEngine` owns reconciliation and retry orchestration. A repository adapter owns
local inventory, staged apply, durable commit notifications and draft coordination.
Provider adapters own remote authentication, addressing, deltas and transfer.

Core provider contracts should expose account/capabilities, Vault discovery and
identity inspection, idempotent Vault creation, paged deltas, entry metadata,
staged/checksummed transfer, conditional publication, move and deletion intent.
Initial upload/download are engine workflows, not provider-specific UI logic.
Tokens are supplied through a separate platform credential/auth service; domain
models contain neither token objects nor HTTP clients.

## Sync inclusion policy

Allow exact `workspace.json`, recognized owning files under `Notes`, `Objects`,
`Boards`, `Drawings`, and original `Attachments` bytes after safe-path validation.
Include trashed owning files; do not filter by active-object UI visibility.
Preserve empty Notes directory structure. Archived authored content must remain
eligible by default; exact archive semantics await the rest of the owner's brief.

Report unrecognized files and unsupported formats in preflight; never delete them
or silently claim a complete Vault upload while omitting them. Future Views/Types/
Relations formats need explicit registration. Opaque user-file replication needs
an explicit inventory policy, not automatic adoption into Universal Objects.

Exclude all `.orbit` operational material by default: device settings, indexes
(including WAL/SHM and quarantined copies), locks, cache, logs, temp downloads,
history and recovery journals. A future portable tombstone format gets an explicit
allowlist entry. `.orbit-sync` on the provider is versioned transport metadata;
it is never executed as a native recovery journal. Tokens never enter either tree.

## Local operational state

Use a separate device-local operational database, outside `workspace.sqlite` and
its rebuild lifecycle. Proposed location: application-support `sync/`, keyed by
installation ID, local replica ID and Vault UUID, with provider/account binding.
A copied Vault directory must not clone an installation ID or account credentials.
Two local copies of one Vault UUID need distinct replica records.

Persist device identity, opaque remote IDs/root IDs, per-entry base hash and path,
remote version/fingerprint, cursor, outbox operations, upload-session references,
download staging state, retry state and conflict alternatives. Secure upload URLs
that act as credentials require secret handling, not diagnostics or exports.
Keep shared base bytes or a verified history reference when needed for conflict
comparison; a hash alone cannot reconstruct a diff.

Outbox coalesces after local durable saves. File commitment and database commitment
are not atomic: startup inventory reconciles differences against persisted bases,
and a deletion journal records intent before bytes disappear. Outbox-write failure
must not relabel saved local content as unsaved. Show sync needs attention and
reconcile on the next run. Never prune unresolved operations or conflicts as cache.

## Reconciliation

For each identity, compare `(content hash, logical path, deletion intent)` against
the last acknowledged base. Provider IDs identify remote entries; canonical IDs
remain inside local Markdown/JSON. SHA-256 is over exact bytes, not normalized text.
Stream attachment hashes and cache file-stat hints; revalidate content before
publication when hints are ambiguous. Modification timestamps are diagnostic only.

| Local vs base | Remote vs base | Action |
|---|---|---|
| Same | Same | No transfer |
| Changed | Same | Conditional upload |
| Same | Changed | Verified staged download and local expected-hash apply |
| Changed | Changed, same desired result | Reconcile acknowledgement after validation |
| Changed | Changed, different result | Preserve alternatives and require resolution |
| No common base | Both present | Verify equality or ask; never infer a winner by time |

Moves use object identity plus base path. Different simultaneous moves conflict.
Remote rename updates provider mappings; Notes moves reuse `NativePathMoves`.
Do not create a duplicate object then delete its old path as two unrelated writes.
Whole-board conflicts preserve both scenes; field merges are not part of the first
release. A conflict-resolution operation records the alternatives it supersedes
and rechecks them before publication.

Downloads occur outside the editor save queue. Apply only within the existing
repository boundary with current Vault generation, writable state, expected hash
and dirty-draft guards. Stage attachment bytes before records referencing them.
Persist page/cursor advancement only after changes are applied or durably staged
as recoverable conflicts. A crash must replay safely rather than skip unseen data.

## Google Drive adapter

Use `drive.file` and ordinary user-visible files. Create an app-managed root,
persist its ID, and discover app-owned roots by compact appProperties rather than
display name. Multiple matching roots/Vaults require disambiguation; do not pick
the first same-named folder. All platform OAuth clients belong to the same Cloud
project; test cross-client visibility of app-created files on Windows and Android.

Persist Drive file IDs. Use compact properties such as `orbitVaultId`, `orbitObjectId`,
`orbitProtocol`, and role. Verify the owning-file identity rather than trusting
appProperties alone. Roots renamed by users stay connected by ID.

Acquire a Changes start token before initial inventory, then consume subsequent
changes to close the listing race. Persist every page transition safely. Removed
entries may lack metadata: use known remote mappings. Filter unrelated changes;
do not recursively scan the entire Drive at each pass. Invalid cursor triggers
scoped reconciliation, never resetting the base and overwriting local files.

Use resumable uploads for attachments and idempotent creation identifiers so an
accepted request followed by a timeout does not create another object. Verify
download size/digest against protocol metadata; Drive checksum availability varies.
Provider version changes identify potential divergence but are not mutual exclusion.

**Unresolved production gate:** prove safe concurrent publication against the
actual Drive API. A preliminary metadata GET followed by an unconditional PATCH
has a lost-update race. If reliable conditional writes cannot be established,
use immutable revisions carrying explicit parent hashes and retain divergent heads;
ordinary visible files remain a recoverable projection, not the sole conflict copy.
Do not ship a mutable remote catalog that two devices can overwrite silently.

## WebDAV adapter

HTTPS endpoint and scoped account credentials; no certificate-validation bypass.
Validate endpoint-origin confinement and redirect handling before attaching auth.
Use MKCOL, PROPFIND/GET, PUT and MOVE with verified server capabilities. Prefer
sync-collection tokens when available; otherwise use bounded scoped listings/ETags.
Never treat a failed/partial multistatus listing as evidence of deletion.

Require tested strong conditional mutation semantics (`If-Match` /
`If-None-Match`) or the same immutable revision safety protocol. Reject unsafe
servers for write sync instead of silently degrading to timestamp overwrite.
Locking support alone does not prove correct crash recovery. Unknown outcomes
must be reconciled before retrying a creation or move.

## Setup, triggers and failure behavior

Existing local Vault: preflight → explicit provider/account binding → resumable
upload → verify inventory → checkpoint. Do not mark synchronized after partial
completion. New device: discover UUID → download into a separate staging directory
→ verify manifest, paths, identities and dependencies → publish → rebuild index
→ open through ordinary Vault selection. Never hydrate into an unrelated live Vault.

Triggers: manual Sync Now, successful Vault open, debounced durable local changes,
foreground resume, periodic checks while active and usable-network hints. Network
hints are not proof of authenticated provider reachability. Use bounded backoff,
jitter and provider Retry-After; pause on revoked auth or quota errors. Mobile
background suspension is expected. Do not promise an always-running daemon.

Disconnect clears credentials/binding as appropriate but retains local knowledge,
pending alternatives and exported recovery. Remote deletion is a separate explicit
action. No team sharing, CRDT, E2EE, AI or other providers in this milestone.

## Delivery sequence

1. Local lock/deletion journal, inventory and durable operational-state tests.
2. Engine with two-replica crash/conflict tests and repository apply adapter.
3. Google auth/secure storage and adapter conformance, including write-race proof.
4. Real initial upload/new-device/ongoing sync UI, conflict review and acceptance.
5. WebDAV conformance and the same end-to-end acceptance suite.

Each stage must leave local editing, analysis, tests and Windows builds green.
Production readiness requires real Google credentials/device and WebDAV testing;
a fake provider or green unit suite is insufficient evidence.
