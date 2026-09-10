# Local-first and future sync

Status: local-first accepted; sync protocol/provider integration deferred to M6.
Supabase hosted/self-hosted is the intended first backend candidate, not an
installed dependency or a ready-made conflict-resolution engine.

## Local path

```text
User action → application command → local durable save → local observable state
                                       ↓ later
                               durable outbox → transport → server
                                                          ↓
                                        remote changes → local command adapter
```

The UI can show an optimistic edit immediately with an honest saving/error state.
It never treats server acknowledgement as the condition for local use. Use the
[storage save/recovery contract](storage-formats.md); do not maintain a second
independent cloud-backed repository for views.

Prepare stable UUIDs, workspace scoping, local revisions, timestamps, tombstones,
portable serialization, repository boundaries, and reversible commands as their
features arrive. Do not implement authentication/outbox/CRDT scaffolding in M0.

## Platform storage

| Platform | Planned adapter / limitation |
|---|---|
| Windows/native desktop | User-selected workspace files plus native Drift/SQLite; external edits reconciled |
| Android/iOS | App-private files/database initially; explicit import/export or permissioned folder access; background execution is constrained |
| Browser | Drift's web-compatible SQLite path and browser-managed durable storage; file import/export bridges the same logical formats |

Browser storage is quota/permission/eviction dependent and cannot assume an
unrestricted desktop directory or filesystem watcher. Verify worker/WASM/storage
requirements for the selected Drift version. Export and recovery remain essential.
The generated web runner establishes a compile target, not an implemented web
storage adapter. See [Drift platforms](https://drift.simonbinder.eu/platforms/).

## Replication design to validate before M6 implementation

- Change envelopes carry workspace/entity ID, unique operation ID, device ID,
  base version/ancestry token, payload reference/hash, and deletion intent.
- Outbox is durable, ordered as dependencies require, replay-safe and idempotent.
  Delivery retries with bounded backoff; cursor advancement follows local commit.
- A monotonic local revision or wall-clock timestamp is insufficient to resolve
  concurrent edits. Detect divergence from a shared base; do not silently use
  last-writer-wins for text, ink, or irreplaceable structured content.
- First text sync preserves conflicting versions and offers a reviewed merge.
  Automatic merges require type-specific rules and tests. CRDT/OT evaluation is
  reserved for real collaboration requirements.
- Deletion is a tombstone; offline edit-versus-delete is a visible conflict.
  Retention/garbage collection requires an acknowledged replica frontier and a
  safe rejoin policy for stale devices. Timestamps alone cannot authorize cleanup.
- Attachment transfer uses checksums, resumable/idempotent upload and separate
  blob storage. Content references may show a pending-download placeholder. Avoid
  dangling committed references and premature orphan-blob deletion.
- Recovery/rebuild preserves unsent knowledge. Lost cursors trigger reconciliation;
  they never authorize overwriting the only local content with a remote snapshot.

Before shipping, specify the exact protocol, server schema, and ownership/auth
model in an ADR. Test duplicate/reordered deliveries, retries, offline devices,
clock skew, interrupted saves/transfers, concurrent edits and workspace separation.

## Provider boundary

Supabase can supply auth, PostgreSQL, storage and change notifications. Notifications
trigger pulling changes; they are not the durable replication log by themselves.
Keep backend access behind a transport interface with configurable endpoints so
hosted Supabase, [self-hosted Supabase](https://supabase.com/docs/guides/self-hosting),
or a later custom service does not change the domain model.

Use server-enforced workspace membership/access rules; never ship service-role
credentials to clients. Secrets belong in platform secure storage, not exported
workspace files. Encryption/end-to-end key management and shared-workspace roles
need separate design before claims or implementation. Offline use stays available
when sign-in, subscription, remote AI, or the original service is unavailable.

The [sync specification](../features/sync-and-collaboration.md) details optional
identity/provider choices, shared-base property merges, lazy attachments and
collaboration scopes. Google identity is not mandatory storage. Space sharing,
protocol negotiation and E2EE need explicit later design; no such implementation
or security guarantee follows from the accepted Supabase direction alone.
