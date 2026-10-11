# Calendars and event context

## Delivered future occurrences and individual changes — 2026-10-09

Month/week calendar, planning agenda and day/week grids now project future event
occurrences with the original UUID and stable ordinal keys. Completion advances
the current schedule without renumbering future occurrences. Paused series show
only their current schedule; finished series retain the final schedule with its
override. A cancelled final occurrence stays hidden after skipped recording.

In planning details choose Change this occurrence; the month-calendar event edit
button also opens these controls. Choose a date/time to reschedule with retained
duration, cancel the occurrence, or restore its original schedule. The cadence and
resource links stay intact. Moves across visible date windows remain discoverable.
Cancelled events are omitted from the calendar; Repeat & history lists individual
changes and offers Restore. Actions use guarded source snapshots and undo, with
document history preserving recoverable changes. Completion of a moved occurrence
records its actual dates; cancelled current occurrences must be recorded as skipped.

Unsupported metadata, clock gaps and the 10,000-occurrence projection bound show
coverage warnings. At most 1,000 overrides are stored, refusing additions beyond
that limit. ICS still exports the current snapshot, applying a supported current
override; there is no RRULE interchange or external sync. Device-clock policy is
unchanged. See [ADR 0026](../adr/0026-calendar-occurrence-projection.md).

## Delivered rolling event repeats — 2026-10-09

Calendar planning event details offer Repeat & history. Configure daily, weekly,
monthly or yearly repeats, interval 1–366, optional total count/last start date,
pause and repeated-hour preference. Six upcoming starts are previewed. Monthly
and yearly repeats retain the initial anchor day, clamping to month end.
Record completed or Skip occurrence saves the current dates/outcome/action time
and advances once on the same object with its links intact. Missed dates stay
overdue; limits mark the last occurrence finished without deleting it. Guarded
undo and document history retain recovery paths. Actions use the saved rule;
save edited settings before recording. The history panel shows the latest 100;
all records remain in the event file, up to the explicit 10,000-record limit.

Timed repeats retain device-local start clock and elapsed duration. Earlier/later
policy resolves repeated hours; nonexistent local times refuse the advance without
writing history. Edit the current time before retrying. Device timezone changes
affect subsequent local repeats. All-day spans use civil dates. The ICS snapshot
shows only the current occurrence, not an expanded RRULE series.
Calendars and individual overrides are extended by the newer section above.
No provider sync, notifications or named-zone recurrence.
See [ADR 0025](../adr/0025-rolling-event-occurrences.md).

## Delivered local planning workspace — 2026-10-09

Open Calendar planning from the workspace/Home toolbar, Planning workspace from
Calendar, or Assignments & exams from a course dashboard. The existing month
calendar is retained. New day/week civil-hour grids clip overnight events into
each day and show overlapping events in separate lanes. All-day events and task
deadlines/scheduled dates have separate rows; the 30-day agenda exposes those
roles without copying objects. Timed conflict details consider other events in
the current scope, even when hidden by course/text filters. Named-zone calendars
and repeated-hour disambiguation remain separate; source UTC instants are retained.

Course, item-type, text and completed filters precede display. Unscheduled means
task without scheduledDate, even if a deadline exists. Effort summaries total only
explicit estimates. Remember view stores filters/date locally on this device;
unknown future settings are preserved. Large-text controls scroll independently.

Assignment/exam/lecture/meeting/study presets create ordinary tasks/events with
portable optional metadata. Resource links reference canonical UUIDs and generate
backlinks. A linked study session retains its assignment/exam resource; opening
an exam exposes actual review workload through its date and the existing review
queue. Dates, metadata, title and description updates use guarded recoverable
commands with undo; future metadata is preserved on unrelated edits and rejected
by unsupported planning edits. Missing resources are labelled rather than recreated.

Export filtered calendar writes an ICS snapshot: VEVENT for events and VTODO for
dated tasks, stable UIDs, UTC times/exclusive date ends, escaped/folded Unicode.
Unscheduled undated tasks are not exported. Scheduling on/after a deadline is
retained as X-ORBIT-SCHEDULED-DATE instead of an invalid start/due interval.
This provides local EVT-01–03/STUDY-01 subsets; no remote sync, invitations,
notifications, expanded recurrence calendar or time-grid drag/resize is claimed.

Status: local projection/rescheduling subset implemented; providers/sharing planned. Source: S10. [Tasks](tasks-calendar-and-planning.md) own task
semantics; this spec owns event/calendar behavior, not another task store.

| ID | Observable behavior |
|---|---|
| EVT-01 | Personal and project calendars display configured event dates, deadlines, milestones and scheduled tasks; scheduling a task does not silently replace its deadline. |
| EVT-02 | Events are Universal Objects with linked notes, resources and people. Opening an event reveals its recorded context and history, with backlinks to related work. |
| EVT-03 | Date-only, timed, timezone and daylight-saving behavior is explicit. Dragging a scheduled item previews and saves the affected date fields with undo. |
| EVT-04 | Shared calendars honor membership and object permissions; availability of a calendar never implies permission to read every linked note/resource. |
| EVT-05 | Later Google Calendar, Outlook and CalDAV adapters expose separate read-only/write scopes, source identity, sync state and conflict handling. No duplicate event on retry. |

Example: link lecture notes and a PDF to a course event, then open that context
from the calendar. Undated tasks remain available in an unscheduled list.
Deleting a calendar presentation must not delete all represented events.
External provider disconnect retains allowed local records with visible origin;
revocation and remote deletion need an explicit policy before adapter delivery.

Acceptance: open the same event from calendar and search and observe one identity;
move a scheduled task across a DST transition without changing its due date;
verify a viewer cannot perform a write through a drag gesture. External write
authorization is separate from permission to edit an ordinary local object.

2026-10-08: month/week day targets accept planning drags; agenda and timeline offer
keyboard-accessible date picking. Every move previews the affected field and uses
a stale/read-only guarded recoverable command with undo. Task deadlines and
schedules stay distinct. All-day moves retain exclusive civil-day duration;
timed moves retain local start clock/subseconds and elapsed duration. Existing
device-local DST gap validation applies. Named zones/ambiguous-time disambiguation,
external calendars and shared scheduling remain separate. See [ADR 0022](../adr/0022-smart-views-spaces-and-task-planning.md).
