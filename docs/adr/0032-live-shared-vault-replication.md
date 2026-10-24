# ADR-0032 — Live shared Vault replication

Status: accepted, 2026-10-22. Extends ADR-0027/0031; does not replace personal Drive sync.

## Decision

Protocol 1 negotiates per-room `replicationVersion: 2`, advertised capabilities
and minimum client 2. New app-created rooms opt in. Historical rooms retain
existing-document behavior; create a new shared snapshot to enable the full
workflow. Live rooms require `X-Orbit-Client: 2`. Unaware clients fail before
reading or mutating a room, rather than missing lifecycle changes silently.

The host owns a private append/flush journal and content-addressed SHA-256 blobs.
`put` creates objects idempotently, `edit` performs a known-base merge, and
`remove` retains a permanent tombstone. Trash/restore remain object snapshots.
All ordinary owning object types share the same stable identity and unknown data.
Physical owner-file moves require explicit reconciliation. Placement removal
never deletes its referenced object. Attachments must be complete and verified
before publishing their path or file owner. Immutable attachment paths reject
different bytes, including case collisions. Upload/download chunks are 1 MiB;
uploads resume from the host's verified offset, native downloads from guarded
device-local recovery stages. Browser/memory transfers remain bounded at 16 MiB.

Authenticated long polls wake on durable changes or ephemeral awareness. Hints
never carry authority: clients re-fetch state and recheck role, host epoch,
opening and drafts before applying through repository/history commands. Viewer
and revoked grants cannot upload/publish/delete. Live clients coalesce local
changes at 120 ms with a five-second integrity/heartbeat fallback. Network and
platform scheduling are not latency guarantees.

Device-only `.orbit/device/shared/<binding hash>.json` stores acknowledged bases,
uncertain edit operations and creation proposals. Endpoint, room, hashed grant,
Vault identity and host epoch bind recovery. Tokens remain outside the Vault in
optional secure device profiles. A changed epoch requires review for differing
ancestry; the client never invents a common base. This journal uses the existing
16 MiB checkpoint/CAS boundary. Inflight operations are checkpointed before send;
lost acknowledgements replay idempotently after a controller/process restart.

Bounded scalar-aware multi-edit merging combines independent text changes while
keeping UTF-16 selection offsets. Ambiguous/overlapping replacements conflict.
Large differences fall back to a conservative splice. This is not a CRDT/OT
guarantee. Note awareness uses source SHA-256, UTF-16 range and grant-bound name;
stale ranges are not drawn. Rich/source overlays do not mutate text or selection.
Structured blocks may show source navigation without a precise inline caret.

## Compatibility and recovery

Authored Markdown/JSON/attachments and portable tombstone formats are unchanged.
Before the first new `put`/`attachment` journal kind, the host flushes and verifies
an exact private `events.before-live-v2.jsonl` checkpoint. The active journal then
requires the updated host; do not run an older host against it. Stop and back up
the **whole** private directory before upgrading or restoring. The checkpoint
does not include later edits, blobs or updated grants and is not a complete
current backup. Unknown complete journal records refuse startup and release the
lock; torn final records retain existing repair behavior.

Limits: 2 MiB per document, 10,000 document identities (including tombstones),
128 MiB room metadata/history, 32 retained bases/8 MiB history per document,
1,000 retained edit operation receipts and 128 simultaneous event waiters per
room. Initial/import snapshots retain the existing 128 MiB encoded limit.
Live attachments may exceed a downloadable snapshot; backup then fails clearly.
Blob disk usage and journal growth are not automatically compacted. Operators
must provision storage and preserve private backups. Cache/index data remain
rebuildable, never knowledge authority.

## Continuity and explicit limits

Remembered server profiles can opt into reconnect on launch/resume. Explicit
Disconnect suppresses reconnect for that opening. This installs no OS service.
Drive and shared authority remain mutually exclusive per Vault. There is no
closed-app mobile worker or promise of background real-time delivery. Android
and iOS scheduling is controlled by their operating systems. Physical device,
real-network/TLS and Android platform validation remain separate acceptance
requirements; two local clients cannot substitute for them.

## Validation

See [implementation evidence](../tasks/live-shared-sync-2026-10-22.md) for actual
commands/results, failure tests and remaining work. No credentials or dependency
packages were introduced by this protocol.
