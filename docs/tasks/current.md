# Current task — repair Rich math and Calendar workflows

Status: repair batch delivered and validated, 2026-09-10.
The owner's request to repair the newly added features supersedes the earlier
Rich-only task. Preserve the committed editor, Calendar, graph and callout work.

## Scope and acceptance

- Make symbol insertion target the active visual fraction slot; synchronize focused
  visual fields on undo, preserve edited TeX argument boundaries, and render line breaks.
- Share the validated event form between Calendar and event details. Convert local
  clock input to UTC correctly; keep all-day dates civil and end-exclusive.
- Persist complete event commands, retain failed drafts and unknown properties,
  reject stale edits and invalid schedules without silently replacing source data.
- Keep Universal Object identity, repository save/recovery, Markdown and documented
  JSON authority. No cloud, plugins, AI or new persistence layer.

## Targeted reading

- [Markdown editing](../features/markdown-and-editing.md), EDT-01–15.
- [Calendar/events](../features/calendar-and-events.md), EVT-01–05.
- [Planning semantics](../features/tasks-calendar-and-planning.md).
- [Rich projection](../adr/0011-source-preserving-rich-markdown.md).
- [Implemented formats](../architecture/implemented-formats.md).

## Validation and handoff

Run `dart format lib test tool`, zero-change format check, `flutter analyze`,
`flutter test`, and `flutter build windows --release`; smoke-launch if possible.
The [CURRENT capability map](../planning/implementation-status.md) records evidence
and boundaries. Update architecture decisions only if the architecture changes;
these repairs retain the accepted architecture and require no storage migration.

Next bounded task: Rich selection/formatting across inline equation segments,
with keyboard and large-note layout acceptance. Do not restart the projection.

Final evidence: zero-change format, clean analyzer, all 151 tests passing, Windows
release build successful (37.9 seconds), responsive native startup and clean exit.
The existing user app instance was preserved; restart it to load the rebuilt code.
