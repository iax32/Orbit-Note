# ADR-0030 — Immutable personal Drive revisions

Status: accepted for the authorized personal sync task, 2026-10-15.
Extends ADR-0017; supersedes its conditional-publication-only engine gate for
providers implementing the explicit immutable-branch contract. Other providers
still require atomic conditional publication. ADR-0027 backups remain independent.

Drive's file version field is not a compare-and-swap guarantee. Instead, personal
sync publishes immutable blob files followed by immutable revision records. Each
record binds the Vault UUID, exact SyncEntry, operation UUID, blob ID/size and the
parent revision IDs observed before publication. Generated Drive IDs and resumable
session URLs are journaled device-locally before use. Lost acknowledgements retry
the same IDs; completed blobs are verified before their record is published.

A complete paginated listing reconstructs each object's revision graph. Multiple
heads are conflicts, never timestamp winners. The engine retains each alternative
locally before checkpointing the observation and stops publishing that key until
review. Resolution appends a revision whose parents are all reviewed heads; a
concurrent unknown branch remains another head. No remote live file is overwritten
or deleted, even when two publications race. Equal-content forks may still require
review. Missing parents, incompatible records, changed bytes and missing previously
observed revisions stop safely. A missing listing entry is never a tombstone.

Existing native staging, hash/draft/opening guards, file history and portable
permanent-deletion tombstones remain authoritative. Sync state and upload journals
are device-only and bound to Google subject, remote folder, Vault UUID and opening.
Tokens remain in existing secure account storage. Settings opt-in covers authored
objects (including Archive/Trash), attachments and tombstones, excluding local
history, caches and device settings. Empty folders are not replicated in this
slice; device-local folder Archive metadata continues to block setup explicitly.

Automatic sync runs only while Orbit is open, coalesces passes, backs off failures,
and pauses for credentials, unsafe local state or explicit disconnect. Shared
multiplayer and personal Drive sync may not run simultaneously for a Vault. Pause
does not erase local data or remove published Drive revisions. No remote revision
garbage collection is introduced; storage usage grows with changed content.

The protocol avoids an undocumented Drive mutable-write precondition. Google
documents generated-ID duplicate-create rejection and resumable status probing in
[file creation](https://developers.google.com/workspace/drive/api/guides/create-file)
and [uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads).
Provider simulations/native two-replica tests prove our protocol behavior, not
Google account rollout or real two-device acceptance. Current task records actual
checks and remaining limits.

## Discovery optimization — 2026-10-22

2026-10-29 compatible optimization: acknowledged immutable publications and their
verified cache bodies enter the local feed ID set atomically with the receipt,
without advancing Google's token. This avoids hiding own publications while the
remote change index catches up. Missing query results for retained identities
must be verified directly by ID, never treated as deletion or silently forgotten.
Publication may consume the engine's immediately preceding same-key inspection
once within two seconds; another observation invalidates it. Parent/fork checks,
create-only writes and replay identity remain authoritative. Complete Google
create acknowledgements may prove stored revision bytes using exact returned
identity/size/MD5; partial/inconsistent replies still require verified readback.
These are transport/checkpoint refinements, with no cloud schema migration.

The complete graph may also be reconstructed from a fully listed baseline plus
validated Drive change-feed pages. The optional device-journal checkpoint binds
complete membership and cursor; reset snapshots preserve independent engine crash
replay. Full audits and immutable/missing-parent guards remain. See
[implementation contract](../architecture/sync.md). This changes discovery cost,
not storage authority, publication or conflict semantics.
