# ADR 0018 — Recoverable native Universal Object folder commands

- Status: accepted
- Date: 2026-09-13

## Context

Notes use physical folders while other Universal Objects use folder metadata.
Independent filesystem and metadata operations can split a project after failure.
Sequential delete-before-write is unsafe, especially on constrained storage.

## Decision

Add an explicit `WorkspaceFolderCommandStore` capability used through the existing
serialized repository boundary. Native storage stages exact after-images and a
workspace-bound intent with before/after hashes. It preflights every entry and
reuses existing owner-write recovery. Interrupted commands roll forward on reopen;
unresolved or externally changed inputs keep the workspace read-only.

## Consequences

Folders remain organization over existing canonical files, not a new data store.
UUIDs and unknown object data remain unchanged. Empty-only directory removal
protects unrecognized files. This does not promise filesystem-wide atomicity.
Adapters without this capability refuse folder commands before mutation; browser
transaction support requires a separate tested implementation.

## Evidence

`test/universal_folder_safety_test.dart` exercises real native Vaults, collisions,
failed writes, reopen recovery, external edits, mixed objects and relative links.
See [storage contract](../architecture/storage-formats.md) and
[runtime audit](../planning/runtime-audit-2026-09-13.md).
