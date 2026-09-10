# ADR-0008 — Backup restore publication and device workspace selection

Status: accepted, 2026-09-09. Extends ADR-0007's deferred backup-import portion.

Partially superseded by [ADR-0009](0009-audit-and-incremental-local-state.md):
mixed-content warnings replace rejection of unsupported objects, and native change
events replace idle polling. Publication/quarantine and selection contracts remain.
Empty Notes-folder preservation is extended by [ADR-0010](0010-notes-folder-moves.md).

## Decision

Desktop import validates the complete v1 bundle before creating files: format and
manifest identity, safe portable paths, case-insensitive and file/folder collisions,
file count, decoded size, object decoding/unique IDs and required file-object
attachment bytes. Limits are 128 MiB encoded input, 80 MiB decoded and 10,000 files.
The picker checks file size before reading and parsing runs off the desktop UI isolate.

Import creates a unique `.orbit-import-<uuid>` staging directory below a chosen
existing parent, flushes each file, and renames the completed directory to a unique
`Imported Orbit <uuid>` folder. It never imports over an existing workspace. Failure
leaves an identifiable incomplete staging directory for inspection; it does not
publish a completed folder or delete existing data. The original identities and
unknown supported-envelope fields are preserved. This is a restored copy, not a
fork with rewritten IDs. There is no sync account to join automatically.

Imported `.orbit/recovery` files are retained under `.orbit/imported-recovery` so
opening the restored folder cannot replay archive-supplied journals. Original
canonical/history bytes remain intact. Recovery review is a future explicit action.
Unknown future manifest versions and malformed/unadopted canonical objects fail
validation before disk writes. Import does not execute attachments or run migrations.

The selected native folder lives in versioned `selected-workspace.json` in the
application-support directory, separate from portable workspace files. Remember it
only after opening succeeds. An unavailable saved folder produces a recoverable
choice, never silent recreation of the missing workspace. Preferences use a flushed
temporary file and rename. Tests inject a separate preference path.

## External edits

Use a bounded-frequency five-second check plus a check on app resume. Compare
canonical object paths and content hashes through the repository. Reload clean
objects; if local drafts exist, preserve them and retain the existing file-hash
conflict/recovered-copy workflow. A draft created during refresh is also protected.
Manifest changes make the current repository read-only until explicitly reopened.
This is polling, not an operating-system watcher or a multi-process lock. Large
workspace scan cost, atomic multi-file external edits and automatic binary-attachment
preview invalidation remain follow-up work.

## Consequences and alternatives

Overwriting the active folder was rejected because partial restore could destroy
working data. A staged directory avoids requiring a speculative multi-file mutation
protocol in the live repository. It does not prove power-loss behavior on every
filesystem. Native watcher integration can later supplement, not replace, hash
reconciliation. Browser folder import remains unsupported; existing browser local
storage/export remains available with its documented limits.

## Evidence

Backup tests cover canonical/attachment byte round-trips, unknown fields, journal
quarantine, invalid paths and injected partial-write failure. Workspace tests cover
reopening the saved selection, unavailable paths, failed-startup recovery, external
clean reload and dirty conflicts. See [batch report](../planning/local-hardening-report.md).
