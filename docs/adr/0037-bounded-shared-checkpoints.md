# 0037 — Bounded large shared-session checkpoints

Status: accepted, 2026-10-30.

The shared host permits 32-MiB documents, but a client retains both known bases
and uncertain outgoing snapshots in a 16-MiB device recovery file. Consequently
even one supported large board can stop publication after connection succeeds.

Keep the existing shared-outbox state model, operation IDs and journal path.
For native shared-session state only, encode large checkpoints as lossless gzip
in a worker; small states remain plain JSON. Read both encodings, detect gzip by
its header, enforce the existing 16-MiB stored limit and incrementally enforce a
256-MiB decoded limit. Authored files, exports, Drive state and server protocols
are unchanged. This device state stays excluded from Vault import/sync/export.

Worker preparation does not confer permission to commit: recheck the session
after preparation and use the original expected-byte hash for atomic writes.
Unchanged-state fingerprints use immutable operation IDs and document versions;
same-version content changes are already refused by the replication protocol.

Older clients can read plain small checkpoints. They cannot read the new large
compressed device checkpoints; they fail safely instead of deleting/replacing
them. Upgrading restores access. Original user knowledge is always ordinary
Vault content/history, not this operational file. Limits still require recovery
feedback; this change is not a delta protocol or an arbitrary-size guarantee.
