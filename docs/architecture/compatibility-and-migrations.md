# Compatibility and migrations

Status: required design contract before durable content ships; implementation is
pending. Source: S10. Extends [storage](storage-formats.md) and accepted ADR-0004;
does not change the file-first authority decision.

| ID | Observable behavior |
|---|---|
| COMP-01 | Workspace manifest, object JSON, Canvas, ink and Smart View formats declare documented versions independently of the Drift database schema. |
| COMP-02 | Old supported workspaces open through tested, explicit migrations; risky migrations create and verify a recoverable backup before writing. |
| COMP-03 | Parsers tolerate optional/unknown fields where safe and preserve them on round-trip. Unsupported newer formats open read-only or show a useful unsupported state rather than destructive downgrade. |
| COMP-04 | Versioned old-workspace fixtures verify content, IDs, relationships, attachments, view configuration and unknown metadata survive upgrades and index rebuilds. |
| COMP-05 | Full workspace backup/restore includes authoritative files and required recovery records; rebuildable indexes are distinguished from non-rebuildable operational state. |
| COMP-06 | A published deprecation/support policy precedes format retirement. Plugin API and sync protocol versions later negotiate compatibility and fail safely. |

## Migration contract

Inventory versions and validate the source first. Plan migration, check free space
and permissions, create a backup, then apply through a recoverable operation.
Record progress so interruption does not create an ambiguous partially migrated
workspace. Reopen and verify identities/references before declaring success.
Keep the old backup until the user can confirm recovery. Never mark a workspace
upgraded just because a SQLite schema migration succeeded.

Database indexes may be rebuilt from owning files; unsynced journal operations,
conflict copies and pending recovery data must not be casually deleted as cache.
Precise support windows and multi-file migration atomicity are open decisions in
[prerequisites](../planning/open-questions.md), not implemented guarantees.

## Content anchors

Block references, task extraction and PDF Highlight objects need stable anchors
and documented orphan behavior. A highlight may be an object while individual
pen samples remain part of an ink payload. Do not promote every stroke into an
object or identify a highlight only by a mutable screen coordinate.

Test interruption, full disk, corrupt source, unsupported future version and
restoration with the old app version. Unknown required semantics may justify
read-only access; tolerant parsing is not permission to silently discard data.
