# Tasks, calendar and planning

Status: planned. Stage: M2 basic occurrences; M5 advanced planning.
Sources: S01, S03, S04 in the [source map](../product/conversation-extraction.md).
Architecture: [task ownership in the model](../architecture/universal-object-model.md).

## Purpose and workflow

A checkbox written in a lecture or project note should be discoverable in a
global task view. A standalone task can have its own identity, project, priority
and dates. Planning views help users act on their knowledge without maintaining
another unconnected checklist.

## Requirements

| ID | Observable behavior |
|---|---|
| TASK-01 | Aggregate supported Markdown checkboxes with source note and a navigable location; identical text in different locations remains distinguishable. |
| TASK-02 | Completing a source-backed task updates its owner once stable anchors are supported; initial read-only aggregation must be labelled honestly. |
| TASK-03 | Standalone task objects support completion/status, title, optional description, priority, dates and project relations as those properties are introduced. |
| TASK-04 | Planning provides Today, Upcoming, Someday and Completed views with explicit scope/filter semantics and a visible way to find undated work. |
| TASK-05 | Tasks can appear in project context, collections, documents, boards and calendar/timeline views while preserving source/identity. |
| TASK-06 | Moving a dated item in calendar/timeline updates the configured date property through an undoable command; it does not duplicate the item. |
| TASK-07 | Recurring tasks represent occurrences and completion history explicitly; users can distinguish “this occurrence” from “the series.” |
| TASK-08 | Reminders and project-progress summaries are optional; define notification consent, due-date semantics and the denominator used for progress. |
| TASK-09 | Task dependencies, blockers, subtasks and project milestones have explicit relations and completion semantics; reject invalid cycles where the chosen dependency model forbids them. |
| TASK-10 | Assignees, task comments, assigned-to-me/assignee inbox and linked resources use the shared identity/permissions model when collaboration exists; local person links do not send assignments. |
| TASK-11 | Task creation from selected text preserves a source/context link. Natural-language dates preview the resolved date/time/timezone before committing ambiguous input. |
| TASK-12 | Distinguish hard-time reminders, context-triggered reminders, resurfacing reminders and smart deadline warnings; users can control, snooze and inspect why each appears. |

## Ownership and proposed defaults

A Markdown task occurrence remains part of its note. A stable source anchor is
required before allowing editing from remote views; line number alone is not stable
under unrelated insertions. Standalone tasks own their content separately. Promotion
from an occurrence needs a deliberate replacement/reference choice and undo.

Proposed planning defaults: Today includes overdue and due-today incomplete tasks
in separate sections; Upcoming excludes overdue; Someday is undated; Completed
includes completion timestamps where available. A task's due date is different
from an event's start/end time. A project deadline does not automatically become
a new task. These defaults should be accepted/refined by the implementing task.

## States and edge cases

If an external edit removes/reorders a checkbox and its anchor cannot be resolved,
show a stale source and offer navigation/reconciliation rather than toggling another
line. Recurrence must handle timezone/DST, missed occurrences and series edits with
explicit rules before shipping. A notification that was not scheduled should not
appear as confirmed. Shared assignments wait for a real sharing/identity model;
local person relations do not imply notification or account access.

## Acceptance scenarios

- TASK-01/02: index two identical checkboxes, insert unrelated text externally,
  then complete one from Tasks; only its intended source changes.
- TASK-05/06: move a project task's deadline on the calendar and observe the same
  date on its board card and source properties; undo restores it.
- TASK-07: complete one recurring occurrence, then edit the series; history remains
  meaningful and previously completed occurrences do not reappear as new work.

Dedicated personal/project/shared calendars and event objects are specified in
[calendar/events](calendar-and-events.md). Task Kanban uses VIEW-04; task calendar
uses VIEW-05; advanced timeline/Gantt uses VIEW-11. These remain views of real
tasks, not independent planning copies.

## Delivery

Start with source navigation and reliable aggregation; implement stable anchor
round-trips before cross-view toggles. Standalone tasks, dates and basic views follow.
Recurring schedules, reminders and advanced dependencies are separate later work.

## Implemented incremental subset

Task list date/search filters and quick due-date editing reuse Universal Tasks; Calendar still projects those same deadlines. Recurrence, named zones, reminders and task dependencies remain future work. See [CURRENT](../planning/implementation-status.md).
