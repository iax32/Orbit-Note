# ADR 0035 — Portable Vault preferences

Accepted, 2026-10-26, following the owner's settings persistence/sync request.
Extends ADRs 0017/0030/0032; narrows ADR 0022's device-preference boundary.

Store explicitly portable preferences as ordinary `orbit.preferences` universal
objects in `Objects/<uuid>.object.json`, one writer record per installation/Vault.
Existing repository commands provide CAS, before-images, history and unknown-field
retention. Drive inventories and live shared-object replication transport these
records; no new provider service, permissions, credentials or SQLite authority.
Hide records from knowledge navigation, graph/search and ordinary object lists.

Data version 1 contains `fields: {key: {clock: integer, value: JSON}}`. Each command
increments the maximum observed field counter; concurrent same-field updates use
record UUID as a deterministic tie-breaker, independent of wall clock skew.
Different fields merge independently; lists/maps are single fields, not CRDTs.
Each writer changes only its record. Unknown fields remain stored; future or
malformed records block portable mutation and report an error without rewriting.
Records are capped at 500,000 UTF-16 units. Existing sync conflicts remain
recoverable rather than automatically choosing bytes for a divergent same-writer
record (for example, a manual copy including `.orbit/device`).

Portable allowlist covers appearance/editor defaults, user dictionary, focus
durations, note sorting, folder colors/collapse and explorer visibility preferences.
Device settings retain UI zoom, pane dimensions, tabs, caret/cameras, Spaces,
dashboard, local paths/tools, account secrets and the writer ID. A durable device
outbox covers a failed portable write after the device save. Reopen replays only
uncommitted choices. Applying remote settings preserves locally modified fields.
Legacy nondefault device preferences seed a record on the first successful
settings save. Fresh-device defaults do not compete with another device's choices.
Successful portable writes increment a distinct change revision so automatic
Drive sync also schedules an upload when no content object changed.

Scope is a Vault, not an account-global settings service: enable existing Drive
automatic sync or connect the same live shared Vault. Participants in a shared
Vault receive these preferences; server authorization still governs publication.
Physical cross-device and real-account acceptance remain separate from local
two-client tests. No cross-Vault inheritance or new closed-app sync guarantee.

Normal tab/history navigation never expands collapsed ancestors. Explicit reveal
may expand them. Folder rename remaps saved collapse paths; deletion removes them.
