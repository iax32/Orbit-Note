# ADR-0010 — Real Notes folders and recoverable explicit moves

Status: accepted, 2026-09-09. Extends
[ADR-0007](0007-local-core-storage.md) and
[ADR-0008](0008-backup-import-and-workspaces.md).

## Context and decision

Vault is the user-facing alias of Workspace. Notes folders are ordinary native
directories under `Notes/`, not collections, Spaces or duplicate object types.
Create, rename and move commands go through the application repository. UUIDs,
open tabs and Canvas object references survive path changes. Folder names use
portable Windows-safe paths and existing destinations are never overwritten.

Before an explicit move, drafts are flushed and the UI temporarily waits for file
organization. For recognized Markdown owners, common outgoing inline/reference
destinations are rebased to the destination; links inside a moved subtree follow
that subtree. Fences/inline code, wiki identities and readable labels stay intact.
Unchanged bodies retain exact owner bytes. Ordinary unadopted Markdown or symlinks
inside a folder block automatic moves instead of being silently rewritten.

Native move recovery is a bounded roll-forward protocol. Stage and flush replacement
bytes under `.orbit/recovery/<uuid>-<n>.move-data`, then flush
`<uuid>.move.json` with `format: orbit-note-path-move`, `version: 1`, `source`,
`target`, `directory` and `files` entries containing `path`, `beforeHash`,
`afterHash`, optional `staged`. Verify every file/tree precondition before applying
replacement bytes through the existing recoverable save path. Recheck hashes and
destination absence, then rename the source file/directory within the Vault.

Startup finishes only if exactly one source/destination exists and all current
bytes match the relevant recorded hashes. Recovery-directory scanning rejects
symbolic links/junctions before reading journals. A changed file, symlink or changed file
set retains the journal and bytes; the repository opens read-only for review.
Published target bytes are authoritative; staging cleanup can retry later.
Archive-supplied journals remain quarantined by backup import.

Backup v1 gains optional `directories`, a list of safe Notes paths (maximum 10,000).
Old bundles without the list remain valid. Empty folders are created inside import
staging before publication. Folder collapse and sorting are device session state,
not object content or portable semantic structure.

## Alternatives and limits

Copy/delete was rejected because it duplicates identities and increases partial
publication boundaries. No parallel folder identity table or database-only hierarchy
was introduced. A strict multi-process filesystem transaction is not claimed.
An interruption can leave staged bytes and partially prepared sources awaiting
roll-forward recovery. There is no end-user recovery/history browser or folder undo
command yet. Folder Trash and internal drag/drop are follow-up features.

Complex HTML/Markdown destinations and incoming path links authored outside the
moved subtree are not globally repaired. Stable object/wiki references remain the
preferred cross-object relationship. New formats and unrecognized Markdown are
preserved, not adopted implicitly.

## Evidence

`folder_organization_test.dart` verifies ID/attachment preservation, nested rename,
empty-folder export/import, forbidden paths/collisions, unrecognized Markdown
preservation, interrupted multi-file recovery, external-conflict read-only behavior,
relative link rebasing and persisted collapsed folders. Hardware power-loss and
hostile concurrent filesystem mutation remain outside the evidence. A Windows
junction regression verifies that external journal bytes remain untouched.
