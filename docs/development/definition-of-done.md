# Definition of done

A task is done when its scoped behavior works, applicable failure boundaries are
checked and evidence is recorded. A feature document is not proof of implementation.

| Change | Required evidence when applicable |
|---|---|
| Flutter code | Format check, analyze and behavior tests; requested platform builds and actual blocked-check details. |
| Interaction | Empty/loading/error/read-only states, keyboard/focus/text scale, narrow/wide layouts and appropriate pointer/stylus/clipboard checks. |
| Persistent content | Round-trip, restart, interrupted/failed write, undo/trash recovery, external-edit reconciliation, export and index rebuild. |
| Format/schema | Old fixtures, unknown fields, migration backup/restore, unsupported future-version handling, documented version changes. |
| Canvas/ink | Shared engine behavior, gesture undo, saved coordinates/strokes, representative profile-mode performance and device input checks. |
| Views/context | Same-object consistency, deleted anchors/fields, stale saved state and independent private pane state. |
| Sync/plugins/AI | Offline/failure/cancel/stale states, permissions, replay/idempotency and honest recovery limits. |
| Documentation only | Relative links, requirement IDs, backlog coverage, consistent terminology/scope and no accidental code or ADR changes. |

Usual code checks are `dart format lib test`,
`dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`,
and `flutter test`. Do not create implementation-mirroring tests for prose changes.
Performance budgets are proposed targets until measured on identified hardware,
build mode and datasets. Test the feature's actual boundary rather than repeatedly
running unrelated checks after a clean result.

Completion notes identify changed behavior/files, checks and results, limitations,
architecture changes if any, and one next suggested task. Do not silently broaden
the current task or mark its unchecked criteria complete.
