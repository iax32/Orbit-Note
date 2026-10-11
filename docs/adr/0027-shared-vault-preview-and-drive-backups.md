# ADR-0027 — Self-hosted shared Vault preview and immutable Drive backups

- Status: accepted
- Date: 2026-10-11
- Scope: SYNC-02/03/04/05/09/10 shared-note/Canvas and backup subsets
- Supersedes: none; ADR-0017/0019 personal replica safety gates remain in effect

## Context

The owner requested simultaneous editing with named cursors and Google Drive
support, selected self-hosting and asked for help registering OAuth. Existing
code has local durability, Google account adapters and personal sync simulation;
it has no production shared service or proven Drive conditional-publication API.

## Decision

Add a standalone Dart HTTP service and application session boundary. Sharing is
an explicit whole-Vault snapshot, preserving canonical workspace/object identity.
Only existing active notes/Canvas boards are live-editable in this preview.
The service assigns opaque grants, server-enforces owner/editor/viewer access,
binds names to grants, and supports revocation. HTTP is accepted only on loopback
by app clients; remote hosting requires HTTPS via a trusted TLS reverse proxy.
No browser-origin access is accepted yet.

Merge shared text conservatively using a known base and independent UTF-16
splices; combine same-position insertions in server acceptance order. Merge
Canvas elements by stable placement ID and independent fields. Overlapping edits,
edit/delete races, conflicting reorderings and expired bases stop for recovery.
This is not a CRDT or a guarantee of automatic merge for arbitrary simultaneous
editing. Snapshot proposal IDs deduplicate lost acknowledgements and reject reuse
with another proposal. The append/flush journal precedes server acknowledgement;
partial trailing records are truncated on restart. Unsupported complete records
fail startup instead of skipping accepted edits.
Storage append/flush failures stop subsequent mutations until restart/repair;
the service never appends an acknowledged event after an uncertain partial write.

Remote accepted content goes through ordinary controller edit/save/history; local
and server save states stay separate. A session ends on a Vault opening generation
change, including reopening the same UUID. Lost network requests retain their
proposal in memory; saved local files survive process restarts. Rejoining divergent
content requires explicit recovery rather than guessing a common base. Invitations
are bearer capabilities, not verified email identities. Keep connection details
privately for rejoining; credentials are not written to Vault metadata.

Drive transfers are independent immutable backups with resumable 1 MiB chunks,
server MD5 acknowledgement verification, SHA-256 download verification, narrow
drive.file access, Google-subject binding and explicit restore into a new folder.
They do not implement SyncProvider or overwrite live remote owning files. OAuth
app registration and live-account acceptance remain distribution prerequisites.

## Alternatives

Timestamp winners would discard concurrent work. Pretending Drive is a live
presence/OT service would bypass its actual API and the sync write-race gate.
A hosted service was not selected by the owner. A CRDT and encrypted team identity
system require a separate format/protocol/security scope and migration evidence.

## Consequences and validation

No local format migration or additional dependency. Server journal/initial backup
are separate private deployment data. Attachments and other objects are included
in the initial copy; live creation/deletion, attachment updates, per-object grants,
shared comments, text selection/caret sharing, E2EE and browser clients are absent.
Named note pointers use relative viewport coordinates; Canvas cursors use world
coordinates and the common camera. Presence expires after 15 seconds and is never
durable. Polling occurs at 500 ms, transmits document deltas, and bounds history to
32 bases/8 MiB per object and 1,000 proposal acknowledgements per room. The append
journal itself requires operator disk monitoring and backup; compaction is deferred.

See current task for actual tests, builds and unperformed deployment/account checks.
