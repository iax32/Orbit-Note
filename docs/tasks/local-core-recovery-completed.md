# Current task — implementation recovery and usable local core

Status: implemented; final verification recorded in the [implementation status](../planning/implementation-status.md).
Scope was explicitly expanded by the owner on 2026-09-09 beyond the original M0 shell.
The [original task](M0-01-original.md) is retained as superseded history, not a claim
that its old system-theme/no-persistence criteria were followed.

## Outcome and delivered scope

Preserve the existing Flutter project and finish a usable local workspace: native
open-format storage with a rebuildable Drift index, Notes editing/preview and links,
Canvas cards/shapes/ink/images, tasks, attachment capture, search, trash/restore,
tabs, two-pane work, Focus, a recoverable layout and the calm Orbit dark theme.
Fix compile, analyzer, runtime-widget and save coordination failures. Keep future
Graph, calendar, sync, plugins and AI out of the navigation until functional.

## Required context

- [Implementation status and remaining limits](../planning/implementation-status.md)
- [Architecture overview](../architecture/overview.md)
- [First local storage implementation decision](../adr/0007-local-core-storage.md)
- Relevant feature spec only, from the [spec map](../features/README.md)

## Verification

Run format and the zero-change format check, analyze, the complete test suite and
Windows debug build. Web compilation is an additional compatibility check. Record
actual results in implementation status. Tests cover real storage failure/recovery,
concurrent draft saves, workspace switch recovery, layout flush, Markdown editing,
links, spatial operations, small-screen navigation, split panes and Focus recovery.

## Suggested next task (not started)

Implement safe backup import into a **new empty workspace**, with strict path and
size limits, a preview of contents, complete validation before writes, and a
round-trip test covering notes, tasks, boards, attachment bytes and unknown fields.
Do not overwrite the current workspace. Scope restore separately from history UI,
cloud sync and automatic migration. Promote this to the current task when chosen.
