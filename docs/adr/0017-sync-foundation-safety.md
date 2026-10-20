# ADR-0017 — Local sync safety foundation

Status: accepted implemented subset, 2026-09-12. Extends ADR-0007/0010/0016.
This does not mark Google Drive, WebDAV or end-user sync complete.

2026-10-15: [ADR-0030](0030-immutable-drive-revisions.md) partially supersedes the
conditional-publication-only gate below for explicit immutable revision providers.
Concurrent branches remain recoverable conflicts; ordinary mutable providers still
require atomic conditional publication. The original foundation decision follows.

## Decision

Native stores hold an OS file lock at `.orbit/device/vault.lock` before recovery
and keep it until close/switch. A process-local guard also prevents duplicate
owners where OS locks have process-wide semantics. Never delete the lock file to
steal ownership. Closing/crashing releases the OS handle; stale file existence is
not ownership. Mutating methods reject calls without ownership. External editors
do not honor this advisory protocol; expected-hash checks remain necessary.

Permanent deletion writes a local `.orbit/recovery/delete-<object-id>.json` intent
before deleting exact expected bytes, then publishes
`.orbit/tombstones/<object-id>.json`, then removes intent. The tombstone retains
Vault/object/operation UUID, old path, SHA-256 and diagnostic UTC time, not body or
credentials. Startup completes only supported local intents with matching identity
and unchanged/absent source. Conflicts preserve files and open read-only for review.
Portable tombstones alone never execute a delete. Backup import already quarantines
recovery journals; a restored object plus tombstone is retained read-only, not purged.
Unknown optional tombstone metadata survives recovery. No tombstone garbage collection.

Sync uses exact-byte SHA-256 plus logical path and explicit deletion state against
a persisted common base. Missing is distinct from deletion. The engine requires
atomic conditional publication from a provider; a GET followed by unconditional
PATCH is not a valid implementation. There is no chosen Drive write-race solution
yet. The fake provider proves the engine contract only.

Device-local sync state lives at `.orbit/device/sync/state-v1.json`, through the
existing expected-hash/journaled store, separate from disposable FTS. This selects
the existing recoverable device-file mechanism instead of the preliminary proposal's
additional operational database. The 16 MiB limit and whole-state checkpoint cost
are explicit foundation limits; benchmark/migrate operational state before claiming
large-Vault production performance. Such a migration must preserve outbox/bases.

Installation identity is lazily stored under application support
`orbit-sync-installation/.orbit/device/identity-v1.json`, outside portable Vaults.
It is non-secret. Replica ID in sync state is distinct from installation, Vault and
object identities. The auth/Settings composition will supply the current app version.
No identity/network initialization is added to local-only startup.

## Consequences and validation

Local deletion is safer immediately. Empty Trash is still a sequence of independently
recoverable object deletions, not an all-or-nothing batch. Attachments/history are
not purged by deleting a file object's metadata. No old Vault is rewritten on open
merely to install sync; operational files appear only when their capability is used
(the native ownership lock is required for opening writable native storage).

Tests cover separate-process ownership, state reopen/CAS/device-journal recovery,
deletion interruption boundaries, foreign intents, preserved external bytes,
inventory inclusion and streamed attachment hashing, and three simulated replicas.
Native streaming remote apply is now implemented using the existing file-save
journal and repository queue. Device staging is separate from authored content;
required controller guards protect drafts and Vault generation, and the replica's
state wrapper serializes checkpoint writes with workspace switches. Notes moves
reuse the existing move journal. Remote deletion intents optionally retain exact
`tombstoneSource` bytes; older local intents remain supported. Conflict payloads and
remote-deletion before-images live in `.orbit/sync-conflicts`, excluded from sync
but included in backups. No domain schema migration is performed on existing files.

Conflict UI, live provider auth/transfer and hardware acceptance remain required.
Native adapter limits are in the [current sync contract](../architecture/sync.md).
