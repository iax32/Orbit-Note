# ADR-0016 — Provider-neutral sync around canonical workspace files

- Status: proposed protocol; provider order accepted by owner
- Date: 2026-09-12
- Scope: M6, Google Drive first, WebDAV second
- Supersedes: Supabase-first candidate language in local-first-sync.md and SYNC-11

## Context

The owner requests Windows/Android multi-device synchronization while preserving
offline local files and existing Universal Object identities. The
[audit](../planning/sync-audit-2026-09-12.md) found no durable sync base/outbox,
permanent-deletion tombstones, cross-process Vault lock or authentication layer.
Copying a Vault directory, including SQLite/recovery files, would be unsafe.

## Proposed decision

Use a provider-neutral application SyncEngine with repository-owned local commits
and infrastructure provider/auth adapters. Exact canonical bytes remain local
authority. Keep device-local operational sync state separate from the rebuildable
FTS index; credentials use OS-protected storage. Use stable Vault/object UUIDs and
provider IDs, explicit common bases and deletion intent, recoverable staged apply,
and visible conflicts. No last-write-wins based on timestamps.

Google Drive uses normal user-visible files with narrow drive.file access and the
Changes feed. WebDAV implements the same contract after server capability testing.
Detailed [design and release gates](../architecture/sync-design.md) remain proposed
until the missing tail of the owner's brief and concurrent-publication proof are
resolved. No accepted security or production guarantee is implied by this ADR.

## Alternatives and consequences

Database/cloud authority, whole-directory drive mirroring, name-based Vault merge,
and unconditional remote overwrite are rejected. CRDT/team collaboration and other
providers are out of scope. Protocol implementation must first address local
deletion/recovery and demonstrate remote race safety. Extra retained alternatives
and operational state cost disk space but prevent silent data loss.

## Evidence required

Two-replica offline/restart/concurrent-edit/delete/move tests, crash boundaries,
secure auth/platform checks, transfer integrity and real Windows/Android Google
Drive acceptance; then WebDAV conformance on actual servers. Audit/documentation
and existing local tests alone do not satisfy the production-sync milestone.
